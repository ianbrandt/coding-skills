// claude plugin test: the context added at a session's start, and the edit to a
// file in the primary checkout.
import { expect, test } from 'claude-code/testing'
import { splice } from './splice'

function world(on: any, entry?: string) {
  on('fs.read', (_$: any, e: any) => {
    const name = String(e.path).split(/[\\/]/).pop()
    return { value: name === 'rules.md' ? 'before\n{{title}}\n{{wrap-up}}after\n' : `<${name}>\n` }
  })
  on('env.get', () => ({ value: entry }))
  on('classic.SessionStart', () => ({ additionalContext: ['from a settings hook'] }))
}
const rules = (title: string, wrapUp = '') => ['from a settings hook', `before\n<${title}>\n${wrapUp}after\n`]

test('a session starts with rules.md, after the context of a settings hook', async ($: any, on: any) => {
  world(on)
  for (const source of ['startup', 'resume', 'clear', 'compact']) {
    expect((await $.classic.SessionStart({ source })).additionalContext).toEqual(rules('title-print.md'))
  }
})

test('the desktop app gets the title instruction for its tool and the rule for its wrap_up tool', async ($: any, on: any) => {
  world(on, 'claude-desktop')
  expect((await $.classic.SessionStart({ source: 'startup' })).additionalContext).toEqual(rules('title-desktop.md', '<wrap-up-desktop.md>\n\n'))
})

test('a terminal session gets the title instruction for the tool registered there', async ($: any, on: any) => {
  world(on, 'cli')
  expect((await $.classic.SessionStart({ source: 'startup' })).additionalContext).toEqual(rules('title-cli.md'))
})

test('any other entry point gets the printed title block', async ($: any, on: any) => {
  world(on, 'sdk-cli')
  expect((await $.classic.SessionStart({ source: 'startup' })).additionalContext).toEqual(rules('title-print.md'))
})

test('a fork gets nothing added', async ($: any, on: any) => {
  world(on)
  expect((await $.classic.SessionStart({ source: 'fork' })).additionalContext).toEqual(['from a settings hook'])
})

test('a passage is replaced where it occurs once, and a replacement with $& in it is literal', () => {
  expect(splice('a\nb\nc\n', 'b\n', '$&x\n')).toBe('a\n$&x\nc\n')
  expect(splice('a\n', '', 'b\n')).toBe('a\nb\n')
  expect(() => splice('a\nb\n', 'z', 'y')).toThrow('occurs 0 times')
  expect(() => splice('a\na\n', 'a', 'y')).toThrow('occurs 2 times')
})

test('in a file with CRLF line ends, a passage with LF line ends is matched and written with CRLF', () => {
  expect(splice('a\r\nb\r\nc\r\n', 'a\nb\n', 'x\ny\n')).toBe('x\r\ny\r\nc\r\n')
  expect(splice('a\r\nb\r\n', 'b', 'x\ny')).toBe('a\r\nx\r\ny\r\n')
  expect(splice('a\r\n', '', 'b\nc\r\n')).toBe('a\r\nb\r\nc\r\n')
  // A passage that is in the file as written is matched as written.
  expect(splice('a\nb\nc\r\n', 'a\nb\n', 'x\r\n')).toBe('x\r\nc\r\n')
  expect(splice('a\r\nb\r\n', 'a\r\n', 'x\n')).toBe('x\nb\r\n')
  expect(() => splice('a\r\nb\r\n', 'a\nz\n', 'y')).toThrow('occurs 0 times')
  expect(splice('a\r\nb\r\n', 'a\nb\n', '$&\n')).toBe('$&\r\n')
})

