# Print the unescaped value of one string field in the JSON on stdin.
#   awk -v key=last_assistant_message -f jsonstr.awk < hook-input.json
# The field is the first occurrence of "<key>" that is followed by a colon and a
# string; an occurrence inside a value is skipped. Every escape JSON allows is
# handled; \uXXXX is decoded for the code points a reply is likely to carry and
# replaced with "?" otherwise (the hook inputs are written by JSON.stringify,
# which leaves non-ASCII text unescaped, so the table is rarely reached).
# The value is found with one regex match and decoded with one split, so the
# cost is linear in the size of the input.
{ buf = buf $0 "\n" }
END {
  needle = "\"" key "\""
  rest = buf
  while ((i = index(rest, needle)) > 0) {
    rest = substr(rest, i + length(needle))
    if (match(rest, /^[ \t\r\n]*:[ \t\r\n]*"/)) { rest = substr(rest, RLENGTH + 1); break }
  }
  if (i == 0) exit
  if (!match(rest, /^([^"\\]|\\.)*"/)) exit
  raw = substr(rest, 1, RLENGTH - 1)
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
  printf "%s", out
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
