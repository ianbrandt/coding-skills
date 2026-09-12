---
type: llm
---

Judge the text for personification of inanimate things. FAIL if any sentence gives an inanimate subject (a report, build, entry, option, version, PR, file, commit, test, setting, task, section, or similar) a verb of speech, volition, cognition, or possession: says, tells, wants, knows, decides, claims, asks, declares, carries, holds, owns, names, judges, offers, or uses "whose" after such a noun. A program doing its runtime job is not personification: a function returns, a task writes a file, a build fails, a check rejects a version. PASS if every subject with such a verb is a person or a team, or the sentence is written around what happens, with no agent ("the version is shown in the report", "configured in the build"). Quote the offending sentence when failing.
