#Requires -Version 5.1
# Split a shell command into the keys the gate looks up to decide whether the
# command can publish, with no command name written down here. keys.awk is the
# same extractor, and shell-keys.tsv is the fixture both are tested against, so
# a rule changed here is changed there in the same commit.
#
#   Get-CommandKey $command bash     the command from the Bash tool
#   Get-CommandKey $command pwsh     the same, from the PowerShell tool
# The return value is a string array, one element per output line, each line
# "<segment number>`t<entry>". See keys.awk's header comment for what a
# segment and an entry are, and for the sentence rule behind 0<TAB>PROSE: the
# rules here are the same rules, ported one awk function to one function below.
#
# ASCII only, so 5.1 cannot mangle it reading a BOM-less file as the ANSI
# codepage. PowerShell's -match and -replace operators fold case, so every
# pattern below runs through a case-sensitive [regex] object instead.

function Get-CommandKey([string]$command, [string]$mode) {
  $pwshMode = ($mode -eq 'pwsh')
  $ctx = if ($pwshMode) { $script:CtxPwsh } else { $script:CtxBash }
  $lines = New-Object System.Collections.Generic.List[string]
  if ($script:ReProse.IsMatch($command)) { [void]$lines.Add("0`tPROSE") }

  $st = @{
    Bad       = $false
    SegText   = (New-Object System.Collections.Generic.List[string])
    # A plain @{} hashtable compares string keys case-insensitively, which
    # would conflate "grep -i null" and "grep -i NULL" as the same cached
    # text, so the cache and its lookups need an ordinal dictionary instead.
    SegCache  = (New-Object 'System.Collections.Generic.Dictionary[string,object]')
    BodyCache = (New-Object 'System.Collections.Generic.Dictionary[string,object]')
  }
  $r = Invoke-Scan $command $ctx $st
  if (-not $st.Bad) {
    Invoke-AddSegments (Invoke-Collapse $r.P1 $ctx $st) $ctx $st
    Invoke-Subst $r.P2 $ctx $st
  }
  if ($st.Bad) {
    [void]$lines.Add("1`tREAD")
    return $lines.ToArray()
  }

  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $n = 0
  foreach ($segText in $st.SegText) {
    if (-not $seen.Add($segText)) { continue }
    $n++
    foreach ($outLine in $segText.Split("`n")) { [void]$lines.Add("$n`t$outLine") }
  }
  return $lines.ToArray()
}

# ---- Internal helpers below. Only Get-CommandKey above is meant to be called. ----

