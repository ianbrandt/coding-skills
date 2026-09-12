---
max_turns: 3
tags: [commit, style]
runs: 2
---

Write a commit message for this fix. Reply with the message only.

Bug: when a plugin is declared through a version catalog alias with a strictly bound, the bound was attributed in the report to the plugins block declaration, so the wrong source was printed. The fix reads the bound from the catalog entry and prints the catalog file as the source. A regression spec covers the alias case.
