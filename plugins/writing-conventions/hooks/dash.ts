// Spaced em dashes taken out of a reply as it streams, so the text on screen and
// the text in the transcript are both `word—word`. A `session.append` hook would
// fix only the stored reply: the screen shows the streamed text first.
//
// What is left alone is what lint.awk leaves alone: a fenced block, inline code,
// and text in straight or curly double quotes. A `draft` fence is the exception,
// since its text is for publication. Where a line leaves it unclear whether a
// span is closed, the text is left as written, and the reply lint still reports it.
import type { Register } from 'claude-code'

// One text block's position: the text held back while the next piece could
// change it, whether the next character starts a line, the open fence and whether it
// is a `draft` fence, the length of an open backtick run, the open quote, and
// whether the last character written was a dash in prose.
export type Dash = { held: string; lineStart: boolean; fence: string; draft: boolean; code: number; quote: string; afterDash: boolean }

export function start(): Dash {
  return { held: '', lineStart: true, fence: '', draft: false, code: 0, quote: '', afterDash: false }
}

// The run of `chars` at `i`, as its end, or -1 when the text ends inside it and
// more may follow.
function run(text: string, i: number, chars: string, end: boolean): number {
  let j = i
  while (j < text.length && chars.includes(text[j])) j++
  return j === text.length && !end ? -1 : j
}

// feed(state, piece): the text to show for this piece. With `end`, nothing more
// follows and everything held is written.
export function feed(s: Dash, piece: string, end = false): string {
  const text = s.held + piece
  let out = ''
  let i = 0
  s.held = ''
  while (i < text.length) {
    if (s.lineStart) {
      // A fence marker is three or more backticks or tildes after any indent. The
      // whole line is needed to read an opening fence's info string.
      const indent = run(text, i, ' \t', end)
      const marker = indent < 0 ? -1 : run(text, indent, text[indent] === '~' ? '~' : '`', end)
      if (marker < 0) break
      if (marker - indent >= 3) {
        const newline = text.indexOf('\n', marker)
        if (newline < 0 && !end) break
        const stop = newline < 0 ? text.length : newline + 1
        const m = text.slice(indent, marker)
        if (s.fence === '') {
          s.fence = m
          s.draft = text.slice(marker, stop).trim() === 'draft'
        } else if (m[0] === s.fence[0] && m.length >= s.fence.length) {
          s.fence = ''
        }
        out += text.slice(i, stop)
        i = stop
        continue
      }
      s.lineStart = false
      s.code = 0
      s.quote = ''
      s.afterDash = false
    }
    const c = text[i]
    if (c === '\n') {
      s.lineStart = true
      out += c
      i++
    } else if (s.fence !== '' && !s.draft) {
      out += c
      i++
    } else if (c === '`') {
      const j = run(text, i, '`', end)
      if (j < 0) break
      if (s.quote === '') s.code = s.code === 0 ? j - i : s.code === j - i ? 0 : s.code
      s.afterDash = false
      out += text.slice(i, j)
      i = j
    } else if (s.code !== 0) {
      out += c
      i++
    } else if (c === '"' || c === '“' || c === '”') {
      if (s.quote === '') s.quote = c === '”' ? '' : c
      else if ((s.quote === '"' && c === '"') || (s.quote === '“' && c === '”')) s.quote = ''
      s.afterDash = false
      out += c
      i++
    } else if (s.quote !== '') {
      out += c
      i++
    } else if (c === ' ' || c === '\t') {
      const j = run(text, i, ' \t', end)
      if (j < 0) break
      if (!s.afterDash && text[j] !== '—') out += text.slice(i, j)
      i = j
    } else {
      s.afterDash = c === '—'
      out += c
      i++
    }
  }
  s.held = text.slice(i)
  return out
}

export const register: Register = on => {
  on('turn.step', async function* ($, e, next) {
    const blocks = new Map<number, Dash>()
    const stream = next(e)[Symbol.asyncIterator]()
    for (;;) {
      const step = await stream.next()
      const chunk: any = step.done ? undefined : step.value
      if (chunk?.kind === 'text') {
        if (!blocks.has(chunk.index)) blocks.set(chunk.index, start())
        yield { ...chunk, text: feed(blocks.get(chunk.index)!, chunk.text) }
        continue
      }
      // Anything else can end a block, so what is held is written ahead of it.
      // The block's position is kept, in case more of it follows.
      for (const [index, s] of blocks) {
        const text = feed(s, '', true)
        if (text !== '') yield { kind: 'text', index, text }
      }
      if (step.done) return step.value
      yield chunk
    }
  })
}
