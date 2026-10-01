---
type: Decision
title: Fetch first, with stamped per-layer references as the middle ground
description: "Plugin-component claims are settled by fetching the official docs, backed by stamped distillations kept one skill per layer, never by copied snapshots or a merged reference pile."
status: draft
tags:
  - docs
  - portability
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: 5bba5b19972c7dffde917e0568eaba5c4f3b7ff1fea6de54c2e21767facd0337
sources:
  - resource: ../../plugins/plugin-bot/claude-code/skills/agent-plugins-docs/references/agent-skills-spec.md
    title: A stamped distillation of the Agent Skills specification
  - resource: https://agentskills.io/specification.md
    title: The URL that stamp points back to
---

# Fetch first, with stamped per-layer references as the middle ground

## Context

Both hosts this repository targets, Claude Code and GitHub Copilot, ship new hook events, handler types, frontmatter fields and manifest keys between releases. Training-data recall goes stale against that pace, and so does any copy of the docs kept in the repository. The question is where a plugin author or auditing agent should get its facts.

## Decision

Fetch the official docs at the moment of need rather than keeping a snapshot. The upstream docs are served as markdown and are cheap to fetch, so the freshness guarantee costs one request.

The sanctioned middle ground is a stamped distillation: a reference that is distilled rather than copied and opens with `Verified against <url> — <date>`, for example line 3 of `plugins/plugin-bot/claude-code/skills/agent-plugins-docs/references/agent-skills-spec.md`. The stamp makes staleness auditable and refreshable by re-diffing against the stamped URL. The fetch step of the evidence ladder in each context skill is the backstop for when a reference is silent, version-sensitive or old.

References are split one skill per layer (portable, Copilot, Claude Code), not merged into one pile. The way agents apply this is set out in [the narrowest-layer convention](../conventions/narrowest-layer-fetch-first.md).

## Alternatives rejected

- Copy doc content into skills or design docs. A copy rots silently: nothing validates it against upstream, and one that is correct today is a second source of truth tomorrow.
- Rely on training-data recall. It is untrusted for the same pace-of-change reason.
- One merged reference set. It gives no signal about which host a fact came from, so it cannot answer "is this portable?". Splitting by layer turns that into a lookup and is what lets the narrowest-layer rule be checked rather than merely intended.

## Consequences

- Each context skill carries stamped references and the evidence ladder; a stale stamp is a visible, fixable defect.
- Every reference must be refreshed by re-fetching its stamped URL, which is a recurring cost.
- Portability questions are answered from the portable layer's references first.
