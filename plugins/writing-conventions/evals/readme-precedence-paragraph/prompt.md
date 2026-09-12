---
max_turns: 3
tags: [docs, style]
runs: 2
---

Write one README paragraph, four to six sentences, explaining how three ways of setting the same option relate. Reply with the paragraph only.

The option: the revision (release, milestone, or integration) used to pick candidate versions. It can be set as a task property in the build script, passed as the --revision command-line option, or set as the system property revision. The command-line option is for a single run and wins over the build-script setting. The system property is older than the command-line option; it is read after the build-script setting and before the command-line option, and is kept for compatibility.
