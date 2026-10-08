// claude plugin test: the claim ledger's rules, the three tools, and the release
// at session end. The costly errors are a sibling's live claim deleted, which
// ends its lane, and a claim left behind, which nothing expires.
import { expect, test } from 'claude-code/testing'
import { dead, fileOf, ownedBy, parse } from './ledger'

const claim = (branch: string, session = 'SIBLING', touches = ['src/**']) =>
  JSON.stringify({ item: 'x', branch, started: '2026-01-01T00:00:00Z', session, touches }) + '\n'
const entry = (name: string, text: string, mtimeMs = 0) => ({ name, text, mtimeMs })

test('a claim file is named for its branch', () => {
  expect(fileOf('claude/r1-teal-marten')).toBe('claude-r1-teal-marten.json')
})

test('a claim written by the earlier printf is still read', () => {
  expect(parse('{ "item": "a", "branch": "claude/a", "started": "s", "session": "S", "touches": ["a/**"] }\n')?.branch).toBe('claude/a')
  expect(parse('{ "item": "a" }')).toBeNull()
  expect(parse('{ "item": "a", "bran')).toBeNull()
})

test('a claim is dead when its branch is in no worktree, whatever its age', () => {
  const list = [entry('a.json', claim('claude/a')), entry('b.json', claim('claude/b'))]
  expect(dead(list, ['main', 'claude/a'], 10).map(e => e.name)).toEqual(['b.json'])
})

test('with a worktree detached, no claim that parses is dead', () => {
  const list = [entry('b.json', claim('claude/b')), entry('t.json', '{ "item": "a", "bran', 1_000)]
  expect(dead(list, ['main'], 62_000, true).map(e => e.name)).toEqual(['t.json'])
})

test('a file that does not parse is dead only after a minute', () => {
  const torn = [entry('t.json', '{ "item": "a", "bran', 1_000)]
  expect(dead(torn, [], 30_000)).toEqual([])
  expect(dead(torn, [], 62_000).map(e => e.name)).toEqual(['t.json'])
})

test('an empty session id matches no claim', () => {
  const list = [entry('a.json', claim('claude/a', '')), entry('b.json', claim('claude/b', 'MINE')), entry('c.json', '{ "branch": "claude/c" }')]
  expect(ownedBy(list, '')).toEqual([])
  expect(ownedBy(list, 'MINE').map(e => e.name)).toEqual(['b.json'])
})

// A primary checkout at /repo on main, worktrees by path and branch, and the
// ledger's files. `git clean` deletes from `files`, as git does on disk. The
// session's directory is a worktree that was removed, so git starts only when
// it is run in /repo.
function world(on: any, worktrees: Record<string, string>, files: Record<string, string>, session = 'MINE', other: Record<string, string> = {}) {
  const posix = (p: string) => p.replace(/^[A-Za-z]:/, '').replace(/\\/g, '/')
  const dir = '/repo/.claude/claims/'
  const w = { files, worktrees, now: 1_000_000, root: '/repo' as string | null, torn: null as { name: string; text: string } | null }
  on('session.repo', () => ({ value: w.root ? { root: w.root, remote: null, internal: false } : null }))
  on('session.id', () => ({ value: session }))
  on('clock.now', () => ({ value: w.now }))
  on('fs.list', (_$: any, e: any) => {
    if (posix(e.path) + '/' !== dir || Object.keys(w.files).length === 0) throw new Error('ENOENT')
    return { value: Object.keys(w.files).map(name => ({ name, kind: 'file', size: 1, mtimeMs: 0, isLink: false })) }
  })
  on('fs.read', (_$: any, e: any) => {
    const name = posix(e.path).slice(dir.length)
    // A claim being rewritten reads as torn text once.
    if (w.torn?.name === name) { const { text } = w.torn; w.torn = null; return { value: text } }
    return { value: w.files[name] }
  })
  on('fs.exists', (_$: any, e: any) => {
    const path = posix(e.path)
    return { value: path.startsWith(dir) ? path.slice(dir.length) in w.files : path === '/repo' || path in w.worktrees || path in other }
  })
  on('fs.write', (_$: any, e: any) => { w.files[posix(e.path).slice(dir.length)] = e.text; return { value: undefined } })
  on('process.run', (_$: any, e: any) => {
    if (e.init?.cwd !== '/repo') throw new Error("ENOENT: no such file or directory, posix_spawn 'git'")
    const [, , cwd, ...argv] = e.argv as string[]
    const out = (stdout: string, exitCode = 0) => ({ value: { exitCode, stdout, stderr: exitCode ? 'fatal' : '' } })
    const all = { '/repo': 'main', ...w.worktrees }
    if (argv[0] === 'rev-parse') return posix(cwd) in all || posix(cwd) in other ? out(posix(cwd) + '\n') : out('', 128)
    if (argv.join(' ') === 'worktree list --porcelain') {
      return out(Object.entries(all).map(([p, b]) => `worktree ${p}\nHEAD 0\n${b === 'HEAD' ? 'detached' : `branch refs/heads/${b}`}\n`).join('\n'))
    }
    if (argv[0] === 'clean') delete w.files[argv[argv.length - 1].replace(':(literal).claude/claims/', '')]
    return out('')
  })
  on('classic.SessionEnd', () => ({}))
  return w
}
const call = ($: any, name: string, input: object = {}) => $.tool.call({ tool: `mcp__parallel-session-skills__${name}`, ...input })

