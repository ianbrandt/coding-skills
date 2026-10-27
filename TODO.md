# To do

## Four native fallbacks don't fire under the guard on Windows

Checked on a managed-settings Windows 11 machine, Claude Code 2.1.310, right after a
`/plugin` update. `cc-plugin-sec-default` forwards past every `classic.*` event as
expected, and the native fallbacks on `prompt.submit` and `turn.complete` work: the
rules land on the first prompt and again after `/compact`, the per-turn style reminder
and the lint note arrive on their prompts, the title tool refuses in the terminal and
the `/rename` block is printed, the push follow-up fires after a `git push` turn with
no fenced block, and the draft-lint follow-up fires on a reply with
`The report says so.` in a `draft` block.

The fallbacks that modify a `tool.call` request or result don't land. Four checks
fail with the same pattern:

- A subagent started with the Agent tool is given neither `WRITING CONVENTIONS ACTIVE`
  nor `You are a subagent with no user to ask` in its task.
- A Workflow agent is given neither rule, same root cause.
- A Write to a Markdown file returns the standard tool result with no re-read request
  appended by session-skills.
- The ghostwrite Skill returns the skill text with no `## Voice data, loaded by the
  plugin` section appended.

The five passing checks go through `prompt.submit` or `turn.complete`; the four failing
checks all go through `tool.call` modification. A diagnostic probe narrowed this to one
case. The `{ tool: 'Agent' }` wrapper in orchestration-skills' register.ts was patched
to log one line per call to `C:\Dev\.claude\jobs\<id>\tmp\probe.log` via `$.fs.write`,
since no telemetry is written on this machine (`DISABLE_TELEMETRY=1` is set in
`settings.json`). One Agent subagent produced the line
`tool.call Agent fired: classic=false, agentId=, prompt starts "Reply with the single
word: pong. Do not call any tool."` and the subagent reached the model with no
`SUBAGENT_RULE` prepended. So: **the hook fires, `isClassic` is correctly false, the
mutation branch runs, and the mutated `prompt` returned via `next({ ...e, prompt: ...
})` is dropped by the engine before the subagent is spawned.**

The probe is reverted. The fix is upstream in Claude Code: under managed settings a
`tool.call` hook's return of a mutated `prompt` on the Agent tool is dropped. Any
workaround here either spawns the subagent differently or has to wait for the engine
fix.

### Upstream issue to file

Repo: `anthropics/claude-code` (public). Title suggestion:

> `tool.call` hook's mutated request is dropped under `cc-plugin-sec-default` managed-settings guard

Body outline:
- Env: Windows 11 Enterprise, Claude Code 2.1.311, managed `cc-plugin-sec-default`
  plugin at tier `prepend` that calls `next.to(e, 'append')` on every `classic.*`
  event, so no `classic.*` event reaches user plugins.
- Repro: a user plugin registers `on('tool.call', { tool: 'Agent' }, ($, e, next) =>
  next({ ...e, prompt: '<PREFIX>\n\n' + e.prompt }))`. Fire one Agent subagent.
- Expected: the subagent's first message starts with `<PREFIX>`.
- Observed: the subagent receives the original prompt. The diagnostic written with
  `$.fs.write` at the top of the hook shows that the hook fires and the mutation
  branch runs.
- Scope: the same drop pattern is seen for a Workflow agent, for a tool result returned
  from `on('tool.call', ..., async (…) => { const r = await next(e); return { ...r,
  context: [...] } })` on the `Write` tool, and for a Skill text augmentation. The five
  checks that go through `prompt.submit` or `turn.complete` all work; the four that go
  through `tool.call` all fail.
- Hypothesis: under the guard, a `tool.call` hook's return value is read for `deny`
  but its mutated request/result fields are discarded. The classic-event path reads
  the whole return value; the native-event path does not.
- Note: `$.telemetry.log` is a no-op where `DISABLE_TELEMETRY=1` is set in
  `settings.json`, so a diagnostic probe wanting to run on such a machine needs
  `$.fs.write` instead.

## Push detector matches command text, not git state

The regex `/\bgit(\s+-C\s+\S+)?\s+push\b/` in session-skills' register.ts matched
`git push` wherever it appeared in a Bash command. In the testing above it fired twice
on this parent session, each time because the string sat inside a quoted argument of a
`claude -p ... "...git push --dry-run origin main..."` Bash call. Each quoted argument
is now replaced with X before the regex runs, so a push mentioned only inside a quoted
argument no longer counts. A push run as `bash -c 'git push'` is now missed, which is
rare and left as a known shortcut.
