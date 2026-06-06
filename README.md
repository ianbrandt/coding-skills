# gradle-skills

A [Claude Code](https://claude.ai/code) plugin providing skills for working with Gradle projects.

## Skills

### `upgrade-dependencies`

Guides Claude through checking, upgrading, and validating Gradle dependencies one at a time — including **settings plugins** (those applied in the `plugins { }` block of `settings.gradle(.kts)`), which the gradle-versions-plugin does not report.

**Requires:** [gradle-versions-plugin](https://github.com/ben-manes/gradle-versions-plugin) in the target project for the `dependencyUpdates` task. Optionally, the [dependency-analysis-gradle-plugin](https://github.com/autonomousapps/dependency-analysis-gradle-plugin) for the `buildHealth` task.

**Works with:** any Gradle project using a [version catalog](https://docs.gradle.org/current/userguide/platforms.html) (`libs.versions.toml`). Settings plugins are covered too, including the common case where their versions are declared inline in `settings.gradle(.kts)`.

**Workflow:**
1. Run `dependencyUpdates` to identify available upgrades
2. Check settings plugins separately against the [Gradle Plugin Portal](https://plugins.gradle.org/) (the gradle-versions-plugin does not report them)
3. Update one dependency or settings plugin at a time — in `libs.versions.toml`, or in the `settings.gradle(.kts)` `plugins { }` block
4. Run `build` (and `buildHealth` if available) after each change
5. Stop and wait for maintainer confirmation before proceeding

### `upgrade-gradle`

Guides Claude through upgrading the Gradle wrapper to the latest available version.

**Requires:** [gradle-versions-plugin](https://github.com/ben-manes/gradle-versions-plugin) in the target project for the `dependencyUpdates` task.

**Works with:** any Gradle project with a [Gradle wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html).

**Workflow:**
1. Run `dependencyUpdates` to discover the latest Gradle version
2. If the root build script has a `wrapper` task configuration, update the version there and run `./gradlew wrapper` then `./gradlew help`; otherwise update `gradle-wrapper.properties` directly and run `./gradlew help`
3. Run `build` to validate the upgrade

## Installation

Install at user scope (available across all your projects):

```
/plugin marketplace add IanBrandt/gradle-skills
/plugin install gradle-skills@ianbrandt
```

### Bash permissions (optional)

The dependency update workflow runs `./gradlew` tasks. To avoid per-invocation approval prompts, add these permissions in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(./gradlew dependencyUpdates:*)",
      "Bash(./gradlew build:*)",
      "Bash(./gradlew buildHealth)",
      "Bash(./gradlew wrapper)",
      "Bash(./gradlew help)"
    ]
  }
}
```

The settings-plugin check additionally fetches plugin metadata from [plugins.gradle.org](https://plugins.gradle.org/) over HTTPS (via `curl` or a web fetch); allow that mechanism if you want to avoid a prompt for it.

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
