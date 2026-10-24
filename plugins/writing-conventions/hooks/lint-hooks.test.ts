// claude plugin test: the reply lint's hooks, the reminders, and the lint tool.
import { expect, test } from 'claude-code/testing'

// The session a prompt is sent in, and the text the model still reads.
const session = { id: 's1', read: [] as string[] }

function world(on: any, base = '2.1.289', env: Record<string, string> = {}) {
  session.id = 's1'
  session.read = []
  on('session.version', () => ({ value: { version: base, base, builtAt: '' } }))
  on('session.id', () => ({ value: session.id }))
  on('session.messages', () => ({ value: session.read.map(text => ({ role: 'user', content: [{ type: 'text', text }] })) }))
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text, context: e.context }))
  const files: Record<string, string> = {}
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
  on('classic.SubagentStart', () => ({}))
  on('classic.SessionStart', () => ({}))
  return files
}

const stop = ($: any, text: string, session_id = 's1') => $.classic.Stop({ session_id, last_assistant_message: text })
// What is added to a prompt, past the rules, which a session that started
// under the classic events already has.
const prompt = async ($: any, id = 's1') => {
  session.id = id
  return ((await $.prompt.submit({ text: 'next' })).context ?? []).filter((c: string) => c !== '<rules.md>')
}

test('the note on a reply opens the next turn, once, before the reminder', async ($: any, on: any) => {
  world(on)
  expect((await stop($, 'The report says the build is load-bearing.')).block).toBeUndefined()
  const first = await prompt($)
  expect(first).toHaveLength(1)
  expect(first[0]).toMatch(/^A house-style lint flagged the previous reply:\n[\s\S]*banned word[\s\S]*\nStyle, for this reply/)
  expect(await prompt($)).toEqual([expect.stringMatching(/^Style, for this reply/)])
})

test('the note is cleared after a clean reply, and is kept per session', async ($: any, on: any) => {
  world(on)
  await stop($, 'The build is load-bearing.')
  await stop($, 'The build passed.')
  expect((await prompt($))[0]).toMatch(/^Style/)
  await stop($, 'The build is load-bearing.', 's2')
  expect((await prompt($, 's1'))[0]).toMatch(/^Style/)
  expect((await prompt($, 's2'))[0]).toMatch(/^A house-style lint/)
})

test('the text in a draft fence is linted as prose', async ($: any, on: any) => {
  world(on)
  const F = '```'
  await stop($, `Here it is.\n${F}draft\nThe build is load-bearing.\n${F}\n`)
  expect((await prompt($))[0]).toContain('banned word')
  await stop($, `Here it is.\n${F}sh\necho load-bearing\n${F}\n`)
  expect((await prompt($))[0]).toMatch(/^Style/)
})

test('the re-read request is added for a prose or source file just written, in any letter case', async ($: any, on: any) => {
  world(on)
  native(on)
  const wrote = async (tool: string, file_path: string) =>
    (await $.tool.call({ tool, file_path, content: '', old_string: 'x', new_string: 'y', tool_use_id: 't' })).context ?? []
  for (const p of ['/p/a.md', '/p/README.MD', '/p/A.kt', '/p/b.txt']) expect((await wrote('Write', p)).join()).toContain('You just wrote prose')
  expect((await wrote('Edit', '/p/a.md')).join()).toContain('You just wrote prose')
  expect(await wrote('Write', '/p/a.py')).toEqual([])
  expect(await wrote('Read', '/p/a.md')).toEqual([])
})

test('a session starts with the rules, on an older CLI too', async ($: any, on: any) => {
  world(on, '2.1.200')
  expect((await $.classic.SessionStart({ source: 'fork' })).additionalContext).toEqual(['<rules.md>'])
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
  const files = world(on, '2.1.289', { TEMP: '/win/Temp' })
  await stop($, 'The build is load-bearing.')
  expect(Object.keys(files)).toEqual(['/win/Temp/claude-reply-lint-s1.txt'])
})

test('with no session id nothing is saved', async ($: any, on: any) => {
  world(on)
  await stop($, 'The build is load-bearing.', '')
  expect((await prompt($, ''))[0]).toMatch(/^Style/)
})

test('on an older CLI no note, reminder, or subagent rules are recorded or added', async ($: any, on: any) => {
  const files = world(on, '2.1.200')
  await stop($, 'The build is load-bearing.')
  expect(Object.keys(files)).toEqual([])
  expect(await prompt($)).toEqual([])
  expect((await $.classic.SubagentStart({ agent_id: 'a1', agent_type: 'Explore' })).additionalContext).toBeUndefined()
})

// Under managed settings cc-plugin-sec-default sends every classic.* event past
// user plugins, as this copy of its rule does. The native events stand in.
const guard = { name: 'guard', tier: 'prepend' as const, register(on: any) {
  on('classic.*', (_$: any, e: any, next: any) => next.to(e, 'append'))
} }
// `task` is the last subagent task.
function native(on: any) {
  const w = { task: '' }
  on('tool.call', (_$: any, e: any) => {
    w.task = e.prompt
    return {
      result: e.tool === 'Write' ? { type: 'create', filePath: e.file_path, content: e.content }
        : e.tool === 'Edit' ? { filePath: e.file_path, oldString: e.old_string, newString: e.new_string }
        : '',
    }
  })
  return w
}
const submit = async ($: any) => (await $.prompt.submit({ text: 'next' })).context ?? []

test('where the classic events run, the rules are not added to a prompt or an Agent task, and a Write is checked', async ($: any, on: any) => {
  world(on)
  const w = native(on)
  await $.classic.SessionStart({ source: 'startup' })
  expect(await submit($)).toEqual([expect.stringMatching(/^Style, for this reply/)])
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe('look')
  expect((await $.tool.call({ tool: 'Write', file_path: '/p/a.md', content: '', tool_use_id: 't' })).context.join()).toContain('You just wrote prose')
})

test('under the guard, the rules are added to a prompt while the model does not read them, then the note and the reminder', { plugins: [guard] }, async ($: any, on: any) => {
  world(on)
  native(on)
  expect((await $.classic.SessionStart({ source: 'startup' })).additionalContext).toBeUndefined()
  const [rules, reminder] = await submit($)
  expect(rules).toBe('<rules.md>')
  expect(reminder).toMatch(/^Style, for this reply/)
  session.read = ['<system-reminder>\n<rules.md>\n</system-reminder>']
  expect((await submit($))[0]).toMatch(/^Style/)
})

test('under the guard, the rules are added at the start of an Agent task, and the re-read request to a Write result', { plugins: [guard] }, async ($: any, on: any) => {
  world(on)
  const w = native(on)
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe('<rules.md>\n\nlook')
  expect((await $.tool.call({ tool: 'Write', file_path: '/p/a.md', content: '', tool_use_id: 't' })).context.join()).toContain('You just wrote prose')
})

test('a classic event after a late load ends the fallback', async ($: any, on: any) => {
  world(on)
  const w = native(on)
  await $.classic.SubagentStart({ agent_id: 'a1', agent_type: 'Explore' })
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe('look')
})

test('a classic.Stop after a late load ends the Agent fallback', async ($: any, on: any) => {
  world(on)
  const w = native(on)
  await stop($, 'The build passed.')
  await $.tool.call({ tool: 'Agent', prompt: 'look', description: 'd' })
  expect(w.task).toBe('look')
})

test('after a mid-session load, a classic event before the first prompt still leaves the rules to the fallback', async ($: any, on: any) => {
  world(on)
  native(on)
  await stop($, 'The build passed.')
  expect((await submit($))[0]).toBe('<rules.md>')
})
