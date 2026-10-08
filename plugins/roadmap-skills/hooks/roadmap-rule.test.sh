#!/bin/sh
# Self-check for roadmap-rule.sh. Run it directly: sh roadmap-rule.test.sh
#
# The property under test: the rule is printed in a repo that has a roadmap of its
# own, and nothing is printed anywhere else. An upstream project's ROADMAP.md in a
# fork is not the user's plan, and a rule printed there sends a session to edit it.
set -u
S="$(cd "$(dirname "$0")" && pwd)/roadmap-rule.sh"
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
fails=0

check() { # check <label> <expected first line> <actual first line>
  if [ "$2" = "$3" ]; then echo "ok   - $1"
  else echo "FAIL - $1: expected [$2] got [$3]"; fails=$((fails + 1)); fi
}
seed() {
  rm -rf "$T/primary"; mkdir -p "$T/primary"
  git -C "$T/primary" init -q .; git -C "$T/primary" commit -q --allow-empty -m init
}
track() { # track <path>
  mkdir -p "$(dirname "$T/primary/$1")"; : > "$T/primary/$1"
  git -C "$T/primary" add "$1"; git -C "$T/primary" commit -q -m "add $1"
}
first() { CLAUDE_PROJECT_DIR="$1" sh "$S" | sed -n 1p; }
ON="ROADMAP RULE ACTIVE"

seed
check "prints nothing with no roadmap" "" "$(first "$T/primary")"

seed; : > "$T/primary/ROADMAP.local.md"
check "prints the rule for a local-only roadmap" "$ON" "$(first "$T/primary")"
git -C "$T/primary" worktree add -q "$T/primary/.claude/worktrees/lane" -b claude/lane
check "finds the local-only roadmap from a worktree" "$ON" "$(first "$T/primary/.claude/worktrees/lane")"
CLAUDE_PROJECT_DIR="$T/primary" sh "$S" | grep -q 'ROADMAP.local.md' \
  && echo "ok   - states the roadmap file" || { echo "FAIL - states the roadmap file"; fails=$((fails + 1)); }

seed; track ROADMAP.md
check "prints the rule for a tracked roadmap" "$ON" "$(first "$T/primary")"

seed; track docs/roadmap.md
check "prints the rule for the legacy tracked location" "$ON" "$(first "$T/primary")"

seed; track ROADMAP.md; git -C "$T/primary" remote add upstream https://example.invalid/x.git
check "prints nothing for an upstream project's ROADMAP.md in a fork" "" "$(first "$T/primary")"
: > "$T/primary/ROADMAP.local.md"
check "prints the rule for a fork with a local-only roadmap" "$ON" "$(first "$T/primary")"

seed; : > "$T/primary/ROADMAP.md"
check "prints nothing for an untracked ROADMAP.md" "" "$(first "$T/primary")"

check "prints nothing outside a git repo" "" "$(first "$T")"

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
