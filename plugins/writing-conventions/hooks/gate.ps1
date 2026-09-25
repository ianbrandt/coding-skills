#Requires -Version 5.1
# Publication gate for a Windows install where the PowerShell tool is the shell.
# gate.sh is the same gate; gate-prompt.md is the one copy of the check itself.
#
# The check runs as one nested `claude -p --safe-mode --tools=` call, with
# gate-prompt.md as the system prompt, rules.md appended to it so that the rules
# are written down once, and the hook input as the message.
# `--safe-mode` starts the call with no CLAUDE.md, skills, plugins, hooks, or MCP
# servers and keeps the normal sign-in, so it works on a browser sign-in as well as
# with a key. With `--tools=` the nested model has no tools, and the default tool
# definitions are 24k of the 26k input tokens of a call without it: with it a call
# is about 2k tokens and a few seconds. It is written as one argument because
# Windows PowerShell drops an empty argument to a native command, and PowerShell 7
# does the same for a .cmd or .bat launcher.
#
# The model comes from WRITING_CONVENTIONS_GATE_MODEL, or the `sonnet` alias when
# that is unset. Set it in the `env` block of a settings file to any id the
# session's endpoint serves. An alias works because `--model` resolves one through
# ANTHROPIC_DEFAULT_SONNET_MODEL and friends, on a first-party install and on a
# proxy in front of Bedrock or Vertex alike. The `model` field of a prompt-type
# hook resolves nothing: `"model": "sonnet"` there reaches the API verbatim and
# comes back as HTTP 400, which is why the check runs out here instead.
#
# A gate that cannot reach a model must not stop a commit, so every failure path
# exits 0. Only a finding with its quote in the command exits 2, which blocks the
# command and hands the text back to the session.
#
# ASCII only, so 5.1 cannot mangle it reading a BOM-less file as the ANSI codepage.

# Managed policy settings still apply under `--safe-mode`, so a copy of this hook
# registered that way runs inside the nested call. The call below sets this marker
# for its child, and nothing here is worth doing for the reader's own session.
if ($env:WRITING_CONVENTIONS_NESTED) { exit 0 }

# One of gate.ps1 and gate.sh runs the check, never both; shell-owner.ps1 is the
# test, and the mirror of it sits in gate.sh.
. (Join-Path $PSScriptRoot 'shell-owner.ps1')
if (-not $PowerShellOwnsHook) { exit 0 }

# The draft-fence scanner, shared with lint.ps1, and the shell command splitter,
# the same as keys.awk.
. (Join-Path $PSScriptRoot 'draft.ps1')
. (Join-Path $PSScriptRoot 'patch.ps1')
. (Join-Path $PSScriptRoot 'keys.ps1')

# Native stderr under 'Stop' is a terminating error on 5.1 once it is redirected,
# and the nested call is allowed to fail.
$ErrorActionPreference = 'Continue'

# 5.1 encodes a pipeline into a native command as ASCII by default and decodes its
# output through the console codepage, so an em dash in a commit message would
# reach the gate as "?" and never be flagged.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = $utf8
[Console]::OutputEncoding = $utf8

$reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8)
try { $raw = $reader.ReadToEnd() } finally { $reader.Dispose() }
$json = $null
if ($raw.Trim() -ne '') { try { $json = ConvertFrom-Json $raw } catch { $json = $null } }
$stopMode = ($args.Count -gt 0 -and $args[0] -eq '--stop')
$fileMode = ($args.Count -gt 0 -and $args[0] -eq '--file')
if ($null -eq $json) { exit 0 }
if (-not $stopMode -and $null -eq $json.tool_input) { exit 0 }
$model = if ($env:WRITING_CONVENTIONS_GATE_MODEL) { $env:WRITING_CONVENTIONS_GATE_MODEL } else { 'sonnet' }

# A command can need a classifier call and then a reader call, so each call gets
# the smaller of 60 seconds and the time left less 10, and none starts with under
# 15. The deadline for each branch is 15 seconds short of its hook timeout in
# hooks.json, so that a killed call, the cleanup, and the notice fit inside it;
# gate-test.ps1 checks the two agree. The self-test sets a short deadline, to
# reach a time limit in seconds.
$Deadlines = @{ shell = 165; mcp = 75; file = 45; stop = 45 }
$clock = [Diagnostics.Stopwatch]::StartNew()
$branch = 'shell'
if ($stopMode) { $branch = 'stop' } elseif ($fileMode) { $branch = 'file' } elseif ([string]$json.tool_name -like 'mcp__*') { $branch = 'mcp' }
$deadline = $Deadlines[$branch]
if ($env:WRITING_CONVENTIONS_GATE_DEADLINE) { $deadline = [int]$env:WRITING_CONVENTIONS_GATE_DEADLINE }

