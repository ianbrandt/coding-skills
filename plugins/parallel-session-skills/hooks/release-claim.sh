#!/bin/sh
# Release this session's claim from the shared ledger when the session ends.
#
# The net, not the path: land-and-wrap releases at wrap, which hands the lane back
# immediately. This catches the session that ends without wrapping.
#
# Best-effort by design. Every unexpected condition is a silent no-op, because a
# hook that errors at session end is noise, and a hook that deletes the wrong claim
# kills a live sibling's lane.
set -u

# Both spellings exist: CLAUDE_SESSION_ID in the binary, CLAUDE_CODE_SESSION_ID in
# the tool environment. Without an id we cannot tell our claim from a sibling's.
id="${CLAUDE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"
[ -n "$id" ] || exit 0

# The ledger lives in the PRIMARY checkout, which is not necessarily this session's
# directory: a worktree session's project dir is the worktree. Ask git for it.
main=$(git -C "${CLAUDE_PROJECT_DIR:-.}" worktree list --porcelain 2>/dev/null | awk 'NR==1{print $2}')
[ -n "$main" ] || exit 0
[ -d "$main/.claude/claims" ] || exit 0

for f in "$main"/.claude/claims/*.json; do
  [ -e "$f" ] || continue                      # unmatched glob stays literal
  if grep -q "\"session\"[[:space:]]*:[[:space:]]*\"$id\"" "$f" 2>/dev/null; then
    rm -f "$f"
  fi
done
exit 0
