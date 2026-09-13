---
name: ghostwrite
description: >-
  Draft text that ships under the user's name (issues, PRs, comments, commit
  messages, docs, code comments) in their voice, from a voice spec derived from
  their own hand-written samples: read the spec, draft to its caps, self-review,
  and log the delta after the user edits. Derives the spec from samples when the
  user has none. Trigger on drafting or reviewing anything the user will post
  under their name, and on "log the delta" / "update my voice spec". NOT for
  text the assistant signs, and never for retro-editing already-published
  writing.
---

# Ghostwrite—draft in the user's voice

This skill is the method; the voice is the user's own data (§0). The user signs the text, so the
user reads it first: **drafting is yours, posting is theirs.**

## 0. Locate the voice data—and detect the mode
The plugin's `voice_dir` option is substituted into the first line below (empty when the user set
none); then `$GHOSTWRITING_DIR`, then the default.
```bash
VOICE='${user_config.voice_dir}'
VOICE=${VOICE:-${GHOSTWRITING_DIR:-$HOME/.claude/ghostwriting}}
[ -f "$VOICE/voice-spec.md" ] && echo "spec: $VOICE/voice-spec.md" || echo "MODE=bootstrap"
ls "$VOICE/corpus" 2>/dev/null || echo "no corpus"
```
- `$VOICE/voice-spec.md`—voice rules, per-genre caps, delta log, procedure.
- `$VOICE/corpus/`—hand-written samples, one file per piece or genre.

Either path may be a symlink into a private repo. The voice data never lives in this skill, in a
project repo, or in memory. No spec ⇒ **bootstrap** (§5).

**Always-on rules live elsewhere, split by when they load.** Prohibitions that must hold in chat
replies too—typography, formatting tells, banned vocabulary—live in an always-on rules file that
loads every session: the `writing-conventions` plugin's `hooks/rules.md` when that plugin is
installed, or the user's global `CLAUDE.md` (`~/.claude/CLAUDE.md`) when they keep them there
instead. Check which of those loaded in this session, and follow a pointer rather than assuming a
file; `voice-spec.md` is the positive spec, read on demand. Both are maintained here (§4, §5). With
no always-on file at all, the prohibitions go in the spec too.

## 1. Read the spec before drafting
Read `voice-spec.md` end to end, delta log included, and read two or three corpus samples matching
the genre—as models to imitate, not background.
A summary carried in context is not the spec; re-read it per session. No corpus, or no sample for
the genre ⇒ draft on the spec alone and record the gap in §4.

**Re-read the always-on rules file §0 names in the same pass**, even though it loaded at session
start: by drafting time that copy sits far back in the context, where it is weakly attended, and
most rule breaks happen deep in long sessions. Reading it again immediately before drafting puts
the prohibitions where they bind.

This also governs **reviewing** a draft—carried over from an earlier session, written by another
agent, or by you hours ago. Calling a draft ready is drafting.

## 2. Draft to the spec
Write to the spec's entry for the genre—its form and size. No entry ⇒ use the nearest neighbor
and record the gap in §4. **Caps are caps, not targets**: exceed one only when the content forces it,
never for thoroughness. A fact the user gave always forces it: never drop a given fact to fit a cap.
Keep the fact, and use the hand-over line (§3) to say which part runs over. Everything else about the
draft comes from the spec, not your defaults.

**Imitate, then check.** Draft by matching the corpus samples and the spec's **Contrast pairs**,
sentence rhythm included, and only then check the rule list for what imitation missed. Text written
to match the user's own sentences lands the register more reliably than text written from
prohibitions; a draft written from the rule list alone drifts back to the default register.

## 3. Self-review, rewrite, lint, then hand it over
Check the draft against the spec rule by rule and fix what you broke **before** the user sees it; a
rule you broke and fixed yourself still goes to §4 as a procedure failure, recorded when §4 runs.

Self-review is not enough for register tells: you re-read your own draft with the same tendency
that produced it, and its tells read as natural. A report of violations is not enough either, since
each fix comes from that same tendency, and rounds of find-and-fix rarely converge. So before the
first hand-over of a piece, **have a fresh-context subagent rewrite it**. Give the subagent nothing
but the draft verbatim, the always-on rules file §0 names (or the spec's prohibitions when there is
none), the spec's **Contrast pairs** section verbatim, the genre's cap, and this brief:

> Rewrite the draft so it breaks none of the rules, imitating the right-hand side of each contrast
> pair. For every sentence, find the subject and check its verb against the inanimate-agency rule;
> replace a noun that stands in for a thing as a metaphor with the thing's literal name; fix dashes
> and banned words. Keep every fact, number, name, link, code span, and fenced block as given, and
> add nothing. Stay inside the cap, unless that means dropping a fact; then keep the fact. Return only
> the rewritten text.

