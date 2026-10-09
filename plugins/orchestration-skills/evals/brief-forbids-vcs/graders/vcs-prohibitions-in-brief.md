---
type: llm
---

PASS only if the brief includes an instruction to the agent not to commit and not to push (a single instruction covering commit, merge, and push counts). The prohibition must be inside the brief, addressed to the agent, and explicit: "follow the repo's conventions" or "leave integration to me" alone does not count. FAIL if the brief asks the agent to commit its work, or says nothing about committing and pushing, or the prohibition appears only in commentary outside the brief. Quote the sentence that decides it.
