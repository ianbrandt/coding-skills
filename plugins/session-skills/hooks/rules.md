SESSION RULES ACTIVE

## Give the session a title

**A reply that does substantive work in a session with no title yet gives it one.** That is usually
the first reply past a question, when the subject of the session is known, and it includes a
close-out or a wrap-up of work done elsewhere. Trivial Q&A gets no title. **Title the session again
after a significant turn when a better title fits**: the work turned out to be something else, or
the session claimed a unit of work with a title format of its own. When the title given earlier
still fits, leave it alone and print nothing about it.

**Capitalize the first word.** Spell words out ("package", not "pkg"), keeping established type and
API names as they are.

**Where the session has a tool that sets its own title, set the title with it and print no title
block.** The Claude desktop app has one, `set_session_title`, called with the session ID `self`. It
can be a deferred tool, which is loaded by name before the first call.

**Where no tool in the session sets its title, as in the Claude Code CLI, print the title at those
same points.** A tool is in the session only if it is listed, deferred or not; do not skip the
block on the chance that one exists. It goes last in the reply, as a `**Session title:**` label line
followed by the CLI's `/rename` command with the title, alone in a plain untagged fenced block, so
the user renames the session with one paste:

````
**Session title:**

```
/rename Parser aggregation core
```
````

Nothing but the command and the title inside the fence—no quotes, no label—because everything in it
gets pasted.

A printed block is the last thing in the reply, with no exception. Where the reply also includes the
launch snippet from the handoff section below, that snippet comes first and this block closes the
reply. Both are plain untagged fences, and emitting the launch snippet does not replace this one.

## Judge whether the session should continue

At the end of a turn that closed a unit of work, weigh continuing against handing off, silently. Say
nothing unless a tell below trips: a turn that ends with a paragraph about session length costs more
than the handoff it was hedging against. That silence applies to this judgment only—the title rule
above runs on its own trigger and is never suppressed by it.

A turn that hands a decision back closes a unit too, and it is where a session most often ends: work
stops until the user answers, and the answer may come in a different session or not at all. Listing
the open items is half of it—say for each one whether this session takes it or a fresh one does.
After a list of open items with no owner, the user has no handoff to launch and no sign that this
session will continue, so the work stops.

Hand off when:

- **The claimed unit just landed** and the next one touches different files. The state is in the
  repo now, so a fresh session re-derives it for the price of one backlog entry.
- **The session has been compacted**, or is re-reading files it already read, or re-deriving a fact
  it established earlier. Those three count as one tell, that the work can no longer be read back
  from the transcript.
- **The next thing is a different repo, a different lane, or a different kind of work.** Context
  built for the last unit is dead weight against the new one, and it is re-read on every turn.

Keep going when:

- **A diff is built but unreviewed**, a build unverified, or a hypothesis live and unwritten.
  Whatever exists nowhere but this transcript is what a fresh session cannot re-derive.
- **The work is mid-unit.** Wait for the landing; handing off from the middle of a unit costs more
  than it saves.

When a tell trips, say so in one line and hand off in the format below.

## Hand off the next session

Recommending a fresh session comes with a launch snippet. Three parts, all required:

1. **The root directory to start in**, then a standalone prompt in a plain untagged fenced block. As
   few tokens as stand alone—an entry point (a skill invocation, a work-item ID, a doc path) plus
   the goal—and **never a recap of this session**, which the new one re-derives from the repo.
2. **One line on why the work goes to a fresh session** rather than this one.
3. **The model and effort to run it at**, in bold, as the picker's model name and effort label:
   **Opus + High**. The effort is one of Low, Medium, High, Extra, or Max. Never a tier name
   ("everyday") or "default", which match nothing in the picker.

**Writing the next session's entry point into a sentence is that recommendation, not a substitute
for it.** "Next session starts clean on the parser item" is this handoff in a form nobody can
copy, with no tier attached. Write the block instead, and never both.

Where the repo tracks work in a backlog, the entry point is that backlog plugin's invocation.
It resolves in-flight work by itself, from the primary checkout, so the snippet needs no worktree
path—and a freehand prompt reconstructing that state is how a resume becomes a second branch on
work already half-built.

## Raise an out-of-scope finding in the reply

Work noticed in passing, a defect outside the current change, a stale doc, a missing test, is
raised in the reply where it was found. A host's suggested-task feature, where one exists, has
room for no context and no discussion, and in a repo with a backlog it is a second queue outside
that backlog.

Where the finding should outlive the session, write it into the repo's backlog in that backlog's
form, including work that needs a machine or an account this session does not have. A
suggested task is worth adding only alongside that, never instead of it, and only for
self-contained work that needs no decision from the user and would start in its own worktree now.

## The skills behind these rules

`work-in-worktree`—getting the work into the right worktree before touching code, off a
**fetched** default branch: a clean working tree is no evidence the checkout is current, and a
file another machine edits too, such as a shared to-do, needs that fetch even for a one-line edit
with no worktree involved.
`land-and-wrap`—how finished work leaves its branch, and the rest of the wrap-up. **Invoke it at
the end of any session that opened a worktree**, including one where a repo-local landing runbook
already merged the work: that runbook covers the landing, not the wrap-up.
