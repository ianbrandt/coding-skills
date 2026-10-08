// claude plugin test: the deletion of a landed item, and the tool that runs it.
import { expect, test } from 'claude-code/testing'
import { deleteItem } from './item'

const ROADMAP = `# Roadmap

## R10: other

body

## R102: landed

Quotes \`s.index('## Order and dependencies')\` mid-line and R103.

### R102.1: sub

x

## R103: later one

a

## Order and dependencies

R102 first.
`

test('an item is deleted up to the next heading of its level, with its sub-items', () => {
  const { text, removed } = deleteItem(ROADMAP, 'R102')
  expect(removed).toEqual(['## R102: landed', '### R102.1: sub'])
  expect(text).toBe(ROADMAP.replace(/## R102: landed[\s\S]*?(?=## R103)/, ''))
})

test('an ID that is the start of another ID matches only its own item', () => {
  expect(deleteItem(ROADMAP, 'R10').removed).toEqual(['## R10: other'])
  expect(deleteItem(ROADMAP, 'R102.1').removed).toEqual(['### R102.1: sub'])
})

test('the last section is deleted to the end of the file', () => {
  const { text, removed } = deleteItem(ROADMAP, 'Order')
  expect(removed).toEqual(['## Order and dependencies'])
  expect(text.endsWith('a\n\n')).toBe(true)
})

test('an ID with no heading, or with two, is refused', () => {
  expect(() => deleteItem(ROADMAP, 'R999')).toThrow('R999: 0 headings')
  expect(() => deleteItem(ROADMAP + '\n## R10: again\n', 'R10')).toThrow('R10: 2 headings')
})

test('a heading inside a fenced block does not end the item', () => {
  const F = '```'
  const s = `## R1: one\n\n${F}md\n## R2: quoted\n${F}\n\ntail\n\n## R3: three\n`
  expect(deleteItem(s, 'R1')).toEqual({ text: '## R3: three\n', removed: ['## R1: one'] })
})

const TOOL = 'mcp__roadmap-skills__delete_item'

test('the tool rewrites the file and returns the headings removed', async ($: any, on: any) => {
  const files: Record<string, string> = { '/repo/ROADMAP.local.md': ROADMAP }
  on('fs.read', (_$: any, e: any) => ({ value: files[e.path] }))
  on('fs.write', (_$: any, e: any) => { files[e.path] = e.text; return { value: undefined } })
  const ran = await $.tool.call({ tool: TOOL, path: '/repo/ROADMAP.local.md', id: 'R102' })
  expect(ran.result).toBe('removed:\n## R102: landed\n### R102.1: sub')
  expect(files['/repo/ROADMAP.local.md']).toBe(deleteItem(ROADMAP, 'R102').text)
})

test('the tool writes nothing when the ID is refused', async ($: any, on: any) => {
  let wrote = false
  on('fs.read', () => ({ value: ROADMAP }))
  on('fs.write', () => { wrote = true; return { value: undefined } })
  const ran = await $.tool.call({ tool: TOOL, path: '/repo/ROADMAP.local.md', id: 'R999' })
  expect(ran.isError).toBe(true)
  expect(ran.text).toContain('R999: 0 headings')
  expect(wrote).toBe(false)
})
