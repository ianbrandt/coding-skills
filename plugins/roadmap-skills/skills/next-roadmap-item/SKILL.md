---
name: next-roadmap-item
description: >-
  Use this skill to pick up the next piece of work on THIS repo's roadmap and
  start building it. Works in two modes, auto-detected: a versioned roadmap for
  repos you own (git history is the done-record), or a local-only shadow roadmap
  for an upstream OSS project you contribute to via a fork (nothing touches
  GitHub until you say so). If the repo has no roadmap yet, it bootstraps one
  first, asking about anything that isn't obvious. Trigger whenever the user
  wants to claim, grab,
  select, or start an unclaimed/next/disjoint roadmap item—phrasings like
  "tackle a roadmap item", "claim a task and get going", "knock out the next
  thing on the roadmap", or "kick things off without colliding with the other
  sessions/worktrees." An optional lane hint may ride along (an R-number or
  keyword, e.g. "/next-roadmap-item R1") to bias the pick—a preference only,
  never an override of the no-collision rules. Do NOT use it for merely reading
  or summarizing the roadmap, editing roadmap entries, running tests, or
  wrapping up an item that's already done.
---

# Next roadmap item—parallel-safe session cold-start

You're (probably) one of 2–3 Claude Code sessions working this repo at once, each in its own git
worktree, coordinating **only** through git and a shared claim ledger—sessions can't see each
other directly. This runbook gets you oriented and into a **non-colliding lane** before you touch
code, then hands off to normal TDD.

This skill runs in one of **two modes**, auto-detected in §0:

- **`versioned`**—a repo you own. The roadmap is a **tracked** file; landing an item is a
  commit that removes it, and **git history is the done-record** (no changelog). Work lands on
  `main` by fast-forward and is pushed.
- **`local`**—an upstream OSS project you contribute to **via a fork**. The roadmap and all its
  companion files are **untracked, local-only** (git-excluded), so upstream never sees them. There
  is no commit trail for the plan, so a **changelog** stands in as the done-record. Critically:
  **nothing is written to GitHub**—no push (not even to your fork), no issues, comments, or PRs.
  Issue/comment/PR text is **drafted as local files for you to review** and post by hand. You do
  every sync.

If the invocation carried a **lane hint** (any free text after the skill name—an R-number, a
sub-item, a keyword), it biases which item you pick in **step 4**. It's a preference, never a license
to collide: the unclaimed-and-disjoint gates and the claim tiebreaker still decide what you can
actually take.

This skill is the **authoritative runbook** for the cold-start mechanics—the prune-only worktree
tidy, the claim tiebreaker, the workflow-worktree reap. Where this repo has contributor docs
(`CLAUDE.md`, `CONTRIBUTING`, `docs/`), they carry the invariants; on a judgment call, these steps
decide. The parallel machinery (§1–3, §5–6) is identical in both modes; only where the roadmap
lives (§0, §4) and how an item lands (§8) differ.

## 0. Detect the mode and locate the roadmap
Mode is **self-describing**—read it off the working tree, don't guess. Check fork-ness **before**
looking for a tracked roadmap: an upstream project's own `ROADMAP.md` is *their* plan, not your
shadow roadmap, and must never flip a fork into `versioned` mode.
```bash
if [ -f ROADMAP.local.md ]; then
  MODE=local; ROADMAP=ROADMAP.local.md; HISTORY=ROADMAP-CHANGELOG.local.md
elif git remote get-url upstream >/dev/null 2>&1; then
  MODE=bootstrap                                     # a fork with no shadow roadmap yet—see §9
elif R=$(git ls-files ROADMAP.md docs/roadmap.md | head -1) && [ -n "$R" ]; then
  MODE=versioned; ROADMAP=$R                         # tracked roadmap ⇒ versioned (docs/ is legacy)
else
  MODE=bootstrap                                     # no roadmap anywhere—see §9
fi
echo "mode: $MODE  roadmap: ${ROADMAP:-<none>}"
```
- **`ROADMAP.local.md` present** ⇒ `local`. This correctly catches a fork whose `origin` is your
  own GitHub account (an `upstream` remote pushing to `no_push` is the fork tell) but whose work is
  still OSS.
