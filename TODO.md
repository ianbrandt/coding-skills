# To do

## Measure which `tool.call` changes are dropped under the guard on Windows

On the Windows 11 machine (the Claude Code CLI, with an `apiKeyHelper` in user settings, under
managed settings), in the probe run on 2.1.311 recorded in f2ee78b, a changed Agent prompt, a
changed Bash command, and a Grep deny landed, but context added to a Read result did not. On 2.1.310 the
Agent change had not landed either. On the Mac (the desktop app on a subscription, unmanaged, no
guard) every change lands, with or without the user plugins.

That run left five questions open, and this round answers all of them:

- The Read check passed only when Haiku repeated the marker in its reply. The probe now reads the
  session transcript on disk. A `hook_additional_context` attachment row is written when the
  engine records the context, and an `api-request-blob` row with the marker when it is sent.
- Context is now also added to a Write result, to see whether the drop is specific to Read. The
  re-read request after a Markdown Write was one of the fallbacks that did not take effect.
- The run loaded every user plugin. The probe now authenticates with project settings and the
  `apiKeyHelper` copied alone from user settings, and runs both ways.
- There was one run per case. Each setup now runs until three runs are complete.
- With one run, a fix of the Agent change in 2.1.311 looks the same as flakiness. The round also runs
  2.1.310 from npm, installed into the scratch directory and nowhere else.

The upstream issue is filed from the Mac, since this machine has no `gh`. A session on this machine
files nothing and drafts no issue text: it runs the probe and records the output here.

Everything below runs in the session through its Bash tool, with no step done by hand.

1. `git pull`, then start the round with `run_in_background` and wait for the notification. It
   takes 10 to 20 minutes, which is longer than a foreground call is allowed, and calls Haiku 9 to
   15 times:

   ```bash
   d=$(mktemp -d) && e2e/tool-call-rounds.sh "$d" > "$d.txt" 2>&1; echo "$d.txt"
   ```

   The script retries a run in which Haiku skipped a tool call by itself, and records an npm
   failure in its output rather than stopping.
2. Replace the text under `Results from Windows` below with the whole content of that `.txt` file in
   a fenced block, verbatim. If the script fails to run, for example because `claude` is not on the
   Git Bash `PATH`, record the error output there instead.
3. Commit `TODO.md` alone, with the message `Record the second Windows tool.call probe round`, and
   push it to `main`. Ian asked for this push when he set up the round, on 2026-10-26.

For comparison, the round on the Mac had three complete runs of each setup with no retries,
including 2.1.310, and every run printed the same result lines:

```
"apiKeySource":"none"
classic.PreToolUse reached the plugin: yes
agent hook ran: yes  in the subagent prompt: yes
bash  hook ran: yes  in the tool result: yes
grep  hook ran: yes  in the tool result: yes
read  hook ran: yes  attachment recorded: yes  in an API request: yes  repeated by the model: yes
write hook ran: yes  attachment recorded: yes  in an API request: yes  repeated by the model: yes
[DEBUG] cc-plugin-sec-default@builtin not seated: no managed settings and not a Team or Enterprise organization (max)
```

Before Haiku was told to quote the hook context, two runs on the Mac had the Read marker in
the API request but not in the reply. The `no` for Read in f2ee78b is therefore not proof of a
drop.

### Results from Windows

Not run yet.
