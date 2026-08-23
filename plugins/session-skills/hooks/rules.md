SESSION RULES ACTIVE

## Suggest a session title

A session that did substantive work owes a title suggestion at its end. It goes last in the reply,
as a `**Session title:**` label line followed by the bare title alone in a plain untagged fenced
block, so the user copies it in one gesture:

````
**Session title:**

```
R1: aggregation core
```
````

Nothing but the title inside the fence—no quotes, no label—because everything in it gets copied.
Spell words out ("package", not "pkg"), keeping established type and API names as they are. Trivial
Q&A owes nothing.

A skill may also emit this earlier, when a unit of work is claimed and its name is already known.
That title and this one are the same block, byte-identical, revised at the end only if the work
turned out to be something else.

## Judge whether the session should continue

At the end of a turn that finished something, weigh continuing against handing off, silently. Say
nothing unless a tell below trips: a turn that ends with a paragraph about session length costs more
than the handoff it was hedging against.

Hand off when:

- **The claimed unit just landed** and the next one touches different files. The repo holds the
  state now, so a fresh session re-derives it for the price of one backlog entry.
- **The session has been compacted**, or is re-reading files it already read, or re-deriving a fact
  it established earlier. Those are one tell: the transcript has stopped carrying the work.
- **The next thing is a different repo, a different lane, or a different kind of work.** Context
  built for the last unit is dead weight against the new one, and it is re-read on every turn.

Keep going when:

- **A diff is built but unreviewed**, a build unverified, or a hypothesis live and unwritten.
  Whatever exists nowhere but this transcript is what a fresh session cannot re-derive.
- **The work is mid-unit.** Wait for the landing; handing off from the middle of a unit costs more
  than it saves.

When a tell trips, say so in one line and hand off in the format below.

## Hand off the next session

Recommending a fresh session owes it a launch snippet: the root directory to start in, then a
standalone prompt in a plain untagged fenced block. As few tokens as stand alone—an entry point (a
skill invocation, a work-item ID, a doc path) plus the goal—and **never a recap of this session**,
which the new one re-derives from the repo. Say in one line why the work goes to a fresh session
rather than this one, and name the model and effort to run it at in the terms the user's picker
shows ("Opus + Medium").

Where the repo tracks work in a backlog, the entry point is that backlog plugin's own invocation.
It resolves in-flight work by itself, from the primary checkout, so the snippet needs no worktree
path—and a freehand prompt reconstructing that state is how a resume becomes a second branch on
work already half-built.

## The skills behind these rules

`work-in-worktree`—getting the work into the right worktree before touching code.
`land-and-wrap`—how finished work leaves its branch, and the rest of the wrap-up.
