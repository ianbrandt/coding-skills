// Publication gate: check the human-facing text in a git commit, a gh command, a
// call to an MCP tool that can publish, a prose file just written, or a draft the
// reply puts in a `draft` fence, against the four prohibitions, before it reaches
// a reader.
//
// The check is one `$.model.complete` call with gate-prompt.md as the system
// prompt, rules.md appended to it so that the rules are written down once, and
// the text under review as the message. The model comes from
// WRITING_CONVENTIONS_GATE_MODEL, or the `sonnet` alias when that is unset. An
// alias is resolved the way `--model` resolves one, on a first-party install and
// on a proxy in front of Bedrock or Vertex alike.
//
// A gate that cannot reach a model must not stop a commit, so every failure
// lets the event through, and the user is told once. Only a finding with its
// quote in the text under review blocks a command, a call, or a reply.
import type { Register } from 'claude-code'
import { bodyFiles, keys, walk } from './keys'
import { lint } from './lint'
import { drafts, excerpt, findings } from './text'

// The function-hook API is early access and moves between releases. This is the
// CLI the module was checked on. On an older one the module does nothing, and
// the user is told once.
const CHECKED = [2, 1, 289]

let warned = false

// Whether CLI version `base` is the checked one or later. dash.ts asks this
// with a version it read through its own $.
export function atLeast(base: unknown): boolean {
  const v = String(base).split('.').map(Number)
  for (let i = 0; i < 3; i++) if (v[i] !== CHECKED[i]) return v[i] > CHECKED[i]
  return true
}

async function isChecked($: any): Promise<boolean> {
  const ok = atLeast((await $.session.version()).base)
  if (!ok && !warned) {
    warned = true
    $.ui.toast(`writing-conventions: the gate and the reply lint are off. They need Claude Code ${CHECKED.join('.')} or later.`, { timeoutMs: 15000 })
  }
  return ok
}

// What a check found: `block` for a finding, `context` for a note to the model,
// or neither.
type Verdict = { block?: string; context?: string }

const CAP = 50000
const ADVICE = 'Each rewrite after -> is only a suggestion; where one reads stiffly, write the sentence the way a person would say it.'

// Four command families always reach the reader, whatever is cached, so a wrong
// NEVER from the classifier can never lose them. Matching the command text
// covers `git -C <path> commit`, which no `Bash(git commit *)` rule matches.
const FAMILIES = /git commit|git -C[\s\S]*commit|gh pr |gh issue |gh release /

// A model call that failed, or a reply that could not be used.
class Off extends Error {}

async function ask($: any, system: string[], prompt: string): Promise<string> {
  const parts: string[] = []
  for (const f of system) parts.push(await $.fs.read(`${$.plugin.root}/hooks/${f}`))
  const reply = await $.model.complete({
    model: (await $.env.get('WRITING_CONVENTIONS_GATE_MODEL')) || 'sonnet',
    system: parts.join(''),
    prompt,
    timeoutMs: 60000,
  })
  if (!reply.isAnswered) throw new Off()
  return reply.text
}

// The user is told the first time in a session that a check could not run,
// through a toast, which the user is shown and the model is not.
let told = false

function off($: any): Verdict {
  if (!told) {
    told = true
    $.ui.toast('writing-conventions: model review is off, because a check failed. Commit, PR, MCP, file, and draft text is not being read; the reply lint still runs.', { timeoutMs: 15000 })
  }
  return {}
}

// The classifiers' answers are kept per user, outside the plugin's directory,
// which is per version. A file is named for a hash of the classifier's prompt,
// so a changed prompt starts a new file. The user can read and edit it.
function hash(text: string): string {
  let h = 0x811c9dc5
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 0x01000193)
  return (h >>> 0).toString(16)
}

async function cachePath($: any, name: string, prompt: string): Promise<string> {
  const config = (await $.env.get('CLAUDE_CONFIG_DIR')) || `${(await $.env.get('HOME')) || (await $.env.get('USERPROFILE'))}/.claude`
  return `${config}/writing-conventions/${name}-${hash(await $.fs.read(`${$.plugin.root}/hooks/${prompt}`))}.txt`
}

// A cache the user saved from an editor may have CRLF line ends.
const lines = (text: string) => text.split(/\r?\n/).filter(l => l !== '')

async function cached($: any, path: string): Promise<string[]> {
  return lines(await $.fs.read(path).catch(() => ''))
}

// ponytail: read, then write the whole file, one append at a time in this
// session. Another session's append in between is lost, and its key is asked
// about again.
let writing: Promise<void> = Promise.resolve()

