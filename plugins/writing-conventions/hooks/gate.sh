#!/usr/bin/env bash
# Publication gate: check the human-facing text in a git commit or gh command
# against the four prohibitions before it is published. bash plus awk only.
#
# The check runs as one nested `claude -p --safe-mode --tools=` call, with
# gate-prompt.md as the system prompt, rules.md appended to it so that the rules
# are written down once, and the hook input as the message.
# `--safe-mode` starts the call with no CLAUDE.md, skills, plugins, hooks, or MCP
# servers and keeps the normal sign-in, so it works on a browser sign-in as well as
# with a key. With `--tools=` the nested model has no tools, and the default tool
# definitions are 24k of the 26k input tokens of a call without it: with it a call
# is about 2k tokens and a few seconds. It is written as one argument because
# PowerShell can drop an empty one, and gate.ps1 makes the same call.
#
# The model comes from WRITING_CONVENTIONS_GATE_MODEL, or the `sonnet` alias when
# that is unset. Set it in the `env` block of a settings file to any id the
# session's endpoint serves. An alias works because `--model` resolves one through
# ANTHROPIC_DEFAULT_SONNET_MODEL and friends, on a first-party install and on a
# proxy in front of Bedrock or Vertex alike. The `model` field of a prompt-type
# hook resolves nothing: `"model": "sonnet"` there reaches the API verbatim and
# comes back as HTTP 400, which is why the check runs out here instead.
#
# `--safe-mode` has not been checked on an install that signs in through a gateway
# with a key (see TODO.md), so a call that exits non-zero is retried once with
# `--bare`, which is known to work there and prints "Not logged in" on a browser
# sign-in.
#
# A gate that cannot reach a model must not stop a commit, so every failure path
# exits 0. Only a finding with its quote in the command exits 2, which blocks the
# command and hands the text back to the session.

# Managed policy settings still apply under `--safe-mode`, so a copy of this hook
# registered that way runs inside the nested call. The call below sets this marker
# on its child, and nothing here is worth doing for the reader's own session.
[ -z "$WRITING_CONVENTIONS_NESTED" ] || exit 0

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
# reader <--safe-mode|--bare>
reader() {
  printf '%s' "$input" | WRITING_CONVENTIONS_NESTED=1 claude -p "$1" --tools= \
    --model "${WRITING_CONVENTIONS_GATE_MODEL:-sonnet}" \
    --system-prompt-file "$HERE/gate-prompt.md" \
    --append-system-prompt-file "$HERE/rules.md" 2>/dev/null
}
verdict=$(reader --safe-mode) || verdict=$(reader --bare) || exit 0

# verdict.awk keeps the findings that quote the command. A reply in any
# other form is a failure path, so it lets the command through as well.
tmp=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$tmp"' EXIT
printf '%s' "$cmd" > "$tmp/source"
printf '%s\n' "$verdict" > "$tmp/verdict"
findings=$(awk -v verdict="$tmp/verdict" -f "$HERE/verdict.awk" "$tmp/source" "$tmp/verdict")
[ -n "$findings" ] || exit 0
printf '%s\nRewrite the quoted text and run the command again.\n' "$findings" >&2
exit 2
