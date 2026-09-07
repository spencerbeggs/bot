# Copilot plugin reference

> Verified against <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference> — 2026-09-07
> Verified against <https://docs.github.com/en/copilot/concepts/agents/about-plugins> — 2026-09-07
> Verified against <https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating> — 2026-09-07
> Verified against <https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace> — 2026-09-07

What Copilot's manifest carries beyond the closed Agent Plugins 1.0 schema, how a plugin is discovered and installed, and how conflicts resolve. For the portable manifest itself — the `$schema` value, the `name` grammar, the closed-schema failure boundaries — read `agent-plugins-docs/references/agent-plugins-spec.md` first.

A Copilot plugin is a distributable package bundling components into one installable unit. It is supported on the Copilot CLI, the Copilot cloud agent (installed declaratively through `.github/copilot/settings.json`), and the GitHub Copilot app.

## `plugin.json`

`name` is the only required field.

| Field | Required | Notes |
| :-- | :-- | :-- |
| `name` | Yes | Kebab-case, max 64 characters. **Dots are permitted** where the plugin opts into Open Plugin Spec compliance (`acme.tools`). |
| `$schema` | No | Schema URL. |
| `description` | No | Max 1024 characters. |
| `version` | No | Plugin version. |
| `author` | No | Author metadata. |
| `homepage` | No | Homepage URL. |
| `repository` | No | Source repository URL. |
| `license` | No | License identifier. |
| `keywords` | No | Discovery tags. |
| `category` | No | **Copilot addition** — not in the Agent Plugins schema. |
| `tags` | No | **Copilot addition** — not in the Agent Plugins schema. |

### Component paths

All optional. Only `agents` and `skills` have defaults; the rest load nothing unless declared.

| Field | Default | Points at |
| :-- | :-- | :-- |
| `agents` | `agents/` | Directory of `.agent.md` files |
| `skills` | `skills/` | Directory of skill directories; may be an array of directories |
| `commands` | — | Slash-command definitions |
| `hooks` | — | A `hooks.json` file (see `hooks-reference.md`) |
| `extensions` | — | Client-specific data, the Agent Plugins escape hatch |
| `mcpServers` | — | An MCP config file, conventionally `.mcp.json` |
| `lspServers` | — | LSP server declarations |

The how-to's example spells these as `"agents": "agents/"`, `"skills": ["skills/", "extra-skills/"]`, `"hooks": "hooks.json"`, `"mcpServers": ".mcp.json"`.

## Agents — `.agent.md`

Agents are the Copilot component with no portable equivalent. One `.agent.md` file per agent under the `agents` path; the agent's ID is derived from the filename (`reviewer.agent.md` → `reviewer`). The how-to's frontmatter example:

```yaml
---
name: my-agent
description: Helps with specific tasks
tools: ["bash", "edit", "view"]
---
```

**Open question — do not resolve from memory.** The `tools` identifiers are unsettled. `plugins-creating` shows `["bash", "edit", "view"]`, as quoted above. A shipped port in another repo uses `["read", "edit", "search"]`. At most one is right, and the CLI plugin reference does not document `.agent.md` frontmatter at all, so neither candidate has a schema behind it. Record the ambiguity when it comes up; a later task settles it.

## `lspServers`

Also Copilot-only. At least one of `command`, `bash`, `powershell` is required; the CLI selects the platform-appropriate one.

| Field | Type | Required | Notes |
| :-- | :-- | :-- | :-- |
| `command` | string | One of three | Executable to launch. Ignored when `bash`/`powershell` is used. |
| `bash` | string | One of three | Run via `bash -c SCRIPT`. |
| `powershell` | string | One of three | Run via `pwsh -c SCRIPT`. |
| `fileExtensions` | object | **Yes** | Maps file extensions to language IDs. |
| `args` | string[] | No | Arguments to `command`; ignored for `bash`/`powershell`. |
| `cwd` | string | No | Working directory. **Supports `${PLUGIN_ROOT}`.** |
| `env` | object | No | Environment variables. |
| `rootUri` | string | No | Project root relative to the git root; defaults to `.`. |
| `initializationOptions` | any | No | Passed on the LSP `initialize` request. |

