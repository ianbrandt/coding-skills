---
name: upgrade-dependencies
description: Check for and upgrade Gradle version-catalog dependencies and settings.gradle plugins one at a time, verifying and committing each verified upgrade atomically, and optionally pushing once all upgrades pass.
paths: "**/libs.versions.toml,**/settings.gradle.kts,**/settings.gradle"
---

# Upgrade Dependencies

Check for, upgrade, and verify Gradle dependencies one at a time.

The primary update check is a **direct metadata lookup** against each version catalog's declared entries — the same query the settings-plugin check below uses, generalized to every `libs.versions.toml` entry. This requires no plugin and works on **composite builds** (mono-repos using `includeBuild`), where the Gradle Versions Plugin alone is not enough (see [Composite and included builds](#composite-and-included-builds)). The Versions Plugin's `dependencyUpdates` report is used as **optional enrichment** where the plugin is applied.

This also covers **settings plugins** — plugins applied in the `plugins { }` block of `settings.gradle(.kts)` — which the Gradle Versions Plugin does not report. They are found with the same metadata lookup, then flow through the same one-at-a-time upgrade workflow.

## Prerequisites

None required. The catalog and settings-plugin checks query published metadata directly and need no plugin applied.

Two plugins, if present, enrich the run:

- [gradle-versions-plugin](https://github.com/ben-manes/gradle-versions-plugin) (optional) — provides the `dependencyUpdates` task, which also surfaces transitive and build-script dependencies and a newer-Gradle line. Used as enrichment, not as the primary engine.
- [dependency-analysis-gradle-plugin](https://github.com/autonomousapps/dependency-analysis-gradle-plugin) (optional) — provides the `buildHealth` task for verification.

## Composite and included builds

A project may be more than one Gradle build: a root build plus other builds pulled in with `includeBuild(...)`, possibly transitively. The practical rule for enumeration: **each directory with its own `settings.gradle(.kts)` is a build.** Each build may have its own version catalog, its own declared repositories, and its own applied plugins.

This matters because the Gradle Versions Plugin's `dependencyUpdates` task **does not traverse included builds** — it reports only the build it runs in (plus that build's subprojects), and only if the plugin is applied there. The plugin is often applied in just one build, or none. And a catalog shared by several builds is a *menu* consumed piecemeal: no single build's `dependencyUpdates` ever sees the whole catalog. So `dependencyUpdates` alone systematically under-reports a composite build.

The direct metadata lookup avoids this: it checks the **declared catalog entries** themselves, build by build, regardless of which build (if any) applies the Versions Plugin.

**Honest ceiling:** metadata lookup checks declared catalog versions, not the fully resolved dependency graph. It will miss transitive-only dependencies and non-catalog build-script dependencies, and you own BOM / `version.ref` / repository-selection reasoning yourself. That is an acceptable trade for a catalog-centric repo; where the Versions Plugin is applied, its `dependencyUpdates` stays the richer check and runs as enrichment.

Throughout this skill, "enumerate the builds" means: find every `settings.gradle(.kts)` and every `libs.versions.toml`, **excluding** generated and throwaway trees:

```
find . \( -name 'settings.gradle.kts' -o -name 'settings.gradle' \) \
  -not -path '*/build/*' -not -path '*/.claude/worktrees/*'
find . -name 'libs.versions.toml' \
  -not -path '*/build/*' -not -path '*/.claude/worktrees/*'
```

Enumerating catalogs by **file** de-dupes naturally: a catalog shared by several builds appears once, so it is checked and edited once, not once per consuming build.

## Delegating verbose work to sub-agents

The discovery output — the per-entry catalog and settings-plugin metadata fetches (one `maven-metadata.xml` per coordinate, across every build's catalog), the optional `dependencyUpdates` report — and especially each verification build is large and mostly noise. Run those steps in **sub-agents** (the general-purpose type, which has the Bash access these commands need) so the raw output stays in the sub-agent's context and only a short summary returns to the main thread. Over a multi-round run, this is where most of the token (plan) usage would otherwise accumulate.

Two jobs are delegated: **discovery** (step 2) and **verification** (steps 5 and 6). For both:

- Spawn one single-shot sub-agent per job — it runs the given command(s) and returns only the summary contract stated in that step.
- The sub-agent **must not** edit files, run `git`, fix failures, or proceed to another dependency. On a failure it returns enough to act on (see the verification contract) — never a bare "FAIL".

Everything else stays in the main thread: prioritization, the version edits (so each diff stays reviewable), commits, and reporting. Relay what a sub-agent returns — a passing build needs only a one-line confirmation; surface a failure's error block.

## Workflow

### 1. Set the run options

Two things govern the run:

1. **Verification tasks** — the Gradle tasks to run after each dependency change (step 5) and once at the end (step 6). Default for a single build: `build buildHealth` (drop `buildHealth` if the dependency-analysis plugin is not applied). For a **composite build**, express this per build: a flat `build buildHealth` covers only the build the wrapper runs in, so name each build's task explicitly, e.g. `build :modules:buildHealth examplesCheck`.

   **Composite-aware verification.** In a composite build, lifecycle tasks do not fan out across included builds, and a task like `buildHealth` may exist in only one build. Derive the task set from the build structure: address an included build's task with a fully-qualified path (`:included:task`), and include any aggregator task that exercises builds the root lifecycle does not reach (for example, an `examplesCheck` that builds a set of standalone example builds). When the right set is not obvious, propose one from the enumeration and confirm it with the maintainer. The final verification (step 6) may use a heavier set, e.g. a clean cumulative run such as `clean build buildHealth`.

2. **Push** — the one outward-facing action, and the only opt-in. Default off: leave the verified atomic commits for the maintainer to push. Push automatically once every round and the final verification have passed **only** if the maintainer opts in.

**Commits are automatic.** Iterate through every available update without stopping for approval, committing each verified round as its own atomic commit (step 4) in the repo's existing commit-message convention (derive it from recent `git log`). Never fold multiple dependencies into one commit; batch only dependencies that must move together (step 4).

Each single dependency update plus its verification is one **round**.

### 2. Check for updates

Delegate this whole step to a sub-agent. It enumerates the builds, runs the lookups below, and returns only a compact update list:

- **Catalog dependencies & plugins:** one line each as `group:artifact  current → available  (catalog file · alias)`, or for catalog `[plugins]` entries `plugin-id  current → available  (catalog file · alias)`.
- **Settings plugins:** one line each as `plugin-id  current → latest-stable  (declaring file(s))`. When the same id+version is declared in several files, list them on one line — it is a single update.
- **Gradle Versions Plugin self-update:** flag separately whether `com.github.ben-manes.versions` itself has an update, since step 3 acts on it before anything else.
- **Enrichment (where available):** any extra updates `dependencyUpdates` surfaces that the catalog check did not (transitive / build-script deps), plus any newer-Gradle line.

The sub-agent returns nothing else — the raw metadata XML and any `dependencyUpdates` report stay in its context — and says so explicitly if it finds no updates. The main thread then prioritizes and drives the one-at-a-time workflow from this list.

#### Primary: catalog-direct metadata lookup

This is the main engine and the only one that fully covers a composite build. Enumerate the builds (see [Composite and included builds](#composite-and-included-builds)) and, for each `libs.versions.toml`, check every declared entry:

1. Parse the catalog's `[versions]`, `[libraries]`, and `[plugins]` tables. Each `[libraries]` entry resolves to a `group:artifact` coordinate; each `[plugins]` entry to a plugin `id`. A `[versions]` entry is reached through the `version.ref` a library or plugin points at — resolve it via the referencing coordinate.
2. Determine that build's declared repositories: read its settings file's `dependencyResolutionManagement { repositories { ... } }` for libraries and `pluginManagement { repositories { ... } }` for plugins. Default to Maven Central (`https://repo1.maven.org/maven2/`) and the Gradle Plugin Portal (`https://plugins.gradle.org/m2/`) when not overridden.
3. For each coordinate, fetch `maven-metadata.xml` (e.g. with `curl -s`) from the declared repositories:
   - **Library** `group:artifact` → `<repo>/<group-with-dots-as-slashes>/<artifact>/maven-metadata.xml`
   - **Plugin** `id` → the marker artifact `<repo>/<id-with-dots-as-slashes>/<id>.gradle.plugin/maven-metadata.xml`
4. From the returned `<versions>` list, choose the highest **stable** version by semantic-version ordering (not string ordering — `3.18` is newer than `3.9`). Ignore pre-releases (`-rc`, `-alpha`, `-beta`, `-M`, `-SNAPSHOT`, and similar) unless the current version is itself a pre-release. Report any entry whose latest stable version is newer than the one declared.

Check each catalog **file** once, even when several builds share it.

#### Settings plugins (not in any catalog)

Settings plugins applied in the `plugins { }` block of `settings.gradle(.kts)` (e.g. `com.gradle.develocity`, `org.gradle.toolchains.foojay-resolver-convention`) are not catalog entries and are not reported by `dependencyUpdates`. They use the **same metadata lookup** as above:

1. From the enumerated settings files, read each `plugins { }` block. For each plugin, record its `id`, current version, the file(s) it is declared in, and whether the version is inline (`version "x"`) or a version-catalog reference. A `plugins { }` block may be absent; many settings files only configure `pluginManagement`/`dependencyResolutionManagement`.
2. Resolve each plugin `id` via its marker artifact (step 3 above), defaulting to the Plugin Portal and falling back to that file's `pluginManagement { repositories { ... } }` if the id is not on the Portal. For example, `org.gradle.toolchains.foojay-resolver-convention` maps to:

   ```
   https://plugins.gradle.org/m2/org/gradle/toolchains/foojay-resolver-convention/org.gradle.toolchains.foojay-resolver-convention.gradle.plugin/maven-metadata.xml
   ```

3. The **same id+version is often repeated across many settings files** in a composite build (e.g. a foojay-resolver literal in every settings file). That is **one** update, applied across all those files in a single round — not one round per file.

#### Optional enrichment: dependencyUpdates (where the Versions Plugin is applied)

Where a build applies the Gradle Versions Plugin, run its report to catch what the catalog check cannot see — transitive and build-script dependencies, and a newer-Gradle line. It does **not** traverse included builds, so run it once per build that applies it, addressing an included build with a fully-qualified path:

```
./gradlew dependencyUpdates --no-parallel              # the build the wrapper runs in, if it applies the plugin
./gradlew :modules:dependencyUpdates --no-parallel     # an included build that applies the plugin
```

If the output contains a "dependencies exceed the version found at the milestone revision level" section, the metadata cache may be stale. Re-run that build's task with `--refresh-dependencies`. Do not use `--refresh-dependencies` on the initial run — it forces re-download of all metadata.

Fold all updates — catalog entries, settings plugins, and any enrichment-only items — into the prioritized, one-at-a-time workflow below.

### 3. Self-update the Gradle Versions Plugin first

If the report lists an update for the Gradle Versions Plugin itself (plugin id `com.github.ben-manes.versions`), upgrade only that plugin before any other dependency. A newer plugin may surface different or more accurate updates, so subsequent prioritization should be based on the refreshed report.

Run it as a normal round (step 4): update its version, verify (step 5), and commit. Then re-run step 2 with the upgraded plugin and continue from the refreshed report.

### 4. Update one dependency at a time

Update each dependency individually so each upgrade is independently reviewable and revertable — one dependency per round, one commit per round. Settings plugins are included here — treat each as a single dependency.

**Prioritize by compatibility relationships:**
1. Build toolchain plugins (compiler plugins, annotation processors, code generators) — update and test with the CURRENT language/platform version BEFORE upgrading the language/platform itself
2. BOM/platform dependencies before their constituent libraries
3. Core libraries before their dependents
4. Independent libraries last

Settings plugins are build infrastructure; slot each into this ordering by what it affects (e.g. a toolchain-resolver plugin alongside other build toolchain updates).

**For each round:**
1. Update only its version — in the `libs.versions.toml` that **declares** it (in a composite build, route the edit to the right catalog file; do not edit a different build's catalog), or directly in the `settings.gradle(.kts)` `plugins { }` block for an inline-versioned settings plugin. When the same settings-plugin id+version is repeated across several files, update **all** of them in this one round — it is a single logical change.
2. Identify affected modules: for catalog entries, search the repository for usages of the catalog alias; for a settings plugin, note the settings file(s) that declare it
3. Run verification (step 5)
4. If verification passed, commit this single dependency — matching the repo's commit-message convention — and continue straight to the next round without pausing for approval. If verification failed, **stop and report; do not commit, do not push, do not touch another dependency** — leave it for the maintainer to resolve before the run continues.

**Watch for:**
- Compiler/toolchain API changes
- Breaking changes in build plugins or test frameworks
- Behavioral changes affecting existing code
- New deprecations or required source changes
- Settings-plugin major version bumps — review the plugin's release notes for renamed DSL extensions or a raised minimum Gradle version before upgrading

**Batching:** Only batch updates when dependencies *must* be updated together (e.g., a library and its required companion version). Prefer single-dependency changes. If batching, explain why — the batch is still a single round and a single commit.

### 5. Verification

After each version change, run the per-round verification tasks — in a sub-agent (see **Delegating verbose work to sub-agents** above):

```
./gradlew <per-round tasks>
```

With the single-build defaults, that is `./gradlew build buildHealth`. For a composite build, use the per-build task set chosen in step 1, with fully-qualified paths for included builds and any aggregator task, e.g. `./gradlew build :modules:buildHealth examplesCheck`.

**`--rerun-tasks` — your judgement.** A catalog version bump is a changed task input, so Gradle's up-to-date checks normally re-run the affected tasks and a plain build verifies the change. Reach for `--rerun-tasks` (which forces every task to re-execute, ignoring up-to-date checks and the build cache) only when you have reason to distrust the incremental result — a toolchain / compiler-plugin or code-generator upgrade, signs of stale caching (a task reported `UP-TO-DATE` that the change should have touched, or a `dependencyUpdates` "exceed the milestone" warning), or when you deliberately want a from-scratch check. Default to leaving it off.

The verification sub-agent returns only:

- **On success:** `PASS`, with the `BUILD SUCCESSFUL` marker and — when `buildHealth` ran — its "no issues" confirmation.
- **On failure:** `FAIL`, which task failed, and the actionable error block (compiler errors with `file:line`, failed test names with the assertion, or the `buildHealth` advice), trimmed to what the main thread needs to decide fix-vs-revert. The sub-agent does not attempt a fix and does not touch any other dependency.

Verification must pass before a round is committed.

### 6. Final verification, then push

After every round has passed and been committed, run a single final verification, in a sub-agent with the same return contract as step 5:

```
./gradlew <final tasks>
```

This is a distinct step from per-round verification and may use the heavier task set chosen in step 1 (e.g. a clean cumulative run). A from-scratch final check is often worth `--rerun-tasks` even when the per-round builds ran without it — same judgement as step 5.

- If final verification fails, **stop and report; do not push.**
- If it passes and push was enabled in step 1, push with `git push`.

Push only after this final-verification step passes, and only if the maintainer opted in. If push is off, the run ends here with every verified upgrade already committed for the maintainer to push.

### 7. Reporting

- Summarize what changed and why
- Report verification results — both per-round and final
- State what was committed and whether the branch was pushed; if push was off, note that the verified commits are left for the maintainer to push
- If a round or the final verification failed, say exactly where the run stopped and what was and was not committed or pushed
- Separate follow-up ideas from completed work

## Constraints

- **Version catalog:** Do not rename catalog aliases, bundles, or plugin aliases unless explicitly asked. Maintain existing formatting and style.
- **Settings plugins:** Settings `plugins { }` versions are normally inline because the version catalog is not available in that block. Upgrade them in place; do not migrate them into the catalog unless explicitly asked.
- **Scope:** Keep diffs focused and minimal. Do not perform unrelated refactors or change unrelated versions. Do not introduce new dependencies without clear justification.
- **Git:** Commit each verified dependency as its own atomic commit in the repo's existing commit-message convention — never fold multiple dependencies into one commit, and commit a round only after its verification passes. Push only when the maintainer opts in through the run options (step 1), and only after the final verification passes. Do not create branches unless explicitly instructed.
