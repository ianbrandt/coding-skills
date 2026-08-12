---
name: conduct-a-pipeline
description: >-
  Run several lanes at once, unattended, as one conductor session: hold 2–5
  file-disjoint units of work in flight, build each in its own worktree via a
  background Workflow, and process each as it finishes—rolling, refilled after
  every completion, until the work runs out or the plan is invalidated. Carries
  the deviations that exist only because no human is in the loop: the mandatory
  build gate on a self-reported green, the retry-then-flag rule, the watchdog for
  a pipeline that died without notifying, and the stop conditions. Trigger on
  "run several items unattended", "autopilot", "keep the pipeline full", or any
  multi-lane run with nobody watching. NOT for a single unit of work (that's
  claim-a-lane then land-and-wrap), and NOT for deciding what the candidates are—
  that comes from the repo's backlog plugin.
---

# Conduct a pipeline

One session conducts; Workflows build. The conductor holds up to N file-disjoint units of work in
flight, builds each in its own worktree via a background Workflow, and processes each as it
finishes—a rolling pipeline, refilled after every completion, running until candidates run out or
the plan is invalidated.

Per-lane mechanics are **inherited**, not restated: `claim-a-lane` for worktrees and the claim
ledger, `land-and-wrap` for the two landing arms. This skill adds the conductor layer and the
**unattended deviations**—each one exists because there is no human in the loop. *This skill is the
Workflow orchestration opt-in for every unit built under it.*

**Candidates come from the backlog** (`claim-a-lane` §0), not from here. A backlog plugin supplies
an ordered list of workable units and records each one done in its own form; this skill decides how
many run at once, what happens when one fails, and when to stop. With no backlog plugin, the user
supplies the list up front and the conductor runs it dry.

The repo decides how a completed unit is **processed**, by `land-and-wrap`'s two facts. A repo you
own lands each one serially on the default branch—rebase, mandatory build, fast-forward, and a push
only if `origin` is private (§2a). A fork of someone else's project stages each one locally and
**never touches GitHub**; those don't serialize (§2b).

## 0. Arguments

**cap** = units in flight, clamped to 2–5 (default 3), of which at most **2 concurrently building
code units** when the repo's build system shares one daemon or home per machine (lock timeouts and
OOM-killed daemons masquerade as unit failures); cheap, isolated builds are exempt from the sub-cap.
**max-items** caps units ***claimed***, not just completed—stop filling when claims-this-run reach
it. A backlog plugin may add its own arguments, such as a hint biasing candidate order.

## 1. Conductor setup—once

The conductor roots in the **main checkout** and never edits repo files outside a unit's worktree,
the run-state file excepted. Get the candidate list from the backlog; if it is empty, stop. Run
`claim-a-lane`'s hygiene pass once. Then:

- **Create the run-state file** `.claude/pipeline-run.json`—git-ignored where the backlog is tracked,
  git-excluded where it isn't, and deliberately NOT under `.claude/claims/`, where the hygiene reaper
  would parse it as a claim and delete it. Per-unit `{status, worktree, branch, taskId, attempts}`,
  plus `landed`/`staged`, `flagged`, `claimedCount`, and the recent completion/failure window.
  **Rewrite it on every state change; re-read it at the top of every wake**—context can be summarized
  mid-run, and IDs, counters, and flags held only in context don't survive that. It doubles as the
  morning-after record.
- Emit the session title, spelled out.

No pause follows—this skill runs unattended.

## 2. The loop—a rolling pipeline

**Every wake begins the same way**—Workflow-completion notification or watchdog: re-read the
run-state file, then **poll the status of every in-flight task**. A Workflow that died without
completing sends no notification: found by polling it is treated exactly as a `failed` report; left
unpolled it occupies its slot forever. So **whenever builds are in flight, arm a bounded watchdog**
(Monitor with an until-condition on task completion and a 30–60 minute timeout)—the all-dead
pipeline is the one stall no completion event can break.

**Candidates:** re-derive after every completion. The backlog supplies what is workable and in what
order (`claim-a-lane` §0); this skill removes what the session layer knows to be unavailable:

