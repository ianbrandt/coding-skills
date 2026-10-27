# To do

## Measure which `tool.call` changes are dropped under the guard on Windows

On the Windows 11 machine (the Claude Code CLI with API-key auth, under managed settings), on
2.1.310, four native fallbacks did not take effect: the subagent rule on an Agent call and on a
Workflow agent, the re-read request after a Markdown Write, and the voice data after the ghostwrite
Skill. Each one changes a `tool.call`
request, or adds context to the result returned by `next()`. The checks that passed went through
`prompt.submit`, `turn.complete`, a Bash `tool.call` hook that only reads the call, and the title
tool's `tool.call` hook, which returns its own result. In the probe log, the Agent hook ran and passed
a changed prompt to `next()`, but the subagent still received the original prompt.

On the Mac (the desktop app on a subscription, unmanaged), on 2.1.311 with no guard, every
change lands. The two machines differ in OS, auth, and managed settings, so a drop on Windows alone
is tied to one of those three, most likely the guard, but which one cannot be seen in the probe output.

The upstream issue is filed from the Mac, since this machine has no `gh`. A session on this machine
files nothing and drafts no issue text: it runs the probe and records the output here.

Everything below runs in the session through its Bash tool, with no step done by hand.

1. `git pull`, then run the probe into a new empty directory. It takes about a minute and calls
   Haiku:

   ```bash
   e2e/tool-call-probe.sh "$(mktemp -d)"
   ```

2. Each of Agent, Bash, Grep, and Read should be listed once under `Tool calls in the
   transcript`. If one is missing, Haiku skipped it: run the probe again into a new directory, up to
   three runs, and keep the output of the first complete run. If a run fails to authenticate, the
   API key is probably set in user settings, which the probe leaves out by default: run it again
   with `PROBE_SETTING_SOURCES=user,project` before the command, and say so with the results.
3. Replace the text under `Results from Windows` below with the probe's whole output in a fenced
   block, verbatim, and the Windows version from `cmd //c ver`. If the probe fails to run, for
   example because `claude` is not on the Git Bash `PATH`, record the error output there instead.
4. Commit `TODO.md` alone, with the message `Record the Windows tool.call probe results`, and push
   it to `main`. Ian asked for this push when he set up the run, on 2026-10-26.

For comparison, this is the run on the Mac:

```
claude 2.1.311 (Claude Code)
"apiKeySource":"none"
classic.PreToolUse reached the plugin: yes
agent hook ran: yes  change reached the model: yes
bash  hook ran: yes  change reached the model: yes
grep  hook ran: yes  change reached the model: yes
read  hook ran: yes  change reached the model: yes
[DEBUG] cc-plugin-sec-default@builtin not seated: no managed settings and not a Team or Enterprise organization (max)
```

### Results from Windows

Microsoft Windows [Version 10.0.22631.7652]

The first two runs with the default settings sources failed to authenticate (`"apiKeySource":"none"`,
exit 1, no tool calls in the transcript), so the third was run with
`PROBE_SETTING_SOURCES=user,project`:

