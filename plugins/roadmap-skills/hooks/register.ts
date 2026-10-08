// The plugin's hooks module: the roadmap rule a session starts with, and the
// tools a session calls to find the plan of record and to delete a landed item.
import type { Register } from 'claude-code'
import { deleteItem } from './item'
import { type Plan, planOf, rule } from './plan'

const DELETE = 'mcp__roadmap-skills__delete_item'
const FIND = 'mcp__roadmap-skills__find_roadmap'

// The primary checkout and its plan. Outside a git repository there is neither.
async function find($: any): Promise<{ main: string; plan: Plan } | null> {
  const main = (await $.session.repo())?.root
  if (!main) return null
  const git = (...argv: string[]) => $.process.run(['git', '-C', main, ...argv])
  const hasLocal = await $.fs.exists(`${main}/ROADMAP.local.md`)
  const hasUpstream = (await git('remote', 'get-url', 'upstream')).exitCode === 0
  const tracked = (await git('ls-files', 'ROADMAP.md', 'docs/roadmap.md')).stdout.split('\n').filter(Boolean)
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
      description: 'Delete one landed item from a roadmap file: from its heading to the next heading of the same or a higher level, sub-items included. Returns the headings removed. Nothing is written when the ID matches no heading or more than one.',
      inputSchema: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Absolute path to the roadmap file.' },
          id: { type: 'string', description: 'The item ID its heading starts with, such as R12 or R12.3.' },
        },
        required: ['path', 'id'],
      },
      isDeferred: false,
    })
    return next(e)
  })

  // In a repo with no roadmap of its own nothing is added. A fork starts with
  // its parent's context, where the rule already is.
  on('classic.SessionStart', async ($, e: any, next: any) => {
    const ran = await next(e)
    if (e.source === 'fork') return ran
    const found = await find($).catch(() => null)
    if (!found || !('roadmap' in found.plan)) return ran
    return { ...ran, additionalContext: [...(ran.additionalContext ?? []), rule(found.plan.roadmap, found.main)] }
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
      const { text, removed } = deleteItem(await $.fs.read(e.path), String(e.id))
      await $.fs.write(e.path, text)
      return { result: `removed:\n${removed.join('\n')}` }
    } catch (err) {
      const text = `delete_item: ${(err as Error).message}`
      return { result: text, text, isError: true }
    }
  })
}
