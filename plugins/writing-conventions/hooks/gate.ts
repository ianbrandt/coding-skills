// The gate's model calls, made in-process where Claude Code runs function hooks.
// gate.sh still decides what is read and which findings stand. Run with
// WRITING_CONVENTIONS_MODULE set, it exits 3 where it would start a nested
// `claude -p`, and prints the key of the request, the model, and the directory
// that holds the request. A hook here answers through `$.model.complete`, which
// resolves a model alias the way `--model` does, and runs the script again.
//
// The command hooks in hooks.json still run for the same events. While a hook
// here has an event in hand, its token is in WRITING_CONVENTIONS_GATE_DONE in
// the environment those hooks start from, and gate.sh exits on finding it.
import type { Register } from 'claude-code'

// The function-hook API is early access and moves between releases. This is the
// CLI the module was checked on, and an older one keeps the command hooks' path.
const CHECKED = [2, 1, 289]

async function isChecked($: any): Promise<boolean> {
  const v = String((await $.session.version()).base).split('.').map(Number)
  for (let i = 0; i < 3; i++) if (v[i] !== CHECKED[i]) return v[i] > CHECKED[i]
  return true
}

// What the command hook would have done with this event: `block` for a finding,
// `context` for a note to the model, or neither. `skip` leaves the event to the
// command hook, which is every path where the script could not run this way.
type Verdict = { block?: string; context?: string; skip?: true }

// The directory the session started in, which is the project's unless the
// session was resumed after a `cd`. gate.sh reads it as CLAUDE_PROJECT_DIR.
let root = ''

// gate($, input, mode): one check through gate.sh, where `input` is the hook
// input the script reads and `mode` is its argument, if any.
async function gate($: any, input: unknown, mode?: string): Promise<Verdict> {
  if (!(await isChecked($))) return { skip: true }
  const stdin = JSON.stringify(input)
  const argv = ['bash', `${$.plugin.root}/hooks/gate.sh`, ...(mode ? [mode] : [])]
  // The script removes its request directory on every exit but 3, so a directory
  // is left only when this loop stops after one.
  let left = ''
  try {
    // A command can take a classifier call and then a reader call, and a
    // classifier reply that leaves keys out is asked again for those.
    for (let run = 0; run < 5; run++) {
      const ran = await $.process.run(argv, { stdin, env: { WRITING_CONVENTIONS_MODULE: '1', ...(root ? { CLAUDE_PROJECT_DIR: root } : {}) } })
      if (ran.exitCode !== 3) left = ''
      if (ran.exitCode === 2) return ran.stderr === '' ? { skip: true } : { block: ran.stderr }
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
  } catch {
    // The gate must not stop an event it could not check.
    return { skip: true }
  } finally {
    if (left.includes('/claude-gate-ask-')) await $.process.run(['rm', '-rf', left]).catch(() => {})
  }
}

// The events in hand. Tool calls can run at once, so the variable is a list.
const DONE = new Set<string>()

async function publish($: any): Promise<void> {
  await $.env.set('WRITING_CONVENTIONS_GATE_DONE', DONE.size === 0 ? undefined : [...DONE].join(' '))
}

// held($, id, prefix, verdict, next): runs the command hooks with the event's
// token in the list, unless the event was left to them.
async function held<T>($: any, id: unknown, prefix: string, verdict: Verdict, next: () => Promise<T>): Promise<T> {
  const token = prefix + String(id ?? '').replace(/[^A-Za-z0-9_-]/g, '_')
  if (verdict.skip || token === prefix) return next()
  DONE.add(token)
  await publish($)
  try {
    return await next()
  } finally {
    DONE.delete(token)
    await publish($)
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    root = await $.session.cwd()
    return next(e)
  })

  // A command or an MCP call, checked before it runs.
  on('tool.call', async ($, e, next) => {
    if (!/^(Bash$|PowerShell$|mcp__)/.test(e.tool)) return next(e)
    const { tool, tool_use_id, agentId, ...tool_input } = e as any
    const verdict = await gate($, {
      session_id: await $.session.id(),
      cwd: await $.session.cwd(),
      tool_name: tool,
      tool_input,
      tool_use_id,
    })
    if (verdict.block) return { deny: verdict.block }
    const ran = await held($, tool_use_id, '', verdict, () => next(e))
    return verdict.context && ran.deny === undefined
      ? { ...ran, context: [...(ran.context ?? []), verdict.context] }
      : ran
  })

  // A prose file just written: findings come back as context, and nothing is
  // blocked.
  on('classic.PostToolUse', async ($, e: any, next: any) => {
    if (e.tool_name !== 'Write' && e.tool_name !== 'Edit') return next(e)
    const verdict = await gate($, e, '--file')
    const ran = await held($, e.tool_use_id, 'file-', verdict, () => next(e))
    return verdict.context ? { ...ran, additionalContext: [...(ran.additionalContext ?? []), verdict.context] } : ran
  })

  // A draft in the reply: a finding blocks the stop, which gate.sh bounds per
  // turn.
  on('classic.Stop', async ($, e: any, next: any) => {
    if (!String(e.last_assistant_message ?? '').includes('draft')) return next(e)
    const verdict = await gate($, e, '--stop')
    const ran = await held($, e.prompt_id, 'stop-', verdict, () => next(e))
    return verdict.block ? { ...ran, block: verdict.block } : ran
  })
}
