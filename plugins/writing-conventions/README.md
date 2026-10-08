# writing-conventions

A [Claude Code](https://claude.ai/code) plugin for how an agent writes. Its main product is a short
set of always-on rules (plain engineering English, free of AI tells, replies a cold reader can follow)
injected at the start of every session and every subagent, so they apply without anyone invoking a
skill.

Every rule in that list arrived the same way: a specific draft came back wrong, and the correction
became a rule. `write-for-the-reader` is where a word you flag gets logged into the list. With the
`ghostwriting-skills` plugin, which drafts text that ships under your name, the general rules that
come out of your edits are added to the same file when this plugin is installed.

Claude Code 2.1.286 is the oldest version supported: it is the first where hooks modules are on by
default. Everything runs in a hooks module, which is a Claude Code mod (see
[What runs the hooks](#what-runs-the-hooks)).

## What loads every session

The hooks module adds [`hooks/rules.md`](hooks/rules.md) to every session at its start, including
after `/clear`, compaction, and a fork, and to every subagent as it starts, since a subagent's report is what a later summary is built from. The file is eleven named
anti-patterns, several with drafted-to-accepted pairs: inanimate agency, mechanics (spaced
em dashes, the Oxford comma, and consistent units), a banned-vocabulary list, epigrams, paired
contrasts, and matched clauses, narration, sentence order, coinages, writing for a reader who has
read nothing since their last message, saying a fact once, evidence, and erring short. Three
standing rules follow: a rule broken in a draft is swept across the branch, the user's private
circumstances stay out of public artifacts, and a draft for publication goes in a fenced block with
the info string `draft`, which is what the `Stop` check below looks for. The file is about 1,350
words, so it costs roughly 1,800 tokens per session and per subagent, against about 1,600 words for
the long form; the reasoning behind each rule, and its edge cases, sit in `write-for-the-reader` §8
and load only when that skill does.

Prohibitions apply everywhere, `SKILL.md` files included, because they are about precision rather
than register. Form rules—bold, redundancy, length, and the reader-facing voice—do not apply to
agent-facing files, so those files are formatted for whatever a model reads best.

The reply lint runs on both ends of a turn, from the plugin's hooks module
([`hooks/gate.ts`](hooks/gate.ts)). On `Stop` the final reply is linted and what is found is saved.
On `UserPromptSubmit` the next turn opens with those hits and a one-line reminder, and the saved
note is cleared. After a `Write` or an `Edit`, the session is asked to re-read the file just written
when it is prose, or is a source file with comments and test names in it (`.md`, `.markdown`,
`.txt`, `.kt`, `.kts`, `.java`, `.groovy`, in any letter case). The lint itself is `lint()` in
[`hooks/lint.ts`](hooks/lint.ts), a pure function over text, checked on 102 cases in
[`hooks/lint.test.ts`](hooks/lint.test.ts). The module also registers it as a tool,
`mcp__writing-conventions__lint`, which the `ghostwrite` skill calls on a draft.

A word is letters and digits in ASCII and Latin-1, so `café` is one word, and a character outside
those is read whole.

The lint flags the mechanically detectable subset of the rules: the banned vocabulary, spaced em
dashes, a missing Oxford comma in a list of single words, an inanimate subject paired with a verb of
speech, volition, or cognition, and a bulleted or numbered item that opens on bold text. The Oxford
comma check needs two commas before the final "and" or "or", because a one-comma list ("a, b and c")
matches too many ordinary clauses. The agency set is deliberately narrow. An earlier version also
matched possession verbs (holds, carries, keeps) and scored about 40% precision on a hand-checked
sample, mostly on code mechanics such as a map that holds a value; with the current set fewer
sentences are flagged, and each hit is one the model can act on.

Matched clauses are left to the gate. A pattern for two clauses of similar length joined by "and"
matched 44 of 582 sentences in this repo's last 400 commit messages and 27 of 419 in its READMEs,
nearly all of them ordinary compound sentences, and it did not match the sentence the rule was
written from. Whether two facts are related cannot be told from a pattern match.

The lint never blocks. A `Stop` hook cannot patch a reply, so blocking one gets a corrected answer
only by re-emitting the entire original, which you have already read and which stays in the
transcript beside it. Carrying the hits into the next turn costs a few dozen tokens instead, and the
flagged reply stands as sent.

Each line of the note ends with the rule that line is about, because a note that contained only the
pattern and a reference to "the rules loaded at session start" did no better than sending nothing:
across six two-turn trials per arm, no note left 6 of 6 next replies dirty, the note with the
reference left 5 of 6 dirty, and the same mechanism with the rule stated inline left 0 of 6 dirty.
Literal senses ("a Slack channel", "an array shape") are not flagged. Text inside code fences,
backticks, and double quotes is never matched. A clean reply clears whatever the previous one left
pending. Rules that need judgment to detect are left to the model's review passes, but a
construction the lint cannot match is still a violation.

## Spaced em dashes in a reply

[`hooks/dash.ts`](hooks/dash.ts) closes up a spaced em dash as the reply streams, through a
`turn.step` hook in the plugin's hooks module, so `word — word` is shown and stored as `word—word`.
The fix has to be made in the stream: a hook on the stored reply alone leaves the screen
showing the spaced form while the reply arrives.

What the lint skips is left as written: a fenced block, inline code, and text in straight or
curly double quotes. A fence counts when it opens in a block quote or on a list item's first line,
and a code span or a quote left open at the end of a line stays open until it closes or a blank
line ends the paragraph. A `draft` fence is the exception, since its text is for publication, though a
fence inside it is left alone. The other findings in a draft still need the review model, so the `Stop`
check is unchanged. Three more cases are left as written because the spaces are markdown: a dash with
no letter, code span, or quote before it on its line, as after a list or heading marker, a dash
alone in a table cell, and spaces between a dash and a line break.

Text is held back only while the next piece of the stream could change it: spaces that may precede
a dash, a run of backticks, and a line that may open a fence. When a chunk of another kind arrives,
what is held is written first, and any more text for a block already begun is passed through as
written. In a 900-word reply no such chunk arrived inside a text block.

[`hooks/dash.test.ts`](hooks/dash.test.ts) checks each case whole and cut into random pieces, under
`claude plugin test`. [`hooks/register.ts`](hooks/register.ts) registers this hook and the gate's,
because `hooks.json` may list only one module.

## What runs the hooks

Everything runs in the plugin's hooks module, [`hooks/register.ts`](hooks/register.ts), so a
Windows session runs the same code as any other and no shell is involved.

2.1.286 is the first CLI where hooks modules are on by default. They are listed in the Claude Code
changelog as Mods from 2.1.287. The gate, the lint tool, the re-read request after a written file,
the rules for subagents, the dash rewrite, and the lint note on the next turn were each checked in a
live session on 2.1.286 through 2.1.291. Hooks modules are in 2.1.285 and older as well, but they
are off there unless `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` is set, and the module was not checked on
those versions. On an older CLI with that variable set, the rules still load at session start, but
the lint, the dash rewrite, the gate, and the rules for subagents are off, and the user is told once
in a toast. Where function hooks are switched off nothing in this plugin runs, the session-start
rules included, and there is no toast: `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` in the environment
turns them on, and `claude --debug` logs a module that did not load.

## The gate at publication

In the census behind this plugin, 101 of 107 corrections were to text that ships: PR bodies,
comments, issue bodies, commit messages, and docs. A lint over chat is never run on those, so a
`tool.call` hook checks the commands that publish them: `git commit`, every `gh pr`, `gh issue`, and
`gh release` subcommand, and any other command that can publish (see "Other shell commands"),
through the `Bash` tool and through the `PowerShell` tool both. Covering only `Bash` leaves every
commit ungated on a Windows session where the PowerShell tool is the shell.
[`hooks/gate.ts`](hooks/gate.ts) sends the command to a model, which pulls out the commit message or
the title and body and checks that text against the four prohibitions: inanimate agency, mechanics
(spaced em dashes and the Oxford comma), the banned words, and rule 4's epigrams, paired contrasts,
and matched clauses. A fifth check is a string match rather than a judgment: a Markdown heading or a
bullet changelog in a commit message, an issue, a pull request, or a comment. Length is never
judged, and no other form is. The model replies `PASS`, `SKIP` for a command that publishes nothing
new (`gh pr view`, `gh pr checks`, `--amend --no-edit`, a label change), or `VIOLATION` with one
line per offending sentence: the quoted words, then a plain rewrite.

`findings()` in [`hooks/text.ts`](hooks/text.ts) looks for each
quote in the command, with runs of whitespace collapsed. A finding with its quote in the command
comes back as the tool's error, and the session fixes the text and runs the command again. A reply in any other
form lets the command through, as a failed call does, because the text the model reads can quote an
untrusted source.

The check is one `$.model.complete` call, with
[`hooks/gate-prompt.md`](hooks/gate-prompt.md) as the system prompt and the hook input as the
message. [`hooks/rules.md`](hooks/rules.md) is appended to that prompt, so a word added to the rules
is checked at the gate with no second edit. Which model answers comes from `WRITING_CONVENTIONS_GATE_MODEL`, or from the `sonnet` alias
when that is unset; set it in the `env` block of a settings file to any id the session's endpoint
serves.

An alias is enough there because `$.model.complete` resolves one the way `--model` does, through
`ANTHROPIC_DEFAULT_SONNET_MODEL` and the related variables, so the default works on a first-party
install and on a LiteLLM proxy in front of Bedrock or Vertex alike. That is the reason the check is
not a prompt-type hook, where an alias in the `model` field is not resolved: `"model": "sonnet"`
there is sent to the API verbatim, a proxy answers HTTP 400
`Invalid model name passed in model=sonnet`, and Claude Code logs `unrecognized_model` with
`query_source: hook_prompt`. Since that field is a free-form string checked at call time rather than
at load time, the only symptom was a hook error on every commit, and the check never ran.

Sonnet is the default because Claude Code's default for a check like this is Haiku, which denied 10
of 24 checks on a dozen clean commit messages and then rejected the rewrites it had suggested, so a
session could not commit at all. Sonnet 5 allowed 23 of those 24, and both models denied all 16
checks on planted violations. Sonnet 5.5, which the alias resolves to on CLI 2.1.289, had the same
two counts on 2026-10-05, and over five runs it allowed 57 of 60 and denied 40 of 40.

Haiku 5.5 had the same two counts as Sonnet 5.5 on 2026-10-07, but Sonnet is still the default. On
a larger set of 35 texts with an inanimate-agency violation and 60 clean ones, each checked twice,
Haiku 5.5 denied 58 of the 70 where Sonnet 5.5 denied 66, and it was no faster. At its default
effort, 9 of its 190 calls ended with no reply, and a check with no reply is skipped.

Matched clauses were checked on 2026-10-06, on the `sonnet` alias with CLI 2.1.291. Four planted
commit messages, each with two unrelated facts in matched clauses, were denied on 17 of 18 runs, and
on none of 4 runs before the rule was added. On sixteen commit messages from this repo's history,
each with a sentence of two similar-length clauses joined by "and", a matched-clause finding was
returned on 1 of 40 runs.

A 265-character comment draft that was corrected after the gate had read it was replayed on
2026-10-06, on the `sonnet` alias with CLI 2.1.292. It was answered with `SKIP` on 9 of 10 runs, and
again on 9 of 10 with a "The README says" sentence added to it. With the `SKIP` paragraph of the
prompt reworded, the draft was read on 10 of 10 runs, and with the added sentence it was denied on
10 of 10.

A PR body draft was replayed the same way. Its sentence "A build that applies
`io.github.ben-manes.versions` in its root build script still gets two copies of the plugin" was
allowed on 8 of 10 runs, with "the build gets two copies" already quoted in item 1 of the prompt.
With item 1 reworded, the draft was denied on 10 of 10 runs. On 60 posted texts that an earlier
review found clean, a finding was kept on 34 of 120 checks, against 31 before the rewording. The
only one that quoted a build as the subject was "a build that relies on that fallback gets the same
report as before", in both runs. Five read-only commands were still answered with `SKIP`, on 4 of 4
runs each.

On Sonnet 5.5 the median call took 1.6 seconds on a planted commit message, 3.6 seconds on a clean
one, and 5.9 seconds on the text of a PR, an issue, or a comment, and the longest of 317 calls took
16 seconds. A call is given at most 60 seconds. No effort is set on it. At `low` the last two
medians fell to 1.3 and 2.3 seconds, but over two runs of 60 posted texts that an earlier review
found clean, a finding was kept on 63 of 120 checks against 42 at the model's default.

Every failure lets the command through, so a commit is not blocked when no model can be called. The
first time in a session that a check fails, the user is told once that model review is off, in a
toast, which is shown to the user and not to the model. A reply from a call that was answered is not
such a failure, whatever its form.

The cost is one call per `git commit` and per `gh pr`, `gh issue`, or `gh release` command, read-only
ones included. One hook covers all four command families, because the command text is
matched in the module rather than through a hook `if` pattern. `git -C <path> commit` is gated that
way too, and no `Bash(git commit *)` rule matches that form, which is the one a worktree session uses.
[`hooks/gate.test.ts`](hooks/gate.test.ts) checks the plumbing under `claude plugin test`, against a
stand-in for the model: which commands are sent to the model, which replies block a command, and the
fail-open path.

### Other shell commands

Any other command is reviewed when the classifier model answers that it can publish. That
way `hg commit`, `svn commit`, `jj describe`, `glab mr create`, and a CLI nobody here has heard of
are read like `git commit`, with no command name written in the plugin.
`keys()` in [`hooks/keys.ts`](hooks/keys.ts) splits the command into
keys: each simple command's first word, up to two subcommand candidates after it, and the words after
each key in case it is a task runner. A substitution inside double quotes counts as a command, but
single-quoted text and heredoc bodies do not. [`hooks/keys.test.ts`](hooks/keys.test.ts) checks it
on 147 commands.

Each key has one of five classes: `NEVER`, `CAN_PUBLISH`, `DESCEND` when the answer depends on the
subcommand (`git`, `hg`), `PROJECT` when the words after it are the project's task names (`make`,
`npm run`, `./gradlew`), or `RUNS_CODE` for an interpreter or `curl`. Keys with no class cost one
classifier call for the whole command, with [`hooks/classify-command.md`](hooks/classify-command.md)
as the prompt. A key missing from the reply is doubt: it reads as `CAN_PUBLISH` and is not kept. A
command with keys that are all `NEVER` makes no call.

The answers are appended to
`${CLAUDE_CONFIG_DIR:-~/.claude}/writing-conventions/shell-commands-<hash>.txt`, one line each:
`<scope><TAB><class><TAB><key>`. The scope is `*` for a key every project shares, or the project
directory for a task name or a program run by path. The file is yours to read and edit, and for one
key a `CAN_PUBLISH` line wins over the other classes.

The four command families above are reviewed whatever is in the file, so a wrong `NEVER` can only
cost coverage of other commands. A command is also reviewed when it has a quote left open, or a word
that cannot be read as a name in a subcommand position, such as `hg "$verb"`. A `RUNS_CODE` command
is read only when it contains a sentence: six or more words, the first capitalized and the last
ending in `.`, `!`, or `?`. A `\n` or `\t` escape between words counts as a space, and a word may be
quoted. Interpreters run in about 16% of commands on the machine this was measured on, and a short
message posted through `curl` or a script is not read. `WRITING_CONVENTIONS_SHELL_CLASSIFIER=0`
turns this off and leaves the four families.

A command that only writes a local file is not blocked, just as a `Write` or `Edit` to a prose file
is not (see "Prose files"). A session in a worktree edits a file that lives only in the primary
checkout with a `python3` or `perl` script, because a worktree guard can refuse an `Edit` there. The
review model answers `LOCAL` in place of `VIOLATION` when nothing in the command sends the text anywhere
else, and doubt is `VIOLATION`. The findings then come back as `additionalContext`, and the session
fixes the file after the command runs. A `LOCAL` answer still blocks the four families and an MCP
call. In a live run on Sonnet 5.5, two local-file scripts came back `LOCAL` 6 times out of 6. Four
scripts that post their text through a webhook, `gh api`, `hg commit -l`, or `glab release create`
were blocked 12 times out of 12.

A body passed by file path is read by the gate, for the four families only: `git commit -F` or
`--file`, and `-F`, `--body-file`, or `--notes-file` on `gh pr`, `gh issue`, and `gh release`. The
flags that take a value are listed per command in `keys.ts`, from each command's
`--help`, so that `git commit -m '-F' notes.txt` reads no file. The review model is sent each file after the
hook input, under a `File: <path>` line, and a finding may quote it. A file is read only when the
text on disk is the text the command will publish, as far as the gate can tell:

- The path is literal, with no variable, glob, `~`, or quoted space in it.
- No other word of the command includes its file name, since a command that writes the file first
  publishes different text from what is in the file now.
- A relative path resolves against the session's `cwd`, and the command has no `cd`, `pushd`,
  `Set-Location`, `git -C`, `git --work-tree`, or `GIT_WORK_TREE` in it.
- It is a readable regular file, not a link, inside the project or a temporary directory, at most
  1 MB, with no NUL byte in its first 8 KB.

Where one command passes two body flags, only the last one is read, as git and gh do. Up to 4 files
are read per command, 50,000 characters in all. Each file that is not read is listed back to the
session with the reason, in the block reason or as `additionalContext`.

The test by file name has two known costs. When a command rewrites the file without its name
appearing, such as `make notes && gh release create v1 -F notes.md`, the old text is read. When the
name appears again only to delete the file, such as `git commit -F msg.txt && rm msg.txt`, no file
is read. A body flag is not found at all after a wrapper that takes a value (`sudo -u me`,
`nice -n 5`) or in a program called by path (`/usr/bin/git`), and nothing is reported for it. A body
file for any other command, such as `hg commit -l`, is not read.

Replayed from an empty cache over 122,260 shell commands from one machine's history, 3.6% of
commands made a classifier call and 9.5% were reviewed, against 4.1% for the four families
alone. Of the rest, 1.8% were `python3` with a sentence in the code, 1.7% were programs run by path
that the classifier did not know, 0.9% were `git merge`, `rebase`, `tag`, and `cherry-pick`, and
0.5% were commands that could not be split into keys. Planted inanimate-agency sentences in `hg commit`,
`svn commit`, `jj describe`, and `glab mr create` were each blocked, and clean messages in the same
four went through.

### MCP calls

A team that publishes through an MCP server, such as Jira and Bitbucket with no `gh` installed, gets
the same read. The `tool.call` hook that reads a shell command reads a call to any `mcp__` tool. No
server or tool name is written in it. The first call to a tool costs one classifier call, with
[`hooks/classify-prompt.md`](hooks/classify-prompt.md) as the system prompt: can this tool hand text
to a human-facing destination? The answer is `CAN_PUBLISH` or `NEVER`, doubt is `CAN_PUBLISH`, and
a reply in any other form is treated as doubt and not kept. On 30 hand-labeled tools with sample
inputs (Jira, Confluence, Bitbucket, GitHub, GitLab, Slack, mail, and read-only search and browser
tools), all 20 publishing tools came back `CAN_PUBLISH` and all 10 others `NEVER`.

The answer is appended as one line, `<tool name> <answer>`, to
`${CLAUDE_CONFIG_DIR:-~/.claude}/writing-conventions/mcp-tools-<hash>.txt`, where the hash is of the
classifier prompt, so a changed prompt starts a new file. A file written by a version before 0.44.0
is not read, since the hash changed. The file is yours to read and edit: for one tool a `CAN_PUBLISH` line wins
over a `NEVER` line, and a malformed line is ignored. A `NEVER` tool costs no model call after the
first. A wrong `NEVER` is a lasting gap on that machine until the line is edited.

For a `CAN_PUBLISH` tool the whole `tool_input` is sent to the review model, structure included, so text
split across short fields is read together. A finding has to quote the decoded string values of
`tool_input`. In a rich-text body such as Atlassian Document Format one sentence can be split
across text nodes, and the review model quotes it as its pieces, `"The report " + "says so."`; each piece
is looked for on its own and nothing is joined.

### Prose files

A `Write` or `Edit` to a `.md`, `.markdown`, `.txt`, `.adoc`, or `.rst` file is read the same way
after the fact, by a `PostToolUse` hook. Nothing is blocked, because a file is cheap to fix and a
blocked edit stops the turn: a verified finding comes back as `additionalContext`, and the session
fixes the file in place. The advisory re-read request on `Write|Edit` is unchanged and still fires
for the same files, so a session in which the review model cannot run keeps it. For a source file
there is only the re-read request.

The review model has no tools, so the gate reads, and only the file the tool just wrote. For a
`Write` the text under review is `content`. For an `Edit` it is the whole paragraphs, bounded by
blank lines, that contain `new_string` in the edited file (`excerpt()` in
[`hooks/text.ts`](hooks/text.ts)): replacing "includes" with "says" in "The report includes the
version." makes a violation that the one word does not show. The size of the excerpt follows the
edit and not the file, so a release note added to a large changelog is read. The review model is
sent that text and the file path, not the hook input.

What is not read is stated in the same feedback: text past the first 50,000 characters, an `Edit`
that only deletes, and the sentences around an `Edit` to a file over 1 MB, where `new_string` alone
is read. A draft written to a file with a shell redirect is not read at all.

### Chat drafts

A draft the session hands its user to paste somewhere else is never in a shell command or an MCP
tool call. A draft for publication goes in its own fenced block with the info string `draft`; that rule
is loaded into every session. On `Stop`, the text inside each `draft` fence is sent to the review model, and
nothing else in the reply is. A turn with no such fence costs one scan and no model call.

A verified finding blocks the stop. That continues the turn, so the session emits a corrected
draft. Claude Code has no hook that runs before a reply is displayed, so review happens afterward. A
blocked reply is re-emitted whole. The blocking is counted per turn, by the turn's `prompt_id`, and
it stops after two; the third time, the user is told that review is unresolved, and the reply
stands. `WRITING_CONVENTIONS_STOP_READER=0` turns this check off.

Tagging keeps this check cheap. The tagging rate was measured before the check was built and again
with the rule text that ships, at n = 12 per arm with `claude -p --model sonnet` and the draft
mentioned only as a by-product of a coding task. With no rule, a drafting skill fired on 3 of 12
runs, and of the 9 replies that included a draft, 6 were in a plain fence, 2 in a blockquote, and 1
between `---` rules; a plain fence of 8 words or more also trips on 4 of 12 ordinary replies. With
the rule text that ships, 8 of the 9 replies that included a draft tagged it, and 0 of 12 ordinary
replies used the tag while 11 of them had some other fence. The miss gave review feedback as the
body of the reply rather than as a block. On Sonnet 5.5, with the prompts of that second run on
2026-10-05, a drafting skill fired on 2 of 12 runs with no rule, and of the 9 drafts 3 were in a
plain fence and 6 in a blockquote. With the rule, 9 of the 10 replies that included a draft tagged
it, with the same miss, and 0 of 12 ordinary replies used the tag while all 12 had another fence. A
draft the session does not tag is not read by the model at all, and is checked by the reply lint
alone.

The lint drops every closed fenced block before matching, so the `draft` fences are unwrapped
first (`drafts()` in [`hooks/text.ts`](hooks/text.ts), the same scanner the `Stop` check uses), and
the whole reply is still linted in one pass. A code fence inside a draft is still a fence and is
still dropped, which is why a draft that includes one goes in a longer fence.

### What is not gated

A `git push` is not read, because a branch name is chosen long before it.

Adding a word to the banned list is a plugin release rather than a local edit: an installed session
reads a version-keyed cache, so the plugin's `version` in `.claude-plugin/marketplace.json` has to
go up in the same commit, unless it is already ahead of the version on `origin/main`. One bump
covers every commit waiting to be pushed. Without one, the session keeps serving the old list.

## Measuring it

[`evals/`](evals/) is a `claude plugin eval` suite of thirteen drafting tasks built from the
corrections that motivated this plugin: commit messages, PR bodies, an issue body, a maintainer
comment, a README paragraph, KDoc, a changelog entry, Spock method names, a code comment, and a
status reply. In each prompt the facts are stated the way a user would state them, without the rules.
In five of them (two PR bodies, a commit message, the issue body, and the status reply) the facts are
written with tells a session is likely to copy into a draft: a personified report or build, a spaced em
dash, a banned word, or a "whose" after a file. A session often paraphrases source text, and with
clean facts the scores with and without the plugin differed little. Each case has three free regex
graders (spaced dashes, the banned words that have no literal sense, and a narrow personification
pattern over present-tense verbs and a fixed noun list), a judge-model grader for personification,
and where the genre calls for it, a judge grader for form. The second PR body case has a fourth
regex grader, for a build, a project, or a script that gets, keeps, or refers to something. The form
graders check only this plugin's rules: lead with the outcome, and no narration of how the change
came about. Sentence counts and heading limits are left to `ghostwrite`, since a limit stated in the
prompt measures whether the model follows the prompt. The personification judge fails a draft only
for a sentence it can quote. With the looser wording and the default Haiku judge, it failed 11 of 24
runs both with and without the plugin loaded, and only one of the 11 flagged drafts had a real
violation. Run the suite from the plugin directory:

```bash
claude plugin eval . --runs 2 --judge-model sonnet --no-publish
```

The default two-arm run scores the same prompts with and without the plugin loaded and reports
the difference. Every run costs a fraction of a dollar in judge and agent calls, so the suite is
for a change to the rules file or the hooks, not for every commit. Results land under
`evals/results/`, which is ignored.

The `Stop` check is on during a run, so a plugin-loaded draft is scored after any rewrite. Each
rewrite takes a turn, which is why `max_turns` is 8 in every case.

Before the prompts were seeded and the judge changed, the plugin raised the mean case score by
0.06. After both changes, the gain was about 0.20, measured on 2026-09-13. Plugin-loaded drafts
failed a regex grader on one run of 24 and the personification judge on 3. Tells copied from the
facts still get through: in the PR body case, "the README told users" appeared in one of two
plugin-loaded drafts, in each of two separate runs.

With `--judge-model sonnet` the judge is Sonnet 5.5 from CLI 2.1.289 on, so a score from before
that is not comparable with a later one. On 2026-10-05 the plugin scored 0.95 and no plugin 0.91, a
gain of 0.04. Plugin-loaded drafts failed no regex grader, the personification judge on 2 runs of
24, both in the same PR body case, and the form judge on 4. A second run that day, after `rules.md`
and `write-for-the-reader` were reworded, scored 0.95 and 0.86, a gain of 0.09, with the same
failures in the plugin-loaded drafts. The score without the plugin moved by 0.05 between two runs of
the same prompts, so the gain from a single run is known only to within about that much.

## Skills

### `write-for-the-reader`

Covers what the agent writes to you: chat replies, summaries, wrap-ups. The agent is told to assume
you have read nothing since your last message, so there is no back-reference to "the fix above," no
term coined three tool calls ago, and the file, decision, and outcome are written out in full every
time. The amount of detail follows what you will do next rather than how much work happened: one
line for a routine call, and one sentence on the rejected alternative for a call you might have made
differently. A file is linked with an absolute path instead of pasted, and what you can already see
is left out, such as a local test-suite pass that CI already reports. When you flag a word as
jargon, the agent logs it into `hooks/rules.md` under this skill.
