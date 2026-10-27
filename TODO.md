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

Not run yet.
