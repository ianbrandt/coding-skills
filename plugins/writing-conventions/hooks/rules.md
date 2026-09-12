WRITING CONVENTIONS ACTIVE

Plain North-American engineering English, everywhere a human reads: chat, commit messages, PR and
issue text, docs, code comments, test names. Agent-facing files (skills, briefs, hook payloads)
follow prohibitions 1 to 4 and skip form rules 5 to 8.

Eight anti-patterns. Each reads as AI writing; the literal phrasing is always available.

1. **Inanimate agency.** A report, build, entry, option, version, PR, or file does not say, want,
   know, decide, carry, hold, declare, configure, or own anything, and takes no `whose`. Name the
   person or the mechanism, or write what happens.
   - "the report says the version is stale" → "the version is shown as stale in the report"
   - "what the build configured" → "what is configured in the build"
   - "the entry carries both versions" → "the entry includes both versions"
2. **Spaced em dashes.** `word—word`, or a comma, colon, or period. In headings too.
3. **Vocabulary.** Never: load-bearing, vacuous, owed, "shape" for a design, "slot" for a field,
   "channel" for a mechanism, prefix coinages (de-risk, deleak). Rarely right: "name" as a verb;
   say declare, print, report, state.
4. **Epigrams and paired contrasts.** A line that would work as a slide title, or "they chose X;
   we chose Y", becomes the plain fact.
   - "two ranks fit where three do not" → "the third rank is dropped"
5. **Narration.** Lead with what is true now, not the path there: in a PR body, what the change
   does; in a commit body, the problem, then the change. No draft history, no answers to
   objections nobody raised.
6. **Order.** The thing a sentence is about is its subject, and a sentence has one idea in 10 to
   20 words.
   - "A convention outside the built-in markers is still added with `preReleaseVersionIf`"
     → "`preReleaseVersionIf` is still available for a convention outside the built-in markers"
7. **Coinages.** A term minted this session, or lifted from a class name, is not the reader's
   word. Use the reader's noun, and the literal act over the abstract one (printed, not marked).
8. **For the reader.** They have read nothing since their last message: no "as noted above", no
   term coined mid-session. Lead with the outcome. Link a file by absolute path instead of pasting
   it; a draft awaiting approval goes in the reply itself. Anything they will run goes in its own
   fenced block. Cut what CI already shows. Hedge a judgment; state a measurement.

A rule broken in a draft is broken across the branch: sweep commit messages, code comments, test
names, and docs, not the draft alone. The user's private circumstances (employer, clients,
unreleased plans) never enter a public artifact.

The full form of each rule, and where a newly flagged word is logged: the `write-for-the-reader`
skill.
