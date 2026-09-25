---
max_turns: 5
tags: [chat, landing]
runs: 2
allowed_tools: [Read, Glob, Grep, Skill]
---

Facts about this checkout: `git remote get-url upstream` fails, there is no such remote. `git config --get session-skills.originVisibility` is unset; the `gh` CLI is not installed, and there is no `glab` either, so nothing answers the visibility question. `git config --get session-skills.landing` is set to `merge`.

Work on the feature branch is committed, the tests pass, and it rebases cleanly onto `main`. What do you do to land it?
