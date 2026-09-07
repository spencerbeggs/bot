# Plugin marketplaces

> Verified against <https://code.claude.com/docs/en/plugin-marketplaces.md> — 2026-07-10

## Contents

- [marketplace.json top-level schema](#marketplacejson-top-level-schema)
- [Owner fields](#owner-fields)
- [Plugin entries](#plugin-entries)
- [Plugin sources](#plugin-sources)
- [Strict mode](#strict-mode)
- [Skills scan under a marketplace-root source](#skills-scan-under-a-marketplace-root-source)
- [Hosting and distribution](#hosting-and-distribution)
- [Managed marketplace restrictions](#managed-marketplace-restrictions)
- [Version resolution and release channels](#version-resolution-and-release-channels)
- [Rename or remove a plugin](#rename-or-remove-a-plugin)
- [CLI commands](#cli-commands)
- [Validation and troubleshooting](#validation-and-troubleshooting)

## marketplace.json top-level schema

File: `.claude-plugin/marketplace.json` at repo root.

| Field | Type | Req | Description |
| :--- | :--- | :--- | :--- |
| `name` | string | Yes | Marketplace identifier (kebab-case). Public-facing (`/plugin install x@name`). One marketplace per name per user — adding a second under the same name replaces the first |
| `owner` | object | Yes | Maintainer info — see [Owner fields](#owner-fields) |
| `plugins` | array | Yes | Plugin entries — see [Plugin entries](#plugin-entries) |
| `$schema` | string | No | JSON Schema URL for editor autocomplete. Ignored at load time |
| `description` | string | No | Brief marketplace description |
| `version` | string | No | Marketplace manifest version |
| `metadata.pluginRoot` | string | No | Base dir prepended to relative plugin `source` paths (e.g. `"./plugins"` lets entries write `"source": "formatter"`) |
| `allowCrossMarketplaceDependenciesOn` | array | No | Other marketplaces this marketplace's plugins may depend on. Deps from an unlisted marketplace are blocked at install |
| `renames` | object | No | Former name → current name (or `null` if removed) map. Requires v2.1.193+. See [Rename or remove a plugin](#rename-or-remove-a-plugin) |

`description` and `version` are also accepted nested under `metadata` for backward compatibility.

**Reserved marketplace names** (third parties can't use; re-checked on every load, not just add): `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `claude-plugins-community`, `claude-community`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `anthropic-agent-skills`, `knowledge-work-plugins`, `life-sciences`, `claude-for-legal`, `claude-for-financial-services`, `financial-services-plugins`, `first-party-plugins`, `healthcare`. Impersonating names (`official-claude-plugins`, `anthropic-plugins-v2`) also blocked. A marketplace registered under a name before it became reserved stops loading (errors "registered from an untrusted source") — remove and re-add under a different name. Before v2.1.205, `first-party-plugins` and `healthcare` weren't reserved.

## Owner fields

| Field | Type | Req | Description |
| :--- | :--- | :--- | :--- |
| `name` | string | Yes | Maintainer/team name |
| `email` | string | No | Contact email |

## Plugin entries

Each entry in `plugins[]` can include any field from the [plugin manifest schema](plugins-reference.md#plugin-manifest-schema) (`description`, `version`, `author`, `commands`, `hooks`, ...) plus marketplace-specific fields below.

### Required

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | string | Plugin identifier (kebab-case). Public-facing (`/plugin install name@marketplace`) |
| `source` | string\|object | Where to fetch the plugin — see [Plugin sources](#plugin-sources) |

### Optional — standard metadata

| Field | Type | Description |
| :--- | :--- | :--- |
| `displayName` | string | UI label, falls back to `name`. Not used for namespacing/lookup. Requires v2.1.143+ |
| `description` | string | Brief plugin description |
| `version` | string | Pins the plugin; omit to fall back to git commit SHA. See [Version resolution](#version-resolution-and-release-channels) |
| `author` | object | `name` required, `email` optional |
| `homepage` | string | Docs URL |
| `repository` | string | Source repo URL |
| `license` | string | SPDX identifier |
| `keywords` | array | Discovery tags |
| `category` | string | Organization category |
| `tags` | array | Searchability tags |
| `strict` | boolean | Whether `plugin.json` is the component authority. Default `true` — see [Strict mode](#strict-mode) |
| `relevance` | object | Signals for org-suggested plugins; effective only in managed-settings-allowlisted marketplaces. Requires v2.1.152+ |
| `defaultEnabled` | boolean | Enabled after install (default `true`). Takes precedence over the same field in `plugin.json`. Requires v2.1.154+ |

### Optional — component configuration

| Field | Type | Description |
| :--- | :--- | :--- |
| `skills` | string\|array | Custom paths to skill dirs containing `<name>/SKILL.md` |
| `commands` | string\|array | Custom paths to flat `.md` skill files/dirs |
| `agents` | string\|array | Custom paths to agent files |
| `hooks` | string\|object | Inline hooks config or path |
| `mcpServers` | string\|object | Inline MCP config or path |
| `lspServers` | string\|object | Inline LSP config or path |

## Plugin sources

Set in each entry's `source` field. After fetch, Claude Code copies the plugin into `~/.claude/plugins/cache`.

| Source | Type | Fields | Notes |
| :--- | :--- | :--- | :--- |
| Relative path | `string` (`"./my-plugin"`) | none | Local dir in the marketplace repo. Must start with `./`. Resolves against the marketplace root (dir containing `.claude-plugin/`), not `.claude-plugin/` itself. No `../` |
| `github` | object | `repo`, `ref?`, `sha?` | — |
| `url` | object | `url`, `ref?`, `sha?` | Any git host URL (`https://` or `git@`; `.git` suffix optional) |
| `git-subdir` | object | `url`, `path`, `ref?`, `sha?` | Sparse clone of one subdir — for monorepos. `url` also accepts `owner/repo` shorthand or SSH URL |
| `npm` | object | `package`, `version?`, `registry?` | Installed via `npm install` |

**Marketplace source vs. plugin source**: the marketplace *source* (where `marketplace.json` itself is fetched from, set via `/plugin marketplace add` or `extraKnownMarketplaces`) supports `ref` but not `sha`. Each plugin *entry's* `source` supports both `ref` and `sha` and is pinned independently of the marketplace's own source.

**`ref`/`sha` precedence** (github/url/git-subdir): when both are set, `sha` is the effective pin — Claude Code fetches that exact commit directly. On GitHub/GitLab/Bitbucket, install still succeeds even if the `ref` branch/tag was since deleted, as long as the commit is reachable. Servers that can't fetch by SHA (e.g. AWS CodeCommit) require `ref` to still exist and reach the pinned commit.

**Relative-path caveat**: resolves only against a local copy of the marketplace (git clone or local dir) — fails with "path not found" when the marketplace was added via a direct URL to `marketplace.json`, since only that file is downloaded. Use `github`/`npm`/git-URL sources, or a git-hosted marketplace, for URL-based distribution.

Full per-type field tables:

- `github`: `repo` (required, `owner/repo`), `ref` (optional, branch/tag, defaults to default branch), `sha` (optional, 40-char commit SHA).
- `url`: `url` (required, full git URL), `ref` (optional), `sha` (optional).
- `git-subdir`: `url` (required), `path` (required, subdir containing the plugin), `ref` (optional), `sha` (optional).
- `npm`: `package` (required, may be scoped), `version` (optional, exact or range e.g. `^2.0.0`), `registry` (optional, defaults to npmjs.org).

## Strict mode

`strict` on a plugin entry controls whether `plugin.json` is authoritative for components (skills, agents, hooks, MCP servers, output styles).

| Value | Behavior |
| :--- | :--- |
| `true` (default) | `plugin.json` is authoritative; marketplace entry can supplement with additional components — both merged |
| `false` | Marketplace entry is the entire definition. A `plugin.json` that also declares components is a conflict — plugin fails to load |

Use `strict: false` when the marketplace operator wants full control over which files in the plugin repo are exposed as which components (curation independent of the plugin author).

## Skills scan under a marketplace-root source

By default a plugin's skills load from `skills/` under its `source`; paths in the `skills` field ADD to that scan (`["./skills/", "./extra-skills/"]`). **Exception**: when several entries share one `skills/` folder at the marketplace root (`source: "./"`), listing specific subdirectories (`"skills": ["./skills/code-review", "./skills/docs"]`) makes that list the *complete* set for the entry — other dirs in the shared folder don't load. Listing `./skills/` itself, or the plugin root, keeps the full scan. If none of the listed paths exist, the default scan runs instead.

## Hosting and distribution

- **GitHub (recommended)**: push `.claude-plugin/marketplace.json` to a repo; users add with `/plugin marketplace add owner/repo`.
- **Other git hosts** (GitLab, Bitbucket, self-hosted): `/plugin marketplace add https://gitlab.com/company/plugins.git`.
- **Private repos**: manual install/update uses existing git credential helpers (HTTPS via `gh auth login`/keychain/credential-store; SSH via `known_hosts` + loaded `ssh-agent` key — no interactive prompts). Background auto-update needs a token env var since it can't prompt:

  | Provider | Env vars | Notes |
  | :--- | :--- | :--- |
  | GitHub | `GITHUB_TOKEN` or `GH_TOKEN` | PAT or GitHub App token |
  | GitLab | `GITLAB_TOKEN` or `GL_TOKEN` | PAT or project token |
  | Bitbucket | `BITBUCKET_TOKEN` | App password or repo access token |

- **Test locally**: `/plugin marketplace add ./my-marketplace` then `/plugin install <plugin>@<marketplace>`.
- **Team auto-prompt** — `.claude/settings.json`:

  ```json
  {
    "extraKnownMarketplaces": {
      "company-tools": { "source": { "source": "github", "repo": "your-org/claude-plugins" } }
    },
    "enabledPlugins": {
      "code-formatter@company-tools": true
    }
  }
  ```

  A local `directory`/`file` source with a relative path resolves against the repo's main checkout — worktrees all share that one location. Marketplace state lives once per user in `~/.claude/plugins/known_marketplaces.json`, not per project.

- **Container/CI seeding**: set `CLAUDE_CODE_PLUGIN_SEED_DIR` to a pre-built dir mirroring `~/.claude/plugins` (`known_marketplaces.json`, `marketplaces/<name>/...`, `cache/<marketplace>/<plugin>/<version>/...`). Layer multiple dirs with `:` (Unix) / `;` (Windows) — first seed containing a given marketplace/plugin wins. Build by running Claude Code once, installing plugins, then copying `~/.claude/plugins`; or set `CLAUDE_CODE_PLUGIN_CACHE_DIR` during build to install straight to the seed path. Behavior: seed dir is **read-only** (no auto-update); **seed entries take precedence** over user config on each startup — use `/plugin disable` to opt out rather than removing the marketplace; path resolution probes `$CLAUDE_CODE_PLUGIN_SEED_DIR/marketplaces/<name>/` at runtime (works if seed is mounted at a different path than built); `/plugin marketplace remove`/`update` fail against a seed-managed marketplace.

## Managed marketplace restrictions

`strictKnownMarketplaces` (managed settings) restricts which marketplaces users may add. Pair with `disableSideloadFlags` to also block the CLI flags that sideload plugins/agents/MCP servers for a single run.

| Value | Behavior |
| :--- | :--- |
| Undefined (default) | No restriction |
| `[]` | Complete lockdown — no new marketplaces |
| List of sources | Only allowlisted sources may be added |

Allowlist entry source types: `github` (`repo` req, `ref`/`path` must also match if specified), `url` (full URL must match exactly — no normalization: trailing slash / `.git` / `ssh://` vs `https://` differ), `hostPattern` (regex against marketplace host — recommended for GitHub Enterprise Server / self-hosted GitLab), `pathPattern` (regex against filesystem path; `".*"` allows any local path while `hostPattern` still gates network sources).

Checked before any network/filesystem op — on add, install, update, refresh, auto-update. A marketplace added before the policy existed, whose source no longer matches, is refused further installs/updates. Same enforcement applies to `blockedMarketplaces`. `strictKnownMarketplaces` alone doesn't register marketplaces — pair with `extraKnownMarketplaces` to auto-register allowed ones. Set in managed settings only — not overridable by user/project config.

## Version resolution and release channels

Resolution order (first set wins): 1) `plugin.json`'s `version`, 2) the marketplace entry's `version`, 3) git commit SHA of the plugin's source. Git-based sources (`github`, `url`, `git-subdir`, relative path in a git-hosted marketplace) can omit `version` entirely so every new commit is a new version.

**Gotcha**: setting `version` pins the plugin — pushing commits without bumping it does nothing for existing users. Never set `version` in both `plugin.json` and the marketplace entry: `plugin.json`'s value always wins silently, so a stale manifest version can mask one you set in `marketplace.json`.

**Release channels**: run two marketplaces pointing at different `ref`/`sha` of the same repo (e.g. `stable` vs `latest`), assign each to a user group via `extraKnownMarketplaces` in managed settings. Each channel must resolve to a distinct version — if using explicit `version`, it must differ per pinned ref; if omitted, distinct commit SHAs already distinguish them. Two refs resolving to the same version string are treated as identical (no update).

## Rename or remove a plugin

`name` is the stable identifier referenced in `enabledPlugins`, `pluginConfigs`, and `/plugin install` — changing it breaks existing installs. To relabel UI only, set `displayName` and keep `name`.

To actually rename/remove, add a top-level `renames` map (former name → new name, or `null` if removed). Requires v2.1.193+ for automatic migration; earlier versions report `plugin-not-found` for the old name.

```json
{
  "renames": {
    "formatter": "code-formatter",
    "legacy-linter": null
  }
}
```

Behavior on load with an old name still in settings: renamed → loads under new name, shows a one-line notice, and rewrites the old key to the new key across user/project/local scopes for both `enabledPlugins` and `pluginConfigs` (notice fires once); removed (`null`) → old key dropped, notice reports removal; renamed plugin with a remote source (`github`/`npm`) → reports `plugin-cache-miss`, user must run `/plugin install` once under the new name. Treat `renames` as append-only — chase-renaming (`code-formatter` → `formatter-pro` later) needs a *second* entry, not an edit to the first; a user still on the original `formatter` then resolves through both hops. `claude plugin validate .` rejects a chain that cycles or doesn't terminate at `null`/a listed plugin. Managed/policy `enabledPlugins` entries are read-only to Claude Code — the rename notice recurs each session until an admin updates them.

## CLI commands

`claude plugin marketplace <subcommand>` — non-interactive equivalents of `/plugin marketplace <subcommand>`.

| Command | Purpose | Key options |
| :--- | :--- | :--- |
| `add <source> [options]` | Add from GitHub `owner/repo` (append `@ref` to pin), git URL (append `#ref`), remote `marketplace.json` URL, or local path. URLs need an explicit scheme (v2.1.196+; a bare host is rejected, not misread as a GitHub path) | `--scope <user\|project\|local>` (default `user`); `--sparse <paths...>` (git sparse-checkout, for monorepos) |
| `list [options]` | List configured marketplaces | `--json` — adds `name`, `source`, source-specific fields (`repo`/`url`/`path`), `ref` if pinned |
| `remove <name> [options]` / alias `rm` | Remove by `marketplace.json`'s `name` (not the `add` source) | `--scope` (omit = all scopes; removing the last scope also uninstalls its plugins) |
| `update [name]` | Refresh from source(s); omit name for all | Fails against seed-managed marketplaces (read-only); other marketplaces still update when updating "all" |

## Validation and troubleshooting

`claude plugin validate .` (or `/plugin validate .`) against a marketplace directory checks `marketplace.json` schema, duplicate plugin names, and source path traversal; for each entry with a local-path `source` it also validates that plugin's own `plugin.json` and warns on a `version` mismatch between entry and manifest (errors prefixed `plugins[N] plugin.json →`). v2.1.196+: also includes entries whose `source` is `.`, runs when `marketplace.json` sits outside a `.claude-plugin/` dir (resolving sources against that file's own directory), and reports each entry's problems independently even if another part of the file has schema errors. Earlier versions skip root-level entries and require a `.claude-plugin/marketplace.json` path.

**Common errors**: `File not found: .claude-plugin/marketplace.json`; `Invalid JSON syntax`; `Duplicate plugin name "x"`; `plugins[0].source: Path contains ".."` (no `..` — see relative-path rule above); `YAML frontmatter failed to parse` (skill/agent/command file, loads with no metadata); `Invalid JSON syntax` in `hooks/hooks.json` (blocks the whole plugin from loading).

**Warnings** (non-blocking): `Marketplace has no plugins defined`; `No marketplace description provided`; `Plugin name "x" is not kebab-case` (Claude Code still accepts it, but claude.ai marketplace sync rejects it).

**Operational env vars**: `CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1` — keep the stale clone instead of wiping it when `git pull` fails (offline/airgapped environments; use `CLAUDE_CODE_PLUGIN_SEED_DIR` for fully offline). `CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS` — override the default 120s git-operation timeout (clone/pull).

See [plugins-reference.md](plugins-reference.md) for plugin caching/file resolution, symlink rules, and the full `plugin.json` manifest schema.
