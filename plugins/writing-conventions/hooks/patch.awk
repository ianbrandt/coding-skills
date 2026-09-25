# Split the patch of a Codex apply_patch call, sent in tool_input.command, by file.
#   awk -v cwd=<dir> -v out=<dir> -f patch.awk   writes out/path.N and out/new.N
#   awk -v cwd=<dir> -f patch.awk                prints one path per line
# N counts the files the patch adds or updates, from 1. new.N holds the lines the
# patch adds to file N, without their leading +, and is empty for an update that
# only deletes. A relative path is taken against cwd, and a Move to line replaces
# the path of the file before it. A deleted file is left out.
function abs(p) { return (p ~ /^\// || p ~ /^[A-Za-z]:[\\\/]/ || cwd == "") ? p : cwd "/" p }
{ sub(/\r$/, "") }
/^\*\*\* (Add|Update) File: / {
  cur = ++n; path[n] = abs(substr($0, index($0, ": ") + 2))
  if (out != "") printf "" > (out "/new." n)
  next
}
/^\*\*\* Move to: / { if (cur) path[cur] = abs(substr($0, 14)); next }
/^\*\*\* (Delete File: |End Patch)/ { cur = 0; next }
cur && out != "" && /^\+/ { print substr($0, 2) > (out "/new." cur) }
END {
  for (i = 1; i <= n; i++) {
    if (out == "") print path[i]
    else { printf "%s", path[i] > (out "/path." i); close(out "/path." i) }
  }
}
