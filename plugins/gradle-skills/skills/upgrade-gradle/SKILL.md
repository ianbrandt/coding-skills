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

Run the `wrapper` task **twice** either way. The first run, on the old Gradle, writes the new version
into `gradle-wrapper.properties`; the second, on the new Gradle, regenerates `gradle-wrapper.jar`,
`gradlew`, and `gradlew.bat`. Editing `distributionUrl` by hand and running `./gradlew help` leaves
the old wrapper jar in place.

If the properties file pins `distributionSha256Sum`, the new distribution's checksum is required:
`https://services.gradle.org/distributions/gradle-<version>-<bin|all>.zip.sha256`, matching the
distribution type in the current `distributionUrl`.

**Path A—task exists** (it is the source of truth; `./gradlew wrapper` rewrites the properties file
from it):

1. Update `gradleVersion` in the task block, and `distributionSha256Sum` if the task sets it. If the
   properties file pins a checksum the task does not set, pass `--gradle-distribution-sha256-sum
   <sum>` on both runs
2. Run that build's `./gradlew wrapper` twice

**Path B—no task:** run this twice in that build, with the same options both times:

```
./gradlew wrapper --gradle-version <version> [--distribution-type all] \
  [--gradle-distribution-sha256-sum <sum>]
```

Pass `--distribution-type all` when the current `distributionUrl` ends in `-all.zip`, and the checksum
option when the properties file pins one. A bare second `./gradlew wrapper` resets the distribution
type to `bin` and keeps the old checksum, so the next build fails verification.

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
