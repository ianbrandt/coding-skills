// The claim ledger's rules, apart from the files and git: what a claim is, the
// name of its file, and which claims are dead.
export type Claim = { item: string; branch: string; started: string; session: string; touches: string[] }
export type Entry = { name: string; text: string; mtimeMs: number }

// The file is named for the branch, with `/` as `-`: a branch is checked out in
// one worktree at most, and two worktrees can share a directory name.
export const fileOf = (branch: string) => `${branch.replace(/\//g, '-')}.json`

export function parse(text: string): Claim | null {
  try {
    const c = JSON.parse(text)
    return c && typeof c.branch === 'string' && c.branch ? c : null
  } catch {
    return null
  }
}

// A claim is dead when no worktree has its branch checked out. Merge state is
// not the test: a branch just claimed has the default branch's tip. A file that
// does not parse may be a claim another session is writing now, so it is dead
// only once it is a minute old.
export function dead(entries: Entry[], live: string[], now: number): Entry[] {
  return entries.filter(e => {
    const c = parse(e.text)
    return c ? !live.includes(c.branch) : now - e.mtimeMs > 60_000
  })
}

export const ownedBy = (entries: Entry[], session: string): Entry[] =>
  session ? entries.filter(e => parse(e.text)?.session === session) : []
