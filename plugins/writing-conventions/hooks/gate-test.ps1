#Requires -Version 5.1
# Self-test for gate.ps1, offline. Run from anywhere:
#   pwsh -File hooks/gate-test.ps1
# A stub `claude` on the PATH stands in for the model, so what is tested is the
# plumbing: which commands reach the check, what the exit codes are, and that a
# nested call which fails lets the command through. gate-test.sh runs the same
# cases against gate.sh.
#
# ASCII only, so 5.1 cannot mangle it reading a BOM-less file as the ANSI codepage.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$gate = Join-Path $here 'gate.ps1'
$fail = 0
$cases = 0

# keys.ps1 against the fixture it shares with keys.awk. \n and \t in a command
# are a newline and a tab, and the output lines are joined as the fixture writes them.
. (Join-Path $here 'keys.ps1')
foreach ($rawLine in Get-Content -LiteralPath (Join-Path $here 'shell-keys.tsv')) {
  if ($rawLine -eq '' -or $rawLine.StartsWith('#')) { continue }
  $fields = $rawLine -split "`t"
  if ($fields.Count -lt 3) { continue }
  $cases++
  $cmd = $fields[1] -creplace '\\n', "`n" -creplace '\\t', "`t"
  $mode = $fields[0]
  $files = $mode.EndsWith('files')
  if ($files) { $mode = $mode.Substring(0, $mode.Length - 5) }
  $out = Get-CommandKey $cmd $mode -Files:$files
  if ($out.Count -eq 0) {
    $got = '-'
  } else {
    $parts = foreach ($line in $out) {
      $idx = $line.IndexOf("`t")
      $line.Substring(0, $idx) + ':' + $line.Substring($idx + 1)
    }
    $got = $parts -join ' | '
  }
  if ($got -cne $fields[2]) {
    Write-Output ("FAIL keys " + $fields[0] + ": " + $fields[1])
    Write-Output ("  wanted " + $fields[2])
    Write-Output ("  got    " + $got)
    $fail = 1
  }
}

$scratch = Join-Path ([IO.Path]::GetTempPath()) ("gateps-" + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)
# The stub is named for the platform running the test: a .bat is not resolved as
# `claude` off Windows, and without this the gate finds the real CLI on the PATH
# and every case that wants the stub reads as "model not called".
$onWindows = $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows
if ($onWindows) {
  $stub = @'
@echo off
rem One line per call: the arguments, then the marker the gate sets on its child.
>>"%GATE_TEST_MARK%" echo %* nested=%WRITING_CONVENTIONS_NESTED%
findstr "^" > "%GATE_TEST_MARK%.stdin"
rem A call past its time limit: ping is a child, so that killing the stub alone
rem would leave it running.
if not "%GATE_TEST_SLEEP%"=="" ping -n %GATE_TEST_SLEEP% 127.0.0.1 >nul
if "%GATE_TEST_FAIL%"=="1" exit /b 1
echo %* | findstr /c:"classify-prompt.md" >nul && (echo %GATE_TEST_CLASS%& exit /b 0)
echo %* | findstr /c:"classify-command.md" >nul && (type "%GATE_TEST_KEYS_FILE%" 2>nul& exit /b 0)
if exist "%GATE_TEST_VERDICT_FILE%" type "%GATE_TEST_VERDICT_FILE%"
'@
  $stubPath = Join-Path $scratch 'claude.bat'
} else {
  $stub = @'
#!/usr/bin/env bash
# One line per call: the arguments, then the marker the gate sets on its child.
printf '%s nested=%s\n' "$*" "$WRITING_CONVENTIONS_NESTED" >> "$GATE_TEST_MARK"
cat > "$GATE_TEST_MARK.stdin"
# A call past its time limit: the sleep is a child, so that killing the stub
# alone would leave it running.
if [ -n "$GATE_TEST_SLEEP" ]; then sleep "$GATE_TEST_SLEEP" & echo $! > "$GATE_TEST_MARK.sleep"; wait; fi
[ "$GATE_TEST_FAIL" = 1 ] && exit 1
case "$*" in *classify-prompt.md*) printf '%s\n' "$GATE_TEST_CLASS"; exit 0;; esac
case "$*" in *classify-command.md*) cat "$GATE_TEST_KEYS_FILE" 2>/dev/null; exit 0;; esac
cat "$GATE_TEST_VERDICT_FILE" 2>/dev/null
'@
  $stubPath = Join-Path $scratch 'claude'
}
[IO.File]::WriteAllText($stubPath, $stub, (New-Object System.Text.UTF8Encoding($false)))
if (-not $onWindows) { & /bin/chmod +x $stubPath }

