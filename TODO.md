# To do

## Check the plugins on Windows with no skipped hooks

On 2026-10-26 every plugin in this repo moved off classic hooks, so that the
`cc-plugin-sec-default` guard has nothing to skip and prints no notice for them. In the run
before (5f10a5f), the native paths reached the model in 3 of 3 runs, but a skip notice for
`classic.SessionStart` was still printed for four plugins each session. In the next run (262cd22),
one notice was printed in each of three runs, for the `skill.prompt` hook in ghostwriting-skills.
That hook is now removed, and the voice data is added beside the Skill tool's result alone.
`e2e/fallback-probe.sh` also checks the rules of three plugins in the main loop and counts the skip
notices for the plugins in this checkout. On the Mac, with no guard, a run on 2.1.311 printed:

```
cc-plugin-sec-default seated: no
main loop rules: writing-conventions yes  session-skills yes  orchestration-skills yes
skip notices for these plugins: 0
agent    transcripts:        1  rules: yes  subagent rule: yes
workflow transcripts:        1  rules: yes  subagent rule: yes
write re-read request as hook context: yes  in an API request: yes
skill voice data in the skill prompt: no  as hook context: yes  in an API request: yes
```

Under the guard, expect the same with `seated: yes`.

Everything below runs in the session through its Bash tool, with no step done by hand.

1. `git pull`, then start three runs with `run_in_background` and wait for the notification. They
   take about 10 minutes and call Sonnet three times:

   ```bash
   d=$(mktemp -d) && for i in 1 2 3; do e2e/fallback-probe.sh "$d/$i"; done > "$d.txt" 2>&1; echo "$d.txt"
   ```

2. Replace the text under `Results from Windows` below with the whole content of that `.txt` file in
   a fenced block, verbatim. If the script fails to run, record the error output there instead.
3. Commit `TODO.md` alone, with the message `Record the Windows run with no skipped hooks`, and
   push it to `main` once Ian approves the push in that session.

After that, by hand: update the installed plugins from the `/plugin` menu, start a new session, and
look for a "hook was skipped" notice from any of these plugins.

### Results from Windows

