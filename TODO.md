# To do

- Needs a machine where `claude plugin eval` can grant Bash (on this Mac the Docker Desktop links in
  `~/.docker` break the sandbox): two live-git `session-skills` eval cases, a repo-root path in
  context still lands the edit in the worktree, and a stale local default branch still branches
  from `origin/<default>`.

## Windows pass follow-up

Checks 1, 2, 3, and 4 of the first Windows pass were re-run on 2026-10-09 and all four cleared.
Setup for each: a scratch repo at a path with a space in it, with one commit, a bare repo beside
it as `origin`, a `notes.local` directory with a file `keep.txt` in it, and `/notes.local` in
`.git/info/exclude`.

Re-run notes:

- Check 1 (what `git worktree remove` leaves): PS 7 and Git Bash behaved the same. Exit 0 in
  both, registration dropped from `git worktree list`, worktree directory left on disk with only
  the `notes.local` junction inside, junction target intact. Previous pass's divergence
  ("one check reported the directory gone, another left") is not reproducible on this box.
- Check 2 (recursive delete through a junction): Git Bash `rm -rf`, PS 7 and Windows PowerShell
  5.1 `Remove-Item -Recurse -Force` all deleted `left` and left `target\keep.txt` intact. No
  shell traversed the junction.
- Check 3 (writing gate blocking a commit): first probed from a session loaded before the plugin
  update to 0.45.6 that day, where `git commit --allow-empty -F body.md` with the dashed body
  landed silently and was recorded as a gate miss. Re-probed from a fresh session on 0.45.6 with
  a one-line log on the review model's reply dropped into `read()`: the first attempt blocked
  with `"A quick change — one line, nothing more." -> A quick change, one line only.`, the
  session rewrote `body.md` to the suggested text, the second attempt returned `PASS`, and the
  rewritten body committed. The gate behaves as intended on 0.45.6; the earlier miss is an
  in-memory stale-plugin artifact of a long-running session.
- Check 4 (voice directory through a junction): with `GHOSTWRITING_DIR` cleared in the launching
  shell and a junction at `%USERPROFILE%\.claude\ghostwriting` pointing at the real voice
  directory, `/ghostwriting-skills:ghostwrite` loaded clean and prompted for a draft, which is
  what loading does when the voice spec resolves.
