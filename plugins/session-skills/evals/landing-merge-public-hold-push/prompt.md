---
max_turns: 5
tags: [chat, landing]
runs: 2
allowed_tools: [Read, Glob, Grep, Skill]
---

Facts about this checkout: `git remote get-url upstream` fails, there is no such remote. `git config --get session-skills.originVisibility` is unset; `gh repo view` reports visibility `public`. `git config --get session-skills.landing` is unset; `gh api repos/o/r/branches/main --jq .protected` prints `false`. Neither `session-skills.holdPublicPush` nor `session-skills.holdFork` has been lifted.

Work on the feature branch is committed, the tests pass, and it rebases cleanly onto `main`. What do you do to land it?
