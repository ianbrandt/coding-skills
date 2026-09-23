WRITING CONVENTIONS ACTIVE

Plain North-American engineering English, everywhere a human reads: chat, commit messages, PR and
issue text, docs, code comments, test names. Agent-facing files (skills, briefs, hook payloads)
follow prohibitions 1 to 4 and skip form rules 5 to 11.

Eleven anti-patterns. Each reads as AI writing; the literal phrasing is always available.

1. **Inanimate agency.** A report, build, entry, option, version, PR, or file does not say, want,
   know, decide, carry, hold, declare, configure, or own anything, and takes no `whose`. Name the
   person or the mechanism, or write what happens. A passive written to satisfy this rule still
   has to be a phrase a person would say on one read. Rebuild the sentence around the observable
   effect.
   - "the report says the version is stale" → "the version is shown as stale in the report"
   - "what the build configured" → "what is configured in the build"
   - "the entry carries both versions" → "the entry includes both versions"
   - "a module is held to the version its platform fixes"
     → "versions outside a platform's constraints are no longer reported"
   - "a build already on a pre-release is still shown newer ones"
     → "newer pre-releases are still reported when the current version is itself a pre-release"
2. **Mechanics.** No spaced em dashes: `word—word`, or a comma, colon, or period. In headings
   too. A list of three or more items takes a comma before the final "and" or "or", in log
   messages and code comments too. Units stay consistent and idiomatic across a piece: `1m5s` and
   `65s` in one table is what makes a set of timings hard to read.
   - "json, xml, html and plain" → "json, xml, html, and plain"
3. **Vocabulary.** Never: load-bearing, vacuous, owed, "shape" for a design, "slot" for a field,
   "channel" for a mechanism, prefix coinages (de-risk, deleak), a deferential frame around a
   question ("worth your ruling", "I'd defer to you on", "your call"), or a judgment stood in for
   a mechanism's name ("nag" for a deprecation warning). An open question takes a question mark.
   Rarely right: "name" as a verb; say declare, print, report, state. No intensifiers: "Gradle's
   own" is "Gradle's". Rewrite the clause rather than swapping in a synonym.
4. **Epigrams and paired contrasts.** A line that would work as a slide title, or "they chose X;
   we chose Y", becomes the plain fact.
   - "two ranks fit where three do not" → "the third rank is dropped"
5. **Narration.** Lead with what is true now, not the path there: in a PR body, what the change
   does; in a commit body, the problem, then the change. No draft history, no answers to
   objections nobody raised.
6. **Order.** The thing a sentence is about is its subject, and a sentence has one idea in 10 to
   20 words. A clause that reverses the one before it takes "but"; "and" hides the reversal.
   - "A custom port can still be set with `server.port`"
     → "`server.port` is still available for a custom port"
   - "the cache is shared between runs on one machine, and none of it reaches a CI agent"
     → "the cache is shared between runs on one machine, but none of it reaches a CI agent"
7. **Coinages.** A term minted this session, or lifted from a class name, is not the reader's
   word. Use the reader's noun, and the literal act over the abstract one (printed, not marked).
   Take the noun a target document already uses for a concept, take none of its phrasing, and fix
   an inherited construction at its source rather than copying it forward.
8. **For the reader.** They have read nothing since their last message: no "as noted above", no
   term coined mid-session, and every "it" and "this" resolves to one named thing (the noun, or
   "this PR" when there is none). Lead with the outcome, and write the point rather than leaving
   the reader to assemble it from the facts. Link a file by absolute path instead of pasting it;
   a draft awaiting approval goes in the reply itself. Anything they will run goes in its own
   fenced block. A list of findings takes no bold, and a fact placed first needs no marking.
   Emphasis elsewhere, bold or italic, is rare and kept for what strongly warrants calling out:
   none of it survives in plain text, it is overused in rendered text, and reaching for it often
   means the phrasing needs work. A set they have not met takes the bare plural, "defects found
   in a review", not "the defects", and a thing they have not seen is written out rather than
   pointed at.
9. **Say it once.** A fact stated as a mechanism is not restated as its consequence, and a reason
   given in one sentence gets no justification clause in the next.
   - "the entry is dropped because nothing in the build requires it, so it no longer appears"
     → "the entry is dropped because nothing in the build requires it"
10. **Evidence.** Cut what the reader can already see, such as an all-green test summary where CI
    reports the same verdict, or a walkthrough of a diff in the same reply. A local result CI
    will not show is worth stating. Hedge a judgment, state a measurement, and check before
    hedging: run history, merged PRs, and a commit log are all measurable from outside, so a
    question about one of those spends the reader's attention on your homework. A claim reused
    from the repo gets checked like one you wrote, and a draft already approved gets re-checked
    against anything found after it.
11. **Err short.** A code comment, a commit message, an issue, and a PR body are short by
    default. Every extra paragraph is paid for three times, in the tokens spent producing it, in
    the reader's attention, and in the correction round when they ask for it to be cut, and where
    an agent writes most of the text that attention is the limit on how much work a human stays
    on top of. Write the shortest version with every fact the reader needs still in it, and cut
    when unsure, since asking for more costs one sentence. A true fact they do not need is cut too,
    such as an aside that a change is not in a release yet. Short is relative to the change: a
    one-sentence body on a large, complex PR fails this as surely as a twenty-sentence body on a
    small one. A heading or a bullet changelog in a commit message, an issue, or a PR body usually
    means the text outgrew its genre rather than that it needed organizing, and long enough to need
    headings should be the rare exception, not the norm. Where the content really is that long, cut
    first and structure what is left: twenty paragraphs read better under headings, and more than a
    few parallel items read better as bullets.

A rule broken in a draft is broken across the branch: sweep commit messages, code comments, test
names, and docs, not the draft alone. The user's private circumstances (employer, clients,
unreleased plans) never enter a public artifact.

A draft for publication—any text the user will paste, post, send, or file somewhere else—goes in
its own fenced block with the info string `draft`, even mid-task, and in a longer fence when the
draft itself holds one. Nothing else takes that info string. A draft written to a file goes through
`Write` or `Edit`, never a shell redirect.

The full form of each rule, and where a newly flagged word is logged: the `write-for-the-reader`
skill.
