#!/usr/bin/env bash
# Publication gate: check the human-facing text in a git commit, a gh command, or
# a call to an MCP tool that can publish, against the four prohibitions, before it
# is published. bash plus awk only.
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
# exits 0. Only a finding with its quote in the text under review exits 2, which
# blocks the command or the call and hands the text back to the session.

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

command -v claude >/dev/null 2>&1 || exit 0
# ask <system prompt> [<file appended to it>]: the reply to one nested call on the
# hook input, retried once with --bare when the first call exits non-zero.
ask() { call --safe-mode "$@" || call --bare "$@"; }
call() {
  printf '%s' "$input" | WRITING_CONVENTIONS_NESTED=1 claude -p "$1" --tools= \
    --model "${WRITING_CONVENTIONS_GATE_MODEL:-sonnet}" \
    --system-prompt-file "$HERE/$2" \
    ${3:+--append-system-prompt-file "$HERE/$3"} 2>/dev/null
}

tool=$(printf '%s' "$input" | awk -v key=tool_name -f "$HERE/jsonstr.awk")
case "$tool" in
  mcp__*)
    # Whether an MCP tool can publish is asked of a model once per tool and kept in
    # a per-user file, one line per answer, so no server or tool name is written
    # here. The file is outside the plugin's directory, which is per version, and is
    # named for a checksum of the classifier's prompt, so a changed prompt starts a
    # new file. The user can read and edit it. For one tool a CAN_PUBLISH line wins
    # over a NEVER line, and a line in any other form is ignored.
    dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/writing-conventions"
    cache="$dir/mcp-tools-$(cksum < "$HERE/classify-prompt.md" | awk '{print $1}').txt"
    class=$(awk -v t="$tool" 'NF == 2 && $1 == t { if ($2 == "CAN_PUBLISH") p = 1; if ($2 == "NEVER") n = 1 }
      END { if (p) print "CAN_PUBLISH"; else if (n) print "NEVER" }' "$cache" 2>/dev/null)
    if [ -z "$class" ]; then
      class=$(ask classify-prompt.md) || exit 0
      class=$(printf '%s\n' "$class" | awk 'NF { sub(/\r$/, ""); print; exit }')
      # A reply in any other form is doubt, which reads as CAN_PUBLISH and is not kept.
      case "$class" in
        NEVER|CAN_PUBLISH) mkdir -p "$dir" && printf '%s %s\n' "$tool" "$class" >> "$cache" ;;
        *) class=CAN_PUBLISH ;;
      esac
    fi
    [ "$class" = CAN_PUBLISH ] || exit 0
    # The reader is sent the whole input, structure included, and a finding has to
    # quote one of the string values in tool_input.
    sources() { printf '%s' "$input" | awk -v under=tool_input -f "$HERE/jsonstr.awk"; }
    again='make the call again' ;;
  *)
    # Matching the command text here rather than through a hook `if` pattern covers
    # `git -C <path> commit`, which no `Bash(git commit *)` rule matches, and keeps one
    # copy of the prompt instead of one per subcommand per tool.
    cmd=$(printf '%s' "$input" | awk -v key=command -f "$HERE/jsonstr.awk")
    case "$cmd" in
      *"git commit"*|*"git -C"*commit*|*"gh pr "*|*"gh issue "*|*"gh release "*) ;;
      *) exit 0 ;;
    esac
    sources() { printf '%s' "$cmd"; }
    again='run the command again' ;;
esac
verdict=$(ask gate-prompt.md rules.md) || exit 0

# verdict.awk keeps the findings that quote the command. A reply in any
# other form is a failure path, so it lets the command through as well.
tmp=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$tmp"' EXIT
sources > "$tmp/source"
printf '%s\n' "$verdict" > "$tmp/verdict"
findings=$(awk -v verdict="$tmp/verdict" -f "$HERE/verdict.awk" "$tmp/source" "$tmp/verdict")
[ -n "$findings" ] || exit 0
printf '%s\nRewrite the quoted text and %s.\n' "$findings" "$again" >&2
exit 2
