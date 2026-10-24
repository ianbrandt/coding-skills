// claude plugin test: the context added to a prompt and to a subagent's task.
import { expect, test } from 'claude-code/testing'
import { SUBAGENT_RULE } from './register'

const read = (text: string) => [{ role: 'user', content: [{ type: 'text', text }] }]

function world(on: any, messages: any[] = []) {
  on('fs.read', () => ({ value: 'ORCHESTRATION MODE ACTIVE\n\nthe rules' }))
  on('session.messages', () => ({ value: messages }))
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text, context: e.context }))
}

test('the rules are added as context once the model no longer reads them', async ($: any, on: any) => {
  world(on, read('hi'))
  expect((await $.prompt.submit({ text: 'hi' })).context).toEqual(['ORCHESTRATION MODE ACTIVE\n\nthe rules'])
})

test('nothing is added while the model still reads the rules', async ($: any, on: any) => {
  world(on, read('ORCHESTRATION MODE ACTIVE\n\nthe rules'))
  const ran = await $.prompt.submit({ text: 'again' })
  expect(ran.context ?? []).toEqual([])
  expect(ran.text).toBe('again')
})

test("a subagent's task opens with the escalation rule only", async ($: any, on: any) => {
  let task = ''
  on('tool.call', (_$: any, e: any) => { task = e.prompt; return { result: 'done' } })
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(task).toBe(`${SUBAGENT_RULE}\n\nlook`)
})
