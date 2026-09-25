---
name: land-and-wrap
description: >-
  Get finished work out of its worktree and close the session cleanly. Decides
  how work lands from facts about the repo itself—whether it is a fork of
  someone else's project, whether its origin is public, and whether its default
  branch takes direct pushes—rather than from the backlog it tracks work in:
  fast-forward into the default branch and push, merge but hold the push for
  review, push the branch and open a pull request, or stage locally and write
  nothing to the remote host. Each hold has a per-clone override.
  Then the wrap-up actions every session runs whether or not the work finished:
  release any lease, stop stray background tasks, leave a resume record. Trigger
  when work is committed and ready to leave its branch, and at the end of any
  session that opened a worktree. NOT for how a wrap-up should read (that's
  write-for-the-reader), and NOT for getting into the worktree in the first
  place (that's work-in-worktree).
---

# Land and wrap

Two separate jobs, and the second one runs even when the first doesn't: **landing** moves finished
work out of its worktree, and the **wrap-up** closes the session whether the work finished, stalled,
or was abandoned.

## 1. What decides how work lands

Read it off the repo, or off the per-clone `git config` values the user set; never from a file in
the tree.

```bash
git remote get-url upstream >/dev/null 2>&1 && echo "fork"        # someone else's project
URL=$(git remote get-url origin)
vis() { tr '[:upper:]' '[:lower:]' | grep -xE 'public|private|internal'; }   # drops CLI error text
VIS=$(git config --get session-skills.originVisibility | vis)     # set once per clone
[ -n "$VIS" ] || VIS=$(gh repo view "$URL" --json visibility -q .visibility 2>/dev/null | vis)
[ -n "$VIS" ] || VIS=$(glab repo view "$URL" -F json --jq .visibility 2>/dev/null | vis)
echo "origin: ${VIS:-unknown}"
```

- **A fork** (an `upstream` remote, ideally with `git remote set-url --push upstream no_push`) means
  the work is a contribution to a project you don't own. It **never merges and never pushes**, and
  **nothing reaches the remote host** (§3).
- **No `upstream`** means the repo is yours, and the work lands by its **landing mode** (below):
  `merge` fast-forwards it into the default branch, and `pr` pushes the branch and opens a pull
  request (both §2). The push depends on visibility: **private pushes; public holds** for the
  user's explicit go, because a public push is published under their name and can't be taken back.
  The user can lift that hold per clone (below).

The per-repo `git config` value comes first and works on any host. `gh` and `glab` are only
shortcuts, for a GitHub and a GitLab `origin`, and each is skipped when it is not installed or not
signed in to that host. A Bitbucket `origin` depends on the config value. With no value from any of
the three, **ask the user once** and record the reply, so no later session asks again:

```bash
git config session-skills.originVisibility private                # or public
```

Until the value is known, treat the repo as public and hold the push—the safe direction of a wrong
guess. Only `private` pushes; `internal` and anything else hold.

### The landing mode

A per-clone value comes first, then `gh` as a shortcut for a GitHub `origin`, skipped when it is not
installed or not signed in. A protected default branch means `pr`, and an unprotected one `merge`.
GitHub returns `protected` from its plain branch endpoint to any reader, while its protection
endpoint needs admin rights, so the check reads the first, plus the branch's rulesets:

```bash
URL=$(git remote get-url origin)
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
DEFAULT=${DEFAULT:-main}
MODE=$(git config --get session-skills.landing | grep -xE 'merge|pr')
PROT=
if [ -z "$MODE" ] && REPO=$(gh repo view "$URL" --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
  PROT=$(gh api "repos/$REPO/branches/$DEFAULT" --jq .protected 2>/dev/null)
  gh api "repos/$REPO/rules/branches/$DEFAULT" --jq '.[].type' 2>/dev/null | grep -qx pull_request && PROT=true
fi
case "$PROT" in true) MODE=pr ;; false) MODE=merge ;; esac
echo "landing: ${MODE:-unknown}"
```

GitLab gets no shortcut: it protects the default branch of every new project, so protection there
does not separate a team repo from a solo one. Where a Bitbucket MCP server is connected, a branch
restriction on the default branch means `pr`. Reading restrictions can need admin rights, and with
no answer the question below runs. A team that works through PRs on an unprotected branch sets the
value. With no answer from any of these, **ask the user once** and record the reply:

```bash
git config session-skills.landing pr                              # or merge
```

Until the mode is known, merge locally and hold the push. Both steps can be undone.

### Holds, and lifting them

The fork hold (§3), the public-push hold, and the wait for a PR's text (§2) are defaults. The user
can lift each one per clone. Set these only when the user says to, never on your own judgment. Read
one with `git config --get session-skills.holdFork`; only a literal `false` lifts it:

```bash
git config session-skills.holdPublicPush false    # a public origin pushes like a private one
git config session-skills.holdFork false          # a fork lands as a PR against upstream (§3)
git config session-skills.holdPrText false        # open a PR without first showing its text
```

These are independent of the backlog. A repo you own can track its work in an untracked, local-only
roadmap and still merge into its own default branch; that combination is ordinary, not a deviation.
Fork-ness and the landing mode decide whether work merges, and visibility and the holds decide
whether it is pushed.

## 2. Landing in a repo you own

**Bring the docs first.** Finishing includes every piece of documentation the change touches: the
subsystem's design doc (the durable *why*) plus any user-facing surface. Then **record it done**
through whatever backlog plugin the repo uses (`work-in-worktree` §0), in that backlog's own form. With
no backlog at all, the landing commit is the record and there is nothing else to write. Keep any
such edit minimal, localized, and in its own final commit—a backlog file is a collision seam every
other lane is also editing.

Follow the repo's end-of-session merge protocol if it has one (a repo-local landing skill or
runbook), otherwise land by the mode from §1.

