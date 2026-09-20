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
printf 'called\n' >> "$GATE_TEST_MARK"
[ "$GATE_TEST_FAIL" = 1 ] && exit 1
printf '%s\n' "$GATE_TEST_VERDICT"
STUB
chmod +x "$scratch/claude"
PATH="$scratch:$PATH"
unset CLAUDE_CODE_USE_POWERSHELL_TOOL WRITING_CONVENTIONS_GATE_MODEL
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
# Garbage in place of the hook input is not a reason to block either.
cases=$((cases + 1))
printf 'not json at all {{{' | bash "$HERE/gate.sh" >/dev/null 2>&1 \
  || { echo "FAIL garbage input exit $?"; fail=1; }

[ $fail -eq 0 ] && echo "PASS ($cases cases)" || { echo "FAILED"; exit 1; }
