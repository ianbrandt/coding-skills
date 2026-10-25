# To do

## Needs a Windows machine

On a machine with managed settings, the built-in `cc-plugin-sec-default` plugin sends every
`classic.*` event and `skill.prompt` past user plugins. The guard code is the same in 2.1.308,
2.1.309, and 2.1.310. The classic hooks are still the main path, and the native fallbacks run only
where the classic events do not reach a plugin: the rules as `prompt.submit` context where
`classic.SessionStart` did not run, re-added once the model no longer reads them, and the subagent
rules prepended to an Agent `tool.call` where no classic event has arrived yet. The per-turn style
reminder, the Write/Edit check, and the next-step check after a push run on native events only. The
ghostwriting voice text comes back beside the Skill tool's result when `skill.prompt` does not run.
The fallbacks were checked on macOS with a copy of the guard in the plugin test kit, not under the
real guard.

On the work machine, after updating the plugins, start a session and check seven things:

1. The first reply follows the session rules, and `/compact` followed by a prompt brings them back.
2. A subagent started with the Agent tool can quote `WRITING CONVENTIONS ACTIVE` and the line
   `You are a subagent with no user to ask` from its task.
3. Writing a Markdown file with Write prints the re-read request in the tool result.
4. The voice spec is added once when `ghostwrite` runs through the Skill tool.
5. A second prompt opens with the `Style, for this reply` reminder.
6. In the terminal, a request for a session title gets an error from `set_session_title` and a
   printed `/rename` block.
7. A turn that runs `git push` and ends with no fenced block is followed by one prompt from
   `session-skills` asking for the next step.

These stay off under the guard, since no native event can do them: the `classic.Stop` blocks in
`writing-conventions`, the title from `set_session_title` in the terminal, the rules for a
Workflow's agents, the rules after a compaction in the middle of a turn, and the voice text for
`/ghostwrite` typed as a slash command.
