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
  roadmap and its companions are untracked, so the done-record is written to
  `ROADMAP-CHANGELOG.local.md` instead of git history.

Naming follows that split: tracked repos have `ROADMAP.md` plus
`ROADMAP-PARKED.md` and `ROADMAP-DECLINED.md` as needed; a local-only plan uses
the same names with a `.local.md` suffix, which is both the never-commit signal
and what keeps a shadow roadmap from colliding with an upstream project's real
`ROADMAP.md`. (`docs/roadmap.md` is honored as a legacy location.)

Where the plan lives is a separate question from how finished work lands. To
land it, `land-and-wrap` checks whether the repo is a fork, whether its default
branch is protected, whether its origin is public, and any `git config` override
the user set per clone. Work in a repo you own lands in its default branch even
when the roadmap is local-only.

An optional lane hint (`/next-roadmap-item R1`) biases the pick without
overriding the no-collision rules. Point the hint at an item that's already in
flight and partially built and the skill **resumes** it, adopting that item's
existing worktree and continuing its branch instead of opening a new one off the
default branch. It finds the lane from the pin in the roadmap or an existing
worktree, not from the claim ledger—a session releases its claim at wrap whether
or not its item finished.

### `execute-roadmap`

The roadmap half of an unattended run. The conductor loop—the in-flight cap,
the fill loop, retries, the build gate, the stop conditions—is
`parallel-session-skills`' `conduct-a-pipeline`, which works the same way
whatever the backlog is. This skill supplies the two inputs that loop takes from
the roadmap: the ordered candidate list (open, ungated, and on a fork not
flagged as requiring you present) and, once an item is green, deleting it from
the roadmap or appending its changelog entry, or, for a PR not yet merged,
pinning it to its branch.

The loop is kept in `parallel-session-skills` because a conductor with several
lanes open needs the disjointness check on the claim ledger, and none of that
work depends on the backlog being a markdown file.

## What it pairs with

The worktree and landing are handled in `session-skills`, and the claim ledger
in `parallel-session-skills`. This plugin is a **backlog plugin** for both: it
supplies what is workable, where an item is already in flight, and how a landed
item gets recorded, from a markdown file rather than an issue tracker. The
dependency runs one way: these skills call into those, never the reverse, so a
different backlog (issues, a tracker) plugs into the same seam without touching
it.

`next-roadmap-item` needs only `session-skills`. When there is no ledger to
read, it runs uncoordinated and reports that in one line. `execute-roadmap`
needs `parallel-session-skills` too, since the conductor loop is defined there.

Sequencing is recorded in the roadmap, because a gate between two items is
known before any session starts and is written only in the backlog. Which files
a lane touches is a fact about the working tree, so disjointness is checked
against the claim ledger.

## How it is wired

One hooks module, `hooks/register.ts`, which is a Claude Code mod and needs Claude Code 2.1.286 or
later, the oldest version supported. No shell or interpreter is involved, and git is run directly.
`delete_item` needs git 2.36 or later, since the worktree list is read with `-z`.

At session start, in a repo that has a roadmap, the module adds a short rule: a task the user states directly ("upgrade X") gets a roadmap item, is entered
through `next-roadmap-item`, and is landed through `land-and-wrap`. On a local-only roadmap the item is
written first. On a tracked one the ID is taken first and the item is written in the lane's worktree
once it is open, and the next free ID is one more than the highest among the roadmap files, the
open worktree directory names, and the items in live claims. Without the rule such a session
never loads a skill from this plugin, and it writes no item, opens no worktree, and decides the
landing from whatever standing instruction it finds. In a repo with no roadmap nothing is added.

Two tools are registered. `mcp__roadmap-skills__find_roadmap` is called from `next-roadmap-item` §1
and returns the primary checkout, the kind of roadmap, and its absolute path, from any worktree.
`mcp__roadmap-skills__delete_item` is called from `next-roadmap-item` to delete a landed item: from the item's heading to the next heading of the same or a higher level,
with headings inside a fenced block skipped. The deletion is a pure function in `hooks/item.ts`,
checked by `claude plugin test` with `hooks/item.test.ts`.

The rule and `find_roadmap` share one lookup, in `hooks/plan.ts` with `hooks/plan.test.ts`: a
`ROADMAP.local.md` in the primary checkout, else a tracked `ROADMAP.md` or `docs/roadmap.md` in a
repo with no `upstream` remote. A fork's tracked `ROADMAP.md` is the upstream project's, so no rule
is added there.
