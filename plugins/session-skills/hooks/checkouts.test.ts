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
// `-C <dir>`, with its stdout, an exit code, a whole result, or nothing for an
// empty success. A program other than git cannot start unless `other` answers
// for it. A file reads as empty unless `files` has it. The session's directory
// is a worktree that was removed, so no program starts unless it is run in
// /repo.
type Said = string | number | void | { exitCode: number; stdout: string; stderr: string }
function world(on: any, git: (argv: string) => Said, other?: (argv: string) => string | void, paths: string[] = [], files: Record<string, string> = {}, root = '/repo') {
  const calls: string[] = []
  on('session.repo', () => ({ value: { root, remote: null, internal: false } }))
  on('session.cwd', () => ({ value: '/repo/.claude/worktrees/removed' }))
  // A drive-letter path is resolved against the test's directory on a POSIX host.
  on('fs.exists', (_$: any, e: any) => ({ value: paths.includes(String(e.path).replace(/^.*\/(?=[A-Za-z]:\/)/, '')) }))
  on('fs.read', (_$: any, e: any) => ({ value: files[e.path] ?? '' }))
  on('process.run', (_$: any, e: any) => {
    const argv = e.argv as string[]
    if (e.init?.cwd !== root) throw new Error(`ENOENT: no such file or directory, posix_spawn '${argv[0]}'`)
    const isGit = argv[0] === 'git'
    const line = (isGit ? argv.slice(3) : argv).join(' ')
    calls.push(line)
    const said = isGit ? git(line) : other?.(line)
    if (!isGit && said === undefined) throw new Error('ENOENT')
    if (typeof said === 'object') return { value: said }
    return { value: typeof said === 'number' ? { exitCode: said, stdout: '', stderr: 'fatal: no' } : { exitCode: 0, stdout: said ? `${said}\n` : '', stderr: '' } }
  })
  return calls
}
const call = ($: any, name: string, input: object = {}) => $.tool.call({ tool: `mcp__session-skills__${name}`, ...input })
// As git prints it with -z: every line ends in NUL, and so does each worktree's block.
const trees = (...branches: [string, string][]) => branches.map(([path, branch]) => `worktree ${path}\0HEAD 0\0branch refs/heads/${branch}\0\0`).join('')
const LIST = trees(['/repo', 'main'], ['/repo/.claude/worktrees/r1-a', 'claude/r1-a'])
const BASE = 'refs/remotes/origin/main'
const FETCH = 'fetch -q origin'

// Local main is ahead of origin/main: a push is held.
const held = (line: string) => {
  if (line.startsWith('symbolic-ref')) return BASE
  if (line === `merge-base --is-ancestor refs/heads/main ${BASE}`) return 1
  if (line.startsWith('show-ref')) return 1
  if (line === 'worktree list --porcelain -z') return LIST
  if (line === 'rev-list --count refs/heads/main..refs/heads/claude/r1-a') return '3'
  if (line.startsWith('rev-list')) return '0'
}

// git prints a path as it is, so a newline in it is a newline in the list.
test('find_checkouts reports a worktree at a path with a newline in it', async ($: any, on: any) => {
  const list = trees(['/repo', 'main'], ['/repo/.claude/worktrees/r1\nx', 'claude/r1-x'])
  world(on, line => (line === 'worktree list --porcelain -z' ? list : held(line)))
  expect((await call($, 'find_checkouts')).result).toContain('  /repo  main\n  /repo/.claude/worktrees/r1\nx  claude/r1-x')
})

test('find_checkouts reports the base and each worktree, and a fetch that failed', async ($: any, on: any) => {
  world(on, line => (line === FETCH ? 1 : held(line)))
  const text = (await call($, 'find_checkouts')).result
  expect(text).toContain('primary checkout: /repo\ndefault branch: main\nbase for a new branch: main\n')
  expect(text).toContain('  /repo  main\n  /repo/.claude/worktrees/r1-a  claude/r1-a  3 commits not on main')
  expect(text).toContain('warning: fetch failed, so origin/main may be behind')
})

