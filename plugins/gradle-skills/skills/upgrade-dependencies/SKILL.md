---
name: upgrade-dependencies
description: Check for and upgrade Gradle dependencies and settings.gradle plugins one at a time, verifying each.
paths: "**/libs.versions.toml,**/settings.gradle.kts,**/settings.gradle"
---

# Upgrade Dependencies

Check for, upgrade, and verify Gradle dependencies one at a time. No prerequisites: the Gradle
Versions Plugin's `dependencyUpdates` task reports the updates, and the plugin is injected by an init
script into any build without it. The plugin needs Gradle 8.4 or later; on an older wrapper, run
`upgrade-gradle` first or ask the maintainer.

Every configuration's declared dependencies are reported, including the settings and build-script
classpaths, but versions that arrive only transitively are not. `buildHealth`, where applied,
enriches verification.

## Composite and included builds

Each directory with its own `settings.gradle(.kts)` is a build, and so is `buildSrc`. Each has its own
catalog, repositories, and plugins, and gets its own report (step 2).

```
find . \( -name 'settings.gradle.kts' -o -name 'settings.gradle' -o -type d -name buildSrc \) \
  -not -path '*/build/*' -not -path '*/.claude/worktrees/*'
```

## Sub-agent delegation

Delegate **verification** (steps 5 and 6), one single-shot general-purpose sub-agent per build, on a
small, fast model: the job is running a command and trimming its output. It returns only step 5's
summary contract. A sub-agent **must not** edit files, run `git`, fix failures, or move on to another
dependency; on failure it returns enough to act on, never a bare "FAIL". Everything else stays in the
main thread. Relay what comes back.

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

Run `dependencyUpdates` once per build, from that build's directory:

```
./gradlew dependencyUpdates --output-formatter=json -q -p <build-dir>      # plugin already applied
./gradlew dependencyUpdates --output-formatter=json -q -p <build-dir> \
  --init-script <absolute-path>/gvp.init.gradle.kts                        # plugin not applied
```

The plugin is already applied when `ben-manes.versions` appears in that build's settings script,
build scripts, catalog, or build logic, or in `~/.gradle/init.d`. **Never add the init script to
such a build:** where `DependencyUpdatesTask` is configured by type in the build, it fails with "is
not a subclass of the given type". An init script applies to every build in one invocation, so run
each build on its own with `-p`, never as `:included:dependencyUpdates` from the root.

Settings plugins are reported only where `io.github.ben-manes.versions.settings` is applied, as the
init script does. Where only the project plugin is applied, look up each plugin in the settings
`plugins { }` block by hand: fetch
`https://plugins.gradle.org/m2/<id-with-dots-as-slashes>/<id>.gradle.plugin/maven-metadata.xml`, or
the same path under that build's `pluginManagement { repositories }`, and take the highest stable
version.

Write the init script outside the repo, in a temp or scratch directory, and pass its absolute path:
`--init-script` resolves a relative path against the working directory, not against `-p`.

```kotlin
import com.github.benmanes.gradle.versions.VersionsSettingsPlugin

initscript {
  repositories { gradlePluginPortal() }
  dependencies { classpath("io.github.ben-manes:gradle-versions-plugin:latest.release") }
}

gradle.beforeSettings(Action<Settings> {
  pluginManager.apply(VersionsSettingsPlugin::class.java)
})
```

Read each report with `jq`, from `build/dependencyUpdates/report.json` under the build directory
unless `outputDir` or `reportfileName` is set on the task:

- **`.outdated.dependencies[]`**: `group`, `name`, `version`, and `available`. The newest release is
  in whichever of `available.release`, `.milestone`, or `.integration` is set, matching the task's
  `revision`. `available.minor` is the newest version in the current major, `available.patch` the
  newest in the current minor. Take `available.preRelease` only when the current version is itself a
  pre-release.
- A plugin, from a settings or build `plugins { }` block, is reported by its marker,
  `<id>:<id>.gradle.plugin`.
- **`.exceeded`**: re-run that build with `--refresh-dependencies`. Never use it on the first run.
- **`.unresolved`** and **`.skipped`**: carry them into the step-7 report; they are not upgrades.
- **`.gradle`**: a newer Gradle. Mention it; `upgrade-gradle` handles it.

Versions outside a `strictly` or `reject` bound, or outside a consumed platform's constraints, are
already left out of the report. Where the plugin is already applied, the rules the maintainer set on
the task apply too.

Find where each entry is declared: a `libs.versions.toml` alias or `[versions]` entry, a
settings `plugins { }` block, or a build script. An entry declared nowhere in the build, such as the
Kotlin compiler classpath filled by `kotlin-dsl`, is not an upgrade: list it in step 7 and move on.
The same coordinate and version declared in one shared catalog, or repeated across settings files, is
**one** update.

### 3. Self-update the Gradle Versions Plugin first

If the plugin is applied in a build and has an update
(`io.github.ben-manes.versions`, `io.github.ben-manes.versions.settings`, or the deprecated
`com.github.ben-manes.versions`), upgrade only that plugin before anything else: run it as a normal
round (step 4), then re-run step 2 and continue from the refreshed report. Keep the plugin ID
already in use unless asked.

### 4. Update one dependency at a time

One dependency per round, one commit per round. Settings plugins count as single dependencies.

**Prioritize by compatibility relationships:**
1. Build toolchain plugins (compiler plugins, annotation processors, code generators)—update and test
   with the CURRENT language/platform version BEFORE upgrading the language/platform itself
2. BOM/platform dependencies before their constituent libraries
3. Core libraries before their dependents
4. Independent libraries last

Place each settings plugin by what it affects (e.g. a toolchain resolver alongside other toolchain
updates).

**Each round:**
1. Update only its version, to the newest release from step 2, where it is **declared**: the
   `libs.versions.toml` declaring it (never another build's catalog), the `settings.gradle(.kts)`
   `plugins { }` block for an inline-versioned settings plugin, or the build script. When the same
   settings-plugin id+version repeats across files, update **all** of them in this one round.
2. Identify affected modules: for catalog entries, search for usages of the alias; for a settings
   plugin, note the declaring file(s)
3. Run verification (step 5)
4. If it passed, commit this single dependency and continue straight to the next round without
   pausing. If it failed on a major-version bump and the entry lists an `available.minor` newer than
   the current version, revert and retry once at that minor; if that passes, commit it, record the
   major as blocked, and continue. Any other failure: **stop and report; do not commit, do not push,
   do not touch another dependency.**

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
reported `UP-TO-DATE` that the change should have touched, or entries under `.exceeded`), or a
deliberate from-scratch check.

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
- Majors held back at their latest minor, with the failure that blocked each
- Entries not upgraded: unresolved, skipped, and those declared nowhere in the build
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
- **Versions Plugin:** Do not apply it to the build, or leave the init script in the repo, unless
  asked.
- **Scope:** Keep diffs focused and minimal. No unrelated refactors, no unrelated version changes, no
  new dependencies without clear justification.
- **Git:** Do not create branches unless explicitly instructed. (Commit and push rules: steps 1, 4,
  5, 6.)
