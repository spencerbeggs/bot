---
status: current
module: plugin-bot
category: meta
created: 2026-07-10
updated: 2026-07-10
last-synced: 2026-07-10
completeness: 90
related:
  - architecture.md
dependencies: []
implementation-plans:
  - ../plans/plugin-bot-skills-phase1.md
---

# plugin-bot - Upstream docs policy

Consult Anthropic's official Claude Code docs before authoring or auditing plugin components. When in doubt, don't guess.

## Table of contents

1. [Overview](#overview)
2. [Current State](#current-state)
3. [Rationale](#rationale)
4. [Related documentation](#related-documentation)

---

## Overview

Claude Code evolves fast: new components (channels, monitors, themes, `bin/`, `settings.json`), new hook events and hook types and new frontmatter fields appear between releases. Training-data recall and internal references — including this plugin's own distilled reference mirror — inevitably go stale against that pace.

The policy: before authoring or auditing any plugin component, fetch the relevant official doc from the list in [Current State](#current-state). When the docs and memory disagree, the docs win. When the docs are silent, don't guess — say so.

The docs annotate version-gated behavior with markers like "Requires Claude Code vX.Y.Z" — verify the gate before relying on a feature, since a consumer's installed version may predate it.

The full doc index is at <https://code.claude.com/docs/llms.txt>.

---

## Current State

The canonical doc list, with when to consult each:

- <https://code.claude.com/docs/en/plugins.md> — creating plugins, local testing (`--plugin-dir`, `/reload-plugins`), converting standalone `.claude/` config, marketplace submission.
- <https://code.claude.com/docs/en/plugins-reference.md> — manifest schema, component locations, path rules, plugin caching, the `CLAUDE_PLUGIN_ROOT`/`CLAUDE_PLUGIN_DATA` contract, version management and the plugin CLI (`init`, `validate`, `details`, `tag`).
- <https://code.claude.com/docs/en/plugin-marketplaces.md> — marketplace.json schema and source variants, hosting and team configuration.
- <https://code.claude.com/docs/en/skills.md> — SKILL.md frontmatter, invocation control, dynamic context injection, skill lifecycle and evals.
- <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md> — skill-authoring best practices: conciseness, degrees of freedom, naming and description rules, progressive disclosure, eval-first iteration and anti-patterns.
- <https://code.claude.com/docs/en/sub-agents.md> — agent frontmatter, plugin-agent restrictions, memory, preloaded skills and forks.
- <https://code.claude.com/docs/en/hooks.md> — hook events, matchers, exec vs shell form, exit codes, JSON output shapes, prompt/agent/http/mcp_tool hook types and async hooks.
- <https://code.claude.com/docs/en/mcp.md> — server configuration, plugin-provided servers and scoped tool naming, tool search and OAuth.
- <https://code.claude.com/docs/en/tools-reference.md> — canonical tool names, permission-rule formats and per-tool behavior.
- <https://code.claude.com/docs/en/env-vars.md> — every environment variable Claude Code reads.
- <https://code.claude.com/docs/en/channels-reference.md> — building channel MCP servers that push events into a session.

The fetch-first policy now has a concrete implementation: every doc in this list is distilled as a stamped reference (`Verified against <url> — <date>`) under `plugins/plugin-bot/skills/anthropic-docs/references/`, and that skill's SKILL.md carries the evidence ladder — use the reference, WebFetch the stamped URL when the reference is silent or the behavior is version-sensitive, never answer from memory. The stamps make staleness auditable; see the [phase 1 skills plan](../../plans/plugin-bot-skills-phase1.md) for how the set was built.

`plugins/CLAUDE.md` (being created in parallel with this doc) carries this policy as loaded context for sessions working under `plugins/`; this doc is the durable record it points back to.

---

## Rationale

**Why fetch-first beats snapshotting:** copying doc content into skills or design docs creates snapshots that rot silently — nothing validates the copy against upstream, and a snapshot that is correct today is still a second source of truth tomorrow. The official docs are markdown-served and cheap to fetch at the moment of need, so the freshness guarantee costs one request. The `anthropic-docs` stamped references are the sanctioned middle ground: distilled rather than copied, stamped so staleness is auditable and refreshable by re-diffing against the stamped URL — with the fetch step of the evidence ladder as the backstop.

**Why this is a repo-wide policy:** plugin-bot's skills already treat training-data recall as untrusted and point at canonical docs rather than restating them (see [architecture](./architecture.md)). This doc generalizes that discipline from the skill family to everything in the repo that touches plugin components.

---

## Related documentation

- [architecture](./architecture.md) — plugin-bot's structure and the design principle this policy generalizes.