```
exit 0
claude 2.1.311 (Claude Code)
cc-plugin-sec-default seated: yes
main loop rules: writing-conventions yes  session-skills yes  orchestration-skills yes
skip notices for these plugins: 0
agent    transcripts: 1  rules: yes  subagent rule: yes
workflow transcripts: 1  rules: yes  subagent rule: yes
write re-read request as hook context: yes  in an API request: yes
skill voice data in the skill prompt: no  as hook context: yes  in an API request: yes
Tool calls in the output stream, the agents included:
      1 Agent
      1 Bash
      1 Skill
      1 Workflow
      1 Write
Debug log lines that mention the guard:
2026-10-27T15:43:00.501Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T15:43:00.507Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T15:43:03.467Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.
2026-10-27T15:43:03.579Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,ghostwriting-skills,orchestration-skills,parallel-session-skills,roadmap-skills,session-skills,writing-conventions,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T15:43:03.579Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T15:43:03.581Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:03.582Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.5ms (native link, next() included)
2026-10-27T15:43:03.582Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 2.2ms (native link, next() included)
2026-10-27T15:43:03.582Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:03.583Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:03.583Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.2ms (native link, next() included)
2026-10-27T15:43:03.583Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.6ms (native link, next() included)
2026-10-27T15:43:03.583Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:03.584Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:03.584Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:43:03.584Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.5ms (native link, next() included)
2026-10-27T15:43:03.584Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:03.584Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:03.584Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:43:03.585Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T15:43:03.585Z [DEBUG] plugin.register: roadmap-skills (user, roadmap-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:03.585Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:03.585Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:43:03.585Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T15:43:03.585Z [DEBUG] plugin.register: session-skills (user, session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:03.585Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:03.586Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:43:03.586Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T15:43:03.586Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:03.599Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T15:43:03.602Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 3.7ms (native link, next() included)
2026-10-27T15:43:03.620Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T15:43:03.622Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in parallel-session-skills#0 > cc-plugin-sec-default#18
2026-10-27T15:43:03.622Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.3ms (native link, next() included)
2026-10-27T15:43:03.808Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 187.7ms (native link, next() included)
2026-10-27T15:43:03.810Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T15:43:03.854Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 44.4ms (native link, next() included)
2026-10-27T15:43:03.857Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T15:43:03.881Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 24.3ms (native link, next() included)
2026-10-27T15:43:03.884Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in roadmap-skills#0
exit 0
claude 2.1.311 (Claude Code)
cc-plugin-sec-default seated: yes
main loop rules: writing-conventions yes  session-skills yes  orchestration-skills yes
skip notices for these plugins: 0
agent    transcripts: 1  rules: yes  subagent rule: yes
workflow transcripts: 1  rules: yes  subagent rule: yes
write re-read request as hook context: yes  in an API request: yes
skill voice data in the skill prompt: no  as hook context: yes  in an API request: yes
Tool calls in the output stream, the agents included:
      1 Agent
      1 Bash
      1 Skill
      1 Workflow
      1 Write
Debug log lines that mention the guard:
2026-10-27T15:43:52.345Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T15:43:52.352Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T15:43:54.707Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.
2026-10-27T15:43:54.820Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,ghostwriting-skills,orchestration-skills,parallel-session-skills,roadmap-skills,session-skills,writing-conventions,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T15:43:54.821Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T15:43:54.823Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:54.824Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.5ms (native link, next() included)
2026-10-27T15:43:54.824Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 2.0ms (native link, next() included)
2026-10-27T15:43:54.824Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:54.824Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:54.825Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.2ms (native link, next() included)
2026-10-27T15:43:54.825Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.7ms (native link, next() included)
2026-10-27T15:43:54.825Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:54.825Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:54.825Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:43:54.825Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.5ms (native link, next() included)
2026-10-27T15:43:54.826Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:54.826Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:54.826Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.2ms (native link, next() included)
2026-10-27T15:43:54.826Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.6ms (native link, next() included)
2026-10-27T15:43:54.826Z [DEBUG] plugin.register: roadmap-skills (user, roadmap-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:54.827Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:54.827Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:43:54.827Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.5ms (native link, next() included)
2026-10-27T15:43:54.827Z [DEBUG] plugin.register: session-skills (user, session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:54.827Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:43:54.828Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:43:54.828Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T15:43:54.828Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:43:54.840Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T15:43:54.843Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 2.9ms (native link, next() included)
2026-10-27T15:43:54.858Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T15:43:54.858Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in parallel-session-skills#0 > cc-plugin-sec-default#18
2026-10-27T15:43:54.859Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.2ms (native link, next() included)
2026-10-27T15:43:54.988Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 129.8ms (native link, next() included)
2026-10-27T15:43:54.990Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T15:43:55.017Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 27.3ms (native link, next() included)
2026-10-27T15:43:55.020Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T15:43:55.048Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 28.2ms (native link, next() included)
2026-10-27T15:43:55.050Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in roadmap-skills#0
exit 0
claude 2.1.311 (Claude Code)
cc-plugin-sec-default seated: yes
main loop rules: writing-conventions yes  session-skills yes  orchestration-skills yes
skip notices for these plugins: 0
agent    transcripts: 1  rules: yes  subagent rule: yes
workflow transcripts: 1  rules: yes  subagent rule: yes
write re-read request as hook context: yes  in an API request: yes
skill voice data in the skill prompt: no  as hook context: yes  in an API request: yes
Tool calls in the output stream, the agents included:
      1 Agent
      1 Bash
      1 Skill
      1 Workflow
      1 Write
Debug log lines that mention the guard:
2026-10-27T15:44:49.329Z [DEBUG] Checking plugin cc-plugin-sec-default: skillsPath=none, skillsPaths=0 paths
2026-10-27T15:44:49.339Z [DEBUG] cc-plugin-sec-default@builtin seated outermost: this machine has managed settings
2026-10-27T15:44:50.650Z [DEBUG] hooks module cc-plugin-sec-default@builtin loaded (native, environment 1, tier prepend); events: classic.*,prompt.section,prompt.context,prompt.attachment,prompt.compose,skill.prompt,attribution.text,session.append,session.compact,settings.read,tool.describe,command.
2026-10-27T15:44:52.436Z [DEBUG] engine.create: no plugin-provided interfaces; $ built for cc-plugin-sec-default,ghostwriting-skills,orchestration-skills,parallel-session-skills,roadmap-skills,session-skills,writing-conventions,cc-plugin-agents-md,cc-plugin-plugin-authoring
2026-10-27T15:44:52.436Z [DEBUG] plugin.register: cc-plugin-sec-default (prepend, cc-plugin-sec-default@builtin), judged by core alone: admitted
2026-10-27T15:44:52.438Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:44:52.438Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.3ms (native link, next() included)
2026-10-27T15:44:52.439Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 1.5ms (native link, next() included)
2026-10-27T15:44:52.439Z [DEBUG] plugin.register: ghostwriting-skills (user, ghostwriting-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:44:52.439Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:44:52.439Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:44:52.439Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.4ms (native link, next() included)
2026-10-27T15:44:52.439Z [DEBUG] plugin.register: orchestration-skills (user, orchestration-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:44:52.440Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:44:52.440Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:44:52.440Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T15:44:52.440Z [DEBUG] plugin.register: parallel-session-skills (user, parallel-session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:44:52.440Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:44:52.440Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:44:52.440Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T15:44:52.440Z [DEBUG] plugin.register: roadmap-skills (user, roadmap-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:44:52.440Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:44:52.440Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:44:52.441Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T15:44:52.441Z [DEBUG] plugin.register: session-skills (user, session-skills@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:44:52.441Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in cc-plugin-sec-default#24
2026-10-27T15:44:52.441Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:44:52.441Z [DEBUG] hooks module cc-plugin-sec-default@builtin plugin.register settled in 0.3ms (native link, next() included)
2026-10-27T15:44:52.441Z [DEBUG] plugin.register: writing-conventions (user, writing-conventions@inline), judged by cc-plugin-sec-default: admitted
2026-10-27T15:44:52.449Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in
2026-10-27T15:44:52.451Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 2.1ms (native link, next() included)
2026-10-27T15:44:52.463Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T15:44:52.464Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): settings.read nested in parallel-session-skills#0 > cc-plugin-sec-default#18
2026-10-27T15:44:52.464Z [DEBUG] hooks module cc-plugin-sec-default@builtin settings.read settled in 0.1ms (native link, next() included)
2026-10-27T15:44:52.565Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 101.4ms (native link, next() included)
2026-10-27T15:44:52.566Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T15:44:52.587Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 20.5ms (native link, next() included)
2026-10-27T15:44:52.588Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in parallel-session-skills#0
2026-10-27T15:44:52.607Z [DEBUG] hooks module cc-plugin-sec-default@builtin tool.register settled in 19.5ms (native link, next() included)
2026-10-27T15:44:52.609Z [DEBUG] hooks module cc-plugin-sec-default@builtin (native): tool.register nested in roadmap-skills#0
```
