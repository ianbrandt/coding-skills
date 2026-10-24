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

test('a classic event after a late load ends the fallback', async ($: any, on: any) => {
  const w = world(on)
  await $.classic.SubagentStart({})
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe('look')
})
