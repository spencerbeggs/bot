# Agent Plugins 1.0 manifest standard

> Verified against <https://github.com/agentplugins/agent-plugins-spec/blob/main/spec/1.0.0.md> — 2026-09-07
> Verified against <https://code.visualstudio.com/docs/agent-customization/agent-plugins> — 2026-09-07

Agent Plugins is "an open, vendor-neutral standard for packaging reusable components that extend AI agents into distributable plugins". Version 1.0.0 carries **Status: Published**; 1.1.0 is a working draft.

## Scope — skills and MCP only

Agent Plugins v1 defines **exactly two component types: skills and MCP servers.** Everything else is outside the format:

> Other proposed component types — such as commands, hooks, agents, rules, and LSP servers — remain too client-specific for a stable portable contract and are outside the v1 format until their formats converge.

**Consequence for authoring:** agents, hooks, slash commands and rules always need per-host authoring. There is no portable spelling to write them in, and no amount of manifest work makes one host's agent file load in another. Only skills and MCP travel.

Clients must ignore component types they do not support.

## The manifest

`plugin.json` in the plugin root. The spec defines **exactly one portable manifest per plugin** — no other file can replace, supplement, or override its core fields, and the client loads and validates it before discovering any components.

The schema is **closed**. The only permitted top-level fields are:

| Field | Required | Type | Notes |
| :-- | :-- | :-- | :-- |
| `$schema` | Yes | string | Must be `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json` for 1.0.0. |
| `name` | Yes | string | Human-readable plugin name; constraints below. |
| `version` | No | string | Semantic Versioning recommended; used for update checks and cache freshness. |
| `description` | No | string | Short description of plugin purpose. |
| `author` | No | object | Only `name`, `email`, `url`, each a string. Any other member invalidates the manifest. |
| `homepage` | No | string | Documentation or homepage URL. |
| `repository` | No | string | Source repository URL. |
| `license` | No | string | SPDX identifier recommended. |
| `keywords` | No | string[] | Search and discovery tags. |
| `extensions` | No | object | Client-specific data; see below. |

Minimal conforming manifest:

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "minimal-plugin"
}
```

### `name` constraints

1–64 characters; `a-z`, `0-9`, `-` and `.` only; first and last characters alphanumeric; no `--` and no `..`. **Periods are allowed in plugin names** — this is the notable difference from an Agent Skills `name`, which permits hyphens only.

Valid: `my-plugin`, `acme.tools`, `lint3r`, `a`. Invalid: `My-Plugin`, `-start`, `has--double`, `too.many..dots`.

### Failure boundaries

- Unknown top-level field → report and ignore, keep loading.
- Non-object `extensions` → report and ignore, keep loading.
- **Any other schema violation → fatal.** Reject the plugin; discover and execute nothing.
- Invalid fixed component location (e.g. `skills` is not a directory) → skip that component type only.
- Invalid `SKILL.md` → skip that skill only.
- Missing fixed location → not an error.

Clients must not retrieve a schema over the network while loading a plugin, and must reject a plugin whose declared `$schema` version they do not support.

## `extensions` — the escape hatch

Client-specific manifest data **must** live under a reverse-domain namespace in `extensions`; client-specific *files* under a top-level directory named for that same namespace. A client may use either or both.

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "example-plugin",
  "extensions": {
    "com.github.copilot": {
      "setting": true
    }
  }
}
```

Agent Plugins assigns **no** portable discovery, validation, loading or failure semantics to extension data or files — each client defines the behavior of its own namespace. A client must ignore namespaces it does not implement without validating their contents.

**This is the only sanctioned route to a single manifest.** Any move toward one manifest serving several hosts goes through `extensions` and a namespaced directory, never through a parallel manifest file. The spec forecloses the parallel-file option explicitly: no other file can supplement or override root `plugin.json`.

## Component discovery

Locations are fixed. `plugin.json` cannot override them or carry inline component configuration.

