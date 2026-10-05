// claude plugin test: the gate against a stand-in for the model and the file
// system, so what is tested is the plumbing: which events reach a model call,
// which replies block, and that a call which fails lets the event through.
import { expect, mock, test } from 'claude-code/testing'

const SAYS = 'git commit -m "The report says so."'
const FINDING = 'VIOLATION\n"The report says so." -> It is shown in the report.'
const CONFIG = '/cfg/writing-conventions'

type World = {
  // The reader's reply, the classifiers' replies, and whether the call fails.
  verdict?: string
  commands?: string
  tool?: string
  down?: boolean
  base?: string
  noSession?: boolean
  env?: Record<string, string>
  files?: Record<string, string>
  links?: string[]
}

// world(on, w): answers everything the gate asks of the engine, and records the
// model calls by the prompt file each was made with, the files written, and the
// toasts. A test calls it once, before its first event, and changes `w`
// afterwards for a different reply.
function world(on: any, w: World = {}) {
  const base = w.base ?? '2.1.289'
  const files: Record<string, string> = { ...w.files }
  const seen = { reader: [] as string[], commands: [] as string[], tool: [] as string[], system: '', toasts: [] as string[], files, ran: 0 }
  mock.env(on, { CLAUDE_CONFIG_DIR: '/cfg', TMPDIR: '/tmp', ...w.env })
  on('session.version', () => ({ value: { version: base, base, builtAt: '' } }))
  on('session.id', () => { if (w.noSession) throw new Error('no session'); return { value: 's1' } })
  on('session.cwd', () => ({ value: '/proj' }))
  on('session.root', () => ({ value: '/proj' }))
  on('ui.toast', (_$: any, e: any) => { seen.toasts.push(JSON.stringify(e)); return { value: undefined } })
  on('fs.read', (_$: any, e: any) => {
    // A prompt file of the plugin's is answered with its name.
    if (/\/hooks\/[a-z-]+\.md$/.test(e.path)) return { value: `<${e.path.split('/').pop()}>` }
    if (!(e.path in files)) throw new Error('ENOENT')
    return { value: files[e.path] }
  })
  on('fs.write', (_$: any, e: any) => { files[e.path] = e.text; return { value: undefined } })
  on('fs.stat', (_$: any, e: any) => {
    if (!(e.path in files) && !['/proj', '/tmp', '/elsewhere'].includes(e.path)) throw new Error('ENOENT')
    const isFile = e.path in files
    return { value: { kind: isFile ? 'file' : 'dir', size: isFile ? files[e.path].length : 0, mtimeMs: 0, isLink: !!w.links?.includes(e.path), realPath: e.path } }
  })
  on('model.complete', (_$: any, e: any) => {
    seen.system = e.system
    const [list, reply] = e.system.includes('<classify-command.md>') ? [seen.commands, w.commands]
      : e.system.includes('<classify-prompt.md>') ? [seen.tool, w.tool]
      : [seen.reader, w.verdict]
    list.push(e.prompt)
    return { value: w.down || reply === undefined ? { isAnswered: false, reason: 'api-error', status: 529, usage: {} } : { isAnswered: true, text: reply, usage: {} } }
  })
  on('tool.call', () => { seen.ran++; return { result: { stdout: 'ran' } } })
  on('classic.PostToolUse', () => ({ additionalContext: ['from a settings hook'] }))
  on('classic.Stop', () => ({}))
  return seen
}

const bash = ($: any, command: string) => $.tool.call({ tool: 'Bash', command, tool_use_id: 'toolu_1' })
const cacheOf = (seen: { files: Record<string, string> }, name: string) =>
  Object.entries(seen.files).filter(([p]) => p.startsWith(`${CONFIG}/${name}-`)).map(([, text]) => text).join('')

test('the four publishing families reach the reader, git -C included', async ($: any, on: any) => {
  const seen = world(on, { verdict: 'PASS' })
  for (const c of ['git commit -m "Plain message"', 'git -C /tmp/wt commit -m "Plain message"', 'gh pr create --title x --body y', 'gh issue comment 1 --body y', 'gh release create v1 --notes y']) {
    expect((await bash($, c)).result).toEqual({ stdout: 'ran' })
  }
  expect(seen.reader).toHaveLength(5)
  expect(seen.commands).toHaveLength(0)
  expect(seen.system).toBe('<gate-prompt.md><rules.md>')
  expect(JSON.parse(seen.reader[0])).toMatchObject({ session_id: 's1', cwd: '/proj', tool_name: 'Bash', tool_input: { command: 'git commit -m "Plain message"' } })
})