$saved = @{
  PATH  = $env:PATH
  OS    = $env:OS
  TOOL  = $env:CLAUDE_CODE_USE_POWERSHELL_TOOL
  MODEL = $env:WRITING_CONVENTIONS_GATE_MODEL
  MARK  = $env:GATE_TEST_MARK
  NEST  = $env:WRITING_CONVENTIONS_NESTED
  FILE  = $env:GATE_TEST_VERDICT_FILE
  CLASS = $env:GATE_TEST_CLASS
  CONF  = $env:CLAUDE_CONFIG_DIR
  TMP   = $env:TMPDIR
  PROJ  = $env:CLAUDE_PROJECT_DIR
  SHELL = $env:WRITING_CONVENTIONS_SHELL_CLASSIFIER
  DEAD  = $env:WRITING_CONVENTIONS_GATE_DEADLINE
}
try {
  # The owner test in shell-owner.ps1 hands the hook to PowerShell only on Windows
  # with the PowerShell tool configured, so the test says so and runs anywhere.
  $env:PATH = $scratch + [IO.Path]::PathSeparator + $env:PATH
  $env:OS = 'Windows_NT'
  $env:CLAUDE_CODE_USE_POWERSHELL_TOOL = '1'
  $env:WRITING_CONVENTIONS_GATE_MODEL = $null
  $env:WRITING_CONVENTIONS_NESTED = $null
  $env:GATE_TEST_MARK = Join-Path $scratch 'mark'
  # The stub prints this file. A verdict has several lines and double quotes, which
  # a .bat `echo` of an environment variable cannot hold.
  $env:GATE_TEST_VERDICT_FILE = Join-Path $scratch 'verdict'
  # The shell classifier's reply, one key<TAB>class line per key; the gate keeps
  # only the lines for keys it asked about.
  $env:GATE_TEST_KEYS_FILE = Join-Path $scratch 'keys'
  $env:CLAUDE_PROJECT_DIR = $null
  $env:WRITING_CONVENTIONS_GATE_DEADLINE = $null
  $env:GATE_TEST_SLEEP = $null
  # No test reads or writes the user's own caches.
  $env:CLAUDE_CONFIG_DIR = Join-Path $scratch 'config'
  # The cases up to the shell classifier's own section are for the four command
  # families that reach the reader whatever is cached.
  $env:WRITING_CONVENTIONS_SHELL_CLASSIFIER = '0'

  # Returns @{ Status; Output; Called } for one command text.
  function Invoke-Gate([string]$verdict, [string]$failCall, [string]$cmdText) {
    $ErrorActionPreference = 'Continue'
    [IO.File]::WriteAllText($env:GATE_TEST_MARK, '')
    [IO.File]::WriteAllText($env:GATE_TEST_VERDICT_FILE, $verdict)
    $env:GATE_TEST_FAIL = $failCall
    $json = @{ tool_input = @{ command = $cmdText } } | ConvertTo-Json -Compress
    $out = $json | pwsh -NoProfile -File $gate 2>&1 | Out-String
    return @{
      Status = $LASTEXITCODE
      Output = $out.Trim()
      Called = ((Get-Item -LiteralPath $env:GATE_TEST_MARK).Length -gt 0)
    }
  }

  function Test-Gate([int]$wantStatus, [bool]$wantCalled, [string]$verdict, [string]$failCall, [string]$cmdText) {
    $script:cases++
    $r = Invoke-Gate $verdict $failCall $cmdText
    if ($r.Status -ne $wantStatus) {
      Write-Output ("FAIL exit " + $r.Status + ", wanted " + $wantStatus + ": " + $cmdText); $script:fail = 1
    }
    if ($r.Called -ne $wantCalled) {
      Write-Output ("FAIL model called=" + $r.Called + ", wanted " + $wantCalled + ": " + $cmdText); $script:fail = 1
    }
  }

  # A command that publishes nothing never reaches the model.
  Test-Gate 0 $false 'PASS' '0' 'Get-ChildItem'
  Test-Gate 0 $false 'PASS' '0' 'git log --grep=commit'
  Test-Gate 0 $false 'PASS' '0' 'gh repo view'
  # The four publishing families do, git -C included: no `if` pattern matches that
  # one, which is why the command text is matched here instead.
  Test-Gate 0 $true 'PASS' '0' 'git commit -m "Plain message"'
  Test-Gate 0 $true 'PASS' '0' 'git -C C:\tmp\wt commit -m "Plain message"'
  Test-Gate 0 $true 'PASS' '0' 'gh pr create --title x --body y'
  Test-Gate 0 $true 'PASS' '0' 'gh issue comment 1 --body y'
  Test-Gate 0 $true 'PASS' '0' 'gh release create v1 --notes y'
  Test-Gate 0 $true 'SKIP' '0' 'gh pr view 1'

  # Only a finding that quotes the command blocks it, and comes back as the reason.
  $says = 'git commit -m "The report says so"'
  # Returns the gate's output, which holds the verified findings.
  function Test-Blocked([string]$verdict, [string]$cmdText) {
    $script:cases++
    $r = Invoke-Gate $verdict '0' $cmdText
    if ($r.Status -ne 2) { Write-Output ("FAIL exit " + $r.Status + ", wanted 2: " + $verdict); $script:fail = 1 }
    return $r.Output
  }
  $out = Test-Blocked "VIOLATION`n`"The report says so`" -> The version is shown in the report." $says
  if ($out -notlike '*shown in the report*run the command again*') { Write-Output ("FAIL violation reason: " + $out); $fail = 1 }
  # A fragment is matched with runs of whitespace collapsed, so a sentence that
  # wraps in the commit body is still found.
  $null = Test-Blocked "VIOLATION`n`"The report says so`" -> x" "git commit -m `"Fix it`n`nThe report`n  says so`""
  # Every fragment of a finding has to be in the command, and the reason leaves out
  # a finding that is not.
  $null = Test-Blocked "VIOLATION`n`"The report`" + `"says so`" -> x" $says
  $out = Test-Blocked "VIOLATION`n`"The build decided`" -> invented`n`"The report says so`" -> real" $says
  if ($out -like '*invented*') { Write-Output ("FAIL unverified finding in the reason: " + $out); $fail = 1 }
  Test-Gate 0 $true "VIOLATION`n`"The report`" + `"never appears`" -> x" '0' $says
  # Anything else lets the command through: a quote that is not in the command, a
  # verdict line with a second word, a finding that does not parse, prose with no
  # verdict line, and the reply the gate asked for before this contract.
  Test-Gate 0 $true "VIOLATION`n`"The build decided`" -> x" '0' $says
  Test-Gate 0 $true "VIOLATION MAYBE`n`"The report says so`" -> x" '0' $says
  Test-Gate 0 $true "VIOLATION`nThe report says so: rewrite it" '0' $says
  Test-Gate 0 $true 'VIOLATION' '0' $says
  # An empty quote is in every command, so it is not a quote.
  Test-Gate 0 $true "VIOLATION`n`"`" -> x" '0' $says
  Test-Gate 0 $true "VIOLATION`n`" -> x" '0' $says
  Test-Gate 0 $true 'the report says: rewrite it' '0' $says
  Test-Gate 0 $true 'CLEAN' '0' $says
  # A gate that cannot reach a model must not stop a commit.
  Test-Gate 0 $true '' '1' 'git commit -m "Plain message"'
  Test-Gate 0 $true '' '0' 'git commit -m "Plain message"'

  # The reader call. `--tools=` is one argument, because PowerShell can drop an empty
  # one, and the marker is set on the child so that a copy of this hook registered by
  # managed policy, which `--safe-mode` does not turn off, exits inside the nested call.
  # Checks the calls of the last run against one wildcard pattern per call.
  function Test-Calls([string[]]$want) {
    $script:cases++
    $lines = @(Get-Content -LiteralPath $env:GATE_TEST_MARK | Where-Object { $_.Trim() -ne '' })
    if ($lines.Count -ne $want.Count) {
      Write-Output ("FAIL " + ($lines -join ' | ') + ", wanted " + $want.Count + " calls"); $script:fail = 1; return
    }
    for ($i = 0; $i -lt $want.Count; $i++) {
      if ($lines[$i] -notlike $want[$i]) { Write-Output ("FAIL call " + ($i + 1) + ": " + $lines[$i]); $script:fail = 1 }
    }
  }
  $blocking = "VIOLATION`n`"The report says so`" -> x"
  $null = Invoke-Gate 'PASS' '0' $says
  # The rules reach the reader from rules.md, appended to gate-prompt.md.
  Test-Calls @('*--safe-mode --tools= --model*gate-prompt.md --append-system-prompt-file *rules.md nested=1*')
  $r = Invoke-Gate '' '1' $says
  if ($r.Status -ne 0) { Write-Output ("FAIL exit " + $r.Status + ", wanted 0 with the call failing"); $fail = 1 }
  Test-Calls @('*--safe-mode*')
  # Inside a nested call the gate does nothing, whatever the reader would have said.
  $env:WRITING_CONVENTIONS_NESTED = '1'
  Test-Gate 0 $false $blocking '0' $says
  $env:WRITING_CONVENTIONS_NESTED = $null

  # MCP calls. The trigger is a lookup of the tool name in a per-user cache that a
  # classifier call fills, so no server or tool name is written in the gate.
  $env:CLAUDE_CONFIG_DIR = Join-Path $scratch 'config'
  # Returns the gate's output for one hook input. A failure goes to the host, so that
  # a caller that drops the output still shows it.
  function Test-Mcp([int]$wantStatus, [int]$wantClass, [int]$wantReader, [string]$class, [string]$verdict, [string]$hookInput) {
    $script:cases++
    $ErrorActionPreference = 'Continue'
    [IO.File]::WriteAllText($env:GATE_TEST_MARK, '')
    [IO.File]::WriteAllText($env:GATE_TEST_VERDICT_FILE, $verdict)
    $env:GATE_TEST_FAIL = '0'
    $env:GATE_TEST_CLASS = $class
    $out = $hookInput | pwsh -NoProfile -File $gate 2>&1 | Out-String
    if ($LASTEXITCODE -ne $wantStatus) {
      Write-Host ("FAIL exit " + $LASTEXITCODE + ", wanted " + $wantStatus + ": " + $hookInput); $script:fail = 1
    }
    $lines = @(Get-Content -LiteralPath $env:GATE_TEST_MARK | Where-Object { $_ -ne '' })
    $c = @($lines | Where-Object { $_ -like '*classify-prompt.md*' }).Count
    $r = @($lines | Where-Object { $_ -like '*gate-prompt.md*' }).Count
    if ($c -ne $wantClass -or $r -ne $wantReader) {
      Write-Host ("FAIL classifier and reader calls $c $r, wanted $wantClass $wantReader" + ": " + $hookInput); $script:fail = 1
    }
    return $out
  }
  function Get-CacheFile { (Get-ChildItem (Join-Path $env:CLAUDE_CONFIG_DIR 'writing-conventions') -Filter 'mcp-tools-*.txt')[0].FullName }
  $jira = '{"tool_name":"mcp__atlassian__createJiraIssue","tool_input":{"projectKey":"PLAT","summary":"Stale check","description":"The report says so."}}'
  $bitbucket = '{"tool_name":"mcp__bitbucket__create_pull_request","tool_input":{"title":"Fix it","description":"The report says so."}}'
  $search = '{"tool_name":"mcp__atlassian__searchJiraIssuesUsingJql","tool_input":{"jql":"text ~ \"The report says so.\""}}'
  $adf = '{"tool_name":"mcp__atlassian__addCommentToJiraIssue","tool_input":{"issueKey":"PLAT-42","body":{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"The report "},{"type":"text","text":"says so.","marks":[{"type":"strong"}]}]}]}}}'
  $whole = "VIOLATION`n`"The report says so.`" -> x"
  # A miss calls the classifier once, a repeat does not, and both inputs reach the reader.
  $null = Test-Mcp 0 1 1 'CAN_PUBLISH' 'PASS' $jira
  $null = Test-Mcp 0 0 1 'CAN_PUBLISH' 'PASS' $jira
  $out = Test-Mcp 2 1 1 'CAN_PUBLISH' $whole $bitbucket
  if ($out -notlike '*make the call again*') { Write-Output ("FAIL MCP reason: " + $out); $fail = 1 }
  # A tool classified NEVER makes no reader call, then or later.
  $null = Test-Mcp 0 1 0 'NEVER' 'PASS' $search
  $null = Test-Mcp 0 0 0 'NEVER' 'PASS' $search
  # A sentence that a rich-text format splits across nodes is quoted as its pieces.
  # Nothing is joined, so the whole sentence is in no source.
  $null = Test-Mcp 2 1 1 'CAN_PUBLISH' "VIOLATION`n`"The report `" + `"says so.`" -> x" $adf
  $null = Test-Mcp 0 0 1 'CAN_PUBLISH' $whole $adf
  $null = Test-Mcp 0 0 1 'CAN_PUBLISH' "VIOLATION`n`"The build decided`" -> x" $adf
  # Only the string values of tool_input are reviewed: not a key, not the tool name.
  $null = Test-Mcp 0 0 1 'CAN_PUBLISH' "VIOLATION`n`"issueKey`" -> x" $adf
  $null = Test-Mcp 0 0 1 'CAN_PUBLISH' "VIOLATION`n`"addCommentToJiraIssue`" -> x" $adf
  # A value is decoded before it is searched: an escaped quote and an escaped newline.
  $null = Test-Mcp 2 0 1 'CAN_PUBLISH' $whole '{"tool_name":"mcp__atlassian__createJiraIssue","tool_input":{"description":"See \"the log\".\nThe report\nsays so."}}'
  # In the cache, a CAN_PUBLISH line for a tool wins over a NEVER line for it, a
  # malformed line is ignored, and a missing file is a miss.
  Add-Content -LiteralPath (Get-CacheFile) -Value 'mcp__x__post NEVER', 'mcp__x__post CAN_PUBLISH', 'mcp__x__odd MAYBE', 'mcp__x__odd'
  $null = Test-Mcp 0 0 1 'NEVER' 'PASS' '{"tool_name":"mcp__x__post","tool_input":{"text":"hi"}}'
  $null = Test-Mcp 0 1 1 'CAN_PUBLISH' 'PASS' '{"tool_name":"mcp__x__odd","tool_input":{"text":"hi"}}'
  Remove-Item -LiteralPath (Get-CacheFile)
  $null = Test-Mcp 0 1 1 'CAN_PUBLISH' 'PASS' $jira
  # A classifier reply in any other form is doubt: the reader runs and nothing is cached.
  $null = Test-Mcp 0 1 1 'It can publish.' 'PASS' '{"tool_name":"mcp__x__vague","tool_input":{"text":"hi"}}'
  $null = Test-Mcp 0 1 1 'CAN_PUBLISH' 'PASS' '{"tool_name":"mcp__x__vague","tool_input":{"text":"hi"}}'

  # Prose files, after a Write or an Edit. Nothing is blocked: a verified finding
  # comes back as additionalContext, and so does a statement of what was not read.
  # Returns @{ Out; Sent }: the gate's output and the message the reader was sent. A
  # failure goes to the host, so that a caller that drops the output still shows it.
  function Test-File([int]$wantReader, [string]$wantLike, [string]$verdict, [string]$hookInput, [string]$failCall = '0') {
    $script:cases++
    $ErrorActionPreference = 'Continue'
    $sentPath = $env:GATE_TEST_MARK + '.stdin'
    [IO.File]::WriteAllText($env:GATE_TEST_MARK, '')
    [IO.File]::WriteAllText($sentPath, '')
    [IO.File]::WriteAllText($env:GATE_TEST_VERDICT_FILE, $verdict)
    $env:GATE_TEST_FAIL = $failCall
    $out = ($hookInput | pwsh -NoProfile -File $gate --file 2>&1 | Out-String).Trim()
    $short = $hookInput.Substring(0, [Math]::Min(160, $hookInput.Length))
    if ($LASTEXITCODE -ne 0) { Write-Host ("FAIL exit " + $LASTEXITCODE + ", wanted 0: " + $short); $script:fail = 1 }
    $r = @(Get-Content -LiteralPath $env:GATE_TEST_MARK | Where-Object { $_ -like '*gate-prompt.md*' }).Count
    if ($r -ne $wantReader) { Write-Host ("FAIL reader calls $r, wanted $wantReader" + ": " + $short); $script:fail = 1 }
    if (($wantLike -eq '' -and $out -ne '') -or ($wantLike -ne '' -and $out -notlike $wantLike)) {
      Write-Host ("FAIL output, wanted " + $wantLike + ": " + $out.Substring(0, [Math]::Min(300, $out.Length))); $script:fail = 1
    }
    return @{ Out = $out; Sent = [IO.File]::ReadAllText($sentPath) }
  }
  function New-Input([string]$tool, [hashtable]$toolInput) { @{ tool_name = $tool; tool_input = $toolInput } | ConvertTo-Json -Compress }
  function New-Edit([string]$path, [string]$new) { New-Input 'Edit' @{ file_path = $path; old_string = 'x'; new_string = $new } }
  $doc = Join-Path $scratch 'doc.md'
  [IO.File]::WriteAllText($doc, "# Title`n`nThe report says the version. It is short.`n`nSecond paragraph stays.`n`nThird one here.`n")
  $r = Test-File 1 '' 'PASS' (New-Input 'Write' @{ file_path = $doc; content = "# Title`n`nPlain text." })
  if ($r.Sent -notlike '*Plain text.*') { Write-Output ("FAIL the content was not sent: " + $r.Sent); $fail = 1 }
  $null = Test-File 0 '' 'PASS' (New-Input 'Write' @{ file_path = (Join-Path $scratch 'Main.kt'); content = '// The report says so.' })
  $null = Test-File 1 '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"\"Plain text.\" -> x\nFix the quoted text in *"}}' "VIOLATION`n`"Plain text.`" -> x" (New-Input 'Write' @{ file_path = (Join-Path $scratch 'NOTES.RST'); content = 'Plain text.' })
  # A one-word edit is reviewed as the whole paragraphs that hold it, so a finding can
  # quote the sentence around the word, and the rest of the file is not sent.
  $r = Test-File 1 '*The report says the version.*' "VIOLATION`n`"The report says the version.`" -> x" (New-Edit $doc 'says')
  if ($r.Sent -notlike '*It is short.*') { Write-Output ("FAIL the paragraph was not sent: " + $r.Sent); $fail = 1 }
  if ($r.Sent -like '*Third one*') { Write-Output ("FAIL another paragraph was sent: " + $r.Sent); $fail = 1 }
  $null = Test-File 1 '' "VIOLATION`n`"Third one here.`" -> x" (New-Edit $doc 'says')
  # new_string can span paragraphs, and every paragraph it touches is reviewed.
  $null = Test-File 1 '*paragraph stays.*' "VIOLATION`n`"The report says`" + `"paragraph stays.`" -> x" (New-Edit $doc "It is short.`n`nSecond")
  # A small edit to a 900 KB file is reviewed by excerpt.
  $sb = New-Object System.Text.StringBuilder
  foreach ($i in 0..14999) { [void]$sb.Append("Filler paragraph $i, sixty characters of plain text to pad.`n`n") }
  [void]$sb.Append("The report says so.`n")
  $big = Join-Path $scratch 'big.md'
  [IO.File]::WriteAllText($big, $sb.ToString())
  $r = Test-File 1 '*The report says so.*' "VIOLATION`n`"The report says so.`" -> x" (New-Edit $big 'says so')
  if ($r.Sent.Length -ge 1000) { Write-Output ("FAIL " + $r.Sent.Length + " characters sent for a small edit"); $fail = 1 }
  # What is not reviewed is stated: a file over 1 MB is not scanned, so new_string
  # alone is read; a deletion; and the text past the cap.
  $huge = Join-Path $scratch 'huge.md'
  [IO.File]::WriteAllText($huge, $sb.ToString() + $sb.ToString())
  $null = Test-File 1 '*says so\" -> x*over 1 MB*' "VIOLATION`n`"says so`" -> x" (New-Edit $huge 'says so')
  $null = Test-File 0 '*Not reviewed*deleted*' 'PASS' (New-Edit $doc '')
  $long = 'Sixty characters of plain text, or near enough, to pad it. ' * 1000
  $r = Test-File 1 '*Only the first 50000 characters*' 'PASS' (New-Input 'Write' @{ file_path = $doc; content = $long })
  if ($r.Sent.Length -ge 51000) { Write-Output ("FAIL " + $r.Sent.Length + " characters sent past the cap"); $fail = 1 }
  # A reader that cannot run says nothing, and the advisory nudge in lint.ps1 still fires.
  $null = Test-File 1 '' '' (New-Edit $doc 'says') '1'

  # The first time in a session that a check cannot run, the user is told once, through
  # systemMessage, which the user is shown and the model is not. The marker is a file
  # named for the session, so another session gets its own notice, and input with no
  # session id gets none, because nothing could stop it repeating.
  $env:TMPDIR = Join-Path $scratch 'tmp'
  [void](New-Item -ItemType Directory -Path $env:TMPDIR)
  $pwshPath = (Get-Command pwsh).Source
  function Test-Notice([string]$want, [string]$failCall, [string]$sid, [string]$cmdText = 'git commit -m x') {
    $script:cases++
    $ErrorActionPreference = 'Continue'
    [IO.File]::WriteAllText($env:GATE_TEST_VERDICT_FILE, 'PASS')
    $env:GATE_TEST_FAIL = $failCall
    $json = @{ session_id = $sid; tool_input = @{ command = $cmdText } } | ConvertTo-Json -Compress
    $out = ($json | & $pwshPath -NoProfile -File $gate 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { Write-Output ("FAIL exit " + $LASTEXITCODE + ", wanted 0: notice $failCall $sid"); $script:fail = 1 }
    if (($want -eq '' -and $out -ne '') -or ($want -ne '' -and $out -notlike $want)) {
      Write-Output ("FAIL notice for $failCall $sid, wanted " + $want + ": " + $out); $script:fail = 1
    }
  }
  Test-Notice '{"systemMessage":"*model review is off*"}' '1' 's1'
  Test-Notice '' '1' 's1'
  Test-Notice '{"systemMessage":"*"}' '1' 's2'
  # A session in which the retry succeeded gets none, and neither does a passing one.
  Test-Notice '' 'safe' 's3'
  Test-Notice '' '0' 's3'
  Test-Notice '' '1' ''
  # No `claude` on the path is the same failure, but only for a command that needed it.
  $withStub = $env:PATH
  $env:PATH = Join-Path $scratch 'tmp'
  Test-Notice '' '1' 's4' 'ls -la'
  Test-Notice '{"systemMessage":"*"}' '1' 's4'
  Test-Notice '' '1' 's4'
  $env:PATH = $withStub
  $env:TMPDIR = $saved.TMP

  # Stop replies. Only the text a `draft` fence holds is reviewed, and a reply with
  # no such fence costs no call at all. A blocked reply is re-emitted whole, so the
  # blocking is counted per turn and stops after two.
  $env:TMPDIR = Join-Path $scratch 'stoptmp'
  [void](New-Item -ItemType Directory -Path $env:TMPDIR)
  $errFile = Join-Path $scratch 'stoperr'
  $tick = [string][char]0x60
  $f3 = $tick * 3
  $f4 = $tick * 4
  $V = "VIOLATION`n`"The report says so.`" -> The version is shown in the report."
  $V2 = "VIOLATION`n`"The build decided it.`" -> x"
  # Afterwards: $out is stdout, $stderr the reason, $sent what the reader was given.
  function Test-Stop([int]$wantStatus, [bool]$wantCalled, [string]$verdict, [string]$promptId,
                     [string]$reply, [string]$failCall = '0', [string]$extra = '') {
    $script:cases++
    $ErrorActionPreference = 'Continue'
    [IO.File]::WriteAllText($env:GATE_TEST_MARK, '')
    [IO.File]::WriteAllText(($env:GATE_TEST_MARK + '.stdin'), '')
    [IO.File]::WriteAllText($env:GATE_TEST_VERDICT_FILE, $verdict)
    $env:GATE_TEST_FAIL = $failCall
    $json = '{"session_id":"stopsess",' + $extra + '"prompt_id":"' + $promptId +
            '","last_assistant_message":"' + $reply + '"}'
    $script:out = ($json | & $pwshPath -NoProfile -File $gate '--stop' 2>$errFile | Out-String).Trim()
    $status = $LASTEXITCODE
    $script:stderr = [IO.File]::ReadAllText($errFile)
    $script:sent = [IO.File]::ReadAllText($env:GATE_TEST_MARK + '.stdin')
    $called = ((Get-Item -LiteralPath $env:GATE_TEST_MARK).Length -gt 0)
    if ($status -ne $wantStatus) { Write-Output ("FAIL exit $status, wanted $wantStatus" + ": " + $reply); $script:fail = 1 }
    if ($called -ne $wantCalled) { Write-Output ("FAIL model called=$called, wanted $wantCalled" + ": " + $reply); $script:fail = 1 }
  }
  # No fence, and a fence that is not a draft, make no call.
  Test-Stop 0 $false $V 's01' 'Here it is. The report says so.'
  Test-Stop 0 $false $V 's02' ('Here it is.\n\n' + $f3 + 'python\nThe report says so.\n' + $f3)
  # A draft fence is read, and the reader is sent the draft and nothing else.
  Test-Stop 2 $true $V 's03' ('Outside text.\n\n' + $f3 + 'draft\nThe report says so.\n' + $f3)
  if ($stderr -notlike '*emit the corrected draft*') { Write-Output ("FAIL stop reason: " + $stderr); $fail = 1 }
  if ($sent -like '*Outside text*') { Write-Output ("FAIL text outside the fence was sent: " + $sent); $fail = 1 }
  # A finding that quotes text outside every draft fence is unverified, so prose the
  # model was never sent cannot block the reply.
  Test-Stop 0 $true $V 's04' ('The report says so.\n\n' + $f3 + 'draft\nPlain text.\n' + $f3)
  # A four-backtick fence is closed by its own marker, so a code fence inside a draft
  # does not end it, and a tilde fence is a fence.
  Test-Stop 2 $true $V 's05' ($f4 + 'draft\nPlain text.\n\n' + $f3 + 'py\nx = 1\n' + $f3 + '\n\nThe report says so.\n' + $f4)
  Test-Stop 2 $true $V 's06' '~~~draft\nThe report says so.\n~~~'
  # Two draft fences are two sources: one quote cannot span both, and a two-fragment
  # finding that quotes each of them can.
  $two = $f3 + 'draft\nThe report \n' + $f3 + '\n\nAnd the second:\n\n' + $f3 + 'draft\nsays so.\n' + $f3
  Test-Stop 0 $true $V 's07' $two
  Test-Stop 2 $true "VIOLATION`n`"The report`" + `"says so.`" -> x" 's08' $two
  # A malformed first line never blocks.
  Test-Stop 0 $true "VIOLATION MAYBE`n`"The report says so.`" -> x" 's09' ($f3 + 'draft\nThe report says so.\n' + $f3)
  # Two blocks in one turn, then the user is told that review is unresolved. An
  # unchanged rewrite blocks the second time, and a violation the rewrite introduced
  # counts as an attempt just the same.
  $draft1 = $f3 + 'draft\nThe report says so.\n' + $f3
  $draft2 = $f3 + 'draft\nThe build decided it.\n' + $f3
  Test-Stop 2 $true $V 's10' $draft1
  Test-Stop 2 $true $V 's10' $draft1
  Test-Stop 0 $true $V 's10' $draft1
  if ($out -notlike '{"systemMessage":"*Review is unresolved*') { Write-Output ("FAIL unresolved notice: " + $out); $fail = 1 }
  Test-Stop 2 $true $V 's11' $draft1
  Test-Stop 2 $true $V2 's11' $draft2
  Test-Stop 0 $true $V2 's11' $draft2
  if ($out -notlike '*Review is unresolved*') { Write-Output ("FAIL unresolved notice after a new violation: " + $out); $fail = 1 }
  # The count is per turn, so the next turn starts over.
  Test-Stop 2 $true $V 's12' $draft1
  # stop_hook_active is another plugin's flag, and this script keeps its own count.
  Test-Stop 2 $true $V 's13' $draft1 '0' '"stop_hook_active":true,'
  # With no prompt_id there is nothing to count with, so nothing is blocked and no
  # call is made.
  Test-Stop 0 $false $V '' $draft1
  # The off switch skips the reader and leaves the reply lint as the only check.
  $env:WRITING_CONVENTIONS_STOP_READER = '0'
  try { Test-Stop 0 $false $V 's14' $draft1 }
  finally { $env:WRITING_CONVENTIONS_STOP_READER = $null }
  # A reader that cannot run does not block the reply, and says so once.
  Test-Stop 0 $true $V 's15' $draft1 '1'
  if ($out -notlike '{"systemMessage":"*model review is off*') { Write-Output ("FAIL stop notice: " + $out); $fail = 1 }
  # The cap comes off the drafts before the reader is sent them and before a
  # finding is checked, so a quote from past it is a quote of text that was never
  # reviewed.
  $pad = ('Sixty characters of plain text, or near enough, to pad it. ' * 1000)
  Test-Stop 0 $true $V2 's17' ($f3 + 'draft\n' + $pad + '\nThe build decided it.\n' + $f3)
  if ($sent.Length -ge 51000) { Write-Output ("FAIL " + $sent.Length + " characters sent past the cap"); $fail = 1 }
  Test-Stop 2 $true $V2 's18' ($f3 + 'draft\nThe build decided it.\n\n' + $pad + '\n' + $f3)

  # A closing fence takes no info string, so a line inside a draft that starts
  # with the marker and goes on does not end the draft, and what follows is still
  # read.
  Test-Stop 2 $true $V2 's19' ($f3 + 'draft\nThe report says so.\n' + $f3 + ' and more\nThe build decided it.\n' + $f3)
  # The count has to fail open. A state file that cannot be written would
  # otherwise leave the count at nothing and block every Stop call of the turn.
  [void](New-Item -ItemType Directory -Path (Join-Path $env:TMPDIR 'claude-gate-stop-s20'))
  Test-Stop 0 $true $V 's20' $draft1
  if ($out -notlike '*could not be written*') { Write-Output ("FAIL no notice for an unwritable count: " + $out); $fail = 1 }
  # A count file another program wrote is not room for another block.
  [IO.File]::WriteAllText((Join-Path $env:TMPDIR 'claude-gate-stop-s21'), " 2 `n")
  Test-Stop 0 $true $V 's21' $draft1
  if ($out -notlike '*after two rewrites*') { Write-Output ("FAIL no notice for a padded count: " + $out); $fail = 1 }
  [IO.File]::WriteAllText((Join-Path $env:TMPDIR 'claude-gate-stop-s22'), 'abc')
  Test-Stop 0 $true $V 's22' $draft1
  if ($out -notlike '*after two rewrites*') { Write-Output ("FAIL no notice for a garbage count: " + $out); $fail = 1 }

  # A draft left open at the end of the reply runs to the end.
  Test-Stop 2 $true $V 's23' ('x\n' + $f3 + 'draft\nThe report says so.\n')
  if ($sent -notlike 'The report says so.*') { Write-Output ("FAIL unterminated draft sent as [" + $sent + "]"); $fail = 1 }
  if ($sent.Trim("`n") -ne 'The report says so.') { Write-Output ("FAIL unterminated draft has trailing lines: [" + $sent + "]"); $fail = 1 }

  # Inside a nested call this entry point does nothing either.
  $env:WRITING_CONVENTIONS_NESTED = '1'
  try { Test-Stop 0 $false $V 's16' $draft1 }
  finally { $env:WRITING_CONVENTIONS_NESTED = $null }
  $env:TMPDIR = $saved.TMP

  # The shell classifier. Any command outside the four families is split into
  # keys, and a key the cache has no answer for costs one classifier call for the
  # whole command. A key below a task runner is kept per project.
  $env:WRITING_CONVENTIONS_SHELL_CLASSIFIER = $null
  $env:CLAUDE_CONFIG_DIR = Join-Path $scratch 'shellconfig'
  $env:TMPDIR = Join-Path $scratch 'shelltmp'
  [void](New-Item -ItemType Directory -Path $env:TMPDIR)
  $script:shellOut = ''
  function Test-Shell([int]$wantStatus, [int]$wantClass, [int]$wantReader, [string]$cmdText,
                      [string]$cwd = '/proj/a', [string]$keys = '', [string]$verdict = 'PASS', [string]$sid = 'shell') {
    $script:cases++
    $ErrorActionPreference = 'Continue'
    [IO.File]::WriteAllText($env:GATE_TEST_MARK, '')
    [IO.File]::WriteAllText($env:GATE_TEST_VERDICT_FILE, $verdict)
    [IO.File]::WriteAllText($env:GATE_TEST_KEYS_FILE, $keys)
    $env:GATE_TEST_FAIL = '0'
    $json = @{ session_id = $sid; cwd = $cwd; tool_name = 'PowerShell'; tool_input = @{ command = $cmdText } } | ConvertTo-Json -Compress
    $script:shellOut = ($json | pwsh -NoProfile -File $gate 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne $wantStatus) {
      Write-Output ("FAIL exit " + $LASTEXITCODE + ", wanted " + $wantStatus + ": " + $cmdText); $script:fail = 1
    }
    $lines = @(Get-Content -LiteralPath $env:GATE_TEST_MARK | Where-Object { $_ -ne '' })
    $c = @($lines | Where-Object { $_ -like '*classify-command.md*' }).Count
    $r = @($lines | Where-Object { $_ -like '*gate-prompt.md*' }).Count
    if ($c -ne $wantClass -or $r -ne $wantReader) {
      Write-Output ("FAIL classifier and reader calls $c $r, wanted $wantClass $wantReader" + ": " + $cmdText); $script:fail = 1
    }
  }
  function Get-ShellCache {
    $d = Join-Path $env:CLAUDE_CONFIG_DIR 'writing-conventions'
    if (-not (Test-Path -LiteralPath $d)) { return '' }
    return (@(Get-ChildItem $d -Filter 'shell-commands-*.txt' | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join '')
  }
  # A cold key costs one call, and its answer is kept; the same command again costs none.
  Test-Shell 0 1 0 'Get-ChildItem -Recurse' -keys "Get-ChildItem`tNEVER`n"
  if ((Get-ShellCache) -cne "*`tNEVER`tGet-ChildItem`n") { Write-Output ("FAIL cache after Get-ChildItem: " + (Get-ShellCache)); $fail = 1 }
  Test-Shell 0 0 0 'Get-ChildItem -Recurse'
  # A publishing command no name was written for reaches the reader, and each
  # answered key is kept, a task name in the project's scope as well.
  Test-Shell 0 1 1 'hg commit -m "Fix it"' -keys "hg`tDESCEND`nhg commit`tCAN_PUBLISH`n"
  $n = @((Get-ShellCache) -split "`n" | Where-Object { $_ -like '*hg*' }).Count
  if ($n -ne 3) { Write-Output ("FAIL cache after hg: " + (Get-ShellCache)); $fail = 1 }
  Test-Shell 0 0 1 'hg commit -m "Fix it"'
  Test-Shell 2 0 1 'hg commit -m "The report says so"' -verdict "VIOLATION`n`"The report says so`" -> x"
  # Below a cached DESCEND, only the subcommand is asked about.
  Test-Shell 0 1 0 'hg log' -keys "hg log`tNEVER`n"
  Test-Shell 0 0 0 'hg log'
  # A classifier reply in any other form is doubt: the reader runs and nothing is kept.
  $before = Get-ShellCache
  Test-Shell 0 1 1 'jj describe -m x' -keys "It can publish.`n"
  if ((Get-ShellCache) -cne $before) { Write-Output ("FAIL a malformed reply was cached: " + (Get-ShellCache)); $fail = 1 }
  # The four families reach the reader whatever is cached.
  $cacheFile = @(Get-ChildItem (Join-Path $env:CLAUDE_CONFIG_DIR 'writing-conventions') -Filter 'shell-commands-*.txt')[0].FullName
  [IO.File]::AppendAllText($cacheFile, "*`tNEVER`tgit`n*`tNEVER`tgit commit`n")
  Test-Shell 0 0 1 'git commit -m x'
  Test-Shell 0 0 1 'git commit -F msg.txt'
  # A task name is kept for its project only, and a task runner with no task, or
  # with one task that is not NEVER, reaches the reader.
  Test-Shell 0 1 0 'make check' -keys "make`tPROJECT`nmake check`tNEVER`n"
  Test-Shell 0 0 0 'make check'
  Test-Shell 0 1 0 'make check' -cwd '/proj/b' -keys "make check`tNEVER`n"
  Test-Shell 0 0 1 'make'
  Test-Shell 0 1 1 'make check publish'
  # A word that cannot be read as a name reaches the reader below DESCEND or
  # PROJECT, and changes nothing below NEVER or RUNS_CODE.
  Test-Shell 0 0 1 'hg "$verb" -m x'
  Test-Shell 0 0 1 'make check "$task"'
  Test-Shell 0 1 0 'ls "$dir"' -keys "ls`tNEVER`n"
  Test-Shell 0 1 0 "python3 -c 'print(1)'" -keys "python3`tRUNS_CODE`n"
  Test-Shell 0 0 0 "python3 -c 'print(1)'"
  Test-Shell 0 0 1 "python3 -c 'print(`"The report says so and more.`")'"
  # A substitution in an expanding here-string, and a quoted first word, reach the
  # reader with no lookup.
  Test-Shell 0 0 1 "`$b = @`"`n`$(hg commit -m x)`n`"@"
  Test-Shell 0 0 1 '"my tool" run'
  # The off switch returns the trigger to the four families.
  $env:WRITING_CONVENTIONS_SHELL_CLASSIFIER = '0'
  try { Test-Shell 0 0 0 'svn commit -m x' -keys "svn`tDESCEND`n" }
  finally { $env:WRITING_CONVENTIONS_SHELL_CLASSIFIER = $null }
  # A classifier call that cannot run lets the command through and says so once.
  $env:PATH = [IO.Path]::GetDirectoryName($pwshPath)
  try { Test-Shell 0 0 0 'svn commit -m x' -sid 'shell-off' }
  finally { $env:PATH = $scratch + [IO.Path]::PathSeparator + $saved.PATH }
  if ($script:shellOut -notlike '{"systemMessage":"*model review is off*') { Write-Output ("FAIL no notice without claude: " + $script:shellOut); $fail = 1 }

  # The time budget. A call past its limit is killed with its children and lets
  # the command through with the notice. The deadline is set short so that the
  # limit is 17 seconds rather than 60.
  $env:TMPDIR = Join-Path $scratch 'budgettmp'
  [void](New-Item -ItemType Directory -Path $env:TMPDIR)
  $cases++
  $ErrorActionPreference = 'Continue'
  [IO.File]::WriteAllText($env:GATE_TEST_MARK, '')
  [IO.File]::WriteAllText($env:GATE_TEST_VERDICT_FILE, 'PASS')
  $env:GATE_TEST_FAIL = '0'
  $env:GATE_TEST_SLEEP = '40'
  $env:WRITING_CONVENTIONS_GATE_DEADLINE = '27'
  try {
    $out = ('{"session_id":"slow","tool_input":{"command":"git commit -m x"}}' | pwsh -NoProfile -File $gate 2>$null | Out-String).Trim()
    $status = $LASTEXITCODE
  } finally { $env:GATE_TEST_SLEEP = $null; $env:WRITING_CONVENTIONS_GATE_DEADLINE = $null }
  if ($status -ne 0) { Write-Output "FAIL exit $status after a kill"; $fail = 1 }
  $lines = @(Get-Content -LiteralPath $env:GATE_TEST_MARK | Where-Object { $_ -ne '' })
  if ($lines.Count -ne 1) { Write-Output ("FAIL calls after a kill: " + ($lines -join ' | ')); $fail = 1 }
  if ($out -notlike '{"systemMessage":"*model review is off*') { Write-Output "FAIL no notice after a kill: $out"; $fail = 1 }
  if (-not $onWindows) {
    $sleeper = [int](Get-Content -LiteralPath ($env:GATE_TEST_MARK + '.sleep'))
    if (Get-Process -Id $sleeper -ErrorAction SilentlyContinue) { Write-Output "FAIL the call's child outlived the kill"; $fail = 1 }
  }
  # A call with under 15 seconds left is not started, on the MCP branch as well.
  $cases++
  [IO.File]::WriteAllText($env:GATE_TEST_MARK, '')
  $env:WRITING_CONVENTIONS_GATE_DEADLINE = '20'
  try {
    $out = ('{"session_id":"late","tool_name":"mcp__x__late","tool_input":{"text":"hi"}}' | pwsh -NoProfile -File $gate 2>$null | Out-String).Trim()
    $status = $LASTEXITCODE
  } finally { $env:WRITING_CONVENTIONS_GATE_DEADLINE = $null }
  if ($status -ne 0 -or (Get-Item -LiteralPath $env:GATE_TEST_MARK).Length -gt 0) { Write-Output 'FAIL a call started with under 15 seconds left'; $fail = 1 }
  if ($out -notlike '{"systemMessage":"*') { Write-Output "FAIL no notice for a call not started: $out"; $fail = 1 }
  # Each branch's deadline is its hook timeout in hooks.json less 15 seconds.
  $cases++
  $want = @{}
  $hooksJson = Get-Content -Raw -LiteralPath (Join-Path $here 'hooks.json') | ConvertFrom-Json
  foreach ($event in 'PreToolUse', 'Stop', 'PostToolUse') {
    foreach ($group in $hooksJson.hooks.$event) {
      foreach ($h in $group.hooks) {
        if (-not (@($h.args) -like '*gate.ps1')) { continue }
        $b = if (@($h.args) -contains '--stop') { 'stop' } elseif (@($h.args) -contains '--file') { 'file' } elseif ($group.matcher -like 'mcp*') { 'mcp' } else { 'shell' }
        $want[$b] = [int]$h.timeout - 15
      }
    }
  }
  $have = @{}
  $m = [regex]::Match((Get-Content -Raw -LiteralPath $gate), '\$Deadlines = @\{ ([^}]*) \}')
  foreach ($pair in ($m.Groups[1].Value -split ';')) { $kv = $pair.Trim() -split ' = '; if ($kv.Count -eq 2) { $have[$kv[0]] = [int]$kv[1] } }
  $wantText = (@($want.Keys | Sort-Object | ForEach-Object { "$_=" + $want[$_] }) -join ' ')
  $haveText = (@($have.Keys | Sort-Object | ForEach-Object { "$_=" + $have[$_] }) -join ' ')
  if ($wantText -cne $haveText -or $haveText -eq '') { Write-Output "FAIL deadlines in gate.ps1 [$haveText], from hooks.json [$wantText]"; $fail = 1 }
  $env:TMPDIR = $saved.TMP
  $env:WRITING_CONVENTIONS_SHELL_CLASSIFIER = '0'

  # Garbage in place of the hook input is not a reason to block either.
  $cases++
  $ErrorActionPreference = 'Continue'
  $null = 'not json at all {{{' | pwsh -NoProfile -File $gate 2>&1
  if ($LASTEXITCODE -ne 0) { Write-Output 'FAIL garbage input exit'; $fail = 1 }
  $cases++
  $null = 'not json at all {{{' | pwsh -NoProfile -File $gate '--stop' 2>&1
  if ($LASTEXITCODE -ne 0) { Write-Output 'FAIL garbage input on --stop exit'; $fail = 1 }
} finally {
  $env:PATH = $saved.PATH
  $env:OS = $saved.OS
  $env:CLAUDE_CODE_USE_POWERSHELL_TOOL = $saved.TOOL
  $env:WRITING_CONVENTIONS_GATE_MODEL = $saved.MODEL
  $env:GATE_TEST_MARK = $saved.MARK
  $env:WRITING_CONVENTIONS_NESTED = $saved.NEST
  $env:GATE_TEST_VERDICT_FILE = $saved.FILE
  $env:GATE_TEST_CLASS = $saved.CLASS
  $env:CLAUDE_CONFIG_DIR = $saved.CONF
  $env:TMPDIR = $saved.TMP
  $env:CLAUDE_PROJECT_DIR = $saved.PROJ
  $env:WRITING_CONVENTIONS_SHELL_CLASSIFIER = $saved.SHELL
  $env:WRITING_CONVENTIONS_GATE_DEADLINE = $saved.DEAD
  $env:GATE_TEST_KEYS_FILE = $null
  $env:GATE_TEST_SLEEP = $null
  Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail -eq 0) { Write-Output "PASS ($cases cases)" } else { Write-Output 'FAILED'; exit 1 }
