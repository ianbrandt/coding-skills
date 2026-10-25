// The headings an issue may keep: the field labels of the target repo's issue
// forms and the headings of its Markdown issue templates, as GitHub lays them
// out in a new issue. Each heading with one of them as its text is removed from
// what the review model is sent, so that item 5 of gate-prompt.md flags every
// other heading.

// A heading line, or the first line of a body quoted in a shell command.
const HEADING = /(^|["'])#{1,6}[ \t]+([^\n]*?)[ \t]*\r?$\n?/gm

// labels(files): the label of every field in the issue forms among `files`,
// and every heading in the Markdown templates. A checkbox option's label is a
// list item, `- label:`, and is not matched.
export function labels(files: { name: string; text: string }[]): string[] {
  const out: string[] = []
  for (const { name, text } of files) {
    const t = text.replace(/\r/g, '')
    if (/\.ya?ml$/i.test(name)) {
      for (const m of t.matchAll(/^[ \t]+label:[ \t]*(.*?)[ \t]*$/gm)) out.push(m[1].replace(/^(["'])(.*)\1$/, '$2'))
    } else if (/\.md$/i.test(name)) {
      for (const m of t.replace(/^---\n[\s\S]*?\n---\n/, '').matchAll(HEADING)) out.push(m[2])
    }
  }
  return out.filter(l => l !== '')
}

// unheaded(text, allowed): the text with each heading whose text is in
// `allowed` removed, along with its line end.
export function unheaded(text: string, allowed: Set<string>): string {
  return allowed.size === 0 ? text : text.replace(HEADING, (line, quote, label) => (allowed.has(label) ? quote : line))
}

// The repos linked in a text, by their github.com URLs, at most three.
export function linked(text: string): string[] {
  const found = [...text.matchAll(/github\.com\/([\w-]+\/[\w.-]+)/g)].map(m => m[1].replace(/\.git$|\.+$/, ''))
  return [...new Set(found)].slice(0, 3)
}

// The repo given to a gh command with --repo or -R.
export function repoFlag(cmd: string): string | undefined {
  return /(?:^|\s)(?:--repo|-R)(?:=|\s+)["']?(?:https?:\/\/)?(?:github\.com\/)?([\w-]+\/[\w.-]+?)(?:\.git)?(?=["'\s/]|$)/.exec(cmd)?.[1]
}

const QUERY = 'query($owner:String!,$name:String!){repository(owner:$owner,name:$name){object(expression:"HEAD:.github/ISSUE_TEMPLATE"){... on Tree{entries{name object{... on Blob{text}}}}}}}'

// Each repo's templates and each directory's repo are read with gh once a
// session. A failed read is tried again at the next check, and meanwhile the
// repo has no templates.
const templates = new Map<string, Promise<string[]>>()
const defaults = new Map<string, Promise<string>>()

function once<T>(cache: Map<string, Promise<T>>, key: string, read: () => Promise<T>, none: T): Promise<T> {
  if (!cache.has(key)) cache.set(key, read().catch(() => { cache.delete(key); return none }))
  return cache.get(key)!
}

async function gh($: any, cwd: string, argv: string[]): Promise<string> {
  const ran = await $.process.run(['gh', ...argv], { cwd, timeoutMs: 5000 })
  if (ran.exitCode !== 0) throw new Error(ran.stderr)
  return ran.stdout
}

function labelsOf($: any, cwd: string, repo: string): Promise<string[]> {
  const [owner, name] = repo.split('/')
  return once(templates, repo, async () => {
    const out = await gh($, cwd, ['api', 'graphql', '-f', `query=${QUERY}`, '-f', `owner=${owner}`, '-f', `name=${name}`])
    return labels((JSON.parse(out).data?.repository?.object?.entries ?? []).map((e: any) => ({ name: String(e.name), text: String(e.object?.text ?? '') })))
  }, [])
}

// headings($, cwd, texts, repos): the headings allowed in an issue to `repos`,
// or to the repo gh picks in `cwd` when `repos` is empty. Where no text has a
// heading, gh is not run.
export async function headings($: any, cwd: string, texts: string[], repos: string[]): Promise<Set<string>> {
  if (!texts.some(t => new RegExp(HEADING.source, 'm').test(t))) return new Set()
  if (repos.length === 0) {
    const here = await once(defaults, cwd, async () => (await gh($, cwd, ['repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner'])).trim(), '')
    repos = here ? [here] : []
  }
  return new Set((await Promise.all(repos.map(r => labelsOf($, cwd, r)))).flat())
}
