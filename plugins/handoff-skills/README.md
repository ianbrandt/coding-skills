# handoff-skills

A [Claude Code](https://claude.ai/code) plugin for sessions you do not read end to
end. It stops the agent before decisions you cannot undo, and it makes every
summary readable cold.

By the time a session wraps, the agent has coined its own terms, made a dozen small
calls you never saw, and written a summary that assumes you read all of it.

## What it does

**Stops for the calls you cannot take back.** Wire contracts, public APIs, data
schemas, permanent branch and PR names, text publishing under your name, and any
decision later work will copy. The test is whether a decision can be undone cheaply,
not how hard it was, so a hard problem with a cheap revert gets solved without
asking. The stop arrives as an interactive picker with two to four options, each
stating what it costs as well as what it buys.

**Does not stop for anything else.** Routine judgment calls, anything `git log` can
answer, and "should I proceed?" after you already said what to do are decided
without you. Interruptions you did not need make you read the next one less
carefully.

**Writes for a cold reader.** No back-references into the transcript, no term coined
three tool calls ago, plain North-American engineering English. Outcome first, then
what is left.

## How it is wired

A `SessionStart` hook injects the always-on half—the register rules and the
escalation trigger—into every session, including after `/clear` and compaction. A
`SubagentStart` hook does the same for subagents, whose reports are what a summary
gets built from. The `handoff` skill holds the rest: the full trigger and
anti-trigger lists, the tradeoff-table format, and the summary template.

The banned-word list lives in `hooks/rules.md` alongside the rules, so it ships with
the plugin rather than sitting in your global `CLAUDE.md`. The skill maintains it: a
word you flag gets added there with the plain alternative that replaces it. That
makes each new word a plugin release, since an installed session reads a
version-keyed cache and will otherwise keep serving the old list.
