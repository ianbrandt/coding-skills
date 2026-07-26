---
name: upgrade-gradle
description: Upgrade the Gradle wrapper to the latest version, with build validation.
paths: "**/gradle-wrapper.properties"
---

# Upgrade Gradle

Upgrade every Gradle wrapper to the latest stable version and validate the build. No prerequisites.

## Sub-agent delegation

Run the step-4 validation build in a single-shot general-purpose sub-agent; keep discovery, edits,
wrapper regeneration, and reporting in the main thread. Sub-agents must not edit files, run `git`, or
fix failures. Relay what they return.

## Workflow

### 1. Discover the version

```
https://services.gradle.org/versions/current             # latest stable
https://services.gradle.org/versions/release-candidate   # current RC, or {} if none
```

Use `version` from the stable response. Mention an available RC; adopt it only if the maintainer asks.

### 2. Find every wrapper

```
find . -name gradle-wrapper.properties -not -path '*/build/*' -not -path '*/.claude/worktrees/*'
```

Each hit is a separate build with its own wrapper. Upgrade each in its own directory (steps 3–4).

### 3. Apply the upgrade

Check that build's root build script for a `wrapper` task configuration (`tasks.wrapper { ... }`,
`tasks.named<Wrapper>("wrapper") { ... }`, `tasks.named("wrapper") { ... }`, or any variation
configuring the `Wrapper` task).

**Path A—task exists** (it is the source of truth; `./gradlew wrapper` rewrites the properties file
from it):

1. Update `gradleVersion` in the task block
2. Run that build's `./gradlew wrapper`
3. Run that build's `./gradlew help`

**Path B—no task:**

1. Update `distributionUrl` in that build's `gradle/wrapper/gradle-wrapper.properties`
2. Run that build's `./gradlew help`

`./gradlew help` applies the new distribution and may update `gradle-wrapper.jar`, `gradlew`, and
`gradlew.bat`.

### 4. Validation

```
./gradlew build
```

A root `build` does not fan out across included builds. If it does not transitively cover an upgraded
wrapper's build, also run that build's own `./gradlew build` or the aggregator task reaching it; when
the task set is not obvious, confirm it with the maintainer.

Sub-agent returns only `PASS` (with the `BUILD SUCCESSFUL` marker), or `FAIL` with the failing task
and actionable error block (compiler errors with `file:line`, failed test names with the assertion).
Must pass before reporting.

`--rerun-tasks` is your judgement: up-to-date checks ignore the Gradle version, so add it when the
validation must genuinely re-exercise the build. Validation build only.

### 5. Reporting

- Previous and new versions
- Every wrapper upgraded and all files modified (`gradle-wrapper.properties`, `gradle-wrapper.jar`,
  `gradlew`, `gradlew.bat`, plus the build script under Path A)
- Validation results
- No Git commits—leave changes for the maintainer

## Constraints

- **Scope:** Only the Gradle version. No dependency updates, build-logic changes, or unrelated
  refactors.
- **Git:** No `git commit`, `git push`, or branch creation unless explicitly instructed.
