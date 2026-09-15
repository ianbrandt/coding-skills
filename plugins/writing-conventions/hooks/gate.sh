#!/usr/bin/env bash
# Publication gate: check the human-facing text in a git commit or gh command
# against the four prohibitions before it is published. bash plus awk only.
#
# The check runs as one nested `claude -p --bare` call, with gate-prompt.md as the
# system prompt and the hook input as the message. `--bare` skips hooks, plugins,
# LSP, and CLAUDE.md discovery, which keeps the call to about 2k tokens and a few
# seconds, and rules out this hook firing inside its own nested session.
#
# The model comes from WRITING_CONVENTIONS_GATE_MODEL, or the `sonnet` alias when
# that is unset. Set it in the `env` block of a settings file to any id the
# session's endpoint serves. An alias works because `--model` resolves one through
# ANTHROPIC_DEFAULT_SONNET_MODEL and friends, on a first-party install and on a
# proxy in front of Bedrock or Vertex alike. The `model` field of a prompt-type
# hook resolves nothing: `"model": "sonnet"` there reaches the API verbatim and
# comes back as HTTP 400, which is why the check runs out here instead.
#
# Under `--bare` the nested call authenticates with ANTHROPIC_API_KEY, an
# apiKeyHelper, or a third-party provider's own credentials. A session signed in
# through OAuth alone has none of those, so the call fails and the gate lets the
# command through.
#
# A gate that cannot reach a model must not stop a commit, so every failure path
# exits 0. Only a violation the model can quote exits 2, which blocks the command
# and hands the text back to the session.

# One of gate.sh and gate.ps1 runs the check, never both. PowerShell takes the
# hook on a Windows install where the PowerShell tool is the configured shell. The
# mirror of this test is in shell-owner.ps1, which also hands PowerShell the hook
# where there is no Git Bash to run this script.
if [ "$OS" = Windows_NT ] && [ "$CLAUDE_CODE_USE_POWERSHELL_TOOL" = 1 ] \
   && command -v pwsh >/dev/null 2>&1; then exit 0; fi
HERE=$(cd "$(dirname "$0")" && pwd)
input=$(cat)

# Matching the command text here rather than through a hook `if` pattern covers
# `git -C <path> commit`, which no `Bash(git commit *)` rule matches, and keeps one
# copy of the prompt instead of one per subcommand per tool.
cmd=$(printf '%s' "$input" | awk -v key=command -f "$HERE/jsonstr.awk")
case "$cmd" in
  *"git commit"*|*"git -C"*commit*|*"gh pr "*|*"gh issue "*|*"gh release "*) ;;
  *) exit 0 ;;
esac

command -v claude >/dev/null 2>&1 || exit 0
verdict=$(printf '%s' "$input" | claude -p --bare \
  --model "${WRITING_CONVENTIONS_GATE_MODEL:-sonnet}" \
  --system-prompt-file "$HERE/gate-prompt.md" 2>/dev/null) || exit 0
case $verdict in
  ''|CLEAN|CLEAN[!A-Za-z]*) exit 0 ;;
esac
printf '%s\n' "$verdict" >&2
exit 2
