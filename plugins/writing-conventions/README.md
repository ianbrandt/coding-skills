# writing-conventions

A [Claude Code](https://claude.ai/code) plugin for how an agent writes. Its main product is a short
set of always-on rules (plain engineering English, free of AI tells, replies a cold reader can follow)
injected at the start of every session and every subagent, so they bind without anyone invoking a
skill.

Every rule in that list arrived the same way: a specific draft came back wrong, and the correction
became a rule. `write-for-the-reader` is where a word you flag gets logged into the list. The
`ghostwriting-skills` plugin, which drafts text that ships under your name, routes the general rules
it learns from your edits into the same file when this plugin is installed.

## What loads every session

A `SessionStart` hook injects [`hooks/rules.md`](hooks/rules.md) into every session, including
after `/clear`, compaction, and a fork. A `SubagentStart` hook injects the same file into every
subagent through [`hooks/rules-context.sh`](hooks/rules-context.sh), since a subagent's report is
what a later summary is built from. The file is eight named
anti-patterns, one line and one drafted-to-accepted pair each: inanimate agency, punctuation
(spaced em dashes and the Oxford comma), a banned-vocabulary list, epigrams and paired contrasts,
narration, sentence order, coinages, and writing for a reader who has read nothing since their last message. Three standing rules follow: a
rule broken in a draft is swept across the branch, the user's private circumstances stay out
of public artifacts, and a draft for publication goes in a fenced block with the info string
`draft`, which is what the `Stop` reader below looks for. It runs about 620 words, so it costs
roughly 800 tokens per session and per subagent, down from about 1,600 words; the reasoning behind each rule, and its edge cases, sit in `write-for-the-reader` §8
and load only when that skill does.

Prohibitions bind everywhere, `SKILL.md` files included, because they are about precision rather
than register. Form rules—bold, redundancy, length, the reader-facing voice—stop at the
agent-facing line, so those files are formatted for whatever a model reads best.

[`hooks/lint.sh`](hooks/lint.sh) runs on both ends of a turn, in bash and awk with no other
dependency. A `Stop` hook runs it with `--record` over the final reply and saves what it finds; a
`UserPromptSubmit` hook runs it with `--emit`, which opens the next turn with those hits and a
one-line reminder, then clears them; a `PostToolUse` hook on `Write` and `Edit` runs `--nudge`,
which asks for a re-read when the file just written is prose, or is a source file with comments and
test names in it (`.md`, `.markdown`, `.txt`, `.kt`, `.kts`, `.java`, `.groovy`, in any letter case).
The lint itself is [`hooks/lint.awk`](hooks/lint.awk), a pure filter over text.

[`hooks/lint.ps1`](hooks/lint.ps1) is the same three modes and the same lint in one PowerShell file,
for a Windows install where the PowerShell tool is the shell; `ConvertFrom-Json` there replaces
[`hooks/jsonstr.awk`](hooks/jsonstr.awk). The two matchers are held together by
[`hooks/lint-corpus.tsv`](hooks/lint-corpus.tsv), 97 cases read by both
[`hooks/lint-test.sh`](hooks/lint-test.sh) and [`hooks/lint-test.ps1`](hooks/lint-test.ps1), so a
change to one matcher and not the other fails a test. On every one of those cases the two agreed
byte for byte, reported example text included, when the port landed. The `.ps1` files are ASCII, with
every em dash and curly quote written as a `\uXXXX` regex escape, because Windows PowerShell 5.1
reads a BOM-less file through the ANSI codepage and one pasted em dash corrupts string parsing.

It flags the mechanically detectable subset of the rules: the banned vocabulary, spaced em dashes,
a missing Oxford comma in a list of single words, and an inanimate subject paired with a verb of
speech, volition, or cognition. The Oxford comma check needs two commas before the final "and" or
"or", because a one-comma list ("a, b and c") matches too many ordinary clauses. The agency set is
deliberately narrow. An earlier version also matched possession verbs (holds, carries, keeps) and
scored about 40% precision on a hand-checked sample, mostly on code mechanics such as a map that
holds a value; the current set trades recall for a hit the model can act on.

The lint never blocks, and that is the whole design. A `Stop` hook cannot patch a reply, so
blocking one buys a corrected answer at the price of re-emitting the entire original, which you
have already read and which stays in the transcript beside it. Carrying the hits into the next turn
costs a few dozen tokens instead, and the flagged reply stands as sent.

Each line of the note ends with the rule that line is about, because a note with only the
pattern in it, deferring to "the rules loaded at session start" measured no better than sending nothing:
across six two-turn trials per arm, no note left 6 of 6 next replies dirty, the deferring note left
5 of 6 dirty, and the same mechanism with the rule stated inline left 0 of 6 dirty. Literal senses
stay ("a Slack channel", "an array shape"), text inside code fences, backticks, and double quotes is
never matched, and a clean reply clears whatever the previous one left pending. Rules that need
judgment to detect stay where they were, in the model's own review passes; the lint is the floor
under them, and a construction it cannot match mechanically is still a violation.

## Which shell runs the hooks

Each of the four command hooks is registered twice, once as a bash script and once as a PowerShell
one, and [`hooks/shell-owner.ps1`](hooks/shell-owner.ps1) is the test that keeps exactly one of each
pair emitting. PowerShell takes the hook on Windows when `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`, the
same setting that makes the PowerShell tool the session's shell, or when there is no Git Bash to run
the bash script; bash takes it everywhere else, and the mirror of that test sits in the `.sh` files.
The `defaultShell` setting is not the switch, since it governs input-box `!` commands rather than
hooks, and the environment variable is what reaches a hook process.

Git Bash's presence is read off the `git` install rather than from a `bash` on the `PATH`. Git for
Windows leaves `bash.exe` in `bin\`, which is not on the `PATH` at all, and the `bash` that is on the
`PATH` is WSL, under two names, which cannot run a hook against a Windows path.

The PowerShell side is registered as `pwsh` with an argument list rather than as a shell command, so
no quoting is involved and a box without PowerShell 7 fails to launch it and falls back to bash. That
failure is silent: on a macOS install with no `pwsh`, nothing reaches the session. Windows PowerShell
5.1 never runs a hook, since only `pwsh` is registered; the scripts stay 5.1-clean so the self-test
runs there. A Windows box with neither PowerShell 7 nor Git Bash gets no command hook at all. The
`SessionStart` rules load either way, since that hook is a plain `cat`.

## The gate at publication

The census behind this plugin found that 101 of 107 corrections landed on text that ships: PR
bodies, comments, issue bodies, commit messages, docs. A lint over chat never sees those, so a
`PreToolUse` hook watches the commands that publish them: `git commit` and every `gh pr`,
`gh issue`, and `gh release` subcommand, through the `Bash` tool and through the `PowerShell` tool
both. Covering only `Bash` leaves every commit ungated on a Windows session where the PowerShell tool
is the shell. [`hooks/gate.sh`](hooks/gate.sh) and [`hooks/gate.ps1`](hooks/gate.ps1) hand the command
to a model, which pulls out the commit message or the title and body and checks that text against the
four prohibitions: inanimate agency, punctuation (spaced em dashes and the Oxford comma), the banned
words, and epigrams. Form and
length are never judged. The model replies `PASS`, `SKIP` for a command that publishes nothing new
(`gh pr view`, `gh pr checks`, `--amend --no-edit`, a label change), or `VIOLATION` with one line per
offending sentence: the quoted words, then a plain rewrite. A body read from a file path is not in
the command, so it is not checked.

[`hooks/verdict.awk`](hooks/verdict.awk) and [`hooks/verdict.ps1`](hooks/verdict.ps1) look for each
quote in the command, with runs of whitespace collapsed. A finding with its quote in the command
comes back as the tool's error, and the session fixes the text and runs the command again. A reply in any other
form lets the command through, as a failed call does, because the text the model reads can quote an
untrusted source.

The check runs as one nested `claude -p --safe-mode --tools=` call, with
[`hooks/gate-prompt.md`](hooks/gate-prompt.md) as the system prompt and the hook input as the
message. [`hooks/rules.md`](hooks/rules.md) is appended to that prompt, so a word added to the rules
is checked at the gate with no second edit. Which model answers comes from `WRITING_CONVENTIONS_GATE_MODEL`, or from the `sonnet` alias
when that is unset; set it in the `env` block of a settings file to any id the session's endpoint
serves.

An alias is enough there because `--model` resolves one through `ANTHROPIC_DEFAULT_SONNET_MODEL` and
friends, so the default holds on a first-party install and on a LiteLLM proxy in front of Bedrock or
Vertex alike. That is the reason the check runs out in a script rather than in a prompt-type hook,
where the `model` field resolves nothing: `"model": "sonnet"` there reaches the API verbatim, a proxy
answers HTTP 400 `Invalid model name passed in model=sonnet`, and Claude Code logs
`unrecognized_model` with `query_source: hook_prompt`. Since that field is a free-form string checked
at call time rather than at load time, the only symptom was a hook error on every commit, with the
gate silently absent.

Sonnet is the default because Claude Code's own default for a check like this is Haiku, which denied
10 of 24 checks on a dozen clean commit messages and then rejected its own suggested rewrites, so a
session could not commit at all. Sonnet allowed 23 of those 24, and both models denied all 16 checks
on planted violations.

`--safe-mode` starts the nested call with no CLAUDE.md, skills, plugins, hooks, or MCP servers and
keeps the normal sign-in, so the check works on a browser sign-in as well as with a key. `--tools=`
leaves the nested model no tools, and the default tool definitions are most of the call: one check
was 1.9k input tokens and 3.3 to 3.8 seconds with it, and 26k tokens with `--safe-mode` alone. The
flag is `--tools=` and not `--tools ""` because PowerShell can drop an empty argument on the way to
`claude`.

`--safe-mode` has not been checked on an install that signs in through a gateway with a key, so a
call that exits non-zero is retried once with `--bare` in its place. `--bare` takes
`ANTHROPIC_API_KEY`, an `apiKeyHelper` from a settings file, or a third-party provider's own
credentials, and prints "Not logged in" on a browser sign-in. Every failure path exits 0, so a gate
that cannot reach a model lets the command through instead of blocking it.

The first time in a session that both calls fail, or that `claude` is not on the path, the user is
told once that model review is off, through the hook's `systemMessage`, which is shown to the user
and not to the model. The marker is a file in the temporary directory, named for the session id. A
reply from a call that exited 0 is not such a failure, whatever its form.

Managed policy settings still apply under `--safe-mode`, so a copy of the gate registered that way
would run inside its own nested call. The scripts set `WRITING_CONVENTIONS_NESTED=1` on that call,
and each exits at once when the variable is set.

The cost is one call per `git commit` and per `gh pr`, `gh issue`, or `gh release` command, read-only
ones included. One hook entry per shell covers all four command families, because the command text is
matched in the script rather than through a hook `if` pattern. `git -C <path> commit` is gated that
way too, and no `Bash(git commit *)` rule matches that form, which is the one a worktree session uses.
[`hooks/gate-test.sh`](hooks/gate-test.sh) and [`hooks/gate-test.ps1`](hooks/gate-test.ps1) check the
plumbing offline against a stub `claude` on the PATH: which commands reach the model, which replies
block a command, the exit codes, and the fail-open path.

### MCP calls

A team that publishes through an MCP server, such as Jira and Bitbucket with no `gh` installed, gets
the same read. A second `PreToolUse` entry matches `mcp__.*` and runs the same two scripts. No
server or tool name is written in them. The first call to a tool costs one classifier call, with
[`hooks/classify-prompt.md`](hooks/classify-prompt.md) as the system prompt: can this tool hand text
to a human-facing destination? The answer is `CAN_PUBLISH` or `NEVER`, doubt is `CAN_PUBLISH`, and
a reply in any other form is treated as doubt and not kept. On 30 hand-labeled tools with sample
inputs (Jira, Confluence, Bitbucket, GitHub, GitLab, Slack, mail, and read-only search and browser
tools), all 20 publishing tools came back `CAN_PUBLISH` and all 10 others `NEVER`.

The answer is appended as one line, `<tool name> <answer>`, to
`${CLAUDE_CONFIG_DIR:-~/.claude}/writing-conventions/mcp-tools-<hash>.txt`, where the hash is of the
classifier prompt, so a changed prompt starts a new file. `gate.sh` and `gate.ps1` hash differently
and keep separate files. The file is yours to read and edit: for one tool a `CAN_PUBLISH` line wins
over a `NEVER` line, and a malformed line is ignored. A `NEVER` tool costs no model call after the
first. A wrong `NEVER` is a lasting gap on that machine until the line is edited.

For a `CAN_PUBLISH` tool the whole `tool_input` goes to the reader, structure included, so text
split across short fields is read together. A finding has to quote the decoded string values of
`tool_input`. In a rich-text body such as Atlassian Document Format one sentence can be split
across text nodes, and the reader quotes it as its pieces, `"The report " + "says so."`; each piece
is looked for on its own and nothing is joined.

### Prose files

A `Write` or `Edit` to a `.md`, `.markdown`, `.txt`, `.adoc`, or `.rst` file gets the same read
after the fact, from a `PostToolUse` entry that runs the gate scripts with `--file`. Nothing is
blocked, because a file is cheap to fix and a blocked edit stops the turn: a verified finding comes
back as `additionalContext`, and the session fixes the file in place. The advisory nudge on
`Write|Edit` is unchanged and still fires for the same files, so a session in which the reader
cannot run keeps it. A source file gets the nudge only.

The nested model has no tools, so the script reads, and only the file the tool just wrote. For a
`Write` the text under review is `content`. For an `Edit` it is the whole paragraphs, bounded by
blank lines, that hold `new_string` in the edited file
([`hooks/excerpt.awk`](hooks/excerpt.awk)): replacing "includes" with "says" in "The report includes
the version." makes a violation that the one word does not show. The size of the excerpt follows
the edit and not the file, so a release note added to a large changelog is read. The reader is sent
that text and the file path, not the hook input.

What is not read is stated in the same feedback: text past the first 50,000 characters, an `Edit`
that only deletes, and the sentences around an `Edit` to a file over 1 MB, where `new_string` alone
is read. A draft written to a file with a shell redirect is not read at all.

### Chat drafts

A draft the session hands its user to paste somewhere else never reaches a shell command or an MCP
tool. A draft for publication goes in its own fenced block with the info string `draft`; that rule
is loaded into every session. A `Stop` entry runs the gate scripts with `--stop`. The text inside
each `draft` fence goes to the reader, and nothing else in the reply does. A turn with no such fence
costs one scan and no model call.

A verified finding exits 2. That continues the turn, so the session emits a corrected draft. Claude
Code has no hook that runs before a reply is displayed, so review happens afterward. A blocked
reply is re-emitted whole. The blocking is counted in a file named for the turn's `prompt_id`, and
it stops after two; the third time, the user is told that review is unresolved, and the reply
stands. `WRITING_CONVENTIONS_STOP_READER=0` turns the reader off.

Tagging keeps this cheap, and the rate was measured before any of it was built and again with the
rule text that ships, at n = 12 per arm with `claude -p --model sonnet` and the draft named only as
a by-product of a coding task. With no rule, a drafting skill fired on 3 of 12 runs, and of the 9
replies that included a draft, 6 were in a plain fence, 2 in a blockquote, and 1 between `---`
rules; a plain fence of 8 words or more also trips on 4 of 12 ordinary replies. With the rule text
that ships, 8 of the 9 replies that included a draft tagged it, and 0 of 12 ordinary replies used
the tag while 11 of them carried some other fence. The miss gave review feedback as the body of the
reply rather than as a block. A draft the session does not tag is not read by the model at all; the
reply lint is all that sees it.

Both matchers drop every closed fenced block before matching, so `--record` unwraps the `draft`
fences first ([`hooks/draft.awk`](hooks/draft.awk), [`hooks/draft.ps1`](hooks/draft.ps1), the same
scanner the reader uses), and the whole reply still gets the one pass it always got. A code fence
inside a draft is still a fence and is still dropped, which is why a draft that includes one goes
in a longer fence.

### What is not gated

A shell command outside the four families is not read, so `glab`, `hg`, `svn`, and `jj` publish
unread. A `git push` is not read, because a branch name is chosen long before it.

Adding a word to the banned list is a plugin release rather than a local edit: an installed session
reads a version-keyed cache, so the plugin's `version` in `.claude-plugin/marketplace.json` has to
bump in the same commit or the session keeps serving the old list.

## Measuring it

[`evals/`](evals/) is a `claude plugin eval` suite of twelve drafting tasks built from the
corrections that motivated this plugin: commit messages, PR bodies, an issue body, a maintainer
comment, a README paragraph, KDoc, a changelog entry, Spock method names, a code comment, and a
status reply. In each prompt the facts are stated the way a user would state them, without the rules.
In four of them (a PR body, a commit message, the issue body, and the status reply) the facts are
written with tells a session is likely to copy into a draft: a personified report or build, a spaced em
dash, a banned word, or a "whose" after a file. A session often paraphrases source text, and with
clean facts the scores with and without the plugin differed little. Each
case has three free regex graders (spaced dashes, the banned words that have no literal sense, and
a narrow personification pattern over present-tense verbs and a fixed noun list), a judge-model
grader for personification, and where the genre calls for it, a judge grader for form. The form
graders check only this plugin's own rules: lead with the outcome, and no narration of how the
change came about. Sentence counts and heading limits are left to `ghostwrite`, since a limit
stated in the prompt measures whether the model follows the prompt.
The personification judge fails a draft only for a sentence it can quote. With the looser wording
and the default Haiku judge, it failed 11 of 24 runs both with and without the plugin loaded, and
only one of the 11 flagged drafts had a real violation.
Run it from the plugin directory:

```bash
claude plugin eval . --runs 2 --judge-model sonnet --no-publish
```

The default two-arm run scores the same prompts with and without the plugin loaded and reports
the difference. Every run costs a fraction of a dollar in judge and agent calls, so the suite is
for a change to the rules file or the hooks, not for every commit. Results land under
`evals/results/`, which is ignored.

Before the prompts were seeded and the judge changed, the plugin raised the mean case score by
0.06. After both changes, the gain was about 0.20, measured on 2026-09-13. Plugin-loaded drafts
failed a regex grader on one run of 24 and the personification judge on 3. Tells copied from the
facts still get through: in the PR body case, "the README told users" appeared in one of two
plugin-loaded drafts, in each of two separate runs.

## Skills

### `write-for-the-reader`

Governs what the agent writes to you: chat replies, summaries, wrap-ups. Assumes you have read
nothing since your last message, so no back-reference to "the fix above," no term coined three
tool calls ago, and the file, decision, and outcome named in full every time. Picks the amount of
detail from what you will do next rather than from how much work happened: a routine call gets one
line, a call you might have made differently gets one sentence naming the alternative it rejected.
Links a file with an absolute path instead of pasting its contents, and leaves out what you can
already see for yourself, like a local test-suite pass CI already reports. When you flag a word as
jargon, this skill is what logs it into `hooks/rules.md`.
