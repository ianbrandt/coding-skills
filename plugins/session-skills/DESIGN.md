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
weigh continuing this session against handing off to a fresh one without writing the weighing out,
and end a turn that closed a unit with the outcome: a hand-off block, a line that this session goes
on, or a line on what the next item waits on. The third applies whenever something out of scope turns up: raise it in the reply, write it
into the repo's backlog where it should outlive the session, and never leave it in a host's
suggested-task feature on its own. All three apply to every session that did real work, including
the ones that never open a worktree and so never load `land-and-wrap`. That is why they are injected
by a hook, and why they ship with the plugin instead of sitting in a personal global `CLAUDE.md`.

`{{wrap-up}}` in `rules.md` is replaced with `wrap-up-desktop.md` in the desktop app and removed
elsewhere. In that app a session calls the `wrap_up` tool at the end of a turn that ran a command.
Text after a call with an `ask` is never shown, and a call without one returns "nothing is pending",
which one session took as a reason to skip the hand-off block after a unit landed. Text written
before any tool call is folded into that call's activity, and another session wrote the block before
two more calls and closed with a pointer to it, so the block now goes after the last call.

A `Stop` hook checks the turn that ran `git push`, the last turn of a landing. In a census of
October 2026 transcripts from the four owned repos, 13 of the 16 turns that pushed held work ended
with no next step, often after a landing turn that had asked for the push and deferred the hand-off
to it. When such a turn's last message has no fenced block, one stop is blocked with a request for the
next step, or for one line saying there is none. The second stop is let through, so a reply that
states there is no next step costs one extra turn. A push is recorded from the `PostToolUse` hook
for `Bash`, and a new prompt drops one left by an interrupted turn.

There is no `SubagentStart` hook, because a subagent doesn't end a session.
