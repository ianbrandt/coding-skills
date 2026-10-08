# parallel-session-skills

A [Claude Code](https://claude.ai/code) plugin for a repo that several sessions are working at once.
Each session sits in its own git worktree and can see none of the others' context, so the sessions
coordinate only through git and a shared claim ledger. The skills here cover writing to that ledger
and running several lanes from one conductor session.

## Skills

### `claim-a-lane`

Write a claim to the ledger before touching code. The paths the session expects to edit
are listed in the claim, so whether two tasks are disjoint is settled by comparing globs instead of
guessing from the task names. No issue tracker can supply that fact: two Jira issues that both edit
a dependency manifest look unrelated in Jira. The skill also covers the dead-claim reap: a claim is
dead when `git worktree list` shows no worktree on its branch. Merge state cannot be used for this,
since a just-claimed session's branch tip equals the default branch. And the etiquette: never `git
worktree remove` a sibling's directory, because a live session between tasks looks the same as an
abandoned one.

The rule that costs the most when it's missed: an empty ledger is not evidence the work is free. A
session releases its claim when the session ends, whether or not the work is finished, so after an
ordinary handoff the work is in flight with no claim.

### `conduct-a-pipeline`

One session conducting several lanes at once, unattended: hold 2–5 file-disjoint units of work in
flight, build each in its own worktree via a background Workflow, and process each as it finishes,
refilling until the candidates run out. Everything in it that looks paranoid is there because
nobody is watching. A Workflow's self-reported `ready` has been wrong on a red tree, so the
conductor runs the build gate itself and treats a report that fails it as a failure. A Workflow that
dies sends no completion notification, so a watchdog covers the pipeline that went quiet rather than
finished. After a second real failure the unit is flagged and the run continues without it, and a
flagged unit stays out of later refills so it isn't re-picked and re-burned every pass.

Candidates come from a backlog plugin, and each finished unit is recorded there.

## What it needs

`session-skills`, which provides the worktree these skills claim a lane in: `work-in-worktree`
locates the primary checkout, adopts the worktree work is already in flight on, and opens a fresh
one otherwise, and `land-and-wrap` gets the work back out. This plugin fills the lease seam defined
in `work-in-worktree` §0. The dependency runs one way: `session-skills` works alone and does not
refer to any plugin that fills its seams, but this plugin does not work without `session-skills`.
Nothing in the manifest format enforces that, so the check is in `claim-a-lane`, where the session
is told to stop and report when `work-in-worktree` is absent.

A backlog plugin is optional on top of both. It supplies what is workable and where something is
already in flight. Disjointness is still checked in the ledger, because an issue tracker has no
record of which paths a task edits.

## How it is wired

No `SessionStart` hook, and so no always-on token cost: nothing here applies to a session that never
opens a lane, and the skill descriptions are enough to trigger both skills.

One hooks module, `hooks/register.ts`, which is a Claude Code mod and needs Claude Code 2.1.286 or
later, the oldest version supported. No shell or interpreter is involved, and git is run directly.

Three tools are registered, and in `claim-a-lane` the ledger is read and written only through them.
With `mcp__parallel-session-skills__read_ledger`, dead claims are deleted and the live ones
returned. With `write_claim`, a claim is filed under the branch checked out in a worktree and
stamped with the session's id, and `release_claim` deletes it. The primary checkout is found from
any worktree, and it is refused as a lane. A claim file is deleted with `git clean` on its literal
path, because a hooks module has no call that deletes a file and git is on every machine these
skills run on.

At session end every claim stamped with the ending session's id is deleted, so a session that dies
or exits without wrapping hands its lane back anyway. That is a safety net: `land-and-wrap` still
releases at wrap, which returns the lane immediately instead of whenever the session exits. Where
hooks modules are off (a managed policy, or an untrusted workspace) the tools are not listed
either, and in `claim-a-lane` the session is told to stop and report it.

The ledger's rules are pure functions in `hooks/ledger.ts`. They are checked, with the tools and the
session-end release, by `claude plugin test` with `hooks/ledger.test.ts`.

Editing any skill here is a plugin release: an installed session reads a version-keyed cache, so the
plugin's `version` in `.claude-plugin/marketplace.json` has to go up in the same commit, unless it
is already ahead of the version on `origin/main`. One bump is enough for every commit waiting to be
pushed. Without one, the session keeps serving the old copy.
