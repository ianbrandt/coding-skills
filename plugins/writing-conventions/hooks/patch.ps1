#Requires -Version 5.1
# Split the patch of a Codex apply_patch call, sent in tool_input.command, by file.
# patch.awk is the same splitter. One entry per file the patch adds or updates, in
# order: Path, and New, the lines the patch adds to it without their leading +,
# which is empty for an update that only deletes. A relative path is taken against
# $cwd, and a Move to line replaces the path of the file before it. A deleted file
# is left out.
function Get-PatchFile([string]$patch, [string]$cwd) {
  $files = New-Object System.Collections.Generic.List[object]
  $cur = $null
  foreach ($line in $patch.Replace("`r", '').Split("`n")) {
    $m = [regex]::Match($line, '^\*\*\* (Add|Update) File: (.*)$')
    if ($m.Success) { $cur = [pscustomobject]@{ Path = $m.Groups[2].Value; New = New-Object System.Collections.Generic.List[string] }; $files.Add($cur); continue }
    if ($line.StartsWith('*** Move to: ')) { if ($null -ne $cur) { $cur.Path = $line.Substring(13) }; continue }
    if ($line -match '^\*\*\* (Delete File: |End Patch)') { $cur = $null; continue }
    if ($null -ne $cur -and $line.StartsWith('+')) { $cur.New.Add($line.Substring(1)) }
  }
  foreach ($f in $files) {
    if ($cwd -ne '' -and $f.Path -notmatch '^(/|[A-Za-z]:[\\/])') { $f.Path = $cwd.TrimEnd('/', '\') + '/' + $f.Path }
  }
  return ,$files
}
