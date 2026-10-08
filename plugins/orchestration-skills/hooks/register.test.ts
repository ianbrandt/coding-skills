// claude plugin test: the context added at a session's start and a subagent's.
import { expect, test } from 'claude-code/testing'
import { SUBAGENT_RULE } from './register'

test('a session starts with rules.md, after the context of a settings hook', async ($: any, on: any) => {
  on('fs.read', (_$: any, e: any) => ({ value: `<${String(e.path).split(/[\\/]/).pop()}>` }))
  on('classic.SessionStart', () => ({ additionalContext: ['from a settings hook'] }))
  const ran = await $.classic.SessionStart({ source: 'compact' })
  expect(ran.additionalContext).toEqual(['from a settings hook', '<rules.md>'])
})

test('a subagent starts with the escalation rule only', async ($: any, on: any) => {
  on('classic.SubagentStart', () => ({}))
  expect((await $.classic.SubagentStart({})).additionalContext).toEqual([SUBAGENT_RULE])
})
