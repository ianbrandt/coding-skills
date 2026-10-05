// claude plugin test: the reply lint's hooks, the reminders, and the lint tool.
import { expect, test } from 'claude-code/testing'

function world(on: any, base = '2.1.289') {
  on('session.version', () => ({ value: { version: base, base, builtAt: '' } }))
  const files: Record<string, string> = {}
  on('env.get', () => ({ value: undefined }))
  on('fs.read', (_$: any, e: any) => {
    if (e.path.endsWith('.md')) return { value: `<${e.path.split('/').pop()}>` }
    if (!(e.path in files)) throw new Error('ENOENT')
    return { value: files[e.path] }
  })
  on('fs.exists', (_$: any, e: any) => ({ value: e.path in files }))
  on('fs.write', (_$: any, e: any) => { files[e.path] = e.text; return { value: undefined } })
  on('ui.toast', () => ({ value: undefined }))
  on('classic.Stop', () => ({}))
  on('classic.UserPromptSubmit', () => ({ additionalContext: ['from a settings hook'] }))
  on('classic.PostToolUse', () => ({}))
  on('classic.SubagentStart', () => ({}))
  return files
}

const stop = ($: any, text: string, session_id = 's1') => $.classic.Stop({ session_id, last_assistant_message: text })
const prompt = async ($: any, session_id = 's1') => (await $.classic.UserPromptSubmit({ session_id, prompt: 'next' })).additionalContext

test('the note on a reply opens the next turn, once, before the reminder', async ($: any, on: any) => {
  world(on)
  expect((await stop($, 'The report says the build is load-bearing.')).block).toBeUndefined()
  const first = await prompt($)
  expect(first[0]).toBe('from a settings hook')
  expect(first[1]).toMatch(/^A house-style lint flagged the previous reply:\n[\s\S]*banned word[\s\S]*\nStyle, for this reply/)
  expect((await prompt($))[1]).toMatch(/^Style, for this reply/)
})

test('a clean reply clears the note, and a note stays with its session', async ($: any, on: any) => {
  world(on)
  await stop($, 'The build is load-bearing.')
  await stop($, 'The build passed.')
  expect((await prompt($))[1]).toMatch(/^Style/)
  await stop($, 'The build is load-bearing.', 's2')
  expect((await prompt($, 's1'))[1]).toMatch(/^Style/)
  expect((await prompt($, 's2'))[1]).toMatch(/^A house-style lint/)
})

test('a draft is linted as the prose it is', async ($: any, on: any) => {
  world(on)
  const F = '```'
  await stop($, `Here it is.\n${F}draft\nThe build is load-bearing.\n${F}\n`)
  expect((await prompt($))[1]).toContain('banned word')
  await stop($, `Here it is.\n${F}sh\necho load-bearing\n${F}\n`)
  expect((await prompt($))[1]).toMatch(/^Style/)
})

test('a prose or source file just written gets the nudge, in any letter case', async ($: any, on: any) => {
  world(on)
  const wrote = async (tool_name: string, file_path: string) =>
    (await $.classic.PostToolUse({ tool_name, tool_input: { file_path, content: '' }, tool_response: {}, tool_use_id: 't' })).additionalContext ?? []
  for (const p of ['/p/a.md', '/p/README.MD', '/p/A.kt', '/p/b.txt']) expect((await wrote('Write', p)).join()).toContain('You just wrote prose')
  expect((await wrote('Edit', '/p/a.md')).join()).toContain('You just wrote prose')
  expect(await wrote('Write', '/p/a.py')).toEqual([])
  expect(await wrote('Read', '/p/a.md')).toEqual([])
})

test('a subagent starts with the rules', async ($: any, on: any) => {
  world(on)
  expect((await $.classic.SubagentStart({ agent_id: 'a1', agent_type: 'Explore' })).additionalContext).toEqual(['<rules.md>'])
})

test('the lint tool answers with the flagged lines, or clean', async ($: any, on: any) => {
  world(on)
  expect((await $.tool.call({ tool: 'mcp__writing-conventions__lint', text: 'The build is load-bearing.' })).result).toBe('banned word\tload-bearing')
  expect((await $.tool.call({ tool: 'mcp__writing-conventions__lint', text: 'The build passed.' })).result).toBe('clean')
})

test('the lint tool reads a draft passed inside its fence', async ($: any, on: any) => {
  world(on)
  const F = '```'
  expect((await $.tool.call({ tool: 'mcp__writing-conventions__lint', text: `${F}draft\nThe build is load-bearing.\n${F}\n` })).result).toBe('banned word\tload-bearing')
})

test('with no session id nothing is saved', async ($: any, on: any) => {
  world(on)
  await stop($, 'The build is load-bearing.', '')
  expect((await prompt($, ''))[1]).toMatch(/^Style/)
})

test('on an older CLI nothing is recorded or added', async ($: any, on: any) => {
  const files = world(on, '2.1.200')
  await stop($, 'The build is load-bearing.')
  expect(Object.keys(files)).toEqual([])
  expect(await prompt($)).toEqual(['from a settings hook'])
  expect((await $.classic.SubagentStart({ agent_id: 'a1', agent_type: 'Explore' })).additionalContext).toBeUndefined()
})
