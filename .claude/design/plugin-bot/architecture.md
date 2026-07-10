---
status: draft
module: plugin-bot
category: architecture
created: 2026-07-10
updated: 2026-07-10
last-synced: 2026-07-10
completeness: 65
related:
  - ../demo/architecture.md
  - upstream-docs.md
dependencies: []
implementation-plans:
  - ../plans/plugin-bot-skills-phase1.md
---

# plugin-bot - Architecture

A Claude Code plugin, developed in this repo at `plugins/plugin-bot`, whose job is helping develop Claude Code plugins.

## Table of contents

1. [Overview](#overview)
2. [Current State](#current-state)
3. [Rationale](#rationale)
4. [Development workflow](#development-workflow)
5. [Future enhancements](#future-enhancements)
6. [Related documentation](#related-documentation)

---

## Overview

plugin-bot is the first plugin that originates in this repo rather than being pulled in from another repo via the marketplace manifest (`.claude-plugin/marketplace.json`). It is a migration and expansion of a user-folder agent/skill combo: the `plugin-bash-engineer` agent (`~/.claude/agents/plugin-bash-engineer.md`) and its family of path-based `cc-*` skills (`~/.claude/skills/cc-*`), which together enforce an opinionated layout, scaffolding and audit discipline for plugin bash scripts, hooks, skills and agents.

**Key design principles:**

- One agent for now, shared skills always. The migration started toward bash/node specialist agents, but the split was consolidated into a single plugin-engineer agent (bash discipline as its named specialization) because all agents would share the same context skills and no Node workload exists yet — specialists get split back out when concrete work justifies them.
- Path-based skill auto-loading. The enforcer skills fire when matching files are read (e.g. a consumer plugin's hook script), so agents get the relevant contract in context without explicit invocation. This mechanism survived the migration and skills rebuild.
- Treat training-data recall as untrusted. The hook contract changes; skills point at canonical docs rather than restating them.

**When to reference this document:** when adding a new agent or skill to the plugin, when verifying parity with (or retiring) the user-folder originals, or when deciding what belongs in the plugin versus a companion Node package.

---

## Current State

The migration has landed and the skill set has been rebuilt per the [phase 1 skills plan](../../plans/plugin-bot-skills-phase1.md). `plugins/plugin-bot` now contains:

- `.claude-plugin/plugin.json` — the plugin manifest (name `plugin-bot`, version 0.0.0).
- `agents/plugin-engineer.md` — the single agent, consolidated from bash-engineer (whose operating principles it carries as a named bash-discipline specialization); it preloads `anthropic-docs` and `plugin-setup` and relies on the path enforcers auto-loading.
- `skills/` — nine skills replacing the legacy `cc-*` family (now archived out of the tree): the `anthropic-docs` context skill, whose `SKILL.md` indexes stamped distillations of the official Claude Code docs under `references/`; five path-based enforcers (`skill-authoring`, `agent-authoring`, `hook-scripts`, `plugin-manifest`, `skill-scripts`) that auto-load on path globs and point into those references; the `plugin-setup` pattern skill, which ships the bootstrap checklist, house-doctrine references (layout, session-env propagation) and the four tested `hooks/lib` script templates verbatim from the user-folder originals; `shelling-out-from-plugins`, the env-hygiene doctrine for third-party CLI calls, copied verbatim as a standalone description-triggered skill; and `persuasion` (formerly cc-nudge-hooks, scope widened), the craft of agent-directed language — hook nudge payloads, skill bodies, agent prompts — with the urgency-tier gradient and injection templates. See the skills directory for the live inventory and the plan for the migration map.

The skill set follows a three-layer design: a context layer (stamped, refreshable reference distillations with an evidence ladder — see [upstream docs policy](./upstream-docs.md)), a path-enforcer layer (compact checklists triggered by file globs) and pattern/workflow layers deferred to later phases.

**Remaining work:**

- A live-session smoke test of path- and description-triggering is the last gate on the skills plan. It requires a fresh session: this plugin loads via `pnpm claude` (`claude --plugin-dir plugins/plugin-bot`), and the rename from plugin-dev happened mid-session, so the current session points at the old folder name.
- The user-folder originals (`~/.claude/agents/plugin-bash-engineer.md`, `~/.claude/skills/cc-*`) still exist in parallel. Parity with them has not been verified and they have not been retired.

**Distribution:** development loads use `--plugin-dir` (the `claude` script in `package.json`), which takes precedence over marketplace installs. The marketplace entry exists in `.claude-plugin/marketplace.json` with a local `./plugins/plugin-bot` source, but the registered `spencerbeggs` marketplace resolves from GitHub, so marketplace installs only work once the entry and plugin are pushed.

---

## Rationale

**Why the name plugin-bot:** the plugin was originally named plugin-dev, but that collides with Anthropic's official plugin-dev plugin. Renaming to plugin-bot avoids the collision while keeping the "plugin about plugins" identity tied to this repo's bot ecosystem.

**Why migrate out of the user folder:** the user-folder combo is unversioned, single-machine and invisible to the marketplace. As a plugin it becomes versioned in git, distributable through the marketplace and testable in-session during development.

**Why multiple agents sharing skills:** bash and Node.js plugin engineering are different expertise domains, but they share most of the plugin-authoring contract (layout, manifest schema, hook I/O, frontmatter discipline). One agent per domain keeps system prompts focused; a shared skill pool keeps the contract single-sourced.

**Companion Node modules:** Claude Code plugins can be paired with a Node package built by this repo's standard pipeline (`packages/*`, see [demo architecture](../demo/architecture.md)). Not used by plugin-bot yet, but it is the pattern to reach for when a plugin needs real programs rather than bash.

---

## Development workflow

Local plugins in this repo are enabled in working sessions via `pnpm claude` (`--plugin-dir` for both `plugins/plugin-bot` and `plugins/dogfood`). The feedback loop is: edit plugin files → user runs `/reload-plugins` → the plugin reboots in-session and its behavior can be observed immediately. Design work should assume this loop rather than a publish-install cycle.

Dogfooding runs through the repo-local `/dogfood` skill (`.claude/skills/dogfood`): it tasks plugin-engineer with building a capability inside the `plugins/dogfood` sandbox (a manifest-only plugin, never distributed), validates and reloads it, evaluates the result (skill-creator evals for skills, fixtures/BATS for hooks) and harvests rough edges in plugin-bot's own guidance as follow-up notes — harvest and fix are deliberately separate passes.

---

## Future enhancements

- Push the marketplace entry and plugin so remote installs resolve (the entry exists locally in `.claude-plugin/marketplace.json` but the registered marketplace resolves from GitHub).
- Verify parity between the migrated plugin and the user-folder originals, then retire the originals.
- Possible companion Node module under `packages/*` if the plugin outgrows bash.

---

## Related documentation

- [demo architecture](../demo/architecture.md) — the build/test pipeline a companion Node module would use.
- [upstream docs policy](./upstream-docs.md) — consult the official Claude Code docs before authoring or auditing plugin components; don't guess.
- `.claude-plugin/marketplace.json` — marketplace manifest this plugin is listed in (local source; remote resolution pending push).
- `~/.claude/agents/plugin-bash-engineer.md` — user-folder original, kept until parity is verified and it is retired.

---

**Document Status:** draft — the migration, skills rebuild and agent consolidation have landed but the smoke test, parity verification and the marketplace push are pending.

**Next Steps:** finish the skills plan smoke test in a fresh session, verify parity with the user-folder originals, retire them, push the marketplace entry, then bump completeness and set status to current. Split specialist agents back out only when concrete Node or orchestration workloads justify them.
