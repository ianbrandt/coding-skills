#Requires -Version 5.1
# Sets $PowerShellOwnsHook for lint.ps1 and rules-context.ps1, which exit 0 with
# no output when it is false. The mirror of this test is in lint.sh and
# rules-context.sh, so exactly one of each pair emits.
#
# PowerShell takes the hook on Windows when the PowerShell tool is the configured
# shell (CLAUDE_CODE_USE_POWERSHELL_TOOL=1, which reaches a hook process through
# the inherited environment), or when there is no Git Bash to run the bash script.
#
# Git Bash's presence is read off the git install rather than from a PATH lookup
# for bash, for two reasons. Git for Windows puts git.exe on the PATH through its
# cmd\ directory and leaves bash.exe in bin\, which is not on the PATH at all. And
# `bash` on the PATH is WSL, under at least two names (System32\bash.exe and the
# WindowsApps execution alias); WSL cannot run a hook against a Windows path, so
# it is not the bash these hooks mean.
#
# ponytail: git.exe off the PATH with Git Bash installed and the switch unset
# reads as "no bash", and both scripts then emit. Probe the default install paths
# if that ever shows up.
$ErrorActionPreference = 'Stop'

$haveGitBash = $false
$gitExe = (Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if ($gitExe) {
  $gitRoot = Split-Path (Split-Path $gitExe -Parent) -Parent
  foreach ($rel in 'bin\bash.exe', 'usr\bin\bash.exe') {
    if (Test-Path -LiteralPath (Join-Path $gitRoot $rel)) { $haveGitBash = $true; break }
  }
}

$PowerShellOwnsHook = ($env:OS -eq 'Windows_NT') -and
                      (($env:CLAUDE_CODE_USE_POWERSHELL_TOOL -eq '1') -or (-not $haveGitBash))
