---
type: regex
pattern: '\b(the|a|an|this|that|its|each|every|no)\s+(\w+\s+){0,3}(says|said|tells|told|wants|wanted|knows|knew|decides|decided|claims|claimed|asks|asked|declares|declared|assumes|assumed|believes|thinks|intends|refuses)\b|\b(report|build|entry|option|version|PR|file|commit|test|setting|task|plugin|row|section|paragraph|title)\s+whose\b'
flags: i
match: not_contains
---
