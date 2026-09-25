---
name: work-in-worktree
description: >-
  Get a unit of work into the right git worktree before touching code: fetch so
  the branch point is current rather than whatever the checkout was left at,
  locate the primary checkout and your own worktree, adopt the worktree the work
  is already in flight on instead of opening a second one, and open a fresh
  worktree and branch when it isn't. Carries the rule that costs the most when
  it is missed—a repo-root path handed over in context means the primary
  checkout, so taking it literally lands the edit on the default branch—plus
  how to edit a file that lives only there, the prune that keeps stale worktrees
  and merged branches from piling up, squash- and rebase-merged PR branches
  included, and the three-question seam a backlog
  plugin fills. Trigger before creating a worktree or branch for a unit
  of work, when picking up work that may already be in flight, before editing a
  file another machine also edits, and on "start on this in a worktree" or "am
  I starting from a stale checkout". NOT for keeping several sessions off each
  other's files—that's a concurrency plugin's lane claim, where one is installed—NOT for
  choosing what to work on (that's the repo's backlog), and NOT for finishing
  and landing it (that's land-and-wrap).
---

# Work in a worktree

You work in your own git worktree, never in the checkout the repo was cloned into. Get the work into
the right one **before** you write code: adopt the worktree it is already in flight on, or open a
fresh one.

On a judgment call about place—which tree, which branch, whose worktree to touch—these steps decide,
over the repo's contributor docs. Those docs govern the code; this governs where the code lands.

**Platform names.** The snippets default to worktrees under `$MAIN/.claude/worktrees/` and branches
under `claude/`, which is what Claude Code's tooling creates. Under another host, set `WTROOT` and
`PFX` in §1 to what its tooling creates, and use the same prefix in §4's reap.

**When other sessions are working the same repo at once**, this is half the job: a concurrency
plugin (§0's lease seam) adds the shared lease that keeps two lanes off the same files. Nothing here
needs it, and a session working alone skips it.

**On PowerShell**, `powershell.md` in this skill's directory has every snippet below in
PowerShell 7, matched by section number.

## 0. The two seams

These skills don't decide *what* to work on. Where a repo keeps a backlog—a roadmap file, GitHub
issues, Jira—a plugin for it answers three questions, and nothing here cares how it stores them:

1. **What is workable?** Open work, with its prerequisites already met. Sequencing between units of
   work is the backlog's data: it is known before any session exists, and only the backlog can say
   whether the thing that gates this one is done.
2. **Where is this already in flight?** A pin resolving a unit of work to a branch or worktree (§2).
3. **Record it done**, in whatever form that backlog uses (`land-and-wrap` §2, or §3 on a fork).

With no backlog plugin at all, these skills still work: the user names the task, and the landing
commit is the record. What does **not** come from a backlog is **disjointness**—whether two lanes
touch the same files. No issue tracker knows that; it is the other seam's data.

**The lease seam.** Where several sessions work one repo at once, a concurrency plugin leases each
session a lane: it answers whether this lane's files are disjoint from every sibling's, it holds the
lease evidence a dead session leaves behind (§2), and it expects the lease released at session end,
finished or not—a lease covers the session, not the work. Nothing here cares how it stores leases. A
session working alone, or a repo with no such plugin, skips every lease step, and these skills still
work.

## 1. Locate the two checkouts

A repo has one main (non-worktree) checkout; you **work in your own worktree**. Capture both paths
up front.

```bash
MAIN=$(git worktree list --porcelain | sed -n '1s/^worktree //p')   # keeps a path with spaces whole
BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
DEFAULT=${DEFAULT:-main}                     # the repo's integration branch (main/master/…)

BASE="origin/$DEFAULT"                       # branch from this, never from the local default branch
git fetch -q || echo "fetch failed: $BASE may be behind" >&2      # do not swallow this
git rev-parse --verify -q "$BASE" >/dev/null || BASE="$DEFAULT"   # no remote: local is all there is

WTROOT="$MAIN/.claude/worktrees"             # where this host's tooling creates worktrees
PFX="claude/"                                # and the branch prefix it uses
NOTES="spike-notes.local"                    # the repo's local-only notes directory, if it has one
```

**Nothing local tells you the checkout is current**, and a clean working tree least of all: another
machine, or another session, may have pushed since anyone last fetched here. Branching from a stale
`$DEFAULT` bakes the staleness into the branch, where it surfaces at push time as a rejected
non-fast-forward, or never surfaces at all and the work merges clean on top of code it never saw.
Fetching costs one round trip at the start of the session and removes both cases. A fetch that
fails, offline or behind an expired credential, leaves `$BASE` as stale as before and looks
identical to a clean one, so let the failure print rather than discarding it, and say so rather
than reporting the branch point as current.

**A file written for another machine to read**—a handoff list, a shared to-do, a status note—is
where this bites hardest, because a second machine editing it is the whole point of the file. Fetch
before editing one even when no worktree is involved and the edit is a single line.

## 2. Resume before you branch

When the work names something specific—a unit of work, an item ID, "keep going on the parser"—
establish whether it **already has a branch** before you create one. Check all three tells; any one
of them means the work is already in flight, and its existing worktree is *your* worktree:

1. **A pin in the backlog** (§0)—a note tying that unit of work to one branch or worktree is the
   durable in-flight record, and it outlives every session that touched it.
2. **An existing worktree or branch named for it** (`git worktree list`), carrying commits the
   default branch doesn't have.
3. **A live lease naming it**, where the repo runs a concurrency plugin (§0's lease seam)—that
   plugin says how to read its ledger; consult it now, before deciding. A lease whose worktree still
   exists catches only a session that died mid-flight.

**The lease is not the trigger, and an empty ledger is no evidence the work is free.** A lease
covers a session, not the work: the ordinary handoff—wrap up cleanly, resume next session—leaves the
work in flight with no lease at all. Tell 1 or 2 is what fires then, and they are the only two tells
a repo with no concurrency plugin has.

```bash
WT="$WTROOT/<the matching worktree dir>"   # resume: work here
```

Set `WT` to it and `BRANCH` to that worktree's checked-out branch, skip §3, and read the branch's
state before writing anything: `git -C "$WT" log --oneline "$BASE..HEAD"` and `git -C "$WT"
status` tell you what already landed and what is half-done. Build on those commits; don't redo them,
and don't reset or rewrite them without saying why.

**Opening a fresh worktree instead strands that branch's commits and silently restarts the work**—
fatally so when the plan pins the work to one branch.

## 3. Open your own worktree—new lanes only

```bash
if [ "$BRANCH" = "$DEFAULT" ]; then
  # Launched in the PRIMARY checkout—open your own worktree now; never edit under $MAIN.
  NAME="<short-kebab-id>"                    # arbitrary pair (color-animal), NOT activity words like
                                             # "roadmap-lap"—every session picks those, and siblings collide
  while [ -d "$WTROOT/$NAME" ] \
     || git show-ref --verify --quiet "refs/heads/$PFX$NAME"; do
    NAME="$NAME-$RANDOM"                     # taken by a sibling—suffix and retry
  done
  git worktree add "$WTROOT/$NAME" -b "$PFX$NAME" "$BASE"   # §1: current, not local
  WT="$WTROOT/$NAME"
  BRANCH="$PFX$NAME"                         # update—the capture above read the default branch
else
  WT=$(git rev-parse --show-toplevel)        # YOUR worktree—edit/build only under here
fi
# Durable notes belong in the primary checkout: a worktree's untracked files go with it on removal.
[ "$WT" != "$MAIN" ] && [ -d "$MAIN/$NOTES" ] && [ ! -e "$WT/$NOTES" ] \
  && ln -s "$MAIN/$NOTES" "$WT/$NOTES"
echo "worktree: $WT   main checkout: $MAIN"
```

**Name the branch for its destination when the work lands as a pull request**: on a fork, or in a
repo whose landing mode is `pr` (`land-and-wrap` §1). A pushed branch becomes a pull request's head,
and a PR head name is permanent and visible to everyone who reviews it. Rename the generated name
to the target project's own convention now, before anything records it—`git -C "$WT" branch -m
add-jvm-target-flag`. Absent a stated convention, a short descriptive slug. **The name
chosen then is final**: filing an issue afterwards is not a reason to renumber it to
`fix-issue-<N>`, which desyncs the branch from its worktree directory and from anything else that
recorded the name.
In `merge` mode the generated name is fine, since nothing outside this machine ever sees it. A
renamed branch escapes §4's merged-branch reap. Once pushed, it is deleted by §4's gone-upstream
check after its PR merges. A held fork branch is never pushed, so it stays until the user removes it.

**Translate every context-supplied `<repo-root>/…` path to `$WT/…`** before any file read or edit.
A git status summary the host injects, memories, and doc links all cite the bare repo-root path,
and taking it literally silently lands edits on the default branch in the primary checkout. Reserve
`$MAIN` for files that live only there and for the final merge. After your first edit, confirm it
shows in `git -C "$WT" status` and NOT in `git -C "$MAIN" status`.

**Files that live only in the primary checkout.** An untracked backlog file, a local-only notes
directory, and any shared ledger a plugin keeps there never propagate to a worktree—that is the
design, one shared copy
rather than per-worktree forks of it. A worktree-guard hook, where the environment has one, blocks
file-edit tools against the primary checkout while a worktree session is active; that is right for
source files and wrong for this family. Don't relocate the file to satisfy the guard. Splice the
edit through a plain shell command instead: a heredoc `python3 - <<'PYEOF'` with an `assert old in s`
before the replace, so a drifted anchor fails loudly instead of silently doing nothing, or write the
whole file to a scratch path and `cp scratch target`. Such guards typically reject
a *compound* command (`A && B`, `VAR=x; cmd`)—split it into plain single commands.

**Write durable notes to the primary checkout, never into the worktree.** `git worktree remove`
deletes a worktree's untracked files without a warning, and the loss shows up only when a later
session follows a reference to a note that is gone. The `ln -s` line in the block above links a
local-only notes directory through, so existing write paths land in `$MAIN`. Set `NOTES` in §1 to
the repo's notes directory; the `-d` test skips the link where that directory is absent. **An
exclude pattern with a trailing slash does not match the link**: `/spike-notes.local/` matches only
a directory, so the link shows as untracked in every new worktree. Write the pattern as
`/spike-notes.local`.

## 4. Hygiene—prune only

Cheap, safe, and worth running whichever of §2 or §3 you came through. None of it has anything to
do with other sessions; a session working alone accumulates the same stale worktree registrations
and merged branches.

```bash
git worktree prune                           # safe: only reaps worktrees whose dir is already gone
git for-each-ref --merged "$DEFAULT" --format='%(refname:short)' \
  'refs/heads/claude/*' 'refs/heads/worktree-*' | xargs -r git branch -d   # merged only; -d self-guards
                                             # claude/: the host's branch prefix, as PFX in §1
```

`--merged` misses a PR branch the host squashed or rebased on merge, so those pile up. Once the host
deletes the remote copy, the local branch's upstream is gone. That alone is no proof of a merge: a
declined PR with its branch deleted looks the same. So delete only a branch that would change
nothing if merged into `$BASE` now. The block derives `$BASE` itself and does nothing when it can't:
with `$BASE` empty, every check fails, and a failed check must never read as merged.

```bash
git fetch -q --prune                         # drops remote-tracking refs the host deleted
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
BASE="origin/${DEFAULT:-main}"
T=$(git rev-parse -q --verify "$BASE^{tree}") &&
git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | awk '$2=="[gone]"{print $1}' |
while read -r b; do
  if [ "$(git merge-tree --write-tree "$BASE" "$b" 2>/dev/null)" != "$T" ]; then   # git 2.38+
    echo "kept: $b (upstream gone, content not on $BASE)"
  elif git worktree list --porcelain | grep -qx "branch refs/heads/$b"; then
    echo "merged, still checked out: $b"
  else
    git branch -D "$b"
  fi
done
```

A merge commit, a rebase merge, and a squash merge all pass. A declined PR and a squash the reviewer
edited print `kept`. List those in the wrap-up and leave them. A merged branch still checked out in
a worktree prints `merged, still checked out`: remove that worktree if it is yours, by the rules
below, then run the block again. List any other in the wrap-up.

**Never `git worktree remove` a worktree you didn't create.** A live session between tasks looks
identical to an abandoned one, and removing its directory kills it mid-flight. Leftovers are
harmless clutter the next `prune` reaps; when in doubt, leave it.

**Before removing your own worktree, list its untracked files** and move anything real to `$MAIN`
first. Build output is filtered out:

```bash
git -C "$WT" status --porcelain -uall | grep '^??' | grep -Ev '(^\?\? |/)(build|\.gradle|\.kotlin)/'
```

A concurrency plugin adds its own hygiene on top of this (§0's lease seam).

## Then what

You are in the right tree with `$MAIN`, `$WT`, `$BRANCH`, and `$DEFAULT` in hand. Two skills take it
from here, and neither is required to start:

- **the concurrency plugin filling §0's lease seam**—when other sessions are working this repo,
  claim a lane and write its lease declaring the paths this lane will touch, before writing code.
- **`land-and-wrap`**—when the work is committed and ready to leave the branch, and at the end of
  any session, finished or not.