- **An `upstream` remote but no shadow roadmap** ⇒ `bootstrap` (§9), regardless of any tracked
  `ROADMAP.md` the upstream project ships.
- **A git-tracked roadmap present** ⇒ `versioned`. Root `ROADMAP.md` is the convention;
  `docs/roadmap.md` is the legacy location—still honored, but worth migrating to the root family in
  a grooming commit when the ledger is empty.
- **None of the above** ⇒ `bootstrap`: set the repo up per §9.

**The roadmap family lives at the repo root, one naming rule for both modes.** Versioned:
`ROADMAP.md`, plus `ROADMAP-PARKED.md` / `ROADMAP-DECLINED.md`; no changelog—git history is the
done-record. Local: the same names with a `.local.md` suffix (`ROADMAP.local.md`,
`ROADMAP-PARKED.local.md`, `ROADMAP-DECLINED.local.md`), plus `ROADMAP-CHANGELOG.local.md`, which
exists only in local mode because it stands in for the git history upstream never sees. The
`.local.md` suffix is the never-commit signal, and it keeps a shadow roadmap from colliding with an
upstream project's real `ROADMAP.md`. Parked/declined files are created on first need, never as
empty stubs.

Everything below uses `$ROADMAP` for the plan and, in `local` mode, `$HISTORY` for the done-record.

## 1. Locate the shared ground—and confirm you're in YOUR worktree
All sessions share one main (non-worktree) checkout; the claim ledger lives under it. But you **work
in your own worktree**—capture BOTH paths up front so you never edit the primary by reflex.
```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')
BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
DEFAULT=${DEFAULT:-main}                    # the repo's integration branch (main/master/…)
if [ "$BRANCH" = "$DEFAULT" ]; then
  # Launched in the PRIMARY checkout (e.g. worktree mode unavailable)—open your own worktree
  # now and operate under it; never edit under $MAIN.
  NAME="<short-kebab-id>"                    # arbitrary pair (color-animal), NOT activity words like
                                             # "roadmap-lap"—every session picks those, and siblings collide
  while [ -d "$MAIN/.claude/worktrees/$NAME" ] \
     || git show-ref --verify --quiet "refs/heads/claude/$NAME"; do
    NAME="$NAME-$RANDOM"                     # taken by a sibling—suffix and retry
  done
  git worktree add "$MAIN/.claude/worktrees/$NAME" -b "claude/$NAME" "$DEFAULT"
  WT="$MAIN/.claude/worktrees/$NAME"
  BRANCH="claude/$NAME"                      # update—the capture above read the default branch
  echo "Opened worktree $WT (branch claude/$NAME)—work under it, NOT $MAIN."
else
  WT=$(git rev-parse --show-toplevel)        # YOUR worktree—edit/build only under here
fi
echo "worktree:      $WT"
echo "main checkout: $MAIN"
```
**Translate every context-supplied `<repo-root>/…` path to `$WT/…`** before handing it to a
`Read`/`Edit`/`Write`—the `gitStatus` block, recalled memories, and doc links all cite the bare
repo-root path, so it's the reflex that silently lands edits on the default branch in the primary.
`Bash` with paths relative to the worktree cwd is immune. Reserve `$MAIN` for the claim ledger and
the final ff-merge (versioned mode) **only**. After your first Edit, confirm with
`git -C "$WT" status` that the change shows there and NOT in `git -C "$MAIN" status`—catch a
mistranslation before it compounds.

## 2. Orient against siblings
```bash
git worktree list                            # who's around (worktrees ≈ sessions)
git log --oneline -15 "$DEFAULT"             # what just landed
cat "$MAIN"/.claude/claims/*.json 2>/dev/null || echo "ledger empty"
```
The ledger is a **live lease board**, not a log: each entry is `{"item","branch","started"}`, and a
session deletes its entry when it finishes. **Empty is normal**—it means nothing is in-flight right
now, not that the mechanism is broken. (You read it *before* you write your own claim, so a freshly
started sibling legitimately shows nothing yet.) In `local` mode the whole `.claude/` tree is
git-excluded (§9), so the ledger is invisible to upstream just like the roadmap.

