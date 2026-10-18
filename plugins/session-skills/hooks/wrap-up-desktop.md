## End a turn with the desktop app's `wrap_up`

**In the desktop app a turn that ran a command ends with `mcp__ccd_turn__wrap_up`, and two of its
outcomes bear on the rules above.**

- **A `wrap_up` with an `ask` ends the turn, and no text can follow it.** Write the answer, and any
  hand-off block that is due under the rules above, before that call. A recap or a question about
  text not yet written leaves the user with nothing to read.
- **A `wrap_up` without an `ask` returns "nothing is pending".** That is about the box: no decision
  waits on the user. It has no bearing on whether the session continues. After a landed unit the
  judgment above still runs, and a hand-off block goes in the closing message after the call.

**A `start_session` card does not replace the hand-off block.** The model and effort on a card are
capped at this session's own, so a hand-off to a higher tier cannot be written on one, and the card
expires after a week. Where the app also requires a card, propose it alongside the block.
