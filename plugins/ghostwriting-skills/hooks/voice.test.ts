// claude plugin test: voice.ts against a stand-in file system.
import { expect, test } from 'claude-code/testing'

const SPEC = '/v/voice-spec.md'
const CACHE = '/home/.claude/plugins/cache'

// files <path to text>: answers the reads, and lists a directory from the paths
// under it. `env` answers $.env.get.
function files(on: any, texts: Record<string, string>, env: Record<string, string> = {}) {
  on('env.get', (_$: any, e: any) => ({ value: { HOME: '/home', GHOSTWRITING_DIR: '/v', ...env }[e.name as string] }))
  on('fs.read', (_$: any, e: any) => (e.path in texts ? { value: texts[e.path] } : { deny: 'no such file' }))
  on('fs.list', (_$: any, e: any) => {
    const names = new Set<string>()
    for (const path of Object.keys(texts)) {
      if (path.startsWith(e.path + '/')) names.add(path.slice(e.path.length + 1).split('/')[0])
    }
    if (names.size === 0) return { deny: 'no such directory' }
    return { value: [...names].map(name => ({ name, kind: Object.keys(texts).includes(`${e.path}/${name}`) ? 'file' : 'dir', size: 1, mtimeMs: 0, isLink: false })) }
  })
  on('skill.prompt', (_$: any, e: any) => ({ text: e.text }))
}

test('the spec, every sample, and the newest rules file follow the skill text', async ($: any, on: any) => {
  files(on, {
    [SPEC]: 'SPEC TEXT',
    '/v/corpus/issues.md': 'ISSUE SAMPLE',
    '/v/corpus/pr-bodies.md': 'PR SAMPLE',
    '/v/corpus/notes.bin': 'NOT A SAMPLE',
    [`${CACHE}/m/writing-conventions/0.9.0/hooks/rules.md`]: 'OLD RULES',
    [`${CACHE}/m/writing-conventions/0.44.0/hooks/rules.md`]: 'NEW RULES',
  })
  const { text } = await $.skill.prompt({ skill: 'ghostwriting-skills:ghostwrite', text: 'SKILL' })
  expect(text.startsWith('SKILL\n')).toBe(true)
  for (const part of ['VOICE=/v\n', 'SPEC TEXT', 'ISSUE SAMPLE', 'PR SAMPLE', 'NEW RULES']) expect(text).toContain(part)
  for (const part of ['NOT A SAMPLE', 'OLD RULES']) expect(text).not.toContain(part)
})

test('with no spec the skill is sent to its bootstrap section', async ($: any, on: any) => {
  files(on, { '/v/corpus/issues.md': 'ISSUE SAMPLE' })
  const { text } = await $.skill.prompt({ skill: 'ghostwrite', text: 'SKILL' })
  expect(text).toContain('MODE=bootstrap')
  expect(text).not.toContain('ISSUE SAMPLE')
})

test('a corpus over the cap is listed by name for the model to read', async ($: any, on: any) => {
  files(on, { [SPEC]: 'SPEC TEXT', '/v/corpus/a.md': 'x'.repeat(40000), '/v/corpus/b.md': 'y'.repeat(40000) })
  const { text } = await $.skill.prompt({ skill: 'ghostwrite', text: 'SKILL' })
  expect(text).toContain('`/v/corpus/a.md`, `/v/corpus/b.md`')
  expect(text).not.toContain('xxxx')
})

test('without GHOSTWRITING_DIR the default directory is read', async ($: any, on: any) => {
  files(on, { '/home/.claude/ghostwriting/voice-spec.md': 'HOME SPEC' }, { GHOSTWRITING_DIR: '' })
  const { text } = await $.skill.prompt({ skill: 'ghostwrite', text: 'SKILL' })
  expect(text).toContain('HOME SPEC')
})

test('another skill gets its text unchanged', async ($: any, on: any) => {
  files(on, { [SPEC]: 'SPEC TEXT' })
  const { text } = await $.skill.prompt({ skill: 'ghostwriting-skills:share-ghostwriting-spec', text: 'SKILL' })
  expect(text).toBe('SKILL')
})