## 3. Tidy stale worktrees—prune only
```bash
git worktree prune                           # safe: only reaps worktrees whose dir is already gone
git for-each-ref --merged "$DEFAULT" --format='%(refname:short)' \
  'refs/heads/claude/*' 'refs/heads/worktree-*' | xargs -r git branch -d   # merged only; -d self-guards
```
For sibling worktrees, prune is the whole step. `prune` touches only git's bookkeeping for worktrees
whose directory is already gone, so it can't disturb a live session. **Do not `git worktree remove` a
sibling's worktree**—not even a merged-and-clean one: a live session between tasks looks exactly the
same, and removing its directory kills it mid-flight (its commits survive in the shared `.git`, but
the running session loses its workspace, and active worktrees here aren't locked, so git won't
refuse). A dead session's leftover worktree is harmless clutter; the next `prune` reaps it once its
dir is gone. When in doubt, leave it.

The branch reap is self-guarding—`-d` refuses unmerged branches and any branch a live worktree has
checked out, so live sessions survive it automatically. Then reap **dead claims**—a claim from a
session that has exited (its worktree directory is gone) or whose branch no longer exists. Key off the
**worktree directory, not merge-state**: a just-started session that has claimed its lane but not yet
committed has a branch tip equal to the default branch, so it *looks* merged—reaping on merged-ness
alone would kill that live sibling. The claim filename is the worktree's directory name, so:
```bash
for f in "$MAIN"/.claude/claims/*.json; do
  [ -e "$f" ] || continue
  name=$(basename "$f" .json)
  b=$(sed -n 's/.*"branch"[^"]*"\([^"]*\)".*/\1/p' "$f")
  # dead if the session's worktree dir is gone (it exited), or its branch no longer exists
  if [ ! -d "$MAIN/.claude/worktrees/$name" ] \
     || ! git show-ref --verify --quiet "refs/heads/$b"; then
    echo "reaping dead claim: $f ($b)"; rm -f "$f"
  fi
done
```
Also—**only when the ledger is empty** (no live session ⇒ no live workflow)—reap leftover
**Workflow-agent worktrees** (`agent-*` / `wf_*` dirs), confirming an unmerged branch's content
actually landed before removing it (diff-apply integration leaves a branch looking unmerged).

## 4. Pick a disjoint, unclaimed item—honoring any lane hint
From `$ROADMAP`, choose an **unclaimed** item whose likely file-touch set is **disjoint** from
everything in the ledger—a different module, no shared core machinery. `$ROADMAP` is the unavoidable
shared seam (every session edits it at the end), so plan to keep those edits minimal, localized, and
last.

**Read the roadmap's own scoping.** `$ROADMAP` is the **active burndown**—each item is a claimable
to-do carrying a stable `Rn` ID (claimable sub-items `Rn.m`). Parked / deferred / declined /
out-of-scope work is **not pickable here**: it lives in the mode's `ROADMAP-PARKED` /
`ROADMAP-DECLINED` variant (§0's naming rule)—don't go fishing there. If the roadmap tags items with a
parallelism note (independent vs gated, plus the within-lane collision seam), honor it: prefer an
**independent** slice whose file-touch set is disjoint from every claimed one—disjointness is
**within-lane too**, not just "different module"; two sessions can collide inside one lane on a shared
file. Skip a *gated* item whose prerequisite hasn't landed (or claim the prerequisite instead).

**The roadmap is priority-ordered, top-down.** Items appear in descending priority/value, optionally
grouped into coarse bands (e.g. Now / Next / Later); `Rn` IDs are stable and carry no order, so R17
sitting above R3 is normal. **Absent a lane hint, take the topmost item that passes the gates
above.** New items are inserted at their priority position (end-of-band is fine), not appended at
the bottom. Wholesale reordering is grooming-only work, done when the claim ledger is empty—moving a
block is a delete-plus-insert that conflicts with any concurrent edit near either end, so never
reshuffle as a rider on a landing.

**If the invocation carried a lane hint, apply it here—as a preference, not an override.** The hint
is matched against the roadmap's item IDs (R-numbers) and headings. It only **reorders** the
candidates that already pass the unclaimed-and-disjoint gates above—it never relaxes them:
- **Hint matches an item that's unclaimed and disjoint** → take it.
- **Hinted item is claimed, or would collide on shared core machinery** → it's unavailable. Prefer a
  *disjoint sub-item within the same lane*; if there's none, fall back to normal disjoint selection.
  Either way, **say so out loud**—name the hinted item, why it couldn't be honored, and what you
  picked instead.
- **Hint matches nothing in the roadmap** (vague, stale, or already-landed) → note that briefly, then
  pick normally as if no hint were given.

If everything worthwhile is already claimed, don't force a collision—watch the ledger and the default
branch for a session to finish (its claim disappears / a new commit lands), then pick. A lane hint
doesn't change this.

**`local`-mode guardrails ride on the pick.** `$ROADMAP`'s header may flag items that **require the
user present** (typically the upstream-outreach and packaging items—filing issues, opening PRs,
maintainer-facing decisions). Those are **never claimable unattended**—skip them here; they are the
user's call, not work this skill performs (see §8's no-GitHub-writes rule).

