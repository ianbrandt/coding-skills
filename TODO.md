# To do

- Needs a Windows machine with git installed as a shim, by scoop or as a portable install: check
  that the `git --exec-path` lookup in `shell-owner.ps1` still lands on the Git root, which is the
  case it was added for. A normal install was covered by the Windows run of the self-test.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
- Needs a machine with an `apiKeyHelper` configured: check whether one in a settings file revives
  `claude -p --bare`. The OAuth half is answered. On an OAuth-only session `--bare` prints
  "Not logged in" in about 0.6s, so the gate fails open and never reaches a model; the README's
  "about 2k tokens and 4 to 10 seconds" was measured on a LiteLLM proxy in front of Bedrock and does
  not describe an OAuth install. See `spike-notes.local/gate-generalization-probes.md`.
