# orchestration-skills

A [Claude Code](https://claude.ai/code) plugin for the part of agent work you do not watch. Handing
a unit of work to a subagent is easy; knowing whether what came back is trustworthy is the hard
part, and most of the ways it goes wrong look like success. A stage that stopped talking reads as
truncated rather than failed. A worktree-isolated verifier reports green against the wrong branch.
Two verifiers in one worktree mutate the code each other is measuring. Every rule here is one of
those, written down with the number it cost.

## Skills

### `delegate-to-subagents`

The coordination protocol. What is worth handing off at all (substantial, well-specified,
objectively verifiable—never a one-liner), what every brief carries verbatim, and how far a
read-heavy fan-out can be scoped before an agent overruns its context and retries from scratch. Has
the isolation table: verifiers and live probes run non-isolated so they see the feature branch,
parallel writers get their own worktrees so they stop failing each other's suites, and adversarial
verifiers run serially because a verifier doing its job mutates the code under test. Ends with how
to integrate parallel worktree diffs into commits that revert on their own.

### `tier-model-and-effort`

Model and effort as two independent knobs: capability class versus deliberation need. Carries the
dated model tier table—apex, everyday, task hero, mechanical—that every other file in this plugin
defers to instead of naming a model inline, since model names age faster than the rules around them.
Also covers the desktop effort labels, why a session running hot should not make every stage pay for
it, and what opting into Ultracode does and does not include.

### `verify-adversarially`

The extra pass that correctness-critical transform logic needs. Position-preserving rewriters, AST
rewriters, and name re-keying fail by succeeding quietly with corrupted state, so a green suite is
the confidence such a bug needs to ship. One independent verifier, whose only deliverable is an
input that produces silently wrong output or a documented failure to find one. Lists the three blind
spots that have shipped past a green suite before, and requires each hypothesis be settled by a live
probe against compiled code rather than a code trace.

## How it is wired

A `SessionStart` hook injects `hooks/rules.md` into every session, including after `/clear` and
compaction. That file is the short always-on form; the three skills hold the full protocols behind
it. There is no `SubagentStart` hook here on purpose—these rules govern the agent doing the
delegating, not the one carrying out the task.

Editing `hooks/rules.md` or any skill is a plugin release: an installed session reads a
version-keyed cache, so the plugin's `version` in `.claude-plugin/marketplace.json` has to bump in
the same commit or the session keeps serving the old copy.

## The incident numbers

The anecdotes in these skills are real runs with the project names removed and the numbers kept,
because the numbers are the argument. An over-scoped census agent burning ~800k tokens over 4
retries against ~150k for its bounded siblings is why the fan-out cap is 10 files. An orchestrator
being wrong on all 4 of its disagreements with a delegate is why disagreements get settled by
spot-check instead of by rank. Two stages in one run ending on holding messages—the second against a
brief that carried the prohibition verbatim—is why writing the rule into the brief is not the same
as the rule holding.
