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

Not run yet.
