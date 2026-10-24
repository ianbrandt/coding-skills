// claude plugin test: the reply lint's hooks, the reminders, and the lint tool.
import { expect, test } from 'claude-code/testing'

// `read` is the text the model still reads, the rules by default, and `task` is
// the last subagent task that reached the Agent tool.
function world(on: any, base = '2.1.289', env: Record<string, string> = {}) {
  on('session.version', () => ({ value: { version: base, base, builtAt: '' } }))
  const w = { files: {} as Record<string, string>, session: 's1', read: ['<rules.md>'], task: '' }
  const { files } = w
  on('session.id', () => ({ value: w.session }))
  on('session.messages', () => ({ value: w.read.map(text => ({ role: 'user', content: [{ type: 'text', text }] })) }))
  // On Windows an engine-level step turns a "/foo" path into "C:\foo" before the
  // mock sees it, so each lookup reads it back as POSIX.
  const posix = (p: string) => p.replace(/^[A-Za-z]:/, '').replace(/\\/g, '/')
  on('env.get', (_$: any, e: any) => ({ value: env[e.name as string] }))
  on('fs.read', (_$: any, e: any) => {
    const p = posix(e.path)
    if (p.endsWith('.md')) return { value: `<${p.split('/').pop()}>` }
    if (!(p in files)) throw new Error('ENOENT')
    return { value: files[p] }
  })
  on('fs.exists', (_$: any, e: any) => ({ value: posix(e.path) in files }))
  on('fs.write', (_$: any, e: any) => { files[posix(e.path)] = e.text; return { value: undefined } })
  on('ui.toast', () => ({ value: undefined }))
  on('classic.Stop', () => ({}))
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text, context: ['from a settings hook', ...(e.context ?? [])] }))
  on('tool.call', (_$: any, e: any) => { w.task = e.prompt; return { result: '' } })
  return w
}

const stop = ($: any, text: string, session_id = 's1') => $.classic.Stop({ session_id, last_assistant_message: text })
const prompt = async ($: any, w: { session: string }, session = 's1') => {
  w.session = session
  return (await $.prompt.submit({ text: 'next' })).context
}

test('the note on a reply opens the next turn, once, before the reminder', async ($: any, on: any) => {
  const w = world(on)
  expect((await stop($, 'The report says the build is load-bearing.')).block).toBeUndefined()
  const first = await prompt($, w)
  expect(first[0]).toBe('from a settings hook')
  expect(first[1]).toMatch(/^A house-style lint flagged the previous reply:\n[\s\S]*banned word[\s\S]*\nStyle, for this reply/)
  expect((await prompt($, w))[1]).toMatch(/^Style, for this reply/)
})

test('the note is cleared after a clean reply, and is kept per session', async ($: any, on: any) => {
  const w = world(on)
  await stop($, 'The build is load-bearing.')
  await stop($, 'The build passed.')
  expect((await prompt($, w))[1]).toMatch(/^Style/)
  await stop($, 'The build is load-bearing.', 's2')
  expect((await prompt($, w, 's1'))[1]).toMatch(/^Style/)
  expect((await prompt($, w, 's2'))[1]).toMatch(/^A house-style lint/)
})

test('the text in a draft fence is linted as prose', async ($: any, on: any) => {
  const w = world(on)
  const F = '```'
  await stop($, `Here it is.\n${F}draft\nThe build is load-bearing.\n${F}\n`)
  expect((await prompt($, w))[1]).toContain('banned word')
  await stop($, `Here it is.\n${F}sh\necho load-bearing\n${F}\n`)
  expect((await prompt($, w))[1]).toMatch(/^Style/)
})

test('the re-read request is added for a prose or source file just written, in any letter case', async ($: any, on: any) => {
  world(on)
  const wrote = async (tool: string, file_path: string) =>
    (await $.tool.call({ tool, file_path, content: '', tool_use_id: 't' })).context ?? []
  for (const p of ['/p/a.md', '/p/README.MD', '/p/A.kt', '/p/b.txt']) expect((await wrote('Write', p)).join()).toContain('You just wrote prose')
  expect((await wrote('Edit', '/p/a.md')).join()).toContain('You just wrote prose')
  expect(await wrote('Write', '/p/a.py')).toEqual([])
  expect(await wrote('Read', '/p/a.md')).toEqual([])
})

test('the rules are added once the model no longer reads them, on an older CLI too', async ($: any, on: any) => {
  const w = world(on, '2.1.200')
  w.read = []
  expect(await prompt($, w)).toEqual(['from a settings hook', '<rules.md>'])
})

test('a subagent starts with the rules', async ($: any, on: any) => {
  const w = world(on)
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe('<rules.md>\n\nlook')
})

test('the lint tool returns the flagged lines, or clean', async ($: any, on: any) => {
  world(on)
  expect((await $.tool.call({ tool: 'mcp__writing-conventions__lint', text: 'The build is load-bearing.' })).result).toBe('banned word\tload-bearing')
  expect((await $.tool.call({ tool: 'mcp__writing-conventions__lint', text: 'The build passed.' })).result).toBe('clean')
})

test('the lint tool reads a draft passed inside its fence', async ($: any, on: any) => {
  world(on)
  const F = '```'
  expect((await $.tool.call({ tool: 'mcp__writing-conventions__lint', text: `${F}draft\nThe build is load-bearing.\n${F}\n` })).result).toBe('banned word\tload-bearing')
})

test('the note is kept in TEMP where there is no TMPDIR', async ($: any, on: any) => {
  const { files } = world(on, '2.1.289', { TEMP: '/win/Temp' })
  await stop($, 'The build is load-bearing.')
  expect(Object.keys(files)).toEqual(['/win/Temp/claude-reply-lint-s1.txt'])
})

test('with no session id nothing is saved', async ($: any, on: any) => {
  const w = world(on)
  await stop($, 'The build is load-bearing.', '')
  expect((await prompt($, w, ''))[1]).toMatch(/^Style/)
})

test('on an older CLI nothing is recorded or added', async ($: any, on: any) => {
  const w = world(on, '2.1.200')
  await stop($, 'The build is load-bearing.')
  expect(Object.keys(w.files)).toEqual([])
  expect(await prompt($, w)).toEqual(['from a settings hook'])
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe('look')
})
