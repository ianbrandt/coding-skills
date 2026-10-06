# To do

- Needs a Windows machine, for `writing-conventions` 0.44.0 and `ghostwriting-skills` 0.8.0: check
  that the hooks module loads with `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` unset (`claude --debug` logs
  a module that did not load), that a `git commit` through the PowerShell tool is read at the gate,
  that the two toasts fit in four lines, and that the reply-lint note is saved under `TEMP`.
- Needs a Windows machine, for the `session-skills` snippets and their `powershell.md` versions:
  check that `git worktree list --porcelain` prints forward-slash paths that both shells parse,
  that the `SessionStart` `cat` hook loads under Git Bash and under PowerShell with no Git Bash,
  and that the notes link in `work-in-worktree` §3 is a link and not a copy. Git Bash's `ln -s`
  copies unless `MSYS=winsymlinks:nativestrict` is set; the PowerShell junction should need no
  Developer Mode.
- Needs a machine where `claude plugin eval` can grant Bash (on this Mac the Docker Desktop links in
  `~/.docker` break the sandbox): two live-git `session-skills` eval cases, a repo-root path in
  context still lands the edit in the worktree, and a stale local default branch still branches
  from `origin/<default>`.
