# gradle-skills

A [Claude Code](https://claude.ai/code) plugin providing skills for working with Gradle projects.

## Skills

### `upgrade-dependencies`

Guides Claude through checking, upgrading, and verifying Gradle dependencies one at a time — including **settings plugins** (those applied in the `plugins { }` block of `settings.gradle(.kts)`), which the gradle-versions-plugin does not report. Each verified upgrade can optionally be committed (one commit per dependency) and pushed.

**Requires:** [gradle-versions-plugin](https://github.com/ben-manes/gradle-versions-plugin) in the target project for the `dependencyUpdates` task. Optionally, the [dependency-analysis-gradle-plugin](https://github.com/autonomousapps/dependency-analysis-gradle-plugin) for the `buildHealth` task.

**Works with:** any Gradle project using a [version catalog](https://docs.gradle.org/current/userguide/platforms.html) (`libs.versions.toml`). Settings plugins are covered too, including the common case where their versions are declared inline in `settings.gradle(.kts)`.

**Workflow:**
1. Choose the per-round and final verification tasks, and whether to auto-commit and push (asked up front)
2. Run `dependencyUpdates` to identify available upgrades
3. Check settings plugins separately against the [Gradle Plugin Portal](https://plugins.gradle.org/) (the gradle-versions-plugin does not report them)
4. Update one dependency or settings plugin at a time — in `libs.versions.toml`, or in the `settings.gradle(.kts)` `plugins { }` block
5. Verify with the chosen tasks (run with `--rerun-tasks`) after each change
6. With auto-commit on, commit each verified change and continue, then push only after a final verification passes; with it off, stop and wait for maintainer confirmation after each

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

The dependency update workflow runs `./gradlew` tasks — and, if you enable auto-commit/push, `git` commands. To avoid per-invocation approval prompts, add these permissions in `~/.claude/settings.json`:

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

The `git` entries are only needed if you opt into auto-commit or auto-push; omit them otherwise. If you choose verification tasks beyond the defaults (e.g. a `clean` cumulative run), add matching `Bash(./gradlew …)` entries.

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