| Component type | Fixed location | Pattern |
| :-- | :-- | :-- |
| Skills | `skills/` | Immediate subdirectories containing `SKILL.md` |
| MCP servers | `mcp.json` | JSON configuration |

Skills are discovered from **immediate** children of `skills/` only — clients must not recurse deeper. The format itself belongs to the [Agent Skills specification](agent-skills-spec.md); Agent Plugins defines only where a skill is found inside a plugin.

Standard layout:

```text
my-plugin/
├── plugin.json
├── skills/
│   └── summarize/
│       ├── SKILL.md
│       ├── scripts/
│       │   └── analyze.sh
│       └── references/
│           └── checklist.md
├── mcp.json
├── com.example.client/
│   └── hooks/
├── LICENSE
└── CHANGELOG.md
```

## `mcp.json`

Requires `$schema` (`https://agent-plugins.org/schemas/1.0.0/mcp.schema.json`, which must match the `plugin.json` version) and `mcpServers`, which may be empty. Transports: **stdio**, **streamable-http**, and legacy **sse**. Clients must support at least stdio or Streamable HTTP; SSE support is optional.

- stdio: `command` (a single executable token — a bare name or a `./`-relative path, never a shell string, and **never placeholder-expanded**), `args`, `env`, `cwd` (defaults to the plugin root).
- HTTP transports: `url` must be absolute HTTPS, except loopback; `headers` are fixed and not expanded.

An invalid MCP configuration disables MCP but still loads the other components.

## Placeholders and the subprocess environment

Clients launching stdio MCP servers must provide two absolute paths in the subprocess environment:

- **`PLUGIN_ROOT`** — the filesystem-resolved plugin root.
- **`PLUGIN_DATA`** — a client-managed, writable, persistent directory unique to the plugin instance, created before launch and preserved across updates.

`${PLUGIN_ROOT}` and `${PLUGIN_DATA}` expand — once, non-recursively — in `args` elements, `env` **values** (not keys), and `cwd`. They do **not** expand in `command`, `env` keys, fixed component locations, `url` or `headers`. Unrecognized placeholders stay literal.

All package paths must resolve within the plugin root; plugin-relative paths begin with `./`. `${PLUGIN_DATA}`-rooted values may leave the plugin root but must stay inside the plugin data directory.

See [cross-client-behavior.md](cross-client-behavior.md) for how these two spellings line up against the Claude and Copilot vocabularies.

## Client conformance, in brief

A conformant client loads plugins from directory paths; validates `plugin.json`; ignores unimplemented `extensions` namespaces; discovers each supported component type from its fixed location; implements at least stdio or Streamable HTTP if it supports MCP; provides and expands `PLUGIN_ROOT`/`PLUGIN_DATA` if it launches subprocesses; resolves `command` as one token with the plugin root as default `cwd`; and supports at least one component type.

## VS Code's reading of the standard

The VS Code documentation frames Agent Plugins as "an open standard for packaging agent skills and MCP servers that works across multiple AI agents", and splits components the same way:

- **Portable:** skills (instructions, scripts, resources) and MCP servers.
- **Client-specific,** carried under the `com.github.copilot` namespace: custom agents, hooks, slash commands, rules.

The Agent Plugins standard is usable across GitHub Copilot in VS Code, GitHub Copilot CLI, and the GitHub Copilot app. Client-specific extensions under reverse-domain namespaces let a tool ignore components it does not implement while the rest of the plugin stays portable.

## Unverified claim, recorded as such

A specific v1.0.0 release date (2026-08-06) and a named launch-client roster (ChatGPT, Codex, Cursor, GitHub Copilot, Kiro, VS Code) circulate in secondary write-ups. **Neither is asserted by the spec repository as of this stamp**: the README states only that 1.0.0 "is the current published release" and names no clients, the repository publishes no releases or tags, and the newest commit touching `spec/1.0.0.md` is dated 2026-07-19. Do not repeat either claim as spec-backed. VS Code's own page is the only first-party client confirmation captured here.
