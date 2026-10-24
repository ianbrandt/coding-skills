// The plugin's hooks module: the rules a session starts with, and the one rule
// a subagent starts with.
import type { Register } from 'claude-code'

export const SUBAGENT_RULE = "You are a subagent with no user to ask. Before a decision that is hard to reverse (a wire contract or public API, a data schema or file format, a name that becomes permanent, text that publishes under the user's name, a push to a public repository, a call later work will build on), put the decision and its options, with what each costs, in your result instead of settling it silently. The agent reading your report is the one who can stop."

// Set when a classic event reaches this plugin. Under managed settings
// `cc-plugin-sec-default` sends every `classic.*` event past it, and the native
// events below stand in. Kept in $.state, which outlives a hot reload.
const CLASSIC = { plugin: 'orchestration-skills', key: 'classic' } as const
const isClassic = async ($: any) => (await $.state.get(CLASSIC).catch(() => ({}))).value === true

// Whether the model still reads this text: false after /clear, a compaction,
// or a plugin update that changed it.
async function isRead($: any, text: string): Promise<boolean> {
  const messages: any[] = await $.session.messages({ as: 'api' }).catch(() => [])
  return messages.some(m => m.role === 'user' && m.content.some((b: any) => b.type === 'text' && String(b.text).includes(text)))
}

export const register: Register = on => {
  on('classic.SessionStart', async ($, e: any, next: any) => {
    await $.state.set(CLASSIC, true).catch(() => {})
    const ran = await next(e)
    const rules = await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    return rules ? { ...ran, additionalContext: [...(ran.additionalContext ?? []), rules] } : ran
  })

  on('classic.SubagentStart', async ($, e: any, next: any) => {
    await $.state.set(CLASSIC, true).catch(() => {})
    const ran = await next(e)
    return { ...ran, additionalContext: [...(ran.additionalContext ?? []), SUBAGENT_RULE] }
  })

  on('prompt.submit', async ($, e: any, next: any) => {
    if (await isClassic($)) return next(e)
    const rules = await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    return next(rules && !(await isRead($, rules)) ? { ...e, context: [...(e.context ?? []), rules] } : e)
  })

  // ponytail: under the guard only a subagent started with the Agent tool gets the rule, so a Workflow's agents start without it.
  on('tool.call', { tool: 'Agent' }, async ($, e: any, next: any) =>
    next((await isClassic($)) ? e : { ...e, prompt: `${SUBAGENT_RULE}\n\n${e.prompt}` }))
}
