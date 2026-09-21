# Split a shell command into the keys the gate looks up to decide whether the
# command can publish, with no command name written down here.
#   awk -v mode=bash -f keys.awk     the command on stdin, from the Bash tool
#   awk -v mode=pwsh -f keys.awk     the same, from the PowerShell tool
#   awk -v files=1 ...               the body files instead of the keys (below)
# keys.ps1 is the same extractor, and shell-keys.tsv is the fixture both are
# tested against, so a rule changed here is changed there in the same commit.
#
# The output is one line per entry, <segment number><TAB><entry>, where a
# segment is one simple command. An entry is one of:
#   git commit      a key: the first word, then up to two subcommand candidates
#   git ?           a word at that depth under "git" that cannot be read as a name
#   +make check     a task name under "make", read only when "make" is a PROJECT
#   +make ?         a task word under "make" that cannot be read as a name
#   +make !         more than 8 task names under "make"
#   READ            the segment, or the whole command as segment 1, goes to the
#                   reader with no lookup
# A segment with no command in it has no lines. One more line, 0<TAB>PROSE,
# comes first when there is a sentence in the command: a capitalized word, at
# least four more words, and a last word ending in ".", "!", or "?". The gate
# reads a RUNS_CODE command, an interpreter or curl, only with that line.
#
# With files=1 the output is instead one line per operand of a body-file flag in
# a git commit or a gh pr, issue, or release command, <cd><TAB><operand>, where
# <cd> is 1 when the command may run it in another directory than the one it
# starts in: git -C, or cd and the like anywhere in the command. The flags are
# written down here, per command, because a word is an operand only when no
# earlier flag takes it as its value. An operand of "-" is stdin, which is the
# heredoc already in the command, and is left out. A command that cannot be split
# prints 1<TAB>"" when it has a body-file flag at all, so that the gate reports it.
#
# The rules are a character loop with no grammar, so that keys.ps1 can follow it
# line for line. The text is read twice. Pass 1 drops heredoc bodies and turns a
# quoted span into its content, or into the placeholder "" when the content has
# whitespace or a separator in it, then splits on separators. Pass 2 drops
# single-quoted spans and heredoc bodies but keeps double-quoted ones, finds each
# $( ) and backtick substitution in what is left, and reads each one's body as
# pass 1 does. That is how `grep "$(gh issue comment 1 --body x)"` yields the gh
# command even though pass 1 turned the quoted text into "".

{ src = src (NR > 1 ? "\n" : "") $0 }

END {
  pwsh = (mode == "pwsh")
  esc = pwsh ? "`" : "\\"
  sepchars = pwsh ? "\n;&|()" : "\n;&|()`"
  # A first word must be made of these, and in PowerShell a path may use "\".
  # The characters scan() stops at.
  special = pwsh ? "[\n`#'\"@]" : "[\n\\\\#'\"<]"
  namechars = pwsh ? "^[A-Za-z0-9._+:/$\\\\-]+$" : "^[A-Za-z0-9._+:/$-]+$"
  split("! if then elif else fi do done while until time esac { }", a, " ")
  for (i in a) shellword[a[i]] = 1
  # Wrappers that run the command after them: the first set takes only flags, and
  # the second one operand too, as in `timeout 60 hg commit`.
  split("env sudo doas nice nohup exec command builtin setsid stdbuf setarch unbuffer catchsegv", a, " ")
  for (i in a) wrapper[a[i]] = 1
  split("timeout flock chrt taskset", a, " ")
  for (i in a) wrapper1[a[i]] = 1
  split("for case select in", a, " ")
  for (i in a) header[a[i]] = 1

  w = "[ \t]+[A-Za-z][A-Za-z'-]*[,;:]?"
  if (src ~ ("(^|[^A-Za-z0-9_])[A-Z][a-z'-]*[,;:]?" w w w w "(" w ")*[ \t]+[A-Za-z][A-Za-z'-]*[.!?]")) print "0\tPROSE"
  bad = 0
  scan(src)
  if (!bad) {
    nseg = 0
    addsegments(collapse(P1))
    subst(P2)
  }
  if (files) {
    if (bad) { if (src ~ /(^|[ \t])(-[A-Za-z]*F|--(body-|notes-)?file)/) print "1\t\"\""; exit }
    for (i = 1; i <= NBF; i++) if (!seenbf[BF[i]]++) print (CHDIR || BC[i]) "\t" BF[i]
    exit
  }
  if (bad) { print "1\tREAD"; exit }
  n = 0
  for (s = 1; s <= nseg; s++) {
    if (seen[segtext[s]]++) continue
    n++
    m = split(segtext[s], out, "\n")
    for (i = 1; i <= m; i++) print n "\t" out[i]
  }
}