For which placeholder tokens expand and where, see `agent-plugins-docs/references/cross-client-behavior.md`. The short version, unchanged: `${PLUGIN_ROOT}`, `${COPILOT_PLUGIN_DATA}`, and `${CLAUDE_PLUGIN_DATA}` as an alias of the second. `${PLUGIN_DATA}` is Agent-Plugins-only and yields a literal unexpanded string on Copilot.

## `marketplace.json`

The distribution mechanism, with no portable counterpart. Required: `name`, `owner`, `plugins`.

| Field | Required | Notes |
| :-- | :-- | :-- |
| `name` | Yes | Kebab-case, max 64 characters; dots permitted as for a plugin name. |
| `owner` | Yes | Object with `name` and an optional `email`. |
| `plugins` | Yes | Array of plugin entries. |
| `metadata` | No | `{ description?, version?, pluginRoot? }`. |

Each entry requires `name` and `source`. Optional entry fields: `description`, `version`, `author`, `homepage`, `repository`, `license`, `keywords`, `category`, `tags`, `commands`, `agents`, `skills`, `hooks`, `mcpServers`, `lspServers`, and `strict`.

**`strict` defaults to `true`** — full schema validation. Setting it `false` relaxes validation.

A marketplace repository carries its `marketplace.json` under `.github/plugin/` (`.claude-plugin/` is also supported), and it is the only required component of a marketplace repository.

### Source objects

The reference's `github` source example, as printed:

```json
{
    "source": "github",
    "repo": "owner/repo",
    "ref": "v1.0.0",
    "path": "plugins/my-plugin"
}
```

A `url` source takes the same optional keys around a URL instead of a repo. Both types accept an optional `sha`:

```json
{
    "source": "url",
    "url": "https://example.com/plugin.tar.gz",
    "sha": "a94a8fe..."
}
```

Upstream guidance, verbatim: *"Pin to a `sha` for reproducible installs that are immune to force-pushes or tag/branch moves."*

Within a marketplace hosted in one repository, an entry's `source` may instead be a plain path relative to the repository root — `"plugins/frontend-design"`; a leading `./` is optional and resolves identically.

## Manifest search order — Copilot's own

The Copilot CLI searches, first found wins:

1. `.plugin/plugin.json`
2. `plugin.json`
3. `.github/plugin/plugin.json`
4. `.claude-plugin/plugin.json`

**This order is Copilot's, not a standard.** Agent Plugins 1.0 defines no search order, and VS Code detects the format in a different sequence that omits `.github/plugin/plugin.json` entirely. Never present the two hosts' orders as one merged list; see `agent-plugins-docs/references/cross-client-behavior.md` for both, side by side.

## Install locations

| Install route | Path |
| :-- | :-- |
| From a marketplace | `~/.copilot/installed-plugins/MARKETPLACE/PLUGIN-NAME` |
| Direct | `~/.copilot/installed-plugins/_direct/SOURCE-ID/` |

## Loading precedence

| Component | Rule |
| :-- | :-- |
| Agents | **First-found-wins**, deduplicated by ID. A project-level agent silently overrides a plugin's. |
| Skills | **First-found-wins**, deduplicated by the `name` field. A project-level skill silently overrides a plugin's. |
| MCP servers | **Last-loaded-wins**, deduplicated by server name. The CLI warns when two plugins declare the same name. |
| Built-in tools and agents | **Never overridable** by anything user-defined. |

The asymmetry is the trap: shipping a skill in a plugin does not guarantee it is the one that loads, and the override is silent for agents and skills but warned for MCP.

## CLI commands

```text
copilot plugin install SPECIFICATION
copilot plugin uninstall NAME
copilot plugin list
copilot plugin update NAME | --all
copilot plugin enable NAME
copilot plugin disable NAME

copilot plugin marketplace add SPECIFICATION
copilot plugin marketplace list
copilot plugin marketplace browse NAME
copilot plugin marketplace update [NAME]   # alias: refresh
copilot plugin marketplace remove NAME
```

A local plugin installs with `copilot plugin install ./my-plugin`. **Local installs cache their components**: after editing a plugin in place, reinstall it or the CLI keeps serving the previous copy. Verify with `copilot plugin list`, and exercise components with `/agent` and `/skills list`.