## 5. Claim your lane—before writing any code
Writing the claim up front is what makes the ledger useful to siblings; a claim written "later" is a
claim that didn't prevent a collision. The filename is the **worktree directory name**—what the
step-3 reap keys off, not the branch—matching the existing entries.
```bash
BRANCH=$(git -C "$WT" rev-parse --abbrev-ref HEAD)   # e.g. claude/witty-fermi-1a2b3c
NAME=$(basename "$WT")                        # worktree dir name → flat filename (step 3's reap keys off this)
ITEM="<the roadmap item you picked, short phrase, e.g. R1: aggregation core>"   # no double quotes—they break the printf-built JSON
mkdir -p "$MAIN/.claude/claims"
printf '{ "item": "%s", "branch": "%s", "started": "%s" }\n' \
  "$ITEM" "$BRANCH" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > "$MAIN/.claude/claims/$NAME.json.tmp" \
  && mv "$MAIN/.claude/claims/$NAME.json.tmp" "$MAIN/.claude/claims/$NAME.json"   # atomic: a torn read of a half-written claim looks dead to a sibling's reaper (empty branch field), which would rm a live claim
cat "$MAIN"/.claude/claims/*.json            # re-read to confirm no clash
```
If another claim names the **same item**, the **lexicographically smaller branch name keeps it**; the
other backs off and re-picks (deterministic—so two sessions starting together can't both bounce onto
the same next item). The write-then-check leaves a writer blind to a claim written after its check—so
**re-read the ledger once more right before starting the work**; a clash found then resolves by the
same rule. On a re-pick, prefer an item no live claim sits near.

## 6. Suggest a descriptive session title—now that the lane is settled
The session started under a non-descriptive auto-title. As soon as the claim above lands (and any
tiebreaker re-pick has settled), **emit a session-title suggestion on its own line, in this exact
format**—a bold label, the title in straight quotes, nothing else on the line:

`**Session title:** "R1: aggregation core"`

Doing it this early is the point: a consistent, scannable line lets the user tell several concurrent
sessions apart at a glance while the work is in flight, and copy the quoted text straight into the
rename. Base the title on the item you just claimed—a short noun phrase naming the deliverable,
**spelled out with no abbreviations**. You will **re-emit this same line at session end** (§8),
revised only if the work's shape changed—so the format is byte-identical at both points.

## 7. Emit the tier plan—never pause
Model and effort are the **user's controls**; you cannot change them yourself—and you no longer need
them changed: **start building immediately, no pause, no end-of-turn checkpoint.** Sessions launch at
the everyday baseline (Opus + Medium) and the main loop stays there; this skill must run unattended.
Escalation happens through **delegation, not the session pickers**: per-agent overrides
(`agent(..., {model, effort})` in a Workflow, `model` on a plain Agent call) are explicit parameters
under your control.

Immediately after the title line, emit a one-line **tier plan**, then execute it. The deciding
question: **would this repo's test suite catch this item going silently wrong?** (If the repo has an
orchestration doc under `docs/`, defer to its tiering.)
- **Mechanical laps** (polish, doc moves, roadmap grooming)—inline at launch settings.
  `Tier plan: inline.`
- **Bounded, test-oracled feature work**—the §8 Workflow with per-stage overrides: mechanical
  stages at `effort: 'low'` or Sonnet, design and adversarial-verify stages at `'high'`.
