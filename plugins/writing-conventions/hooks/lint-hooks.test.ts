// claude plugin test: the reply lint's hooks, the reminders, and the lint tool.
import { expect, test } from 'claude-code/testing'

// `sessionId` carries the id this test's $-dispatched calls see from
// `$.session.id()`, letting a test switch sessions by mutating `w.sessionId`.
function world(on: any, base = '2.1.289', env: Record<string, string> = {}) {
  const w = { sessionId: 's1', files: {} as Record<string, string> }
  on('session.version', () => ({ value: { version: base, base, builtAt: '' } }))
  on('session.id', () => ({ value: w.sessionId }))
  on('session.start', (_$: any, e: any) => e)
  on('prompt.submit', (_$: any, e: any) => ({ ...e, text: `from a settings hook\n\n${String(e.text ?? '')}` }))
  on('tool.call', () => ({ result: '' }))
  // On Windows an engine-level step turns a "/foo" path into "C:\foo" before the
  // mock sees it, so each lookup reads it back as POSIX.
  const posix = (p: string) => p.replace(/^[A-Za-z]:/, '').replace(/\\/g, '/')
  on('env.get', (_$: any, e: any) => ({ value: env[e.name as string] }))
  on('fs.read', (_$: any, e: any) => {
    const p = posix(e.path)
    if (p.endsWith('.md')) return { value: `<${p.split('/').pop()}>` }
    if (!(p in w.files)) throw new Error('ENOENT')
    return { value: w.files[p] }
  })
  on('fs.exists', (_$: any, e: any) => ({ value: posix(e.path) in w.files }))
  on('fs.write', (_$: any, e: any) => { w.files[posix(e.path)] = e.text; return { value: undefined } })
  on('ui.toast', () => ({ value: undefined }))
  on('classic.Stop', () => ({}))
  on('classic.SubagentStart', () => ({}))
  return w
}

const stop = ($: any, text: string, session_id = 's1') => $.classic.Stop({ session_id, last_assistant_message: text })
// What the plugin prepends to the first (or every) prompt, as the text before
// a `<user>` leaf. The returned string is empty when nothing was prepended.
const prompt = async (w: { sessionId: string }, $: any, session_id = 's1') => {
  w.sessionId = session_id
  const { text } = await $.prompt.submit({ text: '<user>' })
  const match = String(text).match(/^(.*)\n\n<user>$/s)
  if (!match) return ''
  return match[1]
}

test('the note on a reply opens the next turn, once, before the reminder', async ($: any, on: any) => {
  const w = world(on)
  expect((await stop($, 'The report says the build is load-bearing.')).block).toBeUndefined()
  expect(await prompt(w, $)).toMatch(/^from a settings hook\n\n<rules.md>\n\nA house-style lint flagged the previous reply:\n[\s\S]*banned word[\s\S]*\nStyle, for this reply/)
  expect(await prompt(w, $)).toMatch(/^from a settings hook\n\nStyle, for this reply/)
})

test('the note is cleared after a clean reply, and is kept per session', async ($: any, on: any) => {
  const w = world(on)
  await stop($, 'The build is load-bearing.')
  await stop($, 'The build passed.')
  expect(await prompt(w, $)).toMatch(/\nStyle/)
  await stop($, 'The build is load-bearing.', 's2')
  expect(await prompt(w, $, 's1')).toMatch(/\nStyle/)
  expect(await prompt(w, $, 's2')).toMatch(/\nA house-style lint/)
})

test('the text in a draft fence is linted as prose', async ($: any, on: any) => {
  const w = world(on)
  const F = '```'
  await stop($, `Here it is.\n${F}draft\nThe build is load-bearing.\n${F}\n`)
  expect(await prompt(w, $)).toContain('banned word')
  await stop($, `Here it is.\n${F}sh\necho load-bearing\n${F}\n`)
  expect(await prompt(w, $)).toMatch(/\nStyle/)
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

// The rules go in on the first prompt now, on every CLI the module runs on.
test('a session starts with the rules, on an older CLI too', async ($: any, on: any) => {
  const w = world(on, '2.1.200')
  expect(await prompt(w, $)).toBe('from a settings hook\n\n<rules.md>')
})

test('a subagent starts with the rules', async ($: any, on: any) => {
  world(on)
  expect((await $.classic.SubagentStart({ agent_id: 'a1', agent_type: 'Explore' })).additionalContext).toEqual(['<rules.md>'])
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
  const w = world(on, '2.1.289', { TEMP: '/win/Temp' })
  await stop($, 'The build is load-bearing.')
  expect(Object.keys(w.files)).toEqual(['/win/Temp/claude-reply-lint-s1.txt'])
})

test('with no session id nothing is saved', async ($: any, on: any) => {
  const w = world(on)
  await stop($, 'The build is load-bearing.', '')
  // The first prompt sees the rules too; the lint note is what matters here.
  expect(await prompt(w, $, '')).toMatch(/\nStyle/)
})

// On an older CLI the lint note isn't recorded or added, but the rules still
// go in on the first prompt.
test('on an older CLI no lint note is recorded or added', async ($: any, on: any) => {
  const w = world(on, '2.1.200')
  await stop($, 'The build is load-bearing.')
  expect(Object.keys(w.files)).toEqual([])
  // First prompt gets the rules.
  expect(await prompt(w, $)).toBe('from a settings hook\n\n<rules.md>')
  // Second prompt gets no prepends, so only the settings-hook stays.
  expect(await prompt(w, $)).toBe('from a settings hook')
  expect((await $.classic.SubagentStart({ agent_id: 'a1', agent_type: 'Explore' })).additionalContext).toBeUndefined()
})
