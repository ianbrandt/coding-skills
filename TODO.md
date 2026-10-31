# To do

## Needs a Windows machine under managed settings

Check the follow-ups that no longer submit a prompt under the real `cc-plugin-sec-default` guard.
Their events are not in the guard's source, but the guard cannot be seated on the Mac. Update the
plugins first, then run this in Git Bash from a checkout of this repo:

```bash
e2e/followup-probe.sh "$TEMP/followup-1"
```

The run passes with 0 plugin prompts, at least 1 next-step request, and a final reply that has a
draft. Run it again if the hook made 0 lint calls, since a clean draft does not test the rewrite.

Then in an interactive `claude` session, ask for any small task and confirm that a `/rename` line
appears at the end of the first turn, with the session title set. Report the results in a session
here, and clear this item.
