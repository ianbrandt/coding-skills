# House-style lint over prose on stdin. Prints one line per flagged sentence:
#   <group>\t<matched text>
# With -v note=1 it prints the note the next turn opens with instead, or
# nothing when the text is clean. Pure: no files, no environment.
#
# Three groups. Banned words and spaced em dashes are exact. Inanimate agency
# is precision-first: a determiner-led or pronoun subject followed by a verb of
# speech, volition, or cognition, with the subject checked against an animate
# list, passives and adjectival participles excluded by the gap words, reduced
# passives ("the rule stated in", "three named endpoints") excluded by the word
# after the verb, and the noun-or-verb forms (names, states, claims, offers)
# kept only when an object-like word follows. Possession verbs (holds, carries,
# keeps) and "notes" are left out on purpose: a hand check of 90 hits found the
# first group mostly code mechanics, and "notes" is nearly always the noun.
BEGIN {
  W = "[[:alnum:]'’_-]+ "
  DET = "(the|a|an|this|that|these|those|each|every|its|our|my|your|neither|either|both|no)"
  ADV = "((never|also|always|still|then|only|just|already|itself) )?"
  VERB = "(says|said|tells|told|wants|wanted|knows|knew|decides|decided|claims|claimed|asks|asked" \
         "|expects|expected|promises|promised|believes|believed|thinks|thought|concludes|concluded" \
         "|states|stated|declares|declared|insists|insisted|refuses|refused|assumes|assumed" \
         "|credits|credited|names|named|judges|judged|offers|offered|withholds|withheld|intends|intended" \
         "|wishes|wished|cares|cared|remembers|remembered|forgets|forgot|exempts|exempted)"
  SB = "(^|[^[:alnum:]_-])"
  NB = "([^[:alnum:]_-]|$)"
  P[1] = SB DET " " W "(" W ")?(" W ")?(" W ")?(" W ")?" ADV VERB NB
  P[2] = SB W ",? (that|which) " ADV VERB NB
  P[3] = SB "(it|this|that|neither|either|both|each) " ADV VERB NB
  P[4] = SB DET " (" W ")?(" W ")?(" W ")?[[:alnum:]'’_-]+,? whose "
  P_BANNED = SB "(load-bearing|vacuous|vacuously|non-vacuous|owe|owes|owed|shape|shapes|slot|slots" \
             "|channel|channels|deleak|de-risk|derisk)" NB
  P_DASH = "[ \t]—|—[ \t]"
  # Subjects that act: people, roles, and the agents and sessions that contain one.
  ANIMATE = " i we you he she they user users author authors maintainer maintainers reviewer reviewers" \
            " team teams developer developers dev devs engineer engineers contributor contributors reader" \
            " readers writer writers person people agent agents assistant model human humans folks everyone" \
            " someone anybody nobody who session sessions subagent subagents verifier verifiers orchestrator" \
            " conductor delegate delegates critic judge "
  # A gap word from this list means a passive, an adjectival participle, or a
  # clause boundary, so the verb is not this subject's.
  SKIPGAP = " is are was were be been being to not n't does do did can could will would may might must" \
            " should has have had the a an this that these those each every its our my your neither" \
            " either both no if when unless because since while whether after before until where" \
            " which who whom and or but "
  # After a past form, a preposition means a reduced passive ("the rule stated in").
  PREP = " in at on by above below under over within there here earlier through via from with as for" \
         " into onto than "
  # A past form is a verb rather than a participle only when an object-like word
  # follows: "the report concluded the build is fine", not "three named endpoints".
  PASTOBJ = " the a an its their this that these those what which who how why where when whether it" \
            " them him her me us you one no every each some any all both several many none nothing" \
            " something anything everything code quote "
  AMBIG = " names states claims offers judges credits wishes cares "
  NOOBJ = " of is are was were and or as for to in on at by with from than that which who . , ; : ) "
  RULE["banned word"] = "that word is banned in prose; use a plain synonym"
  RULE["spaced em dash"] = "an em dash takes no surrounding spaces: write word—word, never word — word"
  RULE["inanimate agency"] = "an inanimate subject must not take a verb of speech, volition, or cognition; say who the real actor is, or rewrite around the act"
  ORDER[1] = "banned word"; ORDER[2] = "spaced em dash"; ORDER[3] = "inanimate agency"
}
{ text = text $0 "\n" }
END {
  text = strip_code(text)
  n = split(text, sentences, /[.!?;:]+[ \t\n]+|\n+/)
  for (k = 1; k <= n; k++) {
    s = sentences[k]
    if (s ~ /^[ \t]*$/) continue
    l = tolower(s)
    if (match(s, P_DASH)) hit("spaced em dash", substr(s, RSTART, RLENGTH))
    if (match(l, P_BANNED)) hit("banned word", trim(substr(s, RSTART, RLENGTH)))
    agency(s, l)
  }
  if (note) {
    if (total == 0) exit
    print "A house-style lint flagged the previous reply:"
    for (o = 1; o <= 3; o++) {
      g = ORDER[o]
      if (COUNT[g]) printf "- %s x%d, e.g. \"%s\". Rule: %s.\n", g, COUNT[g], EXAMPLE[g], RULE[g]
    }
    print "Apply these rules in the reply you are about to write, including in markdown headings. Do not re-send the previous reply and do not correct it; there is no need to mention this note unless the user asks about it. Leave a literal sense (a Slack channel, an array shape, a timetable slot) alone."
  }
}
function hit(g, ex) {
  total++; COUNT[g]++
  if (!(g in EXAMPLE)) EXAMPLE[g] = ex
  if (!note) printf "%s\t%s\n", g, ex
}
# One hit per sentence at most. An excluded match is stepped past so a real hit
# later in the same sentence is still found: "the grounds that the rule wants"
# is excluded on "that", then "the rule wants" is tried on its own.
function agency(s, l,   p, pos, rest, start, len, span, after, verb, m, words, nw, i, w, sub_ok) {
  for (p = 1; p <= 4; p++) {
    pos = 1
    while (pos <= length(l)) {
      rest = substr(l, pos)
      if (!match(rest, P[p])) break
      start = pos + RSTART - 1; len = RLENGTH
      pos = start + 1
      span = trim(substr(l, start, len))
      nextc = substr(l, start + len - 1, 1)     # the boundary character right after the verb
      after = substr(l, start + len)
      sub(/^[^[:alnum:]]+/, "", after); sub(/[^[:alnum:]'’_-].*$/, "", after)
      if (span ~ /^that said/) continue
      nw = split(span, words, /[ \t]+/)
      if (p == 4) { verb = "whose"; m = nw - 1 } else { verb = words[nw]; m = nw - 1 }
      sub_ok = 1
      for (i = 1; i <= m; i++) {
        w = words[i]; gsub(/[^[:alnum:]'’_-]/, "", w)
        if (index(ANIMATE, " " w " ")) sub_ok = 0
        if (i > 1 && index(SKIPGAP, " " w " ")) sub_ok = 0
        if (i == m && w ~ /('s|’s|s')$/) sub_ok = 0
      }
      if (!sub_ok) continue
      if (verb !~ /s$/ && verb != "whose") {
        if (nextc ~ /[,.;:]/) continue
        if (index(PREP, " " after " ")) continue
        if (after !~ /^[0-9]/ && !index(PASTOBJ, " " after " ")) continue
        if (verb == "named" && (after == "code" || after == "quote")) continue   # "a case named `foo`"
      }
      if (index(AMBIG, " " verb " ")) {
        # a noun-or-verb word is a verb here only when an object-like word follows it:
        # "the report names the file", not "the spec names, 163 lines" or "the shorter names re-wrapped"
        if (nextc ~ /[,.;:]/ || after == "" || index(NOOBJ, " " after " ")) continue
        if (!index(PASTOBJ, " " after " ") && !adverb(after)) continue
      }
      hit("inanimate agency", trim(substr(s, start, len)))
      return
    }
  }
}
function strip_code(t,   out, n, i, lines, infence) {
  n = split(t, lines, "\n"); out = ""
  for (i = 1; i <= n; i++) {
    if (lines[i] ~ /^[ \t]*(```|~~~)/) { infence = !infence; continue }
    if (infence) continue
    out = out lines[i] "\n"
  }
  gsub(/`[^`\n]*`/, "CODE", out)
  gsub(/"[^"\n]*"/, "QUOTE", out)
  # literal senses stay: a Slack or byte channel, an array shape, a time slot, release notes
  gsub(/[Ss]lack channel|[Mm]essage channel|[Bb]yte channel|[Rr]elease channel|[Aa]rray shape|[Tt]ensor shape|[Tt]imetable slot|[Tt]ime slot|[Rr]elease notes/, "LITERAL", out)
  return out
}
function trim(x) { sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x); return x }
# "states plainly" keeps the verb reading; "names imply" does not.
function adverb(w) { return w ~ /[a-z][a-z]ly$/ && !index(" imply apply reply supply rely comply multiply ally family early only likely ", " " w " ") }
