---
max_turns: 3
tags: [tests, style]
runs: 2
---

Suggest five Spock specification method names (the quoted-string style, like `def "prints the current version"()`) for these behaviours. Reply with the five names only.

1. When a dependency is constrained by a platform to its current version, the report prints the platform's coordinates on that row.
2. When the constraining platform is itself outdated, the report prints the platform's later version too.
3. When no platform applies, the row is printed as before.
4. When two platforms constrain the same dependency, both are printed.
5. When the constraint comes from a dependency's own strictly bound rather than a platform, nothing extra is printed.
