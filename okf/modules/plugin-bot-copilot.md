---
type: Module
kind: plugin
title: plugin-bot for Copilot
description: The GitHub Copilot target of plugin-bot, a re-authored port of the Claude Code target tracked by a content-hash ledger.
resource: ../../plugins/plugin-bot/copilot
status: draft
tags:
  - architecture
  - portability
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: 7440ba8e2c5e6046dda0a5e6c6646ce72bc994fb19c30673da59e1dbb7fe9b91
sources:
  - resource: ../../plugins/plugin-bot/copilot/port-status.json
    id: port-ledger
    title: Port ledger
  - resource: ../../plugins/plugin-bot/copilot/package.json
    id: tracking-package
    title: Private tracking package
---

# plugin-bot for Copilot

This target trails [plugin-bot for Claude Code](plugin-bot-claude-code.md). It carries the same set of skills and the same agent, but re-authored for Copilot, not copied. A change that originates here is a defect ([one-directional authoring](../decisions/one-directional-authoring.md)).

## Why the bodies differ

Bodies legitimately differ from the source:

- `paths:` and `user-invocable` are Claude-only frontmatter, so the port drops them.
- Copilot documents no substitution inside skill or agent content, so `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` would render literally; the port rewrites them to plain relative paths or prose pointers. A placeholder swap would only trade one literal string for another.

The procedure is the `porting-to-copilot` skill.

## Contents

- `agents/plugin-engineer.agent.md`, the Copilot spelling of the agent (`.agent.md`).
- `skills/`, the same fourteen skill names as the source.
- `plugin.json` at the target root; Copilot's manifest location differs from Claude Code's `.claude-plugin/plugin.json`.
- `port-status.json`, the content-hash ledger. Each entry records the `sourceHash` of the Claude Code file it was ported from, so a drift check can report which ports are stale.[^port-ledger] Refresh procedure: [refresh the Copilot port](../runbooks/refresh-copilot-port.md).

The ledger covers only `skills/**/*.md` and `agents/**/*.md`; see [port ledger coverage](../limitations/port-ledger-coverage.md) for what can drift while it reads green.

## Tracking package

`@plugin-bot/copilot-plugin` is private and unpublished; it lets changesets version this manifest separately ([per-target versioning](../decisions/per-target-versioning.md)).[^tracking-package]

[^port-ledger]: `../../plugins/plugin-bot/copilot/port-status.json`
[^tracking-package]: `../../plugins/plugin-bot/copilot/package.json`
