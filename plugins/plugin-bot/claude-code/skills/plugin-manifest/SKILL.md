---
name: plugin-manifest
description: Enforces manifest well-formedness when a plugin or marketplace manifest is opened for authoring or review — Claude Code's .claude-plugin/plugin.json and marketplace.json, Copilot's root plugin.json and .github/plugin/marketplace.json, and the MCP/LSP config files beside them. Covers the per-host manifest search orders, component-path fields and their add-vs-replace semantics, the extensions escape hatch, source-object variants, the tracking-package rule, and the house version policy.
user-invocable: false
paths:
  - "**/plugin.json"
  - "**/marketplace.json"
  - "**/.mcp.json"
  - "**/mcp.json"
  - "**/.lsp.json"
  - "**/lsp.json"
---

# Plugin manifest checklist

Apply this to the file you just opened. The mistake that matters most: hand-bumping `version` in this repo — versions here are CI-managed, not author-managed. The second: assuming one manifest dialect's rules apply to the other.

## Which layer are you in?

Read the target off the path before applying any rule. A rule marked for the other layer does not apply.

| Path shape | Layer | Manifest |
| :-- | :-- | :-- |
| `plugins/*/claude-code/**` | Claude Code | `.claude-plugin/plugin.json` |
| `plugins/*/copilot/**` | Copilot | root `plugin.json` |
| Neither, and `$schema` is `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json` | Agent Plugins 1.0 | root `plugin.json` |
| Neither, and no Agent Plugins `$schema` | **Default: Copilot** | root `plugin.json`, `.plugin/`, `.github/plugin/` |

The last row is the default, and it is deliberate rather than a fallthrough: a bare root `plugin.json` is Copilot's own format, so treat an unanchored one as Copilot unless something says otherwise. **Claude Code is claimed only by parentage** — the manifest's directory is `.claude-plugin/` — never by content sniffing. The bare `**/plugin.json` and `**/marketplace.json` globs cover Copilot's idiomatic root manifests and all their `.plugin/`, `.github/plugin/` and `.claude-plugin/` variants in one line each.

Before applying any rule, confirm the file is a plugin manifest at all: `**/mcp.json`, `**/.mcp.json`, `**/lsp.json` and `**/.lsp.json` also match ordinary project files that have nothing to do with plugins, and a stray `plugin.json` belonging to some other tool is possible even though no common toolchain claims that name.

## Shared checklist

1. **`name` and `description` present**; `description` is a single sentence stating what the plugin does. Do not carry a limit across layers: **only Copilot documents a cap** on a plugin manifest's `description` (1024 characters) or its `name` (64) — Claude Code and Agent Plugins state neither for `description`. (The 1024 you may be recalling elsewhere is the *skill* frontmatter cap, a different field on a different file.) The `name` grammars are not identical either: Agent Plugins spells its character class out and permits dots, Copilot permits dots for Open-Plugin-Spec compliance, and Claude Code documents only "kebab-case, no spaces" — which is not a stated prohibition on anything. Check your layer's reference rather than assuming the strictest rule applies everywhere.
2. **Every plugin-owned path reference uses the layer's placeholder** — in `mcpServers`/`lspServers` `command`/`args`/`cwd`/`env`, in hook commands, in any bundled-script reference. Bare relative paths break once the plugin runs from a cache install rather than a checkout. **No placeholder spelling is universal**, and `${COPILOT_PLUGIN_ROOT}` is defined by nothing; get the spelling for your layer from `agent-plugins-docs/references/cross-client-behavior.md` § Placeholder vocabulary rather than from memory.
3. **Hook registrations live in a `hooks.json`, not inline in the manifest.** Under Claude Code that file is `hooks/hooks.json`; keeping it separate lets `/reload-plugins` pick up hook edits without restarting MCP/LSP servers keyed off `plugin.json`. Under Copilot the `hooks` manifest field points at a `hooks.json`. Hooks are outside Agent Plugins 1.0 entirely — a portable manifest cannot carry them.
4. **`mcpServers`/`lspServers` entries resolve their own `command`.** For npm-shim binaries (`.cmd`/`.bat`, or `node_modules/.bin` shims) invoke `node` directly with the script path in `args`, not the shim by exec form. Under Agent Plugins 1.0 `command` is a single executable token, never a shell string, and is **never** placeholder-expanded.
5. **`version` field is NOT hand-edited in this repo.** See house version policy below.
6. **MCP/LSP config sits at the plugin root, not nested**, unless the manifest's inline `mcpServers`/`lspServers` key is used instead — pick one form, don't duplicate a server in both. The filename differs by layer: `.mcp.json` for Claude Code and Copilot, `mcp.json` for Agent Plugins 1.0.
7. **A marketplace entry's `source` is a relative path string or a source object.** Any `version` set on the entry is superseded by the plugin manifest's `version` if both are present — don't set it in two places expecting independent control. Object variants differ by layer; see the deltas.
8. **Schema-validation warnings resolved, not ignored.** Claude Code: `claude plugin validate` treats a misspelled or leftover field as a warning, not an error, unless `--strict` is used — always run with `--strict` here. Copilot: a marketplace entry's `strict` defaults to `true`; setting it `false` to silence a complaint is hiding the same class of mistake.
9. **A `package.json` beside the manifest is a tracking package, not a publishable one.** See below.

