#Requires -Version 5.1
# House-style lint and reminders for the assistant's prose, for a Windows install
# where the PowerShell tool is the shell. The bash pair lint.sh + lint.awk is the
# same lint; lint-corpus.tsv is checked against both matchers, so a change to one
# without the other fails lint-test.ps1 or lint-test.sh.
#   --record  Stop hook: lint the final reply, save a note, never block.
#   --emit    UserPromptSubmit hook: print any saved note into the next turn,
#             clear it, then print the standing style reminder.
#   --nudge   PostToolUse hook on Write|Edit: when the file just written holds
#             prose, tell the model to re-read and fix it in place now.
# Never blocking is the point: a Stop hook cannot patch a reply, so blocking one
# costs a full re-emission of an answer the reader has already seen. The
# correction lands on the next reply instead. Every path exits 0.
#
# ASCII only, so 5.1 cannot mangle it reading a BOM-less file as the ANSI
# codepage. Every non-ASCII character is written as a regex \uXXXX escape or
# built from [char]0xXXXX.

# --- which shell owns this hook -------------------------------------------
# One of lint.ps1 and lint.sh emits, never both; shell-owner.ps1 is the test, and
# the mirror of it sits in lint.sh. lint-test.ps1 dot-sources this file with
# $LintPs1LoadOnly set, so the guard and the hook plumbing are both skipped and
# the matcher is tested on any platform.
if (-not $LintPs1LoadOnly) {
  . (Join-Path $PSScriptRoot 'shell-owner.ps1')
  if (-not $PowerShellOwnsHook) { exit 0 }
}

# The draft-fence scanner, shared with gate.ps1.
. (Join-Path $PSScriptRoot 'draft.ps1')

$ErrorActionPreference = 'Stop'
$EM = [char]0x2014

$REMINDER = 'Style, for this reply and any prose written to files: an inanimate subject takes no agentive verb' + $EM + '"the entry declared in the `plugins` block", never "the `plugins` block owns/says/gives". Em dashes unspaced (word' + $EM + 'word). Plain words.'
$NUDGE = "You just wrote prose to a file. Re-read it now for inanimate agency (report/build/entry/declaration as subject of says/gives/owns/configures/carries), spaced em dashes, and banned vocabulary; fix in place before moving on. If this text will publish under the user's name, have a fresh-context subagent sweep it against the rules before hand-over."

# --- patterns (mirrors lint.awk BEGIN) ------------------------------------
# Four groups. Banned words and spaced em dashes are exact. A missing Oxford
# comma is caught only in a list of single words with two commas before the
# final "and" or "or" ("json, xml, html and plain"). A multi-word item, or a
# list with one comma ("a, b and c"), looks too much like a clause to flag. Inanimate agency is
# precision-first: a determiner-led or pronoun subject followed by a verb of
# speech, volition, cognition, or configuration (finite, or a participle such as
# "a file declaring an alias"), with the subject checked against an animate list,
# passives and adjectival participles excluded by the gap words, reduced passives
# ("the rule stated in", "three named endpoints") excluded by the word after the
# verb, and the noun-or-verb forms (names, states, claims, offers) kept only when
# an object-like word follows. Left out on purpose: holds, keeps, writes, uses,
# adds, sets, and "notes". A hand check of 90 hits found the first group mostly
# code mechanics (a map holds a value, a task writes a file, which rules.md
# allows as a program doing its job), and "notes" is nearly always the noun. The
# finite subject patterns are tried shortest first, so "the report says we
# decided" is caught on "the report says" before the longer span that swallows
# the human clause is tried.
$WCH = "0-9A-Za-z'\u2019\u2014_-"   # the word characters of a subject span
$VCH = "0-9A-Za-z'\u2019_-"         # ... without the em dash, for a bare word
$W   = "[$WCH]+ "
$DET = '(the|a|an|this|that|these|those|each|every|its|our|my|your|neither|either|both|no)'
$ADV = '((never|also|always|still|then|only|just|already|itself) )?'
$VERB = '(says|said|tells|told|wants|wanted|knows|knew|decides|decided|claims|claimed|asks|asked' +
        '|expects|expected|promises|promised|believes|believed|thinks|thought|concludes|concluded' +
        '|states|stated|declares|declared|insists|insisted|refuses|refused|assumes|assumed' +
        '|credits|credited|names|named|judges|judged|offers|offered|withholds|withheld|intends|intended' +
        '|wishes|wished|cares|cared|remembers|remembered|forgets|forgot|exempts|exempted' +
        '|configures|configured|enables|enabled|owns|owned|gives|gave|carries|carried' +
        '|produces|produced|shares|shared|joins|joined)'