- **Correctness-critical transform/rewrite machinery** (the suite would *not* catch silent
  wrongness)—design, implement-review, and adversarial-verify stages at `'xhigh'` on Opus.
  `Tier plan: Workflow—design@Opus+xhigh, implement@Sonnet+medium, adversarial-verify@Opus+xhigh.`
- **Fable is attended-only**—never auto-spawn it. The unattended ceiling is Opus + `'xhigh'` stages;
  work that genuinely wants Fable runs at the ceiling and is **flagged in the §8 wrap-up** for an
  attended revisit.

## 8. Build it, then land
Do the work **test-first per THIS repo's conventions**—write the failing test first, then match the
repo's own style:
- **`versioned`**: follow the repo's `CLAUDE.md` / `CONTRIBUTING` / design docs (test framework,
  formatting, module boundaries).
- **`local`**: follow the **House style block** in `$ROADMAP`'s header—the target project's
  conventions distilled from its `CONTRIBUTING` / `.editorconfig` / observed neighbors, since you have
  no `CLAUDE.md` of your own here. **Paste that block verbatim into every implementation-agent
  brief.** When in doubt, match the neighboring file, not your habits.

**Orchestrate substantial items.** If the claimed item is more than a trivial change, build it with the
**Workflow tool**—design → implement test-first → adversarial review → re-verify—scaled to its size.
*This instruction is itself the opt-in, so the orchestration runs even if the session never enabled
`ultracode`.* Keep genuinely small items (a one-file tweak, a doc move) inline. This gives ultracode's
*orchestration* only—not `xhigh` effort; for that, run `/effort ultracode`.

Then land per mode:

### 8a. `versioned`—land on the default branch
**Bring the docs, then delete the item from the roadmap.** Finishing an item includes updating all
applicable documentation as part of the work: the subsystem's design doc (the durable *why*) plus any
user-facing surface it touches. There is **no changelog**—git history is the done-record—so a landed
item is simply **deleted from `$ROADMAP`**, never migrated to a done-list and never annotated
"landed". (An item that turned out *parked* or *declined* moves to `ROADMAP-PARKED.md` /
`ROADMAP-DECLINED.md`, created on first need.)
Keep the roadmap deletion minimal and localized, in its own final commit.

At session end—**even if unfinished**—follow the repo's end-of-session merge protocol (a
`/land-session` runbook if it has one): rebase onto the default branch, do the risk-based post-rebase
build (re-build on shared-seam overlap; skip for a disjoint or docs/fixtures-only lap),
fast-forward-merge from the main checkout, push, then **delete your claim file**. Re-emit the §6
session-title line, revised only if the work's shape changed.
```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')   # re-derive—shell state doesn't persist across Bash calls
WT=$(git rev-parse --show-toplevel)
rm -f "$MAIN/.claude/claims/$(basename "$WT").json"             # keyed off the worktree dir, matching the reap
```

### 8b. `local`—land in the working tree, NOTHING to GitHub
This is the mode's defining rule, and it is **absolute**:

> **NO GitHub writes of any kind: no push (not even a spike branch to your own fork), no issues, no
> comments, no PRs, no `gh` write commands. Everything stays local until the user syncs.**

What you *do* on a finished item:
1. **Local atomic commits on your feature branch**—expected and encouraged (decomposition-ordered,
   past-tense, one logical change each), following the House style's commit convention. The branch and
   its worktree are **left in place** for the user to review and sync; you never merge or push them.
2. **Draft any outreach text as local files** under `spike-notes.local/`, for the user to review,
   refine, and post by hand. Key them by the upstream number once known, matching the reference
   layout: `NNN-issue-draft.md`, `NNN-pr-draft.md`, `NNN-comment-draft.md`; before a number exists,
   key by the `Rn` id. **Filing an issue, opening a PR, and posting a comment are the user's actions,
   never yours**—the roadmap's "requires user present" items (§4) are exactly these.
