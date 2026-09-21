# Find the fenced blocks tagged `draft` in the text on stdin. One scanner, two
# readers: gate.sh sends the blocks to the model, lint.sh unwraps them so the
# regex lint still sees them as the prose they are.
#   awk -f draft.awk              print the text of each draft block, each
#                                 followed by a line holding only \001, so that
#                                 no quote can match across two of them
#   awk -v unwrap=1 -f draft.awk  print the whole text with the opening and
#                                 closing fence lines of each draft block
#                                 removed, everything else unchanged
# A block opens on three or more backticks or tildes with `draft` as the info
# string, and closes on the first later fence of the same character that is at
# least as long, which is the rule lint.awk's strip_code uses. A code fence
# inside a draft therefore has to be shorter or of the other character, which is
# what rules.md asks for. A block left open at the end runs to the end. An
# empty block is no draft.
{
  line = $0
  if (match(line, /^[ \t]*(`{3,}|~{3,})/)) {
    m = substr(line, RSTART, RLENGTH); sub(/^[ \t]+/, "", m)
    if (fence == "") {
      info = substr(line, RSTART + RLENGTH)
      sub(/^[ \t]+/, "", info); sub(/[ \t\r]+$/, "", info)
      fence = m
      draft = (info == "draft" || info ~ /^draft[ \t]/)
      if (draft) { buf = ""; next }
    } else if (substr(m, 1, 1) == substr(fence, 1, 1) && length(m) >= length(fence)) {
      fence = ""
      if (draft) { draft = 0; flush(); next }
    }
  }
  if (draft) { if (unwrap) print line; else buf = buf line "\n"; next }
  if (unwrap) print line
}
END { if (draft && !unwrap) flush() }
function flush() { if (buf ~ /[^ \t\r\n]/) printf "%s\001\n", buf; buf = "" }
