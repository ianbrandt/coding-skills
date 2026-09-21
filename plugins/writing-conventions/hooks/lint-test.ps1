#Requires -Version 5.1
# Self-test for lint.ps1. Run from anywhere:
#   pwsh -File hooks/lint-test.ps1
# The matcher cases come from lint-corpus.tsv, which lint-test.sh reads too, so a
# change to one matcher and not the other fails here or there.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$fail = 0
$cases = 0
$utf8 = New-Object System.Text.UTF8Encoding($false)

$LintPs1LoadOnly = $true
. (Join-Path $here 'lint.ps1')

function Get-Groups([string]$text) {
  $out = Invoke-Lint $text
  if ($out -eq '') { return '' }
  $g = $out -split "`n" | ForEach-Object { ($_ -split "`t")[0] } | Sort-Object -Unique
  return ($g -join ' ')
}

function Test-Case([string]$want, [string]$text) {
  $script:cases++
  $got = Get-Groups $text
  if ($want -eq '-') {
    if ($got -ne '') { Write-Output "FAIL (expected clean): $text  -> $got"; $script:fail = 1 }
  } elseif ((" $got " -notlike "* $want *")) {
    $shown = if ($got -eq '') { 'clean' } else { $got }
    Write-Output "FAIL (expected $want): $text  -> $shown"
    $script:fail = 1
  }
}

# --- the shared corpus ----------------------------------------------------
$corpus = Join-Path $here 'lint-corpus.tsv'
foreach ($line in [IO.File]::ReadAllLines($corpus, $utf8)) {
  if ($line -eq '' -or $line.StartsWith('#')) { continue }
  $parts = $line -split "`t", 2
  if ($parts.Count -ne 2) { Write-Output "FAIL malformed corpus line: $line"; $fail = 1; continue }
  Test-Case $parts[0] ($parts[1] -replace '\\n', "`n")
}

# --- the note -------------------------------------------------------------
$cases++
$note = Invoke-Lint ('A ' + $EM + ' B ' + $EM + ' C, and the report says so.') -AsNote
if ($note -notlike '*spaced em dash x1*' -or $note -notlike ('*never word ' + $EM + ' word*') -or
    $note -notlike '*inanimate agency x1*' -or $note -notlike '*say who the real actor is*') {
  Write-Output "FAIL note: $note"; $fail = 1
}
if ($note -like '*loaded at session start*') { Write-Output 'FAIL note defers to session start'; $fail = 1 }
$cases++
if ((Invoke-Lint 'Plain prose, nothing flagged.' -AsNote) -ne '') { Write-Output 'FAIL clean note not empty'; $fail = 1 }

# --- end to end: record, emit, second emit, clean record clears, nudge ----
# The state files go to a scratch directory so the test never reads or deletes a
# live session's note.
$script = Join-Path $here 'lint.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ("lintps-" + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)
$savedTmp = $env:TMPDIR
$savedTool = $env:CLAUDE_CODE_USE_POWERSHELL_TOOL
$savedOs = $env:OS
$env:TMPDIR = $scratch
# make PowerShell the owner for the run: shell-owner.ps1 wants both the tool
# switch and a Windows OS, and pwsh on macOS or Linux leaves $env:OS unset
$env:CLAUDE_CODE_USE_POWERSHELL_TOOL = '1'
$env:OS = 'Windows_NT'
try {
  function Invoke-Hook([string]$mode, [string]$stdin) {
    return ($stdin | & (Get-Process -Id $PID).Path -NoProfile -File $script $mode | Out-String)
  }

  $cases++
  [void](Invoke-Hook '--record' '{"session_id":"selftest","last_assistant_message":"This shape is vacuous."}')
  $out = Invoke-Hook '--emit' '{"session_id":"selftest"}'
  if ($out -notlike '*banned word x1*' -or $out -notlike '*Style, for this reply*') {
    Write-Output "FAIL emit: $out"; $fail = 1
  }
  $out2 = Invoke-Hook '--emit' '{"session_id":"selftest"}'
  $reminderOnly = Invoke-Hook '--emit' '{"session_id":"x"}'
  if ($out2 -ne $reminderOnly) { Write-Output "FAIL second emit not reminder only: $out2"; $fail = 1 }
  [void](Invoke-Hook '--record' '{"session_id":"selftest","last_assistant_message":"This shape is vacuous."}')
  [void](Invoke-Hook '--record' '{"session_id":"selftest","last_assistant_message":"Plain prose."}')
  $out3 = Invoke-Hook '--emit' '{"session_id":"selftest"}'
  if ($out3 -like '*flagged*') { Write-Output 'FAIL clean record did not clear'; $fail = 1 }

  # Inside the gate's nested reader call nothing is recorded, so a reply written
  # for the reader cannot overwrite this session's note.
  $cases++
  $env:WRITING_CONVENTIONS_NESTED = '1'
  try { [void](Invoke-Hook '--record' '{"session_id":"selftest","last_assistant_message":"This shape is vacuous."}') }
  finally { $env:WRITING_CONVENTIONS_NESTED = $null }
  if ((Invoke-Hook '--emit' '{"session_id":"selftest"}') -like '*flagged*') {
    Write-Output 'FAIL nested record saved a note'; $fail = 1
  }

  $cases++
  $n = Invoke-Hook '--nudge' '{"tool_name":"Write","tool_input":{"file_path":"/tmp/draft.md","content":"x"}}'
  if ($n -notlike '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"You just wrote prose*') {
    Write-Output "FAIL nudge: $n"; $fail = 1
  }
  if ((Invoke-Hook '--nudge' '{"tool_input":{"file_path":"/src/main.py"}}').Trim() -ne '') {
    Write-Output 'FAIL nudge fired on .py'; $fail = 1
  }
  if ((Invoke-Hook '--nudge' '{"tool_input":{"file_path":"/tmp/README.MD"}}').Trim() -eq '') {
    Write-Output 'FAIL nudge skipped README.MD'; $fail = 1
  }

  # no session id: nothing is saved, and nothing another session saved is printed
  $cases++
  [void](Invoke-Hook '--record' '{"last_assistant_message":"This shape is vacuous."}')
  if (@(Get-ChildItem -Path $scratch -File).Count -ne 0) {
    Write-Output 'FAIL record without session id wrote a file'; $fail = 1
  }
  if ((Invoke-Hook '--emit' '{"x":1}') -like '*flagged*') {
    Write-Output 'FAIL emit without session id printed a note'; $fail = 1
  }
  if ((Invoke-Hook '--nudge' 'not json').Trim() -ne '') { Write-Output 'FAIL nudge on garbage'; $fail = 1 }
  [void](Invoke-Hook '--record' 'not json at all {{{')
  if ($LASTEXITCODE -ne 0) { Write-Output 'FAIL garbage record exit'; $fail = 1 }
} finally {
  $env:TMPDIR = $savedTmp
  $env:CLAUDE_CODE_USE_POWERSHELL_TOOL = $savedTool
  $env:OS = $savedOs
  Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail -eq 0) { Write-Output "PASS ($cases cases)" } else { Write-Output 'FAILED'; exit 1 }
