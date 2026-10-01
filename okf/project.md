---
type: Project
title: bot
description: A monorepo that develops and distributes agent plugins for Claude Code and GitHub Copilot through its own marketplace manifests.
status: draft
tags:
  - architecture
  - release
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: dbf96fd232cdb1b6ac46a68dc5cb96e23d1b7256934d7db597c2de31340ca843
---

# bot

## Purpose

This repository develops and distributes agent plugins for two hosts, Claude Code and GitHub Copilot, and publishes them through its own marketplace manifests. plugin-bot, a plugin for developing agent plugins, is the first plugin that originates here instead of being pulled in from another repository. It exists so that the knowledge of how to author plugins (manifests, skills, agents, hooks, MCP wiring, porting between hosts) is versioned, distributable and testable in a live session.

The same knowledge once lived as an agent and skill combination in a user folder. That arrangement was unversioned, tied to a single machine and invisible to the marketplace, so nobody else could install it and no change could be tested or released on its own. As a plugin it is versioned, distributable and exercisable in-session through [the local dev loop](runbooks/local-plugin-dev-loop.md).

## Boundaries

The repository owns:

- `plugins/`, where each plugin lives in a [target workspace](glossary/target.md) at `plugins/<plugin>/<target>/` (see [the layout decision](decisions/target-workspace-layout.md) and [its invariant](invariants/canonical-layout.md)). Today that is [plugin-bot for Claude Code](modules/plugin-bot-claude-code.md), [its Copilot port](modules/plugin-bot-copilot.md) and the [dogfood sandbox](modules/dogfood.md).
- The two marketplace manifests, `.claude-plugin/marketplace.json` and `.github/plugin/marketplace.json` (see [the manifests interface](interfaces/marketplace-manifests.md)).
- The release and repin plumbing: changesets version each target independently ([per-target versioning](decisions/per-target-versioning.md)) and workflows repin marketplace entries to a commit ([release a plugin](runbooks/release-a-plugin.md)).

The repository leaves to others the plugins that the marketplace pins from other repositories (for example vitest-agent, design-docs, effected and okfit). Their entries appear in the manifests, but their source, versions and releases belong to the repositories they come from.

## Non-goals

- No npm-published packages today. The per-target tracking packages (such as `@plugin-bot/claude-code-plugin`) are private and carry no `publishConfig`; they exist only so changesets has something to version.
- No build step between source and plugin. What is under a target workspace is what the host loads.
- No serving of the working tree through the marketplace; a marketplace entry always resolves from GitHub ([gotcha](gotchas/marketplace-never-serves-working-tree.md)).
- No authoring in the Copilot port; `claude-code/` leads and `copilot/` trails ([one-directional authoring](decisions/one-directional-authoring.md)).

## Where to look next

Plugin work is guided by [narrowest-layer, fetch-first authoring](conventions/narrowest-layer-fetch-first.md). Planned work is in [the plugin-bot roadmap](roadmaps/plugin-bot-next.md).