# Character and word tables shared by both modes, and the two mode-specific
# contexts (bash, pwsh), built once when this file is dot-sourced rather than
# on every call, since the parity driver calls Get-CommandKey once per command
# in a single process.
$script:ShellWordSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@('!', 'if', 'then', 'elif', 'else', 'fi', 'do', 'done', 'while', 'until', 'time', 'esac', '{', '}'))
# Wrappers that run the command after them: the first set takes only flags,
# and the second one operand too, as in `timeout 60 hg commit`.
$script:WrapperSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@('env', 'sudo', 'doas', 'nice', 'nohup', 'exec', 'command', 'builtin', 'setsid', 'stdbuf', 'setarch', 'unbuffer', 'catchsegv'))
$script:Wrapper1Set = [System.Collections.Generic.HashSet[string]]::new([string[]]@('timeout', 'flock', 'chrt', 'taskset'))
$script:HeaderSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@('for', 'case', 'select', 'in'))
$script:EscapedSet = [System.Collections.Generic.HashSet[char]]::new([char[]]@(' ', "`t", ';', '&', '|', '(', ')', '{', '}', '<', '>', "'", '"', '`', '#', '$', '\'))
$script:DquoteBashEscapes = [System.Collections.Generic.HashSet[string]]::new([string[]]@('$', '`', '"', '\', "`n"))
$script:WordSepChars = [System.Collections.Generic.HashSet[char]]::new([char[]]@(' ', "`t", ';', '&', '|', '(', ')'))
$script:ParenChars = [char[]]@('(', ')')

$script:ReAssignWord = [regex]::new('^[A-Za-z_][A-Za-z0-9_]*=')
$script:ReRedirPrefix = [regex]::new('^[0-9]*[<>]')
$script:ReRedirFull = [regex]::new('^[0-9]*[<>]+$')
$script:ReDollarAssignPwsh = [regex]::new('^\$[A-Za-z_][A-Za-z0-9_:]*([-+*/]?=.*)?$')
$script:ReValuePrefix = [regex]::new('^[-+*/]?=')
$script:ReNoCommandStart = [regex]::new('^([$@0-9-]|"")')
$script:ReFlag = [regex]::new('^-')
$script:ReNameWord = [regex]::new('^[A-Za-z:][A-Za-z0-9_:.-]*$')
$script:ReUnreadable = [regex]::new('[$`*?\[]')
$script:ReQuoted1Bad = [regex]::new('[ \t\n;&|(){}<>`]')
$script:ReAllWs = [regex]::new('^[ \t\r]*$')
$script:ReWordSplit = [regex]::new('[ \t\r]+')

$wPat = '[ \t]+[A-Za-z][A-Za-z''-]*[,;:]?'
$prosePattern = '(^|[^A-Za-z0-9_])[A-Z][a-z''-]*[,;:]?' + $wPat + $wPat + $wPat + $wPat + '(' + $wPat + ')*[ \t]+[A-Za-z][A-Za-z''-]*[.!?]'
$script:ReProse = [regex]::new($prosePattern)

function New-KeysContext([bool]$pwshMode) {
  $esc = if ($pwshMode) { '`' } else { '\' }
  $specialChars = if ($pwshMode) { [char[]]@("`n", '`', '#', "'", '"', '@') } else { [char[]]@("`n", '\', '#', "'", '"', '<') }
  $nameChars = New-Object System.Collections.Generic.List[char]
  foreach ($c in @('.', '_', '+', ':', '/', '$', '-')) { [void]$nameChars.Add($c) }
  for ([int]$v = [int][char]'A'; $v -le [int][char]'Z'; $v++) { [void]$nameChars.Add([char]$v) }
  for ([int]$v = [int][char]'a'; $v -le [int][char]'z'; $v++) { [void]$nameChars.Add([char]$v) }
  for ([int]$v = [int][char]'0'; $v -le [int][char]'9'; $v++) { [void]$nameChars.Add([char]$v) }
  if ($pwshMode) { [void]$nameChars.Add('\') }
  $nameCharSet = New-Object 'System.Collections.Generic.HashSet[char]'
  foreach ($c in $nameChars) { [void]$nameCharSet.Add($c) }
  $segSepChars = if ($pwshMode) { [char[]]@("`n", ';', '&', '|', '(', ')', '{', '}') } else { [char[]]@("`n", ';', '&', '|', '(', ')', '{', '}', '`') }
  $sepCharsStr = "`n" + ';&|()' + $(if ($pwshMode) { '' } else { '`' })
  return @{
    Pwsh          = $pwshMode
    Esc           = $esc
    SpecialChars  = $specialChars
    QuoteEndChars = [char[]]@('"', $esc)
    NameCharSet   = $nameCharSet
    SegSepChars   = $segSepChars
    SepCharsStr   = $sepCharsStr
  }
}
$script:CtxBash = New-KeysContext $false
$script:CtxPwsh = New-KeysContext $true

# Position of the first char at or after $i that is in $chars, or $s.Length
# when none is found or $i is already past the end.
function NextIndexOfAny([string]$s, [int]$i, [char[]]$chars) {
  if ($i -ge $s.Length) { return $s.Length }
  $idx = $s.IndexOfAny($chars, $i)
  if ($idx -lt 0) { return $s.Length }
  return $idx
}

# Position of the first occurrence of $needle at or after $i, or -1.
function FindFrom([string]$s, [string]$needle, [int]$i) {
  if ($i -ge $s.Length) { return -1 }
  return $s.IndexOf($needle, $i)
}

# awk substr(): out-of-range start or length clamps to "" instead of throwing.
function AwkSubstr([string]$s, [int]$i, [int]$len) {
  if ($i -lt 0 -or $i -ge $s.Length -or $len -le 0) { return '' }
  $avail = $s.Length - $i
  if ($len -gt $avail) { $len = $avail }
  return $s.Substring($i, $len)
}

function IsAllCharsIn([string]$s, $set) {
  if ($s.Length -eq 0) { return $false }
  foreach ($ch in $s.ToCharArray()) { if (-not $set.Contains($ch)) { return $false } }
  return $true
}

# here(s, i): whether a PowerShell here-string opens at i, an @ and a quote
# with nothing but whitespace after them on the line.
function HereTest([string]$s, [int]$i) {
  if ((AwkSubstr $s $i 1) -ne '@') { return $false }
  $q = AwkSubstr $s ($i + 1) 1
  if ($q -ne '"' -and $q -ne "'") { return $false }
  $rest = AwkSubstr $s ($i + 2) ($s.Length - ($i + 2))
  $nl = $rest.IndexOf("`n")
  if ($nl -ge 0) { $rest = $rest.Substring(0, $nl) }
  return $script:ReAllWs.IsMatch($rest)
}

# An escaped character outside quotes is literal: whitespace, a separator, or
# a quote becomes "_" so that it neither splits nor quotes anything.
function EscapedChar([string]$d) {
  if ($d.Length -eq 1 -and $script:EscapedSet.Contains($d[0])) { return '_' }
  return $d
}

# Pass 1's view of a quoted span.
function Quoted1([string]$content) {
  if ($content -eq '' -or $script:ReQuoted1Bad.IsMatch($content)) { return '""' }
  return $content
}

function Invoke-Unreadable([string]$x) {
  return ($x -eq '""') -or $script:ReUnreadable.IsMatch($x)
}

# Append an entry once.
function AddEntry($eLines, $emitted, [string]$entry) {
  if ($emitted.Contains($entry)) { return }
  [void]$emitted.Add($entry)
  [void]$eLines.Add($entry)
}

# Invoke-Cands($w, $m, $from): the subcommand candidates in words from..m-1
# (0-based), as a list of @{ Word; Pos }. A word is a candidate position while
# every word before it is a flag, a redirection, or a word directly after a
# flag with no "=", which may be that flag's value. A word that cannot be read
# as a name gives "?". Directly after such a flag it gives "?" only when no
# name is found at this depth: `git -C "$WT" status` has a subcommand, and
# `hg -v "$verb"` does not.
function Invoke-Cands($w, [int]$m, [int]$from) {
  $result = New-Object System.Collections.Generic.List[object]
  $prevflag = $false
  $j = $from
  $held = -1
  $named = $false
  while ($j -lt $m) {
    $x = $w[$j]
    if ($script:ReFlag.IsMatch($x)) { $prevflag = (-not $x.Contains('=')); $j++; continue }
    if ($script:ReRedirPrefix.IsMatch($x)) {
      if ($script:ReRedirFull.IsMatch($x)) { $j += 2 } else { $j += 1 }
      $prevflag = $false
      continue
    }
    if ($script:ReNameWord.IsMatch($x)) {
      [void]$result.Add(@{ Word = $x; Pos = $j })
      $named = $true
    } elseif (Invoke-Unreadable $x) {
      if (-not $prevflag) {
        [void]$result.Add(@{ Word = '?'; Pos = $j })
      } elseif ($held -lt 0) {
        $held = $j
      }
    }
    if (-not $prevflag) { break }
    $prevflag = $false
    $j++
  }
  if ($held -ge 0 -and -not $named) {
    [void]$result.Add(@{ Word = '?'; Pos = $held })
  }
  return $result
}

# Every later word under key that reads as a name, flags and redirections
# skipped, with the same "?" rule as Invoke-Cands.
function Invoke-Tasks($eLines, $emitted, $w, [int]$m, [string]$key, [int]$from) {
  $n = 0
  $listItems = New-Object System.Collections.Generic.List[string]
  $prevflag = $false
  $j = $from
  while ($j -lt $m) {
    $x = $w[$j]
    if ($script:ReFlag.IsMatch($x)) { $prevflag = (-not $x.Contains('=')); $j++; continue }
    if ($script:ReRedirPrefix.IsMatch($x)) {
      if ($script:ReRedirFull.IsMatch($x)) { $j++ }
      $prevflag = $false
      $j++
      continue
    }
    if ($script:ReNameWord.IsMatch($x)) {
      $n++
      [void]$listItems.Add("+$key $x")
    } elseif ((-not $prevflag) -and (Invoke-Unreadable $x)) {
      [void]$listItems.Add("+$key ?")
    }
    $prevflag = $false
    $j++
  }
  if ($n -gt 8) { AddEntry $eLines $emitted "+$key !"; return }
  foreach ($item in $listItems) { AddEntry $eLines $emitted $item }
}

# One simple command: drop the leading words that are shell syntax, then add
# its entries to $st.SegText. A cache keyed by the segment's own text, since a
# command built of many identical simple commands -- "a b; a b; a b" repeated
# thousands of times, or the same $(x) substituted many times over -- would
# otherwise redo the same word-by-word work once per repeat.
function Invoke-Segment([string]$text, $ctx, $st) {
  if ($st.SegCache.ContainsKey($text)) {
    $cached = $st.SegCache[$text]
    if ($null -ne $cached) { [void]$st.SegText.Add($cached) }
    return
  }
  $result = Invoke-SegmentCompute $text $ctx
  $st.SegCache[$text] = $result
  if ($null -ne $result) { [void]$st.SegText.Add($result) }
}

# Returns the segtext entry for $text ("READ" or the joined entry lines), or
# $null when the segment adds nothing (leading syntax only, or a header word).
function Invoke-SegmentCompute([string]$text, $ctx) {
  $parts = $script:ReWordSplit.Split($text)
  $w = New-Object System.Collections.Generic.List[string]
  $w.AddRange($parts)
  if ($w.Count -gt 0 -and $w[0] -eq '') { $w.RemoveAt(0) }
  if ($w.Count -gt 0 -and $w[$w.Count - 1] -eq '') { $w.RemoveAt($w.Count - 1) }
  $m = $w.Count
  $k = 0
  while ($k -lt $m) {
    if ($script:ReAssignWord.IsMatch($w[$k])) { $k++; continue }
    if ($script:ReRedirPrefix.IsMatch($w[$k])) {
      if ($script:ReRedirFull.IsMatch($w[$k])) { $k += 2 } else { $k += 1 }
      continue
    }
    if ($script:ShellWordSet.Contains($w[$k])) { $k++; continue }
    if ($script:WrapperSet.Contains($w[$k])) {
      $k++
      while ($k -lt $m -and $script:ReFlag.IsMatch($w[$k])) { $k++ }
      continue
    }
    if ($script:Wrapper1Set.Contains($w[$k])) {
      $k++
      while ($k -lt $m -and $script:ReFlag.IsMatch($w[$k])) { $k++ }
      if ($k -lt $m) { $k++ }
      continue
    }
    if ($ctx.Pwsh -and $w[$k] -eq '.') { $k++; continue }
    if ($ctx.Pwsh -and $script:ReDollarAssignPwsh.IsMatch($w[$k])) {
      if ($w[$k].Contains('=')) {
        $rest = $w[$k].Substring($w[$k].IndexOf('=') + 1)
        if ($rest -eq '') { $k++ } else { $w[$k] = $rest }
      } elseif ($k + 1 -lt $m -and $script:ReValuePrefix.IsMatch($w[$k + 1])) {
        $rest = $w[$k + 1].Substring($w[$k + 1].IndexOf('=') + 1)
        $k++
        if ($rest -eq '') { $k++ } else { $w[$k] = $rest }
      } else { break }
      if ($k -ge $m -or $script:ReNoCommandStart.IsMatch($w[$k])) { return }
      break
    }
    break
  }
  if ($k -ge $m -or $script:HeaderSet.Contains($w[$k])) { return }
  $w = $w.GetRange($k, $m - $k)
  $m = $w.Count
  $first = $w[0]

  if ($first -eq '""' -or -not ($first -eq '[' -or $first -eq '[[' -or (IsAllCharsIn $first $ctx.NameCharSet))) {
    return 'READ'
  }

  $emitted = New-Object 'System.Collections.Generic.HashSet[string]'
  $eLines = New-Object System.Collections.Generic.List[string]
  AddEntry $eLines $emitted $first
  $key = New-Object System.Collections.Generic.List[string]
  $kpos = New-Object System.Collections.Generic.List[int]
  [void]$key.Add($first); [void]$kpos.Add(0)
  $lo = 0; $hi = 0
  for ($d = 2; $d -le 3; $d++) {
    $cnt = 0
    for ($x = $lo; $x -le $hi; $x++) {
      $candList = Invoke-Cands $w $m ($kpos[$x] + 1)
      foreach ($cand in $candList) {
        if ($cand.Word -eq '?') { AddEntry $eLines $emitted ($key[$x] + ' ?'); continue }
        $cnt++
        $newKey = $key[$x] + ' ' + $cand.Word
        [void]$key.Add($newKey); [void]$kpos.Add($cand.Pos)
        AddEntry $eLines $emitted $newKey
      }
    }
    if ($cnt -gt 4) { return 'READ' }
    $lo = $hi + 1; $hi = $key.Count - 1
  }
  for ($x = 0; $x -lt $key.Count; $x++) {
    Invoke-Tasks $eLines $emitted $w $m $key[$x] ($kpos[$x] + 1)
  }
  return ($eLines -join "`n")
}

# Split pass-1 text into segments on the separators. The redirections 2>&1,
# >&2, and &> are blanked first so that their & does not split. { and } split
# only as words of their own, so ${HOME} and x.{a,b} stay whole.
function Invoke-AddSegments([string]$t, $ctx, $st) {
  $t = $t -replace '[0-9]*[<>]&[0-9-]*', ' '
  $t = $t -replace '&>', ' >'
  $n = $t.Length
  $cur = New-Object System.Text.StringBuilder
  $i = 0
  while ($true) {
    $j = NextIndexOfAny $t $i $ctx.SegSepChars
    [void]$cur.Append($t.Substring($i, $j - $i))
    if ($j -ge $n) { break }
    $c = $t[$j]
    if ($c -eq '{' -or $c -eq '}') {
      $prev = if ($j -gt 0) { [string]$t[$j - 1] } else { ' ' }
      $next1 = if ($j + 1 -lt $n) { [string]$t[$j + 1] } else { ' ' }
      $haystack = ' ' + "`t" + $ctx.SepCharsStr
      $prevOk = $haystack.IndexOf($prev, [StringComparison]::Ordinal) -ge 0
      $nextOk = $haystack.IndexOf($next1, [StringComparison]::Ordinal) -ge 0
      if (-not $prevOk -or -not $nextOk) {
        [void]$cur.Append($c)
        $i = $j + 1
        continue
      }
    }
    Invoke-Segment $cur.ToString() $ctx $st
    [void]$cur.Clear()
    $i = $j + 1
  }
  Invoke-Segment $cur.ToString() $ctx $st
}

# A cache keyed by the substitution body's own text, since the same $(x)
# substituted many times over would otherwise rescan and re-split it every time.
function Invoke-Body([string]$b, $ctx, $st) {
  if ($st.BodyCache.ContainsKey($b)) {
    $cached = $st.BodyCache[$b]
    if ($null -eq $cached) { $st.Bad = $true; return }
    foreach ($e in $cached) { [void]$st.SegText.Add($e) }
    return
  }
  $startCount = $st.SegText.Count
  $r = Invoke-Scan $b $ctx $st
  if ($st.Bad) { $st.BodyCache[$b] = $null; return }
  Invoke-AddSegments (Invoke-Collapse $r.P1 $ctx $st) $ctx $st
  $added = New-Object System.Collections.Generic.List[string]
  for ($idx = $startCount; $idx -lt $st.SegText.Count; $idx++) { [void]$added.Add($st.SegText[$idx]) }
  $st.BodyCache[$b] = $added
}

# Position of the next opener at or after $i, as @{ Pos; IsBacktick }, with
# Pos = $t.Length when none occurs. $openers holds each 2-character opener to
# look for ("$(", and in bash "<(" and ">("); a backtick is also an opener,
# except for pwsh's own subst(), which never treats one as a substitution.
function NextOpenerPos([string]$t, [int]$i, [string[]]$openers, [bool]$backtickToo) {
  if ($i -ge $t.Length) { return @{ Pos = $t.Length; IsBacktick = $false } }
  $best = $t.Length
  foreach ($opener in $openers) {
    $idx = $t.IndexOf($opener, $i)
    if ($idx -ge 0 -and $idx -lt $best) { $best = $idx }
  }
  $bestIsBacktick = $false
  if ($backtickToo) {
    $btIdx = $t.IndexOf('`', $i)
    if ($btIdx -ge 0 -and $btIdx -lt $best) { $best = $btIdx; $bestIsBacktick = $true }
  }
  return @{ Pos = $best; IsBacktick = $bestIsBacktick }
}

function NextSubstPos([string]$t, [int]$i, [bool]$pwshMode) {
  $openers = if ($pwshMode) { [string[]]@('$(') } else { [string[]]@('$(', '<(', '>(') }
  return NextOpenerPos $t $i $openers (-not $pwshMode)
}

function NextCollapsePos([string]$t, [int]$i, [bool]$pwshMode) {
  $openers = if ($pwshMode) { [string[]]@('$(', '@(') } else { [string[]]@('$(', '<(', '>(') }
  return NextOpenerPos $t $i $openers (-not $pwshMode)
}

# Pass 2: each $( ) body, counting nested parentheses, and in bash each
# backtick pair and each <( )/>( ) process substitution. The scan steps into a
# $( ) body rather than past it, which is how a nested substitution is found
# (i moves 2 past the opener, not past the whole span, so an opener inside the
# body is found again on the next iteration). $(( )) is arithmetic, with no
# command in it but a nested $( ), so its own "((" is skipped rather than read
# as a body.
function Invoke-Subst([string]$t, $ctx, $st) {
  $n = $t.Length
  $i = 0
  while ($true) {
    $np = NextSubstPos $t $i $ctx.Pwsh
    if ($np.Pos -ge $n) { return }
    if ((-not $np.IsBacktick) -and (AwkSubstr $t $np.Pos 3) -eq '$((') {
      $i = $np.Pos + 3
      continue
    }
    if ($np.IsBacktick) {
      $j = FindFrom $t '`' ($np.Pos + 1)
      if ($j -lt 0) { $st.Bad = $true; return }
      Invoke-Body ($t.Substring($np.Pos + 1, $j - $np.Pos - 1)) $ctx $st
      if ($st.Bad) { return }
      $i = $j + 1
      continue
    }
    $depth = 1
    $j = $np.Pos + 2
    while ($depth -gt 0) {
      $j = NextIndexOfAny $t $j $script:ParenChars
      if ($j -ge $n) { $st.Bad = $true; return }
      if ($t[$j] -eq '(') { $depth++ } else { $depth-- }
      $j++
    }
    Invoke-Body ($t.Substring($np.Pos + 2, $j - $np.Pos - 3)) $ctx $st
    if ($st.Bad) { return }
    $i = $np.Pos + 2
  }
}

# Pass 1 reads a substitution, $( ) or a backtick pair, as the one word "$",
# and in bash a process substitution, <( ) or >( ), too; in pwsh, an array
# subexpression, @( ), as well. Pass 2 reads a substitution's body (collapse
# does not, so the words after one stay with the command around it: `git diff
# $(git merge-base a b) HEAD` has no command named HEAD). Unlike Invoke-Subst,
# this always advances past the whole span, since nothing here needs to look
# inside a body for a nested substitution -- Invoke-Subst already does that.
function Invoke-Collapse([string]$t, $ctx, $st) {
  $n = $t.Length
  $i = 0
  $out = New-Object System.Text.StringBuilder
  while ($true) {
    $np = NextCollapsePos $t $i $ctx.Pwsh
    [void]$out.Append($t.Substring($i, $np.Pos - $i))
    if ($np.Pos -ge $n) { return $out.ToString() }
    if ($np.IsBacktick) {
      $k = FindFrom $t '`' ($np.Pos + 1)
      if ($k -lt 0) { $st.Bad = $true; return $out.ToString() }
      [void]$out.Append('$')
      $i = $k + 1
      continue
    }
    $depth = 1
    $k = $np.Pos + 2
    while ($depth -gt 0) {
      $k = NextIndexOfAny $t $k $script:ParenChars
      if ($k -ge $n) { $st.Bad = $true; return $out.ToString() }
      if ($t[$k] -eq '(') { $depth++ } else { $depth-- }
      $k++
    }
    [void]$out.Append('$')
    $i = $k
  }
}

# scan(s): the P1/P2 views of the text s, or $st.Bad set when a quote, a
# heredoc, or a here-string is left open, or when an expanding heredoc body
# holds a substitution. A quoted heredoc body, like single-quoted text,
# expands nothing.
function Invoke-Scan([string]$s, $ctx, $st) {
  $p1 = New-Object System.Text.StringBuilder
  $p2 = New-Object System.Text.StringBuilder
  $n = $s.Length
  $i = 0
  $atword = $true
  $pendKind = New-Object System.Collections.Generic.List[string]
  $pendWord = New-Object System.Collections.Generic.List[string]
  $pendQuoted = New-Object System.Collections.Generic.List[bool]
  $pendDash = New-Object System.Collections.Generic.List[bool]

  while ($i -lt $n) {
    $c = $s[$i]

    if ($c -eq "`n") {
      [void]$p1.Append("`n"); [void]$p2.Append("`n")
      $i++
      $atword = $true
      for ($k = 0; $k -lt $pendKind.Count; $k++) {
        while ($true) {
          if ($i -ge $n) { $st.Bad = $true; return $null }
          $e = $s.IndexOf("`n", $i)
          if ($e -lt 0) { $e = $n }
          $line = $s.Substring($i, $e - $i)
          $i = $e + 1
          if ($pendKind[$k] -eq 'pwsh') {
            if ($line.Length -ge 2 -and $line.Substring(0, 2) -eq ($pendWord[$k] + '@')) { break }
          } else {
            if ($pendDash[$k]) { $line = $line.TrimStart("`t") }
            if ($line -ceq $pendWord[$k]) { break }
          }
          if ((-not $pendQuoted[$k]) -and ($line.Contains('$(') -or ((-not $ctx.Pwsh) -and $line.Contains('`')))) { $st.Bad = $true; return $null }
        }
      }
      $pendKind.Clear(); $pendWord.Clear(); $pendQuoted.Clear(); $pendDash.Clear()
      continue
    }

    if ($c -eq $ctx.Esc) {
      $d = if ($i + 1 -lt $n) { [string]$s[$i + 1] } else { '' }
      $i += 2
      if ($d -eq "`n") { [void]$p1.Append(' '); [void]$p2.Append(' ') }
      elseif ($d -ne '') {
        $e = EscapedChar $d
        [void]$p1.Append($e)
        if (@('$', '`', '\', '"', "'") -contains $d) { [void]$p2.Append('_') } else { [void]$p2.Append($e) }
      }
      $atword = $false
      continue
    }

    if ($c -eq '#' -and $atword) {
      $e = $s.IndexOf("`n", $i)
      if ($e -lt 0) { $e = $n }
      $i = $e
      continue
    }

    if ($c -eq "'") {
      $contentSb = New-Object System.Text.StringBuilder
      $j = $i + 1
      $start = $j
      while ($true) {
        $q = FindFrom $s "'" $j
        if ($q -lt 0) { $q = $n }
        $j = $q
        if ($j -ge $n) { $st.Bad = $true; return $null }
        if ($ctx.Pwsh -and ($j + 1 -lt $n) -and $s[$j + 1] -eq "'") {
          [void]$contentSb.Append($s.Substring($start, $j - $start + 1))
          $j += 2
          $start = $j
          continue
        }
        break
      }
      [void]$contentSb.Append($s.Substring($start, $j - $start))
      [void]$p1.Append((Quoted1 $contentSb.ToString()))
      $i = $j + 1
      $atword = $false
      continue
    }

    if ($c -eq '"') {
      $contentSb = New-Object System.Text.StringBuilder
      $p2cSb = New-Object System.Text.StringBuilder
      $j = $i + 1
      $start = $j
      while ($true) {
        $j = NextIndexOfAny $s $j $ctx.QuoteEndChars
        if ($j -ge $n) { $st.Bad = $true; return $null }
        $d = $s[$j]
        if ($d -eq $ctx.Esc) {
          $e2 = if ($j + 1 -lt $n) { [string]$s[$j + 1] } else { '' }
          $escOk = if ($ctx.Pwsh) { $true } else { $script:DquoteBashEscapes.Contains($e2) }
          if ($escOk) {
            $run = $s.Substring($start, $j - $start)
            [void]$contentSb.Append($run)
            if ($e2 -ne "`n") { [void]$contentSb.Append($e2) }
            [void]$p2cSb.Append($run).Append('_')
            $j += 2
            $start = $j
            continue
          }
        }
        if ($d -eq '"') {
          if ($ctx.Pwsh -and ($j + 1 -lt $n) -and $s[$j + 1] -eq '"') {
            $run = $s.Substring($start, $j - $start)
            [void]$contentSb.Append($run).Append('"')
            [void]$p2cSb.Append($run).Append('_')
            $j += 2
            $start = $j
            continue
          }
          break
        }
        $j++
      }
      $run = $s.Substring($start, $j - $start)
      [void]$contentSb.Append($run)
      [void]$p2cSb.Append($run)
      [void]$p1.Append((Quoted1 $contentSb.ToString()))
      [void]$p2.Append('"').Append($p2cSb.ToString()).Append('"')
      $i = $j + 1
      $atword = $false
      continue
    }

    if ((-not $ctx.Pwsh) -and (AwkSubstr $s $i 2) -eq '<<' -and (AwkSubstr $s $i 3) -ne '<<<') {
      $j = $i + 2
      $dash = $false
      if ((AwkSubstr $s $j 1) -eq '-') { $dash = $true; $j++ }
      while ((AwkSubstr $s $j 1) -eq ' ' -or (AwkSubstr $s $j 1) -eq "`t") { $j++ }
      $wSb = New-Object System.Text.StringBuilder
      $quotedFlag = $false
      while ($j -lt $n) {
        $d = $s[$j]
        if (@(' ', "`t", "`n", ';', '&', '|', '(', ')', '<', '>') -contains $d) { break }
        if ($d -eq "'" -or $d -eq '"' -or $d -eq '\') { $quotedFlag = $true }
        else { [void]$wSb.Append($d) }
        $j++
      }
      $wtext = $wSb.ToString()
      if ($wtext -ne '') {
        [void]$pendKind.Add('bash'); [void]$pendWord.Add($wtext); [void]$pendQuoted.Add($quotedFlag); [void]$pendDash.Add($dash)
        [void]$p1.Append('<<').Append($wtext)
        [void]$p2.Append(' ')
        $i = $j
        $atword = $false
        continue
      }
    }

    if ($ctx.Pwsh -and (HereTest $s $i)) {
      $d = $s[$i + 1]
      [void]$pendKind.Add('pwsh'); [void]$pendWord.Add([string]$d); [void]$pendQuoted.Add($d -eq "'"); [void]$pendDash.Add($false)
      [void]$p1.Append('""')
      [void]$p2.Append('""')
      $i += 2
      $atword = $false
      continue
    }

    $j = NextIndexOfAny $s ($i + 1) $ctx.SpecialChars
    $run = $s.Substring($i, $j - $i)
    [void]$p1.Append($run)
    [void]$p2.Append($run)
    $i = $j
    $lastChar = if ($run.Length -gt 0) { $run[$run.Length - 1] } else { $null }
    $atword = ($null -ne $lastChar -and $script:WordSepChars.Contains($lastChar))
  }

  if ($pendKind.Count -gt 0) { $st.Bad = $true }
  return @{ P1 = $p1.ToString(); P2 = $p2.ToString() }
}
