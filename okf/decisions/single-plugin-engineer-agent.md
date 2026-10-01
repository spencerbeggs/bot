---
type: Decision
title: One plugin-engineer agent, bash as a specialization
description: A single plugin-engineer agent with bash discipline as a named specialization, because all agents would share the same context skills.
status: draft
tags:
  - architecture
  - dx
sources:
  - resource: ../../plugins/plugin-bot/claude-code/agents/plugin-engineer.md
  - resource: ../../plugins/plugin-bot/copilot/agents/plugin-engineer.agent.md
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: bd2e69dfd15fc1a989bf0235821b10e473e24316d12e7871119fef88c19732ca
---

# One plugin-engineer agent, bash as a specialization

## Context

The plugin began as separate bash and Node specialist agents, which were consolidated into the single plugin-engineer agent with bash discipline as its named specialization.

## Decision

Keep one agent, `plugin-engineer`, in each target workspace, with bash discipline as a named specialization rather than a separate agent. All agents would share the same context skills, so a split would duplicate the preloaded skill set without adding distinct context. Specialists get split back out when concrete Node or orchestration work justifies them.

## Alternatives rejected

- **A bash specialist and a Node specialist.** Both would preload the same context skills, leaving two agents that differ only in a paragraph of prompt.
- **Pre-building specialists for work that does not exist yet.** No Node or orchestration work is in the plugin today, so a specialist would have nothing concrete to specialize in.

## Consequences

- One agent file per target to keep in step, which keeps [the port](./one-directional-authoring.md) small.
- The agent's prompt carries the bash discipline directly.
- A real Node or orchestration need is the trigger to revisit this.