$PART = '(saying|telling|wanting|knowing|deciding|claiming|asking|expecting|promising|believing' +
        '|thinking|concluding|stating|declaring|insisting|refusing|assuming|crediting|naming|judging' +
        '|offering|withholding|intending|wishing|exempting|configuring|enabling|owning|giving|carrying' +
        '|producing|sharing|joining)'
$SB = '(^|[^0-9A-Za-z_-])'
$NB = '([^0-9A-Za-z_-]|$)'

$RX = New-Object 'System.Collections.Generic.List[System.Text.RegularExpressions.Regex]'
$KIND = New-Object 'System.Collections.Generic.List[string]'
# Finite subject patterns with one to five words between the determiner and the
# verb, tried in that order (see above). Then the relative clause, the bare
# pronoun, the "whose" possessive, and the participle.
$span = ''
for ($k = 1; $k -le 5; $k++) {
  $span += $W
  $RX.Add([regex]::new($SB + $DET + ' ' + $span + $ADV + $VERB + $NB)); $KIND.Add('finite')
}
$RX.Add([regex]::new($SB + "[$WCH]+,? (that|which) " + $ADV + $VERB + $NB)); $KIND.Add('rel')
$RX.Add([regex]::new($SB + '(it|this|that|neither|either|both|each) ' + $ADV + $VERB + $NB)); $KIND.Add('finite')
$RX.Add([regex]::new($SB + $DET + " ($W)?($W)?($W)?[$WCH]+,? whose ")); $KIND.Add('whose')
$RX.Add([regex]::new($SB + $DET + " ($W)?($W)?($W)?" + $PART + ' ')); $KIND.Add('part')

# In each of the nine a determiner or pronoun comes first, then a verb from one of
# the lists or "whose", so a sentence with no verb after its first determiner
# matches none of them, and the nine are skipped for it. The gate costs two
# matches against the nine it skips, and on a 40,000-line reply that is the
# difference between 15 s and 3 s.
$RX_SUBJ = [regex]::new($SB + '(' + $DET + '|it|which) ')
$RX_VERB = [regex]::new($SB + '(' + $VERB + '|' + $PART + '|whose)' + $NB)

$RX_BANNED = [regex]::new($SB + '(load-bearing|vacuous|vacuously|non-vacuous|owe|owes|owed|shape|shapes|slot|slots' +
                          '|channel|channels|deleak|de-risk|derisk)' + $NB)
$RX_DASH = [regex]::new("[ \t]\u2014|\u2014[ \t]")
$RX_OXFORD = [regex]::new('(?<![0-9A-Za-z_-])[0-9A-Za-z_-]+, [0-9A-Za-z_-]+, [0-9A-Za-z_-]+ (and|or) [0-9A-Za-z_-]+')

# Subjects that act: people, roles, and the agents and sessions that contain one.
$ANIMATE = ' i we you he she they user users author authors maintainer maintainers reviewer reviewers' +
           ' team teams developer developers dev devs engineer engineers contributor contributors reader' +
           ' readers writer writers person people agent agents assistant model human humans folks everyone' +
           ' someone anybody nobody who session sessions subagent subagents verifier verifiers orchestrator' +
           ' conductor delegate delegates critic judge customer customers client clients stakeholder' +
           ' stakeholders owner owners manager managers lead leads designer designers tester testers' +
           ' colleague colleagues operator operators reporter reporters commenter commenters requester' +
           ' requesters bot bots vendor vendors sponsor sponsors '
# A gap word from this list means a passive, an adjectival participle, or a
# clause boundary, so the verb is not this subject's.
$SKIPGAP = " is are was were be been being to not n't does do did can could will would may might must" +
           ' should has have had the a an this that these those each every its our my your neither' +
           ' either both no if when unless because since while whether after before until where' +
           ' which who whom and or but '
# After a past form, a preposition means a reduced passive ("the rule stated in").
$PREP = ' in at on by above below under over within there here earlier through via from with as for' +
        ' into onto than '
# A past form is a verb rather than a participle only when an object-like word
# follows: "the report concluded the build is fine", not "three named endpoints".
$PASTOBJ = ' the a an its their this that these those what which who how why where when whether it' +
           ' them him her me us you one no every each some any all both several many none nothing' +
           ' something anything everything code quote '
$AMBIG = ' names states claims offers judges credits wishes cares shares '
$NOOBJ = ' of is are was were and or as for to in on at by with from than '
# After "that"/"which"/"who", a determiner or pronoun means a clause object ("the
# spec states that the build is fine"), a verb means the noun reading ("the four
# claims that need a live run").
$CLAUSE = ' the a an its their this these those it we you they i there '
# "the loop gives up" is phrasal, not a verb of giving.
$PHRASAL = ' up way in out back off '
# "states plainly" keeps the verb reading; "names imply" does not.
$ADVEXC = ' imply apply reply supply rely comply multiply ally family early only likely '

