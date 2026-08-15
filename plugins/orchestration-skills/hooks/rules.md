ORCHESTRATION MODE ACTIVE

These rules govern work you hand to another agent: subagents, Workflow stages, parallel worktrees.
The main loop orchestrates; delegate units that are well-specified, substantial, and objectively
verifiable. A subagent carries fixed overhead (brief, digest, re-read), so it pays off only on meaty
self-contained units—never a one-liner. Keep emergent or fuzzy work in the main loop.

## Before launching

- **Announce the delegation and why**, then summarize what came back. Subagent output returns to
  you, not to the user's transcript—unsummarized work is invisible work.
- **Put scope, style, and VCS/docs prohibitions verbatim in every brief.** A brief that says "follow
  the repo conventions" does not apply them. Parallel-worktree briefs forbid `commit`/`merge`/`push`
  and shared-doc edits; the orchestrator reconciles and commits serially.
- **Require findings on disk, and name the tools the task may need.** A brief that asks only for a
  return value loses everything when the agent goes silent: one did exactly that, and its result had
  to be reconstructed from the worktree's build reports. A delegate that is not told it can drive a
  browser reports a Cloudflare 403 as a dead end.
- **Do not launch a stage you cannot afford to verify.** A delegated diff is unreviewed until you
  review it. Weigh that against the context you have left, and hand the whole unit to a fresh
  session rather than passing on a diff nobody read.
- **Bound read-heavy fan-out.** Cap a census-style agent at roughly 10 files, read once. An
  over-scoped reader overruns context, dies, and retries from scratch: one such agent burned ~800k
  tokens over 4 retries against ~150k for its bounded siblings.
- **Pick the tier per stage.** Model is the stage's capability class; effort is its deliberation
  need. Reserve the apex tier for the hardest analysis, design, and review. Never name a model from
  memory—the current table lives in the `tier-model-and-effort` skill.
- **State each stage's tier in the message that launches it.** An up-front plan is a forecast and
  nothing later checks it. One session announced `Workflow—design@high, implement@medium, docs@low,
  adversarial-verify@high` and then ran no Workflow, built the item inline, and set no model on
  either agent it launched. Note also that `Agent` has no effort parameter—only a Workflow sets
  both knobs—so never announce an effort you cannot apply.

## Isolation

- `isolation: 'worktree'` branches from the **primary checkout's HEAD**, usually the default branch,
  not your feature-branch worktree. A worktree-isolated agent asked to verify committed work may be
  testing the wrong branch. Check which commit an isolated agent branched from.
- A **non-isolated** agent runs in your session worktree: right for verifiers and live probes, wrong
  for parallel writers, which see each other's half-done state and chase phantom corruption.
- **A verifier that earns its cost is itself a writer**—it mutates the code under test to prove a
  check distinguishes what it claims. Two verifiers fanned out into one worktree produce false
  results, not just wasted tokens. Run verify agents serially, or give each its own scratch copy.

## Trusting what comes back

- **A stage that ends on a holding message ("pausing until the build finishes") is failed work, not
  finished work.** Say so in every brief, and still inspect the tree yourself: two stages in one run
  ended that way against a brief carrying that prohibition verbatim, and both shipped a silent
  defect that only a live probe caught.
- **Verify the fix stage.** Fix stages run after the reviewers, so their diffs are unreviewed.
  Confirm the fix reached its target and watch a regression test go red then green.
- **Arbitrate a disagreement by spot-check, not by rank.** The delegate read deeper on its narrow
  slice and is usually right: in one pass the orchestrator was wrong on all four disagreements.

## Open-ended scope

When several paths are viable, **pick and recommend** the one that balances good context against
weekly usage—do not enumerate options at length or open a multi-session rabbit hole. Prefer landing
a clean, complete, tested increment. Spend subagents and workflows where they clearly pay off.

## The skills behind these rules

`delegate-to-subagents`—the full coordination protocol: briefs, fan-out, isolation, integration.
`tier-model-and-effort`—the dated model table, the effort labels, and when to opt into a Workflow.
`verify-adversarially`—the extra pass correctness-critical transform logic needs before it ships.