// A process is started in the session's directory unless another is given, and
// a session that removed the worktree it had changed into has none.
test('the tools answer after the session\'s directory is removed', async ($: any, on: any) => {
  world(on, line => (line === 'rev-parse --show-toplevel' ? 128 : line === 'config --get session-skills.originVisibility' ? 'public' : held(line)))
  expect((await call($, 'find_checkouts')).result).toContain('session directory: /repo/.claude/worktrees/removed\n')
  expect((await call($, 'prune_branches')).isError).toBeUndefined()
  expect((await call($, 'landing_facts')).result).toContain('origin visibility: public (git config)')
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

// An origin/HEAD set on purpose to another branch is the user's.
test('the tools leave alone an origin/HEAD that names a branch origin has', async ($: any, on: any) => {
  const calls = world(on, held, line => (line.startsWith('ln -s') ? '' : undefined))
  await call($, 'find_checkouts')
  await call($, 'open_worktree', { name: 'a-b' })
  await call($, 'prune_branches')
  expect(calls.filter(c => c.includes('set-head') || c.includes('followRemoteHEAD'))).toEqual([])
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

test('open_worktree does not link the notes directory over one that is already in the worktree', async ($: any, on: any) => {
  const calls = world(on, held, line => (line.startsWith('ln -s') ? '' : undefined), ['/repo/notes.local', '/repo/.claude/worktrees/a-b/notes.local'])
  const text = (await call($, 'open_worktree', { name: 'a-b' })).result
  expect(text).toContain('warning: notes.local was not linked into the worktree, so write notes to /repo/notes.local: it is already there')
  expect(calls.filter(c => c.startsWith('ln'))).toEqual([])
})

test('open_worktree takes a notes name of letters, digits, dots, underscores, and hyphens only', async ($: any, on: any) => {
  const calls = world(on, held, line => (line.startsWith('ln -s') ? '' : undefined), ['/repo/notes.local', '/repo/notes_2-x'])
  for (const notes of ['notes&calc', '%X%', 'a b', '.', '..', '', 'a"b']) {
    const ran = await call($, 'open_worktree', { name: 'a-b', notes })
    expect(ran.isError).toBe(true)
    expect(ran.text).toContain('is not the name of a directory at the repo root')
  }
  expect(calls.filter(c => c.startsWith('worktree add'))).toEqual([])
  expect((await call($, 'open_worktree', { name: 'a-b', notes: 'notes_2-x' })).result).toContain('notes: /repo/.claude/worktrees/a-b/notes_2-x links to')
})

test('open_worktree links a Windows notes directory with a junction', async ($: any, on: any) => {
  const cmd = (line: string) => (line.startsWith('cmd') ? '' : undefined)
  const plain = world(on, held, cmd, ['C:/repo/notes.local'], {}, 'C:/repo')
  expect((await call($, 'open_worktree', { name: 'a-b' })).result).toContain('notes: C:/repo/.claude/worktrees/a-b/notes.local links to')
  expect(plain.filter(c => c.startsWith('cmd'))).toEqual(['cmd /c mklink /J C:\\repo\\.claude\\worktrees\\a-b\\notes.local C:\\repo\\notes.local'])
})

// In an argument, cmd reads these as operators or expands them.
test('open_worktree runs no cmd for a Windows path with a character that cmd reads as an operator', async ($: any, on: any) => {
  const calls = world(on, held, line => (line.startsWith('cmd') ? '' : undefined), ['C:/my%X%repo/notes.local'], {}, 'C:/my%X%repo')
  const text = (await call($, 'open_worktree', { name: 'a-b' })).result
  expect(text).toContain('warning: notes.local was not linked into the worktree, so write notes to C:/my%X%repo/notes.local: ')
  expect(calls.filter(c => c.startsWith('cmd'))).toEqual([])
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
  if (line === 'worktree list --porcelain -z') return LIST
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

// `git update-ref` writes origin/HEAD as a commit, which resolves and names no
// branch. Read as it is, the default branch would be the guess, main.
test('prune_branches sets an origin/HEAD that is not a symbolic ref from the remote', async ($: any, on: any) => {
  const develop = 'refs/remotes/origin/develop'
  let set = false
  const calls = world(on, line => {
    if (line === 'remote set-head origin --auto') set = true
    if (line === 'symbolic-ref -q refs/remotes/origin/HEAD') return set ? develop : 1
    if (line === `rev-parse --verify -q ${develop}^{tree}`) return 'TREE'
    if (line.startsWith('for-each-ref --merged')) return ''
    if (line.startsWith('for-each-ref --format')) return 'hotfix\t[gone]'
    if (line.includes('merge-tree')) return line.includes(develop) ? 'OTHER' : 'TREE'
    return reap(line)
  })
  expect((await call($, 'prune_branches')).result).toBe('kept: hotfix (upstream gone, content not on origin/develop)')
  expect(deleted(calls)).toEqual([])
})

// The host renamed master to main. The prune removes origin/master, and
// origin/HEAD then points at nothing.
test('prune_branches finds a default branch the host renamed once the fetch has pruned the old one', async ($: any, on: any) => {
  let pruned = false
  let set = false
  const calls = world(on, line => {
    if (line === 'fetch -q --prune origin') pruned = true
    if (line === 'remote set-head origin --auto') set = true
    if (line === 'symbolic-ref -q refs/remotes/origin/HEAD') return set ? BASE : 'refs/remotes/origin/master'
    if (line === 'rev-parse --verify -q refs/remotes/origin/HEAD') return pruned && !set ? 1 : undefined
    if (line.startsWith('for-each-ref --merged')) return ''
    return line.startsWith('for-each-ref --format') ? 'feat-squash\t[gone]' : reap(line)
  })
  expect((await call($, 'prune_branches')).result).toBe('deleted: feat-squash (upstream gone, content on origin/main)')
  expect(calls.filter(c => c.includes('set-head'))).toEqual(['remote set-head origin --auto'])
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

// A conflict is a merge that has changes the base lacks: exit 1, with the tree
// it left. A merge that cannot run, as with a git before 2.41, is neither merged
// nor unmerged. Nor is a git that crashed, which Claude Code reports as exit 1
// with no output.
test('prune_branches keeps a branch with git\'s message where the merge cannot run, and with the base\'s content note where it conflicts', async ($: any, on: any) => {
  const one = (line: string) => (line.startsWith('for-each-ref --format') ? 'feat-squash\t[gone]' : reap(line))
  let now = one
  const calls = world(on, line => now(line))
  now = line => (line === whole('feat-squash') ? 128 : one(line))
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-squash (upstream gone, check failed: fatal: no)')
  now = line => (line === since('feat-squash', 'c1') ? 129 : one(line))
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-squash (upstream gone, check failed: fatal: no)')
  const usage = { exitCode: 129, stdout: '', stderr: "error: unknown option `write-tree'\nusage: git merge-tree <base-tree> <branch1> <branch2>\n" }
  now = line => (line === whole('feat-squash') ? usage : one(line))
  expect((await call($, 'prune_branches')).result).toBe("deleted: claude/done (merged into main)\nkept: feat-squash (upstream gone, check failed: error: unknown option `write-tree')")
  now = line => (line === whole('feat-squash') ? { exitCode: 2, stdout: '', stderr: '' } : one(line))
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-squash (upstream gone, check failed: exit 2)')
  now = line => (line === whole('feat-squash') ? { exitCode: 1, stdout: '', stderr: '' } : one(line))
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-squash (upstream gone, check failed: exit 1)')
  now = line => (line === whole('feat-squash') ? { exitCode: 1, stdout: 'OTHER\n\nCONFLICT (content): Merge conflict in s\n', stderr: '' } : one(line))
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-squash (upstream gone, content not on origin/main)')
  expect(deleted(calls)).toEqual(Array(6).fill('branch -d claude/done'))
})

test('prune_branches keeps a branch with git\'s message where merge-base or rev-list fails', async ($: any, on: any) => {
  const one = (line: string) => (line.startsWith('for-each-ref --format') ? 'feat-squash\t[gone]' : reap(line))
  let now = one
  const calls = world(on, line => now(line))
  const list = `rev-list --no-merges --ancestry-path=FORK ${BASE}..refs/heads/feat-squash`
  const merges = `rev-list --merges --ancestry-path=FORK ${BASE}..refs/heads/feat-squash`
  for (const failing of [`merge-base ${BASE} refs/heads/feat-squash`, list, merges]) {
    now = line => (line === failing ? 128 : one(line))
    expect((await call($, 'prune_branches')).result).toContain('kept: feat-squash (upstream gone, check failed: fatal: no)')
  }
  now = line => (line === list ? { exitCode: 129, stdout: '', stderr: '' } : one(line))
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-squash (upstream gone, check failed: exit 129)')
  // The merge has run by then, so the two have a commit in common, and exit 1 is not git's answer.
  now = line => (line === `merge-base ${BASE} refs/heads/feat-squash` ? { exitCode: 1, stdout: '', stderr: '' } : one(line))
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-squash (upstream gone, check failed: exit 1)')
  expect(deleted(calls)).toEqual(Array(5).fill('branch -d claude/done'))
})

// feat-hand has a merge commit, M, with a tree that differs from the automatic
// merge of its parents: it was amended to undo part of the merged work.
// feat-clean has a merge commit, N, that is the automatic merge, as one made by
// `git merge origin/main` is. The merge repeated from M finds what the base lacks.
test('prune_branches checks a merge commit with a change of its own, and skips one with none', async ($: any, on: any) => {
  const git = (line: string) => {
    if (line.startsWith('for-each-ref --format')) return 'feat-hand\t[gone]\nfeat-clean\t[gone]'
    if (line.startsWith('rev-list --no-merges --ancestry-path=FORK')) return 'c1'
    if (line.startsWith('rev-list --merges --ancestry-path=FORK')) return line.endsWith('feat-hand') ? 'M' : 'N'
    if (line === 'rev-parse M^@') return 'P1\nP2'
    if (line === 'rev-parse N^@') return 'Q1\nQ2'
    if (line === 'rev-parse M^{tree}') return 'HAND'
    if (line === 'rev-parse N^{tree}') return 'AUTO'
    if (line === `${MERGE} P1 P2` || line === `${MERGE} Q1 Q2`) return 'AUTO'
    if (line === since('feat-hand', 'M')) return 'OTHER'
    return reap(line)
  }
  const calls = world(on, git)
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-hand (upstream gone, content not on origin/main)')
  expect(calls).toContain(since('feat-clean', 'c1'))
  expect(calls).not.toContain(since('feat-clean', 'N'))
  expect(deleted(calls)).toContain('branch -D feat-clean')
  expect(deleted(calls)).not.toContain('branch -D feat-hand')
})

test('prune_branches keeps a branch whose merge commits cannot be listed, or that has a merge of three parents', async ($: any, on: any) => {
  const over: Record<string, string | number> = {}
  const calls = world(on, line => over[line] ?? (line.startsWith('for-each-ref --format') ? 'feat-x\t[gone]' : line.startsWith('rev-list --no-merges --ancestry-path=FORK') ? 'c1' : reap(line)))
  const list = 'rev-list --merges --ancestry-path=FORK refs/remotes/origin/main..refs/heads/feat-x'
  over[list] = 128
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-x')
  over[list] = 'M'
  over['rev-parse M^@'] = 'P1\nP2\nP3'
  over[since('feat-x', 'M')] = 'OTHER'
  expect((await call($, 'prune_branches')).result).toContain('kept: feat-x')
  expect(calls).not.toContain(`${MERGE} P1 P2`)
  expect(deleted(calls)).not.toContain('branch -D feat-x')
})

test('prune_branches reports that nothing was checked when the base tree or the empty tree cannot be read', async ($: any, on: any) => {
  let failing = ''
  world(on, line => (line === failing ? 128 : reap(line)))
  failing = `rev-parse --verify -q ${BASE}^{tree}`
  expect((await call($, 'prune_branches')).result).toContain('warning: no branch with a gone upstream was checked: the tree of origin/main could not be read')
  failing = 'hash-object -t tree /dev/null'
  expect((await call($, 'prune_branches')).result).toContain('warning: no branch with a gone upstream was checked: the empty tree could not be read')
})

test('prune_branches has no warning in a repo with no origin', async ($: any, on: any) => {
  world(on, line => (line === 'remote get-url origin' || line === `rev-parse --verify -q ${BASE}^{tree}` ? 128 : reap(line)))
  expect((await call($, 'prune_branches')).result).toBe('deleted: claude/done (merged into main)')
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
  const list = trees(...['Claude/Done', 'Feat-Squash', 'feat-upper'].map((b): [string, string] => [`/repo/${b}`, b]))
  const git = (line: string) => (line === 'worktree list --porcelain -z' ? list : line.startsWith('for-each-ref --format') ? 'feat-squash\t[gone]\nFeat-Upper\t[gone]' : reap(line))
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
