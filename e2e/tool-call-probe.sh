#!/usr/bin/env bash
# Measures which tool.call changes made by a user plugin reach the model: a changed Agent prompt, a
# changed Bash command, a Grep call denied without calling next, and context added to a Read result. One headless session loads a scratch plugin that adds a marker in each case and writes a
# file each time a hook runs. Run it with and without the cc-plugin-sec-default guard and compare.
#   e2e/tool-call-probe.sh <empty dir>
set -uo pipefail
dir=${1:?usage: e2e/tool-call-probe.sh <empty dir>}
mkdir -p "$dir" && cd "$dir" || exit 1
# Under Git Bash, claude.exe and $.fs.write need a Windows path.
here=$(cygpath -m "$PWD" 2>/dev/null || pwd)
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
}
EOF

prompt="Make exactly these four tool calls, one at a time, then reply with the word done.
1. Agent, subagent_type general-purpose, prompt: Reply with the single word pong. Do not call any tool.
2. Bash, command: echo original
3. Grep, pattern: zzz, path: $here
4. Read, file_path: $here/a.txt"
# --setting-sources project leaves out the installed plugins and user hooks; managed settings still apply.
claude -p "$prompt" --model haiku --plugin-dir "$here/plug" --setting-sources project \
  --allowedTools=Agent,Bash,Grep,Read --output-format stream-json --verbose \
  --debug-file "$here/debug.log" < /dev/null > stream.jsonl 2> stderr.txt
echo "exit $?"

echo "claude $(claude --version)"
printf 'classic.PreToolUse reached the plugin: %s\n' "$([ -e fired/classic ] && echo yes || echo no)"
for c in agent bash grep read; do
  mark="PROBE-$(echo "$c" | tr a-z A-Z)-MARK"
  printf '%-5s hook ran: %-3s  change reached the model: %s\n' "$c" \
    "$([ -e "fired/$c" ] && echo yes || echo no)" "$(grep -q "$mark" stream.jsonl && echo yes || echo no)"
done
echo 'Tool calls in the transcript:'
grep -o '"type":"tool_use","id":"[^"]*","name":"[^"]*"' stream.jsonl | sed 's/.*"name":"//; s/"$//' | sort | uniq -c
echo 'Debug log lines that mention the guard or the probe plugin:'
grep -iE 'sec-default|bypass|tool-call-probe' debug.log | head -60