test('in a file with both line ends, the replacement is written as given unless the passage is matched with CRLF', () => {
  expect(splice('a\nb\r\nc\n', 'a', 'x\ny')).toBe('x\ny\nb\r\nc\n')
  expect(splice('a\nb\r\n', '', 'c\n')).toBe('a\nb\r\nc\n')
  expect(splice('a\nb\nc\r\na\r\nb\r\n', 'a\nb\n', 'x\ny\n')).toBe('x\ny\nc\r\na\r\nb\r\n')
  expect(splice('a\nb\r\nc\r\n', 'b\nc\n', 'x\ny\n')).toBe('a\nx\r\ny\r\n')
})

const EDIT = 'mcp__session-skills__edit_primary_file'
function repo(on: any, files: Record<string, string>, afterRead: (n: number) => void = () => {}, root = '/repo') {
  let reads = 0
  // On macOS a path with a drive letter is not absolute, so the engine puts the
  // session's directory in front of it, and that prefix is dropped too.
  const posix = (p: string) => p.replace(/\\/g, '/').replace(/^(.*\/)?[A-Za-z]:(?=\/)/, '')
  on('session.repo', () => ({ value: { root, remote: null, internal: false } }))
  on('fs.exists', (_$: any, e: any) => ({ value: posix(e.path) in files }))
  on('fs.read', (_$: any, e: any) => {
    const value = files[posix(e.path)]
    afterRead(++reads)
    return { value }
  })
  on('fs.write', (_$: any, e: any) => { files[posix(e.path)] = e.text; return { value: undefined } })
  return files
}

test('the tool edits a file in the primary checkout, and appends to one that is not there yet', async ($: any, on: any) => {
  const files = repo(on, { '/repo/ROADMAP.local.md': '## R1: one\n\n## R2: two\n' })
  expect((await $.tool.call({ tool: EDIT, path: '/repo/ROADMAP.local.md', old: '## R2: two\n', new: '## R3: three\n' })).result).toBe('edited /repo/ROADMAP.local.md')
  await $.tool.call({ tool: EDIT, path: '/repo/notes.local/log.md', old: '', new: 'first\n' })
  expect(files).toEqual({ '/repo/ROADMAP.local.md': '## R1: one\n\n## R3: three\n', '/repo/notes.local/log.md': 'first\n' })
})

test('the tool writes nothing for a drifted passage or a path outside the primary checkout', async ($: any, on: any) => {
  const files = repo(on, { '/repo/a.md': 'a\n', '/elsewhere/a.md': 'a\n' })
  for (const [path, why] of [['/repo/a.md', 'occurs 0 times'], ['/elsewhere/a.md', 'not inside the primary checkout'], ['/repo/../elsewhere/a.md', 'not inside the primary checkout'], ['/repository/a.md', 'not inside']]) {
    const ran = await $.tool.call({ tool: EDIT, path, old: 'z', new: 'y' })
    expect(ran.isError).toBe(true)
    expect(ran.text).toContain(why)
  }
  expect(files).toEqual({ '/repo/a.md': 'a\n', '/elsewhere/a.md': 'a\n' })
})

test('on Windows a path that differs from the primary checkout only in letter case is edited', async ($: any, on: any) => {
  const files = repo(on, { '/repo/a.md': 'a\n', '/repo-other/a.md': 'a\n' }, undefined, 'C:\\Repo')
  expect((await $.tool.call({ tool: EDIT, path: 'c:\\repo\\a.md', old: 'a\n', new: 'b\n' })).isError).toBeUndefined()
  expect(files['/repo/a.md']).toBe('b\n')
  for (const path of ['c:\\repo\\..\\a.md', 'c:\\repo-other\\a.md', 'C:/Repo/../repo-other/a.md', 'D:\\Repo\\a.md', '/repo/a.md']) {
    expect((await $.tool.call({ tool: EDIT, path, old: '', new: 'b\n' })).isError).toBe(true)
  }
  expect(files).toEqual({ '/repo/a.md': 'b\n', '/repo-other/a.md': 'a\n' })
})

