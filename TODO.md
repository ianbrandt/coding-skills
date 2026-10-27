# To do

## Check the plugins on Windows with no classic hooks

On 2026-10-26 every plugin in this repo moved off classic hooks, so that the
`cc-plugin-sec-default` guard has nothing to skip and prints no notice for them. In the run
before (5f10a5f), the native paths reached the model in 3 of 3 runs, but a skip notice for
`classic.SessionStart` was still printed for four plugins each session. `e2e/fallback-probe.sh` now also checks the
rules of three plugins in the main loop and counts the skip notices for the plugins in this
checkout. On the Mac, with no guard, a run on 2.1.311 printed:

```
cc-plugin-sec-default seated: no
main loop rules: writing-conventions yes  session-skills yes  orchestration-skills yes
skip notices for these plugins: 0
agent    transcripts:        1  rules: yes  subagent rule: yes
workflow transcripts:        1  rules: yes  subagent rule: yes
write re-read request as hook context: yes  in an API request: yes
skill voice data in the skill prompt: yes  as hook context: no  in an API request: no
```

Under the guard, expect the same with `seated: yes`, the voice data as hook context, and 0 skip
notices.

Everything below runs in the session through its Bash tool, with no step done by hand.

1. `git pull`, then start three runs with `run_in_background` and wait for the notification. They
   take about 10 minutes and call Sonnet three times:

   ```bash
   d=$(mktemp -d) && for i in 1 2 3; do e2e/fallback-probe.sh "$d/$i"; done > "$d.txt" 2>&1; echo "$d.txt"
   ```

2. Replace the text under `Results from Windows` below with the whole content of that `.txt` file in
   a fenced block, verbatim. If the script fails to run, record the error output there instead.
3. Commit `TODO.md` alone, with the message `Record the Windows run with no classic hooks`, and
   push it to `main` once Ian approves the push in that session.

After that, by hand: update the installed plugins from the `/plugin` menu, start a new session, and
look for a "hook was skipped" notice from any of these plugins.

### Results from Windows

