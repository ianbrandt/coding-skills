// Spaced em dashes taken out of a reply as it streams, so the text on screen and
// the text in the transcript are both `word—word`. A `session.append` hook would
// fix only the stored reply: the screen shows the streamed text first.
//
// What is left alone is what lint.awk leaves alone: a fenced block, inline code,
// and text in straight or curly double quotes. A `draft` fence is the exception,
// since its text is for publication, though a fence inside it is left alone. A
// dash with no letter before it on its line is left alone too: after a list or
// heading marker the spaces are markdown. Where a line leaves it unclear whether
// a span is closed, the text is left as written, and the reply lint still
// reports it.
import type { Register } from 'claude-code'

// One text block's position: the text held back while the next piece could
// change it, whether the next character starts a line, the open fence, whether it
// is a `draft` fence, the fence open inside a draft, the length of an open
// backtick run, the open quote, whether the line has had a letter, a code span,
// or a quote, and whether the last character written was a dash that was closed
// up. `off` passes the rest of the block through as written.
export type Dash = { held: string; lineStart: boolean; fence: string; draft: boolean; inner: string; code: number; quote: string; word: boolean; afterDash: boolean; off: boolean }

export function start(): Dash {
  return { held: '', lineStart: true, fence: '', draft: false, inner: '', code: 0, quote: '', word: false, afterDash: false, off: false }
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
        // A marker closes a fence of its own character that is no longer than it,
        // with nothing after it on the line. Inside a draft any other marker line
        // opens a fence of its own.
        const m = text.slice(indent, marker)
        const rest = text.slice(marker, stop).trim()
        const closes = (open: string) => m[0] === open[0] && m.length >= open.length && rest === ''
        if (s.fence === '') {
          s.fence = m
          s.draft = rest === 'draft'
          s.inner = ''
        } else if (s.inner !== '') {
          if (closes(s.inner)) s.inner = ''
        } else if (closes(s.fence)) {
          s.fence = ''
        } else if (s.draft) {
          s.inner = m
        }
        out += text.slice(i, stop)
        i = stop
        continue
      }
      s.lineStart = false
      s.code = 0
      s.quote = ''
      s.word = false
      s.afterDash = false
    }
    const c = text[i]
    if (c === '\n') {
      s.lineStart = true
      out += c
      i++
    } else if (s.fence !== '' && (!s.draft || s.inner !== '')) {
      out += c
      i++
    } else if (c === '`') {
      const j = run(text, i, '`', end)
      if (j < 0) break
      s.code = s.code === 0 ? j - i : s.code === j - i ? 0 : s.code
      s.word = true
      s.afterDash = false
      out += text.slice(i, j)
      i = j
    } else if (s.code !== 0) {
      out += c
      i++
    } else if (c === '"' || c === '“' || c === '”') {
      if (s.quote === '') s.quote = c === '”' ? '' : c
      else if ((s.quote === '"' && c === '"') || (s.quote === '“' && c === '”')) s.quote = ''
      s.word = true
      s.afterDash = false
      out += c
      i++
    } else if (s.quote !== '') {
      out += c
      i++
    } else if (c === ' ' || c === '\t') {
      const j = run(text, i, ' \t', end)
      if (j < 0) break
      // Spaces go when a dash that is closed up is on either side of them. Before a
      // line break they stay, since two of them there are a markdown line break.
      const before = text[j] === '—' && s.word
      const after = s.afterDash && j < text.length && text[j] !== '\n' && text[j] !== '\r'
      if (!before && !after) out += text.slice(i, j)
      i = j
    } else {
      s.afterDash = c === '—' && s.word
      if (/\p{L}/u.test(c)) s.word = true
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
      let step: IteratorResult<any, any>
      let failed: unknown
      try {
        step = await stream.next()
      } catch (error) {
        step = { done: true, value: undefined }
        failed = error ?? new Error('turn.step failed')
      }
      const chunk: any = step.done ? undefined : step.value
      if (chunk?.kind === 'text') {
        if (!blocks.has(chunk.index)) blocks.set(chunk.index, start())
        const s = blocks.get(chunk.index)!
        yield s.off ? chunk : { ...chunk, text: feed(s, chunk.text) }
        continue
      }
      // Anything else can end a block, so what is held is written ahead of it. In
      // a long reply nothing else arrived inside a block, so text for a block
      // after this is a retry or a cut the position cannot be trusted across, and
      // it is passed through as written.
      for (const [index, s] of blocks) {
        const text = s.off ? '' : feed(s, '', true)
        s.off = true
        if (text !== '') yield { kind: 'text', index, text }
      }
      if (failed) throw failed
      if (step.done) return step.value
      yield chunk
    }
  })
}