test('a finding that quotes the command blocks it, and comes back as the reason', async ($: any, on: any) => {
  const seen = world(on, { verdict: FINDING })
  const ran = await bash($, SAYS)
  expect(ran.deny).toBeDefined()
  expect(ran.deny).toContain('shown in the report')
  expect(ran.deny).toContain('run the command again')
  expect(seen.ran).toBe(0)
})

test('a reply in any other form lets the command through', async ($: any, on: any) => {
  const w: World = {}
  world(on, w)
  for (const verdict of [
    'VIOLATION\n"The build wants more" -> invented',
    'VIOLATION MAYBE\n"The report says so." -> x',
    'VIOLATION\nthe report says so, rewrite it',
    'VIOLATION',
    'VIOLATION\n"" -> x',
    'the report says: rewrite it',
    'CLEAN',
    'SKIP',
    '',
  ]) {
    w.verdict = verdict
    expect((await bash($, SAYS)).result).toEqual({ stdout: 'ran' })
  }
})

test('a gate that cannot reach a model does not stop a commit, and says so once', async ($: any, on: any) => {
  const seen = world(on, { down: true })
  expect((await bash($, SAYS)).result).toEqual({ stdout: 'ran' })
  expect((await bash($, SAYS)).result).toEqual({ stdout: 'ran' })
  expect(seen.reader).toHaveLength(2)
  expect(seen.toasts).toHaveLength(1)
  expect(seen.toasts[0]).toContain('model review is off')
})

test('a check that cannot read the session lets the command through, and says so', async ($: any, on: any) => {
  const seen = world(on, { verdict: FINDING, noSession: true })
  expect((await bash($, SAYS)).result).toEqual({ stdout: 'ran' })
  expect(seen.toasts.join()).toContain('model review is off')
})

test('a CLI older than the one the module was checked on makes no call, and says so', async ($: any, on: any) => {
  const seen = world(on, { verdict: FINDING, base: '2.1.288' })
  expect((await bash($, SAYS)).result).toEqual({ stdout: 'ran' })
  expect(seen.reader).toHaveLength(0)
  expect(seen.toasts.join()).toContain('2.1.289')
})

test('a cold key costs one classifier call, and its answer is kept', async ($: any, on: any) => {
  const seen = world(on, { commands: 'ls\tNEVER' })
  await bash($, 'ls -la')
  await bash($, 'ls -la')
  expect(seen.commands).toEqual(['ls -la\n\nls'])
  expect(seen.reader).toHaveLength(0)
  expect(cacheOf(seen, 'shell-commands')).toBe('*\tNEVER\tls\n')
  expect(seen.ran).toBe(2)
})

test('a publishing command no name was written for reaches the reader', async ($: any, on: any) => {
  const seen = world(on, { commands: 'hg\tDESCEND\nhg commit\tCAN_PUBLISH', verdict: 'VIOLATION\n"The report says so." -> x' })
  const ran = await bash($, 'hg commit -m "The report says so."')
  expect(ran.deny).toBeDefined()
  // Each answered key is kept, as a task name in the project's scope as well.
  expect(cacheOf(seen, 'shell-commands')).toBe('*\tDESCEND\thg\n*\tCAN_PUBLISH\thg commit\n/proj\tCAN_PUBLISH\thg commit\n')
  // Below a cached DESCEND, only the subcommand is asked about.
  await bash($, 'hg status')
  expect(seen.commands[1]).toBe('hg status\n\nhg status')
})

test('a classifier reply in any other form is doubt: the reader runs and nothing is kept', async ($: any, on: any) => {
  const seen = world(on, { commands: 'I think ls is fine', verdict: 'PASS' })
  await bash($, 'ls -la')
  expect(seen.reader).toHaveLength(1)
  expect(cacheOf(seen, 'shell-commands')).toBe('')
})

test('a classifier that cannot run lets the command through', async ($: any, on: any) => {
  const down = world(on, { down: true })
  expect((await bash($, 'ls -la')).result).toEqual({ stdout: 'ran' })
  expect(down.commands).toHaveLength(1)
  expect(down.toasts).toHaveLength(1)
})

test('the off switch returns the trigger to the four families', async ($: any, on: any) => {
  const off = world(on, { env: { WRITING_CONVENTIONS_SHELL_CLASSIFIER: '0' }, verdict: 'PASS' })
  await bash($, 'hg commit -m x')
  await bash($, 'git commit -m x')
  expect(off.commands).toHaveLength(0)
  expect(off.reader).toHaveLength(1)
})

