# session-skills

A [Claude Code](https://claude.ai/code) plugin for the two ends of a working session: getting a unit
of work into its own git worktree, and getting it back out again. Everything a session does between
those two points is the repo's business, not this plugin's.

## Skills

### `work-in-worktree`

Fetch first, and branch from `origin/<default>` rather than the local default branch: nothing
local shows whether the checkout is current, so a stale branch point either surfaces at push time as
a rejected non-fast-forward or never surfaces and the work merges on top of code it never saw. The
same fetch guards a one-line edit to a file another machine also edits.

Adopt the worktree work is already in flight on, or open a fresh one. The three tells that settle
which—a pin in the repo's backlog, an existing worktree carrying commits the default branch
doesn't have, and a live lease where the repo runs a concurrency plugin—matter because opening a
second worktree
on work that already has one strands the first branch's commits and silently restarts it.

The rule that costs the most when it's missed: a repo-root path handed over in context—from a git
status block, a memory, a doc link—means the **primary checkout**, so taking it literally lands the
edit on the default branch instead of the branch the session thinks it's on. The fix for a file that
genuinely lives only in the primary checkout, such as an untracked backlog, is here too, along with
the prune that keeps stale worktree registrations and merged branches from accumulating. That
includes PR branches the host squashed or rebased on merge, deleted only when their content is on
the default branch.

### `land-and-wrap`

How work leaves a worktree, decided by facts read off the repo instead of a mode declared in a
file. An `upstream` remote means the repo is a fork of someone else's project: the work never
merges, never pushes, and nothing at all reaches the remote host, whether GitHub, GitLab, or
Bitbucket—issue and PR text is drafted as local files for the user to post. No `upstream` means the
repo is theirs. Work then fast-forwards into the default branch, or, where the default branch is
protected, goes up as a branch with a pull request whose title and body wait for the user's go. The
push depends on `origin`'s visibility, going out when private and waiting for the user's explicit go
when public. Visibility and landing mode are each read from a per-clone `git config` value, with
`gh` as a shortcut for both and `glab` for visibility, and the user is asked once when none of them
returns a value. The fork hold, the public-push hold, and the wait on PR text each have a per-clone
`git config` override that only the user sets.

Reading these facts off the repo is what makes "a repo you own with an untracked, local-only
roadmap" an ordinary combination rather than a special case: the backlog decides none of them.

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

`writing-conventions` governs how the wrap-up reads once these actions are done.

## How it is wired

A `SessionStart` hook injects `hooks/rules.md` into every session, including after `/clear` and
compaction. It carries three rules the skills can't. One is the session-title suggestion a session
owes at its end, in a format the user copies in one gesture. Another runs every turn: weigh
continuing this session against handing off to a fresh one, silently, and speak only when a tell
trips—the unit just landed, the session has been compacted, the next thing is unrelated work. The
third fires whenever something out of scope turns up: raise it in the reply, write it into the
repo's backlog where it should outlive the session, and never leave it in a host's suggested-task
feature on its own. All three
apply to every session that did real work, including the ones that never open a worktree and so
never load `land-and-wrap`—which is why they ride a hook rather than a skill, and ship with the
plugin rather than sitting in a personal global `CLAUDE.md`. No `SubagentStart` hook: a subagent
doesn't end a session.

Editing any skill or the rules file here is a plugin release: an installed session reads a
version-keyed cache, so the plugin's `version` in `.claude-plugin/marketplace.json` has to bump in
the same commit or the session keeps serving the old copy.

## Platform

The shell snippets in both skills are bash. PowerShell 7 versions are in
`work-in-worktree/powershell.md` and `land-and-wrap/powershell.md`, matched by section number. The
`SessionStart` hook is a plain `cat`, which runs unchanged under bash, Git Bash, and PowerShell.
