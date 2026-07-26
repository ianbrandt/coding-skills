---
name: upgrade-dependencies
description: Check for and upgrade Gradle version-catalog dependencies and settings.gradle plugins one at a time, verifying each.
paths: "**/libs.versions.toml,**/settings.gradle.kts,**/settings.gradle"
---

# Upgrade Dependencies

Check for, upgrade, and verify Gradle dependencies one at a time. No prerequisites.

Primary check: **direct metadata lookup** against every declared entry in every version catalog, plus
every **settings plugin** (the `plugins { }` block of `settings.gradle(.kts)`). Both kinds flow
through the same one-at-a-time workflow. Where applied, the Gradle Versions Plugin's
`dependencyUpdates` is **optional enrichment**, and `buildHealth` enriches verification.

**Honest ceiling:** the lookup checks declared catalog versions, not the resolved graph. It misses
transitive-only and non-catalog build-script dependencies, and you own BOM / `version.ref` /
repository-selection reasoning yourself.

## Composite and included builds

Each directory with its own `settings.gradle(.kts)` is a build, each possibly with its own catalog,
repositories, and plugins. `dependencyUpdates` does not traverse included builds, reports only where
the plugin is applied, and never reports settings plugins.

"Enumerate the builds" means:

```
find . \( -name 'settings.gradle.kts' -o -name 'settings.gradle' \) \
  -not -path '*/build/*' -not -path '*/.claude/worktrees/*'
find . -name 'libs.versions.toml' \
  -not -path '*/build/*' -not -path '*/.claude/worktrees/*'
```

Enumerate catalogs by **file**: a shared catalog is checked and edited once, not once per consuming
build.

## Sub-agent delegation

Delegate **discovery** (step 2) and **verification** (steps 5 and 6), one single-shot general-purpose
sub-agent per job, each returning only that step's summary contract. A sub-agent **must not** edit
files, run `git`, fix failures, or move on to another dependency; on failure it returns enough to act
on, never a bare "FAIL". Prioritization, edits, commits, and reporting stay in the main thread. Relay
what comes back.

## Workflow

### 1. Set the run options

1. **Verification tasks**—run after each change (step 5) and once at the end (step 6). Single-build
   default: `build buildHealth` (drop `buildHealth` if that plugin is absent). Lifecycle tasks do not
   fan out across included builds: address an included build's task by full path (`:included:task`),
   and include any aggregator task reaching builds the root lifecycle does not—e.g.
   `build :modules:buildHealth examplesCheck`. When the right set is not obvious, propose one from the
   enumeration and confirm it with the maintainer. Step 6 may use a heavier set (`clean build
   buildHealth`).

2. **Push**—the only opt-in, default off. Push only after every round and the final verification pass,
   and only if the maintainer opted in.

**Commits are automatic.** Iterate through every update without stopping for approval, committing each
verified round as its own atomic commit (step 4) in the repo's commit-message convention (derive it
from recent `git log`). Never fold multiple dependencies into one commit; batch only what must move
together (step 4).

One dependency update plus its verification is one **round**.

### 2. Check for updates

Delegate the whole step. The sub-agent enumerates the builds, runs the lookups below, and returns only
a compact update list—nothing else, and says so explicitly if it finds none:

- **Catalog dependencies & plugins:** `group:artifact  current → available  (catalog file · alias)`,
  or for `[plugins]` entries `plugin-id  current → available  (catalog file · alias)`.
- **Settings plugins:** `plugin-id  current → latest-stable  (declaring file(s))`. Same id+version in
  several files is one update—one line.
- **Gradle Versions Plugin self-update:** flagged separately; step 3 acts on it first.
- **Enrichment (where available):** extra updates `dependencyUpdates` surfaces that the catalog check
  did not (transitive / build-script deps), plus any newer-Gradle line.

#### Primary: catalog-direct metadata lookup

For each `libs.versions.toml`, check every declared entry:

1. Parse `[versions]`, `[libraries]`, `[plugins]`. Each `[libraries]` entry resolves to a
   `group:artifact`; each `[plugins]` entry to a plugin `id`; a `[versions]` entry is reached through
   the `version.ref` pointing at it—resolve it via the referencing coordinate.
2. Determine that build's declared repositories: `dependencyResolutionManagement { repositories }`
   for libraries, `pluginManagement { repositories }` for plugins. Default to Maven Central
   (`https://repo1.maven.org/maven2/`) and the Plugin Portal (`https://plugins.gradle.org/m2/`).
3. Fetch `maven-metadata.xml` (e.g. `curl -s`) from those repositories:
   - **Library** → `<repo>/<group-with-dots-as-slashes>/<artifact>/maven-metadata.xml`
   - **Plugin** → `<repo>/<id-with-dots-as-slashes>/<id>.gradle.plugin/maven-metadata.xml`
4. Choose the highest **stable** version by semantic-version ordering, not string ordering (`3.18` is
   newer than `3.9`). Ignore pre-releases (`-rc`, `-alpha`, `-beta`, `-M`, `-SNAPSHOT`, …) unless the
   current version is itself a pre-release. Report any entry whose latest stable is newer than
   declared.

