#!/usr/bin/env bash
# Self-test for lint.awk, jsonstr.awk, and lint.sh. Run from anywhere:
#   bash hooks/lint-test.sh
HERE=$(cd "$(dirname "$0")" && pwd)
fail=0; cases=0
groups() { printf '%s\n' "$1" | awk -f "$HERE/lint.awk" | cut -f1 | sort -u | tr '\n' ' '; }
expect() {  # expect <group or -> <text>
  cases=$((cases + 1)); got=$(groups "$2")
  if [ "$1" = "-" ]; then
    [ -z "$got" ] || { echo "FAIL (expected clean): $2  -> $got"; fail=1; }
  else
    case " $got" in *" $1 "*) ;; *) echo "FAIL (expected $1): $2  -> ${got:-clean}"; fail=1;; esac
  fi
}
# The matcher cases live in lint-corpus.tsv, which lint-test.ps1 reads too, so a
# change to one matcher and not the other fails here or there. A "-" group means
# the text must come back clean; \n in a case is a newline.
while IFS="$(printf '\t')" read -r group text; do
  case "$group" in ""|"#"*) continue;; esac
  expect "$group" "$(printf '%s' "$text" | sed 's/\\n/\n/g')"
done < "$HERE/lint-corpus.tsv"
# the note
note=$(printf '%s' 'A — B — C, and the report says so.' | awk -v note=1 -f "$HERE/lint.awk")
cases=$((cases + 1))
case "$note" in *"spaced em dash x1"*"never word — word"*"inanimate agency x1"*"say who the real actor is"*) ;; *) echo "FAIL note: $note"; fail=1;; esac
case "$note" in *"loaded at session start"*) echo "FAIL note defers to session start"; fail=1;; esac
cases=$((cases + 1)); [ -z "$(printf 'Plain prose, nothing flagged.' | awk -v note=1 -f "$HERE/lint.awk")" ] || { echo "FAIL clean note not empty"; fail=1; }
# jsonstr: escapes, unicode, nested quotes, key order
cases=$((cases + 1))
v=$(printf '{"session_id":"abc/1","cwd":"/x","last_assistant_message":"Line one\\nsays \\"hi\\" \\u2014 done \\\\ end","effort":{"level":"m"}}' | awk -v key=last_assistant_message -f "$HERE/jsonstr.awk")
[ "$v" = "$(printf 'Line one\nsays "hi" — done \\ end')" ] || { echo "FAIL jsonstr: [$v]"; fail=1; }
# lint.sh hands the hook to lint.ps1 when the PowerShell tool is the configured
# shell. This section drives lint.sh itself, so clear that switch for it.
unset CLAUDE_CODE_USE_POWERSHELL_TOOL
# end to end: record, emit, second emit, clean record clears, nudge. The state
# files go to a scratch directory so the test never reads or deletes a live
# session's note.
TMPDIR=$(mktemp -d); export TMPDIR
trap 'rm -rf "$TMPDIR"' EXIT
cases=$((cases + 1))
printf '{"session_id":"selftest","last_assistant_message":"This shape is vacuous."}' | bash "$HERE/lint.sh" --record
out=$(printf '{"session_id":"selftest"}' | bash "$HERE/lint.sh" --emit)
case "$out" in *"banned word x1"*"Style, for this reply"*) ;; *) echo "FAIL emit: $out"; fail=1;; esac
out2=$(printf '{"session_id":"selftest"}' | bash "$HERE/lint.sh" --emit)
[ "$out2" = "$(printf '{"session_id":"x"}' | bash "$HERE/lint.sh" --emit)" ] || { echo "FAIL second emit not reminder only: $out2"; fail=1; }
printf '{"session_id":"selftest","last_assistant_message":"This shape is vacuous."}' | bash "$HERE/lint.sh" --record
printf '{"session_id":"selftest","last_assistant_message":"Plain prose."}' | bash "$HERE/lint.sh" --record
out3=$(printf '{"session_id":"selftest"}' | bash "$HERE/lint.sh" --emit)
case "$out3" in *"flagged"*) echo "FAIL clean record did not clear"; fail=1;; esac
cases=$((cases + 1))
n=$(printf '{"tool_name":"Write","tool_input":{"file_path":"/tmp/draft.md","content":"x"}}' | bash "$HERE/lint.sh" --nudge)
case "$n" in '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"You just wrote prose'*) ;; *) echo "FAIL nudge: $n"; fail=1;; esac
[ -z "$(printf '{"tool_input":{"file_path":"/src/main.py"}}' | bash "$HERE/lint.sh" --nudge)" ] || { echo "FAIL nudge fired on .py"; fail=1; }
[ -n "$(printf '{"tool_input":{"file_path":"/tmp/README.MD"}}' | bash "$HERE/lint.sh" --nudge)" ] || { echo "FAIL nudge skipped README.MD"; fail=1; }
# no session id: nothing is saved, and nothing another session saved is printed
printf '{"last_assistant_message":"This shape is vacuous."}' | bash "$HERE/lint.sh" --record
[ -z "$(ls "$TMPDIR")" ] || { echo "FAIL record without session id wrote a file"; fail=1; }
case "$(printf '{"x":1}' | bash "$HERE/lint.sh" --emit)" in *flagged*) echo "FAIL emit without session id printed a note"; fail=1;; esac
[ -z "$(printf 'not json' | bash "$HERE/lint.sh" --nudge)" ] || { echo "FAIL nudge on garbage"; fail=1; }
printf 'not json at all {{{' | bash "$HERE/lint.sh" --record; [ $? -eq 0 ] || { echo "FAIL garbage record exit"; fail=1; }
[ $fail -eq 0 ] && echo "PASS ($cases cases)" || { echo "FAILED"; exit 1; }
