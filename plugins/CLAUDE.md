# Plugin Development (plugins/)

Context for developing Claude Code plugins in this repo. Applies to all work under `plugins/`.

## Overview

Plugins under `plugins/*` ship skills, agents, hooks, commands and MCP servers for Claude Code. They are enabled in working sessions via the local marketplace entry in `.claude-plugin/marketplace.json` (source `./plugins/<name>`).

## Fetch-first documentation policy

Claude Code changes fast: new components, hook events, frontmatter fields and env vars ship constantly, so training-data recall and internal references go stale. Before authoring or auditing a plugin component, fetch the relevant official doc with WebFetch and verify against it — when in doubt, don't guess. Docs mark version-gated behavior ("Requires Claude Code vX.Y.Z"); check gates before relying on a feature. Full doc index: <https://code.claude.com/docs/llms.txt>.

The plugin-bot plugin's `anthropic-docs` skill carries stamped distillations of all of these docs under `plugins/plugin-bot/skills/anthropic-docs/references/` — check the relevant reference first, escalate to the live URL per its stamp.

## Official docs by component

Fetch the doc matching what you are touching:

- <https://code.claude.com/docs/en/plugins.md> — creating/testing plugins (`--plugin-dir`, `/reload-plugins`), converting standalone config, marketplace submission.
- <https://code.claude.com/docs/en/plugins-reference.md> — manifest schema, component locations, plugin cache, `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_DATA}`, version management, plugin CLI.
- <https://code.claude.com/docs/en/plugin-marketplaces.md> — marketplace.json schema, plugin source variants, hosting and team configuration.
- <https://code.claude.com/docs/en/skills.md> — SKILL.md frontmatter, invocation control, dynamic context injection, skill lifecycle.
- <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md> — skill authoring quality: conciseness, descriptions, progressive disclosure, evals.
- <https://code.claude.com/docs/en/sub-agents.md> — agent frontmatter, plugin-agent restrictions, memory, preloaded skills.
- <https://code.claude.com/docs/en/hooks.md> — events, matchers, exec vs shell form, exit codes, JSON output, hook types.
- <https://code.claude.com/docs/en/mcp.md> — server config, plugin-bundled servers and scoped tool naming (`mcp__plugin_<plugin>_<server>__<tool>`), tool search.
- <https://code.claude.com/docs/en/tools-reference.md> — canonical tool names and permission-rule formats.
- <https://code.claude.com/docs/en/env-vars.md> — every env var Claude Code reads.
- <https://code.claude.com/docs/en/channels-reference.md> — channel MCP servers that push events into a session.

## Local development loop

- Plugins here load through the local marketplace entry in `.claude-plugin/marketplace.json`, so edits take effect in this repo's working sessions.
- After editing plugin components, have the user run `/reload-plugins`. SKILL.md text changes hot-reload without it; hooks, `.mcp.json` and agents need the reload.
- Run `claude plugin validate <path> --strict` before considering plugin work done.
- A CLAUDE.md at a plugin's own root is NOT loaded as plugin context — plugins ship context via skills. That is why this guidance lives at the `plugins/` level.

## Design docs

- Architecture → `@../.claude/design/plugin-bot/architecture.md` — Load when: changing plugin-bot's structure, components or development workflow.
- Upstream docs policy → `@../.claude/design/plugin-bot/upstream-docs.md` — Load when: deciding which official doc to fetch or updating the doc-link inventory.
