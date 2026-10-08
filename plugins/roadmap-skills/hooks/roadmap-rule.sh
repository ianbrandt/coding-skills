#!/bin/sh
# Print the roadmap rule at session start, in a repo that has a roadmap of its own.
#
# The lookup is next-roadmap-item §1's, in the same order: a local-only roadmap
# first, then the fork check, then a tracked one. Anywhere else the hook prints
# nothing, so a repo with no roadmap pays no context for it.
set -u

dir="${CLAUDE_PROJECT_DIR:-.}"
main=$(git -C "$dir" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
[ -n "$main" ] || exit 0

if [ -f "$main/ROADMAP.local.md" ]; then
  roadmap=ROADMAP.local.md
elif git -C "$main" remote get-url upstream >/dev/null 2>&1; then
  exit 0                                       # a fork: a tracked ROADMAP.md is the upstream project's
else
  roadmap=$(git -C "$main" ls-files ROADMAP.md docs/roadmap.md 2>/dev/null | sed -n 1p)
  [ -n "$roadmap" ] || exit 0
fi

cat <<EOF
ROADMAP RULE ACTIVE

This repo's plan of record is \`$roadmap\`, in the primary checkout at \`$main\`.

A task the user states directly is handled like an item picked off the roadmap. Before the first
edit to a file that will be committed:

1. Find the task in \`$roadmap\`. If it is not there, write it as a new item at its priority
   position: the problem in a sentence or two, and the paths it touches. Take the next free \`Rn\`
   ID, checked against the parked, declined, and changelog files too, since an ID is never reused.
2. Run \`next-roadmap-item <Rn>\`. The worktree, the branch name, the claim, and the landing all
   come from there. Run it even when a task-specific skill, an upgrade or a refactor, covers the
   work: from that skill you learn what to change, not where to make the change or how it leaves
   the branch.
3. Land through \`land-and-wrap\` only. When a standing instruction authorizes merging to the
   default branch, \`land-and-wrap\` §1 is still where you find out whether this repo is a fork and
   whether its work lands as a pull request.

Size is no exemption: a one-line change that will be committed gets an item. A question answered
by reading gets none, and neither does an edit to the roadmap files themselves.
EOF
