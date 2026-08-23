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

**This skill fills `work-in-worktree` §0's lease seam**, and requires it. `work-in-worktree`, in
`session-skills`, locates `$MAIN` and `$WT`, adopts the worktree the work is already in flight on,
opens a fresh one otherwise, and prunes stale worktrees and merged branches in its §4. **If it is
not among the available skills, stop and tell the user to install `session-skills`**—nothing here
fails loudly without it, and no manifest enforces the dependency.

**Re-derive `$MAIN` here rather than inheriting it.** Shell state doesn't persist between calls, and
an unset `$MAIN` is the one failure this skill hides instead of raising: `cat
"$MAIN"/.claude/claims/*.json` on an empty variable globs against `/.claude/claims/`, matches
nothing, and falls through to the same "no claims" message a genuinely empty ledger prints. The
session then reads a repo full of live siblings as idle and claims a colliding lane. `$WT` is set by
`work-in-worktree`; unset, §3's first command fails loudly, which is the safe direction.

**Platform names.** Worktrees under `$MAIN/.claude/worktrees/` and claims under
`$MAIN/.claude/claims/` are what Claude Code's tooling produces; name whatever your tooling actually
creates.

## 1. Orient against siblings

```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')   # re-derive—see above; never inherit
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
DEFAULT=${DEFAULT:-main}
git worktree list                            # who's around (worktrees ≈ sessions)
git log --oneline -15 "$DEFAULT"             # what just landed
echo "ledger: $MAIN/.claude/claims"          # print the resolved path—a wrong $MAIN reads as an empty ledger
cat "$MAIN"/.claude/claims/*.json 2>/dev/null || echo "no claims"
```

**Read that path before reading the result.** If it came out as `/.claude/claims`, `$MAIN` didn't
resolve and the "no claims" line means nothing.

The ledger is a **live lease board, not a log**: entries are
`{"item","branch","started","session","touches"}`, deleted by their own session at *its* finish—which
is not the work's finish. **Empty is normal, and it does
not mean the repo is idle**; `work-in-worktree` §2 has the tells that do settle that.

## 2. Reap dead claims

The worktree prune and the merged-branch reap are `work-in-worktree` §4's—they have nothing to do
with siblings, and a session working alone needs them too. Run that first, then this.

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
ITEM="<what you claimed, short phrase, e.g. parser aggregation core>"  # no double quotes—they break the printf-built JSON
TOUCHES='["src/parser/**", "docs/parsing.md"]'                        # paths this lane expects to edit
SESSION="${CLAUDE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"           # stamped so this plugin's SessionEnd hook can release it
mkdir -p "$MAIN/.claude/claims"
printf '{ "item": "%s", "branch": "%s", "started": "%s", "session": "%s", "touches": %s }\n' \
  "$ITEM" "$BRANCH" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$TOUCHES" \
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
dependency manifest, and—where the backlog is a file in the repo—the backlog file itself. Keep edits to both minimal, localized, and last.

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

Your claim is released at **session** end, finished or not: the ledger leases sessions, not progress.
`land-and-wrap` §4 is the trigger; this is the step it runs.

```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')   # re-derive—shell state doesn't persist
rm -f "$MAIN/.claude/claims/$(basename "$WT").json"             # keyed off the worktree dir, matching §2's reap
ls "$MAIN"/.claude/claims/                                      # confirm—rm -f on a wrong path succeeds silently
```

`$WT` is the path `work-in-worktree` set, **written out literally**. Re-deriving it with `git
rev-parse --show-toplevel` returns `$MAIN` in a session launched from the repo root, so the `rm`
removes a file that never existed and the real claim leaks.

This plugin's `SessionEnd` hook releases any claim carrying this session's id when a session ends
without wrapping. It is the net, not the path: releasing at wrap hands the lane back immediately
rather than whenever the session eventually exits.

**Say out loud when the net isn't armed.** Restricted hooks make the release above the *only* path,
and a session that doesn't know that is the one that leaks a lease nothing can expire:

```bash
python3 -c 'import json,os
hits=[k for f in (os.path.expanduser("~/.claude/settings.json"),".claude/settings.json")
      for k in ("disableAllHooks","allowManagedHooksOnly")
      if os.path.exists(f) and json.load(open(f)).get(k)]
print("hooks RESTRICTED:",hits,"— SessionEnd net will not fire") if hits else print("no local hook restriction")'
```

**A clean result is not proof.** The same message names two causes this check cannot see—a managed
policy, and an untrusted workspace—and a malformed `hooks.json` loads a plugin with no hooks at all,
silently. So treat the net as best-effort in every session: release at wrap regardless, and when the
check does trip, name it in one line so nobody counts on a hook that is off.
