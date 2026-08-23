---
name: work-in-worktree
description: >-
  Get a unit of work into the right git worktree before touching code: locate
  the primary checkout and your own worktree, adopt the worktree the work is
  already in flight on instead of opening a second one, and open a fresh
  worktree and branch when it isn't. Carries the rule that costs the most when
  it is missed—a repo-root path handed over in context means the primary
  checkout, so taking it literally lands the edit on the default branch—plus
  how to edit a file that lives only there, the prune that keeps stale worktrees
  and merged branches from piling up, and the three-question seam a backlog
  plugin fills. Trigger before creating a worktree or branch for a unit
  of work, when picking up work that may already be in flight, and on "start on
  this in a worktree". NOT for keeping several sessions off each other's files
  (that's claim-a-lane, in parallel-session-skills), NOT for choosing what to
  work on (that's the repo's backlog), and NOT for finishing and landing it
  (that's land-and-wrap).
---

# Work in a worktree

You work in your own git worktree, never in the checkout the repo was cloned into. Get the work into
the right one **before** you write code: adopt the worktree it is already in flight on, or open a
fresh one.

On a judgment call about place—which tree, which branch, whose worktree to touch—these steps decide,
over the repo's contributor docs. Those docs govern the code; this governs where the code lands.

**Platform names.** Worktrees under `$MAIN/.claude/worktrees/` and branches under `claude/` are what
Claude Code's tooling produces; name whatever your tooling actually creates.

**When other sessions are working the same repo at once**, this is half the job. `claim-a-lane`, in
`parallel-session-skills`, adds the shared claim ledger that keeps two lanes off the same files.
Nothing here needs it, and a session working alone skips it.

## 0. The backlog seam

These skills don't decide *what* to work on. Where a repo keeps a backlog—a roadmap file, GitHub
issues, Jira—a plugin for it answers three questions, and nothing here cares how it stores them:

1. **What is workable?** Open work, with its prerequisites already met. Sequencing between units of
   work is the backlog's data: it is known before any session exists, and only the backlog can say
   whether the thing that gates this one is done.
2. **Where is this already in flight?** A pin resolving a unit of work to a branch or worktree (§2).
3. **Record it done**, in whatever form that backlog uses (`land-and-wrap` §2, or §3 on a fork).

With no backlog plugin at all, these skills still work: the user names the task, and the landing
commit is the record. What does **not** come from a backlog is **disjointness**—whether two lanes
touch the same files. No issue tracker knows that, so a claim ledger carries it, in `claim-a-lane`.

## 1. Locate the two checkouts

A repo has one main (non-worktree) checkout; you **work in your own worktree**. Capture both paths
up front.

```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')
BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
DEFAULT=${DEFAULT:-main}                     # the repo's integration branch (main/master/…)
```

## 2. Resume before you branch

When the work names something specific—a unit of work, an item ID, "keep going on the parser"—
establish whether it **already has a branch** before you create one. Check all three tells; any one
of them means the work is already in flight, and its existing worktree is *your* worktree:

1. **A pin in the backlog** (§0)—a note tying that unit of work to one branch or worktree is the
   durable in-flight record, and it outlives every session that touched it.
2. **An existing worktree or branch named for it** (`git worktree list`), carrying commits the
   default branch doesn't have.
3. **A live claim naming it** (`cat "$MAIN"/.claude/claims/*.json`), where the repo runs a claim
   ledger, whose worktree directory still exists. This one catches only a session that died
   mid-flight.

**The ledger is not the trigger, and an empty ledger is no evidence the work is free.** A session
deletes its claim at *its own* finish whether or not the work finished, so the ordinary handoff—wrap
up cleanly, resume next session—leaves the work in flight with no claim at all. Tell 1 or 2 is what
fires then, and they are the only two tells a repo with no ledger has.

```bash
WT="$MAIN/.claude/worktrees/<the matching worktree dir>"   # resume: work here
```

Set `WT` to it and `BRANCH` to that worktree's checked-out branch, skip §3, and read the branch's
state before writing anything: `git -C "$WT" log --oneline "$DEFAULT..HEAD"` and `git -C "$WT"
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
  while [ -d "$MAIN/.claude/worktrees/$NAME" ] \
     || git show-ref --verify --quiet "refs/heads/claude/$NAME"; do
    NAME="$NAME-$RANDOM"                     # taken by a sibling—suffix and retry
  done
  git worktree add "$MAIN/.claude/worktrees/$NAME" -b "claude/$NAME" "$DEFAULT"
  WT="$MAIN/.claude/worktrees/$NAME"
  BRANCH="claude/$NAME"                      # update—the capture above read the default branch
else
  WT=$(git rev-parse --show-toplevel)        # YOUR worktree—edit/build only under here
fi
echo "worktree: $WT   main checkout: $MAIN"
```

**Name the branch for its destination when the work targets a fork.** A branch pushed to a fork
becomes a pull request's head, and a PR head name is permanent and public. On a fork, rename the
generated name to the target project's own convention now, before anything records it—`git -C "$WT"
branch -m add-jvm-target-flag`. Absent a stated convention, a short descriptive slug. **The name
chosen then is final**: filing an issue afterwards is not a reason to renumber it to
`fix-issue-<N>`, which desyncs the branch from its worktree directory and from any claim naming it.
On a repo you own, the generated name is fine—nothing outside this machine ever sees it. A renamed
branch escapes `claim-a-lane`'s merged-branch reap, which is harmless: a fork's branches are never
merged locally, and the dead-claim reap keys off the claim's own `branch` field rather than the name
pattern.

**Translate every context-supplied `<repo-root>/…` path to `$WT/…`** before any `Read`/`Edit`/
`Write`. The `gitStatus` block, memories, and doc links all cite the bare repo-root path, and taking
it literally silently lands edits on the default branch in the primary checkout. Reserve `$MAIN` for
files that live only there and for the final merge. After your first Edit, confirm it shows in
`git -C "$WT" status` and NOT in `git -C "$MAIN" status`.

**Files that live only in the primary checkout.** An untracked backlog file, a local-only notes
directory, and a claim ledger never propagate to a worktree—that is the design, one shared copy
rather than per-worktree forks of it. A worktree-guard hook, where the environment has one, blocks
`Edit`/`Write` against the primary checkout while a worktree session is active; that is right for
source files and wrong for this family. Don't relocate the file to satisfy the guard. Splice the
edit through a plain `Bash` call instead: a heredoc `python3 - <<'PYEOF'` with an `assert old in s`
before the replace, so a drifted anchor fails loudly instead of silently doing nothing, or `Write`
to a scratch path and `cp scratch target` when rewriting a whole file. Such guards typically reject
a *compound* command (`A && B`, `VAR=x; cmd`)—split it into plain single commands.

## 4. Hygiene—prune only

Cheap, safe, and worth running whichever of §2 or §3 you came through. Neither command has anything
to do with other sessions; a session working alone accumulates the same stale worktree registrations
and merged branches.

```bash
git worktree prune                           # safe: only reaps worktrees whose dir is already gone
git for-each-ref --merged "$DEFAULT" --format='%(refname:short)' \
  'refs/heads/claude/*' 'refs/heads/worktree-*' | xargs -r git branch -d   # merged only; -d self-guards
```

**Never `git worktree remove` a worktree you didn't create.** A live session between tasks looks
identical to an abandoned one, and removing its directory kills it mid-flight. Leftovers are
harmless clutter the next `prune` reaps; when in doubt, leave it.

Where the repo runs a claim ledger, `claim-a-lane` §2 adds the dead-claim reap on top of this.

## Then what

You are in the right tree with `$MAIN`, `$WT`, `$BRANCH`, and `$DEFAULT` in hand. Two skills take it
from here, and neither is required to start:

- **`claim-a-lane`** (`parallel-session-skills`)—when other sessions are working this repo, orient
  against them and write a claim declaring the paths this lane will touch, before writing code.
- **`land-and-wrap`**—when the work is committed and ready to leave the branch, and at the end of
  any session, finished or not.
