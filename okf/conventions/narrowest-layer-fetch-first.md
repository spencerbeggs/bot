---
type: Convention
title: Write to the narrowest layer, and fetch docs before authoring
description: Author each plugin component at the narrowest host layer that carries the capability, and settle claims from your layer's reference, then the stamped URL, never from memory.
status: draft
stale_after: 2026-12-29T00:00:00Z
tags:
  - docs
  - portability
  - dx
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: 4a2ea9090f45a328a5960ece5a783241063b8fdef0836228c5cab2e8b36bdee7
sources:
  - resource: ../../plugins/CLAUDE.md
    title: The loaded-context form of this convention
  - resource: ../../plugins/plugin-bot/claude-code/skills/anthropic-docs/references/hooks.md
    title: Claude Code hook event and handler-type counts
  - resource: ../../plugins/plugin-bot/claude-code/skills/copilot-docs/references/hooks-reference.md
    title: Copilot hook event count
---

# Write to the narrowest layer, and fetch docs before authoring

## The three layers

Plugin hosts nest. The Agent Skills specification is a portable floor, GitHub Copilot is a superset of it, and Claude Code is a superset of that. One context skill answers for each layer, and each ships stamped reference distillations under `references/` plus an escalation URL.

| Layer | Context skill | Adds |
| :-- | :-- | :-- |
| Portable floor, Agent Skills spec | `agent-plugins-docs` | `SKILL.md` and its frontmatter, progressive disclosure, `references/`, `scripts/`, `assets/` |
| GitHub Copilot | `copilot-docs` | Manifest fields beyond the portable schema, `.agent.md` agents, 14 hook events, 3 handler types |
| Claude Code | `anthropic-docs` | 33 hook events, 5 handler types, `paths:` auto-load, `userConfig`, `channels`, monitors, output styles |

The hook-event and handler counts were checked against the skills' references (`hooks-reference.md` for Copilot, `hooks.md` for Claude Code) and will move as the hosts do; re-check them rather than trusting this table.

## The rules

1. Write to the narrowest layer that carries the capability and reach up only deliberately. The reach costs portability.
2. Before authoring or auditing any component, read the reference in the context skill for your layer.
3. Escalate by fetching the URL stamped at the top of that reference (`Verified against <url> — <date>`) when the reference is silent, the claim is version-sensitive, or the stamp looks old.
4. When the docs and memory disagree, the docs win. Never answer from memory.
5. When the docs are silent, say so rather than guess.
6. Docs mark version-gated behaviour with "Requires Claude Code vX.Y.Z". Check the gate before relying on the feature, since a consumer's installed version may predate it.
7. A portable claim settled by a Claude-only page is not settled. `anthropic-docs` describes Claude Code and `copilot-docs` describes Copilot; only `agent-plugins-docs` answers "does this survive the other host?". Ask the portable layer first and escalate to a host layer only once you know the capability is not portable.

The reasoning is in [the fetch-first decision](../decisions/fetch-first-stamped-references.md).

## Escalation index

| Layer | Escalation index |
| :-- | :-- |
| Portable | <https://agentskills.io/specification.md> |
| Copilot | <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference> |
| Claude Code | <https://code.claude.com/docs/llms.txt> |

## Per-layer URL inventory

### Portable layer (`agent-plugins-docs`)

- <https://agentskills.io/specification.md>: the Agent Skills specification, covering `SKILL.md` format and frontmatter, progressive disclosure, `references/`, `scripts/`, `assets/`.
- <https://github.com/agentplugins/agent-plugins-spec/blob/main/spec/1.0.0.md>: the Agent Plugins 1.0 manifest standard.
- <https://agentskills.io/skill-creation/best-practices.md>: skill-authoring guidance on conciseness, degrees of freedom, naming and description rules, eval-first iteration and anti-patterns.
- <https://code.visualstudio.com/docs/agent-customization/agent-plugins>: cross-client behaviour, where conformant clients diverge despite the specs, and the shared placeholder vocabulary.

### Copilot layer (`copilot-docs`)

- <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference>: `plugin.json` and `marketplace.json` schemas, the `copilot plugin` CLI, `.agent.md` agents, LSP servers.
- <https://docs.github.com/en/copilot/reference/hooks-reference>: the Copilot hook event roster and handler types.
- <https://docs.github.com/en/copilot/reference/customization-cheat-sheet>: repository customization surfaces.

### Claude Code layer (`anthropic-docs`)

- <https://code.claude.com/docs/en/plugins.md>: creating plugins, local testing (`--plugin-dir`, `/reload-plugins`), converting standalone `.claude/` config, marketplace submission.
- <https://code.claude.com/docs/en/plugins-reference.md>: manifest schema, component locations, path rules, plugin caching, the `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DATA` contract, version management, the plugin CLI.
- <https://code.claude.com/docs/en/plugin-marketplaces.md>: `marketplace.json` schema and source variants including `git-subdir`, hosting and team configuration.
- <https://code.claude.com/docs/en/skills.md>: `SKILL.md` frontmatter, invocation control, dynamic context injection, skill lifecycle and evals.
- <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md>: Claude-flavoured skill-authoring best practices.
- <https://code.claude.com/docs/en/sub-agents.md>: agent frontmatter, plugin-agent restrictions, memory, preloaded skills and forks.
- <https://code.claude.com/docs/en/hooks.md>: hook events, matchers, exec versus shell form, exit codes, JSON output shapes, handler types and async hooks.
- <https://code.claude.com/docs/en/mcp.md>: server configuration, plugin-provided servers and scoped tool naming, tool search and OAuth.
- <https://code.claude.com/docs/en/tools-reference.md>: canonical tool names, permission-rule formats and per-tool behaviour.
- <https://code.claude.com/docs/en/env-vars.md>: every environment variable Claude Code reads.
- <https://code.claude.com/docs/en/channels-reference.md>: building channel MCP servers that push events into a session.
