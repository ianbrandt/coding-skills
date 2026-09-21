#!/usr/bin/env bash
# Self-test for gate.sh, offline. Run from anywhere:
#   bash hooks/gate-test.sh
# A stub `claude` on the PATH stands in for the model, so what is tested is the
# plumbing: which commands reach the check, what the exit codes are, and that a
# nested call which fails lets the command through. gate-test.ps1 runs the same
# cases against gate.ps1.
HERE=$(cd "$(dirname "$0")" && pwd)
fail=0; cases=0
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

cat > "$scratch/claude" <<'STUB'
#!/usr/bin/env bash
# One line per call: the arguments, then the marker the gate sets on its child.
printf '%s nested=%s\n' "$*" "$WRITING_CONVENTIONS_NESTED" >> "$GATE_TEST_MARK"
cat > "$GATE_TEST_MARK.stdin"
[ "$GATE_TEST_FAIL" = 1 ] && exit 1
case " $* " in *' --safe-mode '*) [ "$GATE_TEST_FAIL" = safe ] && exit 1;; esac
case "$*" in *classify-prompt.md*) printf '%s\n' "$GATE_TEST_CLASS"; exit 0;; esac
printf '%s\n' "$GATE_TEST_VERDICT"
STUB
chmod +x "$scratch/claude"
PATH="$scratch:$PATH"
unset CLAUDE_CODE_USE_POWERSHELL_TOOL WRITING_CONVENTIONS_GATE_MODEL WRITING_CONVENTIONS_NESTED
export GATE_TEST_MARK="$scratch/mark"

# run <verdict> <fail> <command text>; sets $status, $stderr, and $called
run() {
  : > "$GATE_TEST_MARK"
  # exported, or the stub in the child process never sees them
  export GATE_TEST_VERDICT="$1" GATE_TEST_FAIL="$2"
  stderr=$(printf '{"tool_input":{"command":"%s"}}' "$3" | bash "$HERE/gate.sh" 2>&1 >/dev/null)
  status=$?
  called=$([ -s "$GATE_TEST_MARK" ] && echo yes || echo no)
}

# expect <exit> <called> <verdict> <fail> <command text>
expect() {
  cases=$((cases + 1))
  run "$3" "$4" "$5"
  [ "$status" = "$1" ] || { echo "FAIL exit $status, wanted $1: $5"; fail=1; }
  [ "$called" = "$2" ] || { echo "FAIL model called=$called, wanted $2: $5"; fail=1; }
}

# A command that publishes nothing never reaches the model.
expect 0 no PASS 0 'ls -la'
expect 0 no PASS 0 'git log --grep=commit'
expect 0 no PASS 0 'gh repo view'
# The four publishing families do, git -C included: no `if` pattern matches that
# one, which is why the command text is matched here instead.
expect 0 yes PASS 0 'git commit -m \"Plain message\"'
expect 0 yes PASS 0 'git -C /tmp/wt commit -m \"Plain message\"'
expect 0 yes PASS 0 'gh pr create --title x --body y'
expect 0 yes PASS 0 'gh issue comment 1 --body y'
expect 0 yes PASS 0 'gh release create v1 --notes y'
expect 0 yes SKIP 0 'gh pr view 1'