Pick a mid-tier model over the smallest: writing text without the tells is harder than spotting them
in given text. Then check the rewrite before you adopt it:

1. **Diff it against your draft for meaning.** Restore any fact the rewrite dropped or changed, and
   remove anything it added.
2. **Run the lint over it**, because tells survive a rewrite. With `writing-conventions` installed,
   its `lint.awk` prints one line per flagged sentence, and prints nothing for clean text:
   ```bash
   LINT=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/writing-conventions/*/hooks/lint.awk 2>/dev/null | sort -V | tail -1)
   [ -n "$LINT" ] && awk -f "$LINT" "$DRAFT" || echo "no lint installed"   # $DRAFT: a scratch file holding the rewrite
   ```
   Fix a real hit by hand, in place, and leave a false positive alone. Don't send the text back for
   another rewrite round. With no lint installed or no shell, use the hand-over line to say the
   lint did not run.

Each rule break the rewrite or the lint fixed is a §4 procedure failure. Re-run the rewrite only
after substantive redrafting. For a draft of a sentence or two, skip the rewrite but still run the
lint.

Then hand it over: the body exactly as asked, and nothing else. At most one line may follow it, and
only to say that a check did not run, to ask a question that must be settled before posting, or to
say which part runs over a cap (§2). That line follows the spec's prohibitions too. No rewrite notes,
no draft history, no delta-log entries: those wait for §4. Then wait for an explicit go. A question
about scope or wording is the review happening, not its conclusion.

## 4. Log the delta
§4 runs once per piece, after the user edits the draft or gives the go, and never inside the
hand-over. Diff their version against yours, add the rule breaks you fixed yourself in §3, and
**classify each change first**; the two failures take opposite fixes:

- **Missing rule**—the spec didn't cover it. Append a delta-log entry: date, the piece, what you
  wrote, what they changed it to, and the rule that generalizes. Name any entry it amends or
  supersedes.
- **Procedure failure**—the spec covered it and the draft broke it anyway. Record it as one; add
  **no** new rule.

Route each new rule by the §0 split: must hold in every response ⇒ the always-on file §0 names;
genre form or size ⇒ `voice-spec.md`. When that always-on file ships from a plugin, the edit is a
plugin change: make it in the repo the plugin is published from, not the installed cache, and bump
the plugin's `version` in that repo's `.claude-plugin/marketplace.json` in the same commit, or the
installed session keeps serving the old list. When
an entry changes a standing rule, promote it into the spec's body—the log grows, the body stays
stable.

A failure that **recurs** gets a second promotion: into the spec's **Contrast pairs** section, as
the drafted sentence and the user's rewrite, verbatim. The pairs are what §2 imitates. The tendency
that produced the draft reads the rule-breaking form as natural, so an example of the idiomatic
alternative prevents the next instance better than the generalized rule alone.

Log only what recurs or would recur, and don't paste diffs.

## 5. Bootstrap—derive a spec from samples
The one attended path: **ask (AskUserQuestion) about anything that isn't obvious** rather than
guessing. One-time setup; afterwards proceed from §1.

1. **Ask where the hand-written samples are** and which genres to cover. Samples must be the
   user's own unassisted writing.
2. **Collect them into `$VOICE/corpus/`** by copy or symlink. Never rewrite a sample.
3. **Extract observable regularities**, per genre: sentence length and structure, person and
   hedging, how evidence is carried, openings and closings, formatting habits (headings, bullets,
   emphasis, links), title style, and typical length. Sort each finding by the §0 split as you go.
4. **Write `voice-spec.md`** with five sections: **Voice** (cross-genre rules), **Per-genre caps**
   (one entry per genre, size and form), **Contrast pairs** (seeded with one before→after pair
   contrasting a default-register draft with the samples), **Delta log** (starts empty), and
   **Procedure** (§1–§4 in a line each, so the spec stands alone).
5. **Route the always-on rules** the samples imply: the step-3 prohibitions belong in the always-on
   file §0 names, which already includes the typography and banned-vocabulary rules when it is the
   `writing-conventions` file—add only what it lacks. With no always-on file, they go in the spec's
   own prohibitions section. Show any edit and ask before making it, and where the file ships from a
   plugin, bump its `version` in that repo's `.claude-plugin/marketplace.json` in the same commit.
6. **Say what you could not derive.** A genre with no sample gets no entry—don't invent one.

A **seed spec**—a `share-ghostwriting-spec` export—replaces derivation from scratch: copy it in as
the starting `voice-spec.md`, keep its per-genre caps, refit its Voice placeholder from the user's
samples (steps 1–3), and note in the delta log any seed rule the samples contradict.

One spec describes one person; don't blend samples from several writers.
