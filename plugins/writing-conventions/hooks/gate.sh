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
# A gate that cannot reach a model must not stop a commit, so every failure path
# exits 0. Only a finding with its quote in the text under review exits 2, which
# blocks the command or the call and hands the text back to the session.

# Managed policy settings still apply under `--safe-mode`, so a copy of this hook
# registered that way runs inside the nested call. The call below sets this marker
# on its child, and nothing here is worth doing for the reader's own session.
[ -z "$WRITING_CONVENTIONS_NESTED" ] || exit 0

# See lint.sh for this handoff to gate.ps1.
if [ "$OS" = Windows_NT ] && [ "$CLAUDE_CODE_USE_POWERSHELL_TOOL" = 1 ] \
   && command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoProfile -File "$(dirname "$0")/gate.ps1" "$@"
fi
HERE=$(cd "$(dirname "$0")" && pwd)
input=$(cat)

# ask <system prompt> [<file appended to it>]: the reply to one nested call on
# $msg, or on the hook input when $msg is empty, and non-zero when the call exits
# non-zero, was killed at its time limit, or was not started for lack of time.
# With no `claude` on the path there is no call, which is the same failure.
ask() {
  command -v claude >/dev/null 2>&1 || return 1
  call --safe-mode "$@"
}
# A command can need a classifier call and then a reader call, so each call gets
# the smaller of 60 seconds and the time left less 10, and none starts with under
# 15. The deadline for each branch is 15 seconds short of its hook timeout in
# hooks.json, so that a killed call, the cleanup, and the notice fit inside it;
# gate-test.sh checks the two agree. macOS has no `timeout`, so the call runs in a
# process group of its own, and a watcher kills the group at the limit.
DEADLINES='shell=165 mcp=75 file=45 stop=45'
call() {
  lim=$((deadline - SECONDS - 10))
  [ $lim -gt 60 ] && lim=60
  [ $lim -ge 15 ] || return 124
  printf '%s' "${msg:-$input}" > "$tmp/in"
  rm -f "$tmp/killed"
  set -m
  WRITING_CONVENTIONS_NESTED=1 claude -p "$1" --tools= \
    --model "${WRITING_CONVENTIONS_GATE_MODEL:-sonnet}" \
    --system-prompt-file "$HERE/$2" \
    ${3:+--append-system-prompt-file "$HERE/$3"} < "$tmp/in" > "$tmp/out" 2>/dev/null &
  pid=$!
  (sleep $lim; : > "$tmp/killed"; kill -TERM -- -$pid; sleep 2; kill -KILL -- -$pid) >/dev/null 2>&1 &
  watch=$!
  set +m
  { wait $pid; rc=$?; } 2>/dev/null
  kill -- -$watch 2>/dev/null
  [ -e "$tmp/killed" ] && return 124
  [ $rc = 0 ] && cat "$tmp/out"
  return $rc
}

tmp=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$tmp"' EXIT
CAP=50000

