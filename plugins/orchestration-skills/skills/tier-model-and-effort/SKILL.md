---
name: tier-model-and-effort
description: >-
  Pick the model and the reasoning effort for each stage of a piece of work, as two
  independent knobs: capability class versus deliberation need. Carries the dated model
  tier table this repo's other skills defer to, the effort labels the user's picker shows,
  the rule that a session running hot should not make every stage pay for it, and what
  opting into Workflow orchestration does and does not include. Trigger when planning a
  multi-stage run, when writing per-stage model or effort overrides, when a stage is
  underperforming or overspending, and on "which model should this use". NOT for how to
  brief or bound a delegated agent (that's delegate-to-subagents).
---

# Tier model and effort—two knobs, set per stage

Model and effort are independent. Model is the stage's **capability class**; effort is its
**deliberation need**. A capability shortfall wants a bigger model, not more thinking. Careful
multi-step bookkeeping wants more effort, not a bigger model. Setting both high everywhere is how a
run costs four times what it needed to.

## 1. The model tiers

**Table current as of 2026-08-11.** Model names age fast; re-tune this table when releases land,
and treat every other skill's tier language ("the apex tier", "a task hero") as pointing here rather
than at a name. Nothing else in this plugin names a model.

| Tier | Model | Use it for | Cost note |
|---|---|---|---|
| Apex | Fable | The most challenging, riskiest, correctness-critical, or key-strategy work: design, adversarial verification, judge stages. | Roughly 4x the effective cost of the everyday tier—2x usage against a weekly budget half the size. Aim it; never default to it. |
| Everyday | Opus | The orchestrator and the workhorse. The main loop runs here. | The baseline. |
| Task hero | Sonnet | Any unit that is well-specified and objectively verifiable, inside a Workflow or not. Test-driven work is the ideal case. | Cheap enough to fan out. |
| Mechanical | Haiku | Stages with a loud oracle: tests, compiles, a verifiable count, bulk reads, fixture sweeps, doc updates. | Cheapest. Only where failure is loud. |

**"Mechanical" means failure is loud.** A stage that could fail silently is not mechanical, however
rote it looks. Give it a task-hero model and a real check.

## 2. The effort labels

The desktop picker shows: **Low / Medium / High / Extra / Max / Ultracode**. There is no "default"
label, so write guidance in these terms. "Extra" is the API's `xhigh`.

Rough fit:

- **Low**—mechanical stages with a loud oracle.
- **Medium / High**—ordinary implementation and review.
- **Extra / Max**—design, adversarial verification, judge stages, and careful multi-step bookkeeping.

**A session running at a high effort should not make every stage pay for it.** Set the expensive
tier on the stages that need it and let the rest run cheap.

## 3. Override per stage, do not pause for the picker

Model and effort are user-side settings, and they are only weakly observable from inside a session:
effort is never surfaced, and the environment block's model name can lag a mid-session change.

So do not stop and ask the user to change a picker. Launch at the everyday baseline, keep the main
loop there, and set the tier explicitly on the stages that need something else.

**The two knobs are not both available everywhere.** The `Agent` tool takes `model` and has no
effort parameter, so a subagent launched that way inherits the session's effort no matter what you
announce. Only a Workflow's `agent(..., {model, effort})` sets both. A stage that genuinely needs a
different effort is itself a reason to reach for a Workflow; a stage that only needs a different
model is fine on `Agent`. Never announce an effort setting you have no way to apply.

**Announce each stage's tier in the message that launches it.** An up-front plan is worth
writing—it tells the user what a run will cost before it starts—but nothing later checks it, and a
plan written before the stages are known describes stages that never happen. So plan only what you
actually intend to delegate, restate the tier as you launch each stage, and say plainly when a
planned stage turns out not to run. In one session the plan `Workflow—design@high, implement@medium,
docs@low, adversarial-verify@high` was announced within a minute of the claim, before any source had
been read. That session then ran no Workflow at all, built the item inline in the main loop, sent
both delegated agents out with no model override, and never launched the apex judgment pass it
promised an hour later.

The apex tier can be spawned unattended for analysis, design, and review stages. Its cost is the
reason to **aim** it, not the reason to avoid it.

## 4. Ultracode: what it is and what it is not

**Ultracode = Extra effort (`xhigh`) plus automatic Workflow orchestration.**

It is deliberately non-persistent—no settings key, no environment variable, no hook. Opt in per turn
(the keyword `ultracode`, or asking for a workflow) or per session (`/effort ultracode`).

A `SKILL.md` that says to **use the Workflow tool** opts that skill into orchestration on its own,
scoped to its own task. That grants orchestration **only**, not the effort half. Extra effort still
needs the explicit opt-in.

## 5. Open-ended scope: pick and recommend

When several paths are viable, pick the one that balances good context against weekly usage, and
recommend it—rather than enumerating options at length or pushing into unfocused deep work. Prefer
landing a clean, complete, tested increment over opening a multi-session rabbit hole in the same
turn. Spend subagents and workflows where they clearly pay off, not lavishly.
