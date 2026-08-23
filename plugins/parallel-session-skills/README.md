# parallel-session-skills

A [Claude Code](https://claude.ai/code) plugin for a repo that several sessions are working at once.
Each session sits in its own git worktree and can see none of the others' context, so the only
coordination that exists is what git and a shared claim ledger can carry. These skills are that
ledger, and the conductor that drives several lanes off it.

## Skills

### `claim-a-lane`

Write an atomic claim to the ledger before touching code. The claim declares which paths the lane
expects to edit, which is what turns "are these two tasks disjoint?" from a guess about their names
into a glob comparison—and it is the one fact no issue tracker can supply, since Jira has no idea
two issues collide on a dependency manifest. Carries the dead-claim reap too, keyed off the worktree
directory rather than merge state, because a just-claimed session's branch tip equals the default
branch and merge state reads that as dead. And the etiquette: never `git worktree remove` a
sibling's directory, because a live session between tasks looks exactly like an abandoned one.

The rule that costs the most when it's missed: an empty ledger is not evidence the work is free. A
session releases its claim at its own finish rather than the work's, so the ordinary handoff leaves
work in flight with no claim at all.

### `conduct-a-pipeline`

One session conducting several lanes at once, unattended: hold 2–5 file-disjoint units of work in
flight, build each in its own worktree via a background Workflow, and process each as it finishes,
refilling until the candidates run out. Everything in it that looks paranoid is there because
nobody is watching. A Workflow's self-reported `ready` has been wrong on a red tree, so the
conductor runs the build gate itself and treats a report that fails it as a failure. A Workflow that
dies sends no completion notification, so a watchdog covers the pipeline that went quiet rather than
finished. A second real failure flags the unit and the run continues without it, and a flagged unit
stays out of later refills so it isn't re-picked and re-burned every pass.

It takes its candidates from a backlog plugin and hands each finished unit back to it to record.

## What it needs

`session-skills`, which owns the worktree these skills claim a lane in: `work-in-worktree` locates
the primary checkout, adopts the worktree work is already in flight on, and opens a fresh one
otherwise, and `land-and-wrap` gets the work back out and releases the claim at session end. The
dependency runs one way—`session-skills` works alone, this plugin does not.

A backlog plugin is optional on top of both. It answers what is workable and where something is
already in flight; disjointness stays here, in the ledger, because no issue tracker knows it.
`roadmap-skills` is one such plugin, backing those answers with a markdown file.

## How it is wired

No `SessionStart` hook, and so no always-on token cost: nothing here applies to a session that never
opens a lane, and the skill descriptions are enough to trigger both skills.

Editing any skill here is a plugin release: an installed session reads a version-keyed cache, so the
plugin's `version` in `.claude-plugin/marketplace.json` has to bump in the same commit or the
session keeps serving the old copy.
