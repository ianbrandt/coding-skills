// The plugin's hooks module: the tool a session calls to delete a landed item.
import type { Register } from 'claude-code'
import { deleteItem } from './item'

const TOOL = 'mcp__roadmap-skills__delete_item'

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
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

  on('tool.call', { tool: TOOL }, async ($, e: any) => {
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
