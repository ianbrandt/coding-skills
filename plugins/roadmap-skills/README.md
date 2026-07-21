# roadmap-skills

A [Claude Code](https://claude.ai/code) plugin for driving a repo's roadmap when
you track work as a roadmap file rather than GitHub issues.

## Skills

### `next-roadmap-item`

Claims the next unclaimed, file-disjoint item on the repo's roadmap and starts
building it test-first, coordinating with other concurrent sessions through git
worktrees and a shared claim ledger so they don't collide.

Runs in one of two auto-detected modes:

- **versioned**: a repo you own. The roadmap is tracked, git history is the
  done-record, and finished work lands on the default branch by fast-forward and
  is pushed.
- **local**: an upstream OSS project you contribute to via a fork. The roadmap
  and its companion files are untracked and local-only; **nothing is written to
  GitHub** (no push, issues, comments, or PRs). Issue, comment, and PR text is
  drafted as local files for you to review and post by hand, and a local
  changelog stands in for git history.

An optional lane hint (`/next-roadmap-item R1`) biases the pick without
overriding the no-collision rules.

The roadmap family lives at the repo root under one naming rule: versioned repos
track `ROADMAP.md` plus `ROADMAP-PARKED.md`/`ROADMAP-DECLINED.md` as needed;
local mode uses the same names with a `.local.md` suffix plus
`ROADMAP-CHANGELOG.local.md` as the done-record git history can't provide. The
suffix keeps a shadow roadmap from colliding with an upstream project's real
`ROADMAP.md`. (`docs/roadmap.md` is honored as a legacy location.)

### `execute-roadmap`

An unattended conductor for working through the whole roadmap in one session: it
claims several file-disjoint items, builds each in its own worktree via a
background Workflow (2–5 in flight), and processes each as it finishes, until the
roadmap is dry or the plan is invalidated. In **versioned** mode it lands each
item serially on the default branch; in **local** mode it stages each on its own
branch (no GitHub writes) for you to sync. Built on `next-roadmap-item`'s mode
detection and worktree/claim mechanics.