function keep($: any, path: string, answers: string[]): Promise<void> {
  writing = writing.then(async () => {
    const old = await $.fs.read(path).catch(() => '')
    await $.fs.write(path, `${old}${answers.join('\n')}\n`)
  }).catch(() => {})
  return writing
}

// publishes($, cmd, mode, proj): whether a command outside the four families
// goes to the reader. keys() splits it into keys, and walk() looks them up in
// the cache, one line per answer, <scope><TAB><class><TAB><key>, where a key
// below a task runner or under a path is kept per project. One call answers
// every key the cache has no line for, and a key it leaves out, or answers in
// any other form, is doubt: it reads as CAN_PUBLISH and is not kept.
async function publishes($: any, cmd: string, mode: 'bash' | 'pwsh', proj: string): Promise<boolean> {
  // walk() reads no keys as a safe command, so a command that could not be
  // split goes to the reader.
  let keyLines: string[]
  try {
    keyLines = keys(cmd, mode)
  } catch {
    return true
  }
  const path = await cachePath($, 'shell-commands', 'classify-command.md')
  const known = await cached($, path)
  const first = walk(keyLines, known, proj)
  if (first[0] !== 'ASK') return first[0] === 'READER'
  const want = new Map<string, string[]>()
  for (const line of first.slice(1)) {
    const [, scope, key] = line.split('\t')
    want.set(key, [...(want.get(key) ?? []), scope])
  }
  const reply = await ask($, ['classify-command.md'], `${cmd}\n\n${[...want.keys()].join('\n')}`)
  const answers: string[] = []
  for (const line of reply.split('\n')) {
    const m = /[ \t]+(NEVER|CAN_PUBLISH|DESCEND|PROJECT|RUNS_CODE)\r?$/.exec(line)
    const key = m ? line.slice(0, m.index) : ''
    for (const scope of (m && want.get(key)) || []) answers.push(`${scope}\t${m![1]}\t${key}`)
    want.delete(key)
  }
  if (answers.length > 0) await keep($, path, answers)
  return walk(keyLines, [...known, ...answers], proj, true)[0] !== 'SAFE'
}

type Bodies = { read: { name: string; text: string }[]; unread: string[] }

// bodies($, cmd, mode, base, proj): the files the command passes a commit, PR,
// issue, or release body in, and a line for each one that is not read.
// bodyFiles() finds the files, from the flags written down there, and the reader
// never chooses one. A file is read only when the text on disk is the text the
// command will publish, as far as can be told: a literal path that no other
// word of the command names, since a command that writes the file first
// publishes other text; relative to the directory the command starts in, with
// no cd and no git -C; a readable regular file, not a link, in the project or a
// temporary directory; and at most 1 MB with no NUL in its first 8 KB. Up to 4
// files are read, with CAP characters in all.
async function bodies($: any, cmd: string, mode: 'bash' | 'pwsh', base: string, proj: string): Promise<Bodies> {
  const out: Bodies = { read: [], unread: [] }
  const real = async (p: string | undefined) => (p ? (await $.fs.stat(p, { resolve: true }).catch(() => undefined))?.realPath : undefined)
  let total = 0
  for (const line of bodyFiles(cmd, mode)) {
    const tab = line.indexOf('\t')
    const moved = line.slice(0, tab) === '1'
    const op = line.slice(tab + 1)
    let why = ''
    let text = ''
    const path = /^(\/|[A-Za-z]:\/)/.test(op) ? op : `${base}/${op}`
    if (op === '' || /[^A-Za-z0-9._/+@,:=-]/.test(op)) why = 'it is not a literal path'
    else if (path !== op && moved) why = 'the command may change directory first'
    else if (cmd.split(op.slice(op.lastIndexOf('/') + 1)).length > 2) why = 'the command names it more than once, so it may write the file before reading it'
    else {
      const stat = await $.fs.stat(path, { resolve: true }).catch(() => undefined)
      if (!stat || stat.isLink || stat.kind !== 'file' || !stat.realPath) why = 'it is not a regular file'
      else {
        const roots = [await real(proj), await real(await $.env.get('TMPDIR')), await real('/tmp')]
        const dir = stat.realPath.slice(0, stat.realPath.lastIndexOf('/') + 1)
        if (!roots.some(r => r && dir.startsWith(`${r.replace(/\/$/, '')}/`))) why = 'it is outside the project and the temporary directory'
        else if (stat.size > 1048576) why = 'it is over 1 MB'
        else {
          const got = await $.fs.read(path).catch(() => undefined)
          if (got === undefined) why = 'it cannot be read'
          else if (got.slice(0, 8192).includes('\0')) why = 'it is not text'
          else if (out.read.length >= 4 || total + got.length > CAP) why = `the gate reads at most 4 body files and ${CAP} characters`
          else text = got
        }
      }
    }
    if (why) out.unread.push(`The body in ${op} was not read: ${why}.`)
    else {
      total += text.length
      out.read.push({ name: op, text })
    }
  }
  return out
}

