// The plugin's hooks module: the tools a session calls to read the claim
// ledger, write its claim, and release it, and the release at session end for a
// session that never wrapped.
import type { Register } from 'claude-code'
import { type Entry, dead, fileOf, ownedBy } from './ledger'

const TOOLS = {
  read_ledger: {
    description: 'Read the claim ledger in the primary checkout, from any worktree. Dead claims are deleted first: a claim is dead when no worktree has its branch checked out. Returns the ledger path, the claims deleted, and every live claim.',
    inputSchema: { type: 'object', properties: {} },
  },
  write_claim: {
    description: "Write this session's claim for the branch checked out in a worktree, replacing any claim for that branch. Returns the whole ledger as it is after the write, to compare touches against.",
    inputSchema: {
      type: 'object',
      properties: {
        worktree: { type: 'string', description: "Absolute path of the lane's worktree, never the primary checkout." },
        item: { type: 'string', description: 'What is claimed, as a short phrase.' },
        touches: { type: 'array', items: { type: 'string' }, description: 'Paths and globs this lane expects to edit.' },
      },
      required: ['worktree', 'item', 'touches'],
    },
  },
  release_claim: {
    description: 'Delete the claim for the branch checked out in a worktree. Returns the claims that remain. An error when that branch has no claim.',
    inputSchema: {
      type: 'object',
      properties: { worktree: { type: 'string', description: "Absolute path of the lane's worktree, never the primary checkout." } },
      required: ['worktree'],
    },
  },
} as const

const DIR = '.claude/claims'

// git is run in the primary checkout. The session's directory is the default,
// and nothing starts there once a session has removed the worktree it had
// changed into.
async function git($: any, cwd: string, ...argv: string[]): Promise<string> {
  const ran = await $.process.run(['git', '-C', cwd, ...argv], { cwd: await primary($) })
  if (ran.exitCode !== 0) throw new Error(`git ${argv.join(' ')} in ${cwd}: ${ran.stderr.trim() || `exit ${ran.exitCode}`}`)
  return ran.stdout
}

// The ledger is in the primary checkout, which is not the session's directory
// in a worktree session.
async function primary($: any): Promise<string> {
  const main = (await $.session.repo())?.root
  if (!main) throw new Error('not inside a git repository')
  return main
}

async function entries($: any, main: string): Promise<Entry[]> {
  const listed = await $.fs.list(`${main}/${DIR}`).catch(() => [])
  const files = listed.filter((f: any) => f.kind === 'file' && f.name.endsWith('.json'))
  return Promise.all(files.map(async (f: any) => ({ name: f.name, mtimeMs: f.mtimeMs, text: await $.fs.read(`${main}/${DIR}/${f.name}`).catch(() => '') })))
}

// $.fs has no delete, and git is the one program every session here has. A
// claim file is untracked, so `git clean` on its literal path removes it and
// nothing else.
async function remove($: any, main: string, name: string): Promise<void> {
  await git($, main, 'clean', '-f', '-x', '-q', '--', `:(literal)${DIR}/${name}`)
  if (await $.fs.exists(`${main}/${DIR}/${name}`)) throw new Error(`${DIR}/${name} was not deleted`)
}

// Branches checked out in a worktree, the primary checkout's first.
async function live($: any, main: string): Promise<string[]> {
  await git($, main, 'worktree', 'prune')
  return [...(await git($, main, 'worktree', 'list', '--porcelain')).matchAll(/^branch refs\/heads\/(.+)$/gm)].map(m => m[1])
}

// The branch a lane's claim is filed under. The primary checkout is refused: a
// path re-derived from a session's own directory is often that one, and a
// release keyed off it would delete nothing.
async function lane($: any, main: string, worktree: string): Promise<string> {
  const branch = (await git($, worktree, 'rev-parse', '--abbrev-ref', 'HEAD')).trim()
  if (branch === 'HEAD') throw new Error(`${worktree} is on a detached HEAD: put it on a branch first`)
  if ((await live($, main))[0] === branch) throw new Error(`${worktree} is the primary checkout, on ${branch}: pass the lane's own worktree`)
  return branch
}

const render = (main: string, list: Entry[]) =>
  `ledger: ${main}/${DIR}\n${list.length ? list.map(e => e.text.trim()).join('\n') : 'no claims'}`

async function readLedger($: any, main: string): Promise<string> {
  const all = await entries($, main)
  const gone = dead(all, await live($, main), await $.clock.now())
  for (const e of gone) await remove($, main, e.name)
  const reaped = gone.map(e => `reaped dead claim: ${e.name}\n`).join('')
  return reaped + render(main, all.filter(e => !gone.includes(e)))
}

async function writeClaim($: any, main: string, e: any): Promise<string> {
  const branch = await lane($, main, String(e.worktree))
  const claim = {
    item: String(e.item),
    branch,
    started: new Date(await $.clock.now()).toISOString().replace(/\.\d+Z$/, 'Z'),
    session: await $.session.id(),
    touches: [...e.touches].map(String),
  }
  await $.fs.write(`${main}/${DIR}/${fileOf(branch)}`, JSON.stringify(claim) + '\n')
  return render(main, await entries($, main))
}

async function releaseClaim($: any, main: string, e: any): Promise<string> {
  const name = fileOf(await lane($, main, String(e.worktree)))
  if (!(await $.fs.exists(`${main}/${DIR}/${name}`))) throw new Error(`no claim ${name}\n${render(main, await entries($, main))}`)
  await remove($, main, name)
  return `released: ${name}\n${render(main, await entries($, main))}`
}

// A tool's answer, or its error as the result: nothing is thrown at the model.
async function answer($: any, name: string, run: (main: string) => Promise<string>) {
  try {
    return { result: await run(await primary($)) }
  } catch (err) {
    const text = `${name}: ${(err as Error).message}`
    return { result: text, text, isError: true }
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    for (const [name, tool] of Object.entries(TOOLS)) await $.tool.register({ name, ...tool, isDeferred: false })
    return next(e)
  })

  on('tool.call', { tool: 'mcp__parallel-session-skills__read_ledger' }, async $ => answer($, 'read_ledger', main => readLedger($, main)))
  on('tool.call', { tool: 'mcp__parallel-session-skills__write_claim' }, async ($, e: any) => answer($, 'write_claim', main => writeClaim($, main, e)))
  on('tool.call', { tool: 'mcp__parallel-session-skills__release_claim' }, async ($, e: any) => answer($, 'release_claim', main => releaseClaim($, main, e)))

  // A session that ends without wrapping still hands its lane back. Every
  // failure is silent: an error at session end is noise, and a claim left
  // behind is reaped once its worktree is gone.
  on('classic.SessionEnd', async ($, e: any, next: any) => {
    try {
      const main = await primary($)
      for (const mine of ownedBy(await entries($, main), String(e.session_id ?? ''))) await remove($, main, mine.name)
    } catch {}
    return next(e)
  })
}
