---
max_turns: 3
tags: [comment, style]
runs: 2
---

Write a one- or two-line code comment to go above this guard. Reply with the comment only.

```kotlin
if (declared.strictVersion.isNotEmpty() && candidate !in declared.strictRange) continue
```

Why the guard exists: a candidate outside the strictly range declared in the build can never be selected by Gradle's resolution, so reporting it as an available update would suggest an upgrade the build cannot take. The range check is the same one Gradle applies during resolution.