# The reply to one nested call on $message, the hook input by default, or $null
# when the call exits non-zero, was killed at its time limit, or was not started
# for lack of time. With no `claude` on the path there is no call, which is the
# same failure.
function Invoke-Model([string]$promptFile, [string]$appendFile, [string]$message = $raw) {
  $exe = @(Get-Command claude -CommandType Application -ErrorAction SilentlyContinue)
  if ($exe.Count -eq 0) { return $null }
  $more = @()
  if ($appendFile) { $more = @('--append-system-prompt-file', (Join-Path $PSScriptRoot $appendFile)) }
  $argv = @('-p', '--safe-mode', '--tools=', '--model', $model, '--system-prompt-file', (Join-Path $PSScriptRoot $promptFile)) + $more
  $r = Invoke-Claude $exe[0].Source $argv $message
  if ($r.Code -eq 0) { return $r.Out }
  return $null
}

# One call, killed with its process tree at its time limit. The message is written
# to stdin as UTF-8 bytes, because 5.1 would encode it through the console
# codepage, and a .cmd or .bat launcher runs through cmd.exe.
function Invoke-Claude([string]$path, [string[]]$argv, [string]$message) {
  $limit = [Math]::Min(60, $deadline - [int]$clock.Elapsed.TotalSeconds - 10)
  if ($limit -lt 15) { return @{ Code = 1 } }
  $line = (@($argv | ForEach-Object { Format-Argument $_ }) -join ' ')
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  if ($path -match '\.(cmd|bat)$') {
    $psi.FileName = $env:ComSpec
    $psi.Arguments = '/d /s /c "' + (Format-Argument $path) + ' ' + $line + '"'
  } else {
    $psi.FileName = $path
    $psi.Arguments = $line
  }
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = $utf8
  $psi.EnvironmentVariables['WRITING_CONVENTIONS_NESTED'] = '1'
  try { $p = [System.Diagnostics.Process]::Start($psi) } catch { return @{ Code = 1 } }
  $out = $p.StandardOutput.ReadToEndAsync()
  [void]$p.StandardError.ReadToEndAsync()
  try {
    $bytes = $utf8.GetBytes($message)
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.Close()
  } catch { }
  if (-not $p.WaitForExit($limit * 1000)) {
    # Kill(true) takes the children too, and is missing from the .NET that 5.1 runs on.
    try {
      if ($p.GetType().GetMethod('Kill', [type[]]@([bool]))) { $p.Kill($true) }
      elseif ($env:OS -eq 'Windows_NT') { & taskkill.exe /T /F /PID $p.Id 2>$null | Out-Null }
      else { $p.Kill() }
    } catch { }
    return @{ Code = 1 }
  }
  $p.WaitForExit()
  return @{ Code = $p.ExitCode; Out = $out.Result }
}