```
exit 0
claude 2.1.311 (Claude Code)
cc-plugin-sec-default seated: yes
main loop rules: writing-conventions yes  session-skills yes  orchestration-skills yes
skip notices for these plugins: 1
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
2026-10-27T05:36:17.137Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T05:36:17.144Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T05:36:18.395Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.
2026-10-27T05:36:20.211Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,ghostwriting-skills,orchestration-skills,parallel-session-skills,roadmap-skills,session-skills,writing-conventions,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T05:36:20.211Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T05:36:20.213Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:36:20.213Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.3ms (native link, next() included)
2026-10-27T05:36:20.214Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 1.4ms (native link, next() included)
2026-10-27T05:36:20.214Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:36:20.214Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:36:20.214Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:36:20.214Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T05:36:20.214Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:36:20.214Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:36:20.215Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:36:20.215Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:36:20.215Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:36:20.215Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:36:20.215Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:36:20.215Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:36:20.215Z [DEBUG] plugin.register: roadmap-skills (user, roadmap-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:36:20.215Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:36:20.215Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:36:20.215Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:36:20.215Z [DEBUG] plugin.register: session-skills (user, session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:36:20.216Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:36:20.216Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:36:20.216Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:36:20.216Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:36:20.223Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T05:36:20.225Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 2.0ms (native link, next() included)
2026-10-27T05:36:20.236Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T05:36:20.237Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in parallel-session-skills#0 > cc-plugin-sec-default#18
2026-10-27T05:36:20.237Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:36:20.309Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 72.1ms (native link, next() included)
2026-10-27T05:36:20.310Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T05:36:20.355Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 44.8ms (native link, next() included)
2026-10-27T05:36:20.355Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T05:36:20.373Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 17.7ms (native link, next() included)
2026-10-27T05:36:20.375Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in roadmap-skills#0
exit 0
claude 2.1.311 (Claude Code)
cc-plugin-sec-default seated: yes
main loop rules: writing-conventions yes  session-skills yes  orchestration-skills yes
skip notices for these plugins: 1
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
2026-10-27T05:37:08.982Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T05:37:08.987Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T05:37:09.877Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.
2026-10-27T05:37:11.204Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,ghostwriting-skills,orchestration-skills,parallel-session-skills,roadmap-skills,session-skills,writing-conventions,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T05:37:11.205Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T05:37:11.206Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:11.207Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.4ms (native link, next() included)
2026-10-27T05:37:11.207Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 1.5ms (native link, next() included)
2026-10-27T05:37:11.207Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:11.207Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:11.207Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:11.207Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.5ms (native link, next() included)
2026-10-27T05:37:11.208Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:11.208Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:11.208Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:11.208Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:37:11.208Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:11.208Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:11.208Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:11.208Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:37:11.208Z [DEBUG] plugin.register: roadmap-skills (user, roadmap-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:11.209Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:11.209Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:11.209Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:37:11.209Z [DEBUG] plugin.register: session-skills (user, session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:11.209Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:11.209Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:11.209Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:37:11.209Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:11.217Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T05:37:11.219Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 2.0ms (native link, next() included)
2026-10-27T05:37:11.230Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T05:37:11.230Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in parallel-session-skills#0 > cc-plugin-sec-default#18
2026-10-27T05:37:11.231Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:11.337Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 106.8ms (native link, next() included)
2026-10-27T05:37:11.345Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T05:37:11.365Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 19.5ms (native link, next() included)
2026-10-27T05:37:11.365Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T05:37:11.392Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 27.1ms (native link, next() included)
2026-10-27T05:37:11.394Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in roadmap-skills#0
exit 0
claude 2.1.311 (Claude Code)
cc-plugin-sec-default seated: yes
main loop rules: writing-conventions yes  session-skills yes  orchestration-skills yes
skip notices for these plugins: 1
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
2026-10-27T05:37:43.849Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T05:37:43.855Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T05:37:44.729Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.
2026-10-27T05:37:46.078Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,ghostwriting-skills,orchestration-skills,parallel-session-skills,roadmap-skills,session-skills,writing-conventions,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T05:37:46.078Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T05:37:46.080Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:46.080Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.3ms (native link, next() included)
2026-10-27T05:37:46.080Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 1.5ms (native link, next() included)
2026-10-27T05:37:46.080Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:46.081Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:46.081Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:46.081Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T05:37:46.081Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:46.081Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:46.081Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:46.081Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:37:46.082Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:46.082Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:46.082Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:46.082Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:37:46.082Z [DEBUG] plugin.register: roadmap-skills (user, roadmap-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:46.082Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:46.082Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:46.082Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:37:46.082Z [DEBUG] plugin.register: session-skills (user, session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:46.083Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T05:37:46.083Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:46.083Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T05:37:46.083Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T05:37:46.090Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T05:37:46.093Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 2.0ms (native link, next() included)
2026-10-27T05:37:46.104Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T05:37:46.104Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in parallel-session-skills#0 > cc-plugin-sec-default#18
2026-10-27T05:37:46.105Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T05:37:46.177Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 73.2ms (native link, next() included)
2026-10-27T05:37:46.179Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T05:37:46.222Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 43.7ms (native link, next() included)
2026-10-27T05:37:46.223Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T05:37:46.240Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 17.1ms (native link, next() included)
2026-10-27T05:37:46.241Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in roadmap-skills#0
```

### Skip traced

The one notice in each run is `[ghostwriting-skills] skill.prompt was skipped`, taken from the
debug logs under the probe's temp directory. The hook is registered in
`plugins/ghostwriting-skills/hooks/voice.ts:119`, and a `tool.call` fallback at line 134 is the
designed path for exactly this guard case. So the plugin moved off classic hooks; the
`was skipped` regex in `e2e/fallback-probe.sh:62` is broader than classic and matches this one
too. Either narrow the regex to `classic\.` for the expected `0`, or raise the baseline in the
paragraph above to `1` with this cause named.
