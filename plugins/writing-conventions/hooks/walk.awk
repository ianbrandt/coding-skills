# Decide from the classifier cache whether a shell command goes to the reader.
#   awk -v keys=<keys.awk output> -v scope=<project dir> [-v final=1] \
#       -f walk.awk <cache file>...
# Each cache line is <scope><TAB><class><TAB><key>, where the scope is "*" for a
# key shared by every project or a project directory. For one key in one scope,
# CAN_PUBLISH wins over RUNS_CODE, PROJECT, and DESCEND, in that order, which all
# win over NEVER. A line in any other form is ignored.
#
# The output is READER, SAFE, or ASK followed by one line per key the cache has
# no answer for, ASK<TAB><scope><TAB><key>. With final=1 a key with no answer
# reads as CAN_PUBLISH, so the output is READER or SAFE. gate.ps1 has the same
# walk.
#
# A segment is walked from its first word. NEVER settles it; CAN_PUBLISH sends
# the command to the reader; RUNS_CODE does only when keys.awk found a sentence.
# DESCEND goes down to every subcommand candidate: none is safe, a "?" among
# them or a DESCEND at depth 3 is the reader. PROJECT reads every task name
# below it, in the project's scope: none, a "?", a "!", or any task that is not
# NEVER sends the command to the reader, so one safe task does not settle
# `make check publish`. A path as the first word, and every key below it, is in
# the project's scope as well.

BEGIN {
  FS = "\t"
  split("NEVER DESCEND PROJECT RUNS_CODE CAN_PUBLISH", cname, " ")
  for (i = 1; i <= 5; i++) rank[cname[i]] = i
}

NF == 3 && ($1 == "*" || $1 == scope) && ($2 in rank) {
  k = $1 SUBSEP $3
  if (rank[$2] > best[k]) best[k] = rank[$2]
}

END {
  nseg = 0
  while ((getline line < keys) > 0) {
    split(line, f, "\t")
    if (f[1] == "0") { if (f[2] == "PROSE") prose = 1; continue }
    s = f[1] + 0
    if (s > nseg) nseg = s
    n[s]++; ent[s, n[s]] = f[2]; has[s, f[2]] = 1
  }
  for (s = 1; s <= nseg; s++) {
    if (has[s, "READ"]) { print "READER"; exit }
    r = node(s, ent[s, 1], 1, 0)
    if (r == "READER") { print "READER"; exit }
    if (r == "UNKNOWN") unknown[s] = 1
  }
  for (s = 1; s <= nseg; s++) if (s in unknown) ask(s)
  if (nask) { print "ASK"; printf "%s", asked } else print "SAFE"
}

# The scope a key is looked up in: the project's for a task name or a path.
function scopeof(key, task,    w) {
  if (task) return scope
  w = key; sub(/ .*/, "", w)
  return w ~ /[\/$\\]/ ? scope : "*"
}

function cls(key, task,    r) {
  r = best[scopeof(key, task) SUBSEP key]
  if (r) return cname[r]
  return final ? "CAN_PUBLISH" : ""
}

# The walk of one key at depth d: READER, SAFE, or UNKNOWN.
function node(s, key, d, task,    c, i, e, res, r, kids) {
  c = cls(key, task)
  if (c == "") return "UNKNOWN"
  if (c == "NEVER") return "SAFE"
  if (c == "CAN_PUBLISH" || task) return "READER"
  if (c == "RUNS_CODE") return prose ? "READER" : "SAFE"
  res = "SAFE"
  if (c == "DESCEND") {
    if (d >= 3 || has[s, key " ?"]) return "READER"
    for (i = 1; i <= n[s]; i++) {
      e = ent[s, i]
      if (substr(e, 1, 1) == "+" || !child(e, key) || e == key " ?") continue
      r = node(s, e, d + 1, 0)
      if (r == "READER") return r
      if (r == "UNKNOWN") res = r
    }
    return res
  }
  # PROJECT
  if (has[s, "+" key " ?"] || has[s, "+" key " !"]) return "READER"
  kids = 0
  for (i = 1; i <= n[s]; i++) {
    e = ent[s, i]
    if (substr(e, 1, 1) != "+" || !child(substr(e, 2), key)) continue
    kids++
    r = node(s, substr(e, 2), d + 1, 1)
    if (r == "READER") return r
    if (r == "UNKNOWN") res = r
  }
  return kids ? res : "READER"
}

# Whether e is key and one more word.
function child(e, key) {
  return substr(e, 1, length(key) + 1) == key " " && index(substr(e, length(key) + 2), " ") == 0
}

# The keys of an unsettled segment with no answer in the cache, below a parent
# that is itself unanswered or one that reads them: a DESCEND for a subcommand,
# a PROJECT for a task name.
function ask(s,    i, e, task, key, parent, pc) {
  for (i = 1; i <= n[s]; i++) {
    e = ent[s, i]
    task = substr(e, 1, 1) == "+"
    key = task ? substr(e, 2) : e
    if (key ~ / [?!]$/) continue
    if (index(key, " ")) {
      parent = key; sub(/ [^ ]*$/, "", parent)
      pc = cls(parent, 0)
      if (pc != "" && pc != (task ? "PROJECT" : "DESCEND")) continue
    }
    if (cls(key, task) != "") continue
    if ((scopeof(key, task), key) in done) continue
    done[scopeof(key, task), key] = 1
    nask++; asked = asked "ASK\t" scopeof(key, task) "\t" key "\n"
  }
}
