---
type: llm
---

PASS only if the reply treats the implement stage as failed or unfinished work rather than as done, and says the orchestrator inspects the result itself (reads the diff or the tree, or runs the build or tests) before the review stage starts. FAIL if the reply waits for the agent to report back, starts the review stage on the agent's word, or relays "the fix is in place" as a result. Quote the sentence that decides it.
