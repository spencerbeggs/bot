---
type: Runbook
title: Local plugin development loop
description: Load plugin-bot and dogfood from source, reload after edits, and validate before calling plugin work done.
status: draft
resource: ../../package.json
tags:
  - dx
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: 71bc900ae4aa2c285be43930375813c4078c826bc27f3361519869e5735b067c
---

# Local plugin development loop

**Trigger:** you are editing any plugin component (skill, agent, hook, `.mcp.json`, manifest) under `plugins/`.

## Steps

1. Start the session with `pnpm claude`. The `claude` script in `package.json` runs `claude --plugin-dir ./plugins/plugin-bot/claude-code --plugin-dir ./plugins/dogfood/claude-code`, loading both plugins from source and shadowing any same-named marketplace install for that session. This is the only loop that serves local edits; see [why the marketplace does not](../gotchas/marketplace-never-serves-working-tree.md).
2. Edit the component.
3. After editing hooks, `.mcp.json` or agents, ask the user to run `/reload-plugins`. Do the same for a skill edit that does not seem to land; see [the hot-reload scope](../gotchas/skill-hot-reload-scope.md).
4. Before calling Claude Code plugin work done, run `claude plugin validate <target-workspace> --strict`.
5. For Copilot, `copilot plugin install ./<workspace>` caches components, so reinstall after each edit. Copilot documents no validate subcommand.

A `CLAUDE.md` at a plugin's own root is not loaded as plugin context. Plugins ship context through skills, which is why the shared guidance lives in `plugins/CLAUDE.md`.

## End state

Validation passes and the change is observed working in the session.
