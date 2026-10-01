---
type: Interface
title: Marketplace manifests
description: The two marketplace files that publish plugin-bot, one per host, and how each is pinned.
status: draft
kind: config
resource: ../../.claude-plugin/marketplace.json
tags:
  - release
  - github
  - portability
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: 03fc84aef8105e8d01219f29b23926cc42e796d2a5d648dad124583650c3c9f4
---

# Marketplace manifests

plugin-bot is published through two separate manifests, one per host.

## Claude Code: `.claude-plugin/marketplace.json`

The `plugin-bot` entry is a `git-subdir` source with `url` `https://github.com/spencerbeggs/bot.git` and `path` `plugins/plugin-bot/claude-code`, pinned to a `sha`. The sha is written by `.github/workflows/repin-plugins.yml` on a `plugin-release` repository dispatch; the workflow can also be run by hand with `workflow_dispatch`.

## Copilot: `.github/plugin/marketplace.json`

The `plugin-bot` entry is a `source: github` entry with `repo` `spencerbeggs/bot` and `path` `plugins/plugin-bot/copilot`. The release pipeline does not repin it, so it is bumped by hand, the same arrangement as the `effected` entry in that file, which carries a hand-set `sha`. The plugin-bot entry currently carries no `sha`, so it follows the default branch.

## What consumers can rely on

- A Claude Code install resolves from GitHub at the pinned commit, never from a working tree; see [the gotcha](../gotchas/marketplace-never-serves-working-tree.md).
- The pinned path is the Claude Code target workspace, so the installed plugin has the layout described in [the Claude Code module](../modules/plugin-bot-claude-code.md).
- The Copilot entry points at [the Copilot module](../modules/plugin-bot-copilot.md) and may lag or lead the Claude Code pin, since the two are repinned independently.
