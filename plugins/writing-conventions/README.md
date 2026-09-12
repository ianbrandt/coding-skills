# writing-conventions

A [Claude Code](https://claude.ai/code) plugin for how an agent writes. Its main product is a short
set of always-on rules—plain engineering English, no AI tells, replies a cold reader can follow—
injected at the start of every session and every subagent, so they bind without anyone invoking a
skill.

Every rule in that list arrived the same way: a specific draft came back wrong, and the correction
became a rule. `write-for-the-reader` is where a word you flag gets logged into the list. The
`ghostwriting-skills` plugin, which drafts text that ships under your name, routes the general rules
it learns from your edits into the same file when this plugin is installed.

## What loads every session

A `SessionStart` hook injects [`hooks/rules.md`](hooks/rules.md) into every session, including
after `/clear` and compaction. A `SubagentStart` hook injects the same file into every subagent,
since a subagent's report is what a later summary is built from. The file is eight named
anti-patterns, one line and one drafted-to-accepted pair each: inanimate agency, spaced em dashes,
a banned-vocabulary list, epigrams and paired contrasts, narration, sentence order, coinages, and
writing for a reader who has read nothing since their last message. Two standing rules follow: a
rule broken in a draft is swept across the branch, and the user's private circumstances stay out
of public artifacts. It runs about 450 words, so it costs roughly 600 tokens per session and per
subagent, down from about 1,600 words; the reasoning behind each rule, and its edge cases, sit in `write-for-the-reader` §8
and load only when that skill does.

Prohibitions bind everywhere, `SKILL.md` files included, because they are about precision rather
than register. Form rules—bold, redundancy, length, the reader-facing voice—stop at the
agent-facing line, so those files are formatted for whatever a model reads best.

[`hooks/lint.sh`](hooks/lint.sh) runs on both ends of a turn, in bash and awk with no other
dependency. A `Stop` hook runs it with `--record` over the final reply and saves what it finds; a
`UserPromptSubmit` hook runs it with `--emit`, which opens the next turn with those hits and a
one-line reminder, then clears them; a `PostToolUse` hook on `Write` and `Edit` runs `--nudge`,
which asks for a re-read when the file just written is prose or holds comments and test names
(`.md`, `.txt`, `.kt`, `.kts`, `.java`, `.groovy`). The lint itself is
[`hooks/lint.awk`](hooks/lint.awk), a pure filter over text, and
[`hooks/lint-test.sh`](hooks/lint-test.sh) is its self-test.

It flags the mechanically detectable subset of the rules: the banned vocabulary, spaced em dashes,
and an inanimate subject paired with a verb of speech, volition, or cognition. That last set is
deliberately narrow. An earlier version also matched possession verbs (holds, carries, keeps) and
scored about 40% precision on a hand-checked sample, mostly on code mechanics such as a map that
holds a value; the current set trades recall for a hit the model can act on.

The lint never blocks, and that is the whole design. A `Stop` hook cannot patch a reply, so
blocking one buys a corrected answer at the price of re-emitting the entire original, which you
have already read and which stays in the transcript beside it. Carrying the hits into the next turn
costs a few dozen tokens instead, and the flagged reply stands as sent.

Each line of the note ends with the rule that line is about, because a note that only names the
pattern and defers to "the rules loaded at session start" measured no better than sending nothing:
across six two-turn trials per arm, no note left 6 of 6 next replies dirty, the deferring note left
5 of 6 dirty, and the same mechanism with the rule stated inline left 0 of 6 dirty. Literal senses
stay ("a Slack channel", "an array shape"), text inside code fences, backticks, and double quotes is
never matched, and a clean reply clears whatever the previous one left pending. Rules that need
judgment to detect stay where they were, in the model's own review passes; the lint is the floor
under them, and a construction it cannot match mechanically is still a violation.

The hooks run under bash: on macOS and Linux always, and on Windows when Git for Windows is
installed, which is also what gives Claude Code its Bash tool there. On a native Windows install
without Git Bash, Claude Code runs hooks in PowerShell, and these three will fail quietly; the
session-start rules still load, since that hook is a plain `cat`.

## The gate at publication

The census behind this plugin found that 101 of 107 corrections landed on text that ships: PR
bodies, comments, issue bodies, commit messages, docs. A lint over chat never sees those, so a
`PreToolUse` hook watches the commands that publish them: `git commit`, `gh pr create`, `gh pr
edit`, `gh pr comment`, `gh pr review`, `gh issue create`, `gh issue comment`, and `gh release
create`. It is a prompt-type hook, so a small model reads the command, pulls out the commit message
or the title and body, and checks that text against the four prohibitions: inanimate agency,
spaced em dashes, the banned words, and epigrams. It never judges form or length. A violation it
can quote comes back as the tool's error, with the sentence and a plain rewrite, and the session
fixes the text and runs the command again; anything else, including a message read from a file,
is allowed through. The cost is one small-model call per gated command, a few times a session,
and a few seconds of latency on each.

Nothing else is gated. A `git push` is not read, because a branch name is chosen long before it,
and a `Write` or `Edit` is nudged rather than blocked, because a file is cheap to fix after the
fact and a blocked edit stops the turn.

Adding a word to the banned list is a plugin release rather than a local edit: an installed session
reads a version-keyed cache, so the plugin's `version` in `.claude-plugin/marketplace.json` has to
bump in the same commit or the session keeps serving the old list.

## Measuring it

[`evals/`](evals/) is a `claude plugin eval` suite of twelve drafting tasks built from the
corrections that motivated this plugin: commit messages, PR bodies, an issue body, a maintainer
comment, a README paragraph, KDoc, a changelog entry, Spock method names, a code comment, and a
status reply. Each prompt states the facts the way a user would, without the rules, and each case
carries three free regex graders (spaced dashes, banned words, a narrow personification pattern),
a judge-model grader for personification, and where the genre has a cap, a judge grader for form.
Run it from the plugin directory:

```bash
claude plugin eval . --runs 2 --no-publish
```

The default two-arm run scores the same prompts with and without the plugin loaded and reports
the difference. Every run costs a fraction of a dollar in judge and agent calls, so the suite is
for a change to the rules file or the hooks, not for every commit. Results land under
`evals/results/`, which is ignored.

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
