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
expect 0 no CLEAN 0 'ls -la'
expect 0 no CLEAN 0 'git log --grep=commit'
expect 0 no CLEAN 0 'gh repo view'
# The four publishing families do, git -C included: no `if` pattern matches that
# one, which is why the command text is matched here instead.
expect 0 yes CLEAN 0 'git commit -m \"Plain message\"'
expect 0 yes CLEAN 0 'git -C /tmp/wt commit -m \"Plain message\"'
expect 0 yes CLEAN 0 'gh pr create --title x --body y'
expect 0 yes CLEAN 0 'gh issue comment 1 --body y'
expect 0 yes CLEAN 0 'gh release create v1 --notes y'
# A quoted violation blocks the command and comes back as the reason.
cases=$((cases + 1))
run 'the report says: rewrite it' 0 'git commit -m \"The report says so\"'
[ "$status" = 2 ] || { echo "FAIL violation exit $status, wanted 2"; fail=1; }
case $stderr in *'rewrite it'*) ;; *) echo "FAIL violation reason: $stderr"; fail=1;; esac
# A gate that cannot reach a model must not stop a commit.
expect 0 yes '' 1 'git commit -m \"Plain message\"'
expect 0 yes '' 0 'git commit -m \"Plain message\"'
# Garbage in place of the hook input is not a reason to block either.
cases=$((cases + 1))
printf 'not json at all {{{' | bash "$HERE/gate.sh" >/dev/null 2>&1 \
  || { echo "FAIL garbage input exit $?"; fail=1; }

[ $fail -eq 0 ] && echo "PASS ($cases cases)" || { echo "FAILED"; exit 1; }
