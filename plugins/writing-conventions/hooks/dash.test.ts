// claude plugin test: the dash rewrite in dash.ts, whole and in pieces.
import { expect, test } from 'claude-code/testing'
import { feed, start } from './dash'

const F = '```'
// [reply, the reply as shown]
const CASES: [string, string][] = [
  ['This is one thing — and another.', 'This is one thing—and another.'],
  ['Tight already—no change here.', 'Tight already—no change here.'],
  ['Tab\t—\tboth sides, and one side— here and —there.', 'Tab—both sides, and one side—here and—there.'],
  ['Run `a — b` and then go — now.', 'Run `a — b` and then go—now.'],
  ['He said "wait — what" and left — quickly.', 'He said "wait — what" and left—quickly.'],
  ['She wrote “one — two” and then — three.', 'She wrote “one — two” and then—three.'],
  ['Double ``a ` — b`` ticks — here.', 'Double ``a ` — b`` ticks—here.'],
  [`Before — fence.\n${F}sh\necho a — b\n${F}\nAfter — fence.`, `Before—fence.\n${F}sh\necho a — b\n${F}\nAfter—fence.`],
  [`  ~~~\n  x — y\n  ~~~~\nOut — side.`, `  ~~~\n  x — y\n  ~~~~\nOut—side.`],
  [`${F}draft\nFix it — now, as \`a — b\` shows.\n${F}\n`, `${F}draft\nFix it—now, as \`a — b\` shows.\n${F}\n`],
  [`${F}${F}draft\nOne — two.\n${F}sh\nx — y\n${F}\n${F}${F}`, `${F}${F}draft\nOne—two.\n${F}sh\nx—y\n${F}\n${F}${F}`],
  ['A quote left "open — to the end\nNext — line.', 'A quote left "open — to the end\nNext—line.'],
  ['Trailing spaces stay.  \n  Indent stays — mostly.', 'Trailing spaces stay.  \n  Indent stays—mostly.'],
  [`Ends on a fence — ok.\n${F}\ncode\n${F}`, `Ends on a fence—ok.\n${F}\ncode\n${F}`],
  ['Ends on spaces — and a dash —', 'Ends on spaces—and a dash—'],
]

function whole(text: string): string {
  const s = start()
  return feed(s, text) + feed(s, '', true)
}

test('a spaced em dash is closed up outside code, quotes, and fences', () => {
  for (const [reply, shown] of CASES) expect(whole(reply)).toBe(shown)
})

test('the result is the same however the reply is cut into pieces', () => {
  let seed = 86
  const next = (n: number) => (seed = (seed * 1103515245 + 12345) % 2147483648) % n
  for (const [reply, shown] of CASES) {
    for (let size = 1; size <= 4; size++) {
      for (let round = 0; round < 25; round++) {
        const s = start()
        let out = ''
        for (let i = 0; i < reply.length; ) {
          const n = round === 0 ? size : 1 + next(7)
          out += feed(s, reply.slice(i, i + n))
          i += n
        }
        expect(out + feed(s, '', true)).toBe(shown)
      }
    }
  }
})

test('text is held only while the next piece could change it', () => {
  const s = start()
  expect(feed(s, 'One thing')).toBe('One thing')
  expect(feed(s, ' ')).toBe('')
  expect(feed(s, 'more ')).toBe(' more')
  expect(feed(s, '— done.')).toBe('—done.')
})
