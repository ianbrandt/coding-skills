---
name: land-and-wrap
description: >-
  Get finished work out of its worktree and close the session cleanly. Decides
  how work lands from two facts about the repo itself—whether it is a fork of
  someone else's project, and whether its origin is public—rather than from a
  mode someone declared or the backlog it tracks work in: fast-forward into the default branch and push, merge
  but hold the push for review, or stage locally and touch GitHub not at all.
  Then the wrap-up actions every session runs whether or not the work finished:
  release any claim, stop stray background tasks, leave a resume record. Trigger
  when work is committed and ready to leave its branch, and at the end of any
  session that opened a worktree. NOT for how a wrap-up should read (that's
  write-for-the-reader), and NOT for getting into the worktree in the first
  place (that's work-in-worktree).
---

# Land and wrap

Two separate jobs, and the second one runs even when the first doesn't: **landing** moves finished
work out of its worktree, and the **wrap-up** closes the session whether the work finished, stalled,
or was abandoned.

## 1. Two facts decide how work lands

Read them off the repo; don't take them from a mode someone declared in a file.

```bash
git remote get-url upstream >/dev/null 2>&1 && echo "fork"        # someone else's project
gh repo view --json isPrivate -q .isPrivate                       # origin's visibility
```

- **A fork** (an `upstream` remote, ideally with `git remote set-url --push upstream no_push`) means
  the work is a contribution to a project you don't own. It **never merges and never pushes**, and
  **nothing reaches GitHub** (§3).
- **No `upstream`** means the repo is yours. Work **fast-forwards into the default branch** (§2).
  Then visibility decides the push: **private pushes; public holds** for the user's explicit go,
  because a public push is published under their name and can't be taken back.

If `gh` isn't available or errors, treat the repo as public and hold the push—the safe direction of
a wrong guess.

These are independent of the backlog. A repo you own can track its work in an untracked, local-only
roadmap and still merge into its own default branch; that combination is ordinary, not a deviation.
Only fork-ness stops a merge, and only visibility gates a push.

## 2. Landing in a repo you own

**Bring the docs first.** Finishing includes every piece of documentation the change touches: the
subsystem's design doc (the durable *why*) plus any user-facing surface. Then **record it done**
through whatever backlog plugin the repo uses (`work-in-worktree` §0), in that backlog's own form. With
no backlog at all, the landing commit is the record and there is nothing else to write. Keep any
such edit minimal, localized, and in its own final commit—a backlog file is a collision seam every
other lane is also editing.

Follow the repo's end-of-session merge protocol if it has one (a `/land-session` runbook), otherwise:

1. **Rebase onto the default branch**—`git -C "$WT" rebase "$DEFAULT"`.
2. **Build, risk-based, from `$WT`**: rebuild when the rebase pulled in changes to a seam this work
   touches; skip it for a disjoint lap or one that moved only docs and fixtures. A bare `git rebase`
   or a bare build command targets whatever the shell's cwd is, which in a session launched from the
   repo root is the default branch in the primary checkout—a false green.
3. **Fast-forward-merge from the main checkout**—`git -C "$MAIN" merge --ff-only "$BRANCH"`. If it
   can't fast-forward, say so rather than forcing a merge commit.
4. **Push if private.** On a public repo, present the unpushed range (`origin/main..main`) and stop
   there; the user reads it before it publishes.

## 3. Landing in a fork—nothing to GitHub

The absolute rule:

> **No GitHub writes of any kind: no push (not even a spike branch to your own fork), no issues, no
> comments, no PRs, no `gh` write commands. Everything stays local until the user syncs.**

1. **Commit atomically on the feature branch**—decomposition-ordered, past-tense, one logical change
   each, in the target project's commit style. The branch and worktree are **left in place** for the
   user to review and sync; never merge or push them.
2. **Draft outreach as local files**—`NNN-issue-draft.md`, `NNN-pr-draft.md`,
   `NNN-comment-draft.md`, keyed by the upstream number once known and by the work's own ID before
   then, in whatever local notes directory the repo keeps them in. **Filing an issue, opening a PR,
   and posting a comment are the user's actions, never yours.**
3. **Record it done** through the backlog plugin, in a form that says how far the work got: built
   locally, drafted, filed, or merged upstream are different states to the person who has to sync
   it.

**Fetch upstream before designing, not just before filing.** `git fetch upstream` and diff
`HEAD..upstream/$DEFAULT` at the *start* of a session. A stacked or resumed branch skips the
"branched from upstream" check by construction, and a held branch keeps aging while it waits. The
likeliest overlap is the user's own earlier contributions, since those touch the code still being
worked in. If the diff is non-empty, read those commits before writing code: duplicating merged work
is a wasted branch at best, and a hand-rolled reimplementation of a public API at worst.

## 4. Wrap-up actions—every session, finished or not

**Release the claim, always—where the repo runs a claim ledger.** A session that never wrote a claim
has nothing to release here and skips to the next action; a session that did releases it whether or
not the work finished. The ledger leases *sessions*, not progress, and its reaper keys off
worktree-and-branch existence, so a claim held past its session is a lease nothing can ever expire,
on work no unattended run will ever touch again.

```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')   # re-derive—shell state doesn't persist across Bash calls
WT="$MAIN/.claude/worktrees/<the lane's worktree dir>"          # the path work-in-worktree set, written out literally
rm -f "$MAIN/.claude/claims/$(basename "$WT").json"             # keyed off the worktree dir, matching the reap
ls "$MAIN"/.claude/claims/                                      # confirm it's gone—rm -f on a wrong path succeeds silently
```

**Write `$WT` out; never re-derive it with `git rev-parse --show-toplevel`.** A session launched from
the repo root works the lane through absolute paths and leaves its cwd in the primary checkout, so
`--show-toplevel` returns `$MAIN`, the `rm -f` removes a claim file that never existed, and the real
claim leaks—held past its session, on a lane no unattended run will touch again.

**Unfinished work's resume record is its branch and worktree**, plus the backlog's pin when it
records one. Leave both standing, and name the branch in the wrap-up—that is what the next
session finds.

The rest, in order:

- **Stop stray background tasks.** A superseded search, an abandoned build or server: `TaskStop`
  each. A wrap-up delivered while a stray task is still running isn't a wrap-up. The task list
  tracks todos, not shells—check real processes (`pgrep -fl`) before claiming a session is clear.
- **Capture what belongs outside this session.** Durable conventions go to the repo's versioned
  docs; machine-local facts go to memory. Nothing that the repo already records.
- **Say what's left**, plainly, and where to do it: this session (it holds the context) or a fresh
  one (new scope, or this context has grown long). A fresh one gets a **launch snippet** in the
  format this plugin's `hooks/rules.md` specifies, plus the tier to run it at, named from
  `tier-model-and-effort` rather than from memory. Where the repo has a backlog plugin
  (`work-in-worktree` §0), its invocation is the snippet's entry point: it finds the in-flight work
  itself, so name the unfinished **branch** alongside it and leave the recap out.
- **Suggest a session title** if the session did substantive work, in the format this plugin's
  `hooks/rules.md` specifies—it loads at every session start, so the format is already in context.

`write-for-the-reader` owns how the wrap-up reads: what to include, what the reader can already see,
and why open items go as instructions rather than prose.
