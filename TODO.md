# To do

- `lint.ps1` takes 8 to 10 seconds on a 40,000-line reply, against the Stop hook's 10-second
  timeout, so the PowerShell path can still be cut off on a reply that long. What is left is
  per-sentence PowerShell in `Invoke-Lint`, where the intermediate list and the array literal per
  hit cost about 1.4 seconds between them. `lint-test.ps1` has no budget case for this, and one
  would be flaky until that cost comes down.
- After the next `writing-conventions` update reaches a session: the `mcp__.*` and the `Stop` hook
  entries have never fired through the harness, only through the self-tests and direct calls. Make
  one Jira or browser MCP call and read `~/.claude/writing-conventions/mcp-tools-*.txt`, and put a
  fence tagged `draft` with a planted violation in one reply and check that the turn continues with
  the draft rewritten.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