test('without a drive letter, a path in another letter case is outside the primary checkout', async ($: any, on: any) => {
  const files = repo(on, { '/Repo/a.md': 'a\n' })
  expect((await $.tool.call({ tool: EDIT, path: '/Repo/a.md', old: 'a\n', new: 'b\n' })).text).toContain('not inside the primary checkout')
  expect(files).toEqual({ '/Repo/a.md': 'a\n' })
})

test('the tool writes nothing when the file changed after it was first read', async ($: any, on: any) => {
  const files = repo(on, { '/repo/a.md': 'a\n' }, n => { if (n === 1) files['/repo/a.md'] = 'a\nadded by a sibling\n' })
  const ran = await $.tool.call({ tool: EDIT, path: '/repo/a.md', old: 'a\n', new: 'b\n' })
  expect(ran.isError).toBe(true)
  expect(ran.text).toContain('changed')
  expect(files['/repo/a.md']).toBe('a\nadded by a sibling\n')
})

const TITLE = 'mcp__session-skills__set_session_title'
const prompt = ($: any, session_title?: string) => $.classic.UserPromptSubmit({ session_id: 's1', prompt: 'next', session_title })
function session(on: any, id: string) {
  on('session.id', () => ({ value: id }))
  on('classic.UserPromptSubmit', () => ({ additionalContext: ['from a settings hook'] }))
}

test('a title set with the tool is returned once, with the next prompt', async ($: any, on: any) => {
  session(on, 's1')
  expect((await prompt($)).sessionTitle).toBeUndefined()
  expect((await $.tool.call({ tool: TITLE, title: ' Parser cache ' })).result).toContain('next prompt')
  expect(await prompt($)).toEqual({ additionalContext: ['from a settings hook'], sessionTitle: 'Parser cache' })
  expect((await prompt($, 'Parser cache')).sessionTitle).toBeUndefined()
  // A second title replaces the first, which the session now has.
  await $.tool.call({ tool: TITLE, title: 'R12: parser cache' })
  expect((await prompt($, 'Parser cache')).sessionTitle).toBe('R12: parser cache')
})

test('a title is dropped when the user renamed the session after the last prompt', async ($: any, on: any) => {
  session(on, 's1')
  await prompt($, 'Typed by the user')
  await $.tool.call({ tool: TITLE, title: 'Parser cache' })
  expect((await prompt($, 'Typed again')).sessionTitle).toBeUndefined()
  expect((await prompt($, 'Typed again')).sessionTitle).toBeUndefined()
})

test('a title set in one session is not returned in another', async ($: any, on: any) => {
  session(on, 's2')
  await $.tool.call({ tool: TITLE, title: 'Parser cache' })
  expect((await prompt($)).sessionTitle).toBeUndefined()
})

test('an empty title is an error', async ($: any, on: any) => {
  session(on, 's1')
  expect((await $.tool.call({ tool: TITLE, title: '  ' })).isError).toBe(true)
  expect((await prompt($)).sessionTitle).toBeUndefined()
})

test('the title tool is registered in the terminal only', async ($: any, on: any) => {
  let entry: string | undefined
  let names: string[] = []
  on('env.get', () => ({ value: entry }))
  on('tool.register', (_$: any, e: any) => { names.push(e.name); return { value: undefined } })
  on('session.start', (_$: any, e: any) => e)
  for (const [from, listed] of [['cli', true], ['claude-desktop', false], ['sdk-cli', false], [undefined, false]] as const) {
    entry = from
    names = []
    await $.session.start({ cwd: '/repo' })
    expect(names).toContain('edit_primary_file')
    expect(names.includes('set_session_title')).toBe(listed)
  }
})

