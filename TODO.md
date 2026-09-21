# To do

- The 40,000-line record case in `lint-test.sh` takes 17 to 18 seconds on Windows, over both its
  5-second budget and the Stop hook's 10-second timeout, so on a reply that long the record would
  not finish inside the hook. Find out whether Git Bash alone is that slow or whether `jsonstr.awk`
  or `lint.awk` has gone quadratic again, and fix whichever it is. There is no equivalent case in
  `lint-test.ps1`.
- After the next `writing-conventions` update reaches a session: the `mcp__.*` and the `Stop` hook
  entries have never fired through the harness, only through the self-tests and direct calls. Make
  one Jira or browser MCP call and read `~/.claude/writing-conventions/mcp-tools-*.txt`, and put a
  fence tagged `draft` with a planted violation in one reply and check that the turn continues with
  the draft rewritten.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
