---
name: claim-a-lane
description: >-
  Keep two or three sessions working one repo at once off each other's files,
  when they coordinate only through git: orient against the sibling sessions,
  run the hygiene pass that reaps dead claims without killing a live sibling,
  and write an atomic claim recording which paths this lane will touch. Two
  lanes collide when their declared paths overlap, which is the one fact no
  issue tracker can supply. Carries the tie-break for two sessions that claim
  the same thing, and the rule that a claim leases a session rather than the
  work. Trigger after getting into a worktree and before writing any code, when
  another session may be working the same repo, and on "claim a lane" or "am I
  colliding with another session". NOT for locating or opening the worktree
  itself (that's work-in-worktree, in session-skills), NOT for choosing what to
  work on (that's the repo's backlog), and NOT for finishing and landing it
  (that's land-and-wrap).
---

# Claim a lane

You are probably one of 2–3 sessions working this repo at once, each in its own git worktree,
coordinating **only** through git and a shared claim ledger. Nobody can see anyone else's context.
Claim a lane whose file-touch set is disjoint from every other session's **before** you write code.

On a judgment call about the lane itself—what to claim, whose worktree to touch—these steps decide,
over the repo's contributor docs. Those docs govern the code; this governs the coordination between
sessions they can't see.

**Get into the worktree first.** `work-in-worktree`, in `session-skills`, locates `$MAIN` and
`$WT`, adopts the worktree the work is already in flight on, and opens a fresh one otherwise. It
also carries the backlog seam this skill's disjointness check completes: a backlog says what is
workable and where it is in flight, and only the ledger says whether two units of work collide.
Everything below assumes `$MAIN`, `$WT`, and `$DEFAULT` are already set.

**Platform names.** Worktrees under `$MAIN/.claude/worktrees/` and claims under
`$MAIN/.claude/claims/` are what Claude Code's tooling produces; name whatever your tooling actually
creates.

## 1. Orient against siblings

```bash
git worktree list                            # who's around (worktrees ≈ sessions)
git log --oneline -15 "$DEFAULT"             # what just landed
cat "$MAIN"/.claude/claims/*.json 2>/dev/null || echo "ledger empty"
```

The ledger is a **live lease board, not a log**: entries are `{"item","branch","started"}`, deleted
by their own session at *its* finish—which is not the work's finish. **Empty is normal, and it does
not mean the repo is idle**; `work-in-worktree` §2 has the tells that do settle that.

## 2. Hygiene—prune only

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

## 3. Write the claim—before writing any code

A claim written "later" is a claim that didn't prevent a collision. The filename is the **worktree
directory name**, not the branch.

```bash
BRANCH=$(git -C "$WT" rev-parse --abbrev-ref HEAD)
NAME=$(basename "$WT")
ITEM="<what you claimed, short phrase, e.g. R1: aggregation core>"   # no double quotes—they break the printf-built JSON
TOUCHES='["src/parser/**", "docs/parsing.md"]'                       # paths this lane expects to edit
mkdir -p "$MAIN/.claude/claims"
printf '{ "item": "%s", "branch": "%s", "started": "%s", "touches": %s }\n' \
  "$ITEM" "$BRANCH" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TOUCHES" \
  > "$MAIN/.claude/claims/$NAME.json.tmp" \
  && mv "$MAIN/.claude/claims/$NAME.json.tmp" "$MAIN/.claude/claims/$NAME.json"   # atomic: a torn read looks dead to a sibling's reaper, which would rm a live claim
cat "$MAIN"/.claude/claims/*.json            # re-read to confirm no clash
```

**`touches` is what makes disjointness checkable instead of guessed.** Two lanes collide when any
path one expects to edit falls inside a glob the other declared—compare before claiming, and treat
an overlap as a collision even when the two units of work are unrelated. It is a declared intent,
not a measurement, so it will sometimes be wrong: **when the work spreads past what you declared,
rewrite the claim** (same atomic write) before editing the new paths. A lane that genuinely can't
predict its paths declares the broadest glob it might reach rather than a narrow lie.

Two files are collision seams almost everywhere and are worth declaring even for a one-line edit: a
dependency manifest, and the backlog file itself. Keep edits to both minimal, localized, and last.

If another claim names the **same work**, the **lexicographically smaller branch name keeps it**;
the other backs off and picks something else. Write-then-check leaves you blind to a claim written
after your check, so **re-read the ledger once more right before starting the work**; a clash found
then resolves by the same rule. On a re-pick, prefer work no live claim sits near.

**Resuming work already in flight: the lane already exists—only the lease may be missing.** The
branch and worktree are already correct, so rename nothing, and a claim naming the work you are
resuming is **yours**, not a collision—re-picking on it is the bug this path exists to prevent. If a
live claim exists, confirm its `branch` matches `git -C "$WT" rev-parse --abbrev-ref HEAD` and you
are done. If there is no claim (the ordinary case, since the prior session deleted its own at wrap),
write one now with `NAME=$(basename "$WT")` naming the **existing** worktree directory, which keeps
it keyed for §2's reap.

## Releasing it

Your claim is released at **session** end, finished or not: the ledger leases sessions, not
progress. That half lives in `land-and-wrap`, along with the two ways work leaves a lane.
