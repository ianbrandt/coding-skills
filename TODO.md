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

Not run yet.
