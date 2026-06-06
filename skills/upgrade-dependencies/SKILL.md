---
name: upgrade-dependencies
description: Check for and upgrade Gradle version-catalog dependencies and settings.gradle plugins one at a time, with build validation after each change.
paths: "**/libs.versions.toml,**/settings.gradle.kts,**/settings.gradle"
---

# Upgrade Dependencies

Check for, upgrade, and validate Gradle dependencies one at a time.

This also covers **settings plugins** — plugins applied in the `plugins { }` block of `settings.gradle(.kts)` — which the Gradle Versions Plugin does not report. They are found with a supplementary metadata lookup, then flow through the same one-at-a-time upgrade workflow.

## Prerequisites

The target project must apply these Gradle plugins:

- [gradle-versions-plugin](https://github.com/ben-manes/gradle-versions-plugin) — provides the `dependencyUpdates` task
- [dependency-analysis-gradle-plugin](https://github.com/autonomousapps/dependency-analysis-gradle-plugin) (optional) — provides the `buildHealth` task

The settings-plugin check requires no plugin — it queries published plugin metadata directly.

## Workflow

### 1. Check for updates

#### Catalog and build-script dependencies

```
./gradlew dependencyUpdates --no-parallel
```

If the output contains a "dependencies exceed the version found at the milestone revision level" section, the metadata cache may be stale. Re-run with `--refresh-dependencies`:

```
./gradlew dependencyUpdates --no-parallel --refresh-dependencies
```

Do not use `--refresh-dependencies` on the initial run — it forces re-download of all metadata.

#### Settings plugins (not reported by `dependencyUpdates`)

The `dependencyUpdates` task does not inspect plugins applied in the `plugins { }` block of `settings.gradle(.kts)` (e.g. `com.gradle.develocity`, `org.gradle.toolchains.foojay-resolver-convention`). Check these separately:

1. Find every `settings.gradle.kts` / `settings.gradle` in the build — the root plus any build pulled in with `includeBuild(...)` — and read each `plugins { }` block. For each plugin, record its `id`, current version, the file it is declared in, and whether the version is inline (`version "x"`) or a version-catalog reference. A `plugins { }` block may be absent; many settings files only configure `pluginManagement`/`dependencyResolutionManagement`.
2. For each plugin `id`, fetch the plugin marker metadata from the Gradle Plugin Portal (e.g. with `curl -s`):

   ```
   https://plugins.gradle.org/m2/<id-with-dots-as-slashes>/<id>.gradle.plugin/maven-metadata.xml
   ```

   For example, `org.gradle.toolchains.foojay-resolver-convention` maps to:

   ```
   https://plugins.gradle.org/m2/org/gradle/toolchains/foojay-resolver-convention/org.gradle.toolchains.foojay-resolver-convention.gradle.plugin/maven-metadata.xml
   ```

3. From the returned `<versions>` list, choose the highest **stable** version by semantic-version ordering (not string ordering — `3.18` is newer than `3.9`). Ignore pre-releases (`-rc`, `-alpha`, `-beta`, `-M`, `-SNAPSHOT`, and similar) unless the current version is itself a pre-release. Report any plugin whose latest stable version is newer than the one in use.
4. If a plugin `id` is not found on the Plugin Portal, look for the same `<id>.gradle.plugin` marker in the repositories declared in that file's `pluginManagement { repositories { ... } }` (for example Maven Central under `https://repo1.maven.org/maven2/...`).

Fold any settings-plugin updates into the prioritized, one-at-a-time workflow below — treat each as just another item to update.

### 2. Self-update the Gradle Versions Plugin first

If the report lists an update for the Gradle Versions Plugin itself (plugin id `com.github.ben-manes.versions`), upgrade only that plugin before any other dependency. Validate (step 4), then re-run step 1 with the new version. A newer plugin may surface different or more accurate updates, so subsequent prioritization should be based on the refreshed report.

Treat this as a normal single-dependency turn: update, validate, report, **stop** and wait for the maintainer before re-running the check.

### 3. Update one dependency at a time

Update each dependency individually so the maintainer can review and commit each change independently. Settings plugins are included here — treat each as a single dependency.

**Prioritize by compatibility relationships:**
1. Build toolchain plugins (compiler plugins, annotation processors, code generators) — update and test with the CURRENT language/platform version BEFORE upgrading the language/platform itself
2. BOM/platform dependencies before their constituent libraries
3. Core libraries before their dependents
4. Independent libraries last

Settings plugins are build infrastructure; slot each into this ordering by what it affects (e.g. a toolchain-resolver plugin alongside other build toolchain updates).

**For each dependency:**
1. Update only its version — in `libs.versions.toml` for catalog entries, or directly in the `settings.gradle(.kts)` `plugins { }` block for an inline-versioned settings plugin
2. Identify affected modules: for catalog entries, search the repository for usages of the catalog alias; for a settings plugin, note the settings file(s) that declare it
3. Run validation (step 4)
4. Report results to the maintainer
5. **STOP. Do not touch another dependency.** Your turn is over. Wait for the maintainer to explicitly say to continue before doing anything else.

> **Hard stop after each dependency — no exceptions.**
> - Do not queue up the next update.
> - Do not mention what you plan to do next.
> - Do not continue even if the user previously said "go ahead" or gave general approval.
> - Resume only when the maintainer sends a new message explicitly asking you to proceed.

**Watch for:**
- Compiler/toolchain API changes
- Breaking changes in build plugins or test frameworks
- Behavioral changes affecting existing code
- New deprecations or required source changes
- Settings-plugin major version bumps — review the plugin's release notes for renamed DSL extensions or a raised minimum Gradle version before upgrading

**Batching:** Only batch updates when dependencies *must* be updated together (e.g., a library and its required companion version). Prefer single-dependency changes. If batching, explain why.

### 4. Validation

After each version change, run:

```
./gradlew build
```

If the project applies the dependency-analysis-gradle-plugin, also run:

```
./gradlew buildHealth
```

Both must pass before reporting results.

**`--rerun-tasks` option:** Before the first `./gradlew build` in a session, check memory for a saved `--rerun-tasks` preference. If no preference is found, ask the maintainer:

> Would you like to run `./gradlew build` with `--rerun-tasks`? This forces all tasks to re-execute regardless of up-to-date checks.
> - **yes** — use `--rerun-tasks` this time
> - **no** — skip it this time
> - **always** — use it now and in future sessions (saves preference)
> - **never** — skip it now and in future sessions (saves preference)

If the maintainer answers "always" or "never", save that preference to memory for future invocations. This option applies only to `./gradlew build`, not to other Gradle tasks.

### 5. Reporting

- Summarize what changed and why
- Report validation results
- Separate follow-up ideas from completed work
- Do not create Git commits — leave changes for the maintainer to review

## Constraints

- **Version catalog:** Do not rename catalog aliases, bundles, or plugin aliases unless explicitly asked. Maintain existing formatting and style.
- **Settings plugins:** Settings `plugins { }` versions are normally inline because the version catalog is not available in that block. Upgrade them in place; do not migrate them into the catalog unless explicitly asked.
- **Scope:** Keep diffs focused and minimal. Do not perform unrelated refactors or change unrelated versions. Do not introduce new dependencies without clear justification.
- **Git:** Do not run `git commit`, `git push`, or create branches unless explicitly instructed.