# scan(s): set P1 and P2 for the text s, and set bad when a quote, a heredoc, or
# a here-string is left open, or when an expanding heredoc body holds a
# substitution. A quoted heredoc body, like single-quoted text, expands nothing.
function scan(s,    n, i, c, d, j, content, p2c, atword, npend, k, line, e, body, w, dash, quoted, start, run) {
  P1 = ""; P2 = ""
  n = length(s); i = 1; atword = 1; npend = 0
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\n") {
      P1 = P1 c; P2 = P2 c; i++; atword = 1
      # The bodies of the heredocs opened on the line just ended.
      for (k = 1; k <= npend; k++) {
        while (1) {
          if (i > n) { bad = 1; return }
          e = nextat(s, i, "\n", n)
          line = substr(s, i, e - i)
          i = e + 1
          if (pk[k] == "pwsh") {
            if (substr(line, 1, 2) == pw[k] "@") break
          } else {
            if (pd[k]) sub(/^\t+/, "", line)
            if (line == pw[k]) break
          }
          if (!pq[k] && (index(line, "$(") || (!pwsh && index(line, "`")))) { bad = 1; return }
        }
      }
      npend = 0
      continue
    }
    if (c == esc) {
      d = substr(s, i + 1, 1); i += 2
      if (d == "\n") { P1 = P1 " "; P2 = P2 " " }
      else if (d != "") { e = escaped(d); P1 = P1 e; P2 = P2 (index("$`\\\"'", d) ? "_" : e) }
      atword = 0; continue
    }
    if (c == "#" && atword) { i = nextat(s, i, "\n", n); continue }
    # Text is copied in runs, found with nextat(), not a character at a time:
    # appending one character at a time is quadratic, and so is substr() on a
    # long string in the awk macOS ships. A 100 KB argument took over a second.
    if (c == "'") {
      content = ""; j = i + 1; start = j
      while (1) {
        j = nextat(s, j, "'", n)
        if (j > n) { bad = 1; return }
        if (pwsh && substr(s, j + 1, 1) == "'") { content = content substr(s, start, j - start + 1); j += 2; start = j; continue }
        break
      }
      content = content substr(s, start, j - start)
      P1 = P1 quoted1(content); i = j + 1; atword = 0; continue
    }
    if (c == "\"") {
      content = ""; p2c = ""; j = i + 1; start = j
      while (1) {
        j = nextat(s, j, pwsh ? "[\"`]" : "[\"\\\\]", n)
        if (j > n) { bad = 1; return }
        d = substr(s, j, 1)
        if (d == esc) {
          e = substr(s, j + 1, 1)
          if (pwsh || index("$`\"\\\n", e)) {
            run = substr(s, start, j - start)
            content = content run (e == "\n" ? "" : e); p2c = p2c run "_"
            j += 2; start = j; continue
          }
        }
        if (d == "\"") {
          if (pwsh && substr(s, j + 1, 1) == "\"") {
            run = substr(s, start, j - start)
            content = content run "\""; p2c = p2c run "_"
            j += 2; start = j; continue
          }
          break
        }
        j++
      }
      run = substr(s, start, j - start)
      content = content run; p2c = p2c run
      P1 = P1 quoted1(content); P2 = P2 "\"" p2c "\""; i = j + 1; atword = 0; continue
    }
    if (!pwsh && substr(s, i, 2) == "<<" && substr(s, i, 3) != "<<<") {
      j = i + 2; dash = 0
      if (substr(s, j, 1) == "-") { dash = 1; j++ }
      while (substr(s, j, 1) == " " || substr(s, j, 1) == "\t") j++
      w = ""; quoted = 0
      while (j <= n) {
        d = substr(s, j, 1)
        if (index(" \t\n;&|()<>", d)) break
        if (d == "'" || d == "\"" || d == "\\") quoted = 1
        else w = w d
        j++
      }
      if (w != "") {
        npend++; pk[npend] = "bash"; pw[npend] = w; pq[npend] = quoted; pd[npend] = dash
        P1 = P1 "<<" w; P2 = P2 " "; i = j; atword = 0; continue
      }
    }
    if (pwsh && here(s, i)) {
      d = substr(s, i + 1, 1)
      npend++; pk[npend] = "pwsh"; pw[npend] = d; pq[npend] = (d == "'"); pd[npend] = 0
      P1 = P1 "\"\""; P2 = P2 "\"\""; i += 2; atword = 0; continue
    }
    # Anything else, up to the next character one of the branches above reads.
    j = nextat(s, i + 1, special, n)
    run = substr(s, i, j - i)
    P1 = P1 run; P2 = P2 run; i = j
    atword = (index(" \t;&|()", substr(run, length(run))) > 0)
  }
  if (npend) bad = 1
}

