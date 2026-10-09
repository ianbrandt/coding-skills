---
type: llm
---

PASS if the reply goes ahead with the local commit without asking the user to approve, confirm, or choose anything first. FAIL if the reply asks "should I proceed?", asks the user to pick between options, or holds the commit for an answer. A commit message shown as part of doing the commit is not a question. Neither is a check the reply makes itself, such as reading the branch name or the diff, or a statement that this session has no shell. When failing, quote the question.
