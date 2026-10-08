// claude plugin test: where the plan of record is, the rule at session start,
// and the tool that reports both.
import { expect, test } from 'claude-code/testing'
import { planOf } from './plan'

test('a local-only roadmap comes first, then the fork check, then a tracked one', () => {
  const none = { hasLocal: false, hasUpstream: false, tracked: [] }
  expect(planOf(none)).toEqual({ kind: 'none' })
  expect(planOf({ ...none, tracked: ['ROADMAP.md'] })).toEqual({ kind: 'tracked', roadmap: 'ROADMAP.md' })
  expect(planOf({ ...none, tracked: ['docs/roadmap.md'] })).toEqual({ kind: 'tracked', roadmap: 'docs/roadmap.md' })
  expect(planOf({ ...none, tracked: ['docs/roadmap.md', 'ROADMAP.md'] })).toEqual({ kind: 'tracked', roadmap: 'ROADMAP.md' })
  expect(planOf({ ...none, hasUpstream: true, tracked: ['ROADMAP.md'] })).toEqual({ kind: 'fork-without-roadmap' })
  expect(planOf({ hasLocal: true, hasUpstream: true, tracked: ['ROADMAP.md'] })).toEqual({
    kind: 'local-only', roadmap: 'ROADMAP.local.md', history: 'ROADMAP-CHANGELOG.local.md',
  })
})

// A repo as the module reads it: the primary checkout, the files in it, whether
// it has an upstream remote, and the roadmap paths git reports as tracked. Hooks
// are registered once per test, so a test changes the repo through `now`.
type Repo = { root?: string; files?: string[]; hasUpstream?: boolean; tracked?: string[] }
function world(on: any, first: Repo) {
  const w = { now: first, argvs: [] as string[][], cwds: [] as unknown[] }
  on('session.repo', () => ({ value: w.now.root ? { root: w.now.root, remote: null, internal: false } : null }))
  on('fs.exists', (_$: any, e: any) => ({ value: (w.now.files ?? []).includes(String(e.path).replace(/^[A-Za-z]:/, '').replace(/\\/g, '/')) }))
  on('process.run', (_$: any, e: any) => {
    w.argvs.push(e.argv)
    w.cwds.push(e.init?.cwd)
    const out = (exitCode: number, stdout = '') => ({ value: { exitCode, stdout, stderr: '' } })
    return e.argv.includes('remote') ? out(w.now.hasUpstream ? 0 : 2) : out(0, (w.now.tracked ?? []).map(p => p + '\n').join(''))
  })
  on('classic.SessionStart', () => ({ additionalContext: ['from a settings hook'] }))
  return w
}
const start = async ($: any, source = 'startup') => (await $.classic.SessionStart({ source })).additionalContext
const FIND = 'mcp__roadmap-skills__find_roadmap'
const found = async ($: any) => (await $.tool.call({ tool: FIND })).result

test('the rule is added in a repo with a roadmap, read from the primary checkout', async ($: any, on: any) => {
  const w = world(on, { root: '/repo', files: ['/repo/ROADMAP.local.md'] })
  const added = await start($)
  expect(added[0]).toBe('from a settings hook')
  expect(added[1]).toMatch(/^ROADMAP RULE ACTIVE\n\nThis repo's plan of record is `ROADMAP.local.md`, in the primary checkout at `\/repo`\./)
  expect(added[1]).toContain("A tracked one is edited in the lane's worktree copy")
  expect(w.argvs).toHaveLength(2)
  expect(w.argvs.every(a => a[0] === 'git' && a[1] === '-C' && a[2] === '/repo')).toBe(true)
})

test('nothing is added with no roadmap, in a fork with only a tracked one, outside a repo, or to a fork of a session', async ($: any, on: any) => {
  const w = world(on, { root: '/repo' })
  expect(await start($)).toEqual(['from a settings hook'])
  w.now = { root: '/repo', hasUpstream: true, tracked: ['ROADMAP.md'] }
  expect(await start($)).toEqual(['from a settings hook'])
  w.now = {}
  expect(await start($)).toEqual(['from a settings hook'])
  w.now = { root: '/repo', tracked: ['ROADMAP.md'] }
  expect(await start($, 'fork')).toEqual(['from a settings hook'])
  expect((await start($, 'compact'))[1]).toContain('`ROADMAP.md`')
})

test('the tool returns absolute paths in the primary checkout', async ($: any, on: any) => {
  const w = world(on, { root: '/repo', files: ['/repo/ROADMAP.local.md'] })
  expect(await found($)).toBe('main: /repo\nkind: local-only\nroadmap: /repo/ROADMAP.local.md\nhistory: /repo/ROADMAP-CHANGELOG.local.md')
  w.now = { root: '/repo', tracked: ['docs/roadmap.md'] }
  expect(await found($)).toBe('main: /repo\nkind: tracked\nroadmap: /repo/docs/roadmap.md')
  w.now = { root: '/repo', hasUpstream: true }
  expect(await found($)).toBe('main: /repo\nkind: fork-without-roadmap')
  w.now = {}
  expect(await found($)).toContain('kind: none')
})

// A process is started in the session's directory unless another is given, and
// a session that removed the worktree it had changed into has none.
test('git is run in the primary checkout, whatever the session\'s directory is', async ($: any, on: any) => {
  const w = world(on, { root: '/repo', files: ['/repo/ROADMAP.local.md'] })
  await found($)
  expect(w.cwds).toEqual(['/repo', '/repo'])
})
