---
name: next-roadmap-item
description: >-
  Claim the next unclaimed, non-colliding item on THIS repo's roadmap and start
  building it. Two auto-detected modes: a versioned roadmap for a repo you own,
  or a local-only shadow roadmap for an upstream OSS fork (nothing reaches
  GitHub until you say so); bootstraps a roadmap if the repo has none. Trigger
  on "tackle a roadmap item", "claim a task and get going", or starting work
  without colliding with the other sessions. Also resumes an item already in
  flight and partially built—more building on an in-flight item is this skill,
  which adopts that item's existing worktree. An optional lane hint ("R1") only
  biases the pick.
  NOT for reading, summarizing, or editing the roadmap, or for wrapping up
  finished work that only needs landing.
---

# Next roadmap item—parallel-safe session cold-start

You're (probably) one of 2–3 sessions working this repo at once, each in its own git worktree,
coordinating **only** through git and a shared claim ledger. Get into a **non-colliding lane** before
touching code, then hand off to normal TDD.

Two **modes**, auto-detected in §0:

- **`versioned`**—a repo you own. The roadmap is **tracked**; landing an item is a commit that
  removes it, and **git history is the done-record** (no changelog). Work fast-forwards onto the
  default branch and is pushed.
- **`local`**—an upstream OSS project you contribute to **via a fork**. The roadmap and companions
  are **untracked and git-excluded**; a **changelog** is the done-record. **Nothing is written to
  GitHub** (§8b); outreach text is drafted as local files for the user to post. You do every sync.

§1–3 and §5–7 are mode-independent; only the roadmap's location (§0, §4) and how an item lands (§8)
differ. On a judgment call these steps decide, over the repo's contributor docs.

**Platform names.** Worktrees under `$MAIN/.claude/worktrees/` and branches under `claude/` are what
Claude Code's tooling produces; name whatever your tooling actually creates.