### `merge`

1. **Rebase onto the default branch**—`git -C "$WT" rebase "$DEFAULT"`.
2. **Build, risk-based, from `$WT`**: rebuild when the rebase pulled in changes to a seam this work
   touches; skip it for a disjoint lap or one that moved only docs and fixtures. A bare `git rebase`
   or a bare build command targets whatever the shell's cwd is, which in a session launched from the
   repo root is the default branch in the primary checkout—a false green.
3. **Fast-forward-merge from the main checkout**—`git -C "$MAIN" merge --ff-only "$BRANCH"`. If it
   can't fast-forward, say so rather than forcing a merge commit.
4. **Push if private**, or with the public-push hold lifted (§1). Otherwise, on a public repo,
   present the unpushed range (`origin/main..main`) and stop there; the user reads it before it
   publishes.

### `pr`

1. **Check the branch name.** It becomes the PR head and stays on the host, so it should have
   been named for its destination when the worktree opened (`work-in-worktree` §3). If it still
   has a generated name, ask the user for one, rename it, and update the lease and any backlog pin
   that records the old name.
2. **Rebase onto the remote default branch**—`git -C "$WT" fetch -q && git -C "$WT" rebase
   "origin/$DEFAULT"`. The PR is reviewed against the remote, and the local default branch can lag
   it. For a branch already pushed, first bring in anything a reviewer pushed to it, such as an
   applied suggestion: `git -C "$WT" pull --rebase origin "$BRANCH"`.
3. **Build**, by the same rule as `merge` step 2.
4. **Push the branch**, under the visibility rule—`git -C "$WT" push -u origin "$BRANCH"`. Once a
   rebase has rewritten a pushed branch, add `--force-with-lease --force-if-includes`: the fetch in
   step 2 moves the lease's ref, so `--force-with-lease` alone would overwrite a reviewer's commit.
   On a public hold, present `git -C "$WT" log --oneline "origin/$DEFAULT..HEAD"` and stop there.
5. **Draft the title and body** in the repo's PR style, and show them in the reply. They **wait for
   the user's go**, on a private repo too, unless the hold is lifted (§1).
