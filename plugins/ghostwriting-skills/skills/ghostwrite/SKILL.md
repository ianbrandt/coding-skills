---
name: ghostwrite
description: >-
  Draft text that ships under the user's name—issues, PRs, comments, commit
  messages, docs, code comments—in their voice, working from a voice spec
  derived from their own hand-written samples. Read the spec first, draft to its
  caps, self-review, and after the user edits a draft, classify and log the
  delta. Derives a spec from samples when the user has none. Trigger on drafting
  or reviewing anything the user will post under their name, and on "log the
  delta" / "update my voice spec". NOT for text the assistant signs, and never
  for retro-editing already-published writing.
---

# Ghostwrite—draft in the user's voice

Engine and data are separate. This skill is the method; the voice is the user's own data (§0),
theirs to grow. The user signs the text, so the user reads it first: **drafting is yours, posting is
theirs.**

## 0. Locate the voice data—and detect the mode
```bash
VOICE=${GHOSTWRITING_DIR:-$HOME/.claude/ghostwriting}
[ -f "$VOICE/voice-spec.md" ] && echo "spec: $VOICE/voice-spec.md" || echo "MODE=bootstrap"
ls "$VOICE/corpus" 2>/dev/null || echo "no corpus"
```
- `$VOICE/voice-spec.md`—voice rules, per-genre caps, delta log, procedure.
- `$VOICE/corpus/`—hand-written samples, one file per piece or genre; filenames free.

Either path may be a symlink into a private repo, which keeps the voice under version control while
still answering at the default location. The voice data never lives in this skill, in a project
repo, or in memory. No spec ⇒ **bootstrap** (§5).

**The voice has a third file, and the split is by when it loads.** Always-on prohibitions—banned
vocabulary, typography, formatting tells, anything that must hold in chat replies too—live in the
user's global `CLAUDE.md` (`~/.claude/CLAUDE.md`), loaded into every session whether or not this
skill runs. `voice-spec.md` is the positive spec, read on demand. Both are in scope here (§4, §5);
only their file differs.

## 1. Read the spec before drafting
Read `voice-spec.md` end to end, delta log included, and skim one corpus sample matching the genre.
A summary carried in context is not the spec; re-read it per session.

This also governs **reviewing** a draft—one carried over from an earlier session, written by another
agent, or written by you hours ago. Calling a draft ready is drafting.

## 2. Draft to the spec
Find the spec's entry for the genre you're writing and write to that entry's shape and size. No
entry for the genre ⇒ use the nearest neighbor and flag the gap in §3.

**Caps are caps, not targets.** Exceed one only when the content forces it, never for thoroughness.
Everything else about the draft comes from the spec, not from your defaults.

## 3. Self-review, then hand it over
Check the draft against the spec rule by rule and fix what you broke **before** the user sees it.
Then show it in chat and wait for an explicit go. A question about scope or wording is the review
happening, not its conclusion.

A rule you broke and fixed yourself still happened: carry it to §4 as a procedure failure.

## 4. Log the delta
After the user edits a draft—or after a self-correction in §3—diff their version against yours and
**classify each change before writing anything**, because the two failures take opposite fixes:

- **Missing rule**—the spec didn't cover it. Append a delta-log entry: date, the piece, what you
  wrote, what they changed it to, and the rule that generalizes. Name the entry it amends or
  supersedes if it touches one.
- **Procedure failure**—the spec already covered it and the draft broke it anyway. Record it as one,
  and add **no** new rule. Adding rules to fix a spec that wasn't read makes the file longer and the
  problem worse.

**Then route it to the right file.** A rule that must hold in *every* response, chat included, goes
in the global `CLAUDE.md`; a rule about a genre's shape or size goes in `voice-spec.md`. A
prohibition parked in the spec alone fires only when the spec is read—the exact case the procedure
failure above describes. Show the `CLAUDE.md` edit and ask before making it; that file loads into
every session and it's the user's.

Don't paste diffs; most of a first-to-final diff is one-off content churn. When an entry changes a
standing rule, promote it into the spec's body—the log grows, the body stays stable.

Log only what recurs or would recur. A one-off content fix is not a rule.

## 5. Bootstrap—derive a spec from samples
The one attended path: **ask (AskUserQuestion) about anything that isn't obvious** rather than
guessing. One-time setup; afterwards proceed from §1.

1. **Ask where the hand-written samples are** and which genres to cover. Samples must be the user's
   own unassisted writing—anything you or another model touched teaches the wrong voice.
2. **Collect them into `$VOICE/corpus/`** by copy or symlink. Never rewrite a sample.
3. **Read them all and extract observable regularities**, per genre: sentence length and structure,
   person and hedging, how evidence is carried, openings and closings, formatting habits (headings,
   bullets, emphasis, links), title style, and typical length. Sort each finding by the §0 split as
   you go—a positive shape rule, or an always-on prohibition.
4. **Write `voice-spec.md`** with four sections: **Voice** (rules holding across genres), **Per-genre
   caps** (one entry per genre, size and shape), **Delta log** (seeded with one contrast entry naming
   how a default-register draft differs from the samples), and **Procedure** (§1–§4 in a line each,
   so the spec stands alone).
5. **Draft the always-on half for the global `CLAUDE.md`**: the prohibitions from step 3, plus the
   pointer that sends future sessions here (this skill, and `$VOICE` when it isn't the default).
   Show the block and ask before editing that file.
6. **Say what you could not derive.** A genre with no sample gets no entry—don't invent one.

One spec describes one person. Don't blend samples from several writers into a single voice.
