# To do

- Needs a machine where `claude plugin eval` can grant Bash (on this Mac the Docker Desktop links in
  `~/.docker` break the sandbox): two live-git `session-skills` eval cases, a repo-root path in
  context still lands the edit in the worktree, and a stale local default branch still branches
  from `origin/<default>`.

## Needs a Windows machine

The four checks of the 2026-10-09 re-run all cleared and are no longer listed. One is left, on
`session-skills` 0.21.1 or later.

1. The worktree directory deleted after a removal. In a scratch repo at a path with a space in it,
   with one commit, a `notes.local` directory with a file `keep.txt` in it, and `/notes.local` in
   `.git/info/exclude`: have the session call `open_worktree`, then ask it to remove that worktree,
   once in a Git Bash session and once in a PowerShell 7 session. Pass: the session deletes the
   leftover directory unasked, the directory is gone, and `notes.local\keep.txt` in the primary
   checkout is still there. Record the commands as the tool calls had them.
