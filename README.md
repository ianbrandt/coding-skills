# coding-skills

A personal [Claude Code](https://claude.ai/code) plugin marketplace: topic-scoped
skills for software work, published under the `ianbrandt` marketplace.

## Install

```sh
/plugin marketplace add IanBrandt/coding-skills
/plugin install gradle-skills@ianbrandt
/plugin install roadmap-skills@ianbrandt
/plugin install session-skills@ianbrandt
/plugin install communication-skills@ianbrandt
/plugin install orchestration-skills@ianbrandt
```

Or add the marketplace and install plugins from the Claude Code Desktop plugin UI.

## Plugins

| Plugin | What it does |
| --- | --- |
| [`gradle-skills`](plugins/gradle-skills) | Check, upgrade, and verify Gradle dependencies and the wrapper, one atomic commit at a time. |
| [`roadmap-skills`](plugins/roadmap-skills) | Claim and build the next item on a repo's roadmap, for repos you own or OSS projects you contribute to via a fork. |
| [`session-skills`](plugins/session-skills) | Get into a worktree lane without colliding with the other sessions, claim it in a shared ledger, and land the work by what the repo actually is. |
| [`communication-skills`](plugins/communication-skills) | Write to you so a cold reader can follow it, write as you when the text ships under your name, and stop to ask before decisions you cannot undo. |
| [`orchestration-skills`](plugins/orchestration-skills) | Hand work to other agents without losing control of it: what to delegate, what every brief must carry, which agents worktree isolation breaks, and how to tell a finished stage from one that stopped talking. |

## License

Licensed under MIT. See [LICENSE.md](LICENSE.md).
