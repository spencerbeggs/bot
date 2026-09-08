---
status: current
module: plugin-bot
category: meta
created: 2026-07-10
updated: 2026-09-07
last-synced: 2026-09-07
completeness: 90
related:
  - architecture.md
dependencies: []
implementation-plans:
  - ../plans/plugin-bot-skills-phase1.md
---

# plugin-bot - Upstream docs policy

Consult the official docs for the layer you are working in before authoring or auditing a plugin component. When in doubt, don't guess.

## Table of contents

1. [Overview](#overview)
2. [Current State](#current-state)
3. [Rationale](#rationale)
4. [Related documentation](#related-documentation)

---

## Overview

Both hosts this repo targets evolve fast: new components, new hook events and handler types, new frontmatter fields and new manifest keys appear between releases. Training-data recall and internal references — including this plugin's own distilled reference mirrors — inevitably go stale against that pace.

The policy: before authoring or auditing any plugin component, read the reference in the context skill **for your layer**, then escalate by fetching the URL stamped at the top of that reference when it is silent, when the claim is version-sensitive, or when the stamp looks old. When the docs and memory disagree, the docs win. When the docs are silent, don't guess — say so.

Docs annotate version-gated behavior with markers like "Requires Claude Code vX.Y.Z" — verify the gate before relying on a feature, since a consumer's installed version may predate it.

**The layer rule matters as much as the fetch rule.** A portable claim settled by a Claude-only page is not settled. `anthropic-docs` describes Claude Code and `copilot-docs` describes Copilot; only `agent-plugins-docs` answers "does this survive the other host?" Ask the portable layer first and escalate to a host layer only once you know the capability is not portable.

---

## Current State

The policy has a concrete implementation: three context skills, one per layer of the [three-layer model](./architecture.md#the-three-layers), each shipping stamped distillations (`Verified against <url> — <date>`) under `plugins/plugin-bot/claude-code/skills/<skill>/references/` and each carrying the evidence ladder in its `SKILL.md`. The stamps make staleness auditable and refreshable by re-diffing against the stamped URL.

### Portable layer — `agent-plugins-docs`

Escalation index: <https://agentskills.io/specification.md>

- <https://agentskills.io/specification.md> — the Agent Skills specification: `SKILL.md` format and frontmatter, progressive disclosure, `references/`, `scripts/`, `assets/`.
- <https://github.com/agentplugins/agent-plugins-spec/blob/main/spec/1.0.0.md> — the Agent Plugins 1.0 manifest standard.
- <https://agentskills.io/skill-creation/best-practices.md> — skill-authoring guidance: conciseness, degrees of freedom, naming and description rules, eval-first iteration, anti-patterns.
- <https://code.visualstudio.com/docs/agent-customization/agent-plugins> — cross-client behavior: where conformant clients diverge in spite of the specs, and the shared placeholder vocabulary.

### Copilot layer — `copilot-docs`

Escalation index: <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference>

- <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference> — `plugin.json` and `marketplace.json` schemas, the `copilot plugin` CLI, `.agent.md` agents, LSP servers.
- <https://docs.github.com/en/copilot/reference/hooks-reference> — the Copilot hook event roster and handler types.
- <https://docs.github.com/en/copilot/reference/customization-cheat-sheet> — repository customization surfaces.

### Claude Code layer — `anthropic-docs`

Escalation index: <https://code.claude.com/docs/llms.txt>

- <https://code.claude.com/docs/en/plugins.md> — creating plugins, local testing (`--plugin-dir`, `/reload-plugins`), converting standalone `.claude/` config, marketplace submission.
- <https://code.claude.com/docs/en/plugins-reference.md> — manifest schema, component locations, path rules, plugin caching, the `CLAUDE_PLUGIN_ROOT`/`CLAUDE_PLUGIN_DATA` contract, version management and the plugin CLI.
- <https://code.claude.com/docs/en/plugin-marketplaces.md> — marketplace.json schema and source variants (including `git-subdir`), hosting and team configuration.
- <https://code.claude.com/docs/en/skills.md> — SKILL.md frontmatter, invocation control, dynamic context injection, skill lifecycle and evals.
- <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md> — Claude-flavored skill-authoring best practices.
- <https://code.claude.com/docs/en/sub-agents.md> — agent frontmatter, plugin-agent restrictions, memory, preloaded skills and forks.
- <https://code.claude.com/docs/en/hooks.md> — hook events (distilled into both `hooks.md` and a dedicated `hook-events.md`), matchers, exec vs shell form, exit codes, JSON output shapes, handler types and async hooks.
- <https://code.claude.com/docs/en/mcp.md> — server configuration, plugin-provided servers and scoped tool naming, tool search and OAuth.
- <https://code.claude.com/docs/en/tools-reference.md> — canonical tool names, permission-rule formats and per-tool behavior.
- <https://code.claude.com/docs/en/env-vars.md> — every environment variable Claude Code reads.
- <https://code.claude.com/docs/en/channels-reference.md> — building channel MCP servers that push events into a session.

`plugins/CLAUDE.md` carries this policy as loaded context for sessions working under `plugins/`, including the escalation table; this doc is the durable record it points back to.

---

## Rationale

**Why fetch-first beats snapshotting:** copying doc content into skills or design docs creates snapshots that rot silently — nothing validates the copy against upstream, and a snapshot that is correct today is still a second source of truth tomorrow. The official docs are markdown-served and cheap to fetch at the moment of need, so the freshness guarantee costs one request. The stamped references are the sanctioned middle ground: distilled rather than copied, stamped so staleness is auditable, with the fetch step of the evidence ladder as the backstop.

**Why one skill per layer rather than one reference pile:** a merged reference set cannot answer the portability question, because it gives no signal about which host a fact came from. Splitting the references by layer makes "is this portable?" a lookup rather than a judgment call, and it is what lets the [narrowest-layer authoring rule](./architecture.md#the-three-layers) be checked rather than merely intended.

**Why this is a repo-wide policy:** plugin-bot's skills already treat training-data recall as untrusted and point at canonical docs rather than restating them (see [architecture](./architecture.md)). This doc generalizes that discipline from the skill family to everything in the repo that touches plugin components.

---

## Related documentation

- [architecture](./architecture.md) — plugin-bot's structure, the three-layer model and the design principle this policy generalizes.
- `plugins/CLAUDE.md` — the loaded-context form of this policy, with the escalation table.
