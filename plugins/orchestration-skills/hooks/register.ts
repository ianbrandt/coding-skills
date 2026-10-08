// The plugin's hooks module: the rules a session starts with, and the one rule
// a subagent starts with.
import type { Register } from 'claude-code'

export const SUBAGENT_RULE = "You are a subagent with no user to ask. Before a decision that is hard to reverse (a wire contract or public API, a data schema or file format, a name that becomes permanent, text that publishes under the user's name, a push to a public repository, a call later work will build on), put the decision and its options, with what each costs, in your result instead of settling it silently. The agent reading your report is the one who can stop."

export const register: Register = on => {
  on('classic.SessionStart', async ($, e: any, next: any) => {
    const ran = await next(e)
    const rules = await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    return rules ? { ...ran, additionalContext: [...(ran.additionalContext ?? []), rules] } : ran
  })

  on('classic.SubagentStart', async ($, e: any, next: any) => {
    const ran = await next(e)
    return { ...ran, additionalContext: [...(ran.additionalContext ?? []), SUBAGENT_RULE] }
  })
}