test('a finding in text that only goes into a local file comes back as context', async ($: any, on: any) => {
  const local = 'LOCAL\n"The report says so." -> x'
  const seen = world(on, { commands: 'sed\tCAN_PUBLISH', verdict: local })
  const ran = await bash($, 'sed -i "s/x/The report says so./" notes.md')
  expect(ran.result).toEqual({ stdout: 'ran' })
  expect(ran.context.join()).toContain('The report says so.')
  expect(ran.context.join()).toContain('after the command runs')
  // The four families block on LOCAL as on VIOLATION.
  expect((await bash($, SAYS)).deny).toBeDefined()
  expect(seen.ran).toBe(1)
})

test('a body passed by path is read, sent after the input, and may be quoted', async ($: any, on: any) => {
  const seen = world(on, { verdict: FINDING, files: { '/proj/body.md': 'The report says so.\n' } })
  const ran = await bash($, 'gh pr create --title x --body-file body.md')
  expect(seen.reader[0]).toContain('\n\nFile: body.md\n\nThe report says so.\n')
  expect(ran.deny).toBeDefined()
})

test('a body file that is not read is listed with the reason', async ($: any, on: any) => {
  const files = { '/proj/body.md': 'Plain.', '/proj/link.md': 'Plain.', '/elsewhere/body.md': 'Plain.', '/proj/big.md': 'x'.repeat(1048577), '/proj/bin.md': 'a\0b' }
  const seen = world(on, { verdict: 'PASS', files, links: ['/proj/link.md'] })
  for (const [command, why] of [
    ['echo text > body.md && gh pr create -F body.md', 'the command names it more than once'],
    ['cd sub && gh pr create -F body.md', 'the command may change directory first'],
    ['gh pr create -F "$BODY"', 'it is not a literal path'],
    ['gh pr create -F missing.md', 'it is not a regular file'],
    ['gh pr create -F link.md', 'it is not a regular file'],
    ['gh pr create -F /elsewhere/body.md', 'it is outside the project and the temporary directory'],
    ['gh pr create -F big.md', 'it is over 1 MB'],
    ['gh pr create -F bin.md', 'it is not text'],
  ]) {
    const ran = await bash($, command)
    expect(ran.context.join()).toContain(`was not read: ${why}`)
    expect(seen.reader.pop()).not.toContain('File:')
  }
})

const notion = ($: any, input: Record<string, unknown>) => $.tool.call({ tool: 'mcp__notion__create_page', tool_use_id: 'toolu_2', ...input })

test('an MCP tool is classified once, and a publishing call is read', async ($: any, on: any) => {
  const seen = world(on, { tool: 'CAN_PUBLISH', verdict: FINDING })
  const ran = await notion($, { title: 'x', body: { text: 'The report says so.' } })
  expect(ran.deny).toBeDefined()
  expect(ran.deny).toContain('make the call again')
  await notion($, { title: 'Plain' })
  expect(seen.tool).toHaveLength(1)
  expect(seen.reader).toHaveLength(2)
  expect(cacheOf(seen, 'mcp-tools')).toBe('mcp__notion__create_page CAN_PUBLISH\n')
})

test('only the string values of an MCP input are reviewed, each on its own', async ($: any, on: any) => {
  // A key, and a sentence split across two values, are in no source.
  const w: World = { tool: 'CAN_PUBLISH', verdict: 'VIOLATION\n"The report" -> x' }
  world(on, w)
  expect((await notion($, { 'The report': 'x' })).result).toEqual({ stdout: 'ran' })
  w.verdict = FINDING
  expect((await notion($, { nodes: [{ text: 'The report' }, { text: 'says so.' }] })).result).toEqual({ stdout: 'ran' })
  w.verdict = 'VIOLATION\n"The report" + "says so." -> x'
  expect((await notion($, { nodes: [{ text: 'The report' }, { text: 'says so.' }] })).deny).toBeDefined()
})

test('a tool classified NEVER makes no reader call, then or later', async ($: any, on: any) => {
  const never = world(on, { tool: 'NEVER', verdict: FINDING })
  await notion($, { text: 'The report says so.' })
  await notion($, { text: 'The report says so.' })
  expect(never.tool).toHaveLength(1)
  expect(never.reader).toHaveLength(0)
})

