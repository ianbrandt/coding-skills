// Where a repo's plan of record is, and the rule a session starts with when it
// has one. The lookup order is next-roadmap-item §1's: a local-only roadmap
// first, then the fork check, then a tracked one. A fork's tracked ROADMAP.md is
// the upstream project's.
export type Plan = { kind: 'local-only' | 'tracked'; roadmap: string; history?: string } | { kind: 'fork-without-roadmap' | 'none' }

export function planOf(found: { hasLocal: boolean; hasUpstream: boolean; tracked: string[] }): Plan {
  if (found.hasLocal) return { kind: 'local-only', roadmap: 'ROADMAP.local.md', history: 'ROADMAP-CHANGELOG.local.md' }
  if (found.hasUpstream) return { kind: 'fork-without-roadmap' }
  const roadmap = ['ROADMAP.md', 'docs/roadmap.md'].find(p => found.tracked.includes(p))
  return roadmap ? { kind: 'tracked', roadmap } : { kind: 'none' }
}

export function rule(roadmap: string, main: string): string {
  return `ROADMAP RULE ACTIVE

This repo's plan of record is \`${roadmap}\`, in the primary checkout at \`${main}\`.

A task the user states directly is handled like an item picked off the roadmap. Before the first
edit to a file that will be committed:

1. Find the task in \`${roadmap}\`. If it is not there, write it as a new item at its priority
   position: the problem in a sentence or two, and the paths it touches. A local-only roadmap is
   edited in the primary checkout. A tracked one is edited in the lane's worktree copy, and the edit
   is committed there. Take the next free \`Rn\` ID, checked against the parked, declined, and
   changelog files too, since an ID is never reused.
2. Run \`next-roadmap-item <Rn>\`. The worktree, the branch name, the claim, and the landing all
   come from there. Run it even when a task-specific skill, an upgrade or a refactor, covers the
   work: from that skill you learn what to change, not where to make the change or how it leaves
   the branch.
3. Land through \`land-and-wrap\` only. When a standing instruction authorizes merging to the
   default branch, \`land-and-wrap\` §1 is still where you find out whether this repo is a fork and
   whether its work lands as a pull request.

Size is no exemption: a one-line change that will be committed gets an item. A question answered
by reading gets none, and neither does an edit to the roadmap files themselves.`
}