#### Settings plugins (not in any catalog)

Same lookup:

1. From the enumerated settings files, read each `plugins { }` block (often absent): record `id`,
   current version, declaring file(s), and whether the version is inline or a catalog reference.
2. Resolve each `id` via its marker artifact (step 3 above), defaulting to the Plugin Portal, falling
   back to that file's `pluginManagement { repositories }`.
3. The same id+version repeated across many settings files is **one** update, applied across all of
   them in a single round.

#### Optional enrichment: dependencyUpdates

Run once per build that applies it, addressing an included build by full path:

```
./gradlew dependencyUpdates --no-parallel              # the build the wrapper runs in
./gradlew :modules:dependencyUpdates --no-parallel     # an included build applying the plugin
```

On a "dependencies exceed the version found at the milestone revision level" section, re-run that
build's task with `--refresh-dependencies`. Never use it on the initial run.

Fold all updates—catalog entries, settings plugins, enrichment-only items—into the workflow below.

### 3. Self-update the Gradle Versions Plugin first

If `com.github.ben-manes.versions` itself has an update, upgrade only that plugin before anything
else: run it as a normal round (step 4), then re-run step 2 and continue from the refreshed report.

### 4. Update one dependency at a time

One dependency per round, one commit per round. Settings plugins count as single dependencies.

**Prioritize by compatibility relationships:**
1. Build toolchain plugins (compiler plugins, annotation processors, code generators)—update and test
   with the CURRENT language/platform version BEFORE upgrading the language/platform itself
2. BOM/platform dependencies before their constituent libraries
3. Core libraries before their dependents
4. Independent libraries last

Slot each settings plugin in by what it affects (e.g. a toolchain resolver alongside other toolchain
updates).

**Each round:**
1. Update only its version—in the `libs.versions.toml` that **declares** it (never another build's
   catalog), or in the `settings.gradle(.kts)` `plugins { }` block for an inline-versioned settings
   plugin. When the same settings-plugin id+version repeats across files, update **all** of them in
   this one round.
2. Identify affected modules: for catalog entries, search for usages of the alias; for a settings
   plugin, note the declaring file(s)
3. Run verification (step 5)
4. If it passed, commit this single dependency and continue straight to the next round without
   pausing. If it failed, **stop and report; do not commit, do not push, do not touch another
   dependency.**

**Watch for:** compiler/toolchain API changes; breaking changes in build plugins or test frameworks;
behavioral changes affecting existing code; new deprecations or required source changes;
settings-plugin major bumps (review release notes for renamed DSL extensions or a raised minimum
Gradle version).

**Batching:** only when dependencies *must* move together (a library and its required companion
version). Explain why; still one round, one commit.

### 5. Verification

After each version change, in a sub-agent:

```
./gradlew <per-round tasks>
```

Single-build default `./gradlew build buildHealth`; composite, the step-1 set, e.g.
`./gradlew build :modules:buildHealth examplesCheck`.

`--rerun-tasks` is your judgement, default off: reach for it only when you distrust the incremental
result—a toolchain / compiler-plugin or code-generator upgrade, signs of stale caching (a task
reported `UP-TO-DATE` that the change should have touched, or an "exceed the milestone" warning), or
a deliberate from-scratch check.

The sub-agent returns only:

- **Success:** `PASS`, with the `BUILD SUCCESSFUL` marker and—when `buildHealth` ran—its "no issues"
  confirmation.
- **Failure:** `FAIL`, which task failed, and the actionable error block (compiler errors with
  `file:line`, failed test names with the assertion, or the `buildHealth` advice), trimmed to what
  the main thread needs to decide fix-vs-revert. No fix attempt, no other dependency touched.

Verification must pass before a round is committed.

### 6. Final verification, then push

After every round has passed and been committed, run `./gradlew <final tasks>` once in a sub-agent
with the step-5 return contract. May use the heavier step-1 set; a from-scratch check is often worth
`--rerun-tasks` even when the per-round builds ran without it.

- If it fails, **stop and report; do not push.**
- If it passes and push was enabled in step 1, `git push`. If push is off, the run ends here with
  every verified upgrade committed for the maintainer.

### 7. Reporting

- What changed and why
- Verification results, per-round and final
- What was committed and whether the branch was pushed; if push was off, note the commits are left
  for the maintainer
- If a round or the final verification failed, exactly where the run stopped and what was and was not
  committed or pushed
- Follow-up ideas kept separate from completed work

## Constraints

- **Version catalog:** Do not rename aliases, bundles, or plugin aliases unless asked. Maintain
  existing formatting and style.
- **Settings plugins:** Upgrade inline versions in place; do not migrate them into the catalog unless
  asked.
- **Scope:** Keep diffs focused and minimal. No unrelated refactors, no unrelated version changes, no
  new dependencies without clear justification.
- **Git:** Do not create branches unless explicitly instructed. (Commit and push rules: steps 1, 4,
  5, 6.)
