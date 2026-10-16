#!/bin/bash
# usage: lap.sh first|resume <dir>
# Builds a scratch repo in <dir>, runs one headless session on it with every plugin in this
# checkout loaded and the installed @ianbrandt copies turned off, then writes the repo's state.
# LAP_PLUGINS points at another checkout's plugins, and LAP_MODEL picks the model (opus by default).
set -uo pipefail
S=$(cd "$(dirname "$0")" && pwd)
P=${LAP_PLUGINS:-$(cd "$S/../plugins" && pwd)}
D=$2
case $1 in
  first) "$S/setup.sh" "$D" > /dev/null; cwd=$D/repo; prompt='/roadmap-skills:next-roadmap-item R1' ;;
  resume) "$S/setup.sh" "$D" resume > /dev/null; cwd=$D/repo/.claude/worktrees/r2-plum-wren
    prompt='/roadmap-skills:next-roadmap-item R2' ;;
  *) echo "usage: lap.sh first|resume <dir>" >&2; exit 2 ;;
esac

dirs=(); off=()
for p in "$P"/*/; do
  dirs+=(--plugin-dir "${p%/}")
  off+=("\"$(basename "$p")@ianbrandt\":false")
done
settings="{\"enabledPlugins\":{$(IFS=,; echo "${off[*]}")}}"

(cd "$cwd" && GHOSTWRITING_DIR=$D/voice claude -p "$prompt" --model "${LAP_MODEL:-opus}" \
  "${dirs[@]}" --settings "$settings" --permission-mode acceptEdits \
  --allowedTools Bash Read Edit Write Glob Grep Skill Agent \
    mcp__roadmap-skills mcp__session-skills mcp__parallel-session-skills mcp__writing-conventions \
  --output-format stream-json --verbose > "$D/lap.jsonl" 2> "$D/lap.err" < /dev/null)
echo "exit $?" > "$D/state.txt"

R=$D/repo
{ git -C "$R" worktree list; git -C "$R" branch -a; git -C "$R" log --oneline -5 main
  git -C "$R" status --short
  echo '--- origin'; git -C "$D/origin.git" log --oneline main
  echo '--- roadmap'; grep '^## ' "$R/ROADMAP.local.md"
  echo '--- changelog'; cat "$R/ROADMAP-CHANGELOG.local.md"
  echo '--- claims'; ls -A "$R/.claude/claims" 2>&1
  echo '--- worktrees dir'; ls -A "$R/.claude/worktrees" 2>&1
  echo '--- check'; (cd "$R" && sh check.sh; cat ./*.txt)
} >> "$D/state.txt" 2>&1
