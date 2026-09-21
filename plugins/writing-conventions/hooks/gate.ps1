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
$cmd = [string]$json.tool_input.command

# Matching the command text here rather than through a hook `if` pattern covers
# `git -C <path> commit`, which no `PowerShell(git commit *)` rule matches, and
# keeps one copy of the prompt instead of one per subcommand per tool.
if ($cmd -notmatch 'git commit|git -C.*commit|gh pr |gh issue |gh release ') { exit 0 }
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { exit 0 }

$model = if ($env:WRITING_CONVENTIONS_GATE_MODEL) { $env:WRITING_CONVENTIONS_GATE_MODEL } else { 'sonnet' }
$prompt = Join-Path $PSScriptRoot 'gate-prompt.md'
$rules = Join-Path $PSScriptRoot 'rules.md'
$verdict = ''
$env:WRITING_CONVENTIONS_NESTED = '1'
try {
  foreach ($mode in '--safe-mode', '--bare') {
    $verdict = ($raw | claude -p $mode --tools= --model $model --system-prompt-file $prompt --append-system-prompt-file $rules 2>$null | Out-String)
    if ($LASTEXITCODE -eq 0) { break }
  }
} catch { exit 0 } finally { $env:WRITING_CONVENTIONS_NESTED = $null }
if ($LASTEXITCODE -ne 0) { exit 0 }

# Get-VerifiedFinding keeps the findings that quote the command. A reply
# in any other form is a failure path, so it lets the command through as well.
. (Join-Path $PSScriptRoot 'verdict.ps1')
$findings = @(Get-VerifiedFinding $verdict @($cmd))
if ($findings.Count -eq 0) { exit 0 }
[Console]::Error.WriteLine(($findings -join "`n") + "`nRewrite the quoted text and run the command again.")
exit 2
