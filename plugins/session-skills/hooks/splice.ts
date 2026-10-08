// One edit to a file's text: `old` replaced by `next` where it occurs exactly
// once, or `next` appended when `old` is empty. A passage that has drifted
// throws, so an edit is never reported as made when nothing changed.
export function splice(text: string, old: string, next: string): string {
  if (old === '') return text + next
  const count = text.split(old).length - 1
  if (count !== 1) throw new Error(`the passage occurs ${count} times, not once`)
  const at = text.indexOf(old)
  return text.slice(0, at) + next + text.slice(at + old.length)
}