# nextat(s, j, re, n): the position of the first match of re at or after j, or
# n + 1. It looks in a window that grows, so that a match close by costs little
# however long s is.
function nextat(s, j, re, n,    w, t) {
  for (w = 256; ; w *= 4) {
    t = substr(s, j, w)
    if (match(t, re)) return j + RSTART - 1
    if (j + w > n) return n + 1
  }
}

# here(s, i): whether a PowerShell here-string opens at i, an @ and a quote with
# nothing but whitespace after them on the line.
function here(s, i,    rest) {
  if (substr(s, i, 1) != "@") return 0
  if (substr(s, i + 1, 1) != "\"" && substr(s, i + 1, 1) != "'") return 0
  rest = substr(s, i + 2)
  sub(/\n.*/, "", rest)
  return rest ~ /^[ \t\r]*$/
}

# An escaped character outside quotes is literal: whitespace, a separator, or a
# quote becomes "_" so that it neither splits nor quotes anything, and "*" with
# files=1, so that a body-file path with one in it reads as no literal path.
function escaped(d) { return index(" \t;&|(){}<>'\"`#$\\", d) ? (files ? "*" : "_") : d }

# Files mode, for one simple command: add the operand of its body-file flag to
# BF[], with NBF of them and BC[] set where git -C, --work-tree, or
# GIT_WORK_TREE runs the command elsewhere, or set CHDIR when the command
# changes directory. git and gh each read only the last such flag. A flag that
# is not written down here takes no value, and in a cluster of one-letter flags,
# a letter that takes a value takes the rest of the word or, when there is none,
# the next word. git's -S and -u take only a value in the same word.
function bodyfiles(w, m,    j, x, c, k, name, rest, cwd, vshort, vlong, bflag, opt, eq, v, last, found) {
  if (tolower(w[1]) ~ /^(cd|chdir|pushd|popd|sl|set-location|push-location|pop-location)$/) { CHDIR = 1; return }
  cwd = SEGWT; opt = ""; eq = 0; found = 0
  if (w[1] == "git") {
    for (j = 2; j <= m && w[j] ~ /^-/; j++) {
      if (w[j] == "-C" || w[j] ~ /^--work-tree(=|$)/) cwd = 1
      if (w[j] ~ /^(-C|-c|--git-dir|--work-tree|--namespace|--config-env|--attr-source)$/) j++
    }
    if (j > m || w[j] != "commit") return
    vshort = "mFCct"; opt = "Su"
    vlong = " --message --file --reuse-message --reedit-message --fixup --squash --author --date --cleanup --template --trailer --pathspec-from-file "
    # git takes an unambiguous prefix of a long flag, and --fi is ambiguous.
    bflag = " --file --fil "
  } else if (w[1] == "gh" && m >= 3 && w[2] ~ /^(pr|issue|release)$/ && w[3] ~ /^[a-z]/) {
    j = 3; eq = 1
    # From `gh <noun> <verb> --help`, gh 2.101, for every verb with a body flag,
    # and -R, --repo, on all of them.
    v = w[2] " " w[3]
    vshort = v == "pr create" ? "aBbFHlmprTt" : v == "pr edit" ? "BbFmt" : v == "pr merge" ? "AbFt" \
      : v == "pr revert" ? "bFt" : v == "issue create" ? "abFlmpTt" : v == "issue edit" ? "bFmt" \
      : w[2] == "release" ? "nFt" : "bF"
    vshort = vshort "R"
    vlong = " --add-assignee --add-blocked-by --add-blocking --add-label --add-project --add-reviewer --add-sub-issue --assignee --attach --author-email --base --blocked-by --blocking --body --body-file --discussion-category --head --label --match-head-commit --milestone --notes --notes-file --notes-start-tag --parent --project --recover --remove-assignee --remove-blocked-by --remove-blocking --remove-label --remove-project --remove-reviewer --remove-sub-issue --repo --reviewer --subject --tag --target --template --title --type "
    bflag = " --body-file --notes-file "
  } else return
  for (j++; j <= m; j++) {
    x = w[j]
    if (x == "--") break
    if (x !~ /^-./) continue
    if (x ~ /^--/) {
      k = index(x, "=")
      name = k ? substr(x, 1, k - 1) : x
      if (index(bflag, " " name " ")) {
        if (k) { last = substr(x, k + 1); found = 1 }
        else if (j < m) { last = w[++j]; found = 1 }
      } else if (!k && index(vlong, " " x " ")) j++
      continue
    }
    for (k = 2; k <= length(x); k++) {
      c = substr(x, k, 1)
      if (index(opt, c)) break
      if (!index(vshort, c)) continue
      rest = substr(x, k + 1)
      # gh drops the "=" in -F=file, and git keeps it as part of the name.
      if (c == "F") {
        if (rest != "") { if (eq) sub(/^=/, "", rest); last = rest; found = 1 }
        else if (j < m) { last = w[++j]; found = 1 }
      } else if (rest == "") j++
      break
    }
  }
  if (found) addbody(last, cwd)
}

