# To do

- Needs a Windows machine: trigger the two writing-conventions "gate off" toasts (unset a required
  env var or let a model call fail) and confirm each fits in four lines in the Claude Code UI.
  Toast 1 is 95 chars; toast 2 is 149 chars.
- Needs a machine where `claude plugin eval` can grant Bash (on this Mac the Docker Desktop links in
  `~/.docker` break the sandbox): two live-git `session-skills` eval cases, a repo-root path in
  context still lands the edit in the worktree, and a stale local default branch still branches
  from `origin/<default>`.