// read($, prompt, sources): the reader's verdict on `prompt`, and the findings
// in it that quote one of `sources`. The reader can see text quoted from an
// untrusted source, so no finding is acted on until its quote is found in the
// text the gate chose to review.
async function read($: any, prompt: string, sources: string[]): Promise<{ found: string; local: boolean }> {
  const verdict = await ask($, ['gate-prompt.md', 'rules.md'], prompt)
  const head = verdict.split('\n').find(l => /[^ \t\r]/.test(l)) ?? ''
  return { found: findings(verdict, sources).replace(/\n+$/, ''), local: head.replace(/[ \t\r]/g, '') === 'LOCAL' }
}

const join = (...parts: string[]) => parts.filter(p => p !== '').join('\n')

// A shell command, checked before it runs. `input` is what the reader is sent.
async function shell($: any, input: any): Promise<Verdict> {
  const cmd = String(input.tool_input.command ?? '')
  const mode = input.tool_name === 'PowerShell' ? 'pwsh' : 'bash'
  const proj = (await $.session.root()) || input.cwd || '/'
  let toFile = false
  if (!FAMILIES.test(cmd)) {
    if ((await $.env.get('WRITING_CONVENTIONS_SHELL_CLASSIFIER')) === '0') return {}
    if (!(await publishes($, cmd, mode, proj))) return {}
    toFile = true
  }
  const { read: files, unread } = await bodies($, cmd, mode, input.cwd, proj)
  const prompt = JSON.stringify(input) + files.map(f => `\n\nFile: ${f.name}\n\n${f.text}`).join('')
  const { found, local } = await read($, prompt, [cmd, ...files.map(f => f.text)])
  const notRead = unread.join('\n')
  if (found === '') return notRead ? { context: notRead } : {}
  // The reader answers LOCAL when the text only goes into a file on this
  // machine, such as a script that rewrites a local file. That is the file
  // check's case, so the findings come back and nothing is blocked. The four
  // families always block.
  if (toFile && local) return { context: join(found, `Fix the quoted text in the file after the command runs. ${ADVICE}`, notRead) }
  return { block: join(found, `Rewrite the quoted text and run the command again. ${ADVICE}`, notRead) }
}

// strings(value): every string value at any depth, and no key.
function strings(value: unknown): string[] {
  if (typeof value === 'string') return [value]
  return value && typeof value === 'object' ? Object.values(value).flatMap(strings) : []
}

// A call to an MCP tool. Whether the tool can publish is asked of a model once
// per tool and kept, one line per answer, so no server or tool name is written
// here. For one tool a CAN_PUBLISH line wins over a NEVER line, and a line in
// any other form is ignored.
async function mcp($: any, input: any): Promise<Verdict> {
  const path = await cachePath($, 'mcp-tools', 'classify-prompt.md')
  const mine = (await cached($, path)).map(l => l.split(/[ \t]+/).filter(w => w !== '')).filter(w => w.length === 2 && w[0] === input.tool_name)
  let cls = mine.some(w => w[1] === 'CAN_PUBLISH') ? 'CAN_PUBLISH' : mine.some(w => w[1] === 'NEVER') ? 'NEVER' : ''
  if (cls === '') {
    const reply = await ask($, ['classify-prompt.md'], JSON.stringify(input))
    // The first line that is not blank. A line holding only a carriage return
    // counts, so the answer after it is doubt.
    cls = (reply.split('\n').find(l => /[^ \t]/.test(l)) ?? '').replace(/\r$/, '')
    // A reply in any other form is doubt, which reads as CAN_PUBLISH and is not kept.
    if (cls === 'NEVER' || cls === 'CAN_PUBLISH') await keep($, path, [`${input.tool_name} ${cls}`])
    else cls = 'CAN_PUBLISH'
  }
  if (cls !== 'CAN_PUBLISH') return {}
  // The reader is sent the whole input, structure included, and a finding has
  // to quote one of the string values in tool_input. Each value is a source of
  // its own, so no quote can match across two of them.
  const { found } = await read($, JSON.stringify(input), strings(input.tool_input))
  return found === '' ? {} : { block: join(found, `Rewrite the quoted text and make the call again. ${ADVICE}`) }
}

