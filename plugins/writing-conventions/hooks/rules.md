WRITING CONVENTIONS ACTIVE

Plain North-American engineering English, everywhere a human reads: chat, commit messages, PR and
issue text, docs, code comments, test names. Agent-facing files (skills, briefs, hook payloads)
follow prohibitions 1 to 4 and skip form rules 5 to 9.

Nine anti-patterns. Each reads as AI writing; the literal phrasing is always available.

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
2. **Punctuation.** No spaced em dashes: `word—word`, or a comma, colon, or period. In headings
   too. A list of three or more items takes a comma before the final "and" or "or", in log
   messages and code comments too.
   - "json, xml, html and plain" → "json, xml, html, and plain"
3. **Vocabulary.** Never: load-bearing, vacuous, owed, "shape" for a design, "slot" for a field,
   "channel" for a mechanism, prefix coinages (de-risk, deleak). Rarely right: "name" as a verb;
   say declare, print, report, state. No intensifiers: "Gradle's own" is "Gradle's".
4. **Epigrams and paired contrasts.** A line that would work as a slide title, or "they chose X;
   we chose Y", becomes the plain fact.
   - "two ranks fit where three do not" → "the third rank is dropped"
5. **Narration.** Lead with what is true now, not the path there: in a PR body, what the change
   does; in a commit body, the problem, then the change. No draft history, no answers to
   objections nobody raised.
6. **Order.** The thing a sentence is about is its subject, and a sentence has one idea in 10 to
   20 words. A clause that reverses the one before it takes "but"; "and" hides the reversal.
   - "A convention outside the built-in markers is still added with `preReleaseVersionIf`"
     → "`preReleaseVersionIf` is still available for a convention outside the built-in markers"
   - "the settings are inherited within a build, and none of them reach an included build"
     → "the settings are inherited within a build, but none of them reach an included build"
7. **Coinages.** A term minted this session, or lifted from a class name, is not the reader's
   word. Use the reader's noun, and the literal act over the abstract one (printed, not marked).
8. **For the reader.** They have read nothing since their last message: no "as noted above", no
   term coined mid-session, and every "it" and "this" resolves to one named thing (the noun, or
   "this PR" when there is none). Lead with the outcome. Link a file by absolute path instead of
   pasting it; a draft awaiting approval goes in the reply itself. Anything they will run goes in
   its own fenced block. Cut what CI already shows. Hedge a judgment; state a measurement.
9. **Say it once.** A fact stated as a mechanism is not restated as its consequence, and a reason
   given in one sentence gets no justification clause in the next.
   - "the entry is dropped because nothing in the build requires it, so it no longer appears"
     → "the entry is dropped because nothing in the build requires it"

A rule broken in a draft is broken across the branch: sweep commit messages, code comments, test
names, and docs, not the draft alone. The user's private circumstances (employer, clients,
unreleased plans) never enter a public artifact.

A draft for publication—any text the user will paste, post, send, or file somewhere else—goes in
its own fenced block with the info string `draft`, even mid-task, and in a longer fence when the
draft itself holds one. Nothing else takes that info string. A draft written to a file goes through
`Write` or `Edit`, never a shell redirect.

The full form of each rule, and where a newly flagged word is logged: the `write-for-the-reader`
skill.
