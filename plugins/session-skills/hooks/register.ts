// The plugin's hooks module: the rules a session starts with, the tools that
// run the git work of both skills, and the tool a worktree session calls to edit
// a file that is only in the primary checkout.
import type { Register } from 'claude-code'
import { pickBase, visibility, worktreeName } from './checkouts'
import { splice } from './splice'

const NONE = { type: 'object', properties: {} } as const
const TOOLS = {
  find_checkouts: {
    description: "Fetch, then report the repo's primary checkout, its default branch, the ref a new branch should start from, and every worktree with its branch and the number of commits it has that the base lacks. Read-only apart from the fetch.",
    inputSchema: NONE,
  },
  open_worktree: {
    description: "Fetch, then open a new worktree and branch for a unit of work under the primary checkout's .claude/worktrees, starting from the current base, and link the repo's local notes directory into it. A name already taken gets a numeric suffix. Returns the worktree path and branch.",
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'An arbitrary lowercase pair such as sage-heron, never activity words.' },
        id: { type: 'string', description: "The work's backlog ID, such as R78, prefixed to the name. Omit where the work has none." },
        notes: { type: 'string', description: "The repo's local-only notes directory at its root. Defaults to notes.local." },
      },
      required: ['name'],
    },
  },
  prune_branches: {
    description: "Prune stale worktree registrations, delete claude/ and worktree- branches merged into the default branch, and delete any branch with a deleted upstream and content already on the remote default branch. Never removes a worktree. Returns one line per branch deleted, kept, or still checked out.",
    inputSchema: NONE,
  },
  landing_facts: {
    description: "Report the facts used to choose how work leaves its branch in this repo: whether it is a fork, origin's visibility, the landing mode (merge or pr), and which holds the user lifted. Read from per-clone git config first, then gh or glab where installed. Read-only.",
    inputSchema: NONE,
  },
} as const
// Every command is run by argument vector, so the same code serves bash, Git
// Bash, and PowerShell sessions.
type Ran = { exitCode: number; stdout: string; stderr: string }

// A command that cannot start, or is still running at the timeout, is a failed
// command here: gh and glab are optional, and a fetch can hang on a credential.
async function run($: any, argv: string[], timeoutMs = 30_000): Promise<Ran> {
  try {
    return await $.process.run(argv, { timeoutMs })
  } catch (err) {
    return { exitCode: 127, stdout: '', stderr: (err as Error).message }
  }
}
const gitArgv = (cwd: string, argv: string[]) => ['git', '-C', cwd, ...argv]
const gitTimeout = (argv: string[]) => (argv[0] === 'fetch' ? 120_000 : 30_000)
const git = ($: any, cwd: string, ...argv: string[]) => run($, gitArgv(cwd, argv), gitTimeout(argv))
const ok = async (ran: Promise<Ran>) => (await ran).exitCode === 0
const out = async (ran: Promise<Ran>) => {
  const r = await ran
  return r.exitCode === 0 ? r.stdout.trim() : ''
}
async function must($: any, cwd: string, ...argv: string[]): Promise<string> {
  const r = await run($, gitArgv(cwd, argv), gitTimeout(argv))
  if (r.exitCode !== 0) throw new Error(`git ${argv.join(' ')} in ${cwd}: ${r.stderr.trim() || `exit ${r.exitCode}`}`)
  return r.stdout
}

async function primary($: any): Promise<string> {
  const main = (await $.session.repo())?.root
  if (!main) throw new Error('not inside a git repository')
  return main
}

