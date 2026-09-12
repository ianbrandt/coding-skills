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
A="inanimate agency"
# confirmed violations from hand-checked drafts
expect "$A" "The build script says the tests pass."
expect "$A" "The report says everything is fine."
expect "$A" "The report concluded the build is fine."
expect "$A" "The stability report stated a regression."
expect "$A" "The cap is gone, so the report offers the upgrade anyway."
expect "$A" "so the report is no longer a function of the declarations the build wrote, which the README states plainly."
expect "$A" "The deprecation message names the replacement id."
expect "$A" "It exempts a range on the grounds that the rule wants an interval."
expect "$A" "Recovery runs only when the declared version states a range."
expect "$A" "the system property, whose place is in the middle, is read second."
expect "$A" "A module whose version is unset is skipped."
expect "$A" "The roadmap entry names the file, and the alias, which declares the version, is kept."
expect "$A" "Its own text says the item is gated."
expect "$A" "The commit that decides the default lands last."
expect "$A" "Neither declares a constraint on the classpath."
# acceptable prose that must stay clean
expect - "The user says the build is slow on CI."
expect - "The maintainer wrote the original recovery in 2023."
expect - "The function returns early when the list is empty, keeping the loop simple."
expect - "Gradle flattens the alias to a bare require on the marker."
expect - "The claim file is named by the session that holds the lease."
expect - "I wrote the fix and we decided to keep the flag off by default."
expect - "The value is used only when the declared version is exact."
expect - "This keeps the diff small and the behaviour unchanged."
expect - "That said, the guard is still worth a test."
expect - "The declared bound is a ceiling, not a floor."
expect - "The rule stated in the README covers this case."
expect - "A reviewer who knows the codebase can confirm this in minutes."
expect - "Run the suite before you commit anything."
expect - "A session's notes are kept under the scratchpad."
expect - "A map holds a value until the loop gives up."
expect - "The old names are kept, and the members added last week stay."
expect - "The fix holds up well under load."
expect - "My first attempt used map notation."
expect - "The adversarial pass found two defects."
expect - "the file names in the warning are sorted"
expect - "Two processes hold each other open."
expect - "A subagent who asks for the file gets it."
# false positives found in a 40-hit sample of the first shell version
expect - "Draft release notes below, followed by the release notes you approved."
expect - "The spike notes measured only through 8.14.4."
expect - "The verifier claimed the two settings overwrite each other."
expect - "Covered by a composite test if Ben asks for a reproducer."
expect - "Without that noted, the change surprises every repo."
expect - "The API exposes three named endpoints."
expect - "Coordinates go in with the pom artifact declared through the block."
expect - "One probe for the four claims that need a live run."
expect - "Discovered by the platform scan rather than declared, carrying a dynamic version."
expect - "The two warning strings and the spec names, 163 lines of README alone."
expect - "A scenario column so both unrolled names read correctly."
expect - "The likely cause with its one unconfirmed step named, then the fix in two parts."
expect - "The ladder the model's own field names imply is three levels."
expect - "The three names proposed and declined, with the reasons."
expect - "Covered when a CI job fails or Ben asks for a rerun."
expect - "I fixed the indentation and wrongly assumed the rest was fine."
expect - 'A case named `foo` covers the empty list, and a field named "x" holds it.'
expect "$A" "The stability report claimed a regression."
expect "$A" "The title now names \`rejectPreReleases\`."
expect "$A" "The fenced output below it already names the artifact."
expect "$A" "The body says nothing about the five review commits."
expect "$A" "The revision that asks for snapshots gets them filtered."
# quotations and code never count
expect - 'I said "the report says X" and rewrote it.'
expect - 'Inline `the report says` is code, and so is this fence:
```
the report says everything
```
'
# banned words and dashes
expect "banned word" "This fix is not vacuous at all."
expect "banned word" "That channel predates the options."
expect - "Post it in the Slack channel and check the array shape."
expect "spaced em dash" "This is one thing — and another."
expect - "This is correct—no space here, nothing else flagged."
expect - "Headings: ## Title—subtitle"
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
# end to end: record, emit, second emit, clean record clears, nudge
export TMPDIR="${TMPDIR:-/tmp}"
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
[ -z "$(printf 'not json' | bash "$HERE/lint.sh" --nudge)" ] || { echo "FAIL nudge on garbage"; fail=1; }
printf 'not json at all {{{' | bash "$HERE/lint.sh" --record; [ $? -eq 0 ] || { echo "FAIL garbage record exit"; fail=1; }
[ $fail -eq 0 ] && echo "PASS ($cases cases)" || { echo "FAILED"; exit 1; }
