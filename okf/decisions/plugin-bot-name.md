---
type: Decision
title: The plugin is named plugin-bot
description: The plugin is named plugin-bot to avoid colliding with Anthropic's official plugin-dev plugin.
status: draft
tags:
  - dx
sources:
  - resource: ../../plugins/plugin-bot/claude-code/.claude-plugin/plugin.json
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: b6b1ebf180cffd3258832d642136886148c6d8e9a4679e68cdd285e32537cb15
---

# The plugin is named plugin-bot

## Context

The plugin was originally named plugin-dev, which collides with Anthropic's official plugin-dev plugin, and it was renamed plugin-bot.

## Decision

Name the plugin `plugin-bot`, as set in the `name` field of its manifest. Its skills are invoked under that namespace, for example `plugin-bot:skill-authoring`.

## Alternatives rejected

- **Keeping plugin-dev.** Two installed plugins with the same name would shadow each other or make skill and agent references ambiguous.
- **Qualifying the name only in the marketplace entry.** The manifest name is what namespaces components, so the collision would remain.

## Consequences

- Skill, agent and marketplace references all use `plugin-bot`.
- Anything that still says plugin-dev refers to Anthropic's plugin, not this one.
