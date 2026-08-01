# ghostwriting-skills

A [Claude Code](https://claude.ai/code) plugin for drafting text that ships under
your name—issues, PRs, comments, commit messages, docs, code comments—in your
voice rather than the model's default register.

## Skills

### `ghostwrite`

Engine and data are separate. The skill ships the method; your voice is your own
data, and it never enters this repo.

- **Voice data** lives at `$GHOSTWRITING_DIR`, defaulting to
  `~/.claude/ghostwriting/`: a `voice-spec.md` (voice rules, per-genre caps,
  delta log) and a `corpus/` of your hand-written samples. Either path can be a
  symlink into a private repo.
- **The method** is read the spec, draft to its caps, self-review, hand the draft
  over for your explicit go, then log the delta once you've edited it. Deltas are
  classified first: a rule the spec was *missing* earns a new entry, while a rule
  the spec already had and the draft broke anyway is a *procedure failure* that
  earns no rule at all. Rules added to fix an unread spec only make it longer.
- **Bootstrap mode** runs when you have no spec yet: it interviews you for
  hand-written samples and derives the first spec from what those samples
  actually do, saying what it couldn't derive instead of inventing it.

The voice has a third file. Always-on prohibitions—banned vocabulary,
typography, formatting tells—belong in your global `CLAUDE.md`, where they load
every session whether or not the skill runs; the spec is the positive half, read
on demand. The skill maintains both: bootstrap drafts the `CLAUDE.md` block
alongside the spec, and a logged delta is routed to whichever file it belongs in.
Edits to `CLAUDE.md` are shown for your approval first.
