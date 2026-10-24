// claude plugin test: the context added at a session's start, and the edit to a
// file in the primary checkout.
import { expect, test } from 'claude-code/testing'
import { splice } from './splice'

function world(on: any, entry?: string, id = 's1') {
  on('fs.read', (_$: any, e: any) => {
    const name = String(e.path).split(/[\\/]/).pop()
    return { value: name === 'rules.md' ? 'before\n{{title}}\n{{wrap-up}}after\n' : `<${name}>\n` }
  })
  on('env.get', () => ({ value: entry }))
  on('tool.register', () => ({ value: undefined }))
  on('session.id', () => ({ value: id }))
  on('session.start', (_$: any, e: any) => e)
  on('prompt.submit', (_$: any, e: any) => ({ ...e, text: `from a settings hook\n\n${String(e.text ?? '')}` }))
}
// The rules the plugin prepends to the first prompt of a non-fork session,
// returned as a pair with the settings-hook prefix, split off from the user's
// text. The rules.md fixture ends with a newline, so there is one blank line
// between it and `<user>`.
const start = async ($: any, source = 'startup') => {
  await $.session.start({ cwd: '/repo', source })
  const { text } = await $.prompt.submit({ text: '<user>' })
  const m = String(text).match(/^from a settings hook\n\n(?:(.*)\n\n\n)?<user>$/s)
  if (!m) throw new Error(`unrecognised prompt text: ${JSON.stringify(text)}`)
  return m[1] === undefined ? ['from a settings hook'] : ['from a settings hook', m[1] + '\n']
}
const rules = (title: string, wrapUp = '') => ['from a settings hook', `before\n<${title}>\n${wrapUp}after\n`]

test('the first prompt of a session opens with rules.md, after a settings hook', async ($: any, on: any) => {
  world(on)
  for (const source of ['startup', 'resume', 'clear', 'compact']) {
    expect(await start($, source)).toEqual(rules('title-print.md'))
  }
})

test('the desktop app gets the title instruction for its tool and the rule for its wrap_up tool', async ($: any, on: any) => {
  world(on, 'claude-desktop')
  expect(await start($)).toEqual(rules('title-desktop.md', '<wrap-up-desktop.md>\n\n'))
})

test('a terminal session gets the title instruction for the tool registered there', async ($: any, on: any) => {
  world(on, 'cli')
  expect(await start($)).toEqual(rules('title-cli.md'))
})

test('any other entry point gets the printed title block', async ($: any, on: any) => {
  world(on, 'sdk-cli')
  expect(await start($)).toEqual(rules('title-print.md'))
})

test('a fork gets nothing added', async ($: any, on: any) => {
  world(on)
  expect(await start($, 'fork')).toEqual(['from a settings hook'])
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
function session(on: any, id: string) {
  on('session.id', () => ({ value: id }))
}

// ponytail: the title's rename on the next prompt is dropped under the native
// `prompt.submit` event, which returns only `{ text }` or `{ drop }`. The tool
// still records the title, so the previous tests of the one-shot application
// and the /rename interaction are gone with it.
test('a title set with the tool reports back the title it will apply', async ($: any, on: any) => {
  session(on, 's1')
  const ran = await $.tool.call({ tool: TITLE, title: ' Parser cache ' })
  expect(ran.result).toContain('"Parser cache"')
  expect(ran.result).toContain('next prompt')
})

test('an empty title is an error', async ($: any, on: any) => {
  session(on, 's1')
  expect((await $.tool.call({ tool: TITLE, title: '  ' })).isError).toBe(true)
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

// `tool.call` for Bash reaches the session-skills push-detector by its id,
// not by any input shape, so session_id comes from `on('session.id', ...)`.
const bash = ($: any, command: string) => $.tool.call({ tool: 'Bash', command, tool_use_id: 't' })
const stop = ($: any, text: string, session_id = 's1') => $.classic.Stop({ session_id, last_assistant_message: text })
const BLOCK = 'Start it in `/repo`:\n\n```\n/next-roadmap-item R12\n```\n\n**Opus + High**'
function turnEnd(on: any, block?: string, id = 's1') {
  on('session.id', () => ({ value: id }))
  on('tool.call', () => ({ result: '' }))
  // The other hook blocks the first stop only.
  let blocks = block ? 1 : 0
  on('classic.Stop', () => (blocks-- > 0 ? { block } : {}))
}

test('after a push, one stop is blocked when no next step is written at the end of the turn', async ($: any, on: any) => {
  turnEnd(on)
  await bash($, 'git -C "/repo" push origin main')
  expect((await stop($, 'I pushed 47e3656 to origin/main.')).block).toContain('next step')
  expect((await stop($, 'Nothing comes next: R96 waits on its post count.')).block).toBeUndefined()
  await bash($, 'git fetch -q origin && git push')
  expect((await stop($, `Pushed.\n\n${BLOCK}`)).block).toBeUndefined()
})

test('a turn that pushed nothing is not blocked', async ($: any, on: any) => {
  turnEnd(on)
  await bash($, 'git log --oneline origin/main..main && echo push')
  expect((await stop($, 'One commit waits for the push.')).block).toBeUndefined()
})

// `tool.call` reads the session.id of its own call, so a Bash hook fired in a
// different test world keeps its own session. The classic.Stop that follows
// here runs in the same world, and the stop for a different session_id does
// not clear the push flag.
test("a push in one session is not blocked by another session's stop", async ($: any, on: any) => {
  turnEnd(on, undefined, 's2')
  await bash($, 'git push')
  expect((await stop($, 'Done.', 's1')).block).toBeUndefined()
  expect((await stop($, 'Done.', 's2')).block).toBeDefined()
})

test('a block from another hook is returned unchanged, and the check runs at the next stop', async ($: any, on: any) => {
  turnEnd(on, 'emit the corrected draft')
  await bash($, 'git push')
  expect((await stop($, 'Done.')).block).toBe('emit the corrected draft')
  expect((await stop($, 'Done.')).block).toContain('next step')
})
