---
name: upgrade-gradle
description: Upgrade the Gradle wrapper to the latest version, with build validation.
paths: "**/gradle-wrapper.properties"
---

# Upgrade Gradle

Upgrade the Gradle wrapper to the latest available version and validate the build.

## Prerequisites

The target project must apply this Gradle plugin:

- [gradle-versions-plugin](https://github.com/ben-manes/gradle-versions-plugin) — provides the `dependencyUpdates` task

## Delegating verbose work to sub-agents

The two verbose steps — discovering the latest Gradle version (`dependencyUpdates`, step 1) and the validation `build` (step 4) — produce large output that is mostly noise. Run each in a single-shot **sub-agent** (the general-purpose type, which has the Bash access these commands need) so the raw output stays in the sub-agent and only the short summary contract noted in that step returns to the main thread.

A sub-agent must not edit files, run `git`, or fix failures. The version edit, wrapper regeneration (step 3), and reporting stay in the main thread; relay what each sub-agent returns.

## Workflow

### 1. Discover available Gradle version

Delegate to a sub-agent:

```
./gradlew dependencyUpdates --no-parallel
```

It looks for a "Gradle release-candidate updates" section (or similar) in the output that reports a newer Gradle version, and returns only the current and latest available Gradle version (or that none is available). The raw report stays in the sub-agent.

### 2. Determine upgrade path

Check the root build script (`build.gradle.kts` or `build.gradle`) for a `wrapper` task configuration. This may appear as any of:

- `tasks.wrapper { ... }`
- `tasks.named<Wrapper>("wrapper") { ... }`
- `tasks.named("wrapper") { ... }`
- Other variations that configure the `Wrapper` task

The presence or absence of this configuration determines which path to follow.

### 3. Apply the upgrade

**Path A — wrapper task exists in build script:**

1. Update the `gradleVersion` value in the wrapper task block in the build script
2. Run `./gradlew wrapper` to regenerate wrapper files
3. Run `./gradlew help` to apply the new version

**Path B — no wrapper task:**

1. Update the `distributionUrl` in `gradle/wrapper/gradle-wrapper.properties` to reference the new version
2. Run `./gradlew help` to apply the new version

The `./gradlew help` step is necessary because it causes the wrapper to download and apply the new Gradle distribution, which may update `gradle/wrapper/gradle-wrapper.jar`, `gradlew`, and `gradlew.bat`.

### 4. Validation

Run, in a sub-agent:

```
./gradlew build
```

The sub-agent returns only `PASS` (with the `BUILD SUCCESSFUL` marker), or `FAIL` with the failing task and the actionable error block (compiler errors with `file:line`, failed test names with the assertion) trimmed to what's needed to act on. This must pass before reporting results.

**`--rerun-tasks` option:** Before dispatching the validation build, check memory for a saved `--rerun-tasks` preference. If no preference is found, ask the maintainer:

> Would you like to run `./gradlew build` with `--rerun-tasks`? This forces all tasks to re-execute regardless of up-to-date checks.
> - **yes** — use `--rerun-tasks` this time
> - **no** — skip it this time
> - **always** — use it now and in future sessions (saves preference)
> - **never** — skip it now and in future sessions (saves preference)

If the maintainer answers "always" or "never", save that preference to memory for future invocations. This option applies only to `./gradlew build`, not to other Gradle tasks.

### 5. Reporting

- State the previous and new Gradle versions
- List all files modified (may include `gradle-wrapper.properties`, `gradle-wrapper.jar`, `gradlew`, `gradlew.bat`, and the build script if Path A was used)
- Report validation results
- Do not create Git commits — leave changes for the maintainer to review

## Constraints

- **Scope:** Only change the Gradle version. Do not update dependencies, modify build logic, or perform unrelated refactors.
- **Git:** Do not run `git commit`, `git push`, or create branches unless explicitly instructed.
