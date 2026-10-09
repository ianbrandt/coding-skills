// One edit to a file's text: `old` replaced by `next` where it occurs exactly
// once, or `next` appended when `old` is empty. A passage that has drifted
// throws, so an edit is never reported as made when nothing changed. An `old`
// with LF line ends that is in the file only with CRLF is matched there. `next`
// is then written with CRLF, as it is for an `old` of one line or none in a
// file where every line end is CRLF. Any other edit is made as given.
export function splice(text: string, old: string, next: string): string {
  const crlf = text.includes('\r\n') && !old.includes('\r') && (old.includes('\n') ? !text.includes(old) : !/(^|[^\r])\n/.test(text))
  if (crlf) {
    old = old.replace(/\n/g, '\r\n')
    next = next.replace(/\r?\n/g, '\r\n')
  }
  if (old === '') return text + next
  const count = text.split(old).length - 1
  if (count !== 1) throw new Error(`the passage occurs ${count} times, not once`)
  const at = text.indexOf(old)
  return text.slice(0, at) + next + text.slice(at + old.length)
}
