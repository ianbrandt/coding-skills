# session-skills

A [Claude Code](https://claude.ai/code) plugin for the two ends of a working session: getting a unit
of work into its own git worktree, and getting it back out again. Everything a session does between
those two points is the repo's business, not this plugin's.

## Skills

### `work-in-worktree`

Adopt the worktree work is already in flight on, or open a fresh one. The three tells that settle
which—a pin in the repo's backlog, an existing worktree carrying commits the default branch
doesn't have, and a live lease where the repo runs a concurrency plugin—matter because opening a
second worktree
on work that already has one strands the first branch's commits and silently restarts it.

The rule that costs the most when it's missed: a repo-root path handed over in context—from a git
status block, a memory, a doc link—means the **primary checkout**, so taking it literally lands the
edit on the default branch instead of the branch the session thinks it's on. The fix for a file that
genuinely lives only in the primary checkout, such as an untracked backlog, is here too, along with
the prune that keeps stale worktree registrations and merged branches from accumulating.

### `land-and-wrap`

How work leaves a worktree, decided by two facts read off the repo instead of a mode declared in a
file. An `upstream` remote means the repo is a fork of someone else's project: the work never
merges, never pushes, and nothing at all reaches GitHub—issue and PR text is drafted as local files
for the user to post. No `upstream` means the repo is theirs, so work fast-forwards into the default
branch; `origin`'s visibility then decides the push, private going out and public waiting for the
user's explicit go.

Splitting those two facts apart is what makes "a repo you own with an untracked, local-only roadmap"
an ordinary combination rather than a special case: only fork-ness stops a merge, and only
visibility gates a push.

Then the wrap-up actions every session runs whether or not the work finished: stop stray background
tasks, release any lease, and leave the branch and worktree standing as the resume record.

## What it pairs with

`work-in-worktree` §0 defines two seams other plugins fill. A **concurrency plugin** adds the half
this plugin deliberately leaves out: a shared lease that keeps two or three sessions off each other's
files, plus whatever it builds on top, an unattended conductor for one. A **backlog plugin** answers
what is workable, where something is already in flight, and how to record it done.

Used with neither, these skills still do the job: the user names the task, the landing commit is the
record. The dependency runs one way—a plugin filling a seam references this one, never the reverse—so
this plugin names no filler. The marketplace's own README has the family map and which plugins fill
which seam.

`communication-skills` owns how the wrap-up reads once these actions are done.

## How it is wired

A `SessionStart` hook injects `hooks/rules.md` into every session, including after `/clear` and
compaction. It carries two rules the skills can't. One is the session-title suggestion a session
owes at its end, in a format the user copies in one gesture. The other runs every turn: weigh
continuing this session against handing off to a fresh one, silently, and speak only when a tell
trips—the unit just landed, the session has been compacted, the next thing is unrelated work. Both
apply to every session that did real work, including the ones that never open a worktree and so
never load `land-and-wrap`—which is why they ride a hook rather than a skill, and ship with the
plugin rather than sitting in a personal global `CLAUDE.md`. No `SubagentStart` hook: a subagent
doesn't end a session.

Editing any skill or the rules file here is a plugin release: an installed session reads a
version-keyed cache, so the plugin's `version` in `.claude-plugin/marketplace.json` has to bump in
the same commit or the session keeps serving the old copy.
