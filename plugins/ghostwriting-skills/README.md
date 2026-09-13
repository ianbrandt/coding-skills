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
  your explicit go, with at most one line after it: a check that did not run, a question to settle
  before posting, or the part that runs over a cap because a fact you gave would not fit. Drafting is
  the skill's, posting is yours.
- **Log the delta** once, after you edit or give the go, never in the hand-over. A rule the spec
  was missing earns a new entry; a rule the spec had and the draft broke anyway is recorded as a procedure failure and earns nothing. A rule general
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

## Measuring it

[`evals/`](evals/) is a `claude plugin eval` suite of two PR-body drafting tasks and one issue-body task. Each case runs
`ghostwrite` against a fixture voice spec for an invented maintainer, copied into the workspace by a
scaffold script, and grades the reply for spaced dashes, banned words, and personified subjects.
Two judge-model checks follow: the body kept every fact it was given, and it fits the spec's limit
for the genre. No length or format is given in any prompt, so a form pass means the limit was read
from the spec. The spec's location is in the prompt for both runs, and the run without the plugin
reads the spec too, so the two runs differ by the drafting procedure rather than by access to the
spec. Run it
from the plugin directory:

```bash
claude plugin eval . --scaffold --runs 4 --judge-model sonnet --no-publish
```

The cases grant no shell and load no `writing-conventions`, so the lint step in `ghostwrite` does
not run, and the rewrite pass is all the suite measures. Every prompt is a single turn, and on those the default register
is already clean: every arm, including no plugin, passes personification on nearly every run.
Results land under `evals/results/`, which is ignored.

On 2026-09-13, with three runs per case, the plugin scored lower than no plugin, by 0.28 on
average. The drafted bodies met the spec's limits about as often in both runs. The gap came from
the reply around the body: every plugin-loaded reply added process notes that the prompt did not
ask for, such as the lint not running or a delta-log entry, and 7 of 9 of those notes had a spaced
em dash, which fails the regex grader for the whole reply.

Later on 2026-09-13, `ghostwrite` was changed to hand over the body and at most one line after it,
and the suite was run again with three runs per case. The plugin still scored lower, by 0.15 on
average: 0.67 on every plugin-loaded run, against 0.81 without the plugin. No plugin-loaded reply
had a spaced dash, rewrite notes, or a delta-log entry. Each one ended with a one-line note that the
lint did not run, which is expected, since the cases grant no shell. All 9 plugin-loaded runs failed
both the form and the facts judges, though 7 of the 9 bodies above that note kept every fact within
the limit. The judges most likely counted the note as part of the body. The facts judge also
failed 8 of 9 runs without the plugin, so its verdicts need a read of the drafts before they count.

## Works with `writing-conventions`

Neither plugin needs the other. `writing-conventions` loads the prohibitions every session (no
personified subjects, no spaced em dashes, a banned-word list) and binds chat replies too; this
plugin drafts the positive half, in your voice, on demand. Installed together, the rules
`ghostwrite` learns from your edits land in the file that loads every session.
