# To do

- Needs a machine where `claude plugin eval` can grant Bash (on this Mac the Docker Desktop links in
  `~/.docker` break the sandbox): two live-git `session-skills` eval cases, a repo-root path in
  context still lands the edit in the worktree, and a stale local default branch still branches
  from `origin/<default>`.

## Needs a Windows machine

Checks 1, 2, 3, and 4 of the first Windows pass were re-run on 2026-10-09. Checks 1, 2, and 4 are
cleared and no longer listed; Check 3 is left. Setup for each: a scratch repo at a path with a
space in it, with one commit, a bare repo beside it as `origin`, a `notes.local` directory with
a file `keep.txt` in it, and `/notes.local` in `.git/info/exclude`.

Re-run notes for the three cleared checks:

- Check 1 (what `git worktree remove` leaves): PS 7 and Git Bash behaved the same. Exit 0 in
  both, registration dropped from `git worktree list`, worktree directory left on disk with only
  the `notes.local` junction inside, junction target intact. Previous pass's divergence
  ("one check reported the directory gone, another left") is not reproducible on this box.
- Check 2 (recursive delete through a junction): Git Bash `rm -rf`, PS 7 and Windows PowerShell
  5.1 `Remove-Item -Recurse -Force` all deleted `left` and left `target\keep.txt` intact. No
  shell traversed the junction.
- Check 4 (voice directory through a junction): with `GHOSTWRITING_DIR` cleared in the launching
  shell and a junction at `%USERPROFILE%\.claude\ghostwriting` pointing at the real voice
  directory, `/ghostwriting-skills:ghostwrite` loaded clean and prompted for a draft, which is
  what loading does when the voice spec resolves.

Left:

3. The writing gate blocking a commit. With a spaced em dash in `body.md`, have the session run
   `git commit --allow-empty -F body.md` as the whole command, with no `cd`, no `git -c`, and no
   wrapper, in Git Bash and in PowerShell 7. Pass: the commit is blocked. Re-run on 2026-10-09:
   the gate did not block in either shell. The command was literally
   `git commit --allow-empty -F body.md`, run from the primary checkout with `body.md` holding
   `A quick change — one line, nothing more.`; both commits landed silently with no gate note
   and no toast. The gate hook does hook both tools (`Bash` and `PowerShell`), FAMILIES matches
   `git commit`, and the body file meets every read precondition, so the review model is
   being called and returning no finding.