## Layer deltas

### Manifest search order — per-host, never merged

Each host has its own order and they are **not** the same list. VS Code detects by root manifest and does not list `.github/plugin/plugin.json` at all; the Copilot CLI searches four paths leading with `.plugin/`; Agent Plugins 1.0 defines no order at all and requires the manifest at root `plugin.json` and nowhere else. Both orders are printed side by side in `agent-plugins-docs/references/cross-client-behavior.md` § Manifest search order, and Copilot's own in `copilot-docs/references/plugin-reference.md`. Never restate them as one merged list.

The consequence that holds either way: **both hosts read `.claude-plugin/plugin.json`.** A Claude manifest inside a Copilot tree is therefore discovered, not broken — it is merely not idiomatic. Flag it as a style point, not an error. The real hazard is a repo carrying more than one manifest, which the two orders resolve to different formats.

### `$schema`

**Required** under Agent Plugins 1.0, and it must be the exact 1.0.0 URL. **Optional and ignored at load** under Claude Code and Copilot. A missing `$schema` is a fatal defect in a portable manifest and a non-issue in the other two.

### `extensions`

Agent Plugins 1.0's reverse-domain-keyed escape hatch — the **only** sanctioned way to carry client-specific data in one portable manifest (`com.github.copilot`, and so on). Client-specific *files* go under a top-level directory named for the same namespace. A parallel or supplementary manifest file is not an alternative; the spec forecloses it.

### Component-path semantics are not uniform

Under **Claude Code** a declared path can silently replace the default scan:

- **Replaces the default**: `commands`, `agents`, `workflows`, `outputStyles`, `experimental.themes`, `experimental.monitors`. The classic mistake is setting `"commands": [...]` and silently losing the default `commands/` directory — list it explicitly to keep it (`["./commands/", "./extras/"]`).
- **Adds to the default**: `skills` alone. This asymmetry is the footgun; do not generalize either half of it.

Under **Copilot** the component-path fields are plain defaults, and only `agents` and `skills` have one — the rest load nothing unless declared. Copilot's `commands` field has **no documented file format anywhere**; `copilot-docs/references/plugin-reference.md` marks it unsourced. Do not infer a format for it, and do not treat its absence as a defect to fix.

Under **Agent Plugins 1.0** component locations are fixed and the manifest cannot override them or carry inline component config.

### Source objects

| Layer | Object form | Keys |
| :-- | :-- | :-- |
| Claude Code | `github`, `url`, `git-subdir`, `npm` | `git-subdir` takes `url` + `path`, plus optional `ref`/`sha` |
| Copilot | `github`, `url` | `github` takes `repo` (`owner/repo`), plus optional `ref`/`path`/`sha` |

Both accept a plain repo-relative path string instead. Both accept `sha` — and **pinning a `sha` is what makes an install immune to force-pushes and tag or branch moves.** Where both `ref` and `sha` are set, Claude Code makes `sha` the effective pin; Copilot documents the `sha` recommendation but not a precedence rule, so do not assume the same resolution there.

### Claude-only manifest fields