```
exit 0
claude 2.1.311 (Claude Code)
"apiKeySource":"apiKeyHelper"
classic.PreToolUse reached the plugin: no
agent hook ran: yes  change reached the model: yes
bash  hook ran: yes  change reached the model: yes
grep  hook ran: yes  change reached the model: yes
read  hook ran: yes  change reached the model: no
Tool calls in the transcript:
      1 Agent
      1 Bash
      1 Grep
      1 Read
      1 SubagentHandback
Debug log lines that mention the guard or the probe plugin:
2026-10-27T02:19:55.287Z [DEBUG] Ignoring dangerous permission Agent(*) from cliArg (bypasses classifier)
2026-10-27T02:19:55.287Z [DEBUG] Ignoring dangerous permission Bash(*) from cliArg (bypasses classifier)
2026-10-27T02:19:55.403Z [DEBUG] Read hooks.json for plugin tool-call-probe (enabled=true): C:\Dev\Temp\tmp.8wdNRVytEu\plug\hooks\hooks.json
2026-10-27T02:19:55.405Z [DEBUG] Loaded inline plugin from path: tool-call-probe
2026-10-27T02:19:55.419Z [DEBUG] Checking plugin tool-call-probe: skillsPath=none, skillsPaths=0 paths
2026-10-27T02:19:55.420Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T02:19:55.428Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T02:19:57.727Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.describe,agent.offer,agent.spawn,tool.register,tool.list,tool.check,ui.log,env.get,env.set,plugin.register
2026-10-27T02:19:57.775Z [DEBUG] hooks module tool-call-probe@inline loaded (worker, environment 2, tier user); events: classic.PreToolUse,tool.call
2026-10-27T02:19:57.839Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,tool-call-probe,ponytail,orchestration-skills,session-skills,powershell,writing-conventions,ghostwriting-skills,parallel-session-skills,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T02:19:57.839Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T02:19:57.841Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T02:19:57.842Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.3ms (native link, next() included)
2026-10-27T02:19:57.842Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 1.8ms (native link, next() included)
2026-10-27T02:19:57.842Z [DEBUG] plugin.register: tool-call-probe (user, tool-call-probe@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T02:19:57.842Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T02:19:57.842Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T02:19:57.842Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T02:19:57.842Z [DEBUG] plugin.register: ponytail (user, ponytail@ponytail), judged by cc-plugin-sec-default: admitted
2026-10-27T02:19:57.843Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T02:19:57.843Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T02:19:57.843Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T02:19:57.843Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@ianbrandt), judged by cc-plugin-sec-default: admitted
2026-10-27T02:19:57.843Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T02:19:57.843Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T02:19:57.843Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T02:19:57.843Z [DEBUG] plugin.register: session-skills (user, session-skills@ianbrandt), judged by cc-plugin-sec-default: admitted
2026-10-27T02:19:57.843Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T02:19:57.844Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T02:19:57.844Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T02:19:57.844Z [DEBUG] plugin.register: powershell (user, powershell@jre-team), judged by cc-plugin-sec-default: admitted
2026-10-27T02:19:57.844Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T02:19:57.844Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T02:19:57.844Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T02:19:57.844Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@ianbrandt), judged by cc-plugin-sec-default: admitted
2026-10-27T02:19:57.844Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T02:19:57.844Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T02:19:57.844Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T02:19:57.844Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@ianbrandt), judged by cc-plugin-sec-default: admitted
2026-10-27T02:19:57.845Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T02:19:57.845Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T02:19:57.845Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T02:19:57.845Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@ianbrandt), judged by cc-plugin-sec-default: admitted
2026-10-27T02:19:57.853Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T02:19:57.854Z [DEBUG] orchestration-skills+session-skills+powershell+writing-conventions: classic.SessionStart bypassed by cc-plugin-sec-default (tier user); beneath runs
2026-10-27T02:19:57.854Z [DEBUG] [orchestration-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T02:19:57.855Z [DEBUG] [session-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T02:19:57.855Z [DEBUG] [powershell] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T02:19:57.855Z [DEBUG] [writing-conventions] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T02:19:57.857Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 3.8ms (native link, next() included)
2026-10-27T02:19:58.617Z [DEBUG] hooks module cc-plugin-sec-default@builtin classic.SessionStart settled in 763.0ms (native link, next() included)
2026-10-27T02:20:03.314Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in session-skills#0
2026-10-27T02:20:03.314Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in session-skills#0 > cc-plugin-sec-default#18
2026-10-27T02:20:03.314Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.2ms (native link, next() included)
2026-10-27T02:20:03.422Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 108.7ms (native link, next() included)
2026-10-27T02:20:03.423Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in session-skills#0
2026-10-27T02:20:03.509Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 85.8ms (native link, next() included)
2026-10-27T02:20:03.510Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 20.7ms (native link, next() included)
```
