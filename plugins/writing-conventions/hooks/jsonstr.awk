# Print the unescaped value of one string field in the JSON on stdin.
#   awk -v key=last_assistant_message -f jsonstr.awk < hook-input.json
# The field is the first occurrence of "<key>" that is followed by a colon and a
# string; an occurrence inside a value is skipped. Every escape JSON allows is
# handled; \uXXXX is decoded for the code points a reply is likely to carry and
# replaced with "?" otherwise (the hook inputs are written by JSON.stringify,
# which leaves non-ASCII text unescaped, so the table is rarely reached).
# The value is found with one regex match and decoded with one split, so the
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
  printf "%s", decode(substr(rest, 1, RLENGTH - 1))
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
    if (inside && !iskey) printf "%s\n\001\n", decode(substr(tok, 2, length(tok) - 2))
    else if (iskey && depth == 1 && tok == "\"" under "\"") inside = 1
  }
}
function decode(raw,    n, seg, out, j, s, c) {
  n = split(raw, seg, /\\/)
  out = seg[1]
  for (j = 2; j <= n; j++) {
    s = seg[j]
    if (s == "") { out = out "\\"; j++; if (j <= n) out = out seg[j]; continue }
    c = substr(s, 1, 1); s = substr(s, 2)
    if (c == "n") out = out "\n" s
    else if (c == "t") out = out "\t" s
    else if (c == "r") out = out "\r" s
    else if (c == "b") out = out "\b" s
    else if (c == "f") out = out "\f" s
    else if (c == "u") out = out uni(substr(s, 1, 4)) substr(s, 5)
    else out = out c s
  }
  return out
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
