---
status: current
module: plugin-bot
category: architecture
created: 2026-07-10
updated: 2026-09-07
last-synced: 2026-09-07
completeness: 85
related:
  - ../demo/architecture.md
  - upstream-docs.md
dependencies: []
implementation-plans:
  - ../plans/plugin-bot-skills-phase1.md
---

# plugin-bot - Architecture

An agent plugin, developed in this repo at `plugins/plugin-bot/`, whose job is helping develop agent plugins — for Claude Code and for GitHub Copilot.

## Table of contents

1. [Overview](#overview)
2. [Current State](#current-state)
3. [Rationale](#rationale)
4. [Development workflow](#development-workflow)
5. [Future enhancements](#future-enhancements)
6. [Related documentation](#related-documentation)

---

## Overview

plugin-bot is the first plugin that originates in this repo rather than being pulled in from another repo via the marketplace manifest (`.claude-plugin/marketplace.json`). It began as a migration of a user-folder agent/skill combo — the `plugin-bash-engineer` agent and its family of path-based `cc-*` skills — and has since grown into a multi-host plugin with a Claude Code target and a GitHub Copilot target.

**Key design principles:**

- **The target-workspace directory name is the central mechanism.** Every component lives under `plugins/<plugin>/<target>/`, where `<target>` is exactly `claude-code` or `copilot`. An agent that sees `plugins/*/copilot/**` knows which host's contract governs the file before it reads a byte of it. Nothing else in the tree carries that signal, so nothing may sit outside a target workspace.
- **Three layers, narrowest first.** The Agent Skills specification is a portable floor; GitHub Copilot is a superset of it; Claude Code is a superset of that. Write to the narrowest layer that carries the capability, and reach up only deliberately — the reach costs portability.
- **One agent for now, shared skills always.** The bash/Node specialist split was consolidated into a single plugin-engineer agent (bash discipline as its named specialization) because all agents would share the same context skills. Specialists get split back out when concrete work justifies them.
- **Path-based skill auto-loading.** The enforcer skills fire when matching files are read, so agents get the relevant contract in context without explicit invocation.
- **Treat training-data recall as untrusted.** Both hosts' contracts change; skills point at canonical docs rather than restating them.
- **One-directional authoring.** `claude-code/` leads and `copilot/` trails. A change that originates in the port is a defect.

**When to reference this document:** when adding a new agent or skill, when adding a target, when changing the layout or the release plumbing, or when deciding what belongs in the plugin versus a companion Node package.

---

## Current State

### Canonical layout

```text
plugins/<target>/            # single-plugin repo
plugins/<plugin>/<target>/   # multi-plugin repo — this one
```

Here that is `plugins/plugin-bot/claude-code`, `plugins/plugin-bot/copilot` and `plugins/dogfood/claude-code`. The manifest location is host-specific: `.claude-plugin/plugin.json` for `claude-code`, a root `plugin.json` for `copilot`. `plugins/__test__/canonical-layout.bats` fails if a component directory appears outside a target workspace.

### Independent per-target versioning

Each *distributed* target workspace carries a private tracking `package.json` — `@plugin-bot/claude-code-plugin` and `@plugin-bot/copilot-plugin`. Both are `"private": true` with **no `publishConfig`**, which is what keeps them off npm; they exist only to give changesets something to version. `.changeset/config.json` gives each package a `versionFiles` entry pointing at its own plugin manifest, so a changeset bumps the package and its manifest in lockstep, tags, and releases without publishing. The two targets therefore version independently.

`plugins/dogfood/claude-code` deliberately has **no** tracking package: it is a sandbox and is never distributed.

### The three layers

| Layer | Context skill | Adds |
| :-- | :-- | :-- |
| Portable floor — Agent Skills spec | `agent-plugins-docs` | `SKILL.md` and its frontmatter, progressive disclosure, `references/`, `scripts/`, `assets/` |
| GitHub Copilot | `copilot-docs` | manifest fields beyond the portable schema, `.agent.md` agents, 14 hook events, 3 handler types |
| Claude Code | `anthropic-docs` | 33 hook events, 5 handler types, `paths:` auto-load, `userConfig`, `channels`, monitors, output styles |

Each of the three carries stamped reference distillations under `references/` and its own escalation URL; see [upstream docs policy](./upstream-docs.md) for the evidence ladder and the rule that a portable claim settled by a Claude-only page is not settled.

### Components

`plugins/plugin-bot/claude-code/` ships one agent and fourteen skills:

- `agents/plugin-engineer.md` — the single agent, whose scope is now both hosts. It preloads the three context skills plus `plugin-setup` and relies on the path enforcers auto-loading.
- **Context skills (3):** `agent-plugins-docs`, `copilot-docs`, `anthropic-docs` — one per layer.
- **Path enforcers (5):** `plugin-manifest`, `agent-authoring`, `hook-scripts`, `skill-authoring`, `skill-scripts`. Their `paths:` globs now carry both dialects, so `agent-authoring` matches `**/agents/**/*.agent.md` and `**/.github/agents/**/*.md` alongside the Claude forms.
- **Workflow and pattern skills (6):** `plugin-setup` (scaffolds dual-target, including the per-target release plumbing), `porting-to-copilot` (the re-authoring procedure and the ledger, with `scripts/port-status.sh`), `skill-evals` (trigger and output-quality evals), `monitors` (the Claude-only monitor enforcer and its TypeScript poll harness), `shelling-out-from-plugins`, and `persuasion`.

The legacy `cc-*` family and the user-folder originals are superseded by this set.

### The Copilot port

`plugins/plugin-bot/copilot/` carries all fourteen skills and one agent (`agents/plugin-engineer.agent.md`). It is **re-authored, not copied**: `paths:` and `user-invocable` are Claude-only, and Copilot documents no substitution inside skill or agent content, so bodies legitimately differ. Currency is pinned by a content-hash ledger, `plugins/plugin-bot/copilot/port-status.json`, maintained by `port-status.sh --check` / `--record`.

**The ledger's limit is worth stating plainly:** it tracks `skills/**/*.md` and `agents/**/*.md` and nothing else. `plugin.json`, `hooks.json` and `.mcp.json` can drift while the check stays green. Green means "every ported skill and agent is current", not "the port is complete."

### Testing

`pnpm test:bats` runs `bats --recursive plugins`, which collects three levels with no registration step: `plugins/__test__/` for host-agnostic claims such as the layout itself, and each target's own `__test__/` for host-specific ones. 21 tests today across `canonical-layout.bats`, `lib-templates.bats` and `port-drift.bats`.

### Distribution

The marketplace entry in `.claude-plugin/marketplace.json` is a `git-subdir` source: `url` `https://github.com/spencerbeggs/bot.git`, `path` `plugins/plugin-bot/claude-code`, pinned to a `sha`. It resolves from GitHub at that commit and **cannot serve the working tree**, so it is a distribution channel only, never a development one. Copilot installs are local (`copilot plugin install ./<workspace>`); the Copilot target is not listed in a marketplace.

---

## Rationale

**Why the target-workspace layout:** a single plugin directory cannot say which host's contract governs its contents, and hosts disagree on the manifest location, the agent file extension, the hook roster and the frontmatter keys. Encoding the host in the path makes the contract legible before a file is opened, and lets one plugin serve two hosts without a build step.

**Why independent per-target versions:** the two targets change for different reasons and at different rates — a Copilot re-authoring pass is not a Claude Code feature. Separate tracking packages let each manifest carry an honest version and its own tag. `private` with no `publishConfig` is the mechanism that gets the changesets machinery without an npm artifact nobody wants.

**Why one-directional authoring:** two editable copies of the same guidance become two sources of truth. Making `claude-code/` the source and `copilot/` the trail means drift has a direction, and the ledger can measure it.

**Why the name plugin-bot:** the plugin was originally named plugin-dev, which collides with Anthropic's official plugin-dev plugin.

**Why migrate out of the user folder:** the user-folder combo is unversioned, single-machine and invisible to the marketplace. As a plugin it becomes versioned in git, distributable and testable in-session during development.

**Companion Node modules:** plugins can be paired with a Node package built by this repo's standard pipeline (`packages/*`, see [demo architecture](../demo/architecture.md)). Not used by plugin-bot yet, but it is the pattern to reach for when a plugin needs real programs rather than bash.

---

## Development workflow

`pnpm claude` is the only loop that serves local edits. It runs `claude --plugin-dir ./plugins/plugin-bot/claude-code --plugin-dir ./plugins/dogfood/claude-code`, and a `--plugin-dir` load shadows any same-named marketplace install for that session. The marketplace entry is pinned to a GitHub sha and never reflects the working tree, so design work should assume the `--plugin-dir` loop rather than a publish-install cycle.

After editing hooks, `.mcp.json` or agents, the user runs `/reload-plugins` to pick the change up. The upstream docs do say a `SKILL.md` edit takes effect immediately, but **that statement is scoped to `@skills-dir` plugins**, not to `--plugin-dir` loads (`plugins/plugin-bot/claude-code/skills/anthropic-docs/references/plugins-reference.md`, the edit/reload/disable note). Treat skill hot-reload as unverified for this loop and reload anyway if an edit does not seem to land.

Run `claude plugin validate <target-workspace> --strict` before calling Claude Code plugin work done. Copilot documents no validate subcommand; `copilot plugin install ./<workspace>` caches components, so reinstall after each edit.

Dogfooding runs through the repo-local `/dogfood` skill (`.claude/skills/dogfood`): it tasks plugin-engineer with building a capability inside the `plugins/dogfood/claude-code` sandbox, validates and reloads it, evaluates the result (skill-creator evals for skills, fixtures/BATS for hooks) and harvests rough edges in plugin-bot's own guidance as follow-up notes — harvest and fix are deliberately separate passes.

---

## Future enhancements

- Extend the port ledger beyond `skills/**/*.md` and `agents/**/*.md` so manifest and hook drift is caught rather than assumed, or add a companion check for those files.
- Publish the Copilot target through a Copilot marketplace once one is warranted; today it installs only from a local path.
- Verify parity with, and retire, the remaining user-folder originals.
- Possible companion Node module under `packages/*` if the plugin outgrows bash.

---

## Related documentation

- [upstream docs policy](./upstream-docs.md) — the three-way fetch-first policy and the doc inventory behind the context skills.
- [demo architecture](../demo/architecture.md) — the build/test pipeline a companion Node module would use.
- `plugins/CLAUDE.md` — the loaded-context statement of the layout, the layer model, the fetch-first policy and the ledger's limits; this doc is the durable record behind it.
- `.claude-plugin/marketplace.json` — the `git-subdir` marketplace entry for the Claude Code target.
- `.changeset/config.json` — the `versionFiles` wiring that bumps each target's manifest with its tracking package.

---

**Document Status:** current — the target-workspace layout, per-target versioning, the three-layer skill set and the Copilot port have all landed and are covered by tests.

**Next Steps:** close the ledger's coverage gap on manifests and hook registrations, retire the user-folder originals, and split specialist agents back out only when concrete Node or orchestration workloads justify them.