test('in the cache a CAN_PUBLISH line wins over a NEVER line, and a malformed line is ignored', async ($: any, on: any) => {
  const seen = world(on, { tool: 'NEVER', verdict: 'PASS' })
  await notion($, { text: 'x' })
  const path = Object.keys(seen.files).find(p => p.includes('/mcp-tools-'))!
  seen.files[path] += 'mcp__notion__create_page CAN_PUBLISH extra\nmcp__notion__create_page CAN_PUBLISH\n'
  await notion($, { text: 'x' })
  expect(seen.tool).toHaveLength(1)
  expect(seen.reader).toHaveLength(1)
})

test('a cache saved with CRLF line ends is read the same', async ($: any, on: any) => {
  const seen = world(on, { tool: 'NEVER', verdict: 'PASS' })
  await notion($, { text: 'x' })
  const path = Object.keys(seen.files).find(p => p.includes('/mcp-tools-'))!
  seen.files[path] = 'mcp__notion__create_page NEVER\r\nmcp__notion__create_page CAN_PUBLISH\r\n'
  await notion($, { text: 'x' })
  expect(seen.tool).toHaveLength(1)
  expect(seen.reader).toHaveLength(1)
})

test('a tool classifier reply in any other form is doubt: the reader runs and nothing is kept', async ($: any, on: any) => {
  const doubt = world(on, { tool: 'It might publish.', verdict: 'PASS' })
  await notion($, { text: 'x' })
  expect(doubt.reader).toHaveLength(1)
  expect(cacheOf(doubt, 'mcp-tools')).toBe('')
})

test('a tool classifier reply that opens on a bare carriage return is doubt', async ($: any, on: any) => {
  const w: World = { verdict: FINDING }
  const seen = world(on, w)
  for (const tool of ['\r\nNEVER\r', '\f\nNEVER']) {
    w.tool = tool
    expect((await notion($, { text: 'The report says so.' })).deny).toBeDefined()
  }
  expect(cacheOf(seen, 'mcp-tools')).toBe('')
  // A blank first line is skipped.
  w.tool = '\n \t\nNEVER'
  expect((await notion($, { text: 'The report says so.' })).result).toEqual({ stdout: 'ran' })
})

test('the plugin\'s own lint tool is not gated', async ($: any, on: any) => {
  const seen = world(on, { tool: 'CAN_PUBLISH', verdict: FINDING })
  await $.tool.call({ tool: 'mcp__writing-conventions__lint', text: 'The report says so.' })
  expect(seen.tool).toHaveLength(0)
})

const write = (path: string, content: string) => ({ tool_name: 'Write', tool_input: { file_path: path, content }, tool_response: {}, tool_use_id: 'toolu_3' })
const edit = (path: string, fresh: string) => ({ tool_name: 'Edit', tool_input: { file_path: path, old_string: 'x', new_string: fresh }, tool_response: {}, tool_use_id: 'toolu_4' })
const gateNote = (ran: any) => ran.additionalContext.filter((c: string) => !c.startsWith('You just wrote prose') && c !== 'from a settings hook').join('\n')

test('findings on a prose file come back as context, and nothing is blocked', async ($: any, on: any) => {
  const seen = world(on, { verdict: FINDING })
  const ran = await $.classic.PostToolUse(write('/proj/a.md', 'The report says so.'))
  expect(ran.block).toBeUndefined()
  expect(ran.additionalContext[0]).toBe('from a settings hook')
  expect(gateNote(ran)).toContain('Fix the quoted text in /proj/a.md.')
  expect(seen.reader).toEqual(['File: /proj/a.md\n\nThe report says so.'])
})

test('a file that is not prose, and a tool that writes none, make no call', async ($: any, on: any) => {
  const seen = world(on, { verdict: FINDING })
  await $.classic.PostToolUse(write('/proj/a.kt', '// The report says so.'))
  await $.classic.PostToolUse({ tool_name: 'Read', tool_input: { file_path: '/proj/a.md' }, tool_response: {}, tool_use_id: 'toolu_5' })
  expect(seen.reader).toHaveLength(0)
})

test('an edit is reviewed as the paragraphs that hold it', async ($: any, on: any) => {
  const text = 'First one.\n\nThe report says so. It is short.\n\nThird one.\n'
  const seen = world(on, { verdict: FINDING, files: { '/proj/a.md': text } })
  const ran = await $.classic.PostToolUse(edit('/proj/a.md', 'says'))
  expect(seen.reader[0]).toContain('It is short.')
  expect(seen.reader[0]).not.toContain('Third one')
  expect(gateNote(ran)).toContain('The report says so.')
})

