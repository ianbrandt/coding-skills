#Requires -Version 5.1
# Print hooks/rules.md as the additionalContext of a hook event, JSON-encoded.
#   pwsh -File rules-context.ps1 SubagentStart
# The PowerShell counterpart of rules-context.sh; one of the two emits, never
# both. rules.md is read as UTF-8 explicitly, because 5.1 otherwise reads a
# BOM-less file through the ANSI codepage and every em dash in it comes back
# wrong. ConvertTo-Json does the escaping, so whatever gets pasted into rules.md
# still leaves a valid JSON string.
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'shell-owner.ps1')
if (-not $PowerShellOwnsHook) { exit 0 }

$eventName = if ($args.Count -ge 1) { [string]$args[0] } else { 'SubagentStart' }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$rules = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'rules.md'), $utf8)
if (-not $rules.EndsWith("`n")) { $rules += "`n" }

$out = '{"hookSpecificOutput":{"hookEventName":' + (ConvertTo-Json $eventName) +
       ',"additionalContext":' + (ConvertTo-Json $rules) + '}}'
$bytes = $utf8.GetBytes($out)
$stdout = [Console]::OpenStandardOutput()
$stdout.Write($bytes, 0, $bytes.Length)
$stdout.Flush()