# Only a finding that quotes the command blocks it, and comes back as the reason.
says='git commit -m \"The report says so\"'
# blocked <verdict> <command text>; the verified finding is in $stderr afterwards
blocked() {
  cases=$((cases + 1))
  run "$1" 0 "$2"
  [ "$status" = 2 ] || { echo "FAIL exit $status, wanted 2: $1"; fail=1; }
}
blocked 'VIOLATION
"The report says so" -> The version is shown in the report.' "$says"
case $stderr in *'shown in the report'*'run the command again'*) ;; *) echo "FAIL violation reason: $stderr"; fail=1;; esac
# A fragment is matched with runs of whitespace collapsed, so a sentence that
# wraps in the commit body is still found.
blocked 'VIOLATION
"The report says so" -> x' 'git commit -m \"Fix it\n\nThe report\n  says so\"'
# Every fragment of a finding has to be in the command, and the reason leaves out
# a finding that is not.
blocked 'VIOLATION
"The report" + "says so" -> x' "$says"
blocked 'VIOLATION
"The build decided" -> invented
"The report says so" -> real' "$says"
case $stderr in *invented*) echo "FAIL unverified finding in the reason: $stderr"; fail=1;; esac
expect 0 yes 'VIOLATION
"The report" + "never appears" -> x' 0 "$says"
# Anything else lets the command through: a quote that is not in the command, a
# verdict line with a second word, a finding that does not parse, prose with no
# verdict line, and the reply the gate asked for before this contract.
expect 0 yes 'VIOLATION
"The build decided" -> x' 0 "$says"
expect 0 yes 'VIOLATION MAYBE
"The report says so" -> x' 0 "$says"
expect 0 yes 'VIOLATION
The report says so: rewrite it' 0 "$says"
expect 0 yes 'VIOLATION' 0 "$says"
# An empty quote is in every command, so it is not a quote.
expect 0 yes 'VIOLATION
"" -> x' 0 "$says"
expect 0 yes 'VIOLATION
" -> x' 0 "$says"
expect 0 yes 'the report says: rewrite it' 0 "$says"
expect 0 yes CLEAN 0 "$says"
# A gate that cannot reach a model must not stop a commit.
expect 0 yes '' 1 'git commit -m \"Plain message\"'
expect 0 yes '' 0 'git commit -m \"Plain message\"'

# The reader call. `--tools=` is one argument, because PowerShell can drop an empty
# one, and the marker is set on the child so that a copy of this hook registered by
# managed policy, which `--safe-mode` does not turn off, exits inside the nested call.
# calls <count> <pattern for call 1> [<pattern for call 2>], against the last run
calls() {
  cases=$((cases + 1))
  [ "$(wc -l < "$GATE_TEST_MARK" | tr -d ' ')" = "$1" ] || { echo "FAIL $(cat "$GATE_TEST_MARK"), wanted $1 calls"; fail=1; }
  n=0
  while IFS= read -r line; do
    n=$((n + 1)); eval "want=\${$((n + 1))}"
    case $line in $want) ;; *) echo "FAIL call $n: $line"; fail=1;; esac
  done < "$GATE_TEST_MARK"
}
run PASS 0 "$says"
# The rules reach the reader from rules.md, appended to gate-prompt.md, on both calls.
calls 1 '*--safe-mode --tools= --model*gate-prompt.md --append-system-prompt-file *rules.md nested=1'
case $(cat "$GATE_TEST_MARK") in *--bare*) echo 'FAIL --bare on a first call'; fail=1;; esac
# A call that exits non-zero is retried once with --bare, and that verdict counts.
run 'VIOLATION
"The report says so" -> x' safe "$says"
[ "$status" = 2 ] || { echo "FAIL exit $status, wanted 2 from the --bare retry"; fail=1; }
calls 2 '*--safe-mode --tools= *nested=1' '*--bare --tools= --model*--append-system-prompt-file *rules.md nested=1'
run '' 1 "$says"
[ "$status" = 0 ] || { echo "FAIL exit $status, wanted 0 with both calls failing"; fail=1; }
calls 2 '*--safe-mode*' '*--bare*'
# A reply in the wrong form from a call that exited 0 is not retried.
run 'the report says: rewrite it' 0 "$says"
calls 1 '*--safe-mode*'
# Inside a nested call the gate does nothing, whatever the reader would have said.
export WRITING_CONVENTIONS_NESTED=1
expect 0 no 'VIOLATION
"The report says so" -> x' 0 "$says"
unset WRITING_CONVENTIONS_NESTED

