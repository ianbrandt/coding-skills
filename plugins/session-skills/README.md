# session-skills

A [Claude Code](https://claude.ai/code) plugin for working a repo that several sessions are working
at once. Each session sits in its own git worktree and can see none of the others' context, so the
only coordination that exists is what git and a shared claim ledger can carry. These skills are that
protocol: how a session gets into a lane, and how it gets out.

## Skills

### `claim-a-lane`

Adopt the worktree work is already in flight on, or open a fresh one, then write an atomic claim to
the ledger before touching code. The claim declares which paths the lane expects to edit, which is
what turns "are these two tasks disjoint?" from a guess about their names into a glob comparison—and
it is the one fact no issue tracker can supply, since Jira has no idea two issues collide on a
dependency manifest. Carries the three tells that work is already in flight—and the rule
that an empty ledger is not one of them, since a session releases its claim at its own finish rather
than the work's. Also the hygiene pass: prune, reap dead claims by worktree directory rather than
merge state, and never `git worktree remove` a sibling's directory, because a live session between
tasks looks exactly like an abandoned one.

The rule that costs the most when it's missed: a repo-root path handed over in context—from a git
status block, a memory, a doc link—means the **primary checkout**, so taking it literally lands the
edit on the default branch instead of the branch the session thinks it's on.

### `land-and-wrap`

How work leaves a lane, decided by two facts read off the repo instead of a mode declared in a file.
An `upstream` remote means the repo is a fork of someone else's project: the work never merges,
never pushes, and nothing at all reaches GitHub—issue and PR text is drafted as local files for the
user to post. No `upstream` means the repo is theirs, so work fast-forwards into the default branch;
`origin`'s visibility then decides the push, private going out and public waiting for the user's
explicit go.

Splitting those two facts apart is what makes "a repo you own with an untracked, local-only roadmap"
an ordinary combination rather than a special case: only fork-ness stops a merge, and only
visibility gates a push.

Then the wrap-up actions every session runs whether or not the work finished: release the claim, stop
stray background tasks, and leave the branch and worktree standing as the resume record.

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

## What it pairs with

These skills never decide *what* to work on. A backlog plugin answers three questions for
them—what is workable, where something is already in flight, and how to record it done—and
`roadmap-skills` is one such plugin, backing those answers with a markdown file instead of an issue
tracker. Sequencing between tasks is the backlog's data; disjointness stays here, in the ledger.

Used alone, with no backlog plugin at all, these skills still do the job: the user names the task,
the ledger keeps two sessions off each other, and the landing commit is the record.
`communication-skills` owns how the wrap-up reads once these actions are done.

## How it is wired

A `SessionStart` hook injects `hooks/rules.md` into every session, including after `/clear` and
compaction. It carries two rules the skills can't. One is the session-title suggestion a session
owes at its end, in a format the user copies in one gesture. The other runs every turn: weigh
continuing this session against handing off to a fresh one, silently, and speak only when a tell
trips—the unit just landed, the session has been compacted, the next thing is unrelated work. Both
apply to every session that did real work, including the ones that never claim a lane and so never
load `land-and-wrap`—which is why they ride a hook rather than a skill, and ship with the plugin
rather than sitting in a personal global `CLAUDE.md`. No `SubagentStart` hook: a subagent doesn't
end a session.

Editing any skill or the rules file here is a plugin release: an installed session reads a
version-keyed cache, so the plugin's `version` in `.claude-plugin/marketplace.json` has to bump in
the same commit or the session keeps serving the old copy.
