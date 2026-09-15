# To do

- Needs PowerShell 7, on Windows and off it: run
  `pwsh -File plugins/writing-conventions/hooks/lint-test.ps1`. The self-test's `$env:OS` fix and
  the `git --exec-path` lookup in `shell-owner.ps1` landed code-read only.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
