---
name: anthropic-docs
description: Distilled, verification-stamped reference for the official Claude Code platform contract — plugins, skills, subagents, hooks, MCP, tools, env vars and channels. Use when authoring or auditing any Claude Code plugin component, looking up a frontmatter field, hook event schema, manifest rule, permission-rule format or tool name, or whenever a platform claim needs verifying instead of recalling from memory.
---

# Anthropic docs

Distilled references for the Claude Code platform, one file per official doc page. Each file opens with a stamp naming the exact URL and date it was verified against. The platform changes fast; these files exist so you look things up instead of trusting training-data recall.

## Evidence ladder

Apply this for every platform claim, in order. Never skip to memory.

1. **Use the reference.** Read the matching file below. It carries the contract: field tables, schemas, exact values, version gates.
2. **Escalate to the live doc** when the reference is silent, when the claim is version-sensitive, or when the stamp date looks old relative to the feature. WebFetch the stamped URL at the top of the reference file — never a URL from memory.
3. **Never guess.** If neither the reference nor the live doc settles the claim, say so and stop. A confident wrong answer about a hook schema or frontmatter field ships broken plugins.

Version gates in these files ("Requires Claude Code v2.1.x") are preserved verbatim from the docs — check them before relying on a feature.

## References

All files live in `references/` beside this file. Load only what the task needs.

| File | Load when |
| :-- | :-- |
| [plugins.md](references/plugins.md) | Creating or testing a plugin: `--plugin-dir`, `/reload-plugins` semantics, directory layout, converting standalone `.claude/` config, marketplace submission |
| [plugins-reference.md](references/plugins-reference.md) | Manifest schema questions, component locations and path rules, `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_DATA}` contracts, plugin caching, version management, `claude plugin` CLI |
| [plugin-marketplaces.md](references/plugin-marketplaces.md) | Authoring or editing a marketplace.json, choosing plugin source forms, hosting or team-configuring marketplaces |
| [skills.md](references/skills.md) | Authoring a SKILL.md: frontmatter fields, invocation control, command naming, substitutions, dynamic context injection, skill lifecycle, listing budget |
| [skill-best-practices.md](references/skill-best-practices.md) | Judging or improving skill quality: conciseness, descriptions, progressive disclosure, workflows, eval-first iteration, the pre-share checklist |
| [subagents.md](references/subagents.md) | Authoring an agent file: frontmatter fields, plugin-scope restrictions, model resolution, tool restriction, skill preloading, memory, forks |
| [hooks.md](references/hooks.md) | Hook system questions: events, matchers, handler types, exec vs shell form, exit codes, JSON output fields, async hooks |
| [hook-events.md](references/hook-events.md) | A specific event's input/output schema or decision-control fields — per-event contracts for every hook event |
| [mcp.md](references/mcp.md) | Bundling or configuring MCP servers: `.mcp.json` shapes, plugin-scoped tool naming, tool search, OAuth, timeouts, `_meta` annotations |
| [tools.md](references/tools.md) | Referencing a tool by name: the built-in tools table, permission-rule formats, per-tool behavior gotchas |
| [env-vars.md](references/env-vars.md) | Environment-variable questions: plugin-relevant vars, precedence rules; the full catalog lives at the stamped URL |
| [channels.md](references/channels.md) | Building a channel MCP server: capability declaration, notification format, reply tools, sender gating, permission relay |

## Stamp policy

Every reference opens with `> Verified against <url> — YYYY-MM-DD`. When you correct or extend a reference after checking the live doc, update its stamp date in the same edit. Never edit a reference from memory.
