# To do

## Needs a Windows machine

On a machine where the built-in `cc-plugin-sec-default` plugin is active (managed settings, or a
Team or Enterprise sign-in), every `classic.*` event is sent past user-installed plugins, so none
of our `classic.*` hooks run there. Since Claude Code 2.1.304, each skipped hook is reported as a
transcript line: `<plugin>: its classic.SessionStart hook was skipped. "cc-plugin-sec-default"
runs first and sent the event on past it.` In the 2.1.309 source, `prompt.compose`,
`prompt.context`, `prompt.section`, and `agent.spawn` are sent past user plugins too, but
`tool.call`, `prompt.submit`, and `session.end` are not.

1. Probe first. In a scratch plugin loaded with `--plugin-dir` on that machine, check that hooks on
   `tool.call` (adding `context` to the result), `prompt.submit` (adding `context`), and
   `session.end` run, and that context added on the first `prompt.submit` reaches the model.
2. If they run, move each hook that has a native event: `classic.PostToolUse` to `tool.call`,
   `classic.UserPromptSubmit` to `prompt.submit`, and `classic.SessionEnd` to `session.end`. If
   first-prompt context gets through, move the `classic.SessionStart` rules there too. The
   `classic.Stop` blocks in `writing-conventions` and `session-skills` have no native event that
   can block, so they stay on `classic.Stop`.