## 0. Detect the mode and locate the roadmap
Read the mode off the working tree. Check fork-ness **before** a tracked roadmap—an upstream
project's own `ROADMAP.md` must never flip a fork into `versioned`.
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
```
An `upstream` remote (ideally pushing to `no_push`) is the fork tell, so `local` is caught even when
`origin` is your own account. Migrate a legacy `docs/roadmap.md` to the root family in a grooming
commit when the ledger is empty.

**Naming, repo root, both modes.** Versioned: `ROADMAP.md`, `ROADMAP-PARKED.md`,
`ROADMAP-DECLINED.md`; no changelog. Local: the same names suffixed `.local.md` (the never-commit
signal, and it avoids colliding with upstream's real `ROADMAP.md`), plus
`ROADMAP-CHANGELOG.local.md`. Parked/declined files are created on first need, never as empty stubs.
Below, `$ROADMAP` is the plan; in `local` mode `$HISTORY` is the done-record.

**These files exist ONLY in the primary (non-worktree) checkout**, untracked, so
they never propagate to a worktree—`ls ROADMAP*.local.md` from `$WT` finds
nothing, by design: one shared plan of record, not per-worktree copies. A
worktree-guard hook, if the environment has one, typically blocks `Edit`/`Write`
whose target is under the primary checkout while a worktree session is active—
right for source files, wrong for this family, since the primary is the only
place it lives. Don't fight the guard by trying to relocate the roadmap: splice
the edit via a plain `Bash` call instead (a heredoc `python3 - <<'PYEOF'` with an
`assert old in s` before the replace, so a drifted anchor fails loudly rather
than silently no-op'ing; or Write to a scratch path and `cp scratch target`,
which is easier than a heredoc for rewriting a whole file). What such a guard
typically rejects is a *compound* command (`A && B`, `VAR=x; cmd`)—split it into
plain single commands.

## 1. Locate the shared ground—and confirm you're in YOUR worktree
Sessions share one main (non-worktree) checkout holding the claim ledger; you **work in your own
worktree**. Capture both paths up front.
```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')
BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
DEFAULT=${DEFAULT:-main}                     # the repo's integration branch (main/master/…)
```
**Fetch upstream before designing anything, not just before filing.** In `local`
mode, `git fetch upstream` and diff `HEAD..upstream/$DEFAULT` at the start of the
session, before picking or resuming an item—not only when you go to file the
result. A stacked or resumed branch skips the "branch from `upstream/$DEFAULT`"
check by construction, and a held branch keeps aging while it waits; the likeliest
overlap is your own prior PRs, since they touch the code you're still working in.
If the diff is non-empty, read those commits before writing code—duplicating work
upstream already merged is a wasted branch at best and a hand-rolled reimplementation
of a public API at worst.

**Resume before you branch.** When the run names a specific item—a lane hint, or "keep going on R3"—
establish whether that item already has a branch **before** you create one. Check all three tells; any
one of them means the item is **already in flight**, and its existing worktree is *your* worktree:
1. **The item's own text in `$ROADMAP`**—a build rule pinning the item to one branch/worktree is the
   durable in-flight record, and it outlives every session that touched it.
2. **An existing worktree or branch named for the item** (`git worktree list`), carrying commits the
   default branch doesn't have.
3. **A live claim naming the item** (`cat "$MAIN"/.claude/claims/*.json`) whose worktree directory
   still exists. This one catches only a session that died mid-flight.

**The ledger is not the trigger, and an empty ledger is no evidence the item is free.** A session
deletes its claim at *its own* finish whether or not the item finished (§8), so the ordinary
handoff—wrap up cleanly, resume next session—leaves the item in flight with no claim at all. Tell 1 or
2 is what fires then.
```bash
WT="$MAIN/.claude/worktrees/<the matching worktree dir>"   # resume: work here
```
Set `WT` to it, `BRANCH` to that worktree's checked-out branch, skip the worktree creation below, and go
to §4's resume path. **Opening a fresh worktree instead strands that branch's commits and silently
restarts the item**—fatally so when a roadmap build rule pins the item to one branch. The block below is
for a *new* lane only.
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
**Translate every context-supplied `<repo-root>/…` path to `$WT/…`** before any `Read`/`Edit`/
`Write`—the `gitStatus` block, memories, and doc links all cite the bare repo-root path, and that
reflex silently lands edits on the default branch in the primary. Reserve `$MAIN` for the claim
ledger and the final ff-merge (versioned) **only**. After your first Edit, confirm it shows in
`git -C "$WT" status` and NOT in `git -C "$MAIN" status`.

## 2. Orient against siblings
```bash
git worktree list                            # who's around (worktrees ≈ sessions)
git log --oneline -15 "$DEFAULT"             # what just landed
cat "$MAIN"/.claude/claims/*.json 2>/dev/null || echo "ledger empty"
```
The ledger is a **live lease board**, not a log: entries are `{"item","branch","started"}`, deleted by
their own session at *its* finish—which is not the item's finish. **Empty is normal, and it does not
mean the roadmap is idle** (§1). In `local` mode the whole `.claude/` tree is
git-excluded (§9a).

## 3. Tidy stale worktrees—prune only
```bash
git worktree prune                           # safe: only reaps worktrees whose dir is already gone
git for-each-ref --merged "$DEFAULT" --format='%(refname:short)' \
  'refs/heads/claude/*' 'refs/heads/worktree-*' | xargs -r git branch -d   # merged only; -d self-guards
```
**Never `git worktree remove` a sibling's worktree**, not even a merged-and-clean one—a live session
between tasks looks identical, and removing its directory kills it mid-flight. Leftovers are harmless
clutter the next `prune` reaps; when in doubt, leave it.

Then reap **dead claims**—worktree dir gone, or branch no longer exists. Key off the **worktree
directory, not merge-state**: a just-claimed session's branch tip equals the default branch, which
merge-state would read as dead. The claim filename is the worktree's directory name:
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
Also—**only when the ledger is empty**—reap leftover **Workflow-agent worktrees** (`agent-*` / `wf_*`
dirs), confirming an unmerged branch's content actually landed before removing it (diff-apply
integration leaves a branch looking unmerged).

## 4. Pick a disjoint, unclaimed item—honoring any lane hint
Choose an **unclaimed** item from `$ROADMAP` whose likely file-touch set is **disjoint** from
everything in the ledger—different module, no shared core machinery. `$ROADMAP` itself is the
unavoidable shared seam: keep those edits minimal, localized, and last.

- **Only the active burndown is pickable.** Items are claimable to-dos with stable `Rn` IDs (sub-items
  `Rn.m`). Parked / deferred / declined / out-of-scope work lives in the mode's `ROADMAP-PARKED` /
  `ROADMAP-DECLINED` variant—don't go fishing there.
- **Honor any parallelism note** the roadmap tags items with (independent vs gated, plus the
  within-lane collision seam): prefer an **independent** slice. Disjointness is **within-lane too**.
  Skip a *gated* item whose prerequisite hasn't landed, or claim the prerequisite instead.
- **The roadmap is priority-ordered, top-down**, optionally in coarse bands (Now / Next / Later);
  `Rn` IDs carry no order, so R17 above R3 is normal. **Absent a lane hint, take the topmost item
  that passes these gates.** Insert new items at their priority position (end-of-band is fine).
  Wholesale reordering is grooming-only work for an empty ledger—never a rider on a landing.
- **`local` mode: items `$ROADMAP`'s header flags as requiring the user present** (typically upstream
  outreach and packaging) are **never claimable unattended**. Skip them (§8b).

**A lane hint (free text after the skill name—an R-number, sub-item, or keyword) reorders candidates
that already pass those gates; it never relaxes them.** Match it against item IDs and headings:
- unclaimed and disjoint → take it;
- claimed or colliding → prefer a *disjoint sub-item in the same lane*, else fall back to normal
  selection. Either way **say so out loud**—the hinted item, why it couldn't be honored, what you
  picked instead;
- matches nothing → note that briefly, then pick as if unhinted.

If everything worthwhile is claimed, don't force a collision: wait for a session to finish (its claim
disappears / a commit lands), then pick. A hint doesn't change this.

**Resuming an item already in flight (§1).** The pick is already made—skip the selection gates; a claim
on the item you're resuming is *yours*, not a collision. Before writing any code, **read the branch's
state**: `git -C "$WT" log --oneline "$DEFAULT..HEAD"` and `git -C "$WT" status` tell you what already
landed and what's half-done. Build on those commits; don't redo them, and don't reset or rewrite them
without saying why. Then continue at §7 (§5's claim already exists, §6's title is already set—re-emit
it unchanged).

## 5. Claim your lane—before writing any code
**Resuming (§1/§4): the lane already exists—only the lease may be missing.** The branch and worktree are
already correct: rename nothing (a local-mode rename would desync the branch from the ledger and the
worktree directory), and re-picking on a "clash" with your own item is the bug this path exists to
prevent. Then, for the claim:
- **A live claim for the item exists** (§1 tell 3)—confirm its `branch` matches `git -C "$WT" rev-parse
  --abbrev-ref HEAD` and skip the rest of this section.
- **No claim** (the ordinary case—the prior session deleted its own at wrap)—write one now with the
  block below. `NAME=$(basename "$WT")` names the **existing** worktree directory, which keeps it keyed
  for §3's reap; skip the tiebreaker re-pick, since a claim you find on your own item is yours.

**`local` mode: rename the branch first**—it becomes the PR head the user pushes, and a PR head name
is permanent and public. Rename now that the item is known (§4), before anything below records the
name, following the target project's own branch naming per the **House style block** in `$ROADMAP`'s
header (§8b, §9a). Absent a stated convention, a short descriptive slug (`add-jvm-target-flag`).

**The name chosen here is final.** Filing an upstream issue afterwards is *not* a reason to rename to
`fix-issue-<N>`—that desyncs the branch from its worktree directory and invalidates the name already
recorded in the ledger, the changelog, and any sibling's notes. The issue number belongs in the commit
summary and the draft filenames.
```bash
if [ "$MODE" = "local" ]; then
  git -C "$WT" branch -m "<house-style name>"    # e.g. add-jvm-target-flag
fi
```
A renamed branch escapes step 3's merged-branch reap—harmless, since local-mode branches are never
merged (§8b). The dead-claim reap keys off the claim's `branch` field.

Claim up front: a claim written "later" is a claim that didn't prevent a collision. The filename is
the **worktree directory name**, not the branch.
```bash
BRANCH=$(git -C "$WT" rev-parse --abbrev-ref HEAD)   # generated placeholder (versioned), or the renamed one (local)
NAME=$(basename "$WT")
ITEM="<the item you picked, short phrase, e.g. R1: aggregation core>"   # no double quotes—they break the printf-built JSON
mkdir -p "$MAIN/.claude/claims"
printf '{ "item": "%s", "branch": "%s", "started": "%s" }\n' \
  "$ITEM" "$BRANCH" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > "$MAIN/.claude/claims/$NAME.json.tmp" \
  && mv "$MAIN/.claude/claims/$NAME.json.tmp" "$MAIN/.claude/claims/$NAME.json"   # atomic: a torn read looks dead to a sibling's reaper, which would rm a live claim
cat "$MAIN"/.claude/claims/*.json            # re-read to confirm no clash
```
If another claim names the **same item**, the **lexicographically smaller branch name keeps it**; the
other backs off and re-picks. Write-then-check leaves you blind to a claim written after your check,
so **re-read the ledger once more right before starting the work**; a clash found then resolves by
the same rule. On a re-pick, prefer an item no live claim sits near.

## 6. Suggest a descriptive session title—now that the lane is settled
As soon as the claim lands and any tiebreaker re-pick settles, **emit a session-title suggestion on
its own line, in this exact format**—bold label, straight quotes, nothing else on the line:

`**Session title:** "R1: aggregation core"`

Base it on the item just claimed—a short noun phrase naming the deliverable, **spelled out with no
abbreviations**. **Re-emit this same line at session end** (§8), revised only if the work's shape
changed—byte-identical format at both points.

## 7. Emit the tier plan—never pause
Model and effort are the **user's controls**: **start building immediately, no pause, no end-of-turn
checkpoint.** Sessions launch at the everyday baseline (Opus + Medium) and the main loop stays there.
Escalate by **delegation, not the session pickers**—per-agent overrides (`agent(..., {model, effort})`
in a Workflow, `model` on a plain Agent call).

Immediately after the title line, emit a one-line **tier plan**, then execute it. The deciding
question: **would this repo's test suite catch this item going silently wrong?** (Defer to any
orchestration doc under `docs/`.) Model is the stage's capability class, effort its deliberation need.
Haiku takes mechanical stages only where failure is loud (tests, compile, a verifiable count); a stage
that could fail silently is never mechanical. Formats:
- **Mechanical laps** (polish, doc moves, roadmap grooming)—inline at launch settings.
  `Tier plan: inline.`
- **Bounded, test-oracled feature work**—the §8 Workflow with per-stage overrides.
  `Tier plan: Workflow—design@Opus+high, implement@Sonnet+medium, docs@Haiku+low, adversarial-verify@Opus+high.`
- **Correctness-critical transform/rewrite machinery**, where the suite would *not* catch silent
  wrongness—design, implement-review, and adversarial-verify at `xhigh`.
  `Tier plan: Workflow—design@Opus+xhigh, implement@Sonnet+medium, adversarial-verify@Opus+xhigh.`
- **Apex-grade work**—the hardest analysis, design, and adversarial-review stages, where being wrong
  is expensive and the suite won't catch it—runs **those stages** on **Fable**, unattended, no
  authorization needed. Fable burns roughly 4X Opus: aim it at the stage that needs it; implement and
  mechanical stages stay at their usual tiers.
  `Tier plan: Workflow—design@Fable+xhigh, implement@Sonnet+medium, adversarial-verify@Fable+xhigh.`

## 8. Build it, then land
Work **test-first per THIS repo's conventions**—failing test first, then match the repo's own style:
- **`versioned`**: the repo's `CLAUDE.md` / `CONTRIBUTING` / design docs.
- **`local`**: the **House style block** in `$ROADMAP`'s header, distilled from the project's
  `CONTRIBUTING` / `.editorconfig` / observed neighbors. **Paste that block verbatim into every
  implementation-agent brief.** When in doubt, match the neighboring file, not your habits.

**Orchestrate substantial items** with the **Workflow tool**—design → implement test-first →
adversarial review → re-verify—scaled to size. *This instruction is itself the opt-in, so the
orchestration runs even if the session never enabled `ultracode`*; it grants *orchestration* only, not
`xhigh` effort. Keep genuinely small items (a one-file tweak, a doc move) inline.

**Your claim is released at session end even when the item isn't finished**—both arms below, no
exception. The ledger leases *sessions*, not progress, and §3's reaper keys off worktree-and-branch
existence, so a claim held past its session is a lease nothing can ever expire and an item
`execute-roadmap` will never touch again. **An unfinished item's resume record is its branch and
worktree**, plus the pin in `$ROADMAP` when its build rule names one: leave both standing, say in the
wrap-up which branch the item sits on, and §1 finds it next session.

### 8a. `versioned`—land on the default branch
**Bring the docs, then delete the item from the roadmap.** Finishing an item includes updating all
applicable documentation: the subsystem's design doc (the durable *why*) plus any user-facing surface
it touches. There is **no changelog**—a landed item is **deleted from `$ROADMAP`**, never migrated to
a done-list, never annotated "landed" (an item that turned out *parked* or *declined* moves to
`ROADMAP-PARKED.md` / `ROADMAP-DECLINED.md`, created on first need). Keep that deletion minimal and
localized, in its own final commit.

At session end—**even if unfinished**—follow the repo's end-of-session merge protocol (a
`/land-session` runbook if it has one): rebase onto the default branch, do the risk-based post-rebase
build (re-build on shared-seam overlap; skip for a disjoint or docs/fixtures-only lap),
fast-forward-merge from the main checkout, push **if the repo is private**—a public repo's push waits
for the user's explicit go, so present the unpushed range instead—then **delete your claim file** and
re-emit the §6 session-title line.
```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')   # re-derive—shell state doesn't persist across Bash calls
WT=$(git rev-parse --show-toplevel)
rm -f "$MAIN/.claude/claims/$(basename "$WT").json"             # keyed off the worktree dir, matching the reap
```

### 8b. `local`—land in the working tree, NOTHING to GitHub
The mode's defining rule, **absolute**:

> **NO GitHub writes of any kind: no push (not even a spike branch to your own fork), no issues, no
> comments, no PRs, no `gh` write commands. Everything stays local until the user syncs.**

On a finished item:
1. **Local atomic commits on your feature branch**—decomposition-ordered, past-tense, one logical
   change each, per the House style's commit convention. Branch and worktree are **left in place** for
   the user to review and sync; never merge or push them.
2. **Draft any outreach text as local files** under `spike-notes.local/`: `NNN-issue-draft.md`,
   `NNN-pr-draft.md`, `NNN-comment-draft.md`, keyed by the upstream number once known, by the `Rn` id
   before then. **Filing an issue, opening a PR, and posting a comment are the user's actions, never
   yours**—the roadmap's "requires user present" items (§4) are exactly these.
3. **Move the item out of the forward-only `$ROADMAP`** and **append its done-record to `$HISTORY`**.
   The changelog is a *reasoning archive*, not a bare landed-list: capture what commit messages
   won't—mechanism notes, corrections, refuted hypotheses, the local→upstream sha/number map,
   "do-not-re-derive" findings—with a status keyword (`BUILT-LOCAL` / `DRAFTED` / `FILED` /
   `PR-READY` / `MERGED-UPSTREAM`). Free-form append; no rigid schema.
4. **Delete your claim file** (same command as 8a) and re-emit the §6 session-title line.

Local mode has no ff-merge, no build-gate-on-main, no push.

## 9. Bootstrapping a repo with no roadmap
Runs whenever §0 lands in `bootstrap`—the **one attended exception to §7's never-pause rule**: **ask
(AskUserQuestion) about anything that isn't obvious** rather than guessing (which family, initial
items, fork wiring, a gate command). One-time setup; afterwards proceed from §1 if the new roadmap has
items, otherwise report the bootstrap and stop.

**Which family?** An `upstream` remote ⇒ `local` (§9a). No `upstream` remote and the user owns the
repo ⇒ `versioned` (§9b). Ambiguous ⇒ ask: "versioned roadmap (a repo you own) or local shadow
roadmap (an OSS project you contribute to)?"

### 9a. `local` family (OSS fork)
1. **Confirm the fork wiring**: `origin` = your GitHub fork, `upstream` = the real project, ideally
   with `git remote set-url --push upstream no_push`. If the remotes aren't wired that way, propose
   the rewiring and ask before touching remotes.
2. **Exclude the local-only artifacts** (per-clone, uncommitted—never touch the tracked `.gitignore`):
   ```bash
   printf '\n# Local-only planning artifacts (never commit/push upstream)\n/ROADMAP*.local.md\n/.claude/\n/spike-notes.local/\n' \
     >> .git/info/exclude
   mkdir -p spike-notes.local
   ```
3. **Stamp out `ROADMAP.local.md`** with a header carrying the per-repo config as prose—this header
   *is* the local-mode config:
   - a one-line banner: local-only, excluded via `.git/info/exclude`, never commit or push;
   - a **forward-only** note pointing landed work at `ROADMAP-CHANGELOG.local.md`;
   - the fork/upstream remote names;
   - the **binding guardrails**: §8b's no-GitHub-writes rule verbatim, and which items require the
     user present;
   - a **House style** section distilled from the project's `CONTRIBUTING`, `.editorconfig`, and a
     read of neighboring source—mechanical gate command, comment/KDoc conventions, test framework and
     naming, commit-message convention, **branch-naming convention** (read recent branch and
     merged-PR head names, e.g. `git ls-remote --heads upstream`), em-dash and other prose rules—to
     be pasted verbatim into every implementation-agent brief.
4. **Create `ROADMAP-CHANGELOG.local.md`** as the empty done-record companion. (`spike-notes.local/`
   still holds outreach drafts and spike notes.)
5. **Seed the items**: ask the user what they are—scope is theirs to set, don't invent a plan from the
   codebase unasked—then write them in priority order with stable `Rn` IDs.

The `gradle-versions-plugin` fork is a worked reference for all of these files (it may still carry the
legacy `spike-notes.local/roadmap-history.md` changelog name).

### 9b. `versioned` family (a repo you own)
1. **Stamp out root `ROADMAP.md`** with a short header: the `Rn` ID scheme (stable, never reused, an
   item keeps its ID for life; the claim unit is the item, sub-items `Rn.m`), §4's priority-order rule
   (descending priority top-down, reshuffles grooming-only), and a forward-only note (git history is
   the done-record—landed items are deleted, parked/declined items move to `ROADMAP-PARKED.md` /
   `ROADMAP-DECLINED.md`, created on first need).
2. **Seed the items**: same as §9a step 5.
3. **Commit the roadmap on the default branch**—it's tracked; that's what makes the mode `versioned`.
