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

These two are mostly rules that load at session start, so they change every session without being
invoked.

```sh
/plugin install writing-conventions@ianbrandt
/plugin install orchestration-skills@ianbrandt
```

- [`writing-conventions`](plugins/writing-conventions) changes how a session writes to you and
  when it stops to ask. Replies drop the jargon and the back-references a cold reader cannot
  follow. A decision you cannot undo comes back as a question instead of a done deal.
- [`orchestration-skills`](plugins/orchestration-skills) changes how a session hands work to other
  agents. It decides what is worth delegating and at what tier, puts scope and prohibitions in
  every brief, isolates the agents that would corrupt a shared worktree, and treats a stage that
  stopped talking as failed rather than finished.

### Add for the work you do

```sh
/plugin install ghostwriting-skills@ianbrandt
/plugin install session-skills@ianbrandt
/plugin install parallel-session-skills@ianbrandt
/plugin install roadmap-skills@ianbrandt
/plugin install gradle-skills@ianbrandt
```

- [`ghostwriting-skills`](plugins/ghostwriting-skills) drafts text that ships under your name from a
  voice spec built out of your own writing, hands each draft over for your go, and learns from your
  edits. With `writing-conventions` installed, the general rules it learns land in that plugin's
  always-on file.
- [`session-skills`](plugins/session-skills) puts a unit of work in its own git worktree and gets it
  back out again, landing it by what the repo actually is rather than by a mode you declare. It also
  carries two small session-start rules: the session-title format every session owes at its end, and
  a per-turn judgment of whether the work is better served by continuing here or handing off to a
  fresh session.
- [`parallel-session-skills`](plugins/parallel-session-skills) keeps two or three sessions off each
  other's files, through a claim ledger declaring which paths each lane will touch. It also carries
  the unattended conductor that holds several lanes open at once and refills them as they finish.
  Install it if you run more than one session against a repo at a time; it needs `session-skills`.
- [`roadmap-skills`](plugins/roadmap-skills) backs a lane with a markdown backlog: `Rn` items in
  priority order, claimed one at a time or fed to the conductor in a batch. Claiming one needs
  `session-skills`; feeding the conductor needs `parallel-session-skills` as well.
- [`gradle-skills`](plugins/gradle-skills) upgrades Gradle dependencies and the wrapper, one
  verified atomic commit at a time. Gradle builds only.

## License

Licensed under MIT. See [LICENSE.md](LICENSE.md).
