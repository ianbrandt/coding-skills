# roadmap-skills

A [Claude Code](https://claude.ai/code) plugin for driving a repo's roadmap when
you track work as a roadmap file rather than GitHub issues.

## Skills

### `next-roadmap-item`

Claims the next unclaimed, file-disjoint item on the repo's roadmap and starts
building it test-first, coordinating with other concurrent sessions so they don't
collide.

The plan of record lives in one of two places, and this skill finds it:

- **tracked** at the repo root, in a repo you own. The landing commit that
  deletes the item is the done-record, so there is no changelog.
- **local-only**, for an upstream OSS project you contribute to via a fork. The
  roadmap and its companions are untracked, so git history can't hold the
  done-record and `ROADMAP-CHANGELOG.local.md` does.

Naming follows that split: tracked repos carry `ROADMAP.md` plus
`ROADMAP-PARKED.md` and `ROADMAP-DECLINED.md` as needed; a local-only plan uses
the same names with a `.local.md` suffix, which is both the never-commit signal
and what keeps a shadow roadmap from colliding with an upstream project's real
`ROADMAP.md`. (`docs/roadmap.md` is honored as a legacy location.)

Where the plan lives is a separate question from how finished work lands—
`land-and-wrap` decides that from whether the repo is a fork and whether its
origin is public. A repo you own can carry a local-only roadmap and still merge
into its own default branch.

An optional lane hint (`/next-roadmap-item R1`) biases the pick without
overriding the no-collision rules. Point the hint at an item that's already in
flight and partially built and the skill **resumes** it, adopting that item's
existing worktree and continuing its branch instead of opening a new one off the
default branch. It finds the lane from the roadmap's own pin or an existing
worktree, not from the claim ledger—a session releases its claim at wrap whether
or not its item finished.

### `execute-roadmap`

The roadmap half of an unattended run. The conductor loop itself—the in-flight
cap, the fill loop, retries, the build gate, the stop conditions—is
`session-skills`' `conduct-a-pipeline`, which works the same way whatever the
backlog is. This skill supplies that loop's two roadmap-shaped inputs: the
ordered candidate list (open, ungated, and on a fork not flagged as requiring
you present) and, once an item is green, deleting it from the roadmap or
appending its changelog entry.

The split is why the loop is worth having: a conductor holding several lanes
open is the reader that needs mechanical disjointness, and nothing about holding
those lanes open is specific to tracking work in a markdown file.

## What it pairs with

`session-skills` owns the worktree, the claim ledger, and landing; this plugin
is a **backlog plugin** for it, answering what is workable, where an item is
already in flight, and how a landed item gets recorded—backed by a markdown file
rather than an issue tracker. The dependency runs one way: these skills call into
`session-skills`, never the reverse, so a different backlog (issues, a tracker)
plugs into the same seam without touching it.

Sequencing lives here, because a gate between two items is known before any
session starts and only the backlog can answer it. Disjointness does not: which
files a lane touches is a fact about the working tree, and the claim ledger
carries it.
