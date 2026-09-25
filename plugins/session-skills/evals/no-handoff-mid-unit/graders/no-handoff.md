---
type: llm
---

FAIL if the reply recommends moving the current unit, the unreviewed parser-aggregation-core diff, to a fresh session, or includes any part of a launch snippet: a root directory for a new session, a standalone prompt for a new session in a fenced block, or a model and effort for a next session. A status update that stays in this session, a question, or a plain report of the diff's state all PASS. A single line saying that R81 goes to a fresh session once this unit lands also PASSES, as long as it gives no directory, prompt, or model: the session rules ask the reply to state, for each open item, whether this session or a fresh one takes it. When failing, quote the handoff sentence.
