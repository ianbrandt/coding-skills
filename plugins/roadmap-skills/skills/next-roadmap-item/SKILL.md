---
name: next-roadmap-item
description: >-
  Claim the next unclaimed, non-colliding item on THIS repo's roadmap and start
  building it. Finds the plan of record in either place it lives—tracked at the
  repo root, or untracked and local-only for an OSS project contributed to via a
  fork—and bootstraps one if the repo has none. Trigger on "tackle a roadmap
  item", "claim a task and get going", or starting work without colliding with
  the other sessions. Also resumes an item already in flight and partially
  built—more building on an in-flight item is this skill, which adopts that
  item's existing worktree. An optional lane hint ("R1") only biases the pick.
  NOT for reading, summarizing, or editing the roadmap, and NOT for the worktree
  and claim mechanics themselves (that's claim-a-lane) or for landing finished
  work (that's land-and-wrap).
---

# Next roadmap item—parallel-safe session cold-start

Pick one item off this repo's roadmap and build it, without colliding with the other sessions
working the same repo right now.

This skill is a **backlog plugin**: it fills the three-question seam `claim-a-lane` §0 defines,
using a markdown roadmap in place of an issue tracker. What is workable (§3), where an item is
already in flight (§2), and how a landed item is recorded (§6). Everything else about the session
belongs to two skills this one calls rather than copies:

- **`claim-a-lane`**—adopting or opening the worktree, the shared claim ledger, sibling etiquette.
- **`land-and-wrap`**—how finished work leaves its branch, and what every session does at its end.

**Sequencing is this file's data; disjointness is the ledger's.** A gate ("R3 waits on R2") is known
before any session exists and only the roadmap can answer it. Whether two items collide on the same
files is a fact about the working tree, and it is settled by the `touches` globs in the claim
ledger, not by reading item names.

## 1. Find the plan of record

Two places it can live, and the fork check comes first: an upstream project's own `ROADMAP.md` must
never be mistaken for yours.

```bash
if [ -f ROADMAP.local.md ]; then
  ROADMAP=ROADMAP.local.md; HISTORY=ROADMAP-CHANGELOG.local.md    # local-only plan
elif git remote get-url upstream >/dev/null 2>&1; then
  ROADMAP=                                                        # a fork with no shadow roadmap yet—see §7
elif R=$(git ls-files ROADMAP.md docs/roadmap.md | head -1) && [ -n "$R" ]; then
  ROADMAP=$R; HISTORY=                                            # tracked plan; git history is the done-record
else
  ROADMAP=                                                        # no roadmap anywhere—see §7
fi
```

**Naming, at the repo root.** Tracked: `ROADMAP.md`, plus `ROADMAP-PARKED.md` and
`ROADMAP-DECLINED.md` as needed. Local-only: the same names suffixed `.local.md`—the never-commit
signal, and it keeps a shadow roadmap from colliding with an upstream project's real `ROADMAP.md`—
plus `ROADMAP-CHANGELOG.local.md`. Parked and declined files are created on first need, never as
empty stubs. Migrate a legacy `docs/roadmap.md` to the root in a grooming commit when the ledger is
empty.

**The done-record follows the plan's location, and nothing else.** A tracked roadmap needs no
changelog: the landing commit that deletes the item *is* the record. A local-only roadmap is
untracked, so git history can't hold it and `$HISTORY` does.

Both files live **only in the primary checkout** when they are untracked, which is by design—one
shared plan, not per-worktree copies. `claim-a-lane` has the mechanics for editing a
primary-checkout file from a worktree session.

**This is not the same question as how work lands.** `land-and-wrap` decides that from fork-ness and
`origin`'s visibility. A repo you own can carry a local-only roadmap and still merge into its own
default branch.

## 2. Get into a lane

Run **`claim-a-lane`** now, through its worktree and hygiene steps: locate `$MAIN` and `$WT`, resume
an in-flight worktree or open a fresh one, prune, and reap dead claims. Come back here to pick, then
finish `claim-a-lane` by writing the claim. If `claim-a-lane` is not among the available skills,
**stop and tell the user to install `session-skills`**—nothing below fails loudly without the
ledger, so proceeding just runs uncoordinated.

Its resume tells are what decide whether this run is a resume, and **tell 1 is an item's own text in
`$ROADMAP`**: a build rule pinning the item to one branch or worktree is the durable in-flight
record, outliving every session that touched it.

## 3. Pick a disjoint, unclaimed item

Choose an **unclaimed** item that is **workable**—its gates met—and whose file-touch set is
**disjoint** from every live claim's `touches` globs (`claim-a-lane` §6). Write the paths you expect
to edit into your own claim; `$ROADMAP` itself is the seam every item eventually touches, so declare
it and keep the edit minimal, localized, and last.

- **Only the active burndown is pickable.** Items are claimable to-dos with stable `Rn` IDs
  (sub-items `Rn.m`); an ID is never reused and an item keeps it for life. Parked, deferred,
  declined, and out-of-scope work lives in the parked or declined file—don't go fishing there.
- **Gates are the roadmap's half of the dependency graph.** An item tagged as gated is not
  workable until its prerequisite lands—skip it, or claim the prerequisite instead. Tag new items
  the same way, naming the item that gates them, so a later session doesn't have to infer the edge
  from prose.
- **Prefer an independent slice**, and record the collision seam an item is known to touch so the
  next session can declare it in `touches` without re-deriving it. Disjointness applies within a
  lane too.
- **The roadmap is priority-ordered, top-down**, optionally in coarse bands (Now / Next / Later).
  `Rn` IDs carry no order, so R17 above R3 is normal. **Absent a lane hint, take the topmost item
  that passes these gates.** Insert new items at their priority position; end-of-band is fine.
  Wholesale reordering is grooming work for an empty ledger, never a rider on a landing.
- **Items the roadmap's header flags as requiring the user present**—typically upstream outreach and
  packaging—are **never claimable unattended**. Skip them.

**A lane hint (free text after the skill name—an R-number, sub-item, or keyword) reorders candidates
that already pass those gates; it never relaxes them.** Match it against item IDs and headings:

- unclaimed and disjoint → take it;
- claimed or colliding → prefer a *disjoint sub-item in the same lane*, else fall back to normal
  selection. Either way **say so out loud**: the hinted item, why it couldn't be honored, what you
  picked instead;
- matches nothing → note that briefly, then pick as if unhinted.

If everything worthwhile is claimed, don't force a collision: wait for a session to finish (its
claim disappears, or a commit lands), then pick. A hint doesn't change this.

**Resuming an item already in flight.** The pick is already made—skip these gates entirely. A claim
on the item you are resuming is *yours*, not a collision, and re-picking on it is the bug
`claim-a-lane`'s resume path exists to prevent.

Then write the claim, per `claim-a-lane`.

## 4. Suggest a descriptive session title

As soon as the claim lands and any tiebreaker re-pick settles, **emit a session-title suggestion as
the last thing in the reply**, in the format `session-skills`' session rules specify—a
`**Session title:**` label line, then the bare title alone in a plain untagged fenced block, e.g.
`R1: aggregation core`.

Base it on the item just claimed: a short noun phrase naming the deliverable, **spelled out with no
abbreviations**. **Re-emit the same block at session end**, revised only if the work turned out to be
something else. Byte-identical format at both points.

## 5. Emit the tier plan—never pause

Model and effort are the **user's controls**: **start building immediately, no pause, no
end-of-turn checkpoint.** Sessions launch at the everyday baseline and the main loop stays there;
escalate by **delegation, not the session pickers**.

Immediately after the title line, emit a one-line **tier plan** naming the stages **this item
actually has**, then execute it. Two decisions go into it, and they are independent:

- **How much verification the item needs.** The question: **would this repo's test suite catch this
  item going silently wrong?** A loud suite lets the implement stage run cheap. A silent failure
  mode—transform or rewrite machinery—puts the weight on design and adversarial-verify, at the top
  effort and the apex model wherever being wrong is expensive.
- **What runs each stage.** Inline in the main loop, a delegated agent, or a Workflow. A single
  roadmap item is usually a linear design → build → verify, which the main loop plus one or two
  agents handles with nothing to script. Reach for a **Workflow** when there is fan-out, a loop
  until some condition holds, or several units to drive deterministically. A mechanical lap—polish,
  a doc move, roadmap grooming—stays inline at launch settings: `Tier plan: inline.`

**Name a model for every delegated stage, and an effort only for a Workflow stage.** The `Agent`
tool has no effort parameter, so an effort announced for a plain subagent never applies.

Write the plan against the item in front of you. One derived from a real item reads like this:

`Tier plan: inline design and implementation (the trace is already settled), then one
adversarial-verify agent at the apex tier against the merge logic.`

The plan is a forecast, so restate each stage's tier in the message that launches it, and say so
when a planned stage turns out not to run.

`tier-model-and-effort` carries the current model table and the per-stage override syntax; name
tiers from it rather than from memory, since model names age faster than the rules around them.

## 6. Build it, then land it

Work **test-first per THIS repo's conventions**—a failing test first, then match the repo's own
style. For a repo you own that means its `CLAUDE.md`, `CONTRIBUTING`, and design docs. For a fork it
means the **House style block** in `$ROADMAP`'s header, distilled from the project's `CONTRIBUTING`,
`.editorconfig`, and observed neighbors; **paste that block verbatim into every implementation-agent
brief**. When in doubt, match the neighboring file, not your habits.

**Orchestrate substantial items** with delegated agents—design → implement test-first → adversarial
review → re-verify—scaled to size. *This instruction is itself the opt-in, so the orchestration runs
even if the session never enabled `ultracode`*; it grants orchestration only, not extra effort. Keep
genuinely small items (a one-file tweak, a doc move) inline. Reach for the **Workflow tool** in the
cases §5 names—fan-out, a loop until some condition holds, several units driven
deterministically—rather than as the default vehicle for a single item.

Then hand off to **`land-and-wrap`**, which decides how the work leaves its branch and what the
session does at its end. Two things it defers back to this skill:

- **Bring the docs.** Finishing an item includes every piece of documentation it touches—the
  subsystem's design doc plus any user-facing surface.
- **Record the item done, forward-only.** A tracked roadmap **deletes** the landed item, in its own
  final commit; never migrate it to a done-list, never annotate it "landed". A local-only roadmap
  deletes it too and **appends a done-record to `$HISTORY`**, which is a *reasoning archive* rather
  than a landed-list: mechanism notes, corrections, refuted hypotheses, the local-to-upstream sha
  and number map, findings a later session should not have to re-derive, under a status keyword
  (`BUILT-LOCAL` / `DRAFTED` / `FILED` / `PR-READY` / `MERGED-UPSTREAM`). Free-form append, no rigid
  schema. An item that turned out parked or declined moves to the parked or declined file instead.

**The claim is released at session end even when the item isn't finished.** The unfinished item's
resume record is its branch and worktree, plus its pin in `$ROADMAP`; leave all of it standing and
name the branch in the wrap-up. The next session's entry point is `/next-roadmap-item <Rn>`, or
`/execute-roadmap` for an unattended run—§2's resume path adopts that item's existing worktree from
the ID alone, launched from the primary checkout, so the handoff carries no worktree path and no
account of what was already built.

## 7. Bootstrapping a repo with no roadmap

Runs when §1 finds no plan of record—the **one attended exception to §5's never-pause rule**: **ask
(AskUserQuestion) about anything that isn't obvious** rather than guessing, whether that's which
family, the initial items, fork wiring, or a gate command. One-time setup; afterwards proceed from
§2 if the new roadmap has items, otherwise report the bootstrap and stop.

An `upstream` remote means the local-only family. No `upstream` and the user owns the repo means the
tracked family. Ambiguous, ask.

### 7a. Local-only (an OSS fork)

1. **Confirm the fork wiring**: `origin` is your GitHub fork, `upstream` is the real project, ideally
   with `git remote set-url --push upstream no_push`. If the remotes aren't wired that way, propose
   the rewiring and ask before touching remotes.
2. **Exclude the local-only artifacts**—per-clone and uncommitted; never touch the tracked
   `.gitignore`:
   ```bash
   printf '\n# Local-only planning artifacts (never commit/push upstream)\n/ROADMAP*.local.md\n/.claude/\n/spike-notes.local/\n' \
     >> .git/info/exclude
   mkdir -p spike-notes.local
   ```
3. **Stamp out `ROADMAP.local.md`** with a header carrying the per-repo config as prose—this header
   *is* the config:
   - a one-line banner: local-only, excluded via `.git/info/exclude`, never commit or push;
   - a **forward-only** note pointing landed work at `ROADMAP-CHANGELOG.local.md`;
   - the fork and upstream remote names;
   - the **binding guardrails**: `land-and-wrap`'s no-GitHub-writes rule verbatim, and which items
     require the user present;
   - a **House style** section distilled from the project's `CONTRIBUTING`, `.editorconfig`, and a
     read of neighboring source—mechanical gate command, comment conventions, test framework and
     naming, commit-message convention, **branch-naming convention** (read recent branch and
     merged-PR head names, e.g. `git ls-remote --heads upstream`), em-dash and other prose rules—to
     be pasted verbatim into every implementation-agent brief.
4. **Create `ROADMAP-CHANGELOG.local.md`** as the empty done-record companion.
5. **Seed the items**: ask the user what they are. Scope is theirs to set—don't invent a plan from
   the codebase unasked—then write them in priority order with stable `Rn` IDs.

### 7b. Tracked (a repo you own)

1. **Stamp out root `ROADMAP.md`** with a short header: the `Rn` ID scheme (stable, never reused, an
   item keeps its ID for life; the claim unit is the item, sub-items `Rn.m`), §3's priority-order
   rule, and a forward-only note—git history is the done-record, so landed items are deleted and
   parked or declined items move to their own file.
2. **Seed the items**: same as §7a step 5.
3. **Commit the roadmap on the default branch.** It's tracked; that's what puts it in this family.
