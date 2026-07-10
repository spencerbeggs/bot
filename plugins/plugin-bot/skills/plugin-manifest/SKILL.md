---
name: plugin-manifest
description: Enforces manifest well-formedness when `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.mcp.json`, or `.lsp.json` is opened for authoring or review — path-substitution rules, the hooks.json separation, and the house version policy.
user-invocable: false
paths:
  - "**/.claude-plugin/plugin.json"
  - "**/.claude-plugin/marketplace.json"
  - "**/.mcp.json"
  - "**/.lsp.json"
---

# Plugin manifest checklist

Apply this to the file you just opened. The mistake that matters most: hand-bumping `version` in this repo — versions here are CI-managed, not author-managed. The second: registering hooks inside `plugin.json` instead of `hooks/hooks.json`.

## Checklist

1. **`name` and `description` present**; `description` is a single sentence stating what the plugin does.
2. **Every plugin-owned path reference uses `${CLAUDE_PLUGIN_ROOT}`** — in `mcpServers`/`lspServers` `command`/`args`/`cwd`/`env`, in `hooks.json` commands, in any bundled-script reference. Bare relative paths break once the plugin runs from a cache install rather than a checkout.
3. **Hook registrations live in `hooks/hooks.json`, not `plugin.json`.** Keeping them separate lets `/reload-plugins` pick up hook edits without restarting MCP/LSP servers keyed off `plugin.json`.
4. **`mcpServers`/`lspServers` entries resolve their own `command`.** For npm-shim binaries (`.cmd`/`.bat`, or `node_modules/.bin` shims) invoke `node` directly with the script path in `args`, not the shim by exec form.
5. **`version` field is NOT hand-edited in this repo.** See house version policy below.
6. **`marketplace.json` entry `source` is either a relative path string (`"./plugins/<name>"`) or an object form (`{"source": "github"|"url"|"git-subdir"|"npm", ...}`) — this repo uses both; don't assume relative-path is the only valid form.** Any `version` set on the entry is superseded by `plugin.json`'s `version` if both are present — don't set it in two places expecting independent control.
7. **Unrecognized-field warnings resolved, not ignored.** `claude plugin validate` treats a misspelled or leftover field as a warning, not an error, unless `--strict` is used — always run with `--strict` here (see below).
8. **`.mcp.json`/`.lsp.json` at plugin root, not nested**, unless the manifest's inline `mcpServers`/`lspServers` key is used instead — pick one form, don't duplicate a server in both.
9. **Component path fields have different merge semantics — CRITICAL.** `commands`/`agents`/`outputStyles`/`experimental.*` REPLACE their default directory when set in `plugin.json`. The classic mistake: setting `"commands": [...]` and silently losing the default `commands/` directory — list it explicitly to keep it (`["./commands/", "./extras/"]`). `skills` is the exception: it ADDS to the default `skills/` scan rather than replacing it.
10. **`**/.mcp.json` and `**/.lsp.json` also match non-plugin project files.** Confirm the file is at a plugin root (sibling of `.claude-plugin/`) before applying this checklist to it.

## House version policy

This repo's plugins are versioned by CI. **Do not hand-bump `version` in `plugin.json` or `marketplace.json`.** If a change needs a version bump, that's a release-process concern, not something to fix inline while editing the manifest for an unrelated reason. Flag a manual version edit in review rather than making one yourself.

## Validate before finishing

Manifest work is not done until this passes:

```bash
claude plugin validate <plugin-path> --strict
```

`--strict` promotes warnings (misspelled fields, wrong types, leftover fields from another tool's manifest) to errors — the default (non-strict) mode lets a plugin with only warnings pass and load anyway, which hides the kind of mistake this checklist exists to catch.

## Common mistakes

- Hook registrations pasted into `plugin.json` instead of `hooks/hooks.json`.
- Bare relative path in an `mcpServers`/`lspServers` `command` — breaks under cache-install cwd.
- Manual `version` bump alongside an unrelated manifest edit.
- Running `claude plugin validate` without `--strict` and treating a clean run as sufficient.
- `.cmd`/`.bat` shim referenced via exec form (`args` present) — spawn fails; invoke the underlying script with `node` instead, or drop to shell form.

## Read for the full contract

- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/plugins-reference.md` — full manifest schema, component locations, path-substitution rules, `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_DATA}` contracts, version resolution order, `claude plugin` CLI.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/mcp.md` — `.mcp.json` server shapes, plugin-scoped tool naming, OAuth, timeouts.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/plugin-marketplaces.md` — `marketplace.json` schema, plugin source variants, hosting, team/managed configuration.

Scaffolding a brand-new plugin rather than auditing a manifest? Invoke the `plugin-setup` skill for the bootstrap checklist and the house `hooks/lib/` templates.
