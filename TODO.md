# To do

## Needs a Windows machine

On a machine with managed settings, the built-in `cc-plugin-sec-default` plugin sends every
`classic.*` event and `skill.prompt` past user plugins. The guard code is the same in 2.1.308,
2.1.309, and 2.1.310. The classic hooks are still the main path, and each plugin runs a native
fallback only when no classic event has reached it in the session: the rules as `prompt.submit`
context, re-added once the model no longer reads them, the subagent rules prepended to an Agent
`tool.call`, and the Write/Edit check on `tool.call`. The ghostwriting voice text comes back beside
the Skill tool's result when `skill.prompt` does not run. The fallbacks were checked on macOS with a
copy of the guard in the plugin test kit, not under the real guard.

On the work machine, after updating the plugins, start a session and check four things:

1. The first reply follows the session rules, and `/compact` followed by a prompt brings them back.
2. A subagent started with the Agent tool can quote `WRITING CONVENTIONS ACTIVE` and the line
   `You are a subagent with no user to ask` from its task.
3. Writing a Markdown file with Write prints the re-read request in the tool result.
4. The voice spec is added once when `ghostwrite` runs through the Skill tool.

These stay off under the guard, since no native event can do them: the `classic.Stop` blocks in
`writing-conventions` and `session-skills`, the title from `set_session_title` in the terminal,
the rules for a Workflow's agents, the rules after a compaction in the middle of a turn, and the
voice text for `/ghostwrite` typed as a slash command.
