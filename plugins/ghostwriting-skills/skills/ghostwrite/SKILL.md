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
replies too—typography, formatting tells, banned vocabulary—go wherever the user's always-on
instructions live: their global `CLAUDE.md` (`~/.claude/CLAUDE.md`), or a plugin that injects rules
every session. Follow the pointer rather than assuming a file; `voice-spec.md` is the positive
spec, read on demand. Both are maintained here (§4, §5).

## 1. Read the spec before drafting
Read `voice-spec.md` end to end, delta log included, and skim one corpus sample matching the genre.
A summary carried in context is not the spec; re-read it per session. No corpus, or no sample for
the genre ⇒ draft on the spec alone and flag the gap in §3.

This also governs **reviewing** a draft—carried over from an earlier session, written by another
agent, or by you hours ago. Calling a draft ready is drafting.

## 2. Draft to the spec
Write to the spec's entry for the genre—its shape and size. No entry ⇒ use the nearest neighbor
and flag the gap in §3. **Caps are caps, not targets**: exceed one only when the content forces it,
never for thoroughness. Everything else about the draft comes from the spec, not your defaults.

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

Route each new rule by the §0 split: must hold in every response ⇒ the always-on file §0 names (show the
edit and ask first); genre shape or size ⇒ `voice-spec.md`. When an entry changes a standing rule,
promote it into the spec's body—the log grows, the body stays stable.

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
4. **Write `voice-spec.md`** with four sections: **Voice** (cross-genre rules), **Per-genre caps**
   (one entry per genre, size and shape), **Delta log** (seeded with one contrast entry naming how
   a default-register draft differs from the samples), and **Procedure** (§1–§4 in a line each, so
   the spec stands alone).
5. **Draft the always-on block** for the user's always-on instructions: the step-3 prohibitions plus a
   pointer to this skill (and `$VOICE` when it isn't the default). Show the block and ask before
   editing.
6. **Say what you could not derive.** A genre with no sample gets no entry—don't invent one.

A **seed spec**—a `share-ghostwriting-spec` export—replaces derivation from scratch: copy it in as
the starting `voice-spec.md`, keep its per-genre caps, refit its Voice placeholder from the user's
samples (steps 1–3), and note in the delta log any seed rule the samples contradict.

One spec describes one person; don't blend samples from several writers.
