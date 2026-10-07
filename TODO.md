# To do

- Needs a Windows machine: trigger the two writing-conventions "gate off" toasts (unset a required
  env var or let a model call fail) and confirm each fits in four lines in the Claude Code UI.
  Toast 1 is 95 chars; toast 2 is 149 chars.
- Needs a Windows machine: `a body passed through PowerShell by a Windows path is read` in
  `plugins/writing-conventions/hooks/gate.test.ts` fails on macOS. `C:/proj/body.md` is not
  absolute there, so the path reaches the `fs.stat` mock as `<cwd>/C:/proj/body.md` and the drive
  letter is not at the start, where `posix` removes it. This `posix` gives 92 of 92 on macOS:
  `p.replace(/\\/g, '/').replace(/^(.*\/)?[A-Za-z]:(?=\/)/, '')`. Confirm it on Windows with
  `claude plugin test plugins/writing-conventions`, then commit it.
- Needs a machine where `claude plugin eval` can grant Bash (on this Mac the Docker Desktop links in
  `~/.docker` break the sandbox): two live-git `session-skills` eval cases, a repo-root path in
  context still lands the edit in the worktree, and a stale local default branch still branches
  from `origin/<default>`.
