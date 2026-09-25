---
type: llm
---

PASS only if the reply includes all three handoff parts: (1) a root directory to start in, immediately followed by a standalone prompt in its own plain, untagged fenced code block (no language tag after the opening backticks) that functions as an entry point on its own (a skill invocation, a work-item ID, or a goal), not a recap of this session; (2) one line on why the next work goes to a fresh session rather than continuing here; (3) a model and an effort or reasoning level, in terms a model picker would show (a model name plus a level such as low, medium, high, or max). The `**Session title:**` block and its own fenced title do not count as the handoff prompt, even when it is the only fenced block in the reply. FAIL if any of the three parts is missing, the fenced prompt is a recap of this session rather than a standalone one, the fence has a language tag, or the only fenced block present is the session-title block. When failing, name the missing part.
