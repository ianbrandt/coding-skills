# To do

- Needs a machine where `claude plugin eval` can grant Bash (on this Mac the Docker Desktop links in
  `~/.docker` break the sandbox): two live-git `session-skills` eval cases, a repo-root path in
  context still lands the edit in the worktree, and a stale local default branch still branches
  from `origin/<default>`.

## Needs a Windows machine

None of this has run on Windows. The checks are for `writing-conventions`, `session-skills`,
`parallel-session-skills`, `orchestration-skills`, and `ghostwriting-skills`, installed from this
marketplace, with a current Git for Windows and Claude Code.

Run on 2026-10-09 against a scratch repo at `C:\Dev\Repos\IanBrandt\coding-skills test\repo`
(Windows 11 Enterprise, Git for Windows ucrt64, Claude Code with session-skills + writing-
conventions installed; `parallel-session-skills` not installed in that harness). Current-shell
coverage per check is noted inline. Still outstanding: a Windows PowerShell 5.1 pass for the
checks where it is called out (4 and 10), a Git Bash pass of Check 7 (`edit_primary_file` from a
worktree session), the claim portion of Check 3 plus all of Check 8 once
`parallel-session-skills` is installed, and Checks 9, 11, 12, 13 which have not run yet.
Findings from the pass are in the Findings section at the bottom.

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
   - PASS (PowerShell 7.6.6): junction confirmed by `cmd /c dir /AL`, worktree status clean, `git
     worktree remove` exit 0, `notes.local\keep.txt` still in the primary. Minor: `git worktree
     remove` leaves the worktree directory on disk with the junction intact (unregistered from
     `git worktree list` but the folder is still there). The keep.txt loss failure mode is
     avoided; `cmd /c rmdir <worktree>` may still be needed in a cleanup helper afterward.
2. `/dev/null` as a git argument from a process with no shell. With a merged branch and a branch
   whose upstream is gone, have the session call `prune_branches`. Pass: `deleted:` or `kept:`
   lines, and no `warning:` line that the empty tree could not be read. By hand, `git hash-object -t
   tree /dev/null` prints `4b825dc642cb6eb9a060e54bf8d69288fbee4904`.
   - PASS (PowerShell 7.6.6): `prune_branches` returned two `deleted:` lines, no `warning:`. By
     hand, `git hash-object -t tree /dev/null` prints the empty-tree hash as expected.
3. One whole lane. `find_checkouts`, `open_worktree`, `write_claim`, `read_ledger`, an edit and a
   commit in the worktree, the merge steps of `land-and-wrap` with the push held, `release_claim`,
   and `prune_branches`. Pass: no tool returns an error, the work is on the default branch, the
   claims directory is empty, the worktree and its branch are gone, and a shell command after the
   removal still runs. Note whether `session directory` and `primary checkout` in the result of
   `find_checkouts` differ in slashes or in the case of the drive letter.
   - PARTIAL PASS (PowerShell 7.6.6): `find_checkouts`, `open_worktree`, edit, commit, `git merge
     --ff-only` with push held, `git worktree remove`, `prune_branches` all exit 0. Work is on
     `main`, branch and worktree directory are gone, shell commands after removal still run.
     `write_claim`/`read_ledger`/`release_claim` tools are not installed in this harness
     (`parallel-session-skills` plugin absent), so the claim portion is not run. Slash/case: in
     `find_checkouts` output, `primary checkout` uses backslashes (`C:\Dev\...\repo`) and
     `session directory` uses forward slashes (`C:/Dev/.../repo`); drive letter is uppercase in
     both.
4. Removing a worktree, 5.1. `cd <primary>; git worktree remove <worktree>` has to be two calls
   there, since `&&` is a parse error. Pass: the worktree is gone and the next call runs in the
   primary checkout. If a `cd` in one call does not hold in the next, the two-call form in
   `land-and-wrap` and `work-in-worktree` is wrong and needs another one. Also run the removal while
   a second shell sits inside the worktree: it fails, and passes once that shell is closed.
   - SKIPPED: needs Windows PowerShell 5.1; this session is PowerShell 7.6.6 and Git Bash.
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
   - PARTIAL FAIL (Git Bash and PowerShell 7.6.6): the gate ran, quoted the spaced em dash in
     its context note, and did not block in any variant. On this scratch repo origin is a bare
     local path (`..\origin.git`), so the model's classifier marked the commit as `LOCAL` and
     `gate.ts` returned soft `context` instead of `block` (line 260). Body-read coverage:
     - Git Bash, `-F body.md`: body read, no `was not read` line. Soft context. Commit went through.
     - Git Bash, Windows-form quoted path with spaces: hook note says
       `The body in "" was not read: it is not a literal path.` The quoted backslashes collapsed
       in `bash` before the gate saw them (expected per the TODO). Commit went through.
     - Git Bash, msys path (`/c/.../repo/body.md`) with spaces: body read, no `was not read` line.
       Soft context. Commit went through.
     - Git Bash, `-F /tmp/b.md` after `cp ... /tmp/b.md`: `The body in /tmp/b.md was not read: the
       command names it more than once, so it may write the file before reading it.` Not the
       outside-project path flag. `$TEMP` in the shell is `C:\Dev\Temp` (no 8.3 shortening).
     - PowerShell, `-F body.md`: body read, no `was not read`. Soft context.
     - PowerShell, `-F "C:\...\body.md"` (quoted absolute, spaces): body read, no `was not read`
       line, because PowerShell preserves the quoted path. It is NOT listed as `not a literal
       path` in PowerShell. The TODO's expectation of a `not a literal path` listing in both
       shells does not hold in PowerShell 7.
   The gate's prohibition detection works. The blocking-vs-soft split is driven by LOCAL
   classification, which is sensible on a strictly local origin. For the TODO's "commit is
   blocked" criterion, the commit is blocked only when the remote is public (or with a
   `WRITING_CONVENTIONS_SHELL_CLASSIFIER=0` override).
