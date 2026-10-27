# End-to-end tests

Each test is one headless session that claims, builds, and lands an item in a scratch repo, with
every plugin loaded from this checkout. These tests are the check that `roadmap-skills`,
`session-skills`, and `parallel-session-skills` work together: their unit tests in `test.sh` run
against mocked git and model calls. A test takes about a minute and calls a model, so run them
before a push that changes how those plugins claim, open, or land work, not on every commit.

```bash
e2e/run.sh first /tmp/e2e-1
```

- `first` starts in the repo root with `/roadmap-skills:next-roadmap-item R1`.
- `resume` starts inside a worktree for R2 that already has half of the item committed, with
  `/roadmap-skills:next-roadmap-item R2`. The session has to adopt that worktree rather than open a
  second one.

[`setup.sh`](setup.sh) builds the scratch repo: a bare `origin.git`, a two-item local-only roadmap,
and `session-skills.landing merge`, so the item is fast-forwarded into `main` and the push is held.
The session transcript goes to `<dir>/session.jsonl` and the repo's state afterward to
`<dir>/state.txt`. `python3 e2e/calls.py <dir>/session.jsonl` prints the plugins loaded and each
tool call with the first line of its result.

A test passes when:

- every plugin is listed as `<name>@inline` in the init event, and none as `@ianbrandt`;
- the item is built and fast-forwarded into `main`, and `origin.git` is unchanged;
- the item is gone from the roadmap and has a done-record in the changelog;
- the claim is released and the worktree removed, with no error from a plugin tool and no Bash
  command run in place of one.

Run each kind several times before trusting a pass, one at a time, since a session given the same
prompt does not always make the same calls.

## The `tool.call` probe

[`tool-call-probe.sh`](tool-call-probe.sh) is a separate check, for the `cc-plugin-sec-default`
guard: one headless session with a scratch plugin that changes an Agent prompt, a Bash command, and
a Read result, and denies a Grep call. For each case it prints whether the hook ran and whether the
change reached the model, then the debug log lines about the guard.

```bash
e2e/tool-call-probe.sh /tmp/probe-1
```
