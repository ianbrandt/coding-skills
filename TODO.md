# To do

- Needs PowerShell 7, on Windows and off it: run
  `pwsh -File plugins/writing-conventions/hooks/lint-test.ps1`. The self-test's `$env:OS` fix and
  the `git --exec-path` lookup in `shell-owner.ps1` landed code-read only.
- Needs a Claude Code session with the plugin installed: probe whether a prompt hook's `if` accepts
  an array of permission rules. If it does, the eight identical handlers in
  `plugins/writing-conventions/hooks/hooks.json` collapse to four or one.
- Needs a Claude Code session with the plugin installed: run `cd "$X" && git status` through the
  Bash tool and count the "Checking the text for AI tells..." status lines. Eight means a `$VAR`
  command fires the four `PowerShell(...)` handlers too.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
