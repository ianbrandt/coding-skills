// The plugin's hooks module: the roadmap rule a session starts with, and the
// tools a session calls to find the plan of record and to delete a landed item.
import type { Register } from 'claude-code'
import { deleteItem } from './item'
import { type Plan, planOf, rule } from './plan'

const DELETE = 'mcp__roadmap-skills__delete_item'
const FIND = 'mcp__roadmap-skills__find_roadmap'

// The first line git wrote for a command that failed, or its exit code: Claude
// Code reports a git that crashed as exit 1 with no output.
const why = (r: { exitCode: number; stderr: string }) => String(r.stderr).trim().split(/\r?\n/)[0] || `exit ${r.exitCode}`

// The primary checkout and its plan. Outside a git repository there is neither.
// git is run in the primary checkout: the session's directory is the default,
// and nothing starts there once a session has removed the worktree it had
// changed into. git exits 2 for a remote it does not have, and any other
// failure throws: a repo not known to be a fork is not known to have a roadmap
// of its own.
async function find($: any): Promise<{ main: string; plan: Plan } | null> {
  const main = (await $.session.repo())?.root
  if (!main) return null
  const git = (...argv: string[]) => $.process.run(['git', '-C', main, ...argv], { cwd: main })
  const hasLocal = await $.fs.exists(`${main}/ROADMAP.local.md`)
  const upstream = await git('remote', 'get-url', 'upstream')
  if (upstream.exitCode !== 0 && upstream.exitCode !== 2) throw new Error(`git remote get-url upstream in ${main}: ${why(upstream)}`)
  const hasUpstream = upstream.exitCode === 0
  const listed = await git('ls-files', 'ROADMAP.md', 'docs/roadmap.md')
  if (listed.exitCode !== 0) throw new Error(`git ls-files in ${main}: ${why(listed)}`)
  const tracked = String(listed.stdout).split(/\r?\n/).filter(Boolean)
  return { main, plan: planOf({ hasLocal, hasUpstream, tracked }) }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.tool.register({
      name: 'find_roadmap',
      description: "Find this repo's plan of record from any worktree. Returns the primary checkout, the kind (local-only, tracked, fork-without-roadmap, or none), and the absolute paths of the roadmap and of its changelog where it has one.",
      inputSchema: { type: 'object', properties: {} },
      isDeferred: false,
    })
    await $.tool.register({
      name: 'delete_item',
      description: 'Delete one landed item from a roadmap file: from its heading to the next heading of the same or a higher level, sub-items included. Returns the headings removed. Nothing is written when the ID matches no heading or more than one, or when the file changes during the call. Two calls at the same moment can both succeed with one edit lost, so read the file afterward where that matters.',
      inputSchema: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Absolute path to the roadmap file, inside the primary checkout or one of its worktrees.' },
          id: { type: 'string', description: 'The item ID its heading starts with, such as R12 or R12.3.' },
        },
        required: ['path', 'id'],
      },
      isDeferred: false,
    })
    return next(e)
  })

  // In a repo with no roadmap of its own nothing is added. A fork starts with
  // its parent's context, where the rule already is. A lookup that failed is
  // one line of context, since the repo may have a roadmap.
  on('classic.SessionStart', async ($, e: any, next: any) => {
    const ran = await next(e)
    if (e.source === 'fork') return ran
    const added = await find($).then(
      found => (found && 'roadmap' in found.plan ? rule(found.plan, found.main) : ''),
      err => `The roadmap lookup failed, so it is not known whether this repo has a roadmap: ${(err as Error).message}`,
    )
    return added ? { ...ran, additionalContext: [...(ran.additionalContext ?? []), added] } : ran
  })

  on('tool.call', { tool: FIND }, async $ => {
    try {
      const found = await find($)
      if (!found) return { result: 'kind: none\nNot inside a git repository.' }
      const { main, plan } = found
      const lines = [`main: ${main}`, `kind: ${plan.kind}`]
      if ('roadmap' in plan) lines.push(`roadmap: ${main}/${plan.roadmap}`)
      if ('history' in plan && plan.history) lines.push(`history: ${main}/${plan.history}`)
      return { result: lines.join('\n') }
    } catch (err) {
      const text = `find_roadmap: ${(err as Error).message}`
      return { result: text, text, isError: true }
    }
  })

  on('tool.call', { tool: DELETE }, async ($, e: any) => {
    try {
      const main = (await $.session.repo())?.root
      if (!main) throw new Error('not inside a git repository')
      const path = String(e.path).replace(/\\/g, '/')
      // A tracked roadmap is edited in a lane's worktree, which can be anywhere.
      // With -z each line ends in NUL, so a newline in a path stays in it.
      const listed = await $.process.run(['git', '-C', main, 'worktree', 'list', '--porcelain', '-z'], { cwd: main })
      if (listed.exitCode !== 0) throw new Error(`git worktree list in ${main}: ${String(listed.stderr).trim().split('\n')[0] || `exit ${listed.exitCode}`}`)
      const roots = [main, ...String(listed.stdout).split('\0').filter(l => l.startsWith('worktree ')).map(l => l.slice('worktree '.length))].map(r => r.replace(/\\/g, '/').replace(/\/$/, ''))
      if (!roots.some(r => path.startsWith(`${r}/`)) || path.split('/').includes('..')) throw new Error(`${e.path} is not inside the primary checkout ${main} or one of its worktrees`)
      const before = await $.fs.read(e.path)
      const { text, removed } = deleteItem(before, String(e.id))
      // Another session may have added an item since the read above.
      if ((await $.fs.read(e.path)) !== before) throw new Error(`${e.path} changed while the item was being deleted. Nothing was written. Call the tool again.`)
      await $.fs.write(e.path, text)
      return { result: `removed:\n${removed.join('\n')}` }
    } catch (err) {
      const text = `delete_item: ${(err as Error).message}`
      return { result: text, text, isError: true }
    }
  })
}
