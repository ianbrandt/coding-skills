// claude plugin test: the context added at a session's start and a subagent's,
// and the native fallback where the classic events do not reach the plugin.
import { expect, test } from 'claude-code/testing'
import { SUBAGENT_RULE } from './register'

const RULES = 'ORCHESTRATION MODE ACTIVE\n\nthe rules'

// Under managed settings cc-plugin-sec-default sends every classic.* event past
// user plugins, as this copy of its rule does.
const guard = { name: 'guard', tier: 'prepend' as const, register(on: any) {
  on('classic.*', (_$: any, e: any, next: any) => next.to(e, 'append'))
} }

// `read` is the text the model still reads, and `task` the last subagent task.
function world(on: any) {
  const w = { read: [] as string[], task: '' }
  on('fs.read', () => ({ value: RULES }))
  on('session.messages', () => ({ value: w.read.map(text => ({ role: 'user', content: [{ type: 'text', text }] })) }))
  on('classic.SessionStart', () => ({ additionalContext: ['from a settings hook'] }))
  on('classic.SubagentStart', () => ({}))
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text, context: e.context }))
  on('tool.call', (_$: any, e: any) => { w.task = e.prompt; return { result: 'done' } })
  return w
}

test('a session starts with the rules, after the context of a settings hook', async ($: any, on: any) => {
  world(on)
  expect((await $.classic.SessionStart({ source: 'startup' })).additionalContext).toEqual(['from a settings hook', RULES])
})

test('a subagent starts with the escalation rule only', async ($: any, on: any) => {
  world(on)
  expect((await $.classic.SubagentStart({})).additionalContext).toEqual([SUBAGENT_RULE])
})

test('where the classic events run, nothing is added to a prompt or an Agent task', async ($: any, on: any) => {
  const w = world(on)
  await $.classic.SessionStart({ source: 'startup' })
  expect((await $.prompt.submit({ text: 'hi' })).context ?? []).toEqual([])
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe('look')
})

test('under the guard, the rules are added to a prompt once the model no longer reads them', { plugins: [guard] }, async ($: any, on: any) => {
  const w = world(on)
  await $.classic.SessionStart({ source: 'startup' })
  expect((await $.prompt.submit({ text: 'hi' })).context).toEqual([RULES])
  w.read = [`<system-reminder>\n${RULES}\n</system-reminder>`]
  expect((await $.prompt.submit({ text: 'again' })).context ?? []).toEqual([])
  w.read = ['ORCHESTRATION MODE ACTIVE\n\nolder rules']
  expect((await $.prompt.submit({ text: 'after an update' })).context).toEqual([RULES])
})

test('under the guard, an Agent task opens with the escalation rule', { plugins: [guard] }, async ($: any, on: any) => {
  const w = world(on)
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe(`${SUBAGENT_RULE}\n\nlook`)
})

// The conversations read back, by agent: the main loop under '', an Agent
// subagent's under its ID, and none for a Workflow agent, as on 2.1.310. A
// string is a text block, as a prompt's context and an Agent task are, and
// `result` is the text of a tool result. `deny` refuses the next tool call.
type Read = string | { result: string }
function agents(on: any, read: Record<string, Read[]>) {
  const w = { deny: false }
  on('fs.read', () => ({ value: RULES }))
  on('classic.SessionStart', () => ({}))
  on('session.messages', (_$: any, e: any) => {
    const texts = read[e.agentId ?? '']
    if (!texts) return { value: { deny: `no conversation of agent ${e.agentId} in this session` } }
    return { value: texts.map(t => ({ role: 'user', content: [typeof t === 'string' ? { type: 'text', text: t } : { type: 'tool_result', tool_use_id: 't', content: t.result }] })) }
  })
  on('tool.call', () => (w.deny ? { deny: 'not now' } : { result: 'ok' }))
  return w
}
const call = async ($: any, agentId?: string) => (await $.tool.call({ tool: 'Bash', command: 'ls', ...(agentId && { agentId }) })).context ?? []
const restored = (text: string) => ({ result: `ok\n\n<system-reminder>\ntool.call hook additional context: ${text}\n</system-reminder>` })

test('under the guard, a Workflow agent gets the escalation rule with its first tool result only', { plugins: [guard] }, async ($: any, on: any) => {
  const w = agents(on, { '': [RULES] })
  w.deny = true
  expect(await call($, 'w1')).toEqual([])
  w.deny = false
  expect(await Promise.all([call($, 'w1'), call($, 'w1')])).toEqual([[SUBAGENT_RULE], []])
  expect(await call($, 'w1')).toEqual([])
  expect(await call($, 'w2')).toEqual([SUBAGENT_RULE])
})

test('under the guard, an Agent subagent gets the escalation rule again only once its task is compacted away', { plugins: [guard] }, async ($: any, on: any) => {
  const read: Record<string, Read[]> = { '': [RULES], a1: [`${SUBAGENT_RULE}\n\nlook`] }
  agents(on, read)
  expect(await call($, 'a1')).toEqual([])
  read.a1 = ['a summary']
  expect(await call($, 'a1')).toEqual([SUBAGENT_RULE])
  expect(await call($, 'a1')).toEqual([])
  read.a1 = ['a summary', restored(SUBAGENT_RULE)]
  expect(await call($, 'a1')).toEqual([])
  read.a1 = ['another summary']
  expect(await call($, 'a1')).toEqual([SUBAGENT_RULE])
  // A second compaction before the model read the rule back.
  read.a1 = ['a third summary']
  expect(await call($, 'a1')).toEqual([SUBAGENT_RULE])
  expect(await call($, 'a1')).toEqual([])
})

test('under the guard, the rules are added to one tool result after a compaction, until the model reads them there', { plugins: [guard] }, async ($: any, on: any) => {
  const read: Record<string, Read[]> = { '': [`<system-reminder>\n${RULES}\n</system-reminder>`] }
  const w = agents(on, read)
  expect(await call($)).toEqual([])
  read[''] = ['a summary']
  w.deny = true
  expect(await call($)).toEqual([])
  w.deny = false
  expect(await Promise.all([call($), call($), call($)])).toEqual([[RULES], [], []])
  read[''] = ['a summary', restored(RULES)]
  expect(await call($)).toEqual([])
  read[''] = ['another summary']
  expect(await call($)).toEqual([RULES])
  // A second compaction before the model read them back.
  read[''] = ['a third summary']
  expect(await call($)).toEqual([RULES])
})

test('where the classic events run, nothing is added to a tool result', async ($: any, on: any) => {
  agents(on, { '': ['a summary'] })
  await $.classic.SessionStart({ source: 'startup' })
  expect(await call($)).toEqual([])
  expect(await call($, 'w1')).toEqual([])
})

test('a classic event after a late load ends the fallback', async ($: any, on: any) => {
  const w = world(on)
  await $.classic.SubagentStart({})
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe('look')
})

test('after a mid-session load, a subagent before the first prompt still leaves the rules to the fallback', async ($: any, on: any) => {
  world(on)
  await $.classic.SubagentStart({})
  expect((await $.prompt.submit({ text: 'hi' })).context).toEqual([RULES])
})
