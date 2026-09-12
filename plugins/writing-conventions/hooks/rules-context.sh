#!/usr/bin/env bash
# Print hooks/rules.md as the additionalContext of a hook event, JSON-encoded.
#   bash rules-context.sh SubagentStart
# Backslash, double quote, tab, carriage return, backspace, and form feed are
# escaped; any other control character is dropped, so the output is always a
# valid JSON string whatever gets pasted into rules.md.
HERE=$(cd "$(dirname "$0")" && pwd)
event=${1:-SubagentStart}
esc=$(awk 'BEGIN { ORS = "" }
  { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "\\r")
    gsub(/\b/, "\\b"); gsub(/\f/, "\\f"); gsub(/[\001-\037]/, "")
    print $0 "\\n" }' "$HERE/rules.md")
printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}' "$event" "$esc"