# MCP calls. The trigger is a lookup of the tool name in a per-user cache that a
# classifier call fills, so no server or tool name is written in the gate.
export CLAUDE_CONFIG_DIR="$scratch/config"
# mcp <exit> <classifier calls> <reader calls> <class> <verdict> <hook input>
mcp() {
  cases=$((cases + 1))
  : > "$GATE_TEST_MARK"
  export GATE_TEST_CLASS="$4" GATE_TEST_VERDICT="$5" GATE_TEST_FAIL=0
  stderr=$(printf '%s' "$6" | bash "$HERE/gate.sh" 2>&1 >/dev/null)
  status=$?
  [ "$status" = "$1" ] || { echo "FAIL exit $status, wanted $1: $6"; fail=1; }
  c=$(grep -c classify-prompt.md "$GATE_TEST_MARK"); r=$(grep -c gate-prompt.md "$GATE_TEST_MARK")
  [ "$c $r" = "$2 $3" ] || { echo "FAIL classifier and reader calls $c $r, wanted $2 $3: $6"; fail=1; }
}
cachefile() { ls "$CLAUDE_CONFIG_DIR"/writing-conventions/mcp-tools-*.txt; }
jira='{"tool_name":"mcp__atlassian__createJiraIssue","tool_input":{"projectKey":"PLAT","summary":"Stale check","description":"The report says so."}}'
bitbucket='{"tool_name":"mcp__bitbucket__create_pull_request","tool_input":{"title":"Fix it","description":"The report says so."}}'
search='{"tool_name":"mcp__atlassian__searchJiraIssuesUsingJql","tool_input":{"jql":"text ~ \"The report says so.\""}}'
adf='{"tool_name":"mcp__atlassian__addCommentToJiraIssue","tool_input":{"issueKey":"PLAT-42","body":{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"The report "},{"type":"text","text":"says so.","marks":[{"type":"strong"}]}]}]}}}'
# A miss calls the classifier once, a repeat does not, and both inputs reach the reader.
mcp 0 1 1 CAN_PUBLISH PASS "$jira"
mcp 0 0 1 CAN_PUBLISH PASS "$jira"
mcp 2 1 1 CAN_PUBLISH 'VIOLATION
"The report says so." -> x' "$bitbucket"
case $stderr in *'make the call again'*) ;; *) echo "FAIL MCP reason: $stderr"; fail=1;; esac
# A tool classified NEVER makes no reader call, then or later.
mcp 0 1 0 NEVER PASS "$search"
mcp 0 0 0 NEVER PASS "$search"
# A sentence that a rich-text format splits across nodes is quoted as its pieces.
# Nothing is joined, so the whole sentence is in no source.
mcp 2 1 1 CAN_PUBLISH 'VIOLATION
"The report " + "says so." -> x' "$adf"
mcp 0 0 1 CAN_PUBLISH 'VIOLATION
"The report says so." -> x' "$adf"
mcp 0 0 1 CAN_PUBLISH 'VIOLATION
"The build decided" -> x' "$adf"
# Only the string values of tool_input are reviewed: not a key, not the tool name.
mcp 0 0 1 CAN_PUBLISH 'VIOLATION
"issueKey" -> x' "$adf"
mcp 0 0 1 CAN_PUBLISH 'VIOLATION
"addCommentToJiraIssue" -> x' "$adf"
# A value is decoded before it is searched: an escaped quote and an escaped newline.
mcp 2 0 1 CAN_PUBLISH 'VIOLATION
"The report says so." -> x' '{"tool_name":"mcp__atlassian__createJiraIssue","tool_input":{"description":"See \"the log\".\nThe report\nsays so."}}'
# In the cache, a CAN_PUBLISH line for a tool wins over a NEVER line for it, a
# malformed line is ignored, and a missing file is a miss.
printf '%s\n' 'mcp__x__post NEVER' 'mcp__x__post CAN_PUBLISH' 'mcp__x__odd MAYBE' 'mcp__x__odd' >> "$(cachefile)"
mcp 0 0 1 NEVER PASS '{"tool_name":"mcp__x__post","tool_input":{"text":"hi"}}'
mcp 0 1 1 CAN_PUBLISH PASS '{"tool_name":"mcp__x__odd","tool_input":{"text":"hi"}}'
rm -f "$(cachefile)"
mcp 0 1 1 CAN_PUBLISH PASS "$jira"
# A classifier reply in any other form is doubt: the reader runs and nothing is cached.
mcp 0 1 1 'It can publish.' PASS '{"tool_name":"mcp__x__vague","tool_input":{"text":"hi"}}'
mcp 0 1 1 CAN_PUBLISH PASS '{"tool_name":"mcp__x__vague","tool_input":{"text":"hi"}}'

