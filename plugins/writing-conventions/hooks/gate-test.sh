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

# Garbage in place of the hook input is not a reason to block either.
cases=$((cases + 1))
printf 'not json at all {{{' | bash "$HERE/gate.sh" >/dev/null 2>&1 \
  || { echo "FAIL garbage input exit $?"; fail=1; }

[ $fail -eq 0 ] && echo "PASS ($cases cases)" || { echo "FAILED"; exit 1; }
