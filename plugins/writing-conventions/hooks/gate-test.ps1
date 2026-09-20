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

$scratch = Join-Path ([IO.Path]::GetTempPath()) ("gateps-" + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)
# The stub is named for the platform running the test: a .bat is not resolved as
# `claude` off Windows, and without this the gate finds the real CLI on the PATH
# and every case that wants the stub reads as "model not called".
$onWindows = $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows
if ($onWindows) {
  $stub = @'
@echo off
>>"%GATE_TEST_MARK%" echo called
if "%GATE_TEST_FAIL%"=="1" exit /b 1
if exist "%GATE_TEST_VERDICT_FILE%" type "%GATE_TEST_VERDICT_FILE%"
'@
  $stubPath = Join-Path $scratch 'claude.bat'
} else {
  $stub = @'
#!/usr/bin/env bash
printf 'called\n' >> "$GATE_TEST_MARK"
[ "$GATE_TEST_FAIL" = 1 ] && exit 1
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
  FILE  = $env:GATE_TEST_VERDICT_FILE
}
try {
  # The owner test in shell-owner.ps1 hands the hook to PowerShell only on Windows
  # with the PowerShell tool configured, so the test says so and runs anywhere.
  $env:PATH = $scratch + [IO.Path]::PathSeparator + $env:PATH
  $env:OS = 'Windows_NT'
  $env:CLAUDE_CODE_USE_POWERSHELL_TOOL = '1'
  $env:WRITING_CONVENTIONS_GATE_MODEL = $null
  $env:GATE_TEST_MARK = Join-Path $scratch 'mark'
  # The stub prints this file. A verdict has several lines and double quotes, which
  # a .bat `echo` of an environment variable cannot hold.
  $env:GATE_TEST_VERDICT_FILE = Join-Path $scratch 'verdict'

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
  # Garbage in place of the hook input is not a reason to block either.
  $cases++
  $ErrorActionPreference = 'Continue'
  $null = 'not json at all {{{' | pwsh -NoProfile -File $gate 2>&1
  if ($LASTEXITCODE -ne 0) { Write-Output 'FAIL garbage input exit'; $fail = 1 }
} finally {
  $env:PATH = $saved.PATH
  $env:OS = $saved.OS
  $env:CLAUDE_CODE_USE_POWERSHELL_TOOL = $saved.TOOL
  $env:WRITING_CONVENTIONS_GATE_MODEL = $saved.MODEL
  $env:GATE_TEST_MARK = $saved.MARK
  $env:GATE_TEST_VERDICT_FILE = $saved.FILE
  Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail -eq 0) { Write-Output "PASS ($cases cases)" } else { Write-Output 'FAILED'; exit 1 }
