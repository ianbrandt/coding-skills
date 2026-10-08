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
  expect(pickBase('trunk', false, false, false, false).warning).toContain('neither origin/trunk nor trunk is a branch')
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
// program other than git cannot start unless `other` answers for it. A file
// reads as empty unless `files` has it.
function world(on: any, git: (argv: string) => string | number | void, other?: (argv: string) => string | void, paths: string[] = [], files: Record<string, string> = {}) {
  const calls: string[] = []
  on('session.repo', () => ({ value: { root: '/repo', remote: null, internal: false } }))
  on('session.cwd', () => ({ value: '/repo' }))
  on('fs.exists', (_$: any, e: any) => ({ value: paths.includes(e.path) }))
  on('fs.read', (_$: any, e: any) => ({ value: files[e.path] ?? '' }))
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
const BASE = 'refs/remotes/origin/main'
const FETCH = '-c remote.origin.followRemoteHEAD=always fetch -q origin'

// Local main is ahead of origin/main: a push is held.
const held = (line: string) => {
  if (line.startsWith('symbolic-ref')) return BASE
  if (line === `merge-base --is-ancestor refs/heads/main ${BASE}`) return 1
  if (line.startsWith('show-ref')) return 1
  if (line === 'worktree list --porcelain') return LIST
  if (line === 'rev-list --count refs/heads/main..refs/heads/claude/r1-a') return '3'
  if (line.startsWith('rev-list')) return '0'
}

test('find_checkouts reports the base and each worktree, and a fetch that failed', async ($: any, on: any) => {
  world(on, line => (line === FETCH ? 1 : held(line)))
  const text = (await call($, 'find_checkouts')).result
  expect(text).toContain('primary checkout: /repo\ndefault branch: main\nbase for a new branch: main\n')
  expect(text).toContain('  /repo  main\n  /repo/.claude/worktrees/r1-a  claude/r1-a  3 commits not on main')
  expect(text).toContain('warning: fetch failed, so origin/main may be behind')
})

// A bare `git fetch` reads the remote of the current branch's upstream, which
// on a fork is the parent repo.
test('find_checkouts fetches origin by name, and fetches nothing where there is no origin', async ($: any, on: any) => {
  let origin = true
  const calls = world(on, line => (line === 'remote get-url origin' && !origin ? 1 : held(line)))
  await call($, 'find_checkouts')
  expect(calls.filter(c => c.includes('fetch'))).toEqual([FETCH])
  origin = false
  expect((await call($, 'find_checkouts')).result).not.toContain('warning')
  expect(calls.filter(c => c.includes('fetch'))).toEqual([FETCH])
})

// A repo that was pushed rather than cloned has no origin/HEAD until a fetch
// by git 2.48 or later, or `git remote set-head`, sets one.
test('find_checkouts reads the default branch after the fetch, and from the remote where origin/HEAD is not set', async ($: any, on: any) => {
  let set = false
  const calls = world(on, line => {
    if (line === 'remote set-head origin --auto') set = true
    if (line.endsWith('refs/remotes/origin/HEAD')) return !set ? 1 : line.startsWith('symbolic-ref') ? 'refs/remotes/origin/develop' : undefined
    return held(line)
  })
  expect((await call($, 'find_checkouts')).result).toContain('default branch: develop\n')
  expect(calls.indexOf(FETCH)).toBeLessThan(calls.findIndex(c => c.startsWith('symbolic-ref')))
})

test('open_worktree opens from a local default branch that is ahead, and links the notes directory', async ($: any, on: any) => {
  const calls = world(on, held, line => (line.startsWith('ln -s') ? '' : undefined), ['/repo/notes.local'])
  const text = (await call($, 'open_worktree', { name: 'sage-heron', id: 'R78' })).result
  expect(calls.indexOf(FETCH)).toBeLessThan(calls.indexOf('worktree add --no-track /repo/.claude/worktrees/r78-sage-heron -b claude/r78-sage-heron refs/heads/main'))
  expect(calls).toContain('ln -s /repo/notes.local /repo/.claude/worktrees/r78-sage-heron/notes.local')
  expect(text).toContain('worktree: /repo/.claude/worktrees/r78-sage-heron\nbranch: claude/r78-sage-heron\nopened from: main\n')
})

test('open_worktree suffixes a name that a directory or a branch already has', async ($: any, on: any) => {
  const calls = world(on, line => (line === 'show-ref --verify --quiet refs/heads/claude/a-b-2' ? undefined : held(line)), undefined, ['/repo/.claude/worktrees/a-b'])
  expect((await call($, 'open_worktree', { name: 'a-b' })).result).toContain('branch: claude/a-b-3\n')
  expect(calls).toContain('worktree add --no-track /repo/.claude/worktrees/a-b-3 -b claude/a-b-3 refs/heads/main')
})

test('open_worktree refuses a name that is not a hyphenated pair, and reports a notes directory it could not link', async ($: any, on: any) => {
  const calls = world(on, held, undefined, ['/repo/notes.local'])
  for (const input of [{ name: 'Roadmap Lap' }, { name: '../x' }, { name: 'a-b', id: 'R1/..' }, { name: 'a-b', notes: '../etc' }]) {
    expect((await call($, 'open_worktree', input)).isError).toBe(true)
  }
  expect(calls.filter(c => c.startsWith('worktree add'))).toEqual([])
  expect((await call($, 'open_worktree', { name: 'a-b' })).result).toContain('warning: notes.local was not linked')
})

// Every gone branch but feat-declined has the base's tree when merged.
// feat-undone has a commit, u2, that undoes part of what was merged, under a
// tip commit the base has. feat-merged has no commit of its own since the
// fork, as an ancestor of the base has none. feat-live has an upstream, and
// claude/r1-a is checked out. A merge-tree called any other way, as one that
// runs the repo's merge drivers is, returns the base's tree.
const MERGE = '-c merge.default=text -c core.attributesFile=/dev/null --attr-source=EMPTY merge-tree --write-tree'
const whole = (b: string) => `${MERGE} ${BASE} refs/heads/${b}`
const since = (b: string, c: string) => `${MERGE} --merge-base=${c}^ ${BASE} refs/heads/${b}`
const COMMITS: Record<string, string> = { 'feat-squash': 'c2\nc1', 'feat-undone': 'u3\nu2\nu1', 'claude/r1-a': 'r1' }
const reap = (line: string) => {
  if (line.startsWith('symbolic-ref')) return BASE
  if (line.startsWith('for-each-ref --merged refs/heads/main')) return 'claude/done\nclaude/r1-a'
  if (line === `rev-parse --verify -q ${BASE}^{tree}`) return 'TREE'
  if (line === 'hash-object -t tree /dev/null') return 'EMPTY'
  if (line.endsWith('--git-common-dir')) return '/repo/.git'
  if (line.startsWith('for-each-ref --format=%(refname:lstrip=2)')) return 'feat-squash\t[gone]\nfeat-declined\t[gone]\nfeat-undone\t[gone]\nfeat-merged\t[gone]\nclaude/r1-a\t[gone]\nfeat-live\t[ahead 1]\nmain\t'
  if (line.startsWith(`merge-base ${BASE} `)) return 'FORK'
  if (line.startsWith('rev-list --no-merges --ancestry-path=FORK')) return COMMITS[line.split('..refs/heads/')[1]]
  if (line === whole('feat-declined') || line === since('feat-undone', 'u2')) return 'OTHER'
  if (line.includes('merge-tree')) return 'TREE'
  if (line === 'worktree list --porcelain') return LIST
}
const deleted = (calls: string[]) => calls.filter(c => c.startsWith('branch -'))

test('prune_branches deletes a merged branch, and one with a gone upstream and nothing the base lacks', async ($: any, on: any) => {
  const calls = world(on, reap)
  expect((await call($, 'prune_branches')).result).toBe([
    'deleted: claude/done (merged into main)',
    'deleted: feat-squash (upstream gone, content on origin/main)',
    'kept: feat-declined (upstream gone, content not on origin/main)',
    'kept: feat-undone (upstream gone, content not on origin/main)',
    'deleted: feat-merged (upstream gone, content on origin/main)',
    'merged, still checked out: claude/r1-a',
  ].join('\n'))
  expect(deleted(calls)).toEqual(['branch -d claude/done', 'branch -D feat-squash', 'branch -D feat-merged'])
  expect(calls).toContain(FETCH.replace('-q', '-q --prune'))
  expect(calls).toContain('for-each-ref --merged refs/heads/main --format=%(refname:lstrip=2) refs/heads/claude/* refs/heads/worktree-*')
})

// The remote's default branch is develop, and its main is a release branch
// with everything hotfix has. There is no origin/HEAD until the fetch.
test('prune_branches reads the default branch after the fetch', async ($: any, on: any) => {
  const develop = 'refs/remotes/origin/develop'
  let fetched = false
  const calls = world(on, line => {
    if (line.includes('fetch')) fetched = true
    if (line.endsWith('refs/remotes/origin/HEAD')) return !fetched ? 1 : line.startsWith('symbolic-ref') ? develop : undefined
    if (line === `rev-parse --verify -q ${develop}^{tree}`) return 'TREE'
    if (line.startsWith('for-each-ref --merged')) return ''
    if (line.startsWith('for-each-ref --format')) return 'hotfix\t[gone]'
    if (line.includes('merge-tree')) return line.includes(develop) ? 'OTHER' : 'TREE'
    return reap(line)
  })
  expect((await call($, 'prune_branches')).result).toBe('kept: hotfix (upstream gone, content not on origin/develop)')
  expect(deleted(calls)).toEqual([])
})

// One world a test, since no hook is added after the first call on `$`: the
// faked git reads `now`, which the test changes between calls.
test('prune_branches force-deletes nothing when a check or the fetch fails', async ($: any, on: any) => {
  const one = (line: string) => (line.startsWith('for-each-ref --format') ? 'feat-squash\t[gone]' : reap(line))
  let now = one
  const calls = world(on, line => now(line))
  const checks = [`rev-parse --verify -q ${BASE}^{tree}`, 'hash-object -t tree /dev/null', whole('feat-squash'), `merge-base ${BASE} refs/heads/feat-squash`, `rev-list --no-merges --ancestry-path=FORK ${BASE}..refs/heads/feat-squash`, since('feat-squash', 'c1')]
  for (const failing of checks) {
    now = line => (line === failing ? 128 : one(line))
    await call($, 'prune_branches')
  }
  now = line => (line.includes('merge-tree') ? 'TREE\nCONFLICT (content): s' : one(line))
  await call($, 'prune_branches')
  now = line => (line.includes('fetch') ? 1 : one(line))
  expect((await call($, 'prune_branches')).result).toContain('warning: fetch failed, so no branch with a gone upstream was checked')
  expect(deleted(calls)).toEqual(Array(checks.length + 2).fill('branch -d claude/done'))
})

test('prune_branches checks the gone upstreams where there is no local default branch', async ($: any, on: any) => {
  const calls = world(on, line => (line === 'rev-parse --verify -q refs/heads/main' || line.startsWith('for-each-ref --merged') ? 128 : reap(line)))
  expect((await call($, 'prune_branches')).isError).toBeFalsy()
  expect(deleted(calls)).toEqual(['branch -D feat-squash', 'branch -D feat-merged'])
})

// git has no switch that turns off the drivers set in this one file.
test('prune_branches checks no gone upstream where a merge driver is set in .git/info/attributes', async ($: any, on: any) => {
  const files = { '/repo/.git/info/attributes': '# no merge=ours here\n*.txt text\n' }
  const calls = world(on, reap, undefined, [], files)
  expect((await call($, 'prune_branches')).result).toContain('deleted: feat-squash')
  files['/repo/.git/info/attributes'] += ' ver.txt\tmerge=ours\n'
  expect((await call($, 'prune_branches')).result).toBe('deleted: claude/done (merged into main)\nwarning: a merge driver is set in .git/info/attributes, so no branch with a gone upstream was checked')
  expect(deleted(calls).filter(c => c.startsWith('branch -D'))).toEqual(['branch -D feat-squash', 'branch -D feat-merged'])
})

// On a file system that ignores case, `git checkout Feat-Squash` leaves HEAD at
// refs/heads/Feat-Squash for the branch feat-squash, and git deletes that
// branch from under the worktree.
test('prune_branches leaves a branch that a worktree has checked out under another capitalization', async ($: any, on: any) => {
  const list = ['Claude/Done', 'Feat-Squash', 'feat-upper'].map(b => `worktree /repo/${b}\nHEAD 0\nbranch refs/heads/${b}\n`).join('\n')
  const git = (line: string) => (line === 'worktree list --porcelain' ? list : line.startsWith('for-each-ref --format') ? 'feat-squash\t[gone]\nFeat-Upper\t[gone]' : reap(line))
  const calls = world(on, git)
  expect((await call($, 'prune_branches')).result).toBe('deleted: claude/r1-a (merged into main)\nmerged, still checked out: feat-squash\nmerged, still checked out: Feat-Upper')
  expect(deleted(calls)).toEqual(['branch -d claude/r1-a'])
})

test('landing_facts reads git config first, and is unknown where no host tool is installed', async ($: any, on: any) => {
  const config: Record<string, string> = { originVisibility: 'Private', landing: 'pr', holdFork: 'false', holdPrText: 'true' }
  const git = (line: string) => {
    if (line === 'remote get-url origin') return 'https://example.com/a/b.git'
    if (line === 'remote get-url upstream') return 1
    if (line.startsWith('config --get')) return config[line.split('.')[1]] ?? 1
    if (line.startsWith('symbolic-ref')) return BASE
  }
  const calls = world(on, git)
  expect((await call($, 'landing_facts')).result).toBe('fork: no\norigin visibility: private (git config)\nlanding mode: pr (git config)\nholds lifted: holdFork')
  expect(calls.filter(c => c.startsWith('gh') || c.startsWith('glab'))).toEqual([])
  for (const key of Object.keys(config)) delete config[key]
  expect((await call($, 'landing_facts')).result).toBe('fork: no\norigin visibility: unknown\nlanding mode: unknown\nholds lifted: none')
})

test('landing_facts reads a protected default branch, or a pull-request ruleset, as pr mode', async ($: any, on: any) => {
  const git = (line: string) => (line === 'remote get-url origin' ? 'https://github.com/a/b.git' : line.startsWith('symbolic-ref') ? BASE : line === 'remote get-url upstream' ? undefined : 1)
  const gh = (isProtected: string, rules: string) => (line: string) =>
    line.includes('visibility') ? 'PUBLIC' : line.includes('nameWithOwner') ? 'a/b' : line.includes('/rules/') ? rules : line.startsWith('gh api') ? isProtected : undefined
  let now = gh('', '')
  world(on, git, line => now(line))
  for (const [isProtected, rules, mode] of [['true', '', 'pr'], ['false', 'deletion\npull_request', 'pr'], ['false', 'deletion', 'merge']]) {
    now = gh(isProtected, rules)
    expect((await call($, 'landing_facts')).result).toBe(`fork: yes, an upstream remote is set\norigin visibility: public (gh)\nlanding mode: ${mode} (gh)\nholds lifted: none`)
  }
})
