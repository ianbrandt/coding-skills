---
max_turns: 3
tags: [issue, style]
runs: 2
---

Write the body of a GitHub issue reporting this defect to the maintainer of a Gradle plugin. One to three sentences of problem statement, then the reproduction as a fenced block. Reply with the body only.

The defect: a later version is listed in the dependency-updates report for a library even when a platform (BOM) applied to the build pins that library to an exact version, so the listed upgrade cannot be applied. Reproduction: a build with `implementation(platform("org.springframework.boot:spring-boot-dependencies:3.3.0"))` and `implementation("com.fasterxml.jackson.core:jackson-databind")`, running `./gradlew dependencyUpdates`, prints `jackson-databind [2.17.1 -> 2.18.2]` although the platform pins 2.17.1. Verified on v0.51.0.