- **claimed**—a live claim names it;
- **not disjoint**—any path it expects to edit falls inside a live claim's `touches` globs;
- **already in flight** by any of `claim-a-lane` §2's three tells. **The conductor never takes the
  resume path**: a unit in flight stays out of candidates rather than being resumed here—it is an
  attended session's to finish. **A missing claim does not make it open**: a session that wrapped
  cleanly deleted its own claim and left the work in flight, so check the backlog's pin and `git
  worktree list` before reading an unclaimed unit as free;
- **flagged this run**—a flagged unit's claim was released, so without the exclusion it is re-picked
  and re-burned on every refill.

Keep candidates in the backlog's order so fills take the topmost eligible units first. A unit whose
paths can't be predicted well enough to declare declares the broadest glob it might reach; that
costs parallelism and never costs correctness.

**Fill:** while in-flight < cap, claimed < max-items, and a candidate exists: open its worktree +
branch and write its claim per `claim-a-lane`, **atomically, with its `touches` globs**—the
conductor is the one reader that depends on them being accurate, since it is holding several lanes
open at once.

**When a build reports files outside its declared globs, rewrite that claim before the next fill.**
A stale `touches` is worse than none: it reads as a checked disjointness guarantee. After all claims
in a fill batch are written, **re-read the ledger once more immediately before spawning each
build**—the write-then-check tie-break leaves the earlier writer blind to a later one. Then emit the
unit's one-line tier plan (`tier-model-and-effort`) and spawn its build as a **background Workflow**
sized to the work: design → implement test-first → adversarial review → fix → re-verify for code;
research → synthesize for design and research work. Small units (a note, a doc move) skip the
Workflow: the conductor does them inline in the worktree and processes them in the same pass.

**Every build brief carries, verbatim:**

- work ONLY under `<absolute worktree path>`—never the main checkout, never another worktree;
- you MAY create WIP checkpoint commits at stage boundaries (message `WIP: <stage>`)—a failed-stage
  retry resets to them; you must NEVER `git merge`, `git push`, rewrite history, or edit the backlog
  files—the conductor owns processing and backlog reconciliation (the unit's own new design or notes
  file is fine);
- **[on a fork only] NO GitHub writes of any kind**—no push even to the fork, no issues, comments,
  or PRs, no `gh` write commands; draft any outreach text as local files for the user to post;
- repo conventions apply: test-first, in whatever style guide the repo or the backlog plugin
  supplies, pasted verbatim rather than referenced; delete agent artifacts (think-aloud comments,
  banners, mismatched test names)—cleanup is part of the work, not a later pass;
- final message = a structured report: `status` (`ready` | `failed` | `plan_invalidating`), what was
  built, files touched, findings, and anything that surprised you.

Verify stages run as plain agents in the unit's worktree (no isolation—a worktree-isolated agent
branches from the default branch's HEAD and would test the wrong tree). Tier per stage
(`tier-model-and-effort`): mechanical work at the mechanical model or `effort: 'low'`, loud-oracle
stages only; design and adversarial-verify at `'high'`/`'xhigh'`.

**Process each completion—one at a time:**

1. Read the report. `plan_invalidating` → §3. `failed` → `git reset --hard` to the last WIP
   checkpoint (without checkpoints a retry compounds on a half-mutated tree), then one re-scoped
   retry resuming the Workflow from its run ID (byte-identical stages cache-hit). **A retry
   re-occupies the unit's slot—it is not a completion and does not trigger a refill.** A recognizable
   **infra failure** (build-tool lock timeout, daemon OOM) gets one extra uncounted retry and must
   not feed the stop rules. A second real failure **flags** the unit: record it in `flagged`, release
   its claim, leave its worktree + branch (WIP commits are autopsy evidence), name it in the wrap-up,
   continue with the others.
2. `ready` → inspect the diff (`git -C $WT status` / `diff`), strip any surviving agent artifacts,
   then **squash the WIP checkpoints into atomic, past-tense commits** (soft-reset to the merge-base,
   re-commit in logical units).
3. **A Workflow's self-reported green has been wrong.** `ready` is a claim, not a gate: agents have
   reported it on a red tree—having run a scoped subset, misread the output, or last built before
   their own final edit. **The conductor runs the build gate itself** on every completed unit
   (below), and a `ready` report failing that gate is a `failed` report—back to step 1. Never
   substitute the report for the gate, and never skip the gate because the report was detailed or
   confident.
4. **Then process by what the repo is** (`land-and-wrap` §1):

### 2a. A repo you own—land serially on the default branch

Per `land-and-wrap` §2, with these unattended deviations:

- Rebase onto the default branch. **Record the unit done in the backlog after the rebase.** Where
  the backlog's record is a tracked-file edit, make it the final fresh commit on the rebased tip:
  doing it before conflicts with the previous landing's backlog edit on every serial landing, and
  unattended conflict resolution silently mangles a sibling's backlog state. Where the backlog
  lives outside the tree—an untracked local-only file, an issue tracker—there is no commit to make;
  record it once the unit passes the build gate, through the backlog plugin's own mechanics.
- **Build—mandatory; the risk-based skip is off here**, regardless of what the unit's report claimed
  (step 3). The attended risk-based skip assumes a next session as the net; here that "next session"
  is this loop applying the same skip, and at stop time there is none. Gate on the repo's **full
  build** (from its contributor docs), never a scoped single-module test—a module-scoped gate can
  pass while a sibling module's fixtures stay red.
- Fast-forward-merge from the main checkout. On `--ff-only` refusal—a human session landed inside
  your rebase→build window—**re-rebase onto the moved branch and retry, bounded (3 attempts)**; never
  relax `--ff-only`.
- Push if the repo is private. **On a public repo, never push**: keep landing each unit on local
  `main` and present the accumulated unpushed range (`origin/main..main`) at stop for the user's
  review-then-push. Then delete the claim; remove the worktree and branch; update the run-state file.

### 2b. A fork—stage locally, nothing to GitHub

Per `land-and-wrap` §3. There is no shared branch, so units do NOT serialize:

- Keep the squashed atomic commits **on the unit's branch**; do not merge or push them.
- **Run the repo's build/test yourself** to confirm the branch is green before recording it done—same
  rule as step 3; the unit's own report doesn't count. A red unit is not "done".
- Record it done in the backlog, in a form that says how far it got. Draft any issue, comment, or PR
  text as local files under the repo's notes directory.
- **Leave the worktree + branch in place** for the user to review and sync. Delete the claim; update
  the run-state file (`staged`, not `landed`).

5. **Post-completion premise check:** `plan_invalidating` is self-reported and an agent can miss
   it—if the completed unit's diff touched a shared seam that in-flight or queued units build on, or
   contradicts an assumption the backlog's ordering rests on, treat it as plan invalidation (§3) even
   though the report said `ready`.
6. Refill the pipeline (fresh candidate derivation) and log one line:
   `landed <id> <name> (<sha>)—N in flight, M landed.` on a repo you own /
   `staged <id> <name> on <branch>—N in flight, M staged.` on a fork.

**Stuck build:** a Workflow far past its runtime for work of that size with no progress (the watchdog
gets you here) → TaskStop it, re-scope the stuck stage, resume from the run ID; never let one stuck
unit starve the pipeline.

## 3. Stop conditions—wrap, notify, end

Stopping means: let in-flight builds finish (or TaskStop them if the stop reason poisons their
premises), process whatever is finished-and-green (**conductor-run build gate, no skip**), then wrap.
Stop when:

- **Candidates run out**—nothing passes the filters. The normal end.
- **Plan invalidated**—a unit self-reports it, or the §2.5 check trips: a prerequisite discovered
  wrong, a spike refuting a settled ruling, a finding that materially changes what sibling units
  assume. Do NOT improvise a revised plan—stop and report; re-planning is the user's session.
- **Default branch red after a landing**—one fix-forward attempt; still red → stop immediately. No
  analogue on a fork: nothing lands on a shared branch, so a red unit is simply left flagged and
  unstaged.
- **The failure window trips**—≥2 failures within any 3 consecutive completions (ordered by
  completion time), or ≥3 units flagged in the run.
- **max-items reached.**

On stop: finalize the run-state file, send a PushNotification (one line—units landed/staged, stop
reason), then a full wrap-up per `land-and-wrap` §4: landed/staged units with SHAs (on a fork their
branch names to sync; on a public repo you own the unpushed `origin/main..main` range awaiting
review-then-push), flagged units with why, what the backlog has left, and a recommendation for the
next attended session. Re-emit the session-title line. No stop path skips the notification and
wrap-up.

## 4. Ledger etiquette

The conductor is a peer, not an owner: honor foreign claims when picking (a human session may be
working that unit right now), never `git worktree remove` a worktree it didn't create, and keep its
own claims accurate—one per in-flight unit, written atomically, deleted at completion. Everything
`claim-a-lane` says about the ledger binds here N-fold.
