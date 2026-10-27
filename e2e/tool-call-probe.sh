#!/usr/bin/env bash
# Measures which tool.call changes made by a user plugin reach the model: a changed Agent prompt, a
# changed Bash command, a Grep call denied without calling next, and context added to a Read result
# and to a Write result. One headless session loads a scratch plugin that adds a marker in each case
# and writes a file each time a hook runs. Each marker is then looked up in the session transcript
# on disk, so the result does not depend on the model repeating it. Run it with and without the
# cc-plugin-sec-default guard and compare.
#   e2e/tool-call-probe.sh <empty dir>
# PROBE_SETTING_SOURCES (default project) is passed to --setting-sources. Without user settings, the
# apiKeyHelper in the user settings file, if there is one, is passed alone with --settings.
# PROBE_CLAUDE (default claude) is the binary to run.
set -uo pipefail
dir=${1:?usage: e2e/tool-call-probe.sh <empty dir>}
mkdir -p "$dir" && cd "$dir" || exit 1
# Under Git Bash, claude.exe and $.fs.write need a Windows path.
here=$(cygpath -m "$PWD" 2>/dev/null || pwd)
cfg=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
cfg=$(cygpath -u "$cfg" 2>/dev/null || echo "$cfg")
claude=${PROBE_CLAUDE:-claude}
sources=${PROBE_SETTING_SOURCES:-project}
mkdir -p plug/.claude-plugin plug/hooks fired
echo hello > a.txt
echo '{ "name": "tool-call-probe" }' > plug/.claude-plugin/plugin.json
echo '{ "modules": ["./register.ts"] }' > plug/hooks/hooks.json
cat > plug/hooks/register.ts <<EOF
import type { Register } from 'claude-code'
const fired = (\$: any, name: string) => \$.fs.write('$here/fired/' + name, 'x').catch(() => {})
export const register: Register = on => {
  on('classic.PreToolUse', async (\$, e: any, next: any) => { await fired(\$, 'classic'); return next(e) })
  on('tool.call', { tool: 'Agent' }, async (\$, e: any, next: any) => {
    await fired(\$, 'agent')
    return next({ ...e, prompt: 'PROBE-AGENT-MARK. ' + e.prompt })
  })
  on('tool.call', { tool: 'Bash' }, async (\$, e: any, next: any) => {
    await fired(\$, 'bash')
    return next({ ...e, command: 'echo PROBE-BASH-MARK' })
  })
  on('tool.call', { tool: 'Grep' }, async (\$, e: any) => {
    await fired(\$, 'grep')
    return { deny: 'PROBE-GREP-MARK' }
  })
  on('tool.call', { tool: 'Read' }, async (\$, e: any, next: any) => {
    const ran = await next(e)
    await fired(\$, 'read')
    return { ...ran, context: [...(ran.context ?? []), 'PROBE-READ-MARK'] }
  })
  on('tool.call', { tool: 'Write' }, async (\$, e: any, next: any) => {
    const ran = await next(e)
    await fired(\$, 'write')
    return { ...ran, context: [...(ran.context ?? []), 'PROBE-WRITE-MARK'] }
  })
}
EOF

keys=()
case $sources in
  *user*) auth='user settings loaded' ;;
  *)
    helper=$(grep -oE '"apiKeyHelper"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' "$cfg/settings.json" 2>/dev/null | head -1)
    if [ -n "$helper" ]; then
      echo "{ $helper }" > keys.json
      keys=(--settings "$here/keys.json")
      auth='apiKeyHelper copied from user settings'
    else
      auth='no apiKeyHelper in user settings'
    fi ;;
esac

prompt="Make exactly these five tool calls, one at a time. Then reply with the word done, followed by
every piece of hook context you were shown after a tool result, quoted exactly, or the word none.
1. Agent, subagent_type general-purpose, prompt: Reply with the single word pong. Do not call any tool.
2. Bash, command: echo original
3. Grep, pattern: zzz, path: $here
4. Read, file_path: $here/a.txt
5. Write, file_path: $here/w.md, content: hello"
# project leaves out the installed plugins and user hooks; managed settings still apply.
"$claude" -p "$prompt" --model haiku --plugin-dir "$here/plug" --setting-sources "$sources" ${keys[@]+"${keys[@]}"} \
  --allowedTools=Agent,Bash,Grep,Read,Write --output-format stream-json --verbose \
  --debug-file "$here/debug.log" < /dev/null > stream.jsonl 2> stderr.txt
echo "exit $?"

echo "claude $("$claude" --version)"
echo "settings: $sources, $auth"
grep -o '"apiKeySource":"[^"]*"' stream.jsonl | head -1
sid=$(grep -o '"session_id":"[^"]*"' stream.jsonl | head -1 | cut -d'"' -f4)
t=$([ -n "$sid" ] && find "$cfg/projects" -name "$sid.jsonl" 2>/dev/null | head -1)
if [ -z "$t" ]; then
  echo "session transcript not found under $cfg/projects"
  t=/dev/null
fi
# rows <type> <marker>: whether a row of that type in the main transcript includes the marker. Not
# grep -q, which under pipefail fails the pipe when the first grep is cut off by SIGPIPE.
rows() { [ "$(grep -F "\"type\":\"$1\"" "$t" | grep -cF "$2")" -gt 0 ] && echo yes || echo no; }
ran() { [ -e "fired/$1" ] && echo yes || echo no; }
echo "API request rows in the transcript: $(grep -cF '"type":"api-request-blob"' "$t")"
printf 'classic.PreToolUse reached the plugin: %s\n' "$(ran classic)"
printf 'agent hook ran: %-3s  in the subagent prompt: %s\n' "$(ran agent)" \
  "$(grep -lF PROBE-AGENT-MARK "${t%.jsonl}"/subagents/*.jsonl > /dev/null 2>&1 && echo yes || echo no)"
for c in bash grep; do
  printf '%-5s hook ran: %-3s  in the tool result: %s\n' "$c" "$(ran "$c")" "$(rows user "PROBE-$(echo "$c" | tr a-z A-Z)-MARK")"
done
for c in read write; do
  mark="PROBE-$(echo "$c" | tr a-z A-Z)-MARK"
  printf '%-5s hook ran: %-3s  attachment recorded: %-3s  in an API request: %-3s  repeated by the model: %s\n' \
    "$c" "$(ran "$c")" "$(rows attachment "$mark")" "$(rows api-request-blob "$mark")" "$(rows assistant "$mark")"
done
echo 'Tool calls in the transcript:'
grep -o '"type":"tool_use","id":"[^"]*","name":"[^"]*"' stream.jsonl | sed 's/.*"name":"//; s/"$//' | sort | uniq -c
echo 'Debug log lines that mention the guard, a builtin or user plugin with a tool.call hook, or the probe plugin:'
grep -iE 'sec-default|bypass|tool-call-probe|powershell|tool\.call|attachment|agents-md\): .* found' debug.log |
  grep -vE 'plugin\.register|settings\.read|\$\.fs\.write|telemetry|LSP|skills via attachment' | cut -c1-300 | head -80
