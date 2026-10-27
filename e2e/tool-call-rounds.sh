#!/usr/bin/env bash
# Runs e2e/tool-call-probe.sh until three runs of each setup are complete, with at most five
# attempts per setup: the installed claude with project settings, the installed claude with user
# settings too, and 2.1.310 from npm with project settings. A run is complete when the model made
# all five tool calls. The first complete run of each setup is printed in full, and the others
# without their debug log lines.
#   e2e/tool-call-rounds.sh <empty dir>
set -uo pipefail
dir=${1:?usage: e2e/tool-call-rounds.sh <empty dir>}
probe=$(cd "$(dirname "$0")" && pwd)/tool-call-probe.sh
mkdir -p "$dir" || exit 1
uname -s
cmd //c ver 2>/dev/null | tr -d '\r' | grep .

complete() {
  local t
  for t in Agent Bash Grep Read Write; do grep -qE "^ *[0-9]+ $t\$" "$1" || return 1; done
}
round() { # <setup name> <environment assignments for the probe>...
  local name=$1 ok=0 attempt=0 out
  shift
  echo "=== $name"
  while [ $ok -lt 3 ] && [ $attempt -lt 5 ]; do
    attempt=$((attempt + 1))
    out=$dir/$name-$attempt
    env "$@" bash "$probe" "$out" > "$out.txt" 2>&1
    if complete "$out.txt"; then
      ok=$((ok + 1))
      echo "--- attempt $attempt"
      if [ $ok = 1 ]; then cat "$out.txt"; else sed '/^Debug log lines/,$d' "$out.txt"; fi
    else
      echo "--- attempt $attempt, incomplete"
      sed '/^Debug log lines/,$d' "$out.txt"
    fi
  done
}

round installed-project PROBE_SETTING_SOURCES=project
round installed-user PROBE_SETTING_SOURCES=user,project
if ! command -v npm > /dev/null; then
  echo '=== 2.1.310 skipped: npm is not on the PATH'
elif ! npm install --prefix "$dir/v2.1.310" @anthropic-ai/claude-code@2.1.310 > "$dir/npm.log" 2>&1; then
  echo '=== 2.1.310 skipped: npm install failed'
  tail -5 "$dir/npm.log"
else
  round v2.1.310-project PROBE_SETTING_SOURCES=project PROBE_CLAUDE="$dir/v2.1.310/node_modules/.bin/claude"
fi