`displayName`, `defaultEnabled`, `workflows`, `outputStyles`, `experimental.*`, `userConfig`, `channels` and `dependencies` exist only in the Claude Code manifest. Each one used is a portability cost: it has no Copilot equivalent, and in a portable manifest it is an unknown top-level field — reported and ignored, so the behavior silently vanishes rather than failing loudly. Several are also version-gated; check the gate in `plugins-reference.md` before relying on one.

## House version policy

This repo's plugins are versioned by CI. **Do not hand-bump `version` in a plugin manifest or a `marketplace.json`.** If a change needs a version bump, that's a release-process concern, not something to fix inline while editing the manifest for an unrelated reason. Flag a manual version edit in review rather than making one yourself.

## The tracking package beside the manifest

Every target workspace carries a `package.json` next to its plugin manifest. It is a **tracking package** — it exists only to give changesets something to version so the manifest is bumped, tagged and released in lockstep. It must:

- be `"private": true`,
- carry **no** `publishConfig`,
- be named `@<plugin>/<target>-plugin` (e.g. `@plugin-bot/claude-code-plugin`).

Its `version` and the manifest's `version` move together, under changesets. **Hand-editing either one is a defect** — including "fixing" a drift between them by editing the other.

## Validate before finishing

Claude Code manifest work is not done until this passes:

```bash
claude plugin validate <plugin-path> --strict
```

`--strict` promotes warnings (misspelled fields, wrong types, leftover fields from another tool's manifest) to errors — the default mode lets a plugin with only warnings pass and load anyway, which hides the kind of mistake this checklist exists to catch.

Copilot has no equivalent validator. Install and exercise instead — and note that **a local install caches its components**, so re-install after editing in place or the CLI keeps serving the previous copy:

```bash
copilot plugin install ./my-plugin
copilot plugin list
```

## Common mistakes

- Presenting the two hosts' manifest search orders as one merged list.
- Flagging `.claude-plugin/plugin.json` in a Copilot tree as an error — both hosts read it; it is a style point.
- Omitting `$schema` from an Agent Plugins 1.0 manifest (fatal), or expecting it to do anything under Claude Code (ignored).
- Setting a Claude `commands`/`agents`/`workflows`/`outputStyles` path and silently losing the default directory.
- Assuming Copilot's `commands` has a known file format — it does not; nothing documents one.
- Reaching for a parallel manifest to serve two hosts instead of `extensions` plus a namespaced directory.
- Bare relative path in an `mcpServers`/`lspServers` `command` — breaks under cache-install cwd.
- Writing `${COPILOT_PLUGIN_ROOT}`, or `${PLUGIN_DATA}` in a Copilot-targeted file — neither expands.
- Manual `version` bump alongside an unrelated manifest edit, or hand-editing the tracking `package.json` version.
- Running `claude plugin validate` without `--strict` and treating a clean run as sufficient.
- `.cmd`/`.bat` shim referenced via exec form (`args` present) — spawn fails; invoke the underlying script with `node` instead, or drop to shell form.

## Read for the full contract

Claude Code layer:

- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/plugins-reference.md` — full manifest schema, component locations, add-vs-replace table, path-substitution rules, `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_DATA}` contracts, version resolution order, `claude plugin` CLI.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/mcp.md` — `.mcp.json` server shapes, plugin-scoped tool naming, OAuth, timeouts.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/plugin-marketplaces.md` — `marketplace.json` schema, plugin source variants, `ref`/`sha` precedence, hosting, team/managed configuration.

Copilot layer:

- `${CLAUDE_PLUGIN_ROOT}/skills/copilot-docs/references/plugin-reference.md` — `plugin.json` fields, component paths, `lspServers` schema, `marketplace.json` and its `strict` flag, Copilot's own search order, install locations, loading precedence, CLI commands.
- `${CLAUDE_PLUGIN_ROOT}/skills/copilot-docs/references/hooks-reference.md` — Copilot's `hooks.json` contract.

Portable layer:

- `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/agent-plugins-spec.md` — the closed schema, `name` grammar, failure boundaries, `extensions`, fixed component locations, `mcp.json`.
- `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/cross-client-behavior.md` — both manifest search orders side by side, the placeholder vocabulary matrix, where each host looks for skills, the portability split.

Scaffolding a brand-new plugin rather than auditing a manifest? Invoke the `plugin-setup` skill for the bootstrap checklist and the house `hooks/lib/` templates.
