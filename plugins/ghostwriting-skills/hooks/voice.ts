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

// The newest installed copy of the writing-conventions rules, or none.
async function rules($: any, config: string): Promise<string> {
  const cache = `${config}/plugins/cache`
  let best = ''
  let bestKey: number[] = []
  for (const market of await $.fs.list(cache).catch(() => [])) {
    for (const version of await $.fs.list(`${cache}/${market.name}/writing-conventions`).catch(() => [])) {
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
  const home = (await $.env.get('HOME')) ?? ''
  const dir = configured || (await $.env.get('GHOSTWRITING_DIR')) || `${home}/.claude/ghostwriting`
  const head = '\n\n---\n\n## Voice data, loaded by the plugin\n\n'
  let spec: string
  try {
    spec = await $.fs.read(`${dir}/voice-spec.md`)
  } catch {
    return `${head}MODE=bootstrap: there is no \`${dir}/voice-spec.md\`. Go to §5.\n`
  }
  let out = `${head}The plugin read these files whole as this skill loaded. They are §0's snippet and §1's reads, already done: do not run the snippet, and do not read these files again. If the request points at voice data somewhere else, read it there instead and ignore what follows.\n\nVOICE=${dir}\n\n${file(`${dir}/voice-spec.md`, spec)}`
  const names = (await $.fs.list(`${dir}/corpus`).catch(() => []))
    .filter((e: any) => e.kind !== 'dir' && /\.(md|markdown|txt)$/i.test(e.name))
    .map((e: any) => e.name)
    .sort()
  const samples: string[] = []
  for (const name of names) {
    try {
      samples.push(file(`${dir}/corpus/${name}`, await $.fs.read(`${dir}/corpus/${name}`)))
    } catch {
      // A sample that cannot be read is left for the model to report.
    }
  }
  if (names.length === 0) out += 'There is no corpus: draft on the spec alone and record the gap in §4.\n'
  else if (samples.join('').length <= CORPUS_CAP) out += `\nThe corpus, every sample:\n\n${samples.join('\n')}`
  else out += `\nThe corpus is too large to append. Read two or three of these that match the genre, each whole: ${names.map((n: string) => `\`${dir}/corpus/${n}\``).join(', ')}\n`
  const path = await rules($, (await $.env.get('CLAUDE_CONFIG_DIR')) || `${home}/.claude`)
  try {
    if (path !== '') out += `\nThe always-on rules file, re-read for §1:\n\n${file(path, await $.fs.read(path))}`
  } catch {
    // No rules file: the prohibitions are then in the spec, per §0.
  }
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
