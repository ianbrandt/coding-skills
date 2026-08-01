# coding-skills

A personal [Claude Code](https://claude.ai/code) plugin marketplace: topic-scoped
skills for software work, published under the `ianbrandt` marketplace.

## Install

```sh
/plugin marketplace add IanBrandt/coding-skills
/plugin install gradle-skills@ianbrandt
/plugin install roadmap-skills@ianbrandt
/plugin install ghostwriting-skills@ianbrandt
```

Or add the marketplace and install plugins from the Claude Code Desktop plugin UI.

## Plugins

| Plugin | What it does |
| --- | --- |
| [`gradle-skills`](plugins/gradle-skills) | Check, upgrade, and verify Gradle dependencies and the wrapper, one atomic commit at a time. |
| [`roadmap-skills`](plugins/roadmap-skills) | Claim and build the next item on a repo's roadmap, for repos you own or OSS projects you contribute to via a fork. |
| [`ghostwriting-skills`](plugins/ghostwriting-skills) | Draft issues, PRs, comments, and docs in your voice, from a spec derived from your own hand-written samples. |

## License

Licensed under MIT. See [LICENSE.md](LICENSE.md).