const ran = (command: string, session_id = 's1') => ({ session_id, tool_name: 'Bash', tool_input: { command }, tool_response: {}, tool_use_id: 't' })
const stop = ($: any, text: string, session_id = 's1') => $.classic.Stop({ session_id, last_assistant_message: text })
const BLOCK = 'Start it in `/repo`:\n\n```\n/next-roadmap-item R12\n```\n\n**Opus + High**'
function turnEnd(on: any, block?: string) {
  on('classic.PostToolUse', () => ({}))
  // The other hook blocks the first stop only.
  let blocks = block ? 1 : 0
  on('classic.Stop', () => (blocks-- > 0 ? { block } : {}))
  on('classic.UserPromptSubmit', () => ({}))
}

test('after a push, one stop is blocked when no next step is written at the end of the turn', async ($: any, on: any) => {
  turnEnd(on)
  await $.classic.PostToolUse(ran('git -C "/repo" push origin main'))
  expect((await stop($, 'I pushed 47e3656 to origin/main.')).block).toContain('next step')
  expect((await stop($, 'Nothing comes next: R96 waits on its post count.')).block).toBeUndefined()
  await $.classic.PostToolUse(ran('git fetch -q origin && git push'))
  expect((await stop($, `Pushed.\n\n${BLOCK}`)).block).toBeUndefined()
})

test('a turn that pushed nothing, or pushed in another session, is not blocked', async ($: any, on: any) => {
  turnEnd(on)
  await $.classic.PostToolUse(ran('git log --oneline origin/main..main && echo push'))
  expect((await stop($, 'One commit waits for the push.')).block).toBeUndefined()
  await $.classic.PostToolUse(ran('git push', 's2'))
  expect((await stop($, 'Done.')).block).toBeUndefined()
  expect((await stop($, 'Done.', 's2')).block).toBeDefined()
})

test('a push from an interrupted turn is dropped at the next prompt', async ($: any, on: any) => {
  turnEnd(on)
  await $.classic.PostToolUse(ran('git push'))
  await $.classic.UserPromptSubmit({ session_id: 's1', prompt: 'next' })
  expect((await stop($, 'Done.')).block).toBeUndefined()
})

test('a block from another hook is returned unchanged, and the check runs at the next stop', async ($: any, on: any) => {
  turnEnd(on, 'emit the corrected draft')
  await $.classic.PostToolUse(ran('git push'))
  expect((await stop($, 'Done.')).block).toBe('emit the corrected draft')
  expect((await stop($, 'Done.')).block).toContain('next step')
})

// Under managed settings cc-plugin-sec-default sends every classic.* event past
// user plugins, as this copy of its rule does. The rules then come with a
// prompt, once the model no longer reads them.
const guard = { name: 'guard', tier: 'prepend' as const, register(on: any) {
  on('classic.*', (_$: any, e: any, next: any) => next.to(e, 'append'))
} }
function prompts(on: any) {
  const w = { read: [] as string[] }
  on('session.messages', () => ({ value: w.read.map(text => ({ role: 'user', content: [{ type: 'text', text }] })) }))
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text, context: e.context }))
  return w
}
const submit = async ($: any) => (await $.prompt.submit({ text: 'hi' })).context ?? []

test('where the classic events run, nothing is added to a prompt', async ($: any, on: any) => {
  world(on)
  prompts(on)
  await $.classic.SessionStart({ source: 'startup' })
  expect(await submit($)).toEqual([])
})

test('under the guard, the rules are added to a prompt while the model does not read them', { plugins: [guard] }, async ($: any, on: any) => {
  world(on, 'claude-desktop')
  const w = prompts(on)
  expect((await $.classic.SessionStart({ source: 'startup' })).additionalContext).toEqual(['from a settings hook'])
  const rules = 'before\n<title-desktop.md>\n<wrap-up-desktop.md>\n\nafter\n'
  expect(await submit($)).toEqual([rules])
  w.read = [`<system-reminder>\n${rules}</system-reminder>`]
  expect(await submit($)).toEqual([])
  // The rules for another entry point are not the rules for this one.
  w.read = ['before\n<title-print.md>\nafter\n']
  expect(await submit($)).toEqual([rules])
})
