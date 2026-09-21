# To do

- After the next `writing-conventions` update reaches a session: the `mcp__.*` and the `Stop` hook
  entries have never fired through the harness, only through the self-tests and direct calls. Make
  one Jira or browser MCP call and read `~/.claude/writing-conventions/mcp-tools-*.txt`, and put a
  fence tagged `draft` with a planted violation in one reply and check that the turn continues with
  the draft rewritten.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
