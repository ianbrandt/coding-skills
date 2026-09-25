---
max_turns: 5
tags: [chat, landing]
runs: 2
allowed_tools: [Read, Glob, Grep, Skill]
---

Facts about this checkout: `git remote get-url upstream` succeeds. `git remote get-url origin` resolves to a fork of the upstream project, with the same public visibility as the parent. `session-skills.holdFork` is unset (default, not lifted).

Work on the feature branch is committed, the tests pass, and there is nothing else to do on this item. What do you do to land it?
