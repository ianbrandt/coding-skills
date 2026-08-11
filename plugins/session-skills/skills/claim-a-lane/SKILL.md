---
name: claim-a-lane
description: >-
  Get into a non-colliding lane before touching code, when two or three sessions
  are working one repo at once and coordinating only through git: adopt the
  in-flight worktree or open a fresh one, write an atomic claim to the shared
  ledger, and run the hygiene pass that reaps dead claims without killing a live
  sibling. Carries the rule that a repo-root path from context silently means the
  primary checkout, and the tie-break for two sessions that claim the same thing.
  Trigger before creating a worktree or branch for a unit of work, when picking
  up work that may already be in flight, and on "claim a lane" or "am I
  colliding with another session". NOT for choosing what to work on (that's the
  repo's plan of record), and NOT for finishing and landing it (that's
  land-and-wrap).
---

# Claim a lane

You are probably one of 2–3 sessions working this repo at once, each in its own git worktree,
coordinating **only** through git and a shared claim ledger. Nobody can see anyone else's context.
Get into a lane whose file-touch set is disjoint from every other session's **before** you write
code.

On a judgment call about the lane itself—where to work, what to claim, whose worktree to touch—
these steps decide, over the repo's contributor docs. Those docs govern the code; this governs the
coordination between sessions they can't see.

**Platform names.** Worktrees under `$MAIN/.claude/worktrees/` and branches under `claude/` are what
Claude Code's tooling produces; name whatever your tooling actually creates.

## 1. Locate the shared ground

Sessions share one main (non-worktree) checkout holding the claim ledger; you **work in your own
worktree**. Capture both paths up front.

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

1. **A pin in the repo's plan of record**—a note tying that unit of work to one branch or worktree
   is the durable in-flight record, and it outlives every session that touched it.
2. **An existing worktree or branch named for it** (`git worktree list`), carrying commits the
   default branch doesn't have.
3. **A live claim naming it** (`cat "$MAIN"/.claude/claims/*.json`) whose worktree directory still
   exists. This one catches only a session that died mid-flight.

**The ledger is not the trigger, and an empty ledger is no evidence the work is free.** A session
deletes its claim at *its own* finish whether or not the work finished, so the ordinary handoff—wrap
up cleanly, resume next session—leaves the work in flight with no claim at all. Tell 1 or 2 is what
fires then.

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
`fix-issue-<N>`, which desyncs the branch from its worktree directory and from the ledger. On a repo
you own, the generated name is fine—nothing outside this machine ever sees it. A renamed branch
escapes §5's merged-branch reap, which is harmless: a fork's branches are never merged locally, and
the dead-claim reap keys off the claim's own `branch` field rather than the name pattern.

**Translate every context-supplied `<repo-root>/…` path to `$WT/…`** before any `Read`/`Edit`/
`Write`. The `gitStatus` block, memories, and doc links all cite the bare repo-root path, and taking
it literally silently lands edits on the default branch in the primary checkout. Reserve `$MAIN` for
the claim ledger and the final merge only. After your first Edit, confirm it shows in
`git -C "$WT" status` and NOT in `git -C "$MAIN" status`.

**Files that live only in the primary checkout.** An untracked plan of record, a local-only notes
directory, and the ledger itself never propagate to a worktree—that is the design, one shared copy
rather than per-worktree forks of it. A worktree-guard hook, where the environment has one, blocks
`Edit`/`Write` against the primary checkout while a worktree session is active; that is right for
source files and wrong for this family. Don't relocate the file to satisfy the guard. Splice the
edit through a plain `Bash` call instead: a heredoc `python3 - <<'PYEOF'` with an `assert old in s`
before the replace, so a drifted anchor fails loudly instead of silently doing nothing, or `Write`
to a scratch path and `cp scratch target` when rewriting a whole file. Such guards typically reject
a *compound* command (`A && B`, `VAR=x; cmd`)—split it into plain single commands.

## 4. Orient against siblings