6. **Open the PR**—`gh pr create --base "$DEFAULT" --head "$BRANCH" --title "$TITLE" --body-file
   "$F"`, or `glab mr create -s "$BRANCH" -b "$DEFAULT" -t "$TITLE" --description-file "$F"`. With
   no host tool, as with a Bitbucket `origin` and plain git, write the title and body to a local
   file in the repo's notes directory, and give the user the create link from the `remote:` lines
   of the `git push` output.

The branch and worktree stay until the PR merges, since review fixes go on the same branch. A
backlog record kept in a tracked file rides in the PR and merges with it. One kept outside the tree
records the item as in review until the PR merges, so a declined PR leaves it open. Once the PR has
merged, the session holding its worktree removes it, by the rules in `work-in-worktree` §4, and that
section's cleanup then deletes the branch.

## 3. Landing in a fork—nothing to the remote host

The absolute rule:

> **No writes of any kind to the remote host—GitHub, GitLab, Bitbucket, or any other: no push (not
> even a spike branch to your own fork), no issues, no comments, no PRs or merge requests, no write
> commands from a host CLI (`gh`, `glab`, or another). Everything stays local until the user
> syncs.** The one exception is a fork hold the user lifted (`land-and-wrap` §1).

With `session-skills.holdFork false`, a fork lands like `pr` mode with the PR aimed at `upstream`: rebase onto `upstream/$DEFAULT`, build,
push the branch to `origin` under the visibility rule, then the same wait on the text. A fork of a
public project is usually public too, so its push still holds unless `holdPublicPush` is also
lifted. Open it with `gh pr create --repo <upstream owner/repo> --head <fork owner>:"$BRANCH"`, or
`glab mr create -R <upstream project> -H <fork project>`. The fork's branch gets a name for its
destination in `work-in-worktree` §3, before the first push. The steps below are the default.

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

**Release any lease you hold, always—where the repo runs a concurrency plugin** (`work-in-worktree`
§0's lease seam). A session that never wrote one has nothing to release and skips to the next action;
a session that did releases it whether or not the work finished. A lease covers the session, not the
work, and one held past its session blocks its lane for every unattended run until something expires
it.

**The plugin that owns the ledger carries the release step**—run it now. Identify the lane by the
`$WT` `work-in-worktree` set, **written out literally, never re-derived with `git rev-parse
--show-toplevel`**: a session launched from the repo root works the lane through absolute paths and
leaves its cwd in the primary checkout, so `--show-toplevel` returns `$MAIN`, and a release keyed off
the wrong tree removes nothing and leaks the real lease. Confirm the lease is gone before moving
on.

**Unfinished work's resume record is its branch and worktree**, plus the backlog's pin when it
records one. Leave both standing, and name the branch in the wrap-up—that is what the next
session finds.

The rest, in order:

- **Stop stray background tasks.** A superseded search, an abandoned build or server: stop each
  one, with the host's tool for background tasks where it has one (`TaskStop` in Claude Code), or
  by pid. A wrap-up delivered while a stray task is still running isn't a wrap-up. A todo list is
  not a process list—check real processes (`pgrep -fl`) before claiming a session is clear.
- **Capture what belongs outside this session.** Durable conventions go to the repo's versioned
  docs; machine-local facts go to memory. Nothing that the repo already records.
- **Say what's left**, plainly, and where to do it: this session (it holds the context) or a fresh
  one (new scope, or this context has grown long). A fresh one gets a **launch snippet** in the
  format this plugin's `hooks/rules.md` specifies, plus the tier to run it at, named from
  `tier-model-and-effort` where it is installed rather than from memory. Where the repo has a
  backlog plugin (`work-in-worktree` §0's backlog seam), its invocation is the snippet's entry
  point: it finds the in-flight work itself, so name the unfinished **branch** alongside it and
  leave the recap out.
- **Suggest a session title** if the session did substantive work, in the format this plugin's
  `hooks/rules.md` specifies—it loads at every session start, so the format is already in context.

How the wrap-up reads is covered in `write-for-the-reader`, where it is installed: what to include,
what the reader can already see, and why open items go as instructions rather than prose.
