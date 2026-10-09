# To do

- Needs a machine where `claude plugin eval` can grant Bash (on this Mac the Docker Desktop links in
  `~/.docker` break the sandbox): two live-git `session-skills` eval cases, a repo-root path in
  context still lands the edit in the worktree, and a stale local default branch still branches
  from `origin/<default>`.

## Needs a Windows machine

The thirteen checks of the first Windows pass were run on 2026-10-09 and are no longer listed. These
are left. Setup for each: a scratch repo at a path with a space in it, with one commit, a bare repo
beside it as `origin`, a `notes.local` directory with a file `keep.txt` in it, and `/notes.local` in
`.git/info/exclude`.

1. What `git worktree remove` leaves behind. Have the session call `open_worktree`, then from the
   primary checkout run `git worktree remove <worktree>`, once in PowerShell 7 and once in Git Bash.
   Record for each: the exit code, whether `<worktree>` still exists, and whether `notes.local` is
   still inside it as a junction (`cmd /c dir /AL <worktree>`). In the first pass the directory was
   reported left on disk in one check and gone in another.
2. A recursive delete and a junction, in scratch directories only, never in a worktree. Make
   `target` with a file `keep.txt` in it and an empty `left`, then `cmd /c mklink /J left\link
   target`. Delete `left` with `rm -rf left` in Git Bash, and after making it again, with
   `Remove-Item -Recurse -Force left` in PowerShell 7 and in Windows PowerShell 5.1. Record for
   each whether `target\keep.txt` is still there.
3. The writing gate blocking a commit. With a spaced em dash in `body.md`, have the session run
   `git commit --allow-empty -F body.md` as the whole command, with no `cd`, no `git -c`, and no
   wrapper, in Git Bash and in PowerShell 7. Pass: the commit is blocked. In the first pass the
   gate quoted the dash and the commit went through. If it goes through again, record the
   command exactly as the tool call has it, and the gate's whole note.
4. The voice directory through a junction. Start Claude Code with `GHOSTWRITING_DIR` unset and no
   `voice_dir` option, make `cmd /c mklink /J %USERPROFILE%\.claude\ghostwriting <directory>`
   from a shell that is not elevated, and load the `ghostwrite` skill. Pass: the voice spec is
   found.