# field <key>: one string field of the hook input, decoded
field() { printf '%s' "$input" | awk -v key="$1" -f "$HERE/jsonstr.awk"; }
# context [<event>]: stdin as the additionalContext of a PostToolUse hook, or of
# the event given, JSON-escaped. The text is split and joined, because what a
# backslash means in the replacement of a gsub differs from one awk to the next.
context() {
  awk -v ev="${1:-PostToolUse}" 'function rep(s, from, to,    n, a, i, out) { n = split(s, a, from); out = a[1]; for (i = 2; i <= n; i++) out = out to a[i]; return out }
    { gsub(/[\001-\010\013-\037]/, ""); text = text (NR > 1 ? "\\n" : "") rep(rep(rep($0, "\\", "\\\\"), "\"", "\\\""), "\t", "\\t") }
    END { if (text != "") printf "{\"hookSpecificOutput\":{\"hookEventName\":\"%s\",\"additionalContext\":\"%s\"}}", ev, text }'
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

# shellclass: return when the command in $cmd goes to the reader, and exit 0 when
# it does not. Any other command is split into keys by keys.awk and walked
# through a per-user cache of answers from a classifier call, so no command name
# beyond the four families is written here. The cache is read and written like
# the MCP cache below, one line per answer, <scope><TAB><class><TAB><key>, and a
# key below a task runner or under a path is kept per project. One call answers
# every key the cache has no line for, and a key it leaves out, or answers in any
# other form, is doubt: it reads as CAN_PUBLISH and is not kept.
shellclass() {
  mode=bash; [ "$tool" = PowerShell ] && mode=pwsh
  printf '%s' "$cmd" | awk -v mode=$mode -f "$HERE/keys.awk" > "$tmp/keys"
  proj=${CLAUDE_PROJECT_DIR:-$(field cwd)}
  dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/writing-conventions"
  cache="$dir/shell-commands-$(cksum < "$HERE/classify-command.md" | awk '{print $1}').txt"
  [ -f "$cache" ] && known=$cache || known=/dev/null
  walk=$(awk -v keys="$tmp/keys" -v scope="${proj:-/}" -f "$HERE/walk.awk" "$known")
  case $walk in READER) return ;; SAFE) exit 0 ;; esac
  printf '%s\n' "$walk" | awk -F '\t' '$1 == "ASK"' > "$tmp/ask"
  msg=$(printf '%s\n\n' "$cmd"; awk -F '\t' '!seen[$3]++ { print $3 }' "$tmp/ask")
  reply=$(ask classify-command.md) || off
  msg=
  printf '%s\n' "$reply" | awk -F '\t' -v OFS='\t' '
    FNR == NR { want[$3] = want[$3] SUBSEP $2; next }
    match($0, /[ \t]+(NEVER|CAN_PUBLISH|DESCEND|PROJECT|RUNS_CODE)\r?$/) {
      key = substr($0, 1, RSTART - 1); c = substr($0, RSTART); gsub(/[ \t\r]/, "", c)
      if (!(key in want)) next
      n = split(substr(want[key], 2), sc, SUBSEP)
      for (i = 1; i <= n; i++) print sc[i], c, key
      delete want[key]
    }' "$tmp/ask" - > "$tmp/answers"
  [ -s "$tmp/answers" ] && mkdir -p "$dir" && cat "$tmp/answers" >> "$cache"
  walk=$(awk -v keys="$tmp/keys" -v scope="${proj:-/}" -v final=1 -f "$HERE/walk.awk" "$known" "$tmp/answers")
  [ "$walk" = SAFE ] && exit 0
}

