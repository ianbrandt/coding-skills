# communication-skills

A [Claude Code](https://claude.ai/code) plugin for how an agent writes. Its main product is a short
set of always-on rules—plain engineering English, no AI tells, replies a cold reader can follow—
injected at the start of every session and every subagent, so they bind without anyone invoking a
skill.

Every rule in that list arrived the same way: a specific draft came back wrong, and the correction
became a rule. The `ghostwrite` skill is where that loop runs—draft, hand over, classify the user's
edit, route the resulting rule to the file it belongs in. Keeping the loop running is the second
thing this plugin is for.

Writing in either direction can turn into a decision you cannot take back, so `ask-when-needed`
stops and asks instead of guessing.

## What loads every session

A `SessionStart` hook injects [`hooks/rules.md`](hooks/rules.md) into every session, including
after `/clear` and compaction. A `SubagentStart` hook injects the same file into every subagent,
since a subagent's report is what a later summary is built from. The file contains four kinds of
always-on rule:

- **Register.** A banned-vocabulary list ("load-bearing", "vacuous", "shape" as a noun, "owed",
  coinages built by bolting a prefix onto a verb), plus three constructions to avoid: inanimate
  agency, epigrams and rhetorical antithesis, and spaced em dashes.
- **Write for the reader.** Assume the reader has read nothing since their last message. No
  back-references into the transcript, lead with the outcome, link a file instead of pasting it,
  cut what the reader can already see.
- **Escalation.** The short form of `ask-when-needed`.
- **Scope.** Which of the above bind agent-facing files and which do not. Prohibitions bind
  everywhere, `SKILL.md` files included, because they are about precision rather than register.
  Form rules—bold, redundancy, length, the reader-facing voice—stop at the agent-facing line, so
  those files are formatted for whatever a model reads best.

Adding a word to the banned list is a plugin release rather than a local edit: an installed session
reads a version-keyed cache, so the plugin's `version` in `.claude-plugin/marketplace.json` has to
bump in the same commit or the session keeps serving the old list.

## Skills

### `ghostwrite`

The correction loop, and the drafting protocol it runs inside. Drafts text that ships under your
name—issues, PRs, comments, commit messages, docs, code comments—from a voice spec built out of
your own hand-written samples, then hands the draft over for your explicit go rather than posting
it. Once you edit it, the skill diffs your version against its own and classifies each change: a
rule the spec never covered earns a new entry, and a rule the spec already covered that the draft
broke anyway is recorded as a procedure failure and earns nothing.

Each new rule is then routed by audience. A rule general enough to bind every reply goes into
`hooks/rules.md`, where it becomes part of the always-on set above and ships to everyone who
installs the plugin. A rule about the form or length of one genre stays in your private voice spec,
which is where the part of your writing that does not generalize belongs: how long your PR bodies
run, how you hedge, whether your code comments default to zero.

Runs a bootstrap interview when you have no spec yet, and says what it could not derive rather than
inventing it.

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

The escalation protocol. Stops before a decision that is hard to reverse: a wire contract or public
API, a data schema or file format, a branch or PR name that becomes permanent, text publishing
under your name, or a call later work will build on. Everything else it decides on its own and
keeps moving, including "should I proceed?" once you have already said what to do. A stop arrives
as an `AskUserQuestion` with two to four options, each naming what it costs as well as what it
buys. A subagent with no one to ask puts the decision and its options in its report instead of
settling it silently.

### `share-ghostwriting-spec`

Exports your voice spec as an anonymized seed a teammate can bootstrap from: keeps the per-genre
caps and procedure, drops the delta log and corpus, scrubs names and URLs and quoted drafts, and
shows you the full export before anything ships anywhere shared.

## Your voice data never enters this repo

`voice-spec.md` and the `corpus/` of hand-written samples it is built from live at
`$GHOSTWRITING_DIR`, defaulting to `~/.claude/ghostwriting/`—a path that can itself be a symlink
into a private repo. Nothing about your voice is written into this plugin or this repo.
`share-ghostwriting-spec` exists for the one case where something does leave your machine: it
hands a teammate an anonymized seed to bootstrap their own spec from, not a copy of yours.
