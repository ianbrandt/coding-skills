# coding-skills

A personal [Claude Code](https://claude.ai/code) plugin marketplace: topic-scoped
skills for software work, published under the `ianbrandt` marketplace.

## Install

Add the marketplace, then install the plugins below. The Claude Code Desktop plugin UI does both
without the commands.

```sh
/plugin marketplace add IanBrandt/coding-skills
```

### Start here

These two carry rules that load at session start, so they change every session without being
invoked.

```sh
/plugin install communication-skills@ianbrandt
/plugin install orchestration-skills@ianbrandt
```

- [`communication-skills`](plugins/communication-skills) changes how a session writes to you and
  when it stops to ask. Replies drop the jargon and the back-references a cold reader cannot
  follow. A decision you cannot undo comes back as a question instead of a done deal. It also
  drafts text that ships under your name from a voice spec built out of your own writing.
- [`orchestration-skills`](plugins/orchestration-skills) changes how a session hands work to other
  agents. It decides what is worth delegating and at what tier, puts scope and prohibitions in
  every brief, isolates the agents that would corrupt a shared worktree, and treats a stage that
  stopped talking as failed rather than finished.

### Add for the work you do

```sh
/plugin install session-skills@ianbrandt
/plugin install roadmap-skills@ianbrandt
/plugin install gradle-skills@ianbrandt
```

- [`session-skills`](plugins/session-skills) puts a session in its own git worktree, claims that
  lane in a ledger the other sessions read, and lands the work by what the repo actually is.
  Install it if you run more than one session against a repo at once.
- [`roadmap-skills`](plugins/roadmap-skills) backs that lane with a markdown backlog: `Rn` items in
  priority order, claimed and built one at a time. It needs `session-skills`, which owns the
  worktree and the ledger.
- [`gradle-skills`](plugins/gradle-skills) upgrades Gradle dependencies and the wrapper, one
  verified atomic commit at a time. Gradle builds only.

## License

Licensed under MIT. See [LICENSE.md](LICENSE.md).