# One argument quoted as the C runtime splits a command line.
function Format-Argument([string]$a) {
  if ($a -ne '' -and $a -notmatch '[\s"]') { return $a }
  return '"' + (($a -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
}

# The exit for a check that could not run. The user is told the first time in a
# session, through systemMessage, which the user is shown and the model is not. The
# marker is a file named for the session, as the note in lint.ps1 is, and with no
# session id there is no marker, so nothing is said rather than said every time.
function Exit-Off {
  $sid = [regex]::Replace([string]$json.session_id, '[^A-Za-z0-9_-]', '_')
  if ($sid -ne '') {
    $tmp = if ($env:TMPDIR) { $env:TMPDIR } else { [IO.Path]::GetTempPath() }
    $mark = Join-Path $tmp "claude-gate-off-$sid"
    if (-not (Test-Path -LiteralPath $mark)) {
      try {
        [IO.File]::WriteAllText($mark, '')
        [Console]::Out.Write('{"systemMessage":"writing-conventions: model review is off for this session, because the nested claude -p call failed. Commit, PR, MCP, file, and draft text is not being read; the pattern lint on replies still runs."}')
      } catch { }
    }
  }
  exit 0
}

# Every string value under a node of the decoded tool_input, at any depth.
function Get-StringValue($node) {
  if ($node -is [string]) { return ,$node }
  if ($node -is [System.Collections.IEnumerable]) { return @($node | ForEach-Object { Get-StringValue $_ }) }
  if ($node -is [System.Management.Automation.PSCustomObject]) {
    return @($node.PSObject.Properties | ForEach-Object { Get-StringValue $_.Value })
  }
  return @()
}

$CAP = 50000
# Text as the additionalContext of a PostToolUse hook, or of the event given.
# Written as UTF-8 bytes, because 5.1 would encode a pipeline to stdout through
# the console codepage.
function Write-Context([string]$text, [string]$eventName = 'PostToolUse') {
  if ($text -eq '') { return }
  $text = [regex]::Replace($text, '[\x01-\x08\x0B-\x1F]', '')
  $esc = $text.Replace('\', '\\').Replace('"', '\"').Replace("`t", '\t').Replace("`n", '\n')
  $bytes = $utf8.GetBytes('{"hookSpecificOutput":{"hookEventName":"' + $eventName + '","additionalContext":"' + $esc + '"}}')
  $stdout = [Console]::OpenStandardOutput()
  $stdout.Write($bytes, 0, $bytes.Length); $stdout.Flush()
}

# The whole paragraphs, bounded by blank lines, of a file's text that hold $new.
function Get-Excerpt([string]$text, [string]$new) {
  $text = $text.Replace("`r", ''); $new = $new.Replace("`r", '').TrimEnd("`n")
  $bounds = @([regex]::Matches($text, '\n[ \t]*(?=\n)') | ForEach-Object { $_.Index })
  $keep = New-Object System.Collections.Generic.List[object]
  $at = $text.IndexOf($new, [StringComparison]::Ordinal)
  while ($at -ge 0 -and $keep.Count -lt 1000) {
    $end = $at + $new.Length
    $a = 0; foreach ($b in $bounds) { if ($b -lt $at) { $a = $b } else { break } }
    $z = $text.Length; foreach ($b in $bounds) { if ($b -ge $end) { $z = $b; break } }
    if ($keep.Count -gt 0 -and $a -le $keep[$keep.Count - 1][1]) { $keep[$keep.Count - 1][1] = [Math]::Max($z, $keep[$keep.Count - 1][1]) }
    else { $keep.Add(@($a, $z)) }
    $at = $text.IndexOf($new, $end, [StringComparison]::Ordinal)
  }
  return (@($keep | ForEach-Object { $text.Substring($_[0], $_[1] - $_[0]).Trim("`n") }) -join "`n`n")
}

# excerpt.awk -v lines=1, in PowerShell: the paragraphs of $text that hold a line
# equal to one of the non-blank lines in $added.
function Get-LineExcerpt([string]$text, [string[]]$added) {
  $want = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($a in $added) { if ($a.Trim() -ne '') { [void]$want.Add($a.Replace("`r", '')) } }
  $keep = New-Object System.Collections.Generic.List[string]
  foreach ($para in [regex]::Split($text.Replace("`r", ''), '\n[ \t]*\n')) {
    foreach ($l in $para.Split("`n")) { if ($want.Contains($l)) { $keep.Add($para.Trim("`n")); break } }
  }
  return ($keep -join "`n`n")
}

# walk.awk, in PowerShell: READER, SAFE, or ASK followed by one
# "ASK<TAB><scope><TAB><key>" line per key the cache has no answer for. With
# $final a key with no answer reads as CAN_PUBLISH. walk.awk's header has the
# rules.
function Invoke-Walk([string[]]$keys, [string[]]$cache, [string]$scope, [bool]$final) {
  $names = @('', 'NEVER', 'DESCEND', 'PROJECT', 'RUNS_CODE', 'CAN_PUBLISH')
  $rank = New-Object 'System.Collections.Generic.Dictionary[string,int]'
  for ($i = 1; $i -le 5; $i++) { $rank[$names[$i]] = $i }
  $best = New-Object 'System.Collections.Generic.Dictionary[string,int]'
  foreach ($line in $cache) {
    $f = $line.Split("`t")
    if ($f.Count -ne 3 -or ($f[0] -cne '*' -and $f[0] -cne $scope) -or -not $rank.ContainsKey($f[1])) { continue }
    $k = $f[0] + "`t" + $f[2]
    if (-not $best.ContainsKey($k) -or $rank[$f[1]] -gt $best[$k]) { $best[$k] = $rank[$f[1]] }
  }
  $ent = New-Object 'System.Collections.Generic.Dictionary[int,System.Collections.Generic.List[string]]'
  $prose = $false; $nseg = 0
  foreach ($line in $keys) {
    $f = $line.Split("`t")
    if ($f[0] -ceq '0') { if ($f[1] -ceq 'PROSE') { $prose = $true }; continue }
    $s = [int]$f[0]
    if ($s -gt $nseg) { $nseg = $s }
    if (-not $ent.ContainsKey($s)) { $ent[$s] = New-Object 'System.Collections.Generic.List[string]' }
    $ent[$s].Add($f[1])
  }
  function ScopeOf([string]$key, [bool]$task) {
    if ($task) { return $scope }
    if ($key.Split(' ')[0] -match '[/$\\]') { return $scope }
    return '*'
  }
  function ClassOf([string]$key, [bool]$task) {
    $k = (ScopeOf $key $task) + "`t" + $key
    if ($best.ContainsKey($k)) { return $names[$best[$k]] }
    if ($final) { return 'CAN_PUBLISH' }
    return ''
  }
  # Whether e is key and one more word.
  function IsChild([string]$e, [string]$key) {
    return $e.StartsWith($key + ' ', [StringComparison]::Ordinal) -and $e.Substring($key.Length + 1).IndexOf(' ') -lt 0
  }
  function Walk-Node([int]$s, [string]$key, [int]$d, [bool]$task) {
    $c = ClassOf $key $task
    if ($c -eq '') { return 'UNKNOWN' }
    if ($c -ceq 'NEVER') { return 'SAFE' }
    if ($c -ceq 'CAN_PUBLISH' -or $task) { return 'READER' }
    if ($c -ceq 'RUNS_CODE') { if ($prose) { return 'READER' } else { return 'SAFE' } }
    $res = 'SAFE'
    if ($c -ceq 'DESCEND') {
      if ($d -ge 3 -or $ent[$s].Contains($key + ' ?')) { return 'READER' }
      foreach ($e in $ent[$s]) {
        if ($e.StartsWith('+') -or -not (IsChild $e $key) -or $e -ceq ($key + ' ?')) { continue }
        $r = Walk-Node $s $e ($d + 1) $false
        if ($r -ceq 'READER') { return $r }
        if ($r -ceq 'UNKNOWN') { $res = $r }
      }
      return $res
    }
    # PROJECT
    if ($ent[$s].Contains('+' + $key + ' ?') -or $ent[$s].Contains('+' + $key + ' !')) { return 'READER' }
    $kids = 0
    foreach ($e in $ent[$s]) {
      if (-not $e.StartsWith('+') -or -not (IsChild $e.Substring(1) $key)) { continue }
      $kids++
      $r = Walk-Node $s $e.Substring(1) ($d + 1) $true
      if ($r -ceq 'READER') { return $r }
      if ($r -ceq 'UNKNOWN') { $res = $r }
    }
    if ($kids -gt 0) { return $res }
    return 'READER'
  }
  $unknown = New-Object System.Collections.Generic.List[int]
  for ($s = 1; $s -le $nseg; $s++) {
    if (-not $ent.ContainsKey($s)) { continue }
    if ($ent[$s].Contains('READ')) { return 'READER' }
    $r = Walk-Node $s $ent[$s][0] 1 $false
    if ($r -ceq 'READER') { return 'READER' }
    if ($r -ceq 'UNKNOWN') { $unknown.Add($s) }
  }
  # The keys of an unsettled segment with no answer in the cache, below a parent
  # that is itself unanswered or one that reads them, and no task name below a
  # key of three words.
  $asked = New-Object System.Collections.Generic.List[string]
  $done = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($s in $unknown) {
    foreach ($e in $ent[$s]) {
      $task = $e.StartsWith('+')
      $key = $e; if ($task) { $key = $e.Substring(1) }
      if ($key -match ' [?!]$') { continue }
      $sp = $key.LastIndexOf(' ')
      if ($task -and $key.Split(' ').Count -gt 3) { continue }
      if ($sp -ge 0) {
        $pc = ClassOf $key.Substring(0, $sp) $false
        $want = 'DESCEND'; if ($task) { $want = 'PROJECT' }
        if ($pc -ne '' -and $pc -cne $want) { continue }
      }
      if ((ClassOf $key $task) -ne '') { continue }
      $sc = ScopeOf $key $task
      if (-not $done.Add($sc + "`t" + $key)) { continue }
      $asked.Add("ASK`t$sc`t$key")
    }
  }
  if ($asked.Count -eq 0) { return 'SAFE' }
  return (@('ASK') + $asked.ToArray())
}

# Return when the command in $cmd goes to the reader, and exit 0 when it does not:
# gate.sh's shellclass, which has the reasons. keys.ps1 splits the command, and the
# cache is named for a hash of classify-command.md, as the MCP cache is.
function Test-ShellCommand {
  $mode = 'bash'; if ($tool -ceq 'PowerShell') { $mode = 'pwsh' }
  $keys = @(@(Get-CommandKey $cmd $mode) -join "`n" -split "`n" | Where-Object { $_ -ne '' })
  $proj = $env:CLAUDE_PROJECT_DIR
  if (-not $proj) { $proj = [string]$json.cwd }
  if (-not $proj) { $proj = '/' }
  $base = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
  $dir = Join-Path $base 'writing-conventions'
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot 'classify-command.md')).Hash.Substring(0, 10).ToLower()
  $cache = Join-Path $dir "shell-commands-$hash.txt"
  $known = @()
  if (Test-Path -LiteralPath $cache) { $known = @([IO.File]::ReadAllLines($cache, $utf8)) }
  $walk = @(Invoke-Walk $keys $known $proj $false)
  if ($walk[0] -ceq 'READER') { return }
  if ($walk[0] -ceq 'SAFE') { exit 0 }
  $want = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]'
  foreach ($a in $walk[1..($walk.Count - 1)]) {
    $f = $a.Split("`t")
    if (-not $want.ContainsKey($f[2])) { $want[$f[2]] = New-Object System.Collections.Generic.List[string] }
    $want[$f[2]].Add($f[1])
  }
  $reply = Invoke-Model 'classify-command.md' '' ($cmd + "`n`n" + (@($want.Keys) -join "`n"))
  if ($null -eq $reply) { Exit-Off }
  $answers = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($reply -split "`n")) {
    $m = [regex]::Match($line, '^(.*?)[ \t]+(NEVER|CAN_PUBLISH|DESCEND|PROJECT|RUNS_CODE)\r?$')
    if (-not $m.Success -or -not $want.ContainsKey($m.Groups[1].Value)) { continue }
    foreach ($sc in $want[$m.Groups[1].Value]) { $answers.Add($sc + "`t" + $m.Groups[2].Value + "`t" + $m.Groups[1].Value) }
    [void]$want.Remove($m.Groups[1].Value)
  }
  if ($answers.Count -gt 0) {
    try {
      [void](New-Item -ItemType Directory -Force -Path $dir)
      [IO.File]::AppendAllText($cache, (($answers -join "`n") + "`n"), $utf8)
    } catch { }
  }
  $walk = @(Invoke-Walk $keys ($known + $answers.ToArray()) $proj $true)
  if ($walk[0] -ceq 'SAFE') { exit 0 }
}