# Prose files, after a Write or an Edit. Nothing is blocked: a verified finding
# comes back as additionalContext, and so does a statement of what was not read.
# file <reader calls> <pattern for the output> <verdict> <hook input>; the message
# the reader was sent is in $sent afterwards
file() {
  cases=$((cases + 1))
  : > "$GATE_TEST_MARK"; : > "$GATE_TEST_MARK.stdin"
  export GATE_TEST_VERDICT="$3" GATE_TEST_FAIL="${5:-0}"
  out=$(printf '%s' "$4" | bash "$HERE/gate.sh" --file 2>&1)
  status=$?
  sent=$(cat "$GATE_TEST_MARK.stdin")
  [ "$status" = 0 ] || { echo "FAIL exit $status, wanted 0: ${4:0:160}"; fail=1; }
  r=$(grep -c gate-prompt.md "$GATE_TEST_MARK")
  [ "$r" = "$1" ] || { echo "FAIL reader calls $r, wanted $1: ${4:0:160}"; fail=1; }
  case $out in $2) ;; *) echo "FAIL output, wanted $2: ${out:0:300}"; fail=1;; esac
}
edit() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"x","new_string":"%s"}}' "$1" "$2"; }
doc="$scratch/doc.md"
printf '# Title\n\nThe report says the version. It is short.\n\nSecond paragraph stays.\n\nThird one here.\n' > "$doc"
file 1 '' PASS "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$doc\",\"content\":\"# Title\\n\\nPlain text.\"}}"
case $sent in *'Plain text.'*) ;; *) echo "FAIL the content was not sent: $sent"; fail=1;; esac
file 0 '' PASS "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$scratch/Main.kt\",\"content\":\"// The report says so.\"}}"
file 1 '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"\\"Plain text.\\" -> x\\nFix the quoted text in *"}}' 'VIOLATION
"Plain text." -> x' "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$scratch/NOTES.RST\",\"content\":\"Plain text.\"}}"
# A one-word edit is reviewed as the whole paragraphs that hold it, so a finding can
# quote the sentence around the word, and the rest of the file is not sent.
file 1 '*The report says the version.*' 'VIOLATION
"The report says the version." -> x' "$(edit "$doc" says)"
case $sent in *'It is short.'*) ;; *) echo "FAIL the paragraph was not sent: $sent"; fail=1;; esac
case $sent in *'Third one'*) echo "FAIL another paragraph was sent: $sent"; fail=1;; esac
file 1 '' 'VIOLATION
"Third one here." -> x' "$(edit "$doc" says)"
# new_string can span paragraphs, and every paragraph it touches is reviewed.
file 1 '*paragraph stays.*' 'VIOLATION
"The report says" + "paragraph stays." -> x' "$(edit "$doc" 'It is short.\n\nSecond')"
# A small edit to a 900 KB file is reviewed by excerpt.
awk 'BEGIN { for (i = 0; i < 15000; i++) printf "Filler paragraph %d, sixty characters of plain text to pad.\n\n", i; print "The report says so." }' > "$scratch/big.md"
file 1 '*The report says so.*' 'VIOLATION
"The report says so." -> x' "$(edit "$scratch/big.md" 'says so')"
[ ${#sent} -lt 1000 ] || { echo "FAIL ${#sent} characters sent for a small edit"; fail=1; }
# What is not reviewed is stated: a file over 1 MB is not scanned, so new_string
# alone is read; a deletion; and the text past the cap.
cat "$scratch/big.md" "$scratch/big.md" > "$scratch/huge.md"
file 1 '*says so\\" -> x*over 1 MB*' 'VIOLATION
"says so" -> x' "$(edit "$scratch/huge.md" 'says so')"
file 0 '*Not reviewed*deleted*' PASS "$(edit "$doc" '')"
long=$(awk 'BEGIN { for (i = 0; i < 1000; i++) printf "Sixty characters of plain text, or near enough, to pad it. " }')
file 1 '*Only the first 50000 characters*' PASS "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$doc\",\"content\":\"$long\"}}"
[ ${#sent} -lt 51000 ] || { echo "FAIL ${#sent} characters sent past the cap"; fail=1; }
# A reader that cannot run says nothing, and the advisory nudge in lint.sh still fires.
file 2 '' '' "$(edit "$doc" says)" 1

# The first time in a session that a check cannot run, the user is told once, through
# systemMessage, which the user is shown and the model is not. The marker is a file
# named for the session, so another session gets its own notice, and input with no
# session id gets none, because nothing could stop it repeating.
export TMPDIR="$scratch/tmp"; mkdir -p "$TMPDIR"
# notice <pattern for stdout> <fail> <session id> [<command text>]
notice() {
  cases=$((cases + 1))
  export GATE_TEST_VERDICT=PASS GATE_TEST_FAIL="$2"
  out=$(printf '{"session_id":"%s","tool_input":{"command":"%s"}}' "$3" "${4:-git commit -m x}" | bash "$HERE/gate.sh" 2>/dev/null)
  status=$?
  [ "$status" = 0 ] || { echo "FAIL exit $status, wanted 0: notice $2 $3"; fail=1; }
  case $out in $1) ;; *) echo "FAIL notice for $2 $3, wanted $1: $out"; fail=1;; esac
}
notice '{"systemMessage":"*model review is off*"}' 1 s1
notice '' 1 s1
notice '{"systemMessage":"*"}' 1 s2
# A session in which the retry succeeded gets none, and neither does a passing one.
notice '' safe s3
notice '' 0 s3
notice '' 1 ''
# No `claude` on the path is the same failure, but only for a command that needed it.
realpath=$PATH; PATH=/usr/bin:/bin
notice '' 1 s4 'ls -la'
notice '{"systemMessage":"*"}' 1 s4
notice '' 1 s4
PATH=$realpath
unset TMPDIR

# Stop replies. Only the text a `draft` fence holds is reviewed, and a reply with
# no such fence costs no call at all. A blocked reply is re-emitted whole, so the
# blocking is counted per turn and stops after two.
export TMPDIR="$scratch/stoptmp"; mkdir -p "$TMPDIR"
V='VIOLATION
"The report says so." -> The version is shown in the report.'
V2='VIOLATION
"The build decided it." -> x'
# stopcase <exit> <called> <verdict> <prompt_id> <reply, with \n for a newline>
# Afterwards: $out is stdout, $stderr the reason, $sent what the reader was given.
stopcase() {
  cases=$((cases + 1))
  : > "$GATE_TEST_MARK"; : > "$GATE_TEST_MARK.stdin"
  export GATE_TEST_VERDICT="$3" GATE_TEST_FAIL="${6:-0}"
  out=$(printf '{"session_id":"stopsess","prompt_id":"%s","last_assistant_message":"%s"}' "$4" "$5" \
    | bash "$HERE/gate.sh" --stop 2>"$scratch/err")
  status=$?
  stderr=$(cat "$scratch/err"); sent=$(cat "$GATE_TEST_MARK.stdin")
  called=$([ -s "$GATE_TEST_MARK" ] && echo yes || echo no)
  [ "$status" = "$1" ] || { echo "FAIL exit $status, wanted $1: $5"; fail=1; }
  [ "$called" = "$2" ] || { echo "FAIL model called=$called, wanted $2: $5"; fail=1; }
}
# No fence, and a fence that is not a draft, make no call.
stopcase 0 no "$V" s01 'Here it is. The report says so.'
stopcase 0 no "$V" s02 'Here it is.\n\n```python\nThe report says so.\n```'
# A draft fence is read, and the reader is sent the draft and nothing else.
stopcase 2 yes "$V" s03 'Outside text.\n\n```draft\nThe report says so.\n```'
case $stderr in *'emit the corrected draft'*) ;; *) echo "FAIL stop reason: $stderr"; fail=1;; esac
case $sent in *'Outside text'*) echo "FAIL text outside the fence was sent: $sent"; fail=1;; esac
# A finding that quotes text outside every draft fence is unverified, so prose the
# model was never sent cannot block the reply.
stopcase 0 yes "$V" s04 'The report says so.\n\n```draft\nPlain text.\n```'
# A four-backtick fence is closed by its own marker, so a code fence inside a draft
# does not end it, and a tilde fence is a fence.
stopcase 2 yes "$V" s05 '````draft\nPlain text.\n\n```py\nx = 1\n```\n\nThe report says so.\n````'
stopcase 2 yes "$V" s06 '~~~draft\nThe report says so.\n~~~'
# Two draft fences are two sources: one quote cannot span both, and a two-fragment
# finding that quotes each of them can.
two='```draft\nThe report \n```\n\nAnd the second:\n\n```draft\nsays so.\n```'
stopcase 0 yes "$V" s07 "$two"
stopcase 2 yes 'VIOLATION
"The report" + "says so." -> x' s08 "$two"
# A malformed first line never blocks.
stopcase 0 yes 'VIOLATION MAYBE
"The report says so." -> x' s09 '```draft\nThe report says so.\n```'
# Two blocks in one turn, then the user is told that review is unresolved. An
# unchanged rewrite blocks the second time, and a violation the rewrite introduced
# counts as an attempt just the same.
draft1='```draft\nThe report says so.\n```'
stopcase 2 yes "$V" s10 "$draft1"
stopcase 2 yes "$V" s10 "$draft1"
stopcase 0 yes "$V" s10 "$draft1"
case $out in '{"systemMessage":"'*'Review is unresolved'*) ;; *) echo "FAIL unresolved notice: $out"; fail=1;; esac
stopcase 2 yes "$V" s11 "$draft1"
stopcase 2 yes "$V2" s11 '```draft\nThe build decided it.\n```'
stopcase 0 yes "$V2" s11 '```draft\nThe build decided it.\n```'
case $out in *'Review is unresolved'*) ;; *) echo "FAIL unresolved notice after a new violation: $out"; fail=1;; esac
# The count is per turn, so the next turn starts over.
stopcase 2 yes "$V" s12 "$draft1"
# stop_hook_active is another plugin's flag, and this script keeps its own count.
cases=$((cases + 1))
: > "$GATE_TEST_MARK"; export GATE_TEST_VERDICT="$V" GATE_TEST_FAIL=0
printf '{"prompt_id":"s13","stop_hook_active":true,"last_assistant_message":"%s"}' "$draft1" \
  | bash "$HERE/gate.sh" --stop >/dev/null 2>&1
