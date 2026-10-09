# ghostwriting-skills

A [Claude Code](https://claude.ai/code) plugin for drafting text that ships under your name—issues,
PRs, comments, commit messages, docs, code comments—in your voice rather than the model's default
register. Only the method is in the skills. Your voice data is read from a directory you keep
outside this repo.

## Where your voice data lives

A `voice-spec.md` (voice rules, per-genre form, a delta log of your edits) and a `corpus/` of your
hand-written samples. The directory is asked for when the plugin is enabled (the `voice_dir`
option); left empty, the skills use `$GHOSTWRITING_DIR`, then `~/.claude/ghostwriting/`. The
directory can be a symlink into a private repo.

[`hooks/voice.ts`](hooks/voice.ts) appends that data to the `ghostwrite` skill's text as the skill
loads, through a `skill.prompt` hook: the spec, every corpus sample up to 64,000 characters in all,
and the `writing-conventions` rules file when that plugin is installed. Past that size the samples
are listed by name for the model to read by genre. For `share-ghostwriting-spec` only the directory
is appended, with whether it has a spec. A hooks module is a Claude Code mod, and this one was
checked on Claude Code 2.1.286 through 2.1.291. 2.1.286 is the oldest version supported, so neither
skill has a shell snippet to locate the directory by hand.
[`hooks/voice.test.ts`](hooks/voice.test.ts) runs under `claude plugin test`.

## Skills

### `ghostwrite`

The drafting protocol and the correction loop it runs inside.

- Read the spec, then draft to its caps for the genre, imitating your corpus samples and the spec's
  contrast pairs rather than writing from a rule list. Most drafts should come in under the cap.
- Self-review, lint, then a fresh-context rewrite by a subagent given only the draft, the rules, and
  your spec's contrast pairs, since a draft's tells read as natural to the model that produced it.
  The lint is the `writing-conventions` plugin's, when that plugin is installed. The rewrite is
  skipped for a draft of up to about five sentences with no lint hits. A longer one is rewritten,
  then checked for dropped facts and linted again, because some tells survive a rewrite. Then the
  draft goes in the reply for your explicit go, with at most one line after it: a check that did not
  run, a question to settle before posting, or the part that runs over a cap because a fact you gave
  would not fit. Posting is left to you.
- Log the delta once, after you edit or give the go, never in the hand-over. A rule missing from
  the spec is added as a new entry. A rule that was in the spec and was broken anyway is recorded as
  a procedure failure, with no new rule. A rule general enough to bind every reply is routed to the
  always-on writing rules file your session loads, when one does (the `writing-conventions` plugin's
  `hooks/rules.md`, or your global `CLAUDE.md`); everything about the form and size of one genre
  stays in your spec.
- Bootstrap when you have no spec yet: an interview for hand-written samples, then a first spec
  derived from the samples, with the gaps stated rather than invented. A seed exported by
  `share-ghostwriting-spec` from someone else's spec replaces derivation from scratch.

### `share-ghostwriting-spec`

Exports your spec as an anonymized seed a teammate can bootstrap from. The per-genre form and
procedure are kept as house style; the delta log and corpus are left out; names, repos, URLs, and
quoted drafts are scrubbed; and the export is written to a file beside your spec for you to read
before it goes anywhere. A recipient runs the `ghostwrite` bootstrap with the seed, which keeps
your caps as a starting point and derives the voice rules from the recipient's samples.

## Measuring it

[`evals/`](evals/) is a `claude plugin eval` suite of one PR-body drafting task, one issue-body
task, and one README-section task. In each case `ghostwrite` is run against a fixture voice spec for
an invented maintainer, copied into the workspace by a scaffold script, and the reply is graded for
spaced dashes, banned words, and personified subjects. Two judge-model checks follow: the body kept
every fact it was given, and it fits the spec's limit for the genre. No length or format is given in
any prompt, so a form pass means the limit was read from the spec. The spec's location is in the
prompt for both runs, and the fixture spec has no Procedure section, so the two runs differ only by
the plugin's drafting procedure. Run it from the plugin directory:

```bash
claude plugin eval . --scaffold --runs 4 --judge-model sonnet --no-publish -j 4
```

No shell is granted in the cases and `writing-conventions` is not loaded, so the lint step in
`ghostwrite` does not run. The rewrite is skipped for the short PR and issue bodies, where a
subagent ran in 1 of 24 plugin-loaded runs on 2026-10-05. Only the README section is longer than
five sentences, and a run of that case with no subagent call fails a scored check. Every prompt is
a single turn, and on those the default register is already clean: every arm, including no plugin,
passes personification on nearly every run. Results are written under `evals/results/`, which is
ignored.

On 2026-09-13, with three runs per case, the plugin scored lower than no plugin, by 0.28 on
average. The drafted bodies met the spec's limits about as often in both runs. The gap came from
the reply around the body: every plugin-loaded reply added process notes that were not asked for in
the prompt, such as the lint not running or a delta-log entry, and 7 of 9 of those notes had a
spaced em dash, which fails the regex grader for the whole reply.

Later on 2026-09-13, `ghostwrite` was changed to hand over the body and at most one line after it.
The form and facts judges were also told that notes around the body are not part of it, and the facts
judge now fails a run only when it can state a missing fact or quote an added claim. With three runs
per case, the plugin and no plugin both scored 0.91, a gap of 0.00. No plugin-loaded reply had a
spaced dash, rewrite notes, or a delta-log entry. Each one ended with a one-line note that the lint
did not run, which is expected, since no shell is granted in the cases. Both arms scored 1.00 on the
pruner PR. On the report PR the plugin scored 0.11 higher: all three bodies without the plugin
failed the facts judge, and two of them were missing the fact that `showOutsideRange` is on by
default. On the issue the plugin scored 0.11 lower: all three plugin-loaded bodies failed form, and
two of them had a sentence of prose after the fenced exhibits, which is not allowed under the spec's
issue limit.

Later on 2026-09-13, `ghostwrite` was changed to check the end of a body against the genre's form,
so a fact left after the exhibits goes in a one-fact bullet. With three runs per case, the plugin
scored 0.94 on average and no plugin scored 0.87, a gap of +0.07. On the pruner PR the plugin scored
1.00 and no plugin 0.78, with two replies without the plugin failing on a spaced dash in a closing
note. On the report PR the plugin scored 0.94 and no plugin 0.89. On the issue the plugin scored
0.89 and no plugin 0.94. In two plugin-loaded bodies the version was moved into a bullet, and both
still failed form with three FAIL votes each. Given the same body and criteria by hand, the same
judge model passed both, so the remaining issue gap is most likely judge variance rather than a
closing sentence of prose. In the third plugin-loaded body "Seen on tally 0.9.0." was still on its
own line after the bullets, and that body passed form.

With `--judge-model sonnet` the judge is Sonnet 5.5 from Claude Code 2.1.289 on, so the scores above
are not comparable with a later run. On 2026-10-05, with four runs per case, the plugin scored 0.97
on average and no plugin 0.92, a gap of +0.06. Every plugin-loaded body passed form, but two on the
report PR failed the facts judge. One run without the plugin ended on an API error and is in its
average. A second run that day, after the skills were reworded, scored 0.99 with the plugin and 1.00
without, a gap of -0.01, so no difference between the two was measured.

On 2026-10-07 the README-section case was added, with a limit and a sample for docs in the fixture
spec, and the Procedure section was removed from that spec. With four runs per case, the plugin
scored 0.99 on average and no plugin 0.93, a gap of +0.06. On the new case the plugin scored 1.00
and no plugin 0.82. A subagent rewrote the draft in all 4 runs with the plugin and in none without,
which is one check of seven, and one body without the plugin failed the facts judge. With the
Procedure section still in the spec, a subagent rewrote the draft in every run of that case, with
and without the plugin.

On 2026-10-08, with four runs per case, the plugin scored 1.00 on average and no plugin 0.95, a gap of
+0.05. Most of it was the README-section case (+0.18, five failed checks without the plugin). The PR
body with a report constraint was +0.04. The issue body and `pr-body-in-voice` had no gap, and
`pr-body-in-voice` had none on 2026-10-05 either.

Later on 2026-10-08 the facts in `pr-body-in-voice`, the pruner PR, were rewritten with a spaced
dash, a "whose" after a file, and two personified subjects. With four runs, every body passed every
check with and without the plugin: the prohibitions in the fixture spec are read in both runs, and
they were enough to keep the tells out. The case was removed, which leaves three.

The suite ran in 272 seconds with `-j 4` and 1,047 seconds without it, for the same 32 runs, and the
scores differed by 0.01.

## Works with `writing-conventions`

Neither plugin needs the other. `writing-conventions` loads the prohibitions in every session (no
personified subjects, no spaced em dashes, a banned-word list), and they apply to chat replies too.
This plugin is run on demand to draft in your voice. Installed together, the general rules
that come out of your edits are added to the file that is loaded in every session.
