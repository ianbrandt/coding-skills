---
name: execute-roadmap
description: >-
  Use this skill to work through THIS repo's roadmap unattended as a single
  conductor session: it claims multiple compatible items, builds each in its own
  worktree via background Workflows (2–5 in flight), and keeps going until the
  roadmap is dry or the plan is invalidated. Auto-detects the same two modes as
  next-roadmap-item: for a repo you own it lands each item serially on the
  default branch; for an upstream OSS fork it stages each item locally (no GitHub
  writes) for you to sync. Trigger on "execute the roadmap", "run the roadmap",
  "work through the roadmap", "roadmap autopilot", "burn down the roadmap", or
  any request for an unattended multi-item run. Optional args: an in-flight cap
  (2–5), a max-items budget, and/or a lane hint. Do NOT use it for a single item
  (that's next-roadmap-item), for merely reading or editing the roadmap, or for
  landing an existing session's work.
---

# Execute roadmap—the unattended conductor

One session conducts; Workflows build. The conductor claims up to N file-disjoint roadmap items,
builds each in its own worktree via a background Workflow, and processes each as it finishes—a
rolling pipeline, refilled after every completion, that runs without the user until the roadmap is
dry or something invalidates the plan.

Per-item mechanics are **inherited** from [`next-roadmap-item`](../next-roadmap-item/SKILL.md), not
restated: mode detection (its §0), worktree + claim hygiene (its §1, §3–5), and the two landing arms
(its §8). This skill adds the conductor layer on top and calls out the **unattended deviations**,
each of which exists because there is no human in the loop to be the safety net the attended path
assumes. *This skill is the Workflow orchestration opt-in for every item built under it.*

The mode (from next-roadmap-item §0) changes how an item is **processed on completion**:
- **`versioned`** (a repo you own): land serially on the default branch—rebase, mandatory build,
  fast-forward, push.
- **`local`** (an OSS fork): stage each item locally—commit on its branch, update the local roadmap
  and changelog, draft any outreach files—and **never touch GitHub**. Items don't serialize (no
  shared branch to land on); each is left on its own branch for you to sync.

