# Voice spec

A fixture for the `ghostwrite` eval: an invented maintainer of small developer tools. No real
person's writing is in this file.

## Voice

- Short declarative sentences, one idea each.
- The subject of a sentence is a person, a program doing its runtime job, or the change itself.
- Plain words. The literal name of a thing, never a metaphor for it.
- No hedging on facts that were measured.

## Prohibitions

- Inanimate agency: a file, config, report, option, version, or PR does not say, want, know, decide,
  carry, hold, declare, configure, or own anything, and takes no "whose". Write what happens, or name
  the person or program that does it.
- No spaced em dashes. `word—word`, or a comma, colon, or period.
- Banned words: load-bearing, vacuous, owed, "shape" for a design, "slot" for a field, "channel" for
  a mechanism, de-risk.
- No epigrams and no paired contrasts ("not X but Y").

## Per-genre caps

- **PR body**: one to four sentences of prose, no headings, no bullet list. Open with what the change
  does. A `Fixes #N` line at the end does not count toward the cap.
- **Commit message**: a subject under 60 characters in the imperative; a body only for the reason.

## Contrast pairs

Drafted, then accepted:

- "The config file tells rotor which directories to watch." → "Rotor watches the directories listed
  in the config file."
- "The old option wanted an absolute path, so relative paths silently did nothing." → "The old option
  accepted only an absolute path, and a relative path was ignored without an error."
- "This PR teaches the pruner to respect the retention window the user declared." → "The pruner now
  keeps every archive inside the retention window set in `rotor.toml`."

## Delta log

(empty)

## Procedure

1. Read this spec and a matching corpus sample before drafting.
2. Draft to the genre's cap, imitating the corpus and the contrast pairs.
3. Self-review, have a fresh-context subagent rewrite the draft, check the rewrite, then hand over.
4. After the maintainer edits a draft, log the delta.
