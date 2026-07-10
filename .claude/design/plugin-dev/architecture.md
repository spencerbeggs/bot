---
status: draft
module: plugin-dev
category: architecture
created: 2026-07-10
updated: 2026-07-10
last-synced: never
completeness: 30
related:
  - ../demo/architecture.md
dependencies: []
---

# plugin-dev - Architecture

A Claude Code plugin, developed in this repo at `plugins/plugin-dev`, whose job is helping develop Claude Code plugins.

## Table of contents

1. [Overview](#overview)
2. [Current State](#current-state)
3. [Rationale](#rationale)
4. [Development workflow](#development-workflow)
5. [Future Enhancements](#future-enhancements)
6. [Related Documentation](#related-documentation)

---

## Overview

plugin-dev is the first plugin that originates in this repo rather than being pulled in from another repo via the marketplace manifest (`.claude-plugin/marketplace.json`). It is a migration and expansion of a user-folder agent/skill combo: the `plugin-bash-engineer` agent (`~/.claude/agents/plugin-bash-engineer.md`) and its family of path-based `cc-*` skills (`~/.claude/skills/cc-*`), which together enforce an opinionated layout, scaffolding and audit discipline for plugin bash scripts, hooks, skills and agents.

**Key design principles:**

- Multiple specialist agents, shared skills. The original design was one agent (bash-engineer) with a private skill family. The plugin generalizes this: agents such as bash-engineer and a planned node-engineer (Node.js paradigms) share a common pool of skills instead of each owning duplicates.
- Path-based skill auto-loading. The `cc-*` skills fire when matching files are read (e.g. a consumer plugin's hook script), so agents get the relevant contract in context without explicit invocation. This mechanism must survive the migration.
- Treat training-data recall as untrusted. The hook contract changes; skills point at canonical docs rather than restating them.

**When to reference this document:** when migrating components from the user folder into the plugin, when adding a new agent or skill to the plugin, or when deciding what belongs in the plugin versus a companion Node package.

---

## Current State

Directory scaffolding only. `plugins/plugin-dev/skills/cc-plugin-bash-templates/templates/hooks/fixtures/` exists as empty directories; there are no files yet — no `.claude-plugin/plugin.json` manifest, no agents, no skill content.

**Migration source (user folder, not yet moved):**

- `~/.claude/agents/plugin-bash-engineer.md` — the agent definition, including its required-reading contract of eight skills and per-event auto-load map.
- `~/.claude/skills/cc-*` — the skill family (layout, hooks base, per-event hook skills, skill scripts, bash templates, tools reference, skill/agent frontmatter, nudge hooks). See the agent file for how each is wired in; `ls ~/.claude/skills | grep cc-` for the live inventory.

**Distribution:** once the plugin has a manifest, it gets an entry in `.claude-plugin/marketplace.json` alongside the two externally-sourced plugins (vitest-agent, design-docs), sourced from this repo's `plugins/plugin-dev` path rather than a remote git-subdir.

---

## Rationale

**Why migrate out of the user folder:** the user-folder combo is unversioned, single-machine and invisible to the marketplace. As a plugin it becomes versioned in git, distributable through the marketplace and testable in-session during development.

**Why multiple agents sharing skills:** bash and Node.js plugin engineering are different expertise domains, but they share most of the plugin-authoring contract (layout, manifest schema, hook I/O, frontmatter discipline). One agent per domain keeps system prompts focused; a shared skill pool keeps the contract single-sourced.

**Companion Node modules:** Claude Code plugins can be paired with a Node package built by this repo's standard pipeline (`packages/*`, see [demo architecture](../demo/architecture.md)). Not used by plugin-dev yet, but it is the pattern to reach for when a plugin needs real programs rather than bash.

---

## Development workflow

Local plugins in this repo are enabled in working sessions. The feedback loop is: edit plugin files → user runs `/reload-plugins` → the plugin reboots in-session and its behavior can be observed immediately. Design work should assume this loop rather than a publish-install cycle.

---

## Future Enhancements

- Complete the migration: plugin manifest, the bash-engineer agent and the full `cc-*` skill family moved into `plugins/plugin-dev`.
- node-engineer agent — Node.js paradigms expert sharing the common skill pool.
- Marketplace entry for the plugin once it is functional.
- Possible companion Node module under `packages/*` if the plugin outgrows bash.

---

## Related Documentation

- [demo architecture](../demo/architecture.md) — the build/test pipeline a companion Node module would use.
- `.claude-plugin/marketplace.json` — marketplace manifest this plugin will be listed in.
- `~/.claude/agents/plugin-bash-engineer.md` — migration source of truth until the move completes.

---

**Document Status:** draft — written before migration work began; Current State will change quickly.

**Next Steps:** document the chosen plugin layout and agent/skill split as the migration lands, then bump completeness and set status to current.
