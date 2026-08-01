# ghostwriting-skills

A [Claude Code](https://claude.ai/code) plugin for drafting text that ships under
your name—issues, PRs, comments, commit messages, docs, code comments—in your
voice rather than the model's default register.

## Skills

### `ghostwrite`

The skill ships the method; your voice is your own data, and it never enters
this repo.

- **Voice data** lives at `$GHOSTWRITING_DIR`, defaulting to
  `~/.claude/ghostwriting/`: a `voice-spec.md` (voice rules, per-genre caps,
  delta log) and a `corpus/` of your hand-written samples. Either path can be a
  symlink into a private repo.
- **The method**: read the spec, draft to its caps, self-review, hand the draft
  over for your explicit go, then log the delta once you've edited it. A rule
  the spec was missing earns a new entry; a procedure failure (the spec had the
  rule, the draft broke it) earns none.
- **Bootstrap mode** runs when you have no spec yet: it interviews you for
  hand-written samples and derives the first spec from what they actually do,
  saying what it couldn't derive instead of inventing it.

Always-on prohibitions—banned vocabulary, typography, formatting tells—live in
your global `CLAUDE.md`, loaded every session; the spec is the positive half,
read on demand. The skill maintains both, and shows any `CLAUDE.md` edit for
your approval first.
