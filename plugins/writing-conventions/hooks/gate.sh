#!/usr/bin/env bash
# Publication gate: check the human-facing text in a git commit, a gh command, a
# call to an MCP tool that can publish, a prose file just written, or a draft the
# reply puts in a `draft` fence, against the four prohibitions, before it reaches
# a reader. bash plus awk only.
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

# ask <system prompt> [<file appended to it>]: the reply to one nested call on the
# hook input, retried once with --bare when the first call exits non-zero. With no
# `claude` on the path there is no call, which is the same failure.
ask() { command -v claude >/dev/null 2>&1 || return 1; call --safe-mode "$@" || call --bare "$@"; }
call() {
  printf '%s' "${msg:-$input}" | WRITING_CONVENTIONS_NESTED=1 claude -p "$1" --tools= \
    --model "${WRITING_CONVENTIONS_GATE_MODEL:-sonnet}" \
    --system-prompt-file "$HERE/$2" \
    ${3:+--append-system-prompt-file "$HERE/$3"} 2>/dev/null
}

tmp=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$tmp"' EXIT
CAP=50000

# field <key>: one string field of the hook input, decoded
field() { printf '%s' "$input" | awk -v key="$1" -f "$HERE/jsonstr.awk"; }
# context: stdin as the additionalContext of a PostToolUse hook, JSON-escaped.
# The text is split and joined, because what a backslash means in the replacement
# of a gsub differs from one awk to the next.
context() {
  awk 'function rep(s, from, to,    n, a, i, out) { n = split(s, a, from); out = a[1]; for (i = 2; i <= n; i++) out = out to a[i]; return out }
    { gsub(/[\001-\010\013-\037]/, ""); text = text (NR > 1 ? "\\n" : "") rep(rep(rep($0, "\\", "\\\\"), "\"", "\\\""), "\t", "\\t") }
    END { if (text != "") printf "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"%s\"}}", text }'
}

# off: the exit for a check that could not run. The user is told the first time in a
# session, through systemMessage, which the user is shown and the model is not. The
# marker is a file named for the session, as the note in lint.sh is, and with no
# session id there is no marker, so nothing is said rather than said every time.
off() {
  sid=$(field session_id | tr -c 'A-Za-z0-9_-' '_')
  mark="${TMPDIR:-/tmp}/claude-gate-off-$sid"
  if [ -n "$sid" ] && [ ! -e "$mark" ] && : > "$mark"; then
    printf '{"systemMessage":"writing-conventions: model review is off for this session, because the nested claude -p call failed. Commit, PR, MCP, file, and draft text is not being read; the pattern lint on replies still runs."}'
  fi
  exit 0
}

tool=$(field tool_name)
case "$1:$tool" in
  --stop:*)
    # A reply the session has tagged as a draft for publication. Only the text
    # inside a `draft` fence is reviewed, so nothing else in the reply is judged
    # by the model, and a reply with no such fence costs one awk pass and no
    # call at all. An untagged draft is read by the reply lint alone.
    [ "$WRITING_CONVENTIONS_STOP_READER" = 0 ] && exit 0
    field last_assistant_message | awk -f "$HERE/draft.awk" > "$tmp/text"
    [ -s "$tmp/text" ] || exit 0
    # Blocking a reply is bounded per turn, counted in a file named for the
    # prompt_id, which is the same on every Stop call of one turn. With no
    # prompt_id nothing can be counted, so nothing is blocked and a call would
    # buy nothing.
    pid=$(field prompt_id | tr -c 'A-Za-z0-9_-' '_')
    [ -n "$pid" ] || exit 0
    stop="${TMPDIR:-/tmp}/claude-gate-stop-$pid"
    if [ "$(wc -c < "$tmp/text")" -gt $CAP ]; then
      head -c $CAP "$tmp/text" > "$tmp/cut" && mv "$tmp/cut" "$tmp/text"
    fi
    # The reader is sent the drafts and nothing else. Each one stays a source of
    # its own, so no finding can quote across two of them.
    msg=$(tr '\001' '\n' < "$tmp/text")
    sources() { cat "$tmp/text"; }
    again='emit the corrected draft' ;;
  --file:Write|--file:Edit)
    # A prose file just written. The nested model has no tools, so this script does
    # the reading, and only of the file the tool wrote. The reader is sent the text
    # under review and not the hook input, which for a Write holds the whole file.
    path=$(field file_path)
    case "$(printf '%s' "$path" | tr 'A-Z' 'a-z')" in
      *.md|*.markdown|*.txt|*.adoc|*.rst) ;;
      *) exit 0 ;;
    esac
    unread=
    if [ "$tool" = Write ]; then
      field content > "$tmp/text"
    else
      field new_string > "$tmp/new"
      if ! grep -q '[^[:space:]]' "$tmp/new"; then
        printf 'Not reviewed: this edit to %s only deleted text.\n' "$path" | context
        exit 0
      elif [ ! -f "$path" ] || [ "$(wc -c < "$path")" -gt 1048576 ]; then
        cp "$tmp/new" "$tmp/text"
        unread="Only the new text was reviewed, not the sentences around it: $path is over 1 MB or could not be read."
      else
        awk -v cap=$CAP -f "$HERE/excerpt.awk" "$tmp/new" "$path" > "$tmp/text"
        [ -s "$tmp/text" ] || cp "$tmp/new" "$tmp/text"
      fi
    fi
    if [ "$(wc -c < "$tmp/text")" -gt $CAP ]; then
      head -c $CAP "$tmp/text" > "$tmp/cut" && mv "$tmp/cut" "$tmp/text"
      unread="Only the first $CAP characters of the text were reviewed."
    fi
    msg=$(printf 'File: %s\n\n' "$path"; cat "$tmp/text")
    sources() { cat "$tmp/text"; }
    again= ;;
  --file:*) exit 0 ;;
  :mcp__*)
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
      class=$(ask classify-prompt.md) || off
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
verdict=$(ask gate-prompt.md rules.md) || off

# verdict.awk keeps the findings that quote the text under review. A reply in any
# other form is a failure path, so it lets the command through as well.
sources > "$tmp/source"
printf '%s\n' "$verdict" > "$tmp/verdict"
findings=$(awk -v verdict="$tmp/verdict" -f "$HERE/verdict.awk" "$tmp/source" "$tmp/verdict")
if [ -z "$again" ]; then
  # A file is cheap to fix after the fact and a blocked edit stops the turn, so
  # this path hands the findings back and blocks nothing.
  { [ -z "$findings" ] || printf '%s\nFix the quoted text in %s.\n' "$findings" "$path"
    [ -z "$unread" ] || printf '%s\n' "$unread"; } | context
  exit 0
fi
[ -n "$findings" ] || exit 0
if [ -n "$stop" ]; then
  # A blocked Stop costs a whole re-emitted reply, so a reader that keeps
  # finding something in each rewrite is stopped after two: the user is told
  # that review is unresolved, through systemMessage, and the reply stands.
  n=$(cat "$stop" 2>/dev/null)
  case $n in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -ge 2 ]; then
    printf '{"systemMessage":"writing-conventions: the draft in this reply still reads as a violation after two rewrites. Review is unresolved and the reply stands."}'
    exit 0
  fi
  printf '%s' $((n + 1)) > "$stop" 2>/dev/null
fi
printf '%s\nRewrite the quoted text and %s.\n' "$findings" "$again" >&2
exit 2
