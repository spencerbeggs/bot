---
type: Module
kind: plugin
title: plugin-bot for Claude Code
description: The Claude Code target of plugin-bot, the plugin-engineer agent plus fourteen skills that guide building agent plugins for both hosts.
resource: ../../plugins/plugin-bot/claude-code
status: draft
tags:
  - architecture
  - portability
  - dx
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: 3fe4a73318686c33f16cf97e676966b5d2cceb221ec2bc928b0871f415aca71f
sources:
  - resource: ../../plugins/plugin-bot/claude-code/agents/plugin-engineer.md
    id: plugin-engineer-agent
    title: plugin-engineer agent
  - resource: ../../plugins/plugin-bot/claude-code/package.json
    id: tracking-package
    title: Private tracking package
---

# plugin-bot for Claude Code

This is the leading target of plugin-bot: the source of truth that the [Copilot port](plugin-bot-copilot.md) trails ([one-directional authoring](../decisions/one-directional-authoring.md)). It is loaded from source by `pnpm claude` ([local dev loop](../runbooks/local-plugin-dev-loop.md)) and distributed through the Claude Code marketplace manifest ([interface](../interfaces/marketplace-manifests.md)).

## Agent

`agents/plugin-engineer.md` is the single general-purpose engineer for authoring and auditing plugin components on either host ([why one agent](../decisions/single-plugin-engineer-agent.md)). It preloads the three context skills, `agent-plugins-docs`, `anthropic-docs` and `copilot-docs`, plus `plugin-setup`, and establishes the target from the file path before applying any contract.[^plugin-engineer-agent]

## Skills

There are fourteen skills under `skills/`, in three roles.

**Context skills, one per layer** (portable floor, Copilot, Claude Code; see [narrowest-layer, fetch-first](../conventions/narrowest-layer-fetch-first.md) and [stamped references](../decisions/fetch-first-stamped-references.md)):

- `agent-plugins-docs`: the Agent Skills specification and what survives across hosts.
- `copilot-docs`: GitHub Copilot's manifest, agents and hooks.
- `anthropic-docs`: Claude Code's superset.

**Path enforcers** that auto-load through `paths:` globs when a matching file is opened:

- `skill-authoring`: `SKILL.md` and command files.
- `agent-authoring`: agent files for both hosts.
- `plugin-manifest`: `plugin.json`, `marketplace.json` and MCP files.
- `hook-scripts`: hook scripts and `hooks.json`.
- `skill-scripts`: scripts inside a skill.
- `monitors`: monitor definitions and scripts.

The globs of the enforcers were widened to match both hosts' file dialects, except `monitors`, which stays Claude-only because monitors are a Claude Code feature.

**Workflow and pattern skills:**

- `plugin-setup`: scaffolding and the environment contract.
- `porting-to-copilot`: the re-authoring procedure and the port ledger tooling.
- `skill-evals`: evaluating skills.
- `persuasion`: how to write instructions that agents follow.
- `shelling-out-from-plugins`: running commands safely from plugin code.

## Tracking package

`@plugin-bot/claude-code-plugin` is private and never published to npm. It exists so changesets can bump, tag and release this manifest independently of the Copilot one ([per-target versioning](../decisions/per-target-versioning.md), [release runbook](../runbooks/release-a-plugin.md)).[^tracking-package]

## Tests

BATS tests sit in the target's `__test__/` directory ([placement convention](../conventions/bats-test-placement.md)).

[^plugin-engineer-agent]: `../../plugins/plugin-bot/claude-code/agents/plugin-engineer.md`
[^tracking-package]: `../../plugins/plugin-bot/claude-code/package.json`
