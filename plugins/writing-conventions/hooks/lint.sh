#!/usr/bin/env bash
# House-style lint and reminders for the assistant's prose. bash plus awk only.
#   --record  Stop hook: lint the final reply, save a note, never block.
#   --emit    UserPromptSubmit hook: print any saved note into the next turn,
#             clear it, then print the standing style reminder.
#   --nudge   PostToolUse hook on Write|Edit: when the file just written holds
#             prose, tell the model to re-read and fix it in place now.
# Never blocking is the point: a Stop hook cannot patch a reply, so blocking one
# costs a full re-emission of an answer the reader has already seen. The
# correction lands on the next reply instead. Every path exits 0.
HERE=$(cd "$(dirname "$0")" && pwd)
mode=${1:---record}
input=$(cat)
sid=$(printf '%s' "$input" | awk -v key=session_id -f "$HERE/jsonstr.awk")
sid=${sid:-default}
sid=$(printf '%s' "$sid" | tr -c 'A-Za-z0-9_-' '_')
state="${TMPDIR:-/tmp}/claude-reply-lint-${sid}.txt"

REMINDER='Style, for this reply and any prose written to files: an inanimate subject takes no agentive verb—"the entry declared in the `plugins` block", never "the `plugins` block owns/says/gives". Em dashes unspaced (word—word). Plain words.'
NUDGE='You just wrote prose to a file. Re-read it now for inanimate agency (report/build/entry/declaration as subject of says/gives/owns/wrote/holds), spaced em dashes, and banned vocabulary; fix in place before moving on. If this text will publish under the user'"'"'s name, have a fresh-context subagent sweep it against the rules before hand-over.'

case "$mode" in
  --record)
    note=$(printf '%s' "$input" | awk -v key=last_assistant_message -f "$HERE/jsonstr.awk" \
      | awk -v note=1 -f "$HERE/lint.awk")
    if [ -n "$note" ]; then printf '%s\n' "$note" > "$state"; else rm -f "$state"; fi
    ;;
  --emit)
    if [ -f "$state" ]; then cat "$state"; rm -f "$state"; fi
    printf '%s\n' "$REMINDER"
    ;;
  --nudge)
    path=$(printf '%s' "$input" | awk -v key=file_path -f "$HERE/jsonstr.awk")
    case "$path" in
      *.md|*.markdown|*.txt|*.kt|*.kts|*.java|*.groovy)
        printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$NUDGE"
        ;;
    esac
    ;;
esac
exit 0
