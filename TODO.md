# To do

## Measure which `tool.call` changes are dropped under the guard on Windows

On the managed-settings Windows 11 machine, on Claude Code 2.1.310, four native fallbacks did not
take effect: the subagent rule on an Agent call and on a Workflow agent, the re-read request after a
Markdown Write, and the voice data after the ghostwrite Skill. Each one changes a `tool.call`
request, or adds context to the result returned by `next()`. The checks that passed went through
`prompt.submit`, `turn.complete`, a Bash `tool.call` hook that only reads the call, and the title
tool's `tool.call` hook, which returns its own result. In the probe log, the Agent hook ran and passed
a changed prompt to `next()`, but the subagent still received the original prompt.

On macOS, on 2.1.311 with no guard, every change lands, so the drop is tied to the guard or to
Windows. The upstream issue is filed from the Mac, since this machine has no `gh`. A session on this
machine files nothing and drafts no issue text: it runs the probe and records the output here.

Everything below runs in the session through its Bash tool, with no step done by hand.

1. `git pull`, then run the probe into a new empty directory. It takes about a minute and calls
   Haiku:

   ```bash
   e2e/tool-call-probe.sh "$(mktemp -d)"
   ```

2. Each of Agent, Bash, Grep, and Read should be listed once under `Tool calls in the
   transcript`. If one is missing, Haiku skipped it: run the probe again into a new directory, up to
   three runs, and keep the output of the first complete run.
3. Replace the text under `Results from Windows` below with the probe's whole output in a fenced
   block, verbatim, and the Windows version from `cmd //c ver`. If the probe fails to run, for
   example because `claude` is not on the Git Bash `PATH`, record the error output there instead.
4. Commit `TODO.md` alone, with the message `Record the Windows tool.call probe results`, and push
   it to `main`. Ian asked for this push when he set up the run, on 2026-10-26.

For comparison, this is the run on the Mac:

```
claude 2.1.311 (Claude Code)
classic.PreToolUse reached the plugin: yes
agent hook ran: yes  change reached the model: yes
bash  hook ran: yes  change reached the model: yes
grep  hook ran: yes  change reached the model: yes
read  hook ran: yes  change reached the model: yes
[DEBUG] cc-plugin-sec-default@builtin not seated: no managed settings and not a Team or Enterprise organization (max)
```

### Results from Windows

Not run yet.
