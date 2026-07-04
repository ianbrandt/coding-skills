# gradle-skills

A [Claude Code](https://claude.ai/code) plugin providing skills for working with Gradle projects.

## Skills

### `upgrade-dependencies`

Guides Claude through checking, upgrading, and verifying Gradle dependencies one at a time — including **settings plugins** (those applied in the `plugins { }` block of `settings.gradle(.kts)`), which the gradle-versions-plugin does not report. Claude iterates through every available update automatically, committing each verified upgrade as its own atomic commit (one per dependency), and optionally pushes once all upgrades pass.

The primary update check is a direct metadata lookup against each catalog's declared entries, so it works on **composite builds** (mono-repos using `includeBuild`), where `dependencyUpdates` alone under-reports — it does not traverse included builds and is often applied in only one of them.

**Requires:** nothing. The catalog and settings-plugin checks query published metadata directly. Optionally enriched by the [gradle-versions-plugin](https://github.com/ben-manes/gradle-versions-plugin) (its `dependencyUpdates` task also surfaces transitive and build-script dependencies where applied) and the [dependency-analysis-gradle-plugin](https://github.com/autonomousapps/dependency-analysis-gradle-plugin) (for the `buildHealth` verification task).

**Works with:** any Gradle project using a [version catalog](https://docs.gradle.org/current/userguide/platforms.html) (`libs.versions.toml`), single or composite. Settings plugins are covered too, including the common case where their versions are declared inline in `settings.gradle(.kts)`.

**Workflow:**
1. Settle the per-round and final verification tasks, and whether to push once everything passes (commits are automatic — one atomic commit per verified upgrade)
2. Enumerate the builds (root plus every `includeBuild` target) and check each catalog's entries against the [Gradle Plugin Portal](https://plugins.gradle.org/) and Maven Central by direct metadata lookup
3. Check settings plugins the same way (the gradle-versions-plugin does not report them); where the gradle-versions-plugin is applied, run `dependencyUpdates` as enrichment
4. Update one dependency or settings plugin at a time — in the catalog file that declares it, or in the `settings.gradle(.kts)` `plugins { }` block
5. Verify with the chosen tasks after each change (adding `--rerun-tasks` when a from-scratch check is warranted)
6. Commit each verified change and continue automatically through every update; push only after a final verification passes, and only if you opted into push

**Sub-agents:** The verbose steps — the `dependencyUpdates` report, settings-plugin metadata lookups, and each verification build — run in sub-agents that return only a short summary. This keeps the raw Gradle output out of the main conversation, reducing context and plan (token) usage across a multi-round run.

### `upgrade-gradle`

Guides Claude through upgrading the Gradle wrapper to the latest available version.

**Requires:** nothing. The latest version comes from Gradle's own [version service](https://services.gradle.org/versions/current), so no plugin needs to be applied.

**Works with:** any Gradle project with a [Gradle wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html), single or composite — every wrapper in the project is upgraded, each in its own build.

**Workflow:**
1. Query `services.gradle.org/versions/current` for the latest Gradle version
2. Find every `gradle-wrapper.properties` in the project (the wrapper task is per-build, so each is upgraded in its own directory)
3. For each: if that build's script has a `wrapper` task configuration, update the version there and run `./gradlew wrapper` then `./gradlew help`; otherwise update `gradle-wrapper.properties` directly and run `./gradlew help`
4. Run `build` to validate the upgrade (composite-aware: a root build may not reach every included build)

**Sub-agents:** Discovery and the validation build run in sub-agents that return a short summary, keeping verbose Gradle output out of the main conversation.

## Installation

Install at user scope (available across all your projects):

```
/plugin marketplace add IanBrandt/gradle-skills
/plugin install gradle-skills@ianbrandt
```

### Bash permissions (optional)

The dependency update workflow runs `./gradlew` tasks and `git` commands (it commits each verified upgrade automatically). To avoid per-invocation approval prompts, add these permissions in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(./gradlew dependencyUpdates:*)",
      "Bash(./gradlew build:*)",
      "Bash(./gradlew buildHealth:*)",
      "Bash(./gradlew wrapper)",
      "Bash(./gradlew help)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)"
    ]
  }
}
```

`git add` and `git commit` are used on every dependency run; `git push` is only needed if you opt into push. If you choose verification tasks beyond the defaults (e.g. a `clean` cumulative run), add matching `Bash(./gradlew …)` entries.

Both skills fetch metadata over HTTPS (via `curl` or a web fetch): `upgrade-dependencies` checks catalog and settings-plugin versions against [plugins.gradle.org](https://plugins.gradle.org/) and Maven Central, and `upgrade-gradle` reads the latest Gradle version from [services.gradle.org](https://services.gradle.org/versions/current). Allow that mechanism if you want to avoid a prompt for it.

## Updating

```
/plugin marketplace update ianbrandt
/plugin update gradle-skills@ianbrandt
```

## Usage

Invoke the skill by name:

```
/gradle-skills:upgrade-dependencies
/gradle-skills:upgrade-gradle
```

## License

MIT
