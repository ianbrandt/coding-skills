# To do

- `lint.ps1` takes 8 to 10 seconds on a 40,000-line reply, against the Stop hook's 10-second
  timeout, so the PowerShell path can still be cut off on a reply that long. What is left is
  per-sentence PowerShell in `Invoke-Lint`, where the intermediate list and the array literal per
  hit cost about 1.4 seconds between them. `lint-test.ps1` has no budget case for this, and one
  would be flaky until that cost comes down.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
- Needs a Windows machine, for the `session-skills` snippets and their `powershell.md` versions:
  check that `git worktree list --porcelain` prints forward-slash paths that both shells parse,
  that the `SessionStart` `cat` hook loads under Git Bash and under PowerShell with no Git Bash,
  and that the notes link in `work-in-worktree` §3 is a link and not a copy. Git Bash's `ln -s`
  copies unless `MSYS=winsymlinks:nativestrict` is set; the PowerShell junction should need no
  Developer Mode.