// A prose file just written. Only the file the tool wrote is read, and the
// reader is sent the text under review, not the hook input, which for a Write
// holds the whole file. A file is cheap to fix after the fact and a blocked edit
// stops the turn, so the findings come back as context and nothing is blocked.
async function file($: any, e: any): Promise<Verdict> {
  const path = String(e.tool_input?.file_path ?? '')
  if (!/\.(md|markdown|txt|adoc|rst)$/i.test(path)) return {}
  let text = String(e.tool_input.content ?? '')
  let unread = ''
  if (e.tool_name === 'Edit') {
    const fresh = String(e.tool_input.new_string ?? '')
    if (!/\S/.test(fresh)) return { context: `Not reviewed: this edit to ${path} only deleted text.` }
    const stat = await $.fs.stat(path).catch(() => undefined)
    const whole = stat?.kind === 'file' && stat.size <= 1048576 ? await $.fs.read(path).catch(() => undefined) : undefined
    if (whole === undefined) {
      text = fresh
      unread = `Only the new text was reviewed, not the sentences around it: ${path} is over 1 MB or could not be read.`
    } else text = excerpt(fresh, whole, CAP) || fresh
  }
  if (text.length > CAP) {
    text = text.slice(0, CAP)
    unread = `Only the first ${CAP} characters of the text were reviewed.`
  }
  const { found } = await read($, `File: ${path}\n\n${text}`, [text])
  return { context: join(found && `${found}\nFix the quoted text in ${path}. ${ADVICE}`, unread) }
}

// The blocks of each turn's replies, by prompt_id. A blocked Stop costs a whole
// re-emitted reply, so a reader that keeps finding something in each rewrite is
// stopped after two.
const blocked = new Map<string, number>()

// A reply the session has tagged as a draft for publication. Only the text
// inside a `draft` fence is reviewed, so nothing else in the reply is judged by
// the model, and a reply with no such fence costs no call at all. An untagged
// draft is read by the reply lint alone.
async function stop($: any, e: any): Promise<Verdict> {
  if ((await $.env.get('WRITING_CONVENTIONS_STOP_READER')) === '0') return {}
  // Each draft ends on a line holding only \x01, and the cap comes off before
  // the reader is sent them, so a quote from past it is never verified.
  const text = drafts(String(e.last_assistant_message ?? '')).slice(0, CAP)
  // Blocking is counted per turn, by the prompt_id, which is the same on every
  // Stop of one turn. Without one nothing can be counted, so nothing is blocked
  // and a call would buy nothing.
  const turn = String(e.prompt_id ?? '')
  if (text === '' || turn === '') return {}
  // The reader is sent the drafts and nothing else. Each one stays a source of
  // its own, so no finding can quote across two of them.
  const { found } = await read($, text.replace(/\x01/g, '\n'), text.split('\x01'))
  if (found === '') return {}
  const count = blocked.get(turn) ?? 0
  if (count >= 2) {
    $.ui.toast('writing-conventions: the draft in this reply still reads as a violation after two rewrites. Review is unresolved and the reply stands.', { timeoutMs: 15000 })
    return {}
  }
  blocked.set(turn, count + 1)
  return { block: join(found, `Rewrite the quoted text and emit the corrected draft. ${ADVICE}`) }
}

// One check, which must not stop an event it could not make.
async function gate($: any, check: () => Promise<Verdict>): Promise<Verdict> {
  try {
    return (await isChecked($)) ? await check() : {}
  } catch {
    return off($)
  }
}

// The reply lint and the reminders around it. None of them blocks: a Stop hook
// cannot patch a reply, so blocking one costs a full re-emission of an answer
// the reader has already seen. The correction lands on the next reply instead.
const REMINDER = 'Style, for this reply and any prose written to files: an inanimate subject takes no agentive verb—"the entry declared in the `plugins` block", never "the `plugins` block owns/says/gives". Em dashes unspaced (word—word). Plain words.'
const NUDGE = "You just wrote prose to a file. Re-read it now for inanimate agency (report/build/entry/declaration as subject of says/gives/owns/configures/carries), spaced em dashes, and banned vocabulary; fix in place before moving on. If this text will publish under the user's name, have a fresh-context subagent sweep it against the rules before hand-over."

// The lint tool, for a skill that has a draft to check before the reply.
const TOOL = 'mcp__writing-conventions__lint'

