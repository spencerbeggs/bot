---
type: Gotcha
title: The marketplace install never serves the working tree
description: plugin-bot is installable from this repo's own marketplace, but that entry resolves from GitHub at a pinned sha, so local edits are never live through it.
status: draft
resource: ../../.claude-plugin/marketplace.json
tags:
  - dx
stale_after: 2026-12-29T00:00:00Z
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: d101cf6d16c3beb53a72d770a77b6a5955d940d683ceec4a3d485bf14ec2a4c6
---

# The marketplace install never serves the working tree

## What a reader sees

plugin-bot is installable from this repository's own marketplace, so it is natural to assume that a plugin installed that way tracks the checkout in front of you.

## What they will wrongly conclude

That an edit to a skill, agent, hook or `.mcp.json` under `plugins/plugin-bot/claude-code` is live in a session that installed plugin-bot from the marketplace.

## What is true

The `plugin-bot` entry in `.claude-plugin/marketplace.json` is a `git-subdir` source (`url` `https://github.com/spencerbeggs/bot.git`, `path` `plugins/plugin-bot/claude-code`) pinned to a `sha`. It resolves from GitHub at that commit, never from disk, whether or not the sha is current. It is a distribution channel only.

The one loop that serves local edits is `pnpm claude`, which starts Claude Code with `--plugin-dir` for both plugins. A `--plugin-dir` load shadows a same-named marketplace install for that session. See [the local dev loop](../runbooks/local-plugin-dev-loop.md) and [the manifests](../interfaces/marketplace-manifests.md).
