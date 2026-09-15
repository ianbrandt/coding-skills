# To do

- Needs a Windows machine with git installed as a shim, by scoop or as a portable install: check
  that the `git --exec-path` lookup in `shell-owner.ps1` still lands on the Git root, which is the
  case it was added for. A normal install was covered by the Windows run of the self-test.
- Needs a Windows machine with no Git Bash: check whether the bash-side command hooks print an
  error on every Stop, prompt, and Write/Edit event, and whether `"shell": "bash"` suppresses it.
- Needs a session signed in through OAuth rather than an API key or a proxy: the publication gate
  runs `claude -p --bare`, which reads neither OAuth nor the keychain, so confirm the gate fails open
  there instead of blocking a commit, and whether an `apiKeyHelper` in a settings file revives it.
  Everything else about the gate was measured on a LiteLLM proxy in front of Bedrock.
