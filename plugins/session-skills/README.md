# session-skills

A [Claude Code](https://claude.ai/code) plugin for the two ends of a working session: getting a unit
of work into its own git worktree, and getting it back out again. This plugin covers nothing a
session does between those two points.

## Skills

### `work-in-worktree`

Fetch first, and branch from `origin/<default>` rather than a local default branch that is behind
it. There is no local way to tell whether the checkout is current. A stale branch point either
surfaces at push time as a rejected non-fast-forward, or never surfaces, and the work merges on top
of commits it was not written against. The same fetch guards a one-line edit to a file another
machine also edits. When the local default branch is ahead after the fetch, as it is while commits
are held for review before a push, the new branch is opened from it and includes those commits.

Adopt the worktree work is already in flight on, or open a fresh one. Work is already in flight
when any of three tells is present: a pin in the repo's backlog, an existing worktree with commits
the default branch doesn't have, or a live lease where the repo runs a concurrency plugin. Opening a
second worktree on work that already has one strands the first branch's commits and silently
restarts the work.

The rule that costs the most when it's missed: a repo-root path handed over in context—from a git
status block, a memory, or a doc link—means the **primary checkout**, so taking it literally lands
the edit on the default branch instead of the session's branch. The fix for a file that lives only
in the primary checkout, such as an untracked backlog, is here too, along with the prune that keeps
stale worktree registrations and merged branches from accumulating. That includes PR branches the
host squashed or rebased on merge, deleted only when their content is on the default branch.

### `land-and-wrap`

How work leaves a worktree, decided by facts read off the repo instead of a mode declared in a
file. An `upstream` remote means the repo is a fork of someone else's project: the work is never
merged or pushed, and nothing is written to the remote host, whether GitHub, GitLab, or Bitbucket.
Issue and PR text is drafted as local files for the user to post. No `upstream` means the repo is
the user's. Work then fast-forwards into the default branch, or, where the default branch is
protected, is pushed as a branch with a pull request that is opened only after the user's go on its
title and body. The push depends on `origin`'s visibility, going out when private and waiting for
the user's explicit go when public. Visibility and landing mode are each read from a per-clone
`git config` value, with `gh` as a shortcut for both and `glab` for visibility, and the user is
asked once when none of them returns a value. The fork hold, the public-push hold, and the wait on
PR text each have a per-clone `git config` override that only the user sets.

None of these facts depends on the backlog, so a repo you own with an untracked, local-only roadmap
needs no special case.

Then the wrap-up actions every session runs whether or not the work finished: stop stray background
tasks, release any lease, and leave the branch and worktree standing as the resume record.

## What it pairs with

Two seams that other plugins fill are defined in `work-in-worktree` §0. A **concurrency plugin**
adds the half this plugin deliberately leaves out: a shared lease that keeps two or three sessions
off each other's files, plus whatever it builds on top, an unattended conductor for one. A **backlog
plugin** is where a session finds what is workable, where something is already in flight, and how to
record it done.

Used with neither, these skills still do the job: the user states the task, and the landing commit
is the record. The dependency runs one way—a plugin filling a seam references this one, never the
reverse—so no such plugin is mentioned here. The family map, with which plugins fill which seam, is
in the marketplace's README.

`writing-conventions` governs how the wrap-up reads once these actions are done.

## How it is wired

One hooks module, `hooks/register.ts`, which is a Claude Code mod and needs Claude Code 2.1.286 or
later, the oldest version supported. It registers five tools, named `mcp__session-skills__<tool>`,
and the skills call them where they once had bash to adapt:

- `find_checkouts` fetches, then returns the primary checkout, the default branch, the ref a new
  branch should start from, and every worktree (`work-in-worktree` §1 and §2).
- `open_worktree` opens a worktree and branch from that ref and links the repo's local notes
  directory into it (§3).
- `prune_branches` prunes stale worktree registrations and deletes merged branches, including one a
  host squashed on merge, and never removes a worktree (§4).
- `landing_facts` returns whether the repo is a fork, `origin`'s visibility, the landing mode, and
  the holds the user lifted (`land-and-wrap` §1).
- `edit_primary_file` edits a file that is only in the primary checkout, such as an untracked
  roadmap: one passage is replaced, or text is appended, and nothing is written when the passage
  has drifted.

`hooks/checkouts.test.ts` and `hooks/register.test.ts` run under `claude plugin test`. The five
tool definitions are in every session's context, at roughly 500 tokens by estimate.

At session start the module adds `hooks/rules.md` to every session, including after `/clear` and
compaction. That file has three rules that cannot go in a skill. One is the session-title suggestion
made at the end of a session, in a format the user copies in one gesture. Another runs every turn:
weigh continuing this session against handing off to a fresh one, silently, and speak only when a
tell trips—the unit just landed, the session has been compacted, or the next thing is unrelated
work. The third applies whenever something out of scope turns up: raise it in the reply, write it
into the repo's backlog where it should outlive the session, and never leave it in a host's
suggested-task feature on its own. All three apply to every session that did real work, including
the ones that never open a worktree and so never load `land-and-wrap`. That is why they are injected
by a hook, and why they ship with the plugin instead of sitting in a personal global `CLAUDE.md`.
There is no `SubagentStart` hook, because a subagent doesn't end a session.

Editing any skill or the rules file here is a plugin release: an installed session reads a
version-keyed cache, so the plugin's `version` in `.claude-plugin/marketplace.json` has to go up in
the same commit, unless it is already ahead of the version on `origin/main`. One bump is enough for
every commit waiting to be pushed. Without one, the session keeps serving the old copy.

## Platform

The tools run git by argument vector with no shell, so one implementation serves bash, Git Bash, and
PowerShell sessions. `find_checkouts` and `prune_branches` need git 2.36 or later, since the worktree
list is read with `-z`, and the merge check in `prune_branches` needs 2.43 or later. The commands
left in the skills are single `git`, `gh`, or `glab` calls that read the same in each. On Windows
the notes directory is linked as a junction, which needs no privilege; that path has not been run on
Windows.
