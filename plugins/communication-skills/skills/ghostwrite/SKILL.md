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
```bash
VOICE=${GHOSTWRITING_DIR:-$HOME/.claude/ghostwriting}
[ -f "$VOICE/voice-spec.md" ] && echo "spec: $VOICE/voice-spec.md" || echo "MODE=bootstrap"
ls "$VOICE/corpus" 2>/dev/null || echo "no corpus"
```
- `$VOICE/voice-spec.md`—voice rules, per-genre caps, delta log, procedure.
- `$VOICE/corpus/`—hand-written samples, one file per piece or genre.

Either path may be a symlink into a private repo. The voice data never lives in this skill, in a
project repo, or in memory. No spec ⇒ **bootstrap** (§5).

**Always-on rules live elsewhere, split by when they load.** Prohibitions that must hold in chat
replies too—typography, formatting tells, banned vocabulary—live in this plugin's `hooks/rules.md`,
which loads every session, or in the user's global `CLAUDE.md` (`~/.claude/CLAUDE.md`) when they
keep them there instead. Check the plugin file first, and follow a pointer rather than assuming a
file; `voice-spec.md` is the positive spec, read on demand. Both are maintained here (§4, §5).

## 1. Read the spec before drafting
Read `voice-spec.md` end to end, delta log included, and read two or three corpus samples matching
the genre—as models to imitate, not background.
A summary carried in context is not the spec; re-read it per session. No corpus, or no sample for
the genre ⇒ draft on the spec alone and flag the gap in §3.

**Re-read the always-on rules file §0 names in the same pass**, even though it loaded at session
start: by drafting time that copy sits far back in the context, where it is weakly attended, and
most rule breaks happen deep in long sessions. Reading it again immediately before drafting puts
the prohibitions where they bind.

This also governs **reviewing** a draft—carried over from an earlier session, written by another
agent, or by you hours ago. Calling a draft ready is drafting.

## 2. Draft to the spec
Write to the spec's entry for the genre—its form and size. No entry ⇒ use the nearest neighbor
and flag the gap in §3. **Caps are caps, not targets**: exceed one only when the content forces it,
never for thoroughness. Everything else about the draft comes from the spec, not your defaults.

**Imitate, then check.** Draft by matching the corpus samples and the spec's **Contrast pairs**,
sentence rhythm included, and only then check the rule list for what imitation missed. Text written
to match the user's own sentences lands the register more reliably than text written from
prohibitions; a draft written from the rule list alone drifts back to the default register.

## 3. Self-review, then hand it over
Check the draft against the spec rule by rule and fix what you broke **before** the user sees it; a
rule you broke and fixed yourself still goes to §4 as a procedure failure. Then show the draft in
chat and wait for an explicit go. A question about scope or wording is the review happening, not
its conclusion.

## 4. Log the delta
After the user edits a draft—or after a §3 self-correction—diff their version against yours and
**classify each change first**; the two failures take opposite fixes:

- **Missing rule**—the spec didn't cover it. Append a delta-log entry: date, the piece, what you
  wrote, what they changed it to, and the rule that generalizes. Name any entry it amends or
  supersedes.
- **Procedure failure**—the spec covered it and the draft broke it anyway. Record it as one; add
  **no** new rule.

Route each new rule by the §0 split: must hold in every response ⇒ the always-on file §0 names—this
plugin's `hooks/rules.md`, which makes the edit a plugin change—made in the marketplace repo the
plugin ships from, not the installed cache, bumping the plugin `version` in that repo's
`.claude-plugin/marketplace.json` in the same commit—or the user's global file when they keep the
rules there; genre form or size ⇒ `voice-spec.md`. When an entry changes a standing rule,
promote it into the spec's body—the log grows, the body stays stable.

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
5. **Route the always-on rules** the samples imply: the step-3 prohibitions belong in this plugin's
   `hooks/rules.md`, which already loads every session and already carries the typography and
   banned-vocabulary rules—add only what it lacks. Add a pointer to `$VOICE` there when it isn't the
   default. Show any edit and ask before making it, and bump the plugin `version` in the same
   commit.
6. **Say what you could not derive.** A genre with no sample gets no entry—don't invent one.

A **seed spec**—a `share-ghostwriting-spec` export—replaces derivation from scratch: copy it in as
the starting `voice-spec.md`, keep its per-genre caps, refit its Voice placeholder from the user's
samples (steps 1–3), and note in the delta log any seed rule the samples contradict.

One spec describes one person; don't blend samples from several writers.
