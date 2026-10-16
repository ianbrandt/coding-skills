# Roadmap laps

A lap is one headless session that claims, builds, and lands an item in a scratch repo, with every
plugin loaded from this checkout. Laps are the check that `roadmap-skills`, `session-skills`, and
`parallel-session-skills` work together: their unit tests in `test.sh` run against mocked git and
model calls. A lap takes about a minute and calls a model, so run laps before a push that changes
how those plugins claim, open, or land work, not on every commit.

```bash
laps/lap.sh first /tmp/lap-1
```

- `first` starts in the repo root with `/roadmap-skills:next-roadmap-item R1`.
- `resume` starts inside a worktree for R2 that already has half of the item committed, with
  `/roadmap-skills:next-roadmap-item R2`. The session has to adopt that worktree rather than open a
  second one.

[`setup.sh`](setup.sh) builds the scratch repo: a bare `origin.git`, a two-item local-only roadmap,
and `session-skills.landing merge`, so a lap fast-forwards `main` and holds the push. The session
transcript goes to `<dir>/lap.jsonl` and the repo's state after the lap to `<dir>/state.txt`.
`python3 laps/calls.py <dir>/lap.jsonl` prints the plugins loaded and each tool call with the first
line of its result.

A lap passes when:

- every plugin is listed as `<name>@inline` in the init event, and none as `@ianbrandt`;
- the item is built and fast-forwarded into `main`, and `origin.git` is unchanged;
- the item is gone from the roadmap and has a done-record in the changelog;
- the claim is released and the worktree removed, with no Bash command run in place of a plugin
  tool, and no tool errors except a denied call to a session-title tool, which is not allowed in a
  lap.

Run several laps of a kind before trusting a pass, one at a time, since a session given the same
prompt does not always make the same calls.
