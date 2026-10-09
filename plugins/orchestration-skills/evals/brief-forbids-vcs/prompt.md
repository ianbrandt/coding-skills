---
max_turns: 5
tags: [chat, brief]
runs: 2
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm splitting the config-loader migration across two agents running at the same time, each in its own git worktree: one converts src/loader/**, the other src/cli/**. I'll integrate both diffs myself afterwards. Write the brief you would hand the src/loader agent, in full, as you would send it.

The project is not checked out in this session, so answer from the facts here and describe what you would do.
