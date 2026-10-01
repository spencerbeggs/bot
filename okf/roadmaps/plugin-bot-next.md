---
type: Roadmap
title: plugin-bot next steps
description: Queued work for plugin-bot behind one gate, covering ledger coverage, a pinned Copilot entry, retiring the user-folder originals, and when specialists or a Node companion earn their place.
tags:
  - architecture
  - portability
status: draft
stale_after: 2026-12-29T00:00:00Z
gate: The port ledger covers plugin.json, hooks.json and .mcp.json, and the Copilot marketplace entry for plugin-bot is pinned to a released commit.
sources:
  - id: copilot-marketplace
    resource: ../../.github/plugin/marketplace.json
    title: Copilot marketplace manifest
  - id: claude-marketplace
    resource: ../../.claude-plugin/marketplace.json
    title: Claude Code marketplace manifest
  - id: repin-workflow
    resource: ../../.github/workflows/repin-plugins.yml
    title: Repin workflow
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:28:01Z
  body_sha256: dd76f48ca3b2fee5c955be69c9a899ca455c808a7c787a0ea0b7acada79fa20d
---

# plugin-bot next steps

This is intent, not a decision. The gate above closes the roadmap when the first two items hold; the remaining items are conditional and stay queued until their trigger appears. When the gate holds, deprecate this concept and record what the work produced as Decisions.

## Close the port ledger's coverage gap

The port ledger only watches the markdown skill and agent files, so drift in `plugin.json`, `hooks.json` and `.mcp.json` between the Claude Code and Copilot targets is assumed away rather than caught. The edge is described in [port ledger coverage](../limitations/port-ledger-coverage.md). Closing it means extending the ledger to those three files, or adding a companion check that compares them. Hook registrations are the highest-value case because the two hosts disagree on their shape.

## Pin the Copilot marketplace entry

The Copilot target is already published through a Copilot marketplace: the `plugin-bot` entry in the Copilot manifest is a `github` source naming the repository and `plugins/plugin-bot/copilot`, with no `sha`.[^copilot-marketplace] The Claude Code entry, by contrast, is a `git-subdir` source carrying a `sha`.[^claude-marketplace] An unpinned entry follows the repository's default branch rather than a released commit, so it can serve unreleased work. The remaining work is to pin the Copilot entry to a released commit and then automate its repin. The repin workflow already exposes a `marketplace` choice of `claude-code` or `copilot` on manual dispatch,[^repin-workflow] and other entries in the Copilot manifest carry a `sha`, so the machinery exists; whether it handles the plugin-bot Copilot entry end to end has not been verified. The current release procedure is in [release a plugin](../runbooks/release-a-plugin.md), and the manifest shapes are in [marketplace manifests](../interfaces/marketplace-manifests.md).

## Retire the user-folder originals

The plugin began as a migration of an agent and a family of skills that still exist in the maintainer's user folder, outside this repository. Verify that the plugin versions are at parity with them, then retire the originals so there is one source of truth. Nothing in this repository can check the user folder, so this is a manual comparison.

## Split specialists back out only on evidence

The single plugin-engineer agent stays until concrete Node or orchestration work justifies a specialist. Splitting earlier would duplicate the context skills every agent shares. The reasoning is in [single plugin-engineer agent](../decisions/single-plugin-engineer-agent.md).

## Companion Node package, if bash is outgrown

If a plugin outgrows bash, pair it with a companion Node package. This repository has no build pipeline for one today: there is no `packages/` directory and no `savvy.build.ts`, and the root `build` scripts run turbo tasks that no workspace package defines. The first companion would need that pipeline set up first; `savvy.build.ts` with `@savvy-web/bundler` is the Silk convention to reach for. An earlier private canary package that exercised it was removed, so the pattern is unproven here. Prefer staying in bash until a plugin needs real Node logic.

[^copilot-marketplace]: `../../.github/plugin/marketplace.json`
[^claude-marketplace]: `../../.claude-plugin/marketplace.json`
[^repin-workflow]: `../../.github/workflows/repin-plugins.yml`