## 0. Arguments
`/execute-roadmap [cap] [max-items] [lane hint]`—all optional. **cap** = in-flight items, clamped to
2–5 (default 3), of which at most **2 concurrently building code items** when the repo's build system
shares one daemon or home per machine (parallel heavy builds contend—lock timeouts and OOM-killed
daemons masquerade as item failures; if the repo's builds are cheap and isolated, this sub-cap
doesn't apply). **max-items** caps items ***claimed***, not just completed—stop filling when
claims-this-run reach it. **lane hint** = R-number or keyword biasing candidate order, the same
non-override semantics as next-roadmap-item's hint.

## 1. Conductor setup—once
The conductor roots in the **main checkout** and never edits repo files outside an item's worktree—the
run-state file below is the one exception. Detect the mode (next-roadmap-item §0); a `bootstrap`
result runs next-roadmap-item §9 first—its interview is allowed even here, since a repo's first
roadmap run is inherently attended—and if the freshly bootstrapped roadmap has no items, stop. Then
run its §3 hygiene pass once (worktree prune, dead-branch and dead-claim reaping). Then:

- **Create the run-state file** `.claude/roadmap-run.json` (git-ignored in a versioned repo,
  git-excluded in a local one—either way invisible to the tree; deliberately NOT under
  `.claude/claims/`, where the hygiene reaper would parse it as a claim and delete it): per-item
  `{status, worktree, branch, taskId, attempts}`, plus `landed`/`staged`, `flagged`, `deferredApex`,
  `claimedCount`, and the recent completion/failure window. **Rewrite it on every state change;
  re-read it at the top of every wake.** The conductor's context can be summarized mid-run—task IDs,
  counters, and deferral lists held only in context do not survive that, and the file doubles as the
  morning-after record.
- Emit the session title, spelled out.

No pause follows—this skill runs unattended. Fable never launches without authorization (§4).

## 2. The loop—a rolling pipeline
**Every wake begins the same way**—Workflow-completion notification or watchdog: re-read the run-state
file, then **poll the status of every in-flight task**. A Workflow that died without completing
(terminal API error, harness fault) sends no notification—found by polling, it is treated exactly as a
`failed` report; left unpolled it occupies its slot forever, and each silent death shrinks the pipeline
until nothing runs and nothing will wake the conductor. Which is why: **whenever builds are in flight,
arm a bounded watchdog** (Monitor with an until-condition on task completion and a 30–60 minute
timeout)—the all-dead pipeline is the one stall no completion event can break.

**Candidates:** re-derive after every completion (the roadmap just changed): open items passing
next-roadmap-item §4's filters—unclaimed, ungated, **file-touch-disjoint from every in-flight item**,
and **not user-present** (§4's "requires user present" items are never claimed unattended)—minus this
run's `flagged` and `deferredApex` sets (a flagged item's claim was released, so it reads as unclaimed
again; without the exclusion it is re-picked and re-burned every refill). When disjointness is
uncertain, serialize.

**Fill:** while in-flight < cap, claimed < max-items, and a candidate exists: open its worktree +
branch and write its claim per next-roadmap-item §5, **atomically**. After all claims in a fill batch
are written, **re-read the ledger once more immediately before spawning each build**—the
write-then-check tie-break leaves the earlier writer blind to a later one. Then emit the item's
one-line tier plan (next-roadmap-item §7) and spawn its build as a **background Workflow** sized to the
item: design → implement test-first → adversarial review → fix → re-verify for code items;
research → synthesize for design/research items. Small items (a note, a doc move) skip the Workflow:
the conductor does them inline in the worktree and processes them in the same pass.

**Every item-build brief carries, verbatim:**
- work ONLY under `<absolute worktree path>`—never the main checkout, never another worktree;
- you MAY create WIP checkpoint commits at stage boundaries (message `WIP: <stage>`)—a failed-stage
  retry resets to them; you must NEVER `git merge`, `git push`, rewrite history, or edit the roadmap
  files—the conductor owns processing and roadmap reconciliation (an item's own new design or notes
  file is fine: item-unique and contention-free);
- **[local mode only] NO GitHub writes of any kind**—no push even to the fork, no issues, comments,
  or PRs, no `gh` write commands; draft any outreach text as local files for the user to post;
- repo conventions apply: test-first; in local mode, paste the House-style block from the roadmap
  header verbatim; delete agent artifacts (think-aloud comments, banners, mismatched test names)—
  cleanup is part of the work, not a later pass;
- final message = a structured report: `status` (`ready` | `failed` | `plan_invalidating`), what was
  built, files touched, findings, and anything that surprised you.

Verify stages run as plain agents in the item's worktree (no isolation—a worktree-isolated agent
branches from the default branch's HEAD and would test the wrong tree). Tier per stage: mechanical at
`effort: 'low'` or a smaller model; design and adversarial-verify at `'high'`/`'xhigh'`.

**Process each completion—one at a time:**
1. Read the report. `plan_invalidating` → §3. `failed` → `git reset --hard` to the last WIP checkpoint
   (without checkpoints a retry compounds on a half-mutated tree with nothing to fall back to), then
   one re-scoped retry resuming the Workflow from its run ID (byte-identical stages cache-hit). **A
   retry re-occupies the item's slot—it is not a completion and does not trigger a refill.** A
   recognizable **infra failure** (build-tool lock timeout, daemon OOM) gets one extra uncounted
   retry—machine contention is not an item fault and must not feed the stop rules. A second real
   failure **flags** the item: record it in `flagged`, release its claim, leave its worktree + branch
   (now holding WIP commits, real autopsy evidence), name it in the wrap-up, continue with the others.
2. `ready` → inspect the diff (`git -C $WT status` / `diff`), strip any surviving agent artifacts,
   then **squash the WIP checkpoints into atomic, past-tense commits** (soft-reset to the merge-base,
   re-commit in logical units).
3. **Then process by mode:**

### 2a. `versioned`—land serially on the default branch
Per next-roadmap-item §8a, with these unattended deviations:
- Rebase onto the default branch. **Reconcile the roadmap after the rebase**, as the final fresh
  commit on the rebased tip—reconciling before it guarantees a conflict with the previous landing's
  roadmap edit on every serial landing, and unattended conflict resolution is exactly where a
  sibling's roadmap state gets silently mangled; written fresh post-rebase it conflicts with nothing.
- **Build—mandatory; the optimistic skip is off in this mode.** The attended risk-based skip assumes a
  next session as the net; here the "next session" is this loop applying the same skip, and at stop
  time there is no next session at all—a red default branch would spread silently. Gate on the repo's
  **full build** (from its contributor docs), never a scoped single-module test: a module-scoped gate
  can pass while a sibling module's fixtures, relying on something the change removed, stay red.
- Fast-forward-merge from the main checkout. On `--ff-only` refusal—a human session landed inside your
  rebase→build window—**re-rebase onto the moved branch and retry, bounded (3 attempts)**; never relax
  `--ff-only`.
- Push; delete the claim; remove the worktree and branch; update the run-state file.

### 2b. `local`—stage locally, nothing to GitHub
Per next-roadmap-item §8b. There is no shared branch, so items do NOT serialize—each is independent:
- Keep the squashed atomic commits **on the item's branch**; do not merge or push them.
- Run the repo's **build/test to confirm the branch is green** before recording the item done. There
  is no default branch to protect, but a red item is not "done".
- Move the item out of the forward roadmap and **append its done-record to the changelog** with a
  status keyword (next-roadmap-item §8b). Draft any issue/comment/PR text as local files under the
  notes dir.
- **Leave the worktree + branch in place** for the user to review and sync. Delete the claim; update
  the run-state file (`staged`, not `landed`).

4. **Post-completion premise check:** `plan_invalidating` is self-reported and an agent can miss it—if
   the completed item's diff touched a shared seam that in-flight or queued items build on, or
   contradicts a roadmap gate's stated assumption, treat it as plan invalidation (§3) even though the
   report said `ready`.
5. Refill the pipeline (fresh candidate derivation) and log one line:
   `versioned: landed <Rn.m> <name> (<sha>)—N in flight, M landed.` /
   `local: staged <Rn.m> <name> on <branch>—N in flight, M staged.`

**Stuck build:** a Workflow far past its item-class runtime with no progress (the watchdog is what gets
you here) → TaskStop it, re-scope the stuck stage, resume from the run ID; never let one stuck item
starve the pipeline.

## 3. Stop conditions—wrap, notify, end
Stopping means: let in-flight builds finish (or TaskStop them if the stop reason poisons their
premises), process whatever is finished-and-green (**mandatory build in versioned mode, no skip**),
then wrap. Stop when:
- **Roadmap dry**—no candidate passes the filters (everything landed/staged, gated, flagged, deferred,
  or user-present). The normal end.
- **Plan invalidated**—an item self-reports it, or the §2.4 post-completion check trips: a gate
  discovered wrong, a spike refuting a settled ruling, a finding that materially changes sibling items'
  assumptions. Do NOT improvise a revised plan—stop and report; re-planning is the user's session.
- **[versioned] Default branch red after a landing**—one fix-forward attempt; still red → stop
  immediately (a broken default branch poisons every branch landed after it). No analogue in local
  mode: nothing is pushed and there is no shared branch to poison; a red item is simply left flagged
  and unstaged.
- **The failure window trips**—≥2 failures within any 3 consecutive completions (ordered by completion
  time), or ≥3 items flagged in the run.
- **max-items reached** (claims are capped at it, so there is no overshoot to unwind).

On stop: finalize the run-state file, send a PushNotification (one line—items landed/staged, stop
reason), then a full wrap-up: the landed/staged items with SHAs (and, in local mode, their branch names
for you to sync), flagged/deferred items with why, the roadmap's remaining state, and a recommendation
for the next attended session. Re-emit the session-title line. No stop path skips the notification and
wrap-up.

## 4. Fable—one blocking question at the drain
PushNotification is one-way—no mid-run authorization can arrive on it, so don't poll for one. An item
whose class is **apex-grade** (correctness-critical enough that the tier doctrine wants Fable—
next-roadmap-item §7) is simply **deferred**, recorded in `deferredApex`, pipeline unaffected. Only
when the pipeline is **fully drained**—zero in-flight builds, zero landable/stageable work—and deferred
apex items remain: send a PushNotification, then block on AskUserQuestion (authorize Fable for the
deferred items / run them at the Opus + `xhigh` ceiling / skip them)—the user answers remotely.
Blocking any earlier would queue completion notifications behind the pending question and leave finished
work unprocessed for hours. Never spawn Fable without that explicit yes.

## 5. Ledger etiquette
The conductor is a peer, not an owner: honor foreign claims when picking (a human session may be
working an item right now), never `git worktree remove` a worktree it didn't create, and keep its own
claims accurate—one per in-flight item, written atomically, deleted at completion. Everything
next-roadmap-item's intro says about the ledger binds here N-fold.
