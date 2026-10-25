// The plugin's hooks module: the rules a session starts with, and the one rule
// a subagent starts with.
import type { Register } from 'claude-code'

export const SUBAGENT_RULE = "You are a subagent with no user to ask. Before a decision that is hard to reverse (a wire contract or public API, a data schema or file format, a name that becomes permanent, text that publishes under the user's name, a push to a public repository, a call later work will build on), put the decision and its options, with what each costs, in your result instead of settling it silently. The agent reading your report is the one who can stop."

// Set when a classic event reaches this plugin, and when classic.SessionStart
// added the rules. Under managed settings `cc-plugin-sec-default` sends every
// `classic.*` event past it, and the native events below stand in. Kept in
// $.state, which outlives a hot reload. A plugin loaded mid-session sees no
// classic.SessionStart, so the rules fallback waits on that one alone.
const CLASSIC = { plugin: 'orchestration-skills', key: 'classic' } as const
const STARTED = { plugin: 'orchestration-skills', key: 'started' } as const
const isClassic = async ($: any) => (await $.state.get(CLASSIC).catch(() => ({}))).value === true
const isStarted = async ($: any) => (await $.state.get(STARTED).catch(() => ({}))).value === true

// Whether the model still reads this text: false after /clear, a compaction,
// or a plugin update that changed it, and undefined where the conversation is
// not read back, as a Workflow agent's is not on 2.1.310. Context added to a
// tool call is in its result.
async function isRead($: any, text: string, agentId?: string): Promise<boolean | undefined> {
  const messages = await $.session.messages({ ...(agentId && { agentId }), as: 'api' }).catch(() => undefined)
  if (!Array.isArray(messages)) return undefined
  const has = (b: any): boolean => b.type === 'text' ? String(b.text).includes(text)
    : b.type === 'tool_result' && (typeof b.content === 'string' ? b.content.includes(text) : Array.isArray(b.content) && b.content.some(has))
  return messages.some(m => m.role === 'user' && Array.isArray(m.content) && m.content.some(has))
}

export const register: Register = on => {
  on('classic.SessionStart', async ($, e: any, next: any) => {
    await $.state.set(CLASSIC, true).catch(() => {})
    await $.state.set(STARTED, true).catch(() => {})
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
    if (await isStarted($)) return next(e)
    const rules = await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    return next(rules && !(await isRead($, rules)) ? { ...e, context: [...(e.context ?? []), rules] } : e)
  })

  on('tool.call', { tool: 'Agent' }, async ($, e: any, next: any) =>
    next((await isClassic($)) ? e : { ...e, prompt: `${SUBAGENT_RULE}\n\n${e.prompt}` }))

  // Under the guard a Workflow's agents start without the rule, and after an
  // automatic compaction in the middle of a turn the main loop goes without
  // the rules until the next prompt. They are added to the next tool result,
  // and not again until the model reads them back: calls that run in parallel
  // all start before any result is read back, and a Workflow agent's
  // conversation is never read back.
  // ponytail: kept in memory, so after a hot reload a running Workflow agent gets the rule a second time.
  const added = new Set<string>()
  on('tool.call', async ($, e: any, next: any) => {
    const ran = await next(e)
    if (ran.deny !== undefined) return ran
    const key = e.agentId ?? (await $.session.id().catch(() => ''))
    const text = e.agentId ? ((await isClassic($)) ? '' : SUBAGENT_RULE)
      : (await isStarted($)) ? '' : await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    if (!text) return ran
    const read = await isRead($, text, e.agentId)
    if (read) added.delete(key)
    if (read || added.has(key) || (read === undefined && !e.agentId)) return ran
    added.add(key)
    return { ...ran, context: [...(ran.context ?? []), text] }
  })
}
