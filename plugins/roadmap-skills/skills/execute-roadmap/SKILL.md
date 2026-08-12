---
name: execute-roadmap
description: >-
  Work through THIS repo's roadmap unattended: derive the ordered candidate list
  from the roadmap, hand it to session-skills' conduct-a-pipeline, and record
  each finished item back into the roadmap and its changelog. Trigger on "execute
  the roadmap", "roadmap autopilot", "burn down the roadmap", or any unattended
  multi-item run. Optional args: cap, max-items, lane hint. NOT for a single item,
  and NOT for resuming one item already in flight and partially built (both are
  next-roadmap-item); not for reading or editing the roadmap by hand, and not for
  the conductor loop itself (that's conduct-a-pipeline).
---

# Execute roadmap—the roadmap as a candidate source

This skill is the roadmap half of an unattended run. The conductor loop—the in-flight cap, the fill
loop, the watchdog, processing each completion, retries and flags, the build gate, and the stop
conditions—lives in `session-skills`' `conduct-a-pipeline`. Run that skill; this one supplies its
two backlog-shaped inputs and consumes its output.

It requires `session-skills` installed—check first: if `conduct-a-pipeline` is not among the
available skills, **stop and tell the user to install `session-skills`**, because nothing later
fails loudly without it. Per-item mechanics are inherited the same way:
[`next-roadmap-item`](../next-roadmap-item/SKILL.md) for finding the plan of record (its §1) and the
selection gates (its §3), `claim-a-lane` for worktrees and the ledger, `land-and-wrap` for landing.

## 0. Arguments

`/execute-roadmap [cap] [max-items] [lane hint]`—all optional. **cap** and **max-items** are
`conduct-a-pipeline` §0's, passed straight through. **lane hint** = an R-number or keyword biasing
candidate order, with the same non-override semantics as next-roadmap-item's hint (its §3): it
reorders candidates that already pass the gates and never relaxes one.

## 1. Before the pipeline starts

Find the plan of record (next-roadmap-item §1). A repo with no roadmap at all runs its §7 bootstrap
first—that interview is allowed here, since a repo's first roadmap run is inherently attended—and if
the fresh roadmap has no items, stop without starting a pipeline.

On a fork, the roadmap header's **House style block** is the style guide `conduct-a-pipeline` §2
requires in every build brief. Paste it verbatim; a brief that points at it does not apply it.

## 2. Deriving candidates

`conduct-a-pipeline` §2 re-derives candidates after every completion and asks the backlog for the
ordered workable list. From the roadmap that is:

- **Open items only**—the active burndown. Parked, deferred, and declined items live in the
  `ROADMAP-PARKED` / `ROADMAP-DECLINED` variants and are never candidates.
- **Ungated**—an item whose stated prerequisite hasn't landed is not workable yet. Sequencing is the
  roadmap's data and only the roadmap can answer it.
- **Not user-present**—on a fork, items the roadmap header flags as requiring the user (upstream
  outreach, packaging) are never claimable unattended. Skip them; they are the user's to run.
- **In roadmap order**, priority-descending, so fills take the topmost eligible items first. The
  `Rn` IDs carry no order.

Everything else the conductor filters on—claimed, not disjoint, already in flight, flagged this
run—is the session layer's and needs nothing from here.

The roadmap's **pin** is `claim-a-lane` §2's tell 1: an item's entry naming a branch or worktree is
the durable in-flight record, and it is why an unclaimed item is not automatically free.

## 3. Recording an item done

`conduct-a-pipeline` §2a/§2b calls back here once a unit is green. In roadmap form:

The roadmap is forward-only either way: **delete the item**, never migrate it to a done-list, never
annotate it "landed". An item that turned out parked or declined moves to the parked or declined
file instead, created on first need. What varies is where the done-record goes, and that follows
**the plan's location** (next-roadmap-item §1), not how the work landed:

- **A tracked roadmap**: git history is the done-record—the deletion itself. This edit is the final
  fresh commit on the rebased tip, per §2a—minimal and localized, since every other lane is editing
  the same file.
- **A local-only roadmap** (every fork, and any owned repo keeping its plan off the record): the
  files are untracked and live only in the primary checkout, so there is no commit to make—delete
  the item and **append its done-record to the changelog** through `claim-a-lane`'s
  primary-checkout edit mechanics, once the unit passes the build gate. On a fork the entry carries
  a status keyword (`BUILT-LOCAL` / `DRAFTED` / `FILED` / `PR-READY` / `MERGED-UPSTREAM`, per
  next-roadmap-item §6). The changelog is a reasoning archive, not a landed list: capture what
  commit messages won't.

The conductor's per-completion log line and its wrap-up name items by `Rn.m` and by the roadmap's own
heading text.
