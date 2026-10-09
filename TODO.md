# To do

- Needs a machine where `claude plugin eval` can grant Bash (on this Mac the Docker Desktop links in
  `~/.docker` break the sandbox): two live-git `session-skills` eval cases, a repo-root path in
  context still lands the edit in the worktree, and a stale local default branch still branches
  from `origin/<default>`.

## Needs a Windows machine

None of this has run on Windows. The checks are for `writing-conventions`, `session-skills`,
`parallel-session-skills`, `orchestration-skills`, and `ghostwriting-skills`, installed from this
marketplace, with a current Git for Windows and Claude Code.

Setup: a scratch repo at a path with a space in it, such as `C:\Users\<name>\win check\repo`, with
one commit, a bare repo beside it as `origin`, a `notes.local` directory with a file `keep.txt` in
it, and `/notes.local` in `.git/info/exclude`. Run each check in a session whose shell is Git Bash
(the Bash tool) and again in PowerShell 7. A check marked 5.1 also runs in Windows PowerShell 5.1.
Check 1 comes first: it is the only one where a failure loses files.

1. The notes junction and worktree removal. Have the session call `open_worktree`. `cmd /c dir /AL
   <worktree>` lists `notes.local` as `<JUNCTION>` to the primary checkout's `notes.local`, and
   `git -C <worktree> status --porcelain -uall` has no `notes.local` line. Then, from the primary
   checkout, `git worktree remove <worktree>`. Pass: `notes.local\keep.txt` is still in the primary
   checkout. If it is gone, stop: no session should remove a worktree on Windows until
   `open_worktree` or the removal step is changed. `cmd /c rmdir <worktree>\notes.local` before the
   removal is the likely fix.
2. `/dev/null` as a git argument from a process with no shell. With a merged branch and a branch
   whose upstream is gone, have the session call `prune_branches`. Pass: `deleted:` or `kept:`
   lines, and no `warning:` line that the empty tree could not be read. By hand, `git hash-object -t
   tree /dev/null` prints `4b825dc642cb6eb9a060e54bf8d69288fbee4904`.
3. One whole lane. `find_checkouts`, `open_worktree`, `write_claim`, `read_ledger`, an edit and a
   commit in the worktree, the merge steps of `land-and-wrap` with the push held, `release_claim`,
   and `prune_branches`. Pass: no tool returns an error, the work is on the default branch, the
   claims directory is empty, the worktree and its branch are gone, and a shell command after the
   removal still runs. Note whether `session directory` and `primary checkout` in the result of
   `find_checkouts` differ in slashes or in the case of the drive letter.
4. Removing a worktree, 5.1. `cd <primary>; git worktree remove <worktree>` has to be two calls
   there, since `&&` is a parse error. Pass: the worktree is gone and the next call runs in the
   primary checkout. If a `cd` in one call does not hold in the next, the two-call form in
   `land-and-wrap` and `work-in-worktree` is wrong and needs another one. Also run the removal while
   a second shell sits inside the worktree: it fails, and passes once that shell is closed.
5. The writing gate and a body passed by file, in Git Bash. With a rule violation in `body.md` (a
   spaced em dash will do), have the session run each of these. Pass for each: the commit is
   blocked, and the gate's note has no `was not read` line.
   - `git commit --allow-empty -F body.md`
   - `git commit --allow-empty -F 'C:\Users\<name>\win check\repo\body.md'`
   - `git commit --allow-empty -F "/c/Users/<name>/win check/repo/body.md"`
   - `git commit --allow-empty -F /tmp/b.md`, with the body copied to `/tmp/b.md` in Git Bash. If
     this one is listed as outside the project and the temporary directory, compare `echo $TEMP` in
     Git Bash with `TEMP` in the Claude Code process: one may be an 8.3 short name.
   Then the same four in PowerShell with Windows paths. A quoted absolute path with a space in it
   is expected to be listed as `not a literal path` in both shells: record whether it is.
6. Files the gate must not read. `git commit --allow-empty -F` with each of
   `/tmp/../../../Windows/win.ini`, a `body.md` in a sibling directory named `repo-other`, and
   `//server/share/body.md`. Pass: each is listed as `was not read`.
7. `edit_primary_file`, from a session in a worktree. With the primary checkout's path typed in
   lower case and a one-line addition to a scratch file: `edited`. With `core.autocrlf=true` and a
   tracked file that has CRLF line ends, replace two lines with a passage written with LF, then
   append a line. Pass: `edited` both times, and `git diff` shows only those lines, with no `^M`
   and no whole-file change. With a path under `<primary>-other`: refused.
8. Claims. Call `write_claim` and `release_claim` with the worktree path in lower case, then with
   backslashes only. Pass: all four succeed. Then, with two sessions in the repo, have one call
   `read_ledger` twenty times while the other writes and releases a claim twenty times. Pass: no
   `was not deleted` line, and no claim reported as unreadable.
9. Stray processes. `Get-CimInstance Win32_Process | Where-Object CommandLine -like '*git*' |
   Select-Object ProcessId, CommandLine` lists a running git with its command line.
10. Applying a subagent's diff, 5.1. In a worktree, change a line that has a non-ASCII character
    and a file with CRLF line ends. `git -C <worktree> diff --output=<absolute patch path>`, then
    `git apply <absolute patch path>` in the primary checkout. Pass: both exit 0, and `git diff`
    there equals the worktree's.
11. Home directory. In each shell, `node -e "console.log(process.env.HOME,
    process.env.USERPROFILE)"`. Pass: `HOME` is empty or is `USERPROFILE` in Windows form, not
    `/c/Users/<name>`. For `ghostwriting-skills`, `cmd /c mklink /J
    %USERPROFILE%\.claude\ghostwriting <directory>` from a shell that is not elevated, then load the
    `ghostwrite` skill. Pass: the voice spec is found.
12. Long paths. In the deepest repo in real use, `git config --show-origin core.longpaths`, then
    open a worktree and run `git status` and a build in it. Pass: no `Filename too long`.
13. The two `writing-conventions` "gate off" toasts: unset a required env var, or let a model call
    fail, and confirm each fits in four lines in the Claude Code UI. Toast 1 is 95 chars; toast 2
    is 149 chars.