6. Files the gate must not read. `git commit --allow-empty -F` with each of
   `/tmp/../../../Windows/win.ini`, a `body.md` in a sibling directory named `repo-other`, and
   `//server/share/body.md`. Pass: each is listed as `was not read`.
   - PASS (PowerShell 7.6.6): all three got `was not read` lines, with reasons:
     - `/tmp/../../../Windows/win.ini`: `outside the project and the temporary directory`.
     - `..\repo-other\body.md`: `the command may change directory first` (prior `Set-Location`
       in the script).
     - `//server/share/body.md`: `the command names it more than once, so it may write the file
       before reading it` (the UNC path got doubled in the canonical form). Git itself refused the
       UNC path with `Function not implemented`, so no commit landed there.
   Note: on 6a and 6b the commit still landed because git itself read the file; the gate's
   `was not read` only means the gate's reviewer did not see the body, not that git did not.
7. `edit_primary_file`, from a session in a worktree. With the primary checkout's path typed in
   lower case and a one-line addition to a scratch file: `edited`. With `core.autocrlf=true` and a
   tracked file that has CRLF line ends, replace two lines with a passage written with LF, then
   append a line. Pass: `edited` both times, and `git diff` shows only those lines, with no `^M`
   and no whole-file change. With a path under `<primary>-other`: refused.
   - PASS (PowerShell 7.6.6, session cwd inside worktree):
     - Lower-case path (`c:\dev\...\scratch.txt`): returned `edited`, the second line landed in the
       primary.
     - `core.autocrlf=true` on `crlf.txt`: both calls returned `edited`, the hex of the file still
       has CRLF (`0D 0A`) on every line, and `git diff` shows only the two replaced lines and the
       appended line, no `^M` markers, no whole-file change.
     - `<primary>-other\body.md`: refused with
       `edit_primary_file: ... is not inside the primary checkout ...`.
8. Claims. Call `write_claim` and `release_claim` with the worktree path in lower case, then with
   backslashes only. Pass: all four succeed. Then, with two sessions in the repo, have one call
   `read_ledger` twenty times while the other writes and releases a claim twenty times. Pass: no
   `was not deleted` line, and no claim reported as unreadable.
   - SKIPPED: `parallel-session-skills` is not installed in this harness, so
     `write_claim`/`release_claim`/`read_ledger` tools are absent from the tool list.
9. Stray processes. `Get-CimInstance Win32_Process | Where-Object CommandLine -like '*git*' |
   Select-Object ProcessId, CommandLine` lists a running git with its command line.
   - NOT RUN YET.
10. Applying a subagent's diff, 5.1. In a worktree, change a line that has a non-ASCII character
    and a file with CRLF line ends. `git -C <worktree> diff --output=<absolute patch path>`, then
    `git apply <absolute patch path>` in the primary checkout. Pass: both exit 0, and `git diff`
    there equals the worktree's.
    - PASS (PowerShell 7.6.6 as a best-effort; 5.1 run still needed): worktree change was
      `beta` → `beta-café` on a CRLF-ended `crlf.txt`. `git diff --output` exit 0, `git apply` in
      the primary exit 0. Primary's post-apply hex shows CRLF (`0D 0A`) and UTF-8 `é` (`C3 A9`).
      `git diff` in the primary equals the worktree's byte-for-byte.
11. Home directory. In each shell, `node -e "console.log(process.env.HOME,
    process.env.USERPROFILE)"`. Pass: `HOME` is empty or is `USERPROFILE` in Windows form, not
    `/c/Users/<name>`. For `ghostwriting-skills`, `cmd /c mklink /J
    %USERPROFILE%\.claude\ghostwriting <directory>` from a shell that is not elevated, then load the
    `ghostwrite` skill. Pass: the voice spec is found.
    - NOT RUN YET.
12. Long paths. In the deepest repo in real use, `git config --show-origin core.longpaths`, then
    open a worktree and run `git status` and a build in it. Pass: no `Filename too long`.
    - NOT RUN YET.
13. The two `writing-conventions` "gate off" toasts: unset a required env var, or let a model call
    fail, and confirm each fits in four lines in the Claude Code UI. Toast 1 is 95 chars; toast 2
    is 149 chars.
    - NOT RUN YET.

## Findings from the Windows pass

- `git worktree remove` leaves the worktree directory on disk with the junction intact. The
  directory is unregistered from `git worktree list` and `keep.txt` survives, so the state is
  safe but not tidy. Likely fix: run `cmd /c rmdir <worktree>` after the git remove, in the
  teardown of `open_worktree` or in `land-and-wrap`.
- When origin is a local bare repo, the shell classifier returns `LOCAL`, so the
  writing-conventions gate falls to soft `context` instead of blocking. Check 5 was written for
  a public remote. Fix: give the scratch setup a non-local origin, or document the local-origin
  behavior next to Check 5.
- In PowerShell 7 a quoted absolute path with spaces reaches the gate intact, so it is not
  listed as `not a literal path`. The expectation in Check 5 of that listing "in both shells"
  does not hold on PowerShell 7.
