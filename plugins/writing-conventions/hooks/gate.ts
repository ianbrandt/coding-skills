// The gate's model calls, made in-process where Claude Code runs function hooks.
// gate.sh still decides what is read and which findings stand. Run with
// WRITING_CONVENTIONS_MODULE set, it exits 3 where it would start a nested
// `claude -p`, and prints the key of the request, the model, and the directory
// that holds the request. This hook answers through `$.model.complete`, which
// resolves a model alias the way `--model` does, and runs the script again.
import type { Register } from 'claude-code'

// The function-hook API is early access and moves between releases. This is the
// CLI the module was checked on, and an older one keeps the command hook's path.
const CHECKED = [2, 1, 289]

async function isChecked($: any): Promise<boolean> {
  const v = String((await $.session.version()).base).split('.').map(Number)
  for (let i = 0; i < 3; i++) if (v[i] !== CHECKED[i]) return v[i] > CHECKED[i]
  return true
}

// What the command hook would have done with this call: `deny` for a finding,
// `context` for a note to the model, or neither. `skip` leaves the call to the
// command hook, which is every path where the script could not run this way.
async function gate($: any, e: any): Promise<{ deny?: string; context?: string; skip?: true }> {
  if (!(await isChecked($))) return { skip: true }
  const { tool, tool_use_id, agentId, ...tool_input } = e
  const stdin = JSON.stringify({
    session_id: await $.session.id(),
    cwd: await $.session.cwd(),
    tool_name: tool,
    tool_input,
    tool_use_id,
  })
  const script = `${$.plugin.root}/hooks/gate.sh`
  // The script removes its request directory on every exit but 3, so a directory
  // is left only when this loop stops after one.
  let left = ''
  try {
    // A command can take a classifier call and then a reader call.
    for (let run = 0; run < 3; run++) {
      const ran = await $.process.run(['bash', script], { stdin, env: { WRITING_CONVENTIONS_MODULE: '1' } })
      if (ran.exitCode !== 3) left = ''
      if (ran.exitCode === 2) return { deny: ran.stderr }
      if (ran.exitCode === 0) {
        if (ran.stdout.trim() === '') return {}
        const out = JSON.parse(ran.stdout)
        if (out.systemMessage) $.ui.toast(out.systemMessage, { timeoutMs: 15000 })
        return { context: out.hookSpecificOutput?.additionalContext }
      }
      if (ran.exitCode !== 3) return { skip: true }
      const [key, model, dir] = ran.stdout.split('\n')
      left = dir
      const reply = await $.model.complete({
        model,
        system: await $.fs.read(`${dir}/system.${key}`),
        prompt: await $.fs.read(`${dir}/prompt.${key}`),
        timeoutMs: 60000,
      })
      if (reply.isAnswered) await $.fs.write(`${dir}/reply.${key}`, reply.text)
      else await $.fs.write(`${dir}/fail.${key}`, '')
    }
    return { skip: true }
  } finally {
    if (left.includes('/claude-gate-ask-')) await $.process.run(['rm', '-rf', left])
  }
}

export const register: Register = on => {
  on('tool.call', async ($, e, next) => {
    if (!/^(Bash$|PowerShell$|mcp__)/.test(e.tool)) return next(e)
    let verdict: Awaited<ReturnType<typeof gate>> = { skip: true }
    try {
      verdict = await gate($, e)
    } catch {
      // The gate must not stop a call it could not check.
    }
    if (verdict.deny) return { deny: verdict.deny }
    const ran = await next(e)
    return verdict.context && ran.deny === undefined
      ? { ...ran, context: [...(ran.context ?? []), verdict.context] }
      : ran
  })
}