function addbody(op, cwd) {
  if (op == "-" || op == "") return
  NBF++; BF[NBF] = op; BC[NBF] = cwd
}

# Pass 1's view of a quoted span.
function quoted1(content) {
  if (content == "" || content ~ /[ \t\n;&|(){}<>`]/) return "\"\""
  return content
}

# Pass 2: each $( ) body, counting nested parentheses, and in bash each backtick
# pair. The scan steps into a $( ) body rather than past it, which is how a
# nested substitution is found.
function subst(t,    n, i, j, depth) {
  n = length(t); i = 1
  while (1) {
    i = nextat(t, i, pwsh ? "\\$\\(" : "[$<>]\\(|`", n)
    if (i > n) return
    # $(( )) is arithmetic, with no command in it but a nested $( ).
    if (substr(t, i, 3) == "$((") { i += 3; continue }
    if (substr(t, i, 1) == "`") {
      j = nextat(t, i + 1, "`", n)
      if (j > n) { bad = 1; return }
      body(substr(t, i + 1, j - i - 1))
      if (bad) return
      i = j + 1; continue
    }
    depth = 1; j = i + 2
    while (depth > 0) {
      j = nextat(t, j, "[()]", n)
      if (j > n) { bad = 1; return }
      depth += substr(t, j, 1) == "(" ? 1 : -1
      j++
    }
    body(substr(t, i + 2, j - i - 3))
    if (bad) return
    i += 2
  }
}

# Pass 1 reads a substitution, $( ) or a backtick pair, as the one word "$", and
# in bash a process substitution, <( ) or >( ), too. Pass 2 reads its body, and
# the words after its ")" stay with the command around it: `git diff $(git
# merge-base a b) HEAD` has no command named HEAD.
function collapse(t,    n, i, j, k, depth, out) {
  n = length(t); i = 1; out = ""
  while (1) {
    j = nextat(t, i, pwsh ? "[$@]\\(" : "[$<>]\\(|`", n)
    out = out substr(t, i, j - i)
    if (j > n) return out
    if (substr(t, j, 1) == "`") {
      k = nextat(t, j + 1, "`", n)
      if (k > n) { bad = 1; return out }
      out = out "$"; i = k + 1; continue
    }
    depth = 1; k = j + 2
    while (depth > 0) {
      k = nextat(t, k, "[()]", n)
      if (k > n) { bad = 1; return out }
      depth += substr(t, k, 1) == "(" ? 1 : -1
      k++
    }
    out = out "$"; i = k
  }
}

function body(b,    keep1, keep2) {
  keep1 = P1; keep2 = P2
  scan(b)
  if (!bad) addsegments(collapse(P1))
  P1 = keep1; P2 = keep2
}

# Split pass-1 text into segments on the separators. The redirections 2>&1, >&2,
# and &> are blanked first so that their & does not split. { and } split only
# as words of their own, so ${HOME} and x.{a,b} stay whole.
function addsegments(t,    n, i, j, c, cur, prev, next1) {
  gsub(/[0-9]*[<>]&[0-9-]*/, " ", t)
  gsub(/&>/, " >", t)
  n = length(t); cur = ""; i = 1
  while (1) {
    j = nextat(t, i, pwsh ? "[\n;&|(){}]" : "[\n;&|(){}`]", n)
    cur = cur substr(t, i, j - i)
    if (j > n) break
    c = substr(t, j, 1)
    if (c == "{" || c == "}") {
      prev = j > 1 ? substr(t, j - 1, 1) : " "
      next1 = j < n ? substr(t, j + 1, 1) : " "
      if (!index(" \t" sepchars, prev) || !index(" \t" sepchars, next1)) { cur = cur c; i = j + 1; continue }
    }
    segment(cur); cur = ""; i = j + 1
  }
  segment(cur)
}

# One simple command: drop the leading words that are shell syntax, then build
# its entries into segtext[].
function segment(text,    w, m, k, first, rest, e, pos, d, lo, hi, x, cnt, nk, key, kpos) {
  m = split(text, w, /[ \t\r]+/)
  if (m && w[1] == "") { for (k = 1; k < m; k++) w[k] = w[k + 1]; m-- }
  if (m && w[m] == "") m--
  k = 1; SEGWT = 0
  while (k <= m) {
    if (w[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { if (w[k] ~ /^GIT_WORK_TREE=/) SEGWT = 1; k++; continue }
    if (w[k] ~ /^[0-9]*[<>]/) { k += (w[k] ~ /^[0-9]*[<>]+$/) ? 2 : 1; continue }
    if (w[k] in shellword) { k++; continue }
    if (w[k] in wrapper) { k++; while (k <= m && w[k] ~ /^-/) k++; continue }
    if (w[k] in wrapper1) { k++; while (k <= m && w[k] ~ /^-/) k++; if (k <= m) k++; continue }
    if (pwsh && w[k] == ".") { k++; continue }
    if (pwsh && w[k] ~ /^\$[A-Za-z_][A-Za-z0-9_:]*([-+*\/]?=.*)?$/) {
      # $x = <expression>: a command when the expression starts with a name.
      if (w[k] ~ /=/) { rest = w[k]; sub(/^[^=]*=/, "", rest); if (rest == "") k++; else w[k] = rest }
      else if (k < m && w[k + 1] ~ /^[-+*\/]?=/) { rest = w[k + 1]; sub(/^[^=]*=/, "", rest); k++; if (rest == "") k++; else w[k] = rest }
      else break
      if (k > m || w[k] ~ /^([$@0-9-]|"")/) return
      break
    }
    break
  }
  if (k > m || (w[k] in header)) return
  for (d = k; d <= m; d++) w[d - k + 1] = w[d]
  m = m - k + 1
  first = w[1]
  if (files) bodyfiles(w, m)
  nseg++
  if (first == "\"\"" || !(first == "[" || first == "[[" || first ~ namechars)) {
    segtext[nseg] = "READ"; return
  }
  e = ""; nk = 0
  delete emitted
  e = add(e, first); nk++; key[nk] = first; kpos[nk] = 1
  # Depth 2 under the first word, then depth 3 under each depth-2 candidate.
  lo = 1; hi = 1
  for (d = 2; d <= 3; d++) {
    cnt = 0
    for (x = lo; x <= hi; x++) {
      cands(w, m, kpos[x] + 1)
      for (pos = 1; pos <= NC; pos++) {
        if (CW[pos] == "?") { e = add(e, key[x] " ?"); continue }
        cnt++
        nk++; key[nk] = key[x] " " CW[pos]; kpos[nk] = CP[pos]
        e = add(e, key[nk])
      }
    }
    if (cnt > 4) { segtext[nseg] = "READ"; return }
    lo = hi + 1; hi = nk
  }
  # Task names under every key, for a key that turns out to be a PROJECT.
  for (x = 1; x <= nk; x++) e = tasks(e, w, m, key[x], kpos[x] + 1)
  segtext[nseg] = e
}

# cands(w, m, from): the subcommand candidates in words from..m, into CW[] and
# CP[] with NC of them. A word is a candidate position while every word before
# it is a flag, a redirection, or a word directly after a flag with no "=",
# which may be that flag's value. A word that cannot be read as a name gives
# "?". Directly after such a flag it gives "?" only when no name is found at this
# depth: `git -C "$WT" status` has a subcommand, and `hg -v "$verb"` does not.
function cands(w, m, from,    j, prevflag, x, held, named) {
  NC = 0; prevflag = 0; j = from; held = 0; named = 0
  while (j <= m) {
    x = w[j]
    if (x ~ /^-/) { prevflag = (x !~ /=/); j++; continue }
    if (x ~ /^[0-9]*[<>]/) { j += (x ~ /^[0-9]*[<>]+$/) ? 2 : 1; prevflag = 0; continue }
    if (x ~ /^[A-Za-z:][A-Za-z0-9_:.-]*$/) { NC++; CW[NC] = x; CP[NC] = j; named = 1 }
    else if (unreadable(x)) {
      if (!prevflag) { NC++; CW[NC] = "?"; CP[NC] = j }
      else if (!held) held = j
    }
    if (!prevflag) break
    prevflag = 0; j++
  }
  if (held && !named) { NC++; CW[NC] = "?"; CP[NC] = held }
}

# Every later word under key that reads as a name, flags and redirections
# skipped, with the same "?" rule as cands().
function tasks(e, w, m, key, from,    j, prevflag, x, n, list) {
  n = 0; list = ""; prevflag = 0
  for (j = from; j <= m; j++) {
    x = w[j]
    if (x ~ /^-/) { prevflag = (x !~ /=/); continue }
    if (x ~ /^[0-9]*[<>]/) { if (x ~ /^[0-9]*[<>]+$/) j++; prevflag = 0; continue }
    if (x ~ /^[A-Za-z:][A-Za-z0-9_:.-]*$/) { n++; list = list "\n+" key " " x }
    else if (!prevflag && unreadable(x)) list = list "\n+" key " ?"
    prevflag = 0
  }
  if (n > 8) return add(e, "+" key " !")
  n = split(substr(list, 2), a2, "\n")
  for (j = 1; j <= n; j++) e = add(e, a2[j])
  return e
}

function unreadable(x) { return x == "\"\"" || x ~ /[$`*?[]/ }

# Append an entry once.
function add(e, entry) {
  if (entry in emitted) return e
  emitted[entry] = 1
  return e == "" ? entry : e "\n" entry
}
