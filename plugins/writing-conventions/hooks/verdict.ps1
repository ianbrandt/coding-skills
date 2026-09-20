#Requires -Version 5.1
# Dot-sourced by the scripts that call the reader. Get-VerifiedFinding returns the
# findings in a reader's verdict that quote the text under review. The mirror of
# this file is verdict.awk, and the two are held together by the verdict cases in
# gate-test.sh and gate-test.ps1.
#
# The first line of a verdict is SKIP, PASS, or VIOLATION, and only VIOLATION has
# findings. A finding is one line:
#   "fragment" + "fragment" -> rewrite
# It is verified when every fragment, with runs of whitespace collapsed, is in one
# of the sources; the fragments need not share a source. The reader can see text
# quoted from an untrusted source, so no finding is acted on until its quote is
# found in the text the script chose to review. Anything else returns nothing: a
# verdict line with a second word, a finding that does not parse, a quote that is
# nowhere in the sources.
#
# ASCII only, so 5.1 cannot mangle it reading a BOM-less file as the ANSI codepage.
function Get-VerifiedFinding([string]$Verdict, [string[]]$Sources) {
  $squash = { param([string]$t) [regex]::Replace($t, '[ \t\r\n]+', ' ').Trim(' ') }
  $lines = @($Verdict -split "`n")
  $i = 0
  while ($i -lt $lines.Count -and $lines[$i] -match '^[ \t\r]*$') { $i++ }
  if ($i -ge $lines.Count -or (& $squash $lines[$i]) -cne 'VIOLATION') { return @() }
  $src = @($Sources | ForEach-Object { & $squash $_ })
  $verified = @()
  for ($i++; $i -lt $lines.Count; $i++) {
    $line = $lines[$i].TrimEnd("`r")
    $arrow = $line.IndexOf('" -> ', [StringComparison]::Ordinal)
    if (-not $line.StartsWith('"', [StringComparison]::Ordinal) -or $arrow -lt 1) { continue }
    $ok = $true
    foreach ($frag in $line.Substring(1, $arrow - 1).Split([string[]]@('" + "'), [StringSplitOptions]::None)) {
      $want = & $squash $frag
      if ($want -eq '' -or -not ($src | Where-Object { $_.Contains($want) })) { $ok = $false; break }
    }
    if ($ok) { $verified += $line }
  }
  return $verified
}