3. **Move the item out of the forward roadmap** (`$ROADMAP` is forward-only) and **append its
   done-record to `$HISTORY`** (`ROADMAP-CHANGELOG.local.md`). The changelog is a *reasoning
   archive*, not a bare landed-list: capture what commit messages won't—mechanism notes, corrections,
   refuted hypotheses, the local→upstream sha/number map, and "do-not-re-derive" findings—with a
   status keyword (`BUILT-LOCAL` / `DRAFTED` / `FILED` / `PR-READY` / `MERGED-UPSTREAM`). Free-form
   append; don't impose a rigid schema.
4. **Delete your claim file** (same command as 8a) and re-emit the §6 session-title line.

Local mode has no ff-merge, no build-gate-on-main, no push—there is no shared branch to land on. The
"landing" is entirely: local commits + drafts + roadmap/changelog update, then hands off to the user.

## 9. Bootstrapping a repo with no roadmap
Runs whenever §0 lands in `bootstrap`. This is the **one attended exception to §7's never-pause
rule**—a repo's first roadmap run is inherently attended, so **ask (AskUserQuestion) about anything
that isn't obvious** rather than guessing: which family, initial items, fork wiring, a gate command.
One-time setup; afterwards proceed from §1 if the new roadmap has items, otherwise report the
bootstrap and stop.

**Which family?** An `upstream` remote ⇒ `local` (§9a). No `upstream` remote and the user owns the
repo ⇒ `versioned` (§9b). Ambiguous—say, a direct clone of a project that may not be theirs—⇒ ask:
"versioned roadmap (a repo you own) or local shadow roadmap (an OSS project you contribute to)?"

### 9a. `local` family (OSS fork)

1. **Confirm the fork wiring**: `origin` = your GitHub fork, `upstream` = the real project, ideally
   with `git remote set-url --push upstream no_push` so a stray push can't reach upstream. If the
   remotes aren't wired that way (e.g. a direct clone of upstream), propose the rewiring and ask
   before touching remotes.
2. **Exclude the local-only artifacts** (per-clone, uncommitted—never touch the tracked `.gitignore`):
   ```bash
   printf '\n# Local-only planning artifacts (never commit/push upstream)\n/ROADMAP*.local.md\n/.claude/\n/spike-notes.local/\n' \
     >> .git/info/exclude
   mkdir -p spike-notes.local
   ```
3. **Stamp out `ROADMAP.local.md`** with a header that carries the per-repo config as prose (this
   header *is* the local-mode config—no separate file):
   - a one-line banner: local-only, excluded via `.git/info/exclude`, never commit or push; upstream
     sees issues/PRs, not this file;
   - **forward-only** note pointing landed work at `ROADMAP-CHANGELOG.local.md`;
   - the fork/upstream remote names;
   - the **binding guardrails**: the §8b no-GitHub-writes rule verbatim, and which items require the
     user present;
   - a **House style** section distilled from the project's `CONTRIBUTING`, `.editorconfig`, and a
     read of neighboring source (mechanical gate command, comment/KDoc conventions, test framework and
     naming, commit-message convention, em-dash and other prose rules)—to be pasted verbatim into every
     implementation-agent brief.
4. **Create `ROADMAP-CHANGELOG.local.md`** as the empty done-record companion. (`spike-notes.local/`
   still holds outreach drafts and spike notes—only the changelog moved to the root family.)
5. **Seed the items**: ask the user what the initial items are (scope is theirs to set—don't invent
   a plan from the codebase unasked), then write them in priority order with stable `Rn` IDs.

The `gradle-versions-plugin` fork is a worked reference for every one of these files (it may still
carry the legacy `spike-notes.local/roadmap-history.md` name for the changelog).

### 9b. `versioned` family (a repo you own)

1. **Stamp out root `ROADMAP.md`** with a short header: the `Rn` ID scheme (stable, never reused, an
   item keeps its ID for life; the claim unit is the item, sub-items `Rn.m`), the §4 priority-order
   rule (descending priority top-down; reshuffles are grooming-only), and a forward-only note
   (git history is the done-record—landed items are deleted, parked/declined items move to
   `ROADMAP-PARKED.md` / `ROADMAP-DECLINED.md`, created on first need).
2. **Seed the items**: same as §9a step 5—ask, then write with `Rn` IDs.
3. **Commit the roadmap on the default branch**—it's tracked; that's what makes the mode
   `versioned`.
