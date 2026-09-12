# Print the unescaped value of one string field in the JSON on stdin.
#   awk -v key=last_assistant_message -f jsonstr.awk < hook-input.json
# The first occurrence of "<key>" is taken to be the field, which holds for the
# hook inputs this plugin reads: session_id, last_assistant_message, and
# file_path all precede any value that could contain the same text. Only the
# escapes JSON allows are handled; \uXXXX is decoded for the few code points a
# reply is likely to carry and replaced with "?" otherwise.
{ buf = buf $0 "\n" }
END {
  needle = "\"" key "\""
  i = index(buf, needle)
  if (!i) exit
  rest = substr(buf, i + length(needle))
  n = length(rest)
  j = 1
  while (j <= n && substr(rest, j, 1) ~ /[ \t\r\n:]/) j++
  if (substr(rest, j, 1) != "\"") exit
  j++
  out = ""
  while (j <= n) {
    c = substr(rest, j, 1)
    if (c == "\\") {
      d = substr(rest, j + 1, 1)
      if (d == "n") out = out "\n"
      else if (d == "t") out = out "\t"
      else if (d == "r") out = out "\r"
      else if (d == "u") { out = out uni(substr(rest, j + 2, 4)); j += 4 }
      else out = out d
      j += 2
    } else if (c == "\"") {
      break
    } else {
      out = out c
      j++
    }
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
  return "?"
}
