// claude plugin test: where a new branch starts, and the four tools against a
// faked git. The costly errors are a branch opened without commits held on the
// local default branch, and an unmerged branch deleted by the prune.
import { expect, test } from 'claude-code/testing'
import { pickBase, visibility, worktreeName } from './checkouts'

test('a new branch starts from origin, except where the local default branch has everything origin has', () => {
  expect(pickBase('main', false, true, false, false)).toEqual({ base: 'main' })
  expect(pickBase('main', true, false, false, false)).toEqual({ base: 'origin/main' })
  expect(pickBase('main', true, true, true, true)).toEqual({ base: 'main' })
  expect(pickBase('main', true, true, true, false)).toEqual({ base: 'main' })
  expect(pickBase('main', true, true, false, true)).toEqual({ base: 'origin/main' })
  const diverged = pickBase('main', true, true, false, false)
  expect(diverged.base).toBe('origin/main')
  expect(diverged.warning).toContain('diverged')
})

test('a visibility is one of three words, and anything else is dropped', () => {
  expect(visibility('PUBLIC\n')).toBe('public')
  expect(visibility('Private')).toBe('private')
  expect(visibility('internal')).toBe('internal')
  expect(visibility('HTTP 404: Not Found')).toBe('')
  expect(visibility('')).toBe('')
})

test('a worktree is named for its backlog ID, lowercased, then its pair', () => {
  expect(worktreeName('sage-heron', 'R78')).toBe('r78-sage-heron')
  expect(worktreeName('sage-heron')).toBe('sage-heron')
})

// A primary checkout at /repo. `git` answers a command, given without its
// `-C <dir>`, with its stdout, an exit code, or nothing for an empty success. A
// program other than git cannot start unless `other` answers for it.
function world(on: any, git: (argv: string) => string | number | void, other?: (argv: string) => string | void, paths: string[] = []) {
  const calls: string[] = []
  on('session.repo', () => ({ value: { root: '/repo', remote: null, internal: false } }))
  on('session.cwd', () => ({ value: '/repo' }))
  on('fs.exists', (_$: any, e: any) => ({ value: paths.includes(e.path) }))
  on('process.run', (_$: any, e: any) => {
    const argv = e.argv as string[]
    const isGit = argv[0] === 'git'
    const line = (isGit ? argv.slice(3) : argv).join(' ')
    calls.push(line)
    const said = isGit ? git(line) : other?.(line)
    if (!isGit && said === undefined) throw new Error('ENOENT')
    return { value: typeof said === 'number' ? { exitCode: said, stdout: '', stderr: 'fatal: no' } : { exitCode: 0, stdout: said ? `${said}\n` : '', stderr: '' } }
  })
  return calls
}
const call = ($: any, name: string, input: object = {}) => $.tool.call({ tool: `mcp__session-skills__${name}`, ...input })
const LIST = 'worktree /repo\nHEAD 0\nbranch refs/heads/main\n\nworktree /repo/.claude/worktrees/r1-a\nHEAD 0\nbranch refs/heads/claude/r1-a\n'

// Local main is ahead of origin/main: a push is held.
const held = (line: string) => {
  if (line.startsWith('symbolic-ref')) return 'origin/main'
  if (line === 'merge-base --is-ancestor main origin/main') return 1
  if (line.startsWith('show-ref')) return 1
  if (line === 'worktree list --porcelain') return LIST
  if (line === 'rev-list --count main..claude/r1-a') return '3'
  if (line.startsWith('rev-list')) return '0'
}

test('find_checkouts reports the base and each worktree, and a fetch that failed', async ($: any, on: any) => {
  world(on, line => (line === 'fetch -q' ? 1 : held(line)))
  const text = (await call($, 'find_checkouts')).result
  expect(text).toContain('primary checkout: /repo\ndefault branch: main\nbase for a new branch: main\n')
  expect(text).toContain('  /repo  main\n  /repo/.claude/worktrees/r1-a  claude/r1-a  3 commits not on main')
  expect(text).toContain('warning: fetch failed, so origin/main may be behind')
})

test('open_worktree opens from a local default branch that is ahead, and links the notes directory', async ($: any, on: any) => {
  const calls = world(on, held, line => (line.startsWith('ln -s') ? '' : undefined), ['/repo/notes.local'])
  const text = (await call($, 'open_worktree', { name: 'sage-heron', id: 'R78' })).result
  expect(calls.indexOf('fetch -q')).toBeLessThan(calls.indexOf('worktree add --no-track /repo/.claude/worktrees/r78-sage-heron -b claude/r78-sage-heron main'))
  expect(calls).toContain('ln -s /repo/notes.local /repo/.claude/worktrees/r78-sage-heron/notes.local')
  expect(text).toContain('worktree: /repo/.claude/worktrees/r78-sage-heron\nbranch: claude/r78-sage-heron\nopened from: main\n')
})

test('open_worktree suffixes a name that a directory or a branch already has', async ($: any, on: any) => {
  const calls = world(on, line => (line === 'show-ref --verify --quiet refs/heads/claude/a-b-2' ? undefined : held(line)), undefined, ['/repo/.claude/worktrees/a-b'])
  expect((await call($, 'open_worktree', { name: 'a-b' })).result).toContain('branch: claude/a-b-3\n')
  expect(calls).toContain('worktree add --no-track /repo/.claude/worktrees/a-b-3 -b claude/a-b-3 main')
})

