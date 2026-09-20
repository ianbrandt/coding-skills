# Print the findings in a reader's verdict that quote the text under review.
#   awk -v verdict=<verdict-file> -f verdict.awk <source-file>... <verdict-file>
# The first line of a verdict is SKIP, PASS, or VIOLATION, and only VIOLATION
# has findings. A finding is one line:
#   "fragment" + "fragment" -> rewrite
# It is verified when every fragment, with runs of whitespace collapsed, is in
# one of the source files; the fragments need not share a file. The reader can
# see text quoted from an untrusted source, so no finding is acted on until its
# quote is found in the text the script chose to review. Anything else prints
# nothing: a verdict line with a second word, a finding that does not parse, a
# quote that is nowhere in the sources.
function squash(t) { gsub(/[ \t\r\n]+/, " ", t); sub(/^ /, "", t); sub(/ $/, "", t); return t }
FILENAME != verdict { src[FILENAME] = src[FILENAME] " " $0; next }
!seen {
  if ($0 ~ /^[ \t\r]*$/) next
  seen = 1
  if (squash($0) != "VIOLATION") exit
  for (f in src) src[f] = squash(src[f])
  next
}
{
  line = $0; sub(/\r$/, "", line)
  arrow = index(line, "\" -> ")
  if (substr(line, 1, 1) != "\"" || arrow == 0) next
  n = split(substr(line, 2, arrow - 2), frag, /" \+ "/)
  if (n == 0) next  # split of "" yields no fragments, and the loop below would pass
  for (i = 1; i <= n; i++) {
    want = squash(frag[i]); found = 0
    if (want != "") for (f in src) if (index(src[f], want)) { found = 1; break }
    if (!found) next
  }
  print line
}
