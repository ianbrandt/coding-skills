---
name: share-ghostwriting-spec
description: >-
  Export the user's voice spec as an anonymized seed another writer can
  bootstrap from: keep the Voice, per-genre caps, and Procedure sections, drop
  the delta log and corpus, scrub identifying content, and show the export for
  the user's explicit go before it is shared. Trigger on "share my voice spec",
  "export my spec", "anonymize my spec", or "make a team spec". NOT for
  drafting text (that's ghostwrite), and never for exporting the corpus or the
  delta log.
---

# Share a ghostwriting spec—anonymized export

The export is a **seed**: house style another writer bootstraps from, not a copy of the user's
voice. The user reviews it before it leaves their machine: **building the export is yours, sharing
it is theirs.**

## 0. Locate the spec
```bash
VOICE=${GHOSTWRITING_DIR:-$HOME/.claude/ghostwriting}
[ -f "$VOICE/voice-spec.md" ] && echo "spec: $VOICE/voice-spec.md" || echo "NO SPEC"
```
No spec ⇒ stop and say so; bootstrap first (ghostwrite §5).

## 1. Select what ships
Start from `voice-spec.md` and keep exactly three sections: **Voice**, the per-genre caps, and
**Procedure**. Match the caps section by what it holds—one entry per genre, giving that genre's
size and form—not by its title. `ghostwrite` §5 names it **Per-genre caps**, and a spec written
before that convention may title it something else.

- **The delta log and the corpus never ship.** Replace the log with an empty one. Sweep the
  dropped log for any rule not yet promoted into the body; carry the rule text over, never an
  entry's exhibits.
- **Caps are house style; voice is personal.** Keep the caps as-is. Mark the Voice section as a
  placeholder the recipient refits from their own samples during bootstrap—a recipient who keeps
  it would be writing as the exporter, not as themselves.

## 2. Scrub the remainder
Check every line that ships against this list, and rewrite or drop what matches:
- person, team, and org names;
- repo, project, and product names;
- URLs and issue/PR references;
- quoted or paraphrased draft text;
- dates or events tied to identifiable work.

A rule that can't be stated without its private referent doesn't ship.

## 3. Review gate
Show the complete export in chat and wait for an explicit go before writing it anywhere shared.
Scrubbing is a first pass; the user's read is the anonymization boundary. Name the destination
before writing to it.

## 4. Seeding a recipient
The recipient runs the ghostwrite bootstrap (§5) with the export as the seed spec: the caps carry
over, the Voice placeholder is refit from their samples, and their delta log starts empty and
diverges from there. One seed can serve a whole team; each writer's spec stays their own.