test('open_worktree refuses a name that is not a hyphenated pair, and reports a notes directory it could not link', async ($: any, on: any) => {
  const calls = world(on, held, undefined, ['/repo/notes.local'])
  for (const input of [{ name: 'Roadmap Lap' }, { name: '../x' }, { name: 'a-b', id: 'R1/..' }, { name: 'a-b', notes: '../etc' }]) {
    expect((await call($, 'open_worktree', input)).isError).toBe(true)
  }
  expect(calls.filter(c => c.startsWith('worktree add'))).toEqual([])
  expect((await call($, 'open_worktree', { name: 'a-b' })).result).toContain('warning: notes.local was not linked')
})

// feat-squash and feat-open have the base's tree when merged; feat-declined
// does not; feat-live has an upstream; claude/r1-a is checked out.
const reap = (line: string) => {
  if (line.startsWith('symbolic-ref')) return 'origin/main'
  if (line.startsWith('for-each-ref --merged')) return 'claude/done\nclaude/r1-a'
  if (line === 'rev-parse -q --verify origin/main^{tree}') return 'TREE'
  if (line.startsWith('for-each-ref --format')) return 'feat-squash\t[gone]\nfeat-declined\t[gone]\nclaude/r1-a\t[gone]\nfeat-live\t[ahead 1]\nmain\t'
  if (line === 'merge-tree --write-tree origin/main feat-declined') return 'OTHER'
  if (line.startsWith('merge-tree')) return 'TREE'
  if (line === 'worktree list --porcelain') return LIST
}
const deleted = (calls: string[]) => calls.filter(c => c.startsWith('branch -'))

test('prune_branches deletes a merged branch and one with a gone upstream and no content of its own', async ($: any, on: any) => {
  const calls = world(on, reap)
  expect((await call($, 'prune_branches')).result).toBe([
    'deleted: claude/done (merged into main)',
    'deleted: feat-squash (upstream gone, content on origin/main)',
    'kept: feat-declined (upstream gone, content not on origin/main)',
    'merged, still checked out: claude/r1-a',
  ].join('\n'))
  expect(deleted(calls)).toEqual(['branch -d claude/done', 'branch -D feat-squash'])
})

// One world a test, since no hook is added after the first call on `$`: the
// faked git reads `now`, which the test changes between calls.
test('prune_branches force-deletes nothing when a check fails', async ($: any, on: any) => {
  let now = reap
  const calls = world(on, line => now(line))
  for (const failing of ['rev-parse -q --verify origin/main^{tree}', 'merge-tree --write-tree origin/main feat-squash']) {
    now = line => (line === failing ? 1 : reap(line))
    await call($, 'prune_branches')
  }
  now = line => (line.startsWith('merge-tree') ? 'TREE\nCONFLICT (content): s' : reap(line))
  await call($, 'prune_branches')
  expect(deleted(calls)).toEqual(['branch -d claude/done', 'branch -d claude/done', 'branch -d claude/done'])
})

test('landing_facts reads git config first, and is unknown where no host tool is installed', async ($: any, on: any) => {
  const config: Record<string, string> = { originVisibility: 'Private', landing: 'pr', holdFork: 'false', holdPrText: 'true' }
  const git = (line: string) => {
    if (line === 'remote get-url origin') return 'https://example.com/a/b.git'
    if (line === 'remote get-url upstream') return 1
    if (line.startsWith('config --get')) return config[line.split('.')[1]] ?? 1
    if (line.startsWith('symbolic-ref')) return 'origin/main'
  }
  const calls = world(on, git)
  expect((await call($, 'landing_facts')).result).toBe('fork: no\norigin visibility: private (git config)\nlanding mode: pr (git config)\nholds lifted: holdFork')
  expect(calls.filter(c => c.startsWith('gh') || c.startsWith('glab'))).toEqual([])
  for (const key of Object.keys(config)) delete config[key]
  expect((await call($, 'landing_facts')).result).toBe('fork: no\norigin visibility: unknown\nlanding mode: unknown\nholds lifted: none')
})

test('landing_facts reads a protected default branch, or a pull-request ruleset, as pr mode', async ($: any, on: any) => {
  const git = (line: string) => (line === 'remote get-url origin' ? 'https://github.com/a/b.git' : line.startsWith('symbolic-ref') ? 'origin/main' : line === 'remote get-url upstream' ? undefined : 1)
  const gh = (isProtected: string, rules: string) => (line: string) =>
    line.includes('visibility') ? 'PUBLIC' : line.includes('nameWithOwner') ? 'a/b' : line.includes('/rules/') ? rules : line.startsWith('gh api') ? isProtected : undefined
  let now = gh('', '')
  world(on, git, line => now(line))
  for (const [isProtected, rules, mode] of [['true', '', 'pr'], ['false', 'deletion\npull_request', 'pr'], ['false', 'deletion', 'merge']]) {
    now = gh(isProtected, rules)
    expect((await call($, 'landing_facts')).result).toBe(`fork: yes, an upstream remote is set\norigin visibility: public (gh)\nlanding mode: ${mode} (gh)\nholds lifted: none`)
  }
})