$RULE = @{
  'banned word'      = 'that word is banned in prose; use a plain synonym'
  'spaced em dash'   = 'an em dash takes no surrounding spaces: write word' + $EM + 'word, never word ' + $EM + ' word'
  'oxford comma'     = 'a list of three or more items takes a comma before the final "and" or "or": write a, b, and c'
  'inanimate agency' = 'an inanimate subject must not take a verb of speech, volition, or cognition; say who the real actor is, or rewrite around the act'
}
$ORDER = @('banned word', 'spaced em dash', 'oxford comma', 'inanimate agency')

function Get-Trimmed([string]$x) { return $x.Trim(@(' ', "`t")) }

# The reported text starts and ends on a word, so a multibyte boundary character
# never leaves a partial UTF-8 sequence in the note.
function Get-Example([string]$x) {
  $x = [regex]::Replace($x, '^[^0-9A-Za-z]+', '')
  return [regex]::Replace($x, '[^0-9A-Za-z]+$', '')
}

function Test-Adverb([string]$gword) {
  return ([regex]::IsMatch($gword, '[a-z][a-z]ly$') -and -not $ADVEXC.Contains(" $gword "))
}

# Fenced blocks are dropped by matching the opening marker (three or more of the
# same character, closed by at least as many); a fence left open at the end of
# the text is treated as prose, so a truncated reply is still linted. Inline
# code, straight or curly double-quoted text, and markdown emphasis or link
# syntax around a word are reduced so the sentence keeps its grammar.
function Remove-CodeSpans([string]$t) {
  $out = New-Object System.Text.StringBuilder
  $held = New-Object System.Text.StringBuilder
  $fence = ''
  foreach ($line in $t.Split("`n")) {
    $fm = [regex]::Match($line, '^[ \t]*(`{3,}|~{3,})')
    if ($fm.Success) {
      $mk = [regex]::Replace($fm.Value, '^[ \t]+', '')
      if ($fence -eq '') {
        $fence = $mk
        [void]$held.Clear(); [void]$held.Append($line).Append("`n")
        continue
      }
      if ($mk[0] -eq $fence[0] -and $mk.Length -ge $fence.Length) {
        $fence = ''; [void]$held.Clear()
        continue
      }
    }
    if ($fence -ne '') { [void]$held.Append($line).Append("`n"); continue }
    [void]$out.Append($line).Append("`n")
  }
  if ($fence -ne '') { [void]$out.Append($held.ToString()) }
  $o = $out.ToString()
  $o = [regex]::Replace($o, '`[^`\n]*`', 'CODE')
  $o = [regex]::Replace($o, '"[^"\n]*"', 'QUOTE')
  $o = [regex]::Replace($o, '\u201c[^\u201d\n]*\u201d', 'QUOTE')
  $o = [regex]::Replace($o, '\]\([^)\n]*\)', '')
  $o = [regex]::Replace($o, '[*\[]+', '')
  return [regex]::Replace($o, '[Ss]lack channel|[Mm]essage channel|[Bb]yte channel|[Rr]elease channel|[Aa]rray shape|[Tt]ensor shape|[Tt]imetable slot|[Tt]ime slot', 'LITERAL')
}