[ $? = 2 ] || { echo "FAIL no block with stop_hook_active already true"; fail=1; }
# With no prompt_id there is nothing to count with, so nothing is blocked and no
# call is made.
cases=$((cases + 1))
: > "$GATE_TEST_MARK"
printf '{"last_assistant_message":"%s"}' "$draft1" | bash "$HERE/gate.sh" --stop >/dev/null 2>&1
status=$?
[ "$status" = 0 ] || { echo "FAIL exit $status with no prompt_id"; fail=1; }
[ -s "$GATE_TEST_MARK" ] && { echo "FAIL model called with no prompt_id"; fail=1; }
# The off switch skips the reader and leaves the reply lint as the only check.
cases=$((cases + 1))
: > "$GATE_TEST_MARK"
printf '{"prompt_id":"s14","last_assistant_message":"%s"}' "$draft1" \
  | WRITING_CONVENTIONS_STOP_READER=0 bash "$HERE/gate.sh" --stop >/dev/null 2>&1
status=$?
[ "$status" = 0 ] || { echo "FAIL exit $status with the reader off"; fail=1; }
[ -s "$GATE_TEST_MARK" ] && { echo "FAIL model called with the reader off"; fail=1; }
# A reader that cannot run does not block the reply, and says so once.
stopcase 0 yes "$V" s15 "$draft1" 1
case $out in '{"systemMessage":"'*'model review is off'*) ;; *) echo "FAIL stop notice: $out"; fail=1;; esac
# The cap comes off the drafts before the reader is sent them and before a finding
# is checked, so a quote from past it is a quote of text that was never reviewed.
pad=$(awk 'BEGIN { for (i = 0; i < 1000; i++) printf "Sixty characters of plain text, or near enough, to pad it. " }')
stopcase 0 yes "$V2" s17 '```draft\n'"$pad"'\nThe build decided it.\n```'
[ ${#sent} -lt 51000 ] || { echo "FAIL ${#sent} characters sent past the cap"; fail=1; }
stopcase 2 yes "$V2" s18 '```draft\nThe build decided it.\n\n'"$pad"'\n```'

# A closing fence takes no info string, so a line inside a draft that starts with
# the marker and goes on does not end the draft, and what follows is still read.
stopcase 2 yes "$V2" s19 '```draft\nThe report says so.\n``` and more\nThe build decided it.\n```'
# The count has to fail open. A state file that cannot be written would otherwise
# leave the count at nothing and block every Stop call of the turn.
mkdir -p "$TMPDIR/claude-gate-stop-s20"
stopcase 0 yes "$V" s20 "$draft1"
case $out in *'could not be written'*) ;; *) echo "FAIL no notice for an unwritable count: $out"; fail=1;; esac
# A count file another program wrote is not room for another block.
printf ' 2 \n' > "$TMPDIR/claude-gate-stop-s21"
stopcase 0 yes "$V" s21 "$draft1"
case $out in *'after two rewrites'*) ;; *) echo "FAIL no notice for a padded count: $out"; fail=1;; esac
printf 'abc' > "$TMPDIR/claude-gate-stop-s22"
stopcase 0 yes "$V" s22 "$draft1"
case $out in *'after two rewrites'*) ;; *) echo "FAIL no notice for a garbage count: $out"; fail=1;; esac

