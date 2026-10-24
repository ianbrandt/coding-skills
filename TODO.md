# To do

## Migrate off classic hooks that `cc-plugin-sec-default` forwards past

On a machine with managed settings (an HKLM `SOFTWARE\Policies\ClaudeCode`
value on Windows, or a Team/Enterprise sign-in), Claude Code loads
`cc-plugin-sec-default`, a built-in plugin that sits at the front of the
chain and short-circuits delivery of some events to user plugins. Each
skipped hook is reported in the transcript JSONL as `<plugin>: its <event>
hook was skipped. "cc-plugin-sec-default" runs first and sent the event
on past it.` (Reporting is from Claude Code 2.1.304; the behavior itself
may have shipped earlier.)

### Confirmed on 2026-10-23 against 2.1.309, re-verify on 2.1.310+ before migrating

Forwarded past user plugins:

- `classic.SessionStart`
- `classic.UserPromptSubmit`
- `classic.PostToolUse`
- `classic.Stop`
- `skill.prompt` (native—`ghostwriting-skills`' voice loader broke here)

Still delivered:

- `classic.SessionEnd`
- `classic.SubagentStart`
- `tool.call`, `session.start`, `session.end`, `prompt.submit` (native, inferred from migration tests passing)

The earlier assumption that only `classic.*` events are forwarded past is
wrong; `skill.prompt` being on the list means every native event is suspect
until probed.

### Native `prompt.submit` is a prompt-rewrite event

Its return is `{ text }` or `{ drop }`—no `context` or `additionalContext`
field. To inject rules or notes, prepend to `e.text` and forward with
`next(e)`. The model still reads them; they just arrive inside the prompt rather
than as a separate field.

### Plan

1. Re-verify the forward-past list on the current Claude Code version
   (`claude --debug` and scan the transcript for `hook was skipped` lines,
   or run a scratch plugin via `--plugin-dir` that registers on every
   event and logs what fires).
2. For each `classic.*` event on the forward-past list that has a native
   counterpart, migrate:
   - `classic.PostToolUse` → `tool.call` (`session-skills` push detector,
     `writing-conventions` Write/Edit nudge + gate)
   - `classic.UserPromptSubmit` → `prompt.submit`, prepended to `e.text`
     (`session-skills`, `writing-conventions`)
   - `classic.SessionStart` rules → first `prompt.submit` per non-fork
     session, prepended to `e.text`, with native `session.start` tracking
     fork/reset (`orchestration-skills`, `roadmap-skills`, `session-skills`,
     `writing-conventions`)
3. `classic.Stop` has no native blocking equivalent. Either accept the
   regression (`session-skills` push-next-step, `writing-conventions`
   lint-stop are nudges rather than correctness-critical), or reshape
   each into a `prompt.submit` intervention that fires one turn later.
4. Dropped feature: `set_session_title`'s rename on the next prompt.
   Native `prompt.submit` has no `sessionTitle` return. The tool still
   records the title; the one-shot apply step is gone.
5. Update each migrated hook's tests. The harness exercises native events
   via `$.prompt.submit({ text })`, `$.session.start({ cwd, source })`,
   `$.session.end({ reason })`, and expects `on('tool.register', ...)`
   and `on('session.id', ...)` set up as test-world handlers.

### A WIP migration done against 2.1.309 lives uncommitted on this branch

The five plugins listed above and their tests have this migration applied;
all 240 tests pass; marketplace versions bumped. Left uncommitted because
it was done against a single snapshot without probing first and 2.1.310+
may have shifted things. If the probe matches 2.1.309's set, the diff is
a reasonable starting point.