# One hit per sentence at most, returned as the example text, or $null. An
# excluded match is stepped past so a real hit later in the same sentence is
# still found: "the grounds that the rule wants" is excluded on "that", then
# "the rule wants" is tried on its own.
function Get-AgencyHit([string]$s, [string]$l) {
  $sm = $RX_SUBJ.Match($l)
  if (-not $sm.Success) { return $null }
  if (-not $RX_VERB.IsMatch($l.Substring($sm.Index))) { return $null }
  for ($p = 0; $p -lt $RX.Count; $p++) {
    $pkind = $KIND[$p]
    $pos = 0
    while ($pos -lt $l.Length) {
      $m = $RX[$p].Match($l.Substring($pos))
      if (-not $m.Success) { break }
      # stepping past an excluded match must not turn the middle of a word into a
      # start-of-text boundary
      if ($m.Index -eq 0 -and $pos -gt 0 -and [regex]::IsMatch($l.Substring($pos - 1, 1), '[0-9A-Za-z_-]')) {
        $pos++
        continue
      }
      $start = $pos + $m.Index
      $len = $m.Length
      $pos = $start + 1
      $spanText = Get-Trimmed $l.Substring($start, $len)
      $nextc = $l.Substring($start + $len - 1, 1)   # the boundary character right after the verb
      $after = $l.Substring($start + $len)
      $after = [regex]::Replace($after, '^[^0-9A-Za-z]+', '')
      $after2 = [regex]::Replace($after, "^[$VCH]+[^0-9A-Za-z]+", '')
      $after2 = [regex]::Replace($after2, "(?s)[^$VCH].*$", '')
      $after = [regex]::Replace($after, "(?s)[^$VCH].*$", '')
      if ([regex]::IsMatch($spanText, '^that said')) { continue }
      $words = [regex]::Split($spanText, '[ \t]+')
      $nw = $words.Count
      $gap = $nw - 1
      $vword = if ($pkind -eq 'whose') { 'whose' } else { $words[$nw - 1] }
      $vword = [regex]::Replace($vword, "[^$VCH]", '')
      $subOk = $true
      for ($i = 1; $i -le $gap; $i++) {
        $gword = [regex]::Replace($words[$i - 1], "[^$VCH]", '')
        if ($ANIMATE.Contains(" $gword ")) { $subOk = $false }
        if ($i -gt 1 -and -not ($pkind -eq 'rel' -and $i -eq 2) -and $SKIPGAP.Contains(" $gword ")) { $subOk = $false }
        if ($i -eq $gap -and [regex]::IsMatch($gword, "('s|\u2019s|s')$")) { $subOk = $false }
      }
      if (-not $subOk) { continue }
      if ($pkind -ne 'whose' -and $pkind -ne 'part' -and -not [regex]::IsMatch($vword, 's$')) {
        # a past form: a verb only when an object-like word follows, else a
        # participle or a reduced passive
        if ([regex]::IsMatch($nextc, '[,.;:]')) { continue }
        if ($PREP.Contains(" $after ")) { continue }
        if ($after -ne '' -and -not [regex]::IsMatch($after, '^[0-9]') -and -not $PASTOBJ.Contains(" $after ")) { continue }
        if ($vword -eq 'named' -and ($after -eq 'code' -or $after -eq 'quote')) { continue }   # "a case named `foo`"
      }
      if ([regex]::IsMatch($vword, '^(gives|gave)$') -and $PHRASAL.Contains(" $after ")) { continue }
      if ($AMBIG.Contains(" $vword ")) {
        # a noun-or-verb word is a verb here only when an object-like word follows
        # it: "the report names the file", not "the spec names, 163 lines" or
        # "the shorter names re-wrapped"
        if ([regex]::IsMatch($nextc, '[,.;:]') -or $after -eq '' -or $NOOBJ.Contains(" $after ")) { continue }
        if ([regex]::IsMatch($after, '^(that|which|who)$')) {
          if (-not $CLAUSE.Contains(" $after2 ")) { continue }
        } elseif (-not $PASTOBJ.Contains(" $after ") -and -not (Test-Adverb $after)) { continue }
      }
      return (Get-Example $s.Substring($start, $len))
    }
  }
  return $null
}

# With -AsNote, returns the note the next turn opens with, or '' when the text is
# clean. Otherwise returns one "<group>`t<matched text>" line per flagged
# sentence. Pure: no files, no environment.
function Invoke-Lint([string]$text, [switch]$AsNote) {
  $count = @{}
  $example = @{}
  $lines = New-Object 'System.Collections.Generic.List[string]'
  # One list, cleared each sentence, rather than one built per sentence: New-Object
  # on a generic type costs 75 microseconds a call, which on a 40,000-line reply is
  # 3 of the 7 seconds this function used to take.
  $found = New-Object 'System.Collections.Generic.List[string[]]'
  foreach ($s in [regex]::Split((Remove-CodeSpans $text), '[.!?;:]+[ \t\n]+|\n+')) {
    if ([regex]::IsMatch($s, '^[ \t]*$')) { continue }
    $l = $s.ToLowerInvariant()
    $found.Clear()
    $dm = $RX_DASH.Match($s)
    if ($dm.Success) { $found.Add(@('spaced em dash', $dm.Value)) }
    $bm = $RX_BANNED.Match($l)
    if ($bm.Success) { $found.Add(@('banned word', (Get-Trimmed $s.Substring($bm.Index, $bm.Length)))) }
    $om = $RX_OXFORD.Match($s)
    if ($om.Success) { $found.Add(@('oxford comma', $om.Value)) }
    $ag = Get-AgencyHit $s $l
    if ($null -ne $ag) { $found.Add(@('inanimate agency', $ag)) }
    foreach ($f in $found) {
      $g = $f[0]
      if (-not $count.ContainsKey($g)) { $count[$g] = 0; $example[$g] = $f[1] }
      $count[$g] = $count[$g] + 1
      $lines.Add($g + "`t" + $f[1])
    }
  }
  if (-not $AsNote) { return ($lines -join "`n") }
  if ($lines.Count -eq 0) { return '' }
  $note = New-Object 'System.Collections.Generic.List[string]'
  $note.Add('A house-style lint flagged the previous reply:')
  foreach ($g in $ORDER) {
    if ($count.ContainsKey($g)) {
      # the -f arguments need their own parentheses: inside a method call, a bare
      # comma list is read as further arguments to Add
      $note.Add(('- {0} x{1}, e.g. "{2}". Rule: {3}.' -f $g, $count[$g], $example[$g], $RULE[$g]))
    }
  }
  $note.Add('Apply these rules in the reply you are about to write, including in markdown headings. Do not re-send the previous reply and do not correct it; there is no need to mention this note unless the user asks about it. Leave a literal sense (a Slack channel, an array shape, a timetable slot) alone.')
  return ($note -join "`n")
}

