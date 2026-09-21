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
# `--safe-mode` has not been checked on an install that signs in through a gateway
# with a key (see TODO.md), so a call that exits non-zero is retried once with
# `--bare`, which is known to work there and prints "Not logged in" on a browser
# sign-in.
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
if ($null -eq $json -or $null -eq $json.tool_input) { exit 0 }
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { exit 0 }
$model = if ($env:WRITING_CONVENTIONS_GATE_MODEL) { $env:WRITING_CONVENTIONS_GATE_MODEL } else { 'sonnet' }

# The reply to one nested call on the hook input, retried once with --bare when the
# first call exits non-zero, or $null when both do.
function Invoke-Model([string]$promptFile, [string]$appendFile) {
  $more = @()
  if ($appendFile) { $more = @('--append-system-prompt-file', (Join-Path $PSScriptRoot $appendFile)) }
  $env:WRITING_CONVENTIONS_NESTED = '1'
  try {
    foreach ($mode in '--safe-mode', '--bare') {
      $reply = ($raw | claude -p $mode --tools= --model $model --system-prompt-file (Join-Path $PSScriptRoot $promptFile) @more 2>$null | Out-String)
      if ($LASTEXITCODE -eq 0) { return $reply }
    }
  } catch { } finally { $env:WRITING_CONVENTIONS_NESTED = $null }
  return $null
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
# Text as the additionalContext of a PostToolUse hook. Written as UTF-8 bytes, because
# 5.1 would encode a pipeline to stdout through the console codepage.
function Write-Context([string]$text) {
  if ($text -eq '') { return }
  $text = [regex]::Replace($text, '[\x01-\x08\x0B-\x1F]', '')
  $esc = $text.Replace('\', '\\').Replace('"', '\"').Replace("`t", '\t').Replace("`n", '\n')
  $bytes = $utf8.GetBytes('{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"' + $esc + '"}}')
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

$tool = [string]$json.tool_name
$fileMode = ($args.Count -gt 0 -and $args[0] -eq '--file')
$unread = ''
if ($fileMode) {
  # A prose file just written. The nested model has no tools, so this script does the
  # reading, and only of the file the tool wrote. The reader is sent the text under
  # review and not the hook input, which for a Write holds the whole file.
  $path = [string]$json.tool_input.file_path
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
    if ($null -eq $reply) { exit 0 }
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
  # Matching the command text here rather than through a hook `if` pattern covers
  # `git -C <path> commit`, which no `PowerShell(git commit *)` rule matches, and
  # keeps one copy of the prompt instead of one per subcommand per tool.
  if ($cmd -notmatch 'git commit|git -C.*commit|gh pr |gh issue |gh release ') { exit 0 }
  $sources = @($cmd)
  $again = 'run the command again'
}
$verdict = Invoke-Model 'gate-prompt.md' 'rules.md'
if ($null -eq $verdict) { exit 0 }

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
if ($findings.Count -eq 0) { exit 0 }
[Console]::Error.WriteLine(($findings -join "`n") + "`nRewrite the quoted text and $again.")
exit 2
