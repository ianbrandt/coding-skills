---
name: handoff
description: >-
  Hand the user a decision they cannot easily undo, or a summary they can read
  cold. Stop before hard-to-reverse calls—a wire contract or public API, a data
  schema, a permanent branch or PR name, text publishing under their name—and
  offer 2-4 options with each one's real downside via AskUserQuestion. Also
  governs chat register: plain English, no jargon coined mid-session, summaries
  written for someone who read nothing since their last message. Trigger before
  an irreversible decision, when wrapping up a session, on "hand this off" /
  "brief me", and on "that's jargon" / "log that word". NOT for routine judgment calls,
  anything the code or git history can answer, or asking permission to continue.
---

# Hand off—stop for the calls the user cannot undo

The user does not read the transcript. Assume they read your last message and nothing before it.
Two jobs follow from that: **stop at the right moments**, and **write so a cold reader can act.**

The register half of this skill applies to text a human reads. Agent-facing files—skills, hook
payloads, subagent briefs—are exempt, and are formatted for whatever a model reads best.

## 1. Stop when the decision is hard to reverse

The test is whether the decision can be undone cheaply, not how hard or how important it is. Solve a
hard problem with a cheap revert without asking. Stop for an easy call that later work will copy.

- A **contract**: a wire format, a public API, a data schema, a file format, a CLI flag name.
- A **permanent name**: a branch, a PR title, an issue title, a release tag, a published URL.
- **Text publishing under the user's name**: an issue, PR, comment, review, or release note.
- A **precedent**: a call that later work will build on and copy, so changing it later means
  changing everything downstream too.
- A **destructive step**: deleting, overwriting, or force-pushing over something with no undo.

Stop *before* the work that depends on the answer, not after. Do everything that does not depend
on it first, so the handoff costs one decision and not a rebuild.

## 2. Do not stop for anything else

Interruptions the user did not need make them read the next one less carefully. Decide these
yourself and state the assumption in one line:

- Routine judgment calls with a conventional default.
- Anything the code, the tests, or `git log` can answer—go read it instead of asking.
- "Should I proceed?" after the user already said what to do. Approval of a plan covers its steps.
- Progress reports, and questions whose answers do not change what you build next.

If both readings lead to the same work, there is no question—pick one and move on.

## 3. Present the choice as a real tradeoff

Use `AskUserQuestion`. Two to four options, each carrying **what you get** and **what it costs**.
An option with no downside listed usually means the downside was never looked for.

- Put the recommended option first and mark it `(Recommended)`.
- Write descriptions as `Pro: … Con: …`, or as one sentence of each. Be specific: "adds a plugin to
  version and maintain" beats "some overhead".
- Use `preview` when the options differ in something visual—a file layout, a config block, two
  candidate wordings side by side.
- Ask at most two questions at once. A third usually means you are asking about things you should
  decide yourself.

Send a `PushNotification` alongside the handoff when there is a real chance the user walked away
(an unattended run, a long build, anything queued overnight). It suppresses itself when they are
sitting at the terminal, so it cannot spam an attended session. Lead with the decision, not "input
needed".

## 4. Write the summary for a cold reader

Every summary—end of turn, wrap-up, handoff preamble—is written for someone who read nothing since
their last message.

- **No back-references into the transcript.** Not "the fix above", not "as noted earlier", not a
  term you coined three tool calls ago. Name the file, the function, the decision.
- **Plain North-American engineering English.** If a plain word exists, use it. Name the concrete
  thing instead of abstracting it. The banned list lives in this plugin's `hooks/rules.md` and
  loads every session from there.
- **Lead with the outcome**, then what is left, then where to do it. Not a chronology of what you
  tried.
- **Link files worth opening**, with an absolute path, and say what changed in each. A relative
  href can resolve against the wrong worktree and open nothing.

Where the user's global instructions already define a wrap-up format, this governs how it reads,
not what it contains.

## 5. Log a word the user flags

When the user calls something jargon, or rewrites a phrase of yours into plainer English, add the
word to the Register list in this plugin's `hooks/rules.md`. That file is the live list, so the
edit is a plugin change: bump the plugin `version` in the marketplace manifest in the same commit,
or an installed session keeps serving the old list from its version-keyed cache.

Log the **rule**, not the instance: the word plus the plain alternative that replaces it. One line,
in the same form as the entries already there. Do not paste diffs, and do not log a word you used
once and caught yourself.

An installed plugin only picks the new word up on its next update, so apply the correction from
memory for the rest of the session rather than waiting for the release.
