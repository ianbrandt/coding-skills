# Print the unescaped value of one string field in the JSON on stdin.
#   awk -v key=last_assistant_message -f jsonstr.awk < hook-input.json
# The field is the first occurrence of "<key>" that is followed by a colon and a
# string; an occurrence inside a value is skipped. Every escape JSON allows is
# handled; \uXXXX is decoded for the code points a reply is likely to carry and
# replaced with "?" otherwise (the hook inputs are written by JSON.stringify,
# which leaves non-ASCII text unescaped, so the table is rarely reached).
# The value is found with one regex match and decoded with one split, and each
# piece is printed as it is decoded rather than appended to one string, so the
# cost is linear in the size of the input.
#
# With -v under=<key> in place of key: print every string value, at any depth,
# inside the object at the top-level field <key>, each followed by a line holding
# only \001 so that no quote can match across two values. Keys are not values.
{ buf = buf $0 "\n" }
END {
  if (under != "") { values(buf); exit }
  needle = "\"" key "\""
  rest = buf
  while ((i = index(rest, needle)) > 0) {
    rest = substr(rest, i + length(needle))
    if (match(rest, /^[ \t\r\n]*:[ \t\r\n]*"/)) { rest = substr(rest, RLENGTH + 1); break }
  }
  if (i == 0) exit
  if (!match(rest, /^([^"\\]|\\.)*"/)) exit
  decode(substr(rest, 1, RLENGTH - 1))
}
# ponytail: each token copies the rest of the input, so the cost is input size
# times token count. Walk by offset if a very large rich-text body is ever slow.
function values(rest,    tok, iskey, depth, inside) {
  while (match(rest, /"([^"\\]|\\.)*"|[][{}]/)) {
    tok = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
    if (tok == "{" || tok == "[") { depth++; continue }
    if (tok == "}" || tok == "]") { if (--depth < 2 && inside) return; continue }
    iskey = match(rest, /^[ \t\r\n]*:/)
    if (inside && depth < 2) return
    if (inside && !iskey) { decode(substr(tok, 2, length(tok) - 2)); printf "\n\001\n" }
    else if (iskey && depth == 1 && tok == "\"" under "\"") inside = 1
  }
}
# Prints the decoded string. Two forms are quadratic in the escape count of a
# long reply: appending every piece to one returned string, and splitting on the
# regex /\\/ in the BWK awk macOS ships. A one-character string separator is
# taken literally, which POSIX requires, and does not go through the regex engine.
function decode(raw,    n, seg, j, s, c) {
  n = split(raw, seg, "\\")
  printf "%s", seg[1]
  for (j = 2; j <= n; j++) {
    s = seg[j]
    if (s == "") { printf "\\"; j++; if (j <= n) printf "%s", seg[j]; continue }
    c = substr(s, 1, 1); s = substr(s, 2)
    if (c == "n") printf "\n%s", s
    else if (c == "t") printf "\t%s", s
    else if (c == "r") printf "\r%s", s
    else if (c == "b") printf "\b%s", s
    else if (c == "f") printf "\f%s", s
    else if (c == "u") printf "%s%s", uni(substr(s, 1, 4)), substr(s, 5)
    else printf "%s%s", c, s
  }
}
function uni(h) {
  h = tolower(h)
  if (h == "2014") return "—"
  if (h == "2013") return "–"
  if (h == "2018") return "‘"
  if (h == "2019") return "’"
  if (h == "201c") return "“"
  if (h == "201d") return "”"
  if (h == "00a0") return " "
  if (h == "2192") return "→"
  if (h == "0022") return "\""
  return "?"
}