# Get-Bodies: gate.sh's bodies, in PowerShell. Returns @{ Unread; Texts; Names },
# one entry of Texts/Names per body file read, in order, and one line of Unread
# per file that was not. keys.ps1 finds the files the command in $cmd passes a
# commit, PR, issue, or release body in, from the flags written down there, and
# the reader never chooses one. A file is read only when the text on disk is the
# text the command will publish, as far as a script can tell: a literal path
# that no other word of the command names, since a command that writes the file
# first publishes other text; relative to the directory the command starts in,
# with no cd and no git -C; a readable regular file, not a link, in the project
# or a temporary directory; and at most 1 MB with no NUL in its first 8 KB. Up to 4
# files are read, with $CAP characters in all.
#
# A drive prefix such as C:\ counts as a path being absolute, alongside a
# leading "/" or "\", and the literal-path check allows "\" as well as "/",
# since a command reaching this script may be Windows-style. A link is found
# through its ReparsePoint attribute rather than by resolving the directory
# chain the way gate.sh's `pwd -P` does.
function Get-Bodies([string]$cmdText) {
  $base = [string]$json.cwd
  if ($base -eq '') { $base = (Get-Location).Path }
  $mode = 'bash'; if ($tool -ceq 'PowerShell') { $mode = 'pwsh' }
  $files = @(Get-CommandKey $cmdText $mode -Files | Where-Object { $_ -ne '' })
  # A "\" is a shell escape to the splitter, so an unquoted Windows path arrives
  # with its separators eaten. Every drive-prefixed word of the command is keyed
  # by that stripped form, and an operand matching one of the keys is put back to
  # what the command wrote, so the file is found and named as written.
  $winPaths = @{}
  foreach ($w in [regex]::Matches($cmdText, '[A-Za-z]:\\[^\s"'']*')) { $winPaths[($w.Value -replace '\\', '')] = $w.Value }
  $roots = New-Object System.Collections.Generic.List[string]
  $roots.Add($(if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $base }))
  foreach ($r in $env:TEMP, $env:TMPDIR, [IO.Path]::GetTempPath()) { if ($r) { $roots.Add($r) } }
  if (Test-Path -LiteralPath '/tmp') { $roots.Add('/tmp') }
  $rootFull = @($roots | ForEach-Object { try { [IO.Path]::GetFullPath($_).TrimEnd('/', '\') } catch { $null } } | Where-Object { $_ })

  $unread = New-Object System.Collections.Generic.List[string]
  $texts = New-Object System.Collections.Generic.List[string]
  $names = New-Object System.Collections.Generic.List[string]
  $n = 0; $total = 0
  foreach ($line in $files) {
    $tab = $line.IndexOf("`t")
    $moved = $line.Substring(0, $tab)
    $op = $line.Substring($tab + 1)
    if ($winPaths.ContainsKey($op)) { $op = $winPaths[$op] }
    $why = ''
    $path = ''
    if ($op -eq '' -or $op -cnotmatch '^[A-Za-z0-9._/+@,:=\\-]+$') {
      $why = 'it is not a literal path'
    } elseif ($op.StartsWith('/') -or $op.StartsWith('\') -or $op -cmatch '^[A-Za-z]:\\') {
      $path = $op
    } else {
      $path = Join-Path $base $op
      if ($moved -ceq '1') { $why = 'the command may change directory first' }
    }
    if ($why -eq '') {
      $baseName = $op -replace '^.*[/\\]', ''
      $count = 0; $at = 0
      while (($at = $cmdText.IndexOf($baseName, $at, [StringComparison]::Ordinal)) -ge 0) { $count++; $at += $baseName.Length }
      if ($count -gt 1) { $why = 'the command names it more than once, so it may write the file before reading it' }
    }
    $size = 0
    if ($why -eq '') {
      $item = $null
      try { $item = Get-Item -LiteralPath $path -ErrorAction Stop } catch { }
      $isLink = $null -ne $item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
      $canRead = $false
      if ($null -ne $item -and -not $item.PSIsContainer) {
        try { [IO.File]::OpenRead($item.FullName).Dispose(); $canRead = $true } catch { }
      }
      if ($isLink -or $null -eq $item -or $item.PSIsContainer) {
        $why = 'it is not a regular file'
      } elseif (-not $canRead) {
        $why = 'it cannot be read'
      } else {
        $full = [IO.Path]::GetFullPath($path)
        $inside = $false
        foreach ($r in $rootFull) {
          if ($full -ceq $r -or $full.StartsWith($r + '/', [StringComparison]::Ordinal) -or $full.StartsWith($r + '\', [StringComparison]::Ordinal)) { $inside = $true; break }
        }
        if (-not $inside) {
          $why = 'it is outside the project and the temporary directory'
        } else {
          $size = $item.Length
          if ($size -gt 1048576) { $why = 'it is over 1 MB' }
          else {
            $bytes = [IO.File]::ReadAllBytes($full)
            $headLen = [Math]::Min(8192, $bytes.Length)
            $hasNul = $false
            for ($bi = 0; $bi -lt $headLen; $bi++) { if ($bytes[$bi] -eq 0) { $hasNul = $true; break } }
            if ($hasNul) { $why = 'it is not text' }
            elseif ($n -ge 4 -or ($total + $size) -gt $CAP) { $why = "the gate reads at most 4 body files and $CAP characters" }
          }
        }
      }
    }
    if ($why -ne '') {
      $unread.Add("The body in $op was not read: $why.")
    } else {
      $n++; $total += $size
      $texts.Add([IO.File]::ReadAllText($full, $utf8))
      $names.Add($op)
    }
  }
  return @{ Unread = $unread.ToArray(); Texts = $texts.ToArray(); Names = $names.ToArray() }
}

$tool = [string]$json.tool_name
$unread = ''
$stopState = ''
if ($stopMode) {
  # A reply the session has tagged as a draft for publication. Only the text
  # inside a `draft` fence is reviewed, so nothing else in the reply is judged by
  # the model, and a reply with no such fence costs one scan and no call at all.
  # An untagged draft is read by the reply lint alone.
  if ($env:WRITING_CONVENTIONS_STOP_READER -eq '0') { exit 0 }
  $found = Get-DraftFence ([string]$json.last_assistant_message)
  if ($found.Drafts.Count -eq 0) { exit 0 }
  # Blocking a reply is bounded per turn, counted in a file named for the
  # prompt_id, which is the same on every Stop call of one turn. Codex sends
  # turn_id instead. With neither, nothing can be counted, so nothing is blocked
  # and a call would buy nothing.
  $promptId = [regex]::Replace([string]$json.prompt_id, '[^A-Za-z0-9_-]', '_')
  if ($promptId -eq '') { $promptId = [regex]::Replace([string]$json.turn_id, '[^A-Za-z0-9_-]', '_') }
  if ($promptId -eq '') { exit 0 }
  $tmpdir = if ($env:TMPDIR) { $env:TMPDIR } else { [IO.Path]::GetTempPath() }
  $stopState = Join-Path $tmpdir "claude-gate-stop-$promptId"
  # The reader is sent the drafts and nothing else. Each one stays a source of
  # its own, so no finding can quote across two of them. The cap is taken off the
  # drafts before either use, because a quote from past it was never reviewed;
  # gate.sh cuts the one file that the message and the sources both come from.
  $kept = New-Object System.Collections.Generic.List[string]
  $room = $CAP
  foreach ($d in $found.Drafts) {
    if ($room -le 0) { break }
    if ($d.Length -gt $room) { $kept.Add($d.Substring(0, $room)); $room = 0 }
    else { $kept.Add($d); $room -= $d.Length }
  }
  $raw = ($kept -join "`n")
  $sources = @($kept)
  $again = 'emit the corrected draft'
} elseif ($fileMode) {
  # A prose file just written. The nested model has no tools, so this script does the
  # reading, and only of the file the tool wrote. The reader is sent the text under
  # review and not the hook input, which for a Write holds the whole file.
  $path = [string]$json.tool_input.file_path
  if ($tool -ceq 'apply_patch') {
    # Codex writes files with one patch, which can add, update, or move several.
    # Each prose file in it is reviewed as the paragraphs that hold the lines the
    # patch added, read from the file as patched.
    $notes = New-Object System.Collections.Generic.List[string]
    $parts = New-Object System.Collections.Generic.List[string]
    $sources = @(); $paths = @()
    foreach ($f in (Get-PatchFile ([string]$json.tool_input.command) ([string]$json.cwd))) {
      if (-not [regex]::IsMatch($f.Path.ToLowerInvariant(), '\.(md|markdown|txt|adoc|rst)$')) { continue }
      if (($f.New -join '').Trim() -eq '') { $notes.Add("Not reviewed: this edit to $($f.Path) only deleted text."); continue }
      $text = ''
      try {
        if ((Get-Item -LiteralPath $f.Path -ErrorAction Stop).Length -le 1048576) { $text = Get-LineExcerpt ([IO.File]::ReadAllText($f.Path, $utf8)) $f.New }
      } catch { }
      if ($text -eq '') {
        $text = $f.New -join "`n"
        $notes.Add("Only the new text was reviewed, not the sentences around it: $($f.Path) is over 1 MB or could not be read.")
      }
      $parts.Add("File: $($f.Path)`n`n$text"); $sources += $text; $paths += $f.Path
    }
    if ($paths.Count -eq 0) { if ($notes.Count -gt 0) { Write-Context ($notes -join "`n") }; exit 0 }
    $raw = $parts -join "`n`n"
    if ($raw.Length -gt $CAP) { $raw = $raw.Substring(0, $CAP); $notes.Add("Only the first $CAP characters of the text were reviewed.") }
    $path = $paths -join ', '
    $unread = $notes -join "`n"
  } else {
  if ($tool -cne 'Write' -and $tool -cne 'Edit') { exit 0 }
  if (-not [regex]::IsMatch($path.ToLowerInvariant(), '\.(md|markdown|txt|adoc|rst)$')) { exit 0 }
  if ($tool -ceq 'Write') { $text = [string]$json.tool_input.content }
  else {
    $new = [string]$json.tool_input.new_string
    if ($new.Trim() -eq '') { Write-Context "Not reviewed: this edit to $path only deleted text."; exit 0 }
    $text = ''
    try {
      if ((Get-Item -LiteralPath $path -ErrorAction Stop).Length -le 1048576) { $text = Get-Excerpt ([IO.File]::ReadAllText($path, $utf8)) $new }
      else { $unread = "Only the new text was reviewed, not the sentences around it: $path is over 1 MB or could not be read." }
    } catch { $unread = "Only the new text was reviewed, not the sentences around it: $path is over 1 MB or could not be read." }
    if ($text -eq '') { $text = $new }
  }
  if ($text.Length -gt $CAP) {
    $text = $text.Substring(0, $CAP)
    $unread = "Only the first $CAP characters of the text were reviewed."
  }
  $raw = "File: $path`n`n$text"
  $sources = @($text)
  }
} elseif ($tool -like 'mcp__*') {
  # Whether an MCP tool can publish is asked of a model once per tool and kept in a
  # per-user file, one line per answer, so no server or tool name is written here.
  # The file is outside the plugin's directory, which is per version, and is named
  # for a hash of the classifier's prompt, so a changed prompt starts a new file.
  # The user can read and edit it. For one tool a CAN_PUBLISH line wins over a NEVER
  # line, and a line in any other form is ignored. gate.sh names its file with
  # cksum, so the two scripts on one machine each ask once.
  $base = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
  $dir = Join-Path $base 'writing-conventions'
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot 'classify-prompt.md')).Hash.Substring(0, 10).ToLower()
  $cache = Join-Path $dir "mcp-tools-$hash.txt"
  $class = ''
  if (Test-Path -LiteralPath $cache) {
    foreach ($line in Get-Content -LiteralPath $cache) {
      $f = @($line -split '\s+' | Where-Object { $_ -ne '' })
      if ($f.Count -ne 2 -or $f[0] -cne $tool) { continue }
      if ($f[1] -ceq 'CAN_PUBLISH') { $class = 'CAN_PUBLISH' }
      elseif ($f[1] -ceq 'NEVER' -and $class -eq '') { $class = 'NEVER' }
    }
  }
  if ($class -eq '') {
    $reply = Invoke-Model 'classify-prompt.md' ''
    if ($null -eq $reply) { Exit-Off }
    $class = [string](@($reply -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_.Trim() -ne '' })[0])
    # A reply in any other form is doubt, which reads as CAN_PUBLISH and is not kept.
    if ($class -ceq 'NEVER' -or $class -ceq 'CAN_PUBLISH') {
      try {
        [void](New-Item -ItemType Directory -Force -Path $dir)
        [IO.File]::AppendAllText($cache, "$tool $class`n", $utf8)
      } catch { }
    } else { $class = 'CAN_PUBLISH' }
  }
  if ($class -cne 'CAN_PUBLISH') { exit 0 }
  # The reader is sent the whole input, structure included, and a finding has to
  # quote one of the string values in tool_input.
  $sources = @(Get-StringValue $json.tool_input)
  $again = 'make the call again'
} else {
  $cmd = [string]$json.tool_input.command
  # Four command families always reach the reader, whatever is cached, so a wrong
  # NEVER from the classifier can never lose them. Matching the command text here
  # rather than through a hook `if` pattern covers `git -C <path> commit`, which no
  # `PowerShell(git commit *)` rule matches.
  if ($cmd -notmatch 'git commit|git -C.*commit|gh pr |gh issue |gh release ') {
    if ($env:WRITING_CONVENTIONS_SHELL_CLASSIFIER -eq '0') { exit 0 }
    Test-ShellCommand
  }
  $bodies = Get-Bodies $cmd
  $unread = ($bodies.Unread -join "`n")
  if ($bodies.Texts.Count -gt 0) {
    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add($raw)
    for ($bi = 0; $bi -lt $bodies.Texts.Count; $bi++) { [void]$parts.Add('File: ' + $bodies.Names[$bi] + "`n`n" + $bodies.Texts[$bi]) }
    $raw = ($parts -join "`n`n").TrimEnd("`n")
  }
  $sources = @($cmd) + $bodies.Texts
  $again = 'run the command again'
}
$verdict = Invoke-Model 'gate-prompt.md' 'rules.md'
if ($null -eq $verdict) { Exit-Off }

# Get-VerifiedFinding keeps the findings that quote the command. A reply
# in any other form is a failure path, so it lets the command through as well.
. (Join-Path $PSScriptRoot 'verdict.ps1')
$findings = @(Get-VerifiedFinding $verdict $sources)
if ($fileMode) {
  # A file is cheap to fix after the fact and a blocked edit stops the turn, so this
  # path hands the findings back and blocks nothing.
  $lines = @()
  if ($findings.Count -gt 0) { $lines += $findings; $lines += "Fix the quoted text in $path." }
  if ($unread -ne '') { $lines += $unread }
  Write-Context ($lines -join "`n")
  exit 0
}
if ($findings.Count -eq 0) {
  if ($unread -ne '') { Write-Context $unread 'PreToolUse' }
  exit 0
}
if ($stopState -ne '') {
  # A blocked Stop costs a whole re-emitted reply, so a reader that keeps finding
  # something in each rewrite is stopped after two: the user is told that review
  # is unresolved, through systemMessage, and the reply stands.
  # Anything in the file other than 0 or 1 counts as two, so a file another
  # program wrote cannot be read as room for another block.
  $n = 0
  # A directory at the path is not a count; the write below is what fails on it.
  if (Test-Path -LiteralPath $stopState -PathType Leaf) {
    $n = 2
    try {
      $seen = [IO.File]::ReadAllText($stopState)
      if ($seen -ceq '0') { $n = 0 } elseif ($seen -ceq '1') { $n = 1 }
    } catch { }
  }
  if ($n -ge 2) {
    [Console]::Out.Write('{"systemMessage":"writing-conventions: the draft in this reply still reads as a violation after two rewrites. Review is unresolved and the reply stands."}')
    exit 0
  }
  # A count that cannot be kept is no count at all, and blocking on it would
  # re-emit the reply on every Stop call of the turn: an unwritable temporary
  # directory, a prompt_id too long for a filename, or something else already at
  # the path. So the write is read back, and a failure lets the reply stand.
  $kept = $false
  try {
    [IO.File]::WriteAllText($stopState, [string]($n + 1))
    $kept = ([IO.File]::ReadAllText($stopState) -ceq [string]($n + 1))
  } catch { $kept = $false }
  if (-not $kept) {
    [Console]::Out.Write('{"systemMessage":"writing-conventions: the draft in this reply reads as a violation, and the count that bounds a second look could not be written to ' + $tmpdir + '. Review is unresolved and the reply stands."}')
    exit 0
  }
}
$reason = ($findings -join "`n") + "`nRewrite the quoted text and $again."
if ($unread -ne '') { $reason += "`n$unread" }
[Console]::Error.WriteLine($reason)
exit 2
