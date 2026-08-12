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
  the user's name (that's ghostwrite), and NOT for deciding when to stop and ask
  (that's ask-when-needed).
---

# Write for the reader—register, context, and altitude

This skill governs writing **to** the user. Its sibling `ghostwrite` governs writing **as** the
user, for text they sign and post. Escalation—when to stop and hand over a decision—belongs to
`ask-when-needed`; write none of it here.

This plugin's `hooks/rules.md` loads every session and carries the short form: the banned-word list,
the em-dash rule, and the cold-reader bullets. This file is the full protocol behind it. All of it
applies to text a human reads. Agent-facing files—skills, hook payloads, subagent briefs—are exempt
and are formatted for whatever a model reads best.

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
- **Match the altitude to the reader's next move.** Someone reviewing a diff needs enough to
  disagree with it. Someone who asked for status needs the current state and the blocker. Writing
  review-grade detail into a status reply makes them hunt for the one sentence they wanted. When
  both a summary and the full account are worth having, write the summary and link the account.

## 3. Point at files instead of reproducing them

- **When a draft, report, or note already lives in a file, link it and say what changed and why.**
  Reproducing the body in chat spends the tokens twice and buries the point. This is the rule for
  drafts, reports, plans, and any generated document.
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