# bodies: copy each file the command in $cmd passes a commit, PR, issue, or
# release body in to $tmp/body.<n>, and add a line to $unread for each one that
# is not read. keys.awk finds the files, from the flags written down there, and
# the reader never chooses one. A file is read only when the text on disk is
# the text the command will publish, as far as a script can tell: a literal path
# that no other word of the command names, since a command that writes the file
# first publishes other text; relative to the directory the command starts in,
# with no cd and no git -C; a readable regular file, not a link, in the project
# or a temporary directory; and at most 1 MB with no NUL in its first 8 KB. Up to 4
# files are read, with $CAP characters in all.
bodies() {
  base=$(field cwd); base=${base:-$PWD}
  m=bash; [ "$tool" = PowerShell ] && m=pwsh
  printf '%s' "$cmd" | awk -v mode=$m -v files=1 -f "$HERE/keys.awk" > "$tmp/files"
  n=0; total=0
  while IFS="$(printf '\t')" read -r moved op; do
    why=
    case $op in
      ''|*[!A-Za-z0-9._/+@,:=-]*) why='it is not a literal path' ;;
      /*) path=$op ;;
      *) path=$base/$op; [ "$moved" = 1 ] && why='the command may change directory first' ;;
    esac
    if [ -z "$why" ] && [ "$(printf '%s' "$cmd" | awk -v b="${op##*/}" '{ t = t $0 "\n" }
         END { while (i = index(t, b)) { n++; t = substr(t, i + length(b)) } print n + 0 }')" -gt 1 ]; then
      why='the command names it more than once, so it may write the file before reading it'
    fi
    if [ -z "$why" ]; then
      if [ -L "$path" ] || [ ! -f "$path" ]; then
        why='it is not a regular file'
      elif [ ! -r "$path" ]; then
        why='it cannot be read'
      else
        dir=$(cd "$(dirname "$path")" && pwd -P)
        why='it is outside the project and the temporary directory'
        for r in "${CLAUDE_PROJECT_DIR:-$base}" "${TMPDIR:-/tmp}" /tmp; do
          r=$(cd "$r" 2>/dev/null && pwd -P) || continue
          case "$dir/" in "${r%/}"/*) why= ;; esac
        done
        size=$(wc -c < "$path")
        if [ -n "$why" ]; then :
        elif [ "$size" -gt 1048576 ]; then why='it is over 1 MB'
        elif [ "$(head -c 8192 "$path" | tr -d '\000' | wc -c)" -ne "$(head -c 8192 "$path" | wc -c)" ]; then why='it is not text'
        elif [ $n -ge 4 ] || [ $((total + size)) -gt $CAP ]; then why="the gate reads at most 4 body files and $CAP characters"
        fi
      fi
    fi
    if [ -n "$why" ]; then
      unread="${unread}The body in $op was not read: $why.
"
    else
      n=$((n + 1)); total=$((total + size))
      cp "$path" "$tmp/body.$n"; printf '%s' "$op" > "$tmp/name.$n"
    fi
  done < "$tmp/files"
  [ $n = 0 ] && return
  msg=$(printf '%s' "$input"; i=1
    while [ $i -le $n ]; do printf '\n\nFile: %s\n\n' "$(cat "$tmp/name.$i")"; cat "$tmp/body.$i"; i=$((i + 1)); done)
}

tool=$(field tool_name)
case "$1:$tool" in --stop:*) b=stop ;; --file:*) b=file ;; :mcp__*) b=mcp ;; *) b=shell ;; esac
for d in $DEADLINES; do case $d in "$b="*) deadline=${d#*=} ;; esac; done
# The self-test sets a short deadline, to reach a time limit in seconds.
deadline=${WRITING_CONVENTIONS_GATE_DEADLINE:-$deadline}
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
    # prompt_id, which is the same on every Stop call of one turn. Codex sends
    # turn_id instead. With neither, nothing can be counted, so nothing is
    # blocked and a call would buy nothing.
    pid=$(field prompt_id | tr -c 'A-Za-z0-9_-' '_')
    [ -n "$pid" ] || pid=$(field turn_id | tr -c 'A-Za-z0-9_-' '_')
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
  --file:apply_patch)
    # Codex writes files with one patch, which can add, update, or move several.
    # Each prose file in it is reviewed as the paragraphs that hold the lines the
    # patch added, read from the file as patched.
    field command | awk -v cwd="$(field cwd)" -v out="$tmp" -f "$HERE/patch.awk"
    : > "$tmp/text"; : > "$tmp/msg"; path=; unread=; i=0
    while [ -e "$tmp/path.$((i + 1))" ]; do
      i=$((i + 1)); p=$(cat "$tmp/path.$i")
      case "$(printf '%s' "$p" | tr 'A-Z' 'a-z')" in
        *.md|*.markdown|*.txt|*.adoc|*.rst) ;;
        *) continue ;;
      esac
      if ! grep -q '[^[:space:]]' "$tmp/new.$i"; then
        unread="$unread${unread:+
}Not reviewed: this edit to $p only deleted text."
        continue
      fi
      : > "$tmp/part"
      if [ -f "$p" ] && [ "$(wc -c < "$p")" -le 1048576 ]; then
        awk -v cap=$CAP -v lines=1 -f "$HERE/excerpt.awk" "$tmp/new.$i" "$p" > "$tmp/part"
      fi
      if [ ! -s "$tmp/part" ]; then
        cp "$tmp/new.$i" "$tmp/part"
        unread="$unread${unread:+
}Only the new text was reviewed, not the sentences around it: $p is over 1 MB or could not be read."
      fi
      { printf 'File: %s\n\n' "$p"; cat "$tmp/part"; echo; } >> "$tmp/msg"
      cat "$tmp/part" >> "$tmp/text"
      path="$path${path:+, }$p"
    done
    if [ -z "$path" ]; then
      [ -z "$unread" ] || printf '%s\n' "$unread" | context
      exit 0
    fi
    if [ "$(wc -c < "$tmp/msg")" -gt $CAP ]; then
      head -c $CAP "$tmp/msg" > "$tmp/cut" && mv "$tmp/cut" "$tmp/msg"
      unread="$unread${unread:+
}Only the first $CAP characters of the text were reviewed."
    fi
    msg=$(cat "$tmp/msg")
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
    # Four command families always reach the reader, whatever is cached, so a
    # wrong NEVER from the classifier can never lose them. Matching the command
    # text here rather than through a hook `if` pattern covers `git -C <path>
    # commit`, which no `Bash(git commit *)` rule matches.
    cmd=$(printf '%s' "$input" | awk -v key=command -f "$HERE/jsonstr.awk")
    case "$cmd" in
      *"git commit"*|*"git -C"*commit*|*"gh pr "*|*"gh issue "*|*"gh release "*) ;;
      *) [ "$WRITING_CONVENTIONS_SHELL_CLASSIFIER" = 0 ] && exit 0
         shellclass ;;
    esac
    unread=
    bodies
    sources() { printf '%s' "$cmd"; }
    again='run the command again' ;;
esac
verdict=$(ask gate-prompt.md rules.md) || off

# verdict.awk keeps the findings that quote the text under review. A reply in any
# other form is a failure path, so it lets the command through as well.
sources > "$tmp/source"
printf '%s\n' "$verdict" > "$tmp/verdict"
set -- "$tmp/source"
for f in "$tmp"/body.*; do [ -e "$f" ] && set -- "$@" "$f"; done
findings=$(awk -v verdict="$tmp/verdict" -f "$HERE/verdict.awk" "$@" "$tmp/verdict")
if [ -z "$again" ]; then
  # A file is cheap to fix after the fact and a blocked edit stops the turn, so
  # this path hands the findings back and blocks nothing.
  { [ -z "$findings" ] || printf '%s\nFix the quoted text in %s. Each rewrite after -> is only a suggestion; where one reads stiffly, write the sentence the way a person would say it.\n' "$findings" "$path"
    [ -z "$unread" ] || printf '%s\n' "$unread"; } | context
  exit 0
fi
if [ -z "$findings" ]; then
  [ -z "$unread" ] || printf '%s' "$unread" | context PreToolUse
  exit 0
fi
if [ -n "$stop" ]; then
  # A blocked Stop costs a whole re-emitted reply, so a reader that keeps
  # finding something in each rewrite is stopped after two: the user is told
  # that review is unresolved, through systemMessage, and the reply stands.
  # Anything in the file other than 0 or 1 counts as two, so a file another
  # program wrote cannot be read as room for another block.
  n=$(cat "$stop" 2>/dev/null)
  case $n in '') n=0 ;; 0|1) ;; *) n=2 ;; esac
  if [ "$n" -ge 2 ]; then
    printf '{"systemMessage":"writing-conventions: the draft in this reply still reads as a violation after two rewrites. Review is unresolved and the reply stands."}'
    exit 0
  fi
  # A count that cannot be kept is no count at all, and blocking on it would
  # re-emit the reply on every Stop call of the turn: an unwritable temporary
  # directory, a prompt_id too long for a filename, or something else already at
  # the path. So the write is read back, and a failure lets the reply stand. The
  # subshell keeps the shell's own redirection error out of the reason text.
  ( printf '%s' $((n + 1)) > "$stop" ) 2>/dev/null
  if [ "$(cat "$stop" 2>/dev/null)" != "$((n + 1))" ]; then
    printf '{"systemMessage":"writing-conventions: the draft in this reply reads as a violation, and the count that bounds a second look could not be written to %s. Review is unresolved and the reply stands."}' "${TMPDIR:-/tmp}"
    exit 0
  fi
fi
printf '%s\nRewrite the quoted text and %s. Each rewrite after -> is only a suggestion; where one reads stiffly, write the sentence the way a person would say it.\n%s' "$findings" "$again" "$unread" >&2
exit 2
