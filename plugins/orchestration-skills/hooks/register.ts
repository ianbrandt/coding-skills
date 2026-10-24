// The plugin's hooks module: the rules a session's prompts carry, and the one
// rule a subagent's task opens with.
import type { Register } from 'claude-code'

export const SUBAGENT_RULE = "You are a subagent with no user to ask. Before a decision that is hard to reverse (a wire contract or public API, a data schema or file format, a name that becomes permanent, text that publishes under the user's name, a push to a public repository, a call later work will build on), put the decision and its options, with what each costs, in your result instead of settling it silently. The agent reading your report is the one who can stop."

// Whether the model still reads text that starts with this line: false after
// /clear or a compaction, true in a fork or a resumed session.
async function isRead($: any, text: string): Promise<boolean> {
  const head = text.split('\n')[0]
  const messages: any[] = await $.session.messages({ as: 'api' }).catch(() => [])
  return messages.some(m => m.role === 'user' && m.content.some((b: any) => b.type === 'text' && String(b.text).includes(head)))
}

// Under managed settings `cc-plugin-sec-default` sends every `classic.*` event
// past this plugin, so the rules ride on prompts and subagent tasks instead.
export const register: Register = on => {
  on('prompt.submit', async ($, e: any, next: any) => {
    const rules = await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    return next(rules && !(await isRead($, rules)) ? { ...e, context: [...(e.context ?? []), rules] } : e)
  })

  // ponytail: only a subagent started with the Agent tool gets the rule, so a Workflow's agents start without it.
  on('tool.call', { tool: 'Agent' }, async ($, e: any, next: any) => next({ ...e, prompt: `${SUBAGENT_RULE}\n\n${e.prompt}` }))
}
