# land-and-wrap, in PowerShell

PowerShell 7 equivalents for the §1 bash in `SKILL.md`, and for the PR draft file in its §2 `pr`
step 6. The rest of §2 through §4 is single git, `gh`, or `glab` commands with no shell-specific
parsing around them, so their bash form runs unchanged.

`gh` and `glab` are optional everywhere here, guarded with `Get-Command ... -ErrorAction
SilentlyContinue` rather than `2>$null`: a missing executable is a lookup error PowerShell reports
on the console even under `2>$null`, and the guard avoids it. Where neither is installed, as on a
machine with no `gh`, every block in §1 falls through to `unknown`, and `SKILL.md`'s "ask the user
once" step runs the same as on the bash side.

## 1. What decides how work lands

```powershell
git remote get-url upstream *> $null
if ($LASTEXITCODE -eq 0) { 'fork' }              # someone else's project
$Url = git remote get-url origin
function Get-Vis($s) {
  if (-not $s) { return $null }
  $v = $s.Trim().ToLower()
  if ($v -match '^(public|private|internal)$') { return $v }   # drops CLI error text
  return $null
}
$Vis = Get-Vis (git config --get session-skills.originVisibility 2>$null)   # set once per clone
if (-not $Vis -and (Get-Command gh -ErrorAction SilentlyContinue)) {
  $Vis = Get-Vis (gh repo view $Url --json visibility -q .visibility 2>$null)
}
if (-not $Vis -and (Get-Command glab -ErrorAction SilentlyContinue)) {
  $Vis = Get-Vis (glab repo view $Url -F json --jq .visibility 2>$null)
}
"origin: $(if ($Vis) { $Vis } else { 'unknown' })"
```

With no answer from any of the three, ask the user once and record the reply:

```powershell
git config session-skills.originVisibility private     # or public
```

### The landing mode

```powershell
$Url = git remote get-url origin
$Default = (git symbolic-ref --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
if (-not $Default) { $Default = 'main' }
$Mode = git config --get session-skills.landing 2>$null
if ($Mode -cnotmatch '^(merge|pr)$') { $Mode = $null }
$Prot = $null
if (-not $Mode -and (Get-Command gh -ErrorAction SilentlyContinue)) {
  $Repo = gh repo view $Url --json nameWithOwner -q .nameWithOwner 2>$null
  if ($LASTEXITCODE -eq 0 -and $Repo) {
    $Prot = gh api "repos/$Repo/branches/$Default" --jq .protected 2>$null
    $Rules = gh api "repos/$Repo/rules/branches/$Default" --jq '.[].type' 2>$null
    if ($Rules -contains 'pull_request') { $Prot = 'true' }
  }
}
switch ($Prot) { 'true' { $Mode = 'pr' } 'false' { $Mode = 'merge' } }
"landing: $(if ($Mode) { $Mode } else { 'unknown' })"
```

With no answer from any of these, ask the user once and record the reply:

```powershell
git config session-skills.landing pr        # or merge
```

### Holds, and lifting them

```powershell
git config session-skills.holdPublicPush false    # a public origin pushes like a private one
git config session-skills.holdFork false          # a fork lands as a PR against upstream (§3)
git config session-skills.holdPrText false        # open a PR without first showing its text
```

## 2. Landing in a repo you own

### `pr`, step 6: where the repo has no notes directory

```powershell
$F = "$Main/.claude/pr-drafts/<id>-pr-draft.md"   # the work's backlog ID, or the branch name
New-Item -ItemType Directory -Force (Split-Path $F) | Out-Null
git -C $Main check-ignore -q $F
if ($LASTEXITCODE -ne 0) { Add-Content "$Main/.git/info/exclude" "`n/.claude/pr-drafts/" }
```
