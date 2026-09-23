# To do

- `lint.ps1` takes 8 to 10 seconds on a 40,000-line reply, against the Stop hook's 10-second
  timeout, so the PowerShell path can still be cut off on a reply that long. What is left is
  per-sentence PowerShell in `Invoke-Lint`, where the intermediate list and the array literal per
  hit cost about 1.4 seconds between them. `lint-test.ps1` has no budget case for this, and one
  would be flaky until that cost comes down.
- The `Stop` gate has never blocked a reply through the harness. On a direct call it does: a planted
  violation inside a `draft` fence came back on 2026-09-23 as two findings and exit 2, through the
  real reader. In a live reply the same day, the planted "the cache says the searxng tools were
  classified" was not flagged by the reader and was caught only by the reply lint, so the live check
  needs a blunter one. The `mcp__.*` entry needs no check: searxng classifications from 2026-09-21
  are in `mcp-tools-*.txt` under `$CLAUDE_CONFIG_DIR/writing-conventions`.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