test('read_ledger deletes dead claims and returns the live ones', async ($: any, on: any) => {
  const w = world(on, { '/wt/a': 'claude/a' }, { 'claude-a.json': claim('claude/a'), 'claude-gone.json': claim('claude/gone') })
  expect((await call($, 'read_ledger')).result).toBe(`reaped dead claim: claude-gone.json\nledger: /repo/.claude/claims\n${claim('claude/a').trim()}`)
  expect(Object.keys(w.files)).toEqual(['claude-a.json'])
})

test('read_ledger reaps no claim while a linked worktree is detached, such as in a rebase', async ($: any, on: any) => {
  const w = world(on, { '/wt/a': 'HEAD' }, { 'claude-gone.json': claim('claude/gone') })
  const ran = await call($, 'read_ledger')
  expect(ran.result).toBe(`a worktree is detached, so no claim was reaped\nledger: /repo/.claude/claims\n${claim('claude/gone').trim()}`)
  expect(Object.keys(w.files)).toEqual(['claude-gone.json'])
  w.worktrees = { '/wt/a': 'claude/a' }
  expect((await call($, 'read_ledger')).result).toContain('reaped dead claim: claude-gone.json')
})

test('a claim that was torn when first read, and whole when read again, is kept', async ($: any, on: any) => {
  const w = world(on, { '/wt/a': 'claude/a' }, { 'claude-a.json': claim('claude/a') })
  w.torn = { name: 'claude-a.json', text: '{ "item": "a", "bran' }
  expect((await call($, 'read_ledger')).result).toBe(`ledger: /repo/.claude/claims\n${claim('claude/a').trim()}`)
  expect(Object.keys(w.files)).toEqual(['claude-a.json'])
})

test('a claim that is whole but for a branch in no worktree is still reaped after the second read', async ($: any, on: any) => {
  const w = world(on, { '/wt/a': 'claude/a' }, { 'claude-gone.json': claim('claude/gone') })
  w.torn = { name: 'claude-gone.json', text: '{ "item": "a", "bran' }
  expect((await call($, 'read_ledger')).result).toContain('reaped dead claim: claude-gone.json')
  expect(w.files).toEqual({})
})

test('read_ledger reports an empty or absent ledger with its path', async ($: any, on: any) => {
  world(on, {}, {})
  expect((await call($, 'read_ledger')).result).toBe('ledger: /repo/.claude/claims\nno claims')
})

test("write_claim files the claim under the worktree's branch with this session's id", async ($: any, on: any) => {
  const w = world(on, { '/wt/a': 'claude/a', '/wt/b': 'claude/b' }, { 'claude-b.json': claim('claude/b') })
  const ran = await call($, 'write_claim', { worktree: '/wt/a', item: 'parser core', touches: ['src/parser/**', 'docs/parsing.md'] })
  expect(JSON.parse(w.files['claude-a.json'])).toEqual({
    item: 'parser core', branch: 'claude/a', started: '1970-01-01T00:16:40Z', session: 'MINE', touches: ['src/parser/**', 'docs/parsing.md'],
  })
  expect(ran.result).toContain(claim('claude/b').trim())
  expect(ran.result).toContain('"branch":"claude/a"')
})

test('the primary checkout, a detached HEAD, and a path that is no worktree are refused', async ($: any, on: any) => {
  const w = world(on, { '/wt/d': 'HEAD' }, {})
  for (const [worktree, why] of [['/repo', 'is the primary checkout'], ['/wt/d', 'detached HEAD'], ['/nowhere', 'rev-parse']]) {
    // A path that does not exist is a worktree that was removed, and release_claim treats it as that.
    for (const name of worktree === '/nowhere' ? ['write_claim'] : ['write_claim', 'release_claim']) {
      const ran = await call($, name, { worktree, item: 'x', touches: [] })
      expect(ran.isError).toBe(true)
      expect(ran.text).toContain(why)
    }
  }
  expect(w.files).toEqual({})
})

