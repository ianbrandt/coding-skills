# communication-skills

A [Claude Code](https://claude.ai/code) plugin for both directions of talking to you. When the
agent drafts something that ships under your name, it should read like you wrote it. When it
reports back on work you did not watch, you should be able to follow the reply cold. Either one
can turn into a decision you cannot take back, and that is where the plugin stops and asks instead
of guessing. One plugin, two directions, plus the decision to interrupt.

## Skills

### `write-for-the-reader`

Governs what the agent writes to you: chat replies, summaries, wrap-ups. Assumes you have read
nothing since your last message, so no back-reference to "the fix above," no term coined three
tool calls ago, and the file, decision, and outcome named in full every time. Picks the amount of
detail from what you will do next rather than from how much work happened: a routine call gets one
line, a call you might have made differently gets one sentence naming the alternative it rejected.
Links a file with an absolute path instead of pasting its contents, and leaves out what you can
already see for yourself, like a local test-suite pass CI already reports. When you flag a word as
jargon, this skill is what logs it into `hooks/rules.md`.

### `ask-when-needed`

The escalation protocol, split out from what used to be a skill named "handoff." Stops before a
decision that is hard to reverse: a wire contract or public API, a data schema or file format, a
branch or PR name that becomes permanent, text publishing under your name, or a call later work
will build on. Everything else it decides on its own and keeps moving, including "should I
proceed?" once you have already said what to do. A stop arrives as an `AskUserQuestion` with two
to four options, each naming what it costs as well as what it buys. A subagent with no one to ask
puts the decision and its options in its report instead of settling it silently.

### `ghostwrite`

Carried over from the earlier ghostwriting plugin, unchanged. Drafts text that ships under your
name (issues, PRs, comments, commit messages, docs, code comments) from a voice spec built out of
your own hand-written samples: read the spec, draft to its caps, self-review, hand the draft over
for your go, then log the delta once you have edited it. Runs a bootstrap interview when you have
no spec yet, and says what it could not derive rather than inventing it.

### `share-ghostwriting-spec`

Also carried over unchanged. Exports your voice spec as an anonymized seed a teammate can
bootstrap from: keeps the per-genre caps and procedure, drops the delta log and corpus, scrubs
names and URLs and quoted drafts, and shows you the full export before anything ships anywhere
shared.

## How it is wired

A `SessionStart` hook injects `hooks/rules.md` into every session, including after `/clear` and
compaction. A `SubagentStart` hook injects the same file into every subagent, since a subagent's
report is what a summary later gets built from. Both hooks carry the always-on short form; the
four skills above hold the full protocols behind it.

The banned-vocabulary list lives in `hooks/rules.md` rather than in a personal global `CLAUDE.md`,
so it ships with the plugin and travels with anyone who installs it. That also means adding a word
is a plugin release, not a local edit: an installed session reads a version-keyed cache, so the
plugin's `version` in `.claude-plugin/marketplace.json` has to bump in the same commit or the
session keeps serving the old list.

## Your voice data never enters this repo

`voice-spec.md` and the `corpus/` of hand-written samples it is built from live at
`$GHOSTWRITING_DIR`, defaulting to `~/.claude/ghostwriting/`—a path that can itself be a symlink
into a private repo. Nothing about your voice is written into this plugin or this repo.
`share-ghostwriting-spec` exists for the one case where something does leave your machine: it
hands a teammate an anonymized seed to bootstrap their own spec from, not a copy of yours.
