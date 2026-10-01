---
type: Decision
title: Authoring flows one way, claude-code first
description: claude-code/ leads and copilot/ trails; a change that originates in the port is a defect, so drift has a direction the ledger can measure.
status: draft
tags:
  - architecture
  - portability
sources:
  - resource: ../../plugins/plugin-bot/claude-code/agents/plugin-engineer.md
  - resource: ../../plugins/plugin-bot/copilot/agents/plugin-engineer.agent.md
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: d96bdb984e9f006acef61a559b47d040ddb9391795261972e5b2304c4c6ecb68
---

# Authoring flows one way, claude-code first

## Context

The same guidance exists in both target workspaces, for example the plugin-engineer agent as `agents/plugin-engineer.md` under `claude-code/` and `agents/plugin-engineer.agent.md` under `copilot/`. Two editable copies of the same guidance become two sources of truth.

## Decision

`claude-code/` leads and `copilot/` trails. Changes are authored in `claude-code/` and then ported, and a change that originates in the port is a defect. Making one side the source gives drift a direction, and the port ledger can measure it. The port procedure is in [refresh the Copilot port](../runbooks/refresh-copilot-port.md); what the ledger does and does not see is in [port ledger coverage](../limitations/port-ledger-coverage.md).

## Alternatives rejected

- **Both targets editable.** Divergence would have no direction, so a difference could not be classed as stale or intentional.
- **Copilot leads.** Claude Code is the superset host, so authoring in the narrower one would lose capabilities that then have to be reinvented.

## Consequences

- A port-only fix has to be re-expressed in `claude-code/` first.
- Drift is measurable as the distance the trailing copy sits behind the leading one.
- Where the ledger has no coverage, drift is assumed rather than caught.
