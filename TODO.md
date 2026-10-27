# To do

## Re-run the four failed fallback checks on Windows

On the Windows 11 machine, four checks of the plugin fallbacks under the `cc-plugin-sec-default`
guard failed on 2.1.310: the rules in an Agent subagent's task, the rules in a Workflow agent, the
re-read request after a Markdown Write, and the voice data beside the ghostwrite Skill's result.
Each was judged by whether the model quoted the text back. In the `tool.call` probe on the same
machine (a44d6ec), a changed Agent prompt and context added to a Write result reached the model in
all nine runs on 2.1.310 and 2.1.311, but in four of them the model did not quote the Write context.
So the four failures may be the same false negative.

`e2e/fallback-probe.sh` runs the four checks in one headless session with every plugin loaded from
this checkout, and looks each text up in the session transcripts. Under the guard the voice data is
expected as hook context rather than in the skill prompt. On the Mac, with no guard, a run printed:

```
cc-plugin-sec-default seated: no
agent    transcripts:        1  rules: yes  subagent rule: yes
workflow transcripts:        1  rules: yes  subagent rule: yes
write re-read request as hook context: yes  in an API request: yes
skill voice data in the skill prompt: yes  as hook context: no  in an API request: no
```

Everything below runs in the session through its Bash tool, with no step done by hand.

1. `git pull`, then start three runs with `run_in_background` and wait for the notification. They
   take about 10 minutes and call Sonnet three times:

   ```bash
   d=$(mktemp -d) && for i in 1 2 3; do e2e/fallback-probe.sh "$d/$i"; done > "$d.txt" 2>&1; echo "$d.txt"
   ```

2. Replace the text under `Results from Windows` below with the whole content of that `.txt` file in
   a fenced block, verbatim. If the script fails to run, record the error output there instead.
3. Commit `TODO.md` alone, with the message `Record the Windows fallback probe results`, and push
   it to `main`. Ian asked for this push when he set up the run, on 2026-10-27.

### Results from Windows

