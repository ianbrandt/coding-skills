// The plugin's hooks module: the rules a session starts with.
import type { Register } from 'claude-code'

export const register: Register = on => {
  // A fork starts with its parent's context, where the rules already are.
  on('classic.SessionStart', async ($, e: any, next: any) => {
    const ran = await next(e)
    if (e.source === 'fork') return ran
    const rules = await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    return rules ? { ...ran, additionalContext: [...(ran.additionalContext ?? []), rules] } : ran
  })
}
