// node --test: every regex grader in plugins/*/evals, against one text it has to
// match and one it must not. A grader that cannot fail scores every run as a pass.
import assert from 'node:assert/strict'
import { readdirSync, readFileSync } from 'node:fs'
import { basename, join } from 'node:path'
import { test } from 'node:test'

// By grader name. A regex grader with no entry here fails.
const texts = {
  'no-spaced-dash': {
    hit: ['the gate — as built', 'pages 3 –5'],
    miss: ['the gate—as built', 'pages 3–5'],
  },
  'no-banned-word': {
    hit: ['That check is load-bearing.', 'This will de-risk the release.', 'A reply is owed.'],
    miss: ['The owner allowed the loaded build.'],
  },
  'no-agency-regex': {
    hit: ['The report says the version is stale.', 'It reads a file whose name has a date.'],
    miss: ['The version is shown as stale in the report.', 'The task writes a file.'],
  },
  'no-build-gets': {
    hit: ['A build that applies the plugin still gets two copies.'],
    miss: ['Two copies of the plugin are still applied in such a build.'],
  },
  'title-block-format': {
    hit: ['Merged.\n\n**Session title:**\n\n```\n/rename Tidy hook timeouts\n```\n'],
    miss: [
      '**Session title:**\n\n```\n/rename tidy hook timeouts\n```\n',
      '**Session title:**\n\n```\n/rename Tidy hook timeouts\n```\n\nAnything else?',
    ],
  },
}

// The keys of one grader, from frontmatter or from one entry of a case.yaml list.
function keys(chunk) {
  const out = {}
  for (const [, key, value] of chunk.matchAll(/^\s*(type|pattern|flags):[ \t]*(.*)$/gm)) {
    const quoted = /^'(.*)'$/.exec(value.trim())
    out[key] = quoted ? quoted[1].replaceAll("''", "'") : value.trim()
  }
  return out
}

function graders() {
  const found = []
  for (const plugin of readdirSync('plugins')) {
    let files
    try { files = readdirSync(join('plugins', plugin, 'evals'), { recursive: true }) } catch { continue }
    for (const file of files.map(String)) {
      const path = join('plugins', plugin, 'evals', file)
      if (/[\\/]results[\\/]/.test(path)) continue
      if (/[\\/]graders[\\/][^\\/]+\.md$/.test(path)) {
        const front = readFileSync(path, 'utf8').split(/^---$/m)[1] ?? ''
        found.push({ path, name: basename(path, '.md'), ...keys(front) })
      } else if (basename(path) === 'case.yaml') {
        const list = readFileSync(path, 'utf8').split(/^graders:$/m)[1] ?? ''
        for (const chunk of list.split(/^\s*- name:[ \t]*/m).slice(1)) {
          found.push({ path, name: chunk.split('\n')[0].trim(), ...keys(chunk) })
        }
      }
    }
  }
  return found.filter((g) => g.type === 'regex')
}

const all = graders()

test('every text set is for a grader that exists', () => {
  assert.deepEqual(Object.keys(texts).filter((name) => !all.some((g) => g.name === name)), [])
})

for (const g of all) {
  test(`${g.path}: ${g.name}`, () => {
    assert.ok(texts[g.name], `no texts for the regex grader ${g.name}: add a hit and a miss above`)
    for (const hit of texts[g.name].hit) assert.match(hit, new RegExp(g.pattern, g.flags))
    for (const miss of texts[g.name].miss) assert.doesNotMatch(miss, new RegExp(g.pattern, g.flags))
  })
}
