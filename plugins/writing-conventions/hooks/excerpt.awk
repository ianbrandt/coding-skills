# Print the whole paragraphs of an edited file that hold the text an Edit put there.
#   awk -v cap=<characters> -f excerpt.awk <new_string file> <edited file>
# A paragraph is bounded by blank lines. A one-word edit can make a violation that
# the word alone does not show, so the sentences around it are what gets reviewed,
# and the size of the excerpt follows the edit and not the file. The text is
# matched line by line, because new_string can span lines and paragraphs: its first
# line ends a line of the file, its last line starts one, and the lines between are
# equal. Printing stops soon after cap characters; the caller cuts at the cap.
# The caller never passes an empty new_string file, which would read the edited
# file as the first one.
# With -v lines=1 the first file is instead the lines an apply_patch call added,
# and a paragraph is kept when one of its lines equals one of them.
FNR == NR { sub(/\r$/, ""); if (lines) { if ($0 !~ /^[ \t]*$/) added[$0] = 1; k = 1 } else want[++k] = $0; next }
{ sub(/\r$/, ""); line[++n] = $0 }
function blank(i) { return line[i] ~ /^[ \t]*$/ }
function ends(s, t) { return t == "" || (length(s) >= length(t) && substr(s, length(s) - length(t) + 1) == t) }
function hit(i,    j) {
  if (lines) return line[i] in added
  if (k == 1) return index(line[i], want[1]) > 0
  if (!ends(line[i], want[1])) return 0
  for (j = 2; j < k; j++) if (line[i + j - 1] != want[j]) return 0
  return want[k] == "" || index(line[i + k - 1], want[k]) == 1
}
END {
  for (i = 1; i + k - 1 <= n; i++) {
    if (!hit(i)) continue
    for (a = i; a > 1 && !blank(a - 1); a--) ;
    for (b = i + k - 1; b < n && !blank(b + 1); b++) ;
    for (j = a; j <= b; j++) keep[j] = 1
  }
  for (i = 1; i <= n && size <= cap; i++) {
    if (!(i in keep)) continue
    if (last && i > last + 1) print ""
    print line[i]; size += length(line[i]) + 1; last = i
  }
}
