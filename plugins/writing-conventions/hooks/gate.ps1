#Requires -Version 5.1
# Publication gate for a Windows install where the PowerShell tool is the shell.
# gate.sh is the same gate; gate-prompt.md is the one copy of the check itself.
#
# The check runs as one nested `claude -p --bare` call, with gate-prompt.md as the
# system prompt and the hook input as the message. `--bare` skips hooks, plugins,
# LSP, and CLAUDE.md discovery, which keeps the call to about 2k tokens and a few
# seconds, and rules out this hook firing inside its own nested session.
#
# The model comes from WRITING_CONVENTIONS_GATE_MODEL, or the `sonnet` alias when
# that is unset. Set it in the `env` block of a settings file to any id the
# session's endpoint serves. An alias works because `--model` resolves one through
# ANTHROPIC_DEFAULT_SONNET_MODEL and friends, on a first-party install and on a
# proxy in front of Bedrock or Vertex alike. The `model` field of a prompt-type
# hook resolves nothing: `"model": "sonnet"` there reaches the API verbatim and
# comes back as HTTP 400, which is why the check runs out here instead.
#
# Under `--bare` the nested call authenticates with ANTHROPIC_API_KEY, an
# apiKeyHelper, or a third-party provider's own credentials. A session signed in
# through OAuth alone has none of those, so the call fails and the gate lets the
# command through.
#
# A gate that cannot reach a model must not stop a commit, so every failure path
# exits 0. Only a violation the model can quote exits 2, which blocks the command
# and hands the text back to the session.
#
# ASCII only, so 5.1 cannot mangle it reading a BOM-less file as the ANSI codepage.

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
$verdict = ''
try {
  $verdict = ($raw | claude -p --bare --model $model --system-prompt-file $prompt 2>$null | Out-String)
} catch { exit 0 }
if ($LASTEXITCODE -ne 0) { exit 0 }
$verdict = $verdict.Trim()
if ($verdict -eq '' -or $verdict -match '^CLEAN([^A-Za-z]|$)') { exit 0 }
[Console]::Error.WriteLine($verdict)
exit 2