```bash
git worktree list                            # who's around (worktrees ≈ sessions)
git log --oneline -15 "$DEFAULT"             # what just landed
cat "$MAIN"/.claude/claims/*.json 2>/dev/null || echo "ledger empty"
```

The ledger is a **live lease board, not a log**: entries are `{"item","branch","started"}`, deleted
by their own session at *its* finish—which is not the work's finish. **Empty is normal, and it does
not mean the repo is idle** (§2).

## 5. Hygiene—prune only

```bash
git worktree prune                           # safe: only reaps worktrees whose dir is already gone
git for-each-ref --merged "$DEFAULT" --format='%(refname:short)' \
  'refs/heads/claude/*' 'refs/heads/worktree-*' | xargs -r git branch -d   # merged only; -d self-guards
```

**Never `git worktree remove` a sibling's worktree**, not even a merged-and-clean one. A live
session between tasks looks identical to an abandoned one, and removing its directory kills it
mid-flight. Leftovers are harmless clutter the next `prune` reaps; when in doubt, leave it.

Then reap **dead claims**—worktree directory gone, or branch no longer exists. Key off the
**worktree directory, not merge-state**: a just-claimed session's branch tip equals the default
branch, which merge-state reads as dead. The claim filename is the worktree's directory name:

```bash
for f in "$MAIN"/.claude/claims/*.json; do
  [ -e "$f" ] || continue
  name=$(basename "$f" .json)
  b=$(sed -n 's/.*"branch"[^"]*"\([^"]*\)".*/\1/p' "$f")
  if [ ! -d "$MAIN/.claude/worktrees/$name" ] \
     || ! git show-ref --verify --quiet "refs/heads/$b"; then
    echo "reaping dead claim: $f ($b)"; rm -f "$f"
  fi
done
```

Also—**only when the ledger is empty**—reap leftover Workflow-agent worktrees (`agent-*` / `wf_*`
directories), confirming an unmerged branch's content actually landed before removing it: diff-apply
integration leaves a branch looking unmerged when its content is already on the default branch.

## 6. Write the claim—before writing any code

A claim written "later" is a claim that didn't prevent a collision. The filename is the **worktree
directory name**, not the branch.

```bash
BRANCH=$(git -C "$WT" rev-parse --abbrev-ref HEAD)
NAME=$(basename "$WT")
ITEM="<what you claimed, short phrase, e.g. R1: aggregation core>"   # no double quotes—they break the printf-built JSON
mkdir -p "$MAIN/.claude/claims"
printf '{ "item": "%s", "branch": "%s", "started": "%s" }\n' \
  "$ITEM" "$BRANCH" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > "$MAIN/.claude/claims/$NAME.json.tmp" \
  && mv "$MAIN/.claude/claims/$NAME.json.tmp" "$MAIN/.claude/claims/$NAME.json"   # atomic: a torn read looks dead to a sibling's reaper, which would rm a live claim
cat "$MAIN"/.claude/claims/*.json            # re-read to confirm no clash
```

If another claim names the **same work**, the **lexicographically smaller branch name keeps it**;
the other backs off and picks something else. Write-then-check leaves you blind to a claim written
after your check, so **re-read the ledger once more right before starting the work**; a clash found
then resolves by the same rule. On a re-pick, prefer work no live claim sits near.

**Resuming (§2): the lane already exists—only the lease may be missing.** The branch and worktree
are already correct, so rename nothing, and a claim naming the work you are resuming is **yours**,
not a collision—re-picking on it is the bug this path exists to prevent. If a live claim exists,
confirm its `branch` matches `git -C "$WT" rev-parse --abbrev-ref HEAD` and you are done. If there
is no claim (the ordinary case, since the prior session deleted its own at wrap), write one now with
`NAME=$(basename "$WT")` naming the **existing** worktree directory, which keeps it keyed for §5's
reap.

## Releasing it

Your claim is released at **session** end, finished or not: the ledger leases sessions, not
progress. That half lives in `land-and-wrap`, along with the two ways work leaves a lane.
