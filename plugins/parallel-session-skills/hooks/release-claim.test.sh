#!/bin/sh
# Self-check for release-claim.sh. Run it directly: sh release-claim.test.sh
#
# The property that matters: the hook releases exactly its own session's claim and
# never a sibling's. A hook that over-deletes kills a live lane; one that
# under-deletes leaks a lease nothing can expire.
set -u
S="$(cd "$(dirname "$0")" && pwd)/release-claim.sh"
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
fails=0

check() { # check <label> <expected-remaining> <actual-remaining>
  if [ "$2" = "$3" ]; then echo "ok   - $1"
  else echo "FAIL - $1: expected [$2] got [$3]"; fails=$((fails + 1)); fi
}
claims() { ls "$T/primary/.claude/claims/" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'; }
seed() {
  rm -rf "$T/primary"; mkdir -p "$T/primary/.claude/claims"
  git -C "$T/primary" init -q .; git -C "$T/primary" commit -q --allow-empty -m init
  printf '{ "session": "MINE", "item": "a" }\n'    > "$T/primary/.claude/claims/a.json"
  printf '{ "session": "SIBLING", "item": "b" }\n' > "$T/primary/.claude/claims/b.json"
  printf '{ "item": "no-session-field" }\n'        > "$T/primary/.claude/claims/c.json"
}

seed
git -C "$T/primary" worktree add -q "$T/primary/.claude/worktrees/lane" -b claude/lane
CLAUDE_SESSION_ID=MINE CLAUDE_PROJECT_DIR="$T/primary/.claude/worktrees/lane" sh "$S"
check "releases own claim when run from a worktree" "b.json c.json" "$(claims)"

seed
CLAUDE_SESSION_ID=NOBODY CLAUDE_PROJECT_DIR="$T/primary" sh "$S"
check "unmatched id deletes nothing" "a.json b.json c.json" "$(claims)"

seed
(unset CLAUDE_SESSION_ID CLAUDE_CODE_SESSION_ID; CLAUDE_PROJECT_DIR="$T/primary" sh "$S")
check "missing session id deletes nothing" "a.json b.json c.json" "$(claims)"

seed
printf '{ "session": "", "item": "d" }\n' > "$T/primary/.claude/claims/d.json"
CLAUDE_SESSION_ID="" CLAUDE_CODE_SESSION_ID="" sh "$S"
check "empty id cannot match an empty session field" "a.json b.json c.json d.json" "$(claims)"

seed
CLAUDE_SESSION_ID=MINE CLAUDE_PROJECT_DIR=/ sh "$S"
check "non-repo project dir is a no-op" "a.json b.json c.json" "$(claims)"

seed; rm -rf "$T/primary/.claude/claims"
CLAUDE_SESSION_ID=MINE CLAUDE_PROJECT_DIR="$T/primary" sh "$S"
check "absent ledger exits clean" "" "$(claims)"

[ "$fails" -eq 0 ] && echo "PASS" || { echo "$fails FAILED"; exit 1; }
