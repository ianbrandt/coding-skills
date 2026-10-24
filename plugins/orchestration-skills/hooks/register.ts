// The plugin's hooks module: the rules a session starts with, and the one rule
// a subagent starts with.
import type { Register } from 'claude-code'

export const SUBAGENT_RULE = "You are a subagent with no user to ask. Before a decision that is hard to reverse (a wire contract or public API, a data schema or file format, a name that becomes permanent, text that publishes under the user's name, a push to a public repository, a call later work will build on), put the decision and its options, with what each costs, in your result instead of settling it silently. The agent reading your report is the one who can stop."

export const register: Register = on => {
  // A fork starts with its parent's context, where the rules already are, so
  // the first prompt in a fork sees nothing added.
  // ponytail: `cc-plugin-sec-default` forwards `classic.SessionStart` past user mods under managed settings, so the rules go in on the first prompt instead.
  const seen = new Set<string>()
  on('session.start', async ($, e: any, next: any) => {
    const ran = await next(e)
    const id = String((await $.session.id().catch(() => '')) ?? '')
    if (e.source === 'fork') seen.add(id)
    else seen.delete(id)
    return ran
  })
  on('prompt.submit', async ($, e: any, next: any) => {
    const id = String((await $.session.id().catch(() => '')) ?? '')
    if (seen.has(id)) return next(e)
    seen.add(id)
    const rules = await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    return next(rules ? { ...e, text: `${rules}\n\n${String(e.text ?? '')}` } : e)
  })

  on('classic.SubagentStart', async ($, e: any, next: any) => {
    const ran = await next(e)
    return { ...ran, additionalContext: [...(ran.additionalContext ?? []), SUBAGENT_RULE] }
  })
}