const defaultBranch = async ($: any, main: string) =>
  (await out(git($, main, 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD'))).replace(/^origin\//, '') || 'main'

async function locate($: any) {
  const main = await primary($)
  const def = await defaultBranch($, main)
  const warnings: string[] = []
  const fetched = await git($, main, 'fetch', '-q')
  if (fetched.exitCode !== 0) warnings.push(`fetch failed, so origin/${def} may be behind: ${fetched.stderr.trim() || `exit ${fetched.exitCode}`}`)
  const has = (ref: string) => ok(git($, main, 'rev-parse', '--verify', '-q', ref))
  const within = (a: string, b: string) => ok(git($, main, 'merge-base', '--is-ancestor', a, b))
  const origin = `origin/${def}`
  const picked = pickBase(def, await has(origin), await has(`refs/heads/${def}`), await within(origin, def), await within(def, origin))
  if (picked.warning) warnings.push(picked.warning)
  return { main, def, base: picked.base, warnings }
}

async function worktrees($: any, main: string): Promise<{ path: string; branch: string }[]> {
  return (await must($, main, 'worktree', 'list', '--porcelain'))
    .split(/\r?\n\r?\n/)
    .map(block => ({ path: block.match(/^worktree (.+)$/m)?.[1] ?? '', branch: block.match(/^branch refs\/heads\/(.+)$/m)?.[1] ?? '(detached)' }))
    .filter(w => w.path)
}

async function findCheckouts($: any): Promise<string> {
  const { main, def, base, warnings } = await locate($)
  const cwd = await $.session.cwd()
  const here = await out(git($, cwd, 'rev-parse', '--show-toplevel'))
  const rows = []
  for (const w of await worktrees($, main)) {
    const ahead = w.branch === '(detached)' ? '' : await out(git($, main, 'rev-list', '--count', `${base}..${w.branch}`))
    rows.push(`  ${w.path}  ${w.branch}${ahead && ahead !== '0' ? `  ${ahead} ${ahead === '1' ? 'commit' : 'commits'} not on ${base}` : ''}`)
  }
  return [
    `primary checkout: ${main}`,
    `default branch: ${def}`,
    `base for a new branch: ${base}`,
    `session directory: ${here || cwd}`,
    'worktrees, the primary checkout first:',
    ...rows,
    ...warnings.map(w => `warning: ${w}`),
  ].join('\n')
}

// A junction on Windows, which needs no privilege, and a symbolic link
// elsewhere. $.fs has no link call.
// ponytail: Windows is read off a drive-letter path, there being no platform call.
async function link($: any, target: string, at: string): Promise<Ran> {
  return /^[A-Za-z]:[\\/]/.test(target)
    ? run($, ['cmd', '/c', 'mklink', '/J', at.replace(/\//g, '\\'), target.replace(/\//g, '\\')])
    : run($, ['ln', '-s', target, at])
}

async function openWorktree($: any, e: any): Promise<string> {
  const pair = String(e.name ?? '')
  const id = String(e.id ?? '')
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(pair)) throw new Error(`name ${JSON.stringify(pair)} is not lowercase words joined by hyphens`)
  if (id && !/^[A-Za-z0-9.]+$/.test(id)) throw new Error(`id ${JSON.stringify(id)} is not a backlog ID such as R78`)
  const notes = String(e.notes ?? 'notes.local')
  if (!notes || /[\\/]|^\.\.?$/.test(notes)) throw new Error(`notes ${JSON.stringify(notes)} is not the name of a directory at the repo root`)
  const { main, def, base, warnings } = await locate($)
  const root = `${main}/.claude/worktrees`
  const wanted = worktreeName(pair, id)
  let name = wanted
  for (let n = 2; (await $.fs.exists(`${root}/${name}`)) || (await ok(git($, main, 'show-ref', '--verify', '--quiet', `refs/heads/claude/${name}`))); n++) name = `${wanted}-${n}`
  const path = `${root}/${name}`
  await must($, main, 'worktree', 'add', '--no-track', path, '-b', `claude/${name}`, base)
  const lines = [`worktree: ${path}`, `branch: claude/${name}`, `opened from: ${base}`, `primary checkout: ${main}`, `default branch: ${def}`]
  if (await $.fs.exists(`${main}/${notes}`)) {
    const linked = await link($, `${main}/${notes}`, `${path}/${notes}`)
    if (linked.exitCode === 0) lines.push(`notes: ${path}/${notes} links to ${main}/${notes}`)
    else warnings.push(`${notes} was not linked into the worktree, so write notes to ${main}/${notes}: ${linked.stderr.trim() || `exit ${linked.exitCode}`}`)
  }
  return [...lines, ...warnings.map(w => `warning: ${w}`)].join('\n')
}

const firstLine = (text: string) => text.trim().split(/\r?\n/)[0] ?? ''

async function pruneBranches($: any): Promise<string> {
  const main = await primary($)
  const def = await defaultBranch($, main)
  const lines: string[] = []
  await must($, main, 'worktree', 'prune')
  const merged = await must($, main, 'for-each-ref', '--merged', def, '--format=%(refname:short)', 'refs/heads/claude/*', 'refs/heads/worktree-*')
  const checkedOut = (await worktrees($, main)).map(w => w.branch)
  // A branch a session has just opened has the default branch's tip, and git
  // refuses to delete it while its worktree stands.
  for (const b of merged.split(/\r?\n/).filter(b => b && !checkedOut.includes(b))) {
    const gone = await git($, main, 'branch', '-d', b)
    lines.push(gone.exitCode === 0 ? `deleted: ${b} (merged into ${def})` : `left: ${b} (${firstLine(gone.stderr)})`)
  }

  // A branch a host squashed or rebased on merge is not `--merged`. Its
  // upstream is gone, which a declined pull request's is too, so it is deleted
  // only when merging it into the base now would change nothing. A check that
  // fails must never read as merged.
  const base = `origin/${def}`
  const fetched = await git($, main, 'fetch', '-q', '--prune')
  if (fetched.exitCode !== 0) lines.push(`warning: fetch failed, so a branch merged on the host since the last fetch is not found: ${firstLine(fetched.stderr)}`)
  const tree = await out(git($, main, 'rev-parse', '-q', '--verify', `${base}^{tree}`))
  if (tree) {
    const refs = await must($, main, 'for-each-ref', '--format=%(refname:short)%09%(upstream:track)', 'refs/heads')
    for (const [b, track] of refs.split(/\r?\n/).map(l => l.split('\t'))) {
      if (track !== '[gone]') continue
      const result = await out(git($, main, 'merge-tree', '--write-tree', base, b))
      if (result !== tree) lines.push(`kept: ${b} (upstream gone, content not on ${base})`)
      else if (checkedOut.includes(b)) lines.push(`merged, still checked out: ${b}`)
      else {
        const gone = await git($, main, 'branch', '-D', b)
        lines.push(gone.exitCode === 0 ? `deleted: ${b} (upstream gone, content on ${base})` : `left: ${b} (${firstLine(gone.stderr)})`)
      }
    }
  }
  return lines.length ? lines.join('\n') : 'nothing to prune'
}

async function landingFacts($: any): Promise<string> {
  const main = await primary($)
  const config = (key: string) => out(git($, main, 'config', '--get', `session-skills.${key}`))
  const fork = await ok(git($, main, 'remote', 'get-url', 'upstream'))
  const url = await out(git($, main, 'remote', 'get-url', 'origin'))

  let vis = visibility(await config('originVisibility'))
  let visFrom = 'git config'
  if (!vis && url) [vis, visFrom] = [visibility(await out(run($, ['gh', 'repo', 'view', url, '--json', 'visibility', '-q', '.visibility']))), 'gh']
  if (!vis && url) [vis, visFrom] = [visibility(await out(run($, ['glab', 'repo', 'view', url, '-F', 'json', '--jq', '.visibility']))), 'glab']

  // GitHub returns `protected` from its plain branch endpoint to any reader,
  // and its protection endpoint needs admin rights, so the first is read, plus
  // the branch's rulesets.
  let mode = await config('landing')
  let modeFrom = 'git config'
  if (mode !== 'merge' && mode !== 'pr') {
    mode = ''
    const repo = url && (await out(run($, ['gh', 'repo', 'view', url, '--json', 'nameWithOwner', '-q', '.nameWithOwner'])))
    if (repo) {
      const def = await defaultBranch($, main)
      const isProtected = await out(run($, ['gh', 'api', `repos/${repo}/branches/${def}`, '--jq', '.protected']))
      const rules = await out(run($, ['gh', 'api', `repos/${repo}/rules/branches/${def}`, '--jq', '.[].type']))
      if (isProtected === 'true' || rules.split(/\r?\n/).includes('pull_request')) mode = 'pr'
      else if (isProtected === 'false') mode = 'merge'
      modeFrom = 'gh'
    }
  }

  const lifted = []
  for (const hold of ['holdPublicPush', 'holdFork', 'holdPrText']) if ((await config(hold)) === 'false') lifted.push(hold)
  return [
    `fork: ${fork ? 'yes, an upstream remote is set' : 'no'}`,
    `origin visibility: ${vis ? `${vis} (${visFrom})` : 'unknown'}`,
    `landing mode: ${mode ? `${mode} (${modeFrom})` : 'unknown'}`,
    `holds lifted: ${lifted.join(', ') || 'none'}`,
  ].join('\n')
}

// A tool's answer, or its error as the result: nothing is thrown at the model.
async function answer(name: string, run: () => Promise<string>) {
  try {
    return { result: await run() }
  } catch (err) {
    const text = `${name}: ${(err as Error).message}`
    return { result: text, text, isError: true }
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.tool.register({
      name: 'edit_primary_file',
      description: "Edit a file in the repo's primary checkout from a worktree session: replace one passage, or append. The file is read and written in one call. Nothing is written when the passage is absent or occurs more than once.",
      inputSchema: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Absolute path of a file inside the primary checkout.' },
          old: { type: 'string', description: 'The passage to replace, exactly as it is in the file. Empty to append `new` at the end, creating the file if it is not there.' },
          new: { type: 'string', description: 'The text that replaces it.' },
        },
        required: ['path', 'old', 'new'],
      },
      isDeferred: false,
    })
    for (const [name, tool] of Object.entries(TOOLS)) await $.tool.register({ name, ...tool, isDeferred: false })
    return next(e)
  })

  // A fork starts with its parent's context, where the rules already are.
  on('classic.SessionStart', async ($, e: any, next: any) => {
    const ran = await next(e)
    if (e.source === 'fork') return ran
    const rules = await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    return rules ? { ...ran, additionalContext: [...(ran.additionalContext ?? []), rules] } : ran
  })

  on('tool.call', { tool: 'mcp__session-skills__find_checkouts' }, async $ => answer('find_checkouts', () => findCheckouts($)))
  on('tool.call', { tool: 'mcp__session-skills__open_worktree' }, async ($, e: any) => answer('open_worktree', () => openWorktree($, e)))
  on('tool.call', { tool: 'mcp__session-skills__prune_branches' }, async $ => answer('prune_branches', () => pruneBranches($)))
  on('tool.call', { tool: 'mcp__session-skills__landing_facts' }, async $ => answer('landing_facts', () => landingFacts($)))

  on('tool.call', { tool: 'mcp__session-skills__edit_primary_file' }, async ($, e: any) => {
    try {
      const main = (await $.session.repo())?.root
      if (!main) throw new Error('not inside a git repository')
      const path = String(e.path).replace(/\\/g, '/')
      const root = main.replace(/\\/g, '/').replace(/\/$/, '')
      if (!path.startsWith(`${root}/`) || path.split('/').includes('..')) throw new Error(`${e.path} is not inside the primary checkout ${main}`)
      const text = (await $.fs.exists(e.path)) ? await $.fs.read(e.path) : ''
      await $.fs.write(e.path, splice(text, String(e.old), String(e.new)))
      return { result: `edited ${e.path}` }
    } catch (err) {
      const text = `edit_primary_file: ${(err as Error).message}`
      return { result: text, text, isError: true }
    }
  })
}
