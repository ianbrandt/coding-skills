# To do

- Needs a Windows machine with git installed as a shim, by scoop or as a portable install: check
  that the `git --exec-path` lookup in `shell-owner.ps1` still lands on the Git root, which is the
  case it was added for. A normal install was covered by the Windows run of the self-test.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
- Needs a Windows machine: run `hooks/gate-test.ps1` in `writing-conventions`. The `claude.bat` stub
  now prints the verdict with `type "%GATE_TEST_VERDICT_FILE%"`, records the arguments of each call
  with `echo %*`, and fails a `--safe-mode` call on request. Only the bash stub has been run, under
  PowerShell 7 on macOS.
- Needs a machine signed in through a gateway with a key: check that `claude -p --safe-mode --tools=
  --model sonnet 'Reply with exactly the word PASS.'` prints `PASS`, and that the same call with
  `--bare` in place of `--safe-mode` does too, and time both, a failed one included. On a browser
  sign-in the first call takes about 3.5 s at about 1.9k input tokens and the second prints "Not
  logged in". When both work through the gateway, the `--bare` retry in `gate.sh` and `gate.ps1` can
  be deleted.