test('what is not reviewed in an edit is stated', async ($: any, on: any) => {
  const seen = world(on, { verdict: 'PASS', files: { '/proj/big.md': 'x'.repeat(1048577) } })
  expect(gateNote(await $.classic.PostToolUse(edit('/proj/a.md', '  ')))).toBe('Not reviewed: this edit to /proj/a.md only deleted text.')
  expect(seen.reader).toHaveLength(0)
  expect(gateNote(await $.classic.PostToolUse(edit('/proj/big.md', 'Plain.')))).toContain('Only the new text was reviewed')
  expect(gateNote(await $.classic.PostToolUse(write('/proj/a.md', 'word '.repeat(10001))))).toBe('Only the first 50000 characters of the text were reviewed.')
  expect(seen.reader[1]).toHaveLength('File: /proj/a.md\n\n'.length + 50000)
})

const F = '```'
const reply = (prompt_id: string | undefined, text: string) => ({ prompt_id, last_assistant_message: text.replace(/~/g, F) })

test('only the text in a draft fence is read, and a reply without one costs no call', async ($: any, on: any) => {
  const seen = world(on, { verdict: FINDING })
  expect((await $.classic.Stop(reply('p1', 'The report says so.'))).block).toBeUndefined()
  expect((await $.classic.Stop(reply('p1', 'A draft:\n~sh\nThe report says so.\n~'))).block).toBeUndefined()
  expect(seen.reader).toHaveLength(0)
  const ran = await $.classic.Stop(reply('p1', 'Outside text.\n~draft\nThe report says so.\n~\nMore outside.'))
  expect(ran.block).toContain('emit the corrected draft')
  expect(seen.reader[0]).toBe('The report says so.\n\n\n')
})

test('a finding that quotes text outside every draft fence does not block', async ($: any, on: any) => {
  world(on, { verdict: FINDING })
  expect((await $.classic.Stop(reply('p2', 'The report says so.\n~draft\nPlain text.\n~'))).block).toBeUndefined()
  // Two drafts are two sources: one quote cannot span both.
  expect((await $.classic.Stop(reply('p2', '~draft\nThe report\n~\n~draft\nsays so.\n~'))).block).toBeUndefined()
})

test('a reply is blocked twice in a turn, then the user is told and it stands', async ($: any, on: any) => {
  const seen = world(on, { verdict: FINDING })
  const draft = reply('p3', '~draft\nThe report says so.\n~')
  expect((await $.classic.Stop(draft)).block).toBeDefined()
  expect((await $.classic.Stop(draft)).block).toBeDefined()
  expect((await $.classic.Stop(draft)).block).toBeUndefined()
  expect(seen.toasts.join()).toContain('Review is unresolved')
  // The count is per turn, so the next turn starts over.
  expect((await $.classic.Stop({ ...draft, prompt_id: 'p4' })).block).toBeDefined()
})

test('the count of one turn\'s blocks outlasts a Stop of another turn', async ($: any, on: any) => {
  world(on, { verdict: FINDING })
  const draft = (prompt_id: string) => reply(prompt_id, '~draft\nThe report says so.\n~')
  expect((await $.classic.Stop(draft('p7'))).block).toBeDefined()
  expect((await $.classic.Stop(draft('p7'))).block).toBeDefined()
  expect((await $.classic.Stop(draft('p8'))).block).toBeDefined()
  expect((await $.classic.Stop(draft('p7'))).block).toBeUndefined()
})

const DRAFT = '~draft\nThe report says so.\n~'

test('nothing is blocked without a prompt_id, or with the reader down', async ($: any, on: any) => {
  const w: World = { verdict: FINDING }
  const seen = world(on, w)
  expect((await $.classic.Stop(reply(undefined, DRAFT))).block).toBeUndefined()
  expect(seen.reader).toHaveLength(0)
  w.down = true
  expect((await $.classic.Stop(reply('p6', DRAFT))).block).toBeUndefined()
  expect(seen.toasts.join()).toContain('model review is off')
})

test('the off switch for the draft reader makes no call', async ($: any, on: any) => {
  const off = world(on, { verdict: FINDING, env: { WRITING_CONVENTIONS_STOP_READER: '0' } })
  expect((await $.classic.Stop(reply('p5', DRAFT))).block).toBeUndefined()
  expect(off.reader).toHaveLength(0)
})
