# session-skills design

How the plugin is wired, for anyone changing it. The [README](README.md) covers using it.

## Tools and session rules

One hooks module, `hooks/register.ts`, which is a Claude Code mod and needs Claude Code 2.1.286 or
later, the oldest version supported. It registers six tools, named `mcp__session-skills__<tool>`,
and the skills call them where they once had bash to adapt:

- `find_checkouts` fetches, then returns the primary checkout, the default branch, the ref a new
  branch should start from, and every worktree (`work-in-worktree` §1 and §2).
- `open_worktree` opens a worktree and branch from that ref and links the repo's local notes
  directory into it (§3).
- `prune_branches` prunes stale worktree registrations and deletes merged branches, including one a
  host squashed on merge, and never removes a worktree (§4).
- `remove_worktree` runs `git worktree remove` from the primary checkout, then deletes the
  worktree's directory where it is still on disk, as it is on Windows. A path outside
  `.claude/worktrees` is refused, and a path already unregistered is a no-op (§4, and
  `land-and-wrap` §2).
- `landing_facts` returns whether the repo is a fork, `origin`'s visibility, the landing mode, and
  the holds the user lifted (`land-and-wrap` §1).
- `edit_primary_file` edits a file that is only in the primary checkout, such as an untracked
  roadmap: one passage is replaced, or text is appended, and nothing is written when the passage
  has drifted.

In a terminal session a seventh tool, `set_session_title`, is registered, since the CLI has no tool
that sets the session title. No call in the mod API sets one either, so the title is kept until the
user's next prompt and returned there as the `sessionTitle` of a `UserPromptSubmit` hook, which
renames the session as `/rename` does. A title is dropped when the user renamed the session in
between. The tool is registered only where `CLAUDE_CODE_ENTRYPOINT` is `cli`: the desktop app has a
title tool, and a `claude -p` session has no next prompt.

`hooks/checkouts.test.ts` and `hooks/register.test.ts` run under `claude plugin test`. The
tool definitions are in every session's context, at roughly 600 tokens by estimate for the six.

At session start the module adds `hooks/rules.md` to every session, including after `/clear` and
compaction. That file has three rules that cannot go in a skill. One is the session title, given
once the subject of the session is known and again when a better one fits. How the title is set
differs by surface, so `{{title}}` in `rules.md` is replaced with one of three files, chosen by
`CLAUDE_CODE_ENTRYPOINT`: `title-desktop.md` for the desktop app's tool, `title-cli.md` for this
plugin's, and `title-print.md` anywhere else, for a `/rename` command the user pastes. A session
given all three instructions at once called the terminal's tool in the desktop app and printed the
title when the call failed. Another runs every turn:
weigh continuing this session against handing off to a fresh one, silently, and speak only when a
tell trips—the unit just landed, the session has been compacted, or the next thing is unrelated
work. The third applies whenever something out of scope turns up: raise it in the reply, write it
into the repo's backlog where it should outlive the session, and never leave it in a host's
suggested-task feature on its own. All three apply to every session that did real work, including
the ones that never open a worktree and so never load `land-and-wrap`. That is why they are injected
by a hook, and why they ship with the plugin instead of sitting in a personal global `CLAUDE.md`.
There is no `SubagentStart` hook, because a subagent doesn't end a session.