test("a repo that is not this one's worktree is refused, even on a claimed branch name", async ($: any, on: any) => {
  const w = world(on, { '/wt/a': 'claude/a' }, { 'claude-a.json': claim('claude/a', 'SIBLING') }, 'MINE', { '/other': 'claude/a' })
  for (const name of ['write_claim', 'release_claim']) {
    const ran = await call($, name, { worktree: '/other', item: 'x', touches: [] })
    expect(ran.isError).toBe(true)
    expect(ran.text).toContain('is not a worktree of this repo')
  }
  expect(w.files).toEqual({ 'claude-a.json': claim('claude/a', 'SIBLING') })
})

test('with the primary checkout detached, the first linked worktree can claim and release', async ($: any, on: any) => {
  const w = world(on, { '/repo': 'HEAD', '/wt/a': 'claude/a' }, {})
  const refused = await call($, 'write_claim', { worktree: '/repo', item: 'x', touches: [] })
  expect(refused.text).toContain('is the primary checkout')
  expect((await call($, 'write_claim', { worktree: '/wt/a', item: 'x', touches: [] })).isError).toBeUndefined()
  expect(Object.keys(w.files)).toEqual(['claude-a.json'])
  expect((await call($, 'release_claim', { worktree: '/wt/a' })).result).toContain('released: claude-a.json')
  expect(w.files).toEqual({})
})

test("release_claim deletes the lane's claim and no other", async ($: any, on: any) => {
  const w = world(on, { '/wt/a': 'claude/a', '/wt/b': 'claude/b' }, { 'claude-a.json': claim('claude/a', 'MINE'), 'claude-b.json': claim('claude/b') })
  expect((await call($, 'release_claim', { worktree: '/wt/a' })).result).toBe(`released: claude-a.json\nledger: /repo/.claude/claims\n${claim('claude/b').trim()}`)
  expect(Object.keys(w.files)).toEqual(['claude-b.json'])
  const again = await call($, 'release_claim', { worktree: '/wt/a' })
  expect(again.isError).toBe(true)
  expect(again.text).toContain('no claim claude-a.json')
})

test("the end of a session deletes that session's claims and no other", async ($: any, on: any) => {
  const w = world(on, {}, {
    'a.json': claim('claude/a', 'MINE'), 'b.json': claim('claude/b', 'SIBLING'), 'c.json': '{ "item": "no session", "branch": "claude/c" }', 'd.json': claim('claude/d', ''),
  })
  await $.classic.SessionEnd({ reason: 'other', session_id: 'NOBODY' })
  await $.classic.SessionEnd({ reason: 'other', session_id: '' })
  expect(Object.keys(w.files)).toEqual(['a.json', 'b.json', 'c.json', 'd.json'])
  await $.classic.SessionEnd({ reason: 'other', session_id: 'MINE' })
  expect(Object.keys(w.files)).toEqual(['b.json', 'c.json', 'd.json'])
  w.root = null
  await $.classic.SessionEnd({ reason: 'other', session_id: 'SIBLING' })
  expect(Object.keys(w.files)).toEqual(['b.json', 'c.json', 'd.json'])
})

// A process is started in the session's directory unless another is given.
test("a claim is released after the lane's worktree is removed, by the tool and at session end", async ($: any, on: any) => {
  const w = world(on, {}, { 'claude-a.json': claim('claude/a', 'MINE'), 'claude-b.json': claim('claude/b', 'MINE') })
  const ran = await call($, 'release_claim', { worktree: '/wt/a' })
  expect(ran.result).toContain('released: claude-a.json, claude-b.json')
  expect(ran.result).toContain('/wt/a is gone')
  expect(w.files).toEqual({})
  w.files['claude-c.json'] = claim('claude/c', 'MINE')
  await $.classic.SessionEnd({ reason: 'other', session_id: 'MINE' })
  expect(w.files).toEqual({})
})

test("a removed worktree's release leaves another session's claim, and with none of this session's it is an error", async ($: any, on: any) => {
  const w = world(on, {}, { 'claude-a.json': claim('claude/a', 'SIBLING'), 'claude-b.json': claim('claude/b', 'MINE') })
  expect((await call($, 'release_claim', { worktree: '/wt/gone' })).result).toContain('released: claude-b.json')
  expect(Object.keys(w.files)).toEqual(['claude-a.json'])
  const again = await call($, 'release_claim', { worktree: '/wt/gone' })
  expect(again.isError).toBe(true)
  expect(again.text).toContain('no claim of this session')
  expect(Object.keys(w.files)).toEqual(['claude-a.json'])
})
