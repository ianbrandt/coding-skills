#Requires -Version 5.1
# Find the fenced blocks tagged `draft` in a reply. draft.awk is the same
# scanner; gate.ps1 sends the blocks to the model, and lint.ps1 takes the
# unwrapped text, in which the opening and closing fence lines of each draft
# block are gone and everything else is unchanged, so the regex lint still sees
# a draft as the prose it is.
#
# A block opens on three or more backticks or tildes with `draft` as the info
# string, and closes on the first later fence of the same character that is at
# least as long, which is the rule Remove-CodeSpans in lint.ps1 uses. A code
# fence inside a draft therefore has to be shorter or of the other character,
# which is what rules.md asks for. A block left open at the end runs to the end.
# An empty block is no draft.
#
# ASCII only, so 5.1 cannot mangle it reading a BOM-less file as the ANSI codepage.
function Get-DraftFence([string]$text) {
  $drafts = New-Object System.Collections.Generic.List[string]
  $out = New-Object System.Text.StringBuilder
  $buf = New-Object System.Text.StringBuilder
  $fence = ''
  $draft = $false
  foreach ($line in $text.Split("`n")) {
    $fm = [regex]::Match($line, '^[ \t]*(`{3,}|~{3,})')
    if ($fm.Success) {
      $mk = [regex]::Replace($fm.Value, '^[ \t]+', '')
      if ($fence -eq '') {
        $info = [regex]::Replace([regex]::Replace($line.Substring($fm.Length), '^[ \t]+', ''), '[ \t\r]+$', '')
        $fence = $mk
        $draft = ($info -ceq 'draft' -or $info -cmatch '^draft[ \t]')
        if ($draft) { [void]$buf.Clear(); continue }
      } elseif ($mk[0] -eq $fence[0] -and $mk.Length -ge $fence.Length) {
        $fence = ''
        if ($draft) {
          $draft = $false
          if ($buf.ToString() -match '[^ \t\r\n]') { $drafts.Add($buf.ToString()) }
          [void]$buf.Clear()
          continue
        }
      }
    }
    if ($draft) { [void]$buf.Append($line).Append("`n") }
    [void]$out.Append($line).Append("`n")
  }
  if ($draft -and $buf.ToString() -match '[^ \t\r\n]') { $drafts.Add($buf.ToString()) }
  return @{ Drafts = @($drafts); Unwrapped = $out.ToString() }
}
