---
name: write-for-the-reader
description: >-
  Govern how a reply, summary, or wrap-up reads for the user: plain language, no
  assumed context, and a level of detail matched to what they will do next.
  Covers altitude (when to show reasoning, when to name a mechanism), linking
  files instead of pasting their contents, cutting what the reader can already
  see, and logging a word the user flags as jargon into this plugin's
  hooks/rules.md. Trigger when writing a summary, a wrap-up, or a status
  message, when a reply is running long or turning abstract, and on "that's
  jargon" / "log that word" / "too much detail". NOT for text publishing under
  the user's name when ghostwrite is installed (then that's ghostwrite), and NOT for deciding when to stop and ask
  (that's ask-when-needed).
---

# Write for the reader—register, context, and altitude

This skill governs writing **to** the user. `ghostwrite`, in the `ghostwriting-skills` plugin,
governs writing **as** the user, for text they sign and post, when that plugin is installed. Without
it, this skill covers that text too. Escalation—when to stop and hand over
a decision—belongs to `ask-when-needed` in the `orchestration-skills` plugin; write none of it here.

This plugin's `hooks/rules.md` loads every session and carries the short form: eight named
anti-patterns with one contrast pair each. This file is the full protocol behind it, and §8 is the
long form of the prohibitions. All of it applies to text a human reads. Agent-facing files—skills,
hook payloads, subagent briefs—follow the prohibitions and are exempt from the form rules, so they
are formatted for whatever a model reads best.

## 1. Assume the reader has read nothing since their last message

The user does not read the transcript. They read your last message, and they read it after a gap
during which they were doing something else.

- **No back-references.** Not "the fix above", not "as noted earlier", not "that file". Name the
  file, the function, and the decision in full, every time, even when you named them two messages
  ago.
- **No term you coined mid-session.** A label you invented to think with ("the guard path", "the
  cold branch") means nothing to someone who was not thinking alongside you. Replace it with the
  concrete thing it stands for.
- **Lead with the outcome**, then what is left. A chronology of what you tried is a record of your
  search, not information the reader can act on.
- **Re-establish the subject at the top of a wrap-up.** One clause naming the repo, branch, or
  feature costs nothing and rescues a reader who has three sessions open.

## 2. Choose the altitude before writing the words

Detail is not a virtue. The right amount is whatever lets the reader do the next thing, and no more.

- **Show reasoning only where the reader could reasonably have chosen differently.** A decision
  with one conventional answer gets one line stating what you did. A decision where you rejected a
  plausible alternative gets one sentence naming the alternative and the fact that ruled it out.
  Reasoning shown for a call nobody would question buries the calls that do need it.
- **Name a mechanism when the reader will touch it; describe the outcome when they will not.**
  "Cached the fetch with `@lru_cache(maxsize=1000)`" when they may tune the size; "responses are
  cached now" when they will not. A named mechanism in code they never open is trivia. An outcome
  given where they need the knob forces a second question.
- **Distinguish an explanation the reader asked for from prose defending an unchallenged choice.**
  If the last user message asked "why" or "how", answer in full—that is the deliverable. If nobody
  questioned the choice and the paragraph exists to justify it, delete the paragraph. Prose
  defending a simplification is the complexity coming back in another form.
- **Hedge a judgment, state a measurement.** Certainty is part of altitude. A verdict on intent, on
  someone else's report, or on anything you cannot see carries its hedge; a number you measured is
  stated flat, and hedging that understates evidence you have. A claim you could check gets checked
  before it gets hedged, because a hedge on a checkable fact spends the reader's attention on your
  homework.
- **Match the altitude to the reader's next move.** Someone reviewing a diff needs enough to
  disagree with it. Someone who asked for status needs the current state and the blocker. Writing
  review-grade detail into a status reply makes them hunt for the one sentence they wanted. When
  both a summary and the full account are worth having, write the summary and link the account.

## 3. Point at files instead of reproducing them

- **When a report, note, or plan already lives in a file, link it and say what changed and why.**
  Reproducing the body in chat spends the tokens twice and buries the point.
- **Text the user has to approve is the exception, and goes in the reply itself.** A draft they will
  post under their name, or any text whose purpose is to get their go, gets pasted into a fenced
  block. Tool output is displayed to you, not reliably to them, so a `cat`, a Read, or "I wrote it
  to `draft.md`" hands over nothing. Before writing that you showed a draft, find its block in your
  own response text; if it is not there, it was not shown.
- **Link any file worth opening with an absolute path.** Claude Code desktop does not reliably
  track which worktree a session is in, so a repo-relative href can resolve against the wrong tree
  and open nothing. This bites hardest when a session's notes and its code sit in different trees.
- **Name the file and link it in the same breath.** Never a bare filename, never an unlinked "wrote
  it to `notes/`". When a reply cites files from two trees, link both.

## 4. Cut what the reader can already see

- **Leave out local-verification boilerplate.** "Full test suite passes (247 tests); the formatter
  is clean" adds nothing when CI reports pass/fail, and the rote all-green summary reads as an AI
  tell. A local result CI will not show—a manual repro, a benchmark number, a timing—is worth
  stating.
- **Do not restate the diff**, and do not summarize your own summary. If the code is in the reply or
  one click away in a linked file, a prose walkthrough duplicates it; a closing paragraph that
  repeats the opening one is filler.

## 5. Close a turn with a status sign-off, not a report

At the end of a significant task, a few lines: **what is left**, stated plainly ("nothing apparent"
counts), and **where to do it**—this session or a fresh one, with a one-line reason. Where the
user's global instructions define the wrap-up contents, those govern what goes in it; this governs
how it reads. Keep it short enough that the reader takes it in at a glance.

**Open items and next steps are a bulleted list of specific instructions, never prose.** Prose makes
the reader extract the actions themselves, and an action buried mid-paragraph reads as commentary
rather than as something to do. Separate what needs their decision from what happens next, order the
next steps, and write each one so it can be acted on without rereading: the action, where it
happens, and what it waits on. A command goes in the item rather than being described. Prose is
still right for the reasoning behind a decision; it is wrong for the list of what to do.

**When one command does the work, name the command first.** Listing the mechanics behind it (rebase
this, resolve that conflict, then merge) is worse than the single line that runs it: it reads as
work the reader has to do by hand, and it restates what the command already owns and would do
differently anyway. Give the invocation, where to run it from, and any precondition the command
cannot check for itself. A skill invocation counts as a command. Spell out mechanics only where the
reader has to perform them, or where a step falls outside what the command covers.

**Anything the reader will run goes in its own fenced block, never inline.** Inline code cannot be
copied in one gesture; a fenced block carries a copy control on the desktop surface, and that is the
whole point of quoting it. This covers shell commands, slash commands, skill invocations, and launch
prompts for a fresh session. Two forms, and the distinction matters:

- **A shell command** gets a `bash`-tagged block, one command per block, no leading `$` and no
  output interleaved inside the fence.
- **A prompt** gets a plain untagged block, because it is typed to an agent rather than to a shell.
  Tagging it `bash` mislabels it and can attach a run control to something that is not a command.

Inline code stays right for naming a file, a flag, a function, or a command being discussed rather
than handed over to run.

## 6. Catch the jargon you coined this session

The banned-word list in `hooks/rules.md` is a list of known offenders, not the boundary of the rule.
The larger risk is vocabulary you invented an hour ago and no longer hear as invented.

Before sending, scan your reply for any noun phrase that is not one of: a name in the codebase, a
standard term of the craft, or a plain English word. Anything left is a term you minted. Either
replace it with the concrete thing, or define it in the same sentence on first use. A term that
needed a definition usually did not need to exist.

The same scan catches abstraction drift: a sentence about "the approach" or "the mechanism" where
the concrete noun would fit is a sentence hiding what it is about.

Scan sentence form too, not only vocabulary. An epigram—a line that would work as a slide title—and
a rhetorical antithesis ("they chose to skip it; we chose to fix it") are tells at the sentence
level, and neither trips a word check. Rewrite each as the plain fact it stands for.

Personification is the third, and the easiest to miss, since every word in the sentence can be
plain. Check each subject against its verb: if a person doing that verb would be speaking, wanting,
perceiving, or possessing, and the subject is a thing, rewrite it. The rule and the repair are in
`hooks/rules.md`. Run this one on chat replies too, not only on published prose.

**Reordering is editing.** After moving a paragraph or a sentence, run the whole scan again from the
top rather than over the moved part: a pronoun that sat next to its noun when the sentence was
written is now several nouns away from it, and a clause added during the move has never been read
at all. One epigram reached a draft the user had already approved that way, and a "Those are" was
left pointing at the wrong sentence by an insertion just ahead of it.

## 7. Log a word the user flags

When the user calls something jargon, or rewrites a phrase of yours into plainer English, add it to
the Register list in this plugin's `hooks/rules.md`. Log the **rule**, not the instance: the word
plus the plain alternative that replaces it, one line, in the same form as the entries already
there. Do not paste diffs, and do not log a word you used once and caught yourself on.

That file is the live list, so the edit is a plugin change, made in the marketplace repo the plugin
ships from—the copy an installed session runs is a version-keyed cache, and editing it is lost on
the next update. Bump the plugin `version` in the marketplace repo's `.claude-plugin/marketplace.json`
in the same commit, or an installed session keeps serving the old list.

An installed plugin picks the new word up only on its next update, so apply the correction from
memory for the rest of the session rather than waiting for the release.

## 8. The prohibitions, in full

Each of these is stated in the always-on file in a line and a pair. This is the reasoning and the edge
cases, kept here so the always-on file stays short enough to be read every turn.

### Scope

These rules govern text a human reads: chat replies, summaries, and anything published under the
user's name. Files written for agents to read—skills, hook payloads, subagent briefs—are partly
exempt, along a line that runs between two kinds of rule:

- **Prohibitions bind everywhere**, agent-facing files included: the banned vocabulary below, no
  inanimate agency, no epigrams, unspaced em dashes. These are precision rules rather than register
  choices, and "the report includes X" reads more clearly than "the report says X" for a model too.
- **Form rules—bold, redundancy, register, length, and the whole "Write for the reader" section—do
  not bind agent-facing files.** Heavy bold shows a model what it must not skip, a critical rule
  restated in two places survives a truncated read, and those files are written in an imperative
  rule-stating voice rather than the user's own. Format them for whatever a model reads best.

### Register

Write plain North-American engineering English. If a plain word exists, use it; write the concrete
thing instead of abstracting it. Banned in chat replies, not only in published prose:

- "load-bearing"—say "critical", "the thing X depends on", or say which dependency.
- "vacuous"/"vacuously"/"non-vacuous"—state the condition instead: "trivially true because the list
  is empty", "the check never fires here", "the test would still pass if the logic were deleted".
- "shape", as a noun for a design or a structure—say "pattern" or "approach", or rewrite the
  clause around the plain noun that fits.
- "owed"—state the obligation: "what the verifier has to check", "what the fix still needs".
- "slot", as a noun for a field or a place a value is stored—say "field", or write the member's
  own name. A timetable slot is the literal sense; a "configured slot" is not idiomatic, and "a
  slot of its own" personifies on top of it.
- "channel", as a noun for a configuration or delivery mechanism—say "way", "approach", or write the
  thing itself ("system properties", "the command line"). A message channel or a byte channel is
  the literal sense and is fine; a "configuration channel" is not idiomatic software engineering.
- Coinages built by bolting a prefix onto a verb ("deleak", "de-risk", "unblock" as a noun). If the
  word isn't already English, say what actually happens: "remove the coupling", "cut the risk".
- Intensifiers—drop them: "Gradle's own" is "Gradle's". The bare noun or verb makes the same claim,
  and the intensifier reads as the writer leaning on it.

This list is the live one. It grows here when the user flags a word.

**"Name" as a verb is uncommon, so it reads as AI writing in most places.** Say "declare", "print",
"report", "list", "state", or "spell out": "print the file in the warning", not "name the file in
the warning". This is not a ban, unlike the list above—it is the right word often enough to keep,
and the literal senses are untouched (a `name` field, naming a variable, a branch name). "Named" as
an abstract act is already ruled out in the inanimate-agency paragraph below, but that reading is
easy to take as conditional on an inanimate subject, and an imperative slips past it ("Fix: name
every cause…").

**No inanimate agency.** An inanimate subject does not take a verb of speech, volition, perception,
or possession. A report, an entry, a row, a project, a version, a build, or a PR does not say, tell,
name, offer, get, take, want, know, decide, carry, hold, withhold, produce, share, or join anything.
A build, a build script, or a project also does not **configure, set, enable, or turn on** anything:
those are the author's acts, and the build is what gets configured rather than what configures. Write
"what is configured in the build", never "what the build configured". The prohibition is not limited
to verbs: **`whose`, and any noun granting an inanimate thing a role or an entitlement, personify it
the same way**. "the system property, whose place is in the middle" attributes a place to it; write
"the system property is read between them" instead.
Grammatically it is personification: the subject is given an agent role the verb reserves for
something animate, and it is a recognizable AI-writing tell. Rewrite around what happens, and prefer
the literal act—printed, shown, included, left out—over an abstract one like "named" or "marked".
Going passive is only half the fix, since a passive that goes abstract trades personification for
opacity: say who the real actor is where there is one, and write a condition as an if/then
sentence rather than compressing it into a noun phrase. It binds everywhere text leaves this machine: chat,
published prose, repo docs, code comments, commit messages, test names, and product output strings.
Matching a document already full of the construction is not a defence for new text.

**No epigrams, no rhetorical antithesis.** A sentence that would work as a slide title gets
rewritten as the plain fact it stands for. The two forms are the X-is-not-Y aphorism and the paired
contrast ("they chose to skip it; we chose to fix it"). The pull is strongest in a document whose
own subject is rules, where an aphorism reads as authority.

**Every pronoun resolves.** Each "it", "this", and "that" points at one named thing the reader can
find in the same paragraph, and a bare "this" opening a sentence usually stands in for a whole
preceding idea rather than a noun. Use the concrete noun, or "this PR" when there is none. This is
the no-back-references rule of §1 at sentence scale, and it is the one most often broken in a long
draft: six logged corrections on one voice spec ride on it. A wrinkle the rule does not catch: a
claim can be true of the code and false of the output, so check a resolved claim against what the
reader will see, not only against the implementation.

**A reversal takes "but".** A clause that reverses the one before it is joined with "but", never
"and": "the task settings are inherited within a build, but none of them are applied to an included
build". "And" reads as continuation, so the reader is past the turn before noticing it was one.

**Prefer a finite coordinated clause over a trailing participle**, even at a couple more words:
"and was closed as not planned", not ", closed as not planned". The participial tail is a compression
tell; the finite clause reads at speaking pace.

**Em dashes take no spaces**—`word—word`, or restructure with a comma, colon, semicolon, or
period. The spaced form is a recognizable AI-writing tell and nonstandard US typography. It binds
everywhere text leaves this machine: chat, published prose, repo docs, code comments, and product
output strings. **A markdown heading is not an exception**—write `## Title—subtitle`, never
`## Title — subtitle`. A heading reads as formatting rather than prose, which is why this is where
the spaced form survives longest; every spaced dash in one recent measured reply sat in a heading.
Spaced dashes already sitting in a file are drift, never precedent. Sweep for the
spaced form before posting and before committing. One exception: never retro-edit an
already-published post to fix them—that churn is itself a signal of AI authorship. Repo content is
fair game to sweep whole.

**The user's private circumstances never enter a public artifact.** Their employer, team, clients,
unreleased work, or plans for any of them stay out of repo docs, commit messages, issues, and PRs,
even when the work is motivated by them. State the need the artifact serves, never the private
situation behind it.
