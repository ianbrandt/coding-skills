// claude plugin test: the context added at a session's start.
import { expect, test } from 'claude-code/testing'

function world(on: any) {
  on('fs.read', (_$: any, e: any) => ({ value: `<${String(e.path).split(/[\\/]/).pop()}>` }))
  on('classic.SessionStart', () => ({ additionalContext: ['from a settings hook'] }))
}

test('a session starts with rules.md, after the context of a settings hook', async ($: any, on: any) => {
  world(on)
  for (const source of ['startup', 'resume', 'clear', 'compact']) {
    expect((await $.classic.SessionStart({ source })).additionalContext).toEqual(['from a settings hook', '<rules.md>'])
  }
})

test('a fork gets nothing added', async ($: any, on: any) => {
  world(on)
  expect((await $.classic.SessionStart({ source: 'fork' })).additionalContext).toEqual(['from a settings hook'])
})
