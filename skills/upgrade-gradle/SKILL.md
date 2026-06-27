---
name: upgrade-gradle
description: Upgrade the Gradle wrapper to the latest version, with build validation.
paths: "**/gradle-wrapper.properties"
---

# Upgrade Gradle

Upgrade the Gradle wrapper to the latest available version and validate the build.

## Prerequisites

None. The latest Gradle version comes from Gradle's own version service over HTTPS, so the target project does not need any plugin applied.

## Composite and included builds

A project may be more than one Gradle build: a root build plus other builds pulled in with `includeBuild(...)`, possibly transitively (an included build can include further builds). The practical rule for enumeration: **each directory with its own `gradle-wrapper.properties` is a build that carries its own wrapper** (the wrapper task generates `gradlew`, `gradlew.bat`, the jar, and the properties together, so a properties file always sits next to a runnable `gradlew`).

The wrapper task is **per-build** — a root run never regenerates an included build's wrapper. Each wrapper must therefore be upgraded in its own directory. Most projects have exactly one wrapper (the root); do not assume that without checking.

## Delegating verbose work to sub-agents

The validation `build` (step 4) produces large output that is mostly noise. Run it in a single-shot **sub-agent** (the general-purpose type, which has the Bash access these commands need) so the raw output stays in the sub-agent and only the short summary contract noted in that step returns to the main thread.

Version discovery (step 1) is a small HTTPS call and stays in the main thread. A sub-agent must not edit files, run `git`, or fix failures. The version edits, wrapper regeneration (step 3), and reporting stay in the main thread; relay what the sub-agent returns.

## Workflow

### 1. Discover available Gradle version

Query Gradle's version service directly (e.g. with `curl -s`):

```
https://services.gradle.org/versions/current             # latest stable
https://services.gradle.org/versions/release-candidate   # current RC, or {} if none
```

Each returns a JSON object whose `version` field is the version string (`current` also carries `downloadUrl`). Use the stable version by default; mention an available RC but do not adopt it unless the maintainer asks.

### 2. Find every wrapper

Enumerate all wrappers in the project, **excluding** generated and throwaway trees:

```
find . -name gradle-wrapper.properties -not -path '*/build/*' -not -path '*/.claude/worktrees/*'
```

For a single-build project this is just the root wrapper. For a composite build it may list several; upgrade each one (steps 3–4) in its own directory.

### 3. Apply the upgrade

For **each** wrapper directory found in step 2, check that build's root build script (`build.gradle.kts` or `build.gradle`) for a `wrapper` task configuration. This may appear as any of:

- `tasks.wrapper { ... }`
- `tasks.named<Wrapper>("wrapper") { ... }`
- `tasks.named("wrapper") { ... }`
- Other variations that configure the `Wrapper` task

The presence or absence of this configuration determines which path to follow.

**Path A — wrapper task exists in the build script:**

The task block is the **source of truth**: `./gradlew wrapper` rewrites `gradle-wrapper.properties` from it (including `gradleVersion`, `distributionType`, `networkTimeout`, `retries`, …), so editing only the `.properties` file is fragile.

1. Update the `gradleVersion` value in the wrapper task block in that build's build script
2. Run that build's `./gradlew wrapper` to regenerate wrapper files
3. Run that build's `./gradlew help` to apply the new version

**Path B — no wrapper task:**

1. Update the `distributionUrl` in that build's `gradle/wrapper/gradle-wrapper.properties` to reference the new version
2. Run that build's `./gradlew help` to apply the new version

The `./gradlew help` step is necessary because it causes the wrapper to download and apply the new Gradle distribution, which may update `gradle/wrapper/gradle-wrapper.jar`, `gradlew`, and `gradlew.bat`.

### 4. Validation

Run, in a sub-agent:

```
./gradlew build
```

In a composite build, a root `build` does **not** automatically build every included build — each included build is configured and executed in isolation, and lifecycle tasks do not fan out across them. Some builds may only be exercised by an aggregator task (for example, a set of example builds wired behind a single `examplesCheck`). If the root build does not transitively cover an upgraded wrapper's build, run that build's own validation too (its `./gradlew build`, or the aggregator task that reaches it). When the right task set is not obvious from the build structure, confirm it with the maintainer.

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
- List every wrapper upgraded, and all files modified (may include `gradle-wrapper.properties`, `gradle-wrapper.jar`, `gradlew`, `gradlew.bat`, and the build script if Path A was used)
- Report validation results
- Do not create Git commits — leave changes for the maintainer to review

## Constraints

- **Scope:** Only change the Gradle version. Do not update dependencies, modify build logic, or perform unrelated refactors.
- **Git:** Do not run `git commit`, `git push`, or create branches unless explicitly instructed.
