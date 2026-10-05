// The voice data, appended to the `ghostwrite` skill's text as the skill loads,
// so the spec, the samples, and the always-on rules are in front of the model
// whole. Left to the model, the reads were a locate snippet and three or more
// file reads, any of which could be skipped or cut short.
import type { Register } from 'claude-code'

// ponytail: every sample is appended up to this many characters of corpus, and
// past it only the file names are, for the model to pick by genre. Pick by genre
// here if a corpus that large turns up.
const CORPUS_CAP = 64000

function file(path: string, text: string): string {
  return `<file path="${path}">\n${text}\n</file>\n`
}

// Whether version `a` is later than `b`, part by part as numbers.
function later(a: number[], b: number[]): boolean {
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if ((a[i] ?? 0) !== (b[i] ?? 0)) return (a[i] ?? 0) > (b[i] ?? 0)
  }
  return false
}

// The newest installed copy of the writing-conventions rules, or none. An entry
// that is not named for a version, such as a .DS_Store, is passed over.
// ponytail: the newest copy in the cache, which is not always the one this
// session loaded (a --plugin-dir run, a pinned version). Read the installed
// plugins record if that turns out to matter.
async function rules($: any, config: string): Promise<string> {
  const cache = `${config}/plugins/cache`
  let best = ''
  let bestKey: number[] = []
  for (const market of await $.fs.list(cache).catch(() => [])) {
    for (const version of await $.fs.list(`${cache}/${market.name}/writing-conventions`).catch(() => [])) {
      if (!/^\d+(\.\d+)*$/.test(version.name)) continue
      const key = version.name.split('.').map(Number)
      if (best === '' || later(key, bestKey)) {
        best = `${cache}/${market.name}/writing-conventions/${version.name}/hooks/rules.md`
        bestKey = key
      }
    }
  }
  return best
}

async function voice($: any, configured: string | undefined): Promise<string> {
  const home = (await $.env.get('HOME')) || (await $.env.get('USERPROFILE')) || ''
  const dir = configured || (await $.env.get('GHOSTWRITING_DIR')) || `${home}/.claude/ghostwriting`
  const head = '\n\n---\n\n## Voice data, loaded by the plugin\n\n'
  let spec: string
  try {
    spec = await $.fs.read(`${dir}/voice-spec.md`)
  } catch {
    // Only a spec that is not there is a bootstrap, which ends in writing a new
    // one. After any other failure nothing is appended, and the skill's own
    // snippet runs.
    if (await $.fs.exists(`${dir}/voice-spec.md`).catch(() => true)) return ''
    return `${head}MODE=bootstrap: there is no \`${dir}/voice-spec.md\`. Go to §5.\n`
  }
  let out = `${head}The plugin read these files whole as this skill loaded. They are §0's snippet and §1's reads, already done: do not run the snippet, and do not read these files again. If the request points at voice data somewhere else, read it there instead and ignore what follows.\n\nVOICE=${dir}\n\n${file(`${dir}/voice-spec.md`, spec)}`
  const entries = (await $.fs.list(`${dir}/corpus`).catch(() => []))
    .filter((e: any) => e.kind !== 'dir' && /\.(md|markdown|txt)$/i.test(e.name))
    .sort((a: any, b: any) => (a.name < b.name ? -1 : 1))
  const names: string[] = entries.map((e: any) => e.name)
  const listed = (which: string[]) => which.map(n => `\`${dir}/corpus/${n}\``).join(', ')
  // A character is at most four bytes, so a corpus over four times the cap on
  // disk is over it, and none of it is read.
  let over = entries.reduce((sum: number, e: any) => sum + (e.size ?? 0), 0) > CORPUS_CAP * 4
  const samples: string[] = []
  const unread: string[] = []
  for (const name of over ? [] : names) {
    try {
      samples.push(file(`${dir}/corpus/${name}`, await $.fs.read(`${dir}/corpus/${name}`)))
    } catch {
      unread.push(name)
    }
  }
  over ||= samples.join('').length > CORPUS_CAP
  if (names.length === 0) out += 'There is no corpus: draft on the spec alone and record the gap in §4.\n'
  else if (over) out += `\nThe corpus is too large to append. Read two or three of these that match the genre, each whole: ${listed(names)}\n`
  else {
    out += `\nThe corpus, ${unread.length === 0 ? 'every sample' : 'the samples the plugin could read'}:\n\n${samples.join('\n')}`
    if (unread.length > 0) out += `\nThe plugin could not read ${listed(unread)}. Read each of those yourself, whole, and say so in the hand-over if that fails too.\n`
  }
  const path = await rules($, (await $.env.get('CLAUDE_CONFIG_DIR')) || `${home}/.claude`)
  const found = path === '' ? undefined : await $.fs.read(path).catch(() => undefined)
  if (found !== undefined) out += `\nThe always-on rules file, re-read for §1:\n\n${file(path, found)}`
  else out += '\nThe plugin did not find the always-on rules file. Re-read the one §0 names yourself, for §1.\n'
  return out
}

export const register: Register = (on, options) => {
  on('skill.prompt', async ($, e, next) => {
    const prompt = await next(e)
    if (e.skill !== 'ghostwrite' && !e.skill.endsWith(':ghostwrite')) return prompt
    try {
      return { ...prompt, text: prompt.text + (await voice($, (options as any)?.voice_dir)) }
    } catch {
      return prompt
    }
  })
}
