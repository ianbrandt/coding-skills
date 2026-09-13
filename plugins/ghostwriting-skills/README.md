# ghostwriting-skills

A [Claude Code](https://claude.ai/code) plugin for drafting text that ships under your name—issues,
PRs, comments, commit messages, docs, code comments—in your voice rather than the model's default
register. The skills ship the method; your voice is your own data, and it never enters this repo.

## Where your voice data lives

A `voice-spec.md` (voice rules, per-genre caps, a delta log of your edits) and a `corpus/` of your
hand-written samples. The directory is asked for when the plugin is enabled (the `voice_dir`
option); left empty, the skills use `$GHOSTWRITING_DIR`, then `~/.claude/ghostwriting/`. The
directory can be a symlink into a private repo.

## Skills

### `ghostwrite`

The drafting protocol and the correction loop it runs inside.

- **Read the spec, then draft to its caps** for the genre, imitating your corpus samples and the
  spec's contrast pairs rather than writing from a rule list. A cap is a cap, not a target.
- **Self-review, then a fresh-context rewrite** by a subagent given only the draft, the rules, and
  your spec's contrast pairs, since a draft's tells read as natural to the model that produced it.
  The rewrite is checked for dropped facts, then run through the `writing-conventions` lint when that
  plugin is installed, because some tells survive a rewrite. Then the draft goes in the reply for
  your explicit go; drafting is the skill's, posting is yours.
- **Log the delta** after you edit. A rule the spec was missing earns a new entry; a rule the spec
  had and the draft broke anyway is recorded as a procedure failure and earns nothing. A rule general
  enough to bind every reply is routed to the always-on writing rules file your session loads, when
  one does (the `writing-conventions` plugin's `hooks/rules.md`, or your global `CLAUDE.md`);
  everything about the form and size of one genre stays in your spec.
- **Bootstrap** when you have no spec yet: an interview for hand-written samples, then a first spec
  derived from what they actually do, with the gaps stated rather than invented. A seed exported by
  `share-ghostwriting-spec` from someone else's spec replaces derivation from scratch.

### `share-ghostwriting-spec`

Exports your spec as an anonymized seed a teammate can bootstrap from. The per-genre caps and
procedure carry over as house style; the delta log and corpus never ship; names, repos, URLs, and
quoted drafts are scrubbed; and the export is written to a file beside your spec for you to read
before it goes anywhere. A recipient runs the `ghostwrite` bootstrap with the seed: your caps become
their starting point, while their voice comes from their own samples.

## Works with `writing-conventions`

Neither plugin needs the other. `writing-conventions` loads the prohibitions every session (no
personified subjects, no spaced em dashes, a banned-word list) and binds chat replies too; this
plugin drafts the positive half, in your voice, on demand. Installed together, the rules
`ghostwrite` learns from your edits land in the file that loads every session.