```
exit 0
claude 2.1.311 (Claude Code)
cc-plugin-sec-default seated: yes
agent    transcripts: 1  rules: yes  subagent rule: yes
workflow transcripts: 1  rules: yes  subagent rule: yes
write re-read request as hook context: yes  in an API request: yes
skill voice data in the skill prompt: yes  as hook context: yes  in an API request: yes
Tool calls in the output stream, the agents included:
      1 Agent
      1 Bash
      1 Skill
      1 Workflow
      1 Write
Debug log lines that mention the guard:
2026-10-27T04:42:14.891Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T04:42:14.896Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T04:42:15.809Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.
2026-10-27T04:42:17.375Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,ghostwriting-skills,orchestration-skills,parallel-session-skills,roadmap-skills,session-skills,writing-conventions,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T04:42:17.376Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T04:42:17.378Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:42:17.378Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.4ms (native link, next() included)
2026-10-27T04:42:17.378Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 1.9ms (native link, next() included)
2026-10-27T04:42:17.378Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:42:17.379Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:42:17.379Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:42:17.379Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.6ms (native link, next() included)
2026-10-27T04:42:17.379Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:42:17.379Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:42:17.380Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:42:17.380Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T04:42:17.380Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:42:17.380Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:42:17.380Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:42:17.380Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T04:42:17.380Z [DEBUG] plugin.register: roadmap-skills (user, roadmap-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:42:17.381Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:42:17.381Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:42:17.381Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T04:42:17.381Z [DEBUG] plugin.register: session-skills (user, session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:42:17.381Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:42:17.381Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:42:17.381Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T04:42:17.382Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:42:17.392Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T04:42:17.392Z [DEBUG] orchestration-skills+roadmap-skills+session-skills+writing-conventions: classic.SessionStart bypassed by cc-plugin-sec-default (tier user); beneath runs
2026-10-27T04:42:17.393Z [DEBUG] [orchestration-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:42:17.394Z [DEBUG] [roadmap-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:42:17.394Z [DEBUG] [session-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:42:17.394Z [DEBUG] [writing-conventions] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:42:17.395Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 3.1ms (native link, next() included)
2026-10-27T04:42:17.395Z [DEBUG] hooks module cc-plugin-sec-default@builtin classic.SessionStart settled in 3.0ms (native link, next() included)
2026-10-27T04:42:17.414Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T04:42:17.415Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in parallel-session-skills#0 > cc-plugin-sec-default#18
2026-10-27T04:42:17.415Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.2ms (native link, next() included)
exit 0
claude 2.1.311 (Claude Code)
cc-plugin-sec-default seated: yes
agent    transcripts: 1  rules: yes  subagent rule: yes
workflow transcripts: 1  rules: yes  subagent rule: yes
write re-read request as hook context: yes  in an API request: yes
skill voice data in the skill prompt: yes  as hook context: yes  in an API request: yes
Tool calls in the output stream, the agents included:
      1 Agent
      1 Bash
      1 Skill
      1 Workflow
      1 Write
Debug log lines that mention the guard:
2026-10-27T04:42:58.159Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T04:42:58.164Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T04:42:59.032Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.
2026-10-27T04:43:00.360Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,ghostwriting-skills,orchestration-skills,parallel-session-skills,roadmap-skills,session-skills,writing-conventions,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T04:43:00.361Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T04:43:00.362Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:00.363Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.4ms (native link, next() included)
2026-10-27T04:43:00.363Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 1.5ms (native link, next() included)
2026-10-27T04:43:00.363Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:00.363Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:00.363Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:00.364Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T04:43:00.364Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:00.364Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:00.364Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:00.364Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T04:43:00.364Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:00.364Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:00.364Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:00.364Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T04:43:00.365Z [DEBUG] plugin.register: roadmap-skills (user, roadmap-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:00.365Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:00.365Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:00.365Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T04:43:00.365Z [DEBUG] plugin.register: session-skills (user, session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:00.365Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:00.365Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:00.365Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T04:43:00.365Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:00.373Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T04:43:00.373Z [DEBUG] orchestration-skills+roadmap-skills+session-skills+writing-conventions: classic.SessionStart bypassed by cc-plugin-sec-default (tier user); beneath runs
2026-10-27T04:43:00.374Z [DEBUG] [orchestration-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:43:00.375Z [DEBUG] [roadmap-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:43:00.375Z [DEBUG] [session-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:43:00.375Z [DEBUG] [writing-conventions] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:43:00.375Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 2.3ms (native link, next() included)
2026-10-27T04:43:00.375Z [DEBUG] hooks module cc-plugin-sec-default@builtin classic.SessionStart settled in 2.3ms (native link, next() included)
2026-10-27T04:43:00.390Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T04:43:00.390Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in parallel-session-skills#0 > cc-plugin-sec-default#18
2026-10-27T04:43:00.390Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
exit 0
claude 2.1.311 (Claude Code)
cc-plugin-sec-default seated: yes
agent    transcripts: 1  rules: yes  subagent rule: yes
workflow transcripts: 1  rules: yes  subagent rule: yes
write re-read request as hook context: yes  in an API request: yes
skill voice data in the skill prompt: yes  as hook context: yes  in an API request: yes
Tool calls in the output stream, the agents included:
      2 Agent
      1 Bash
      1 Skill
      1 Workflow
      1 Write
Debug log lines that mention the guard:
2026-10-27T04:43:39.590Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T04:43:39.596Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T04:43:40.548Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.
2026-10-27T04:43:41.888Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,ghostwriting-skills,orchestration-skills,parallel-session-skills,roadmap-skills,session-skills,writing-conventions,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T04:43:41.889Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T04:43:41.890Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:41.891Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.4ms (native link, next() included)
2026-10-27T04:43:41.891Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 1.5ms (native link, next() included)
2026-10-27T04:43:41.891Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:41.891Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:41.891Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:41.891Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T04:43:41.891Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:41.892Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:41.892Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:41.892Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T04:43:41.892Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:41.892Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:41.892Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:41.892Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T04:43:41.892Z [DEBUG] plugin.register: roadmap-skills (user, roadmap-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:41.893Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:41.893Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:41.893Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T04:43:41.893Z [DEBUG] plugin.register: session-skills (user, session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:41.893Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T04:43:41.893Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T04:43:41.893Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T04:43:41.893Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T04:43:41.901Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T04:43:41.901Z [DEBUG] orchestration-skills+roadmap-skills+session-skills+writing-conventions: classic.SessionStart bypassed by cc-plugin-sec-default (tier user); beneath runs
2026-10-27T04:43:41.902Z [DEBUG] [orchestration-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:43:41.903Z [DEBUG] [roadmap-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:43:41.903Z [DEBUG] [session-skills] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:43:41.903Z [DEBUG] [writing-conventions] $.ui.log: its classic.SessionStart hook was skipped. "cc-plugin-sec-default" runs first and sent the event on past it.
2026-10-27T04:43:41.903Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 2.3ms (native link, next() included)
2026-10-27T04:43:41.903Z [DEBUG] hooks module cc-plugin-sec-default@builtin classic.SessionStart settled in 2.2ms (native link, next() included)
2026-10-27T04:43:41.918Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T04:43:41.918Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in parallel-session-skills#0 > cc-plugin-sec-default#18
2026-10-27T04:43:41.918Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
```
