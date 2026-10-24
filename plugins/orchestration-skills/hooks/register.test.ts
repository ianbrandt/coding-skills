// claude plugin test: the context added at a session's start and a subagent's.
import { expect, test } from 'claude-code/testing'
import { SUBAGENT_RULE } from './register'

test('the first prompt of a session opens with the rules prepended to the text', async ($: any, on: any) => {
  on('fs.read', (_$: any, e: any) => ({ value: `<${String(e.path).split(/[\\/]/).pop()}>` }))
  on('session.start', (_$: any, e: any) => e)
  on('prompt.submit', (_$: any, e: any) => e)
  await $.session.start({ cwd: '/repo', source: 'compact' })
  const first = await $.prompt.submit({ text: 'hi' })
  expect(first.text).toBe('<rules.md>\n\nhi')
  // The second prompt sees nothing added.
  const second = await $.prompt.submit({ text: 'again' })
  expect(second.text).toBe('again')
})

test('a fork starts with its parent context, where the rules already are', async ($: any, on: any) => {
  on('fs.read', (_$: any, e: any) => ({ value: `<${String(e.path).split(/[\\/]/).pop()}>` }))
  on('session.start', (_$: any, e: any) => e)
  on('prompt.submit', (_$: any, e: any) => e)
  await $.session.start({ cwd: '/repo', source: 'fork' })
  const first = await $.prompt.submit({ text: 'hi' })
  expect(first.text).toBe('hi')
})

test('a subagent starts with the escalation rule only', async ($: any, on: any) => {
  on('classic.SubagentStart', () => ({}))
  expect((await $.classic.SubagentStart({})).additionalContext).toEqual([SUBAGENT_RULE])
})