// Where the note on a session's last reply is kept until the next prompt: a
// file named for the session, so that a resumed session still gets it. With no
// session id there is no safe place, since a shared file would hand one
// session's note to another.
async function notePath($: any, session: unknown): Promise<string> {
  const id = String(session ?? '').replace(/[^A-Za-z0-9_-]/g, '_')
  return id && `${(await $.env.get('TMPDIR')) || '/tmp'}/claude-reply-lint-${id}.txt`
}

export const register: Register = on => {
  // The lint tool is answered here. Any other command or MCP call is checked
  // before it runs.
  on('tool.call', async ($, e, next) => {
    // A draft may come inside its fence, and lint() drops every closed fence.
    if (e.tool === TOOL) return { result: lint(drafts(String((e as any).text ?? ''), { unwrap: true })).replace(/\n+$/, '') || 'clean' }
    if (!/^(Bash$|PowerShell$|mcp__)/.test(e.tool)) return next(e)
    const { tool, tool_use_id, agentId, ...tool_input } = e as any
    const verdict = await gate($, async () => {
      const input = { session_id: await $.session.id(), cwd: await $.session.cwd(), tool_name: tool, tool_input, tool_use_id }
      return tool.startsWith('mcp__') ? mcp($, input) : shell($, input)
    })
    if (verdict.block) return { deny: verdict.block }
    const ran = await next(e)
    return verdict.context && ran.deny === undefined
      ? { ...ran, context: [...(ran.context ?? []), verdict.context] }
      : ran
  })

  on('session.start', async ($, e, next) => {
    if (await isChecked($)) {
      await $.tool.register({
        name: 'lint',
        description: 'Lint prose against the writing-conventions patterns: inanimate agency, spaced em dashes, banned words, a missing Oxford comma, and a bold list label. Returns one line per flagged sentence, <group><TAB><matched text>, or "clean".',
        inputSchema: { type: 'object', properties: { text: { type: 'string', description: 'The prose to lint.' } }, required: ['text'] },
      })
    }
    return next(e)
  })

  // The final reply is linted and the note saved. lint() drops every closed
  // fence, so the fence lines of a draft block come off first and its text stays
  // in place: a draft is prose, and this is the one check left on it when the
  // model reader cannot run. Then the gate reads the drafts, and a finding
  // blocks the stop.
  on('classic.Stop', async ($, e: any, next: any) => {
    const text = String(e.last_assistant_message ?? '')
    if (await isChecked($).catch(() => false)) {
      const note = lint(drafts(text, { unwrap: true }), { note: true })
      const path = await notePath($, e.session_id).catch(() => '')
      // A clean reply clears what the one before it left.
      if (path && (note || (await $.fs.exists(path).catch(() => false)))) await $.fs.write(path, note).catch(() => {})
    }
    const verdict = text.includes('draft') ? await gate($, () => stop($, e)) : {}
    const ran = await next(e)
    return verdict.block ? { ...ran, block: verdict.block } : ran
  })

  // The next turn opens with the saved note, then the standing reminder.
  on('classic.UserPromptSubmit', async ($, e: any, next: any) => {
    const ran = await next(e)
    if (!(await isChecked($).catch(() => false))) return ran
    const path = await notePath($, e.session_id).catch(() => '')
    const note = path ? await $.fs.read(path).catch(() => '') : ''
    if (note) await $.fs.write(path, '').catch(() => {})
    return { ...ran, additionalContext: [...(ran.additionalContext ?? []), note + REMINDER] }
  })

  // A file just written. One that holds prose, code comments included, gets the
  // nudge, and the gate's findings on a prose file come back beside it.
  on('classic.PostToolUse', async ($, e: any, next: any) => {
    if (e.tool_name !== 'Write' && e.tool_name !== 'Edit') return next(e)
    const verdict = await gate($, () => file($, e))
    const ran = await next(e)
    const isProse = /\.(md|markdown|txt|kt|kts|java|groovy)$/i.test(String(e.tool_input?.file_path ?? ''))
    const added = [...(isProse && (await isChecked($).catch(() => false)) ? [NUDGE] : []), ...(verdict.context ? [verdict.context] : [])]
    return added.length > 0 ? { ...ran, additionalContext: [...(ran.additionalContext ?? []), ...added] } : ran
  })

  // A subagent starts with the rules the session started with.
  on('classic.SubagentStart', async ($, e: any, next: any) => {
    const ran = await next(e)
    if (!(await isChecked($).catch(() => false))) return ran
    const rules = await $.fs.read(`${$.plugin.root}/hooks/rules.md`).catch(() => '')
    return rules ? { ...ran, additionalContext: [...(ran.additionalContext ?? []), rules] } : ran
  })
}
