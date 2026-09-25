# work-in-worktree, in PowerShell

PowerShell 7 equivalents for the bash in `SKILL.md`, one block per section. Run `git` the same way
either shell does; only the surrounding parsing changes.

## 1. Locate the two checkouts

```powershell
$Main = (git worktree list --porcelain | Select-Object -First 1) -replace '^worktree ', ''
$Branch = git rev-parse --abbrev-ref HEAD
$Default = (git symbolic-ref --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
if (-not $Default) { $Default = 'main' }             # the repo's integration branch (main/master/…)

$Base = "origin/$Default"                            # branch from this, never from the local default
git fetch -q
if ($LASTEXITCODE -ne 0) { Write-Warning "fetch failed: $Base may be behind" }   # do not swallow this
git rev-parse --verify -q $Base *> $null
if ($LASTEXITCODE -ne 0) { $Base = $Default }         # no remote: local is all there is

$WtRoot = "$Main/.claude/worktrees"                   # where this host's tooling creates worktrees
$Pfx = 'claude/'                                      # and the branch prefix it uses
$Notes = 'spike-notes.local'                          # the repo's local-only notes directory, if any
```

## 2. Resume before you branch

```powershell
$Wt = "$WtRoot/<the matching worktree dir>"   # resume: work here
```

See `SKILL.md` §2 for when to use this and what to do next.

## 3. Open your own worktree, new lanes only

```powershell
function Test-BranchRef($ref) {
  git show-ref --verify --quiet $ref
  return $LASTEXITCODE -eq 0
}

if ($Branch -ceq $Default) {
  # Launched in the PRIMARY checkout, open your own worktree now; never edit under $Main.
  $Name = '<short-kebab-id>'                 # arbitrary pair (color-animal), NOT activity words like
                                              # "roadmap-lap": every session picks those, and siblings collide
  while ((Test-Path "$WtRoot/$Name") -or (Test-BranchRef "refs/heads/$Pfx$Name")) {
    $Name = "$Name-$(Get-Random)"            # taken by a sibling, suffix and retry
  }
  git worktree add --no-track "$WtRoot/$Name" -b "$Pfx$Name" $Base    # §1: current; no upstream
  $Wt = "$WtRoot/$Name"
  $Branch = "$Pfx$Name"                      # update, the capture above read the default branch
} else {
  $Wt = git rev-parse --show-toplevel        # YOUR worktree, edit/build only under here
}
# Durable notes belong in the primary checkout: a worktree's untracked files go with it on removal.
if (($Wt -ne $Main) -and (Test-Path "$Main/$Notes") -and (-not (Test-Path "$Wt/$Notes"))) {
  New-Item -ItemType ($IsWindows ? 'Junction' : 'SymbolicLink') -Path "$Wt/$Notes" -Target "$Main/$Notes" | Out-Null
}
"worktree: $Wt   main checkout: $Main"
```

## 4. Hygiene, prune only

```powershell
git worktree prune                            # safe: only reaps worktrees whose dir is already gone
git for-each-ref --merged $Default --format='%(refname:short)' `
  'refs/heads/claude/*' 'refs/heads/worktree-*' |
  ForEach-Object { git branch -d $_ }         # merged only; -d self-guards
                                               # claude/: the host's branch prefix, as $Pfx in §1
```

See `SKILL.md` §4 for what `--merged` misses and why this block only deletes a branch that would
change nothing if merged into `$Base` now:

```powershell
git fetch -q --prune                          # drops remote-tracking refs the host deleted
$Default = (git symbolic-ref --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
$Base = "origin/$(if ($Default) { $Default } else { 'main' })"
$T = git rev-parse -q --verify "$Base^{tree}"
if ($LASTEXITCODE -eq 0) {
  $gone = git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads |
    Where-Object { $_ -match '\[gone\]$' } | ForEach-Object { ($_ -split ' ')[0] }
  foreach ($b in $gone) {
    $mt = git merge-tree --write-tree $Base $b 2>$null   # git 2.38+
    if ($mt -ne $T) {
      "kept: $b (upstream gone, content not on $Base)"
    } elseif ((git worktree list --porcelain) -ccontains "branch refs/heads/$b") {
      "merged, still checked out: $b"
    } else {
      git branch -D $b
    }
  }
}
```

See `SKILL.md` §4 for what each printed line means.

Before removing your own worktree, list its untracked files as `SKILL.md` §4 describes:

```powershell
git -C $Wt status --porcelain -uall |
  Where-Object { $_ -match '^\?\? ' } |
  Where-Object { $_ -notmatch '(^\?\? |/)(build|\.gradle|\.kotlin)/' }
```