# A draft left open at the end of the reply runs to the end.
stopcase 2 yes "$V" s23 'x\n```draft\nThe report says so.\n'
case $sent in 'The report says so.'*) ;; *) echo "FAIL unterminated draft sent as [$sent]"; fail=1;; esac

# Inside a nested call this entry point does nothing either.
cases=$((cases + 1))
: > "$GATE_TEST_MARK"
printf '{"prompt_id":"s16","last_assistant_message":"%s"}' "$draft1" \
  | WRITING_CONVENTIONS_NESTED=1 bash "$HERE/gate.sh" --stop >/dev/null 2>&1
status=$?
[ "$status" = 0 ] || { echo "FAIL exit $status inside a nested call"; fail=1; }
[ -s "$GATE_TEST_MARK" ] && { echo "FAIL model called inside a nested call"; fail=1; }
unset TMPDIR

# Garbage in place of the hook input is not a reason to block either.
cases=$((cases + 1))
printf 'not json at all {{{' | bash "$HERE/gate.sh" >/dev/null 2>&1 \
  || { echo "FAIL garbage input exit $?"; fail=1; }
cases=$((cases + 1))
printf 'not json at all {{{' | bash "$HERE/gate.sh" --stop >/dev/null 2>&1 \
  || { echo "FAIL garbage input on --stop exit $?"; fail=1; }

[ $fail -eq 0 ] && echo "PASS ($cases cases)" || { echo "FAILED"; exit 1; }