# --- hook plumbing --------------------------------------------------------
# stdin and stdout are read and written as UTF-8 explicitly: 5.1 otherwise
# decodes both through the console codepage and mangles every em dash.
function Write-Utf8([string]$s) {
  if ($s -eq '') { return }
  $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($s)
  $stdout = [Console]::OpenStandardOutput()
  $stdout.Write($bytes, 0, $bytes.Length)
  $stdout.Flush()
}

function Read-Utf8Stdin {
  $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

# Only lint-test.ps1 dot-sources this file, and it sets this first so the hook
# plumbing below does not run and consume the test's own stdin.
if ($LintPs1LoadOnly) { return }

try {
  $mode = if ($args.Count -ge 1) { [string]$args[0] } else { '--record' }
  $raw = Read-Utf8Stdin
  $json = $null
  if ($raw.Trim() -ne '') { try { $json = ConvertFrom-Json $raw } catch { $json = $null } }

  function Get-Field($obj, [string]$name) {
    if ($null -eq $obj) { return '' }
    $prop = $obj.PSObject.Properties[$name]
    if ($null -eq $prop -or $null -eq $prop.Value) { return '' }
    return [string]$prop.Value
  }

  # With no session id there is no safe place to keep a note: a shared fallback
  # file would hand one session's note to another.
  $sid = [regex]::Replace((Get-Field $json 'session_id'), '[^A-Za-z0-9_-]', '_')
  $tmp = if ($env:TMPDIR) { $env:TMPDIR } else { [IO.Path]::GetTempPath() }
  $state = Join-Path $tmp "claude-reply-lint-$sid.txt"
  $utf8 = New-Object System.Text.UTF8Encoding($false)

  switch ($mode) {
    '--record' {
      # Managed policy settings still apply under `--safe-mode`, so a copy of this
      # hook registered that way runs inside the gate's nested call. That call sets
      # this marker on its child, and a reply written for the gate is not linted.
      if ($env:WRITING_CONVENTIONS_NESTED) { break }
      # Remove-CodeSpans drops every closed fence, so a draft moved into a
      # `draft` fence would lose the one check that is left when the model
      # reader cannot run. Get-DraftFence takes the fence lines of a draft block
      # off first and leaves its text in place, and the whole reply makes the one
      # pass it always made.
      $reply = (Get-DraftFence (Get-Field $json 'last_assistant_message')).Unwrapped
      $note = Invoke-Lint $reply -AsNote
      if ($sid -ne '') {
        if ($note -ne '') { [IO.File]::WriteAllText($state, $note + "`n", $utf8) }
        elseif (Test-Path -LiteralPath $state) { Remove-Item -LiteralPath $state -Force }
      }
    }
    '--emit' {
      if ($sid -ne '' -and (Test-Path -LiteralPath $state) -and (Get-Item -LiteralPath $state).Length -gt 0) {
        Write-Utf8 ([IO.File]::ReadAllText($state, $utf8))
        Remove-Item -LiteralPath $state -Force
      }
      Write-Utf8 ($REMINDER + "`n")
    }
    '--nudge' {
      $path = Get-Field $json 'file_path'
      if ($path -eq '' -and $null -ne $json) { $path = Get-Field $json.tool_input 'file_path' }
      if ([regex]::IsMatch($path.ToLowerInvariant(), '\.(md|markdown|txt|kt|kts|java|groovy)$')) {
        Write-Utf8 ('{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"' + $NUDGE + '"}}')
      }
    }
  }
} catch {
  # A hook that cannot lint must not end the turn.
}
exit 0
