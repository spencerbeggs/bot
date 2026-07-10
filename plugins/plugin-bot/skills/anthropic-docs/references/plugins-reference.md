# Plugins reference

> Verified against <https://code.claude.com/docs/en/plugins-reference.md> — 2026-07-10

## Contents

- [Component reference](#component-reference)
  - [Skills](#skills)
  - [Agents](#agents)
  - [Hooks](#hooks)
  - [MCP servers](#mcp-servers)
  - [LSP servers](#lsp-servers)
  - [Monitors](#monitors)
  - [Themes](#themes)
- [Plugin installation scopes](#plugin-installation-scopes)
- [Skills-directory plugins](#skills-directory-plugins)
- [Plugin manifest schema](#plugin-manifest-schema)
- [Path behavior rules](#path-behavior-rules)
- [Environment variables](#environment-variables)
- [Plugin caching and file resolution](#plugin-caching-and-file-resolution)
- [Plugin directory structure](#plugin-directory-structure)
- [CLI commands reference](#cli-commands-reference)
- [Debugging and common issues](#debugging-and-common-issues)
- [Version management](#version-management)

## Component reference

A **plugin** is a self-contained directory of components that extends Claude Code with custom functionality. Components: skills, agents, hooks, MCP servers, LSP servers, monitors, themes.

### Skills

**Location**: `skills/` or `commands/` directory in plugin root, or a single `SKILL.md` file at plugin root.
**Format**: skills are directories with `SKILL.md`; commands are flat markdown files.

```text
skills/
├── pdf-processor/
│   ├── SKILL.md
│   ├── reference.md (optional)
│   └── scripts/ (optional)
└── code-reviewer/
    └── SKILL.md
```

- Skills and commands are auto-discovered when the plugin is installed; Claude can invoke them automatically based on task context.
- If a plugin has no `skills/` directory and no `skills` manifest field, a `SKILL.md` at plugin root loads as a single skill. Use `skills/` layout for plugins shipping more than one skill. Invocation-name fallback rule — see [Path behavior rules](#path-behavior-rules).

### Agents

**Location**: `agents/` directory in plugin root. **Format**: markdown files.

```markdown
---
name: agent-name
description: What this agent specializes in and when Claude should invoke it
model: sonnet
effort: medium
maxTurns: 20
disallowedTools: Write, Edit
---

Detailed system prompt for the agent describing its role, expertise, and behavior.
```

**Supported frontmatter**: `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation` (only valid value: `"worktree"`).

**Not supported for plugin-shipped agents (security)**: `hooks`, `mcpServers`, `permissionMode` — these fields are ignored/rejected if present.

Integration: agents appear in @-mention typeahead under scoped name (`my-plugin:code-reviewer`) once enabled; Claude can invoke automatically or be invoked manually; work alongside built-in agents.

### Hooks

**Location**: `hooks/hooks.json` in plugin root, or inline in `plugin.json`. **Format**: JSON with event matchers and actions.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/format-code.sh" }
        ]
      }
    ]
  }
}
```

**Full event list** (plugin hooks respond to the same lifecycle events as user-defined hooks):

| Event | When it fires |
| :--- | :--- |
| `SessionStart` | Session begins or resumes |
| `Setup` | Started with `--init-only`, or `--init`/`--maintenance` in `-p` mode. One-time prep for CI/scripts |
| `UserPromptSubmit` | Prompt submitted, before Claude processes it |
| `UserPromptExpansion` | A user-typed command expands into a prompt, before it reaches Claude. Can block the expansion |
| `PreToolUse` | Before a tool call executes. Can block it |
| `PermissionRequest` | When a permission dialog appears |
| `PermissionDenied` | Tool call denied by the auto mode classifier. Return `{retry: true}` to let the model retry |
| `PostToolUse` | After a tool call succeeds |
| `PostToolUseFailure` | After a tool call fails |
| `PostToolBatch` | After a full batch of parallel tool calls resolves, before the next model call |
| `Notification` | Claude Code sends a notification |
| `MessageDisplay` | While assistant message text is displayed |
| `SubagentStart` | Subagent spawned |
| `SubagentStop` | Subagent finishes |
| `TaskCreated` | Task being created via `TaskCreate` |
| `TaskCompleted` | Task being marked completed |
| `Stop` | Claude finishes responding |
| `StopFailure` | Turn ends due to an API error. Output and exit code ignored |
| `TeammateIdle` | Agent-team teammate about to go idle |
| `InstructionsLoaded` | CLAUDE.md or `.claude/rules/*.md` loaded into context. Fires at session start and on lazy load during session |
| `ConfigChange` | Config file changes during a session |
| `CwdChanged` | Working directory changes (e.g. `cd`). Useful for reactive env management (direnv) |
| `FileChanged` | A watched file changes on disk. `matcher` field specifies which filenames to watch |
| `WorktreeCreate` | Worktree being created via `--worktree` or `isolation: "worktree"`. Replaces default git behavior |
| `WorktreeRemove` | Worktree being removed, at session exit or subagent finish |
| `PreCompact` | Before context compaction |
| `PostCompact` | After context compaction completes |
| `Elicitation` | MCP server requests user input during a tool call |
| `ElicitationResult` | After user responds to an MCP elicitation, before response sent back to server |
| `SessionEnd` | Session terminates |

**Hook types**: `command` (shell commands/scripts), `http` (POST event JSON to a URL), `mcp_tool` (call a tool on a configured MCP server), `prompt` (evaluate a prompt with an LLM, `$ARGUMENTS` placeholder), `agent` (agentic verifier with tools).

**Scoped tool names for plugin-bundled MCP**: hooks targeting the plugin's own bundled MCP server must use scoped names. Matcher/`if` fields take `mcp__plugin_<plugin-name>_<server-name>__<tool>`; an `mcp_tool` hook's `server` field takes `plugin:<plugin-name>:<server-name>`. A matcher written against the bare server key never fires.

### MCP servers

**Location**: `.mcp.json` in plugin root, or inline in `plugin.json`. **Format**: standard MCP server config.

```json
{
  "mcpServers": {
    "plugin-database": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": { "DB_PATH": "${CLAUDE_PLUGIN_ROOT}/data" }
    },
    "plugin-api-client": {
      "command": "npx",
      "args": ["@company/mcp-server", "--plugin-mode"],
      "cwd": "${CLAUDE_PLUGIN_ROOT}"
    }
  }
}
```

Plugin MCP servers start automatically when the plugin is enabled; appear as standard MCP tools; configured independently of user MCP servers.

### LSP servers

**Location**: `.lsp.json` in plugin root, or inline in `plugin.json`. **Format**: JSON mapping language server names to config.

```json .lsp.json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": { ".go": "go" }
  }
}
```

Inline equivalent: set `lspServers` key in `plugin.json` to the same object shape.

**Required fields**:

| Field | Description |
| :--- | :--- |
| `command` | The LSP binary to execute (must be in PATH) |
| `extensionToLanguage` | Maps file extensions to language identifiers |

**Optional fields**:

| Field | Description |
| :--- | :--- |
| `args` | Command-line arguments for the LSP server |
| `transport` | `stdio` (default) or `socket` |
| `env` | Environment variables to set when starting the server |
| `initializationOptions` | Options passed to the server during initialization |
| `settings` | Settings passed via `workspace/didChangeConfiguration` |
| `workspaceFolder` | Workspace folder path for the server |
| `startupTimeout` | Max time to wait for server startup (ms) |
| `shutdownTimeout` | Max time to wait for graceful shutdown (ms). On timeout, Claude Code terminates the process. Unset = no timeout |
| `restartOnCrash` | Restart after crash. Default `true`. `false` leaves a crashed server stopped |
| `maxRestarts` | Max restart attempts before giving up |
| `diagnostics` | Push diagnostics into context after edits (default `true`). `false` keeps navigation but suppresses automatic diagnostic injection |

`restartOnCrash` and `shutdownTimeout` require Claude Code v2.1.205 or later. Before v2.1.205, the schema accepted both but setting either caused Claude Code to skip that LSP server entirely at startup (reason visible only via `claude --debug`).

**Multiple servers, same extension**: when more than one enabled LSP server declares the same extension in `extensionToLanguage` (same plugin or different plugins), the first server registered handles those files; others never start. `/plugin` shows a warning naming the active plugin.

**Servers that fail to initialize**: Claude Code skips a server with invalid config (e.g. missing `command` or `extensionToLanguage`); other configured servers still start. `claude --debug` shows why a server was skipped. A skipped server doesn't claim its extensions, so another valid server for the same extension still works — before v2.1.205, a failed server still claimed its extensions and blocked another valid server for that extension.

Users must install the language server binary separately — plugins only configure the connection, not the server itself. `Executable not found in $PATH` in `/plugin` Errors tab means install the binary.

Official pre-built LSP plugins: `pyright-lsp` (Pyright/Python, `pip install pyright` or `npm install -g pyright`), `typescript-lsp` (TypeScript Language Server, `npm install -g typescript-language-server typescript`), `rust-analyzer-lsp` (rust-analyzer, see rust-analyzer docs). Install the language server first, then the plugin.

### Monitors

Background monitors Claude Code starts automatically when the plugin is active (no need to instruct Claude to start the watch). Each runs a shell command for the session lifetime; every stdout line is delivered to Claude as a notification.

Uses the same mechanism as the Monitor tool and shares its constraints: runs only in interactive CLI sessions, runs unsandboxed at the same trust level as hooks, skipped on hosts where the Monitor tool is unavailable.

Requires Claude Code v2.1.105 or later.

**Location**: `monitors/monitors.json` in plugin root, or inline in `plugin.json` under `experimental.monitors`. **Format**: JSON array.

```json monitors/monitors.json
[
  {
    "name": "deploy-status",
    "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/poll-deploy.sh ${user_config.api_endpoint}",
    "description": "Deployment status changes"
  },
  {
    "name": "error-log",
    "command": "tail -F ./logs/error.log",
    "description": "Application error log",
    "when": "on-skill-invoke:debug"
  }
]
```

To declare inline, set `experimental.monitors` to the array. To load from a non-default path, set it to a relative path string, e.g. `"./config/monitors.json"`. Monitors are an experimental component (see [Experimental components](#experimental-components)).

**Required fields**:

| Field | Description |
| :--- | :--- |
| `name` | Identifier unique within the plugin. Prevents duplicate processes on reload / repeat skill invocation |
| `command` | Shell command run as persistent background process in session working directory |
| `description` | Short summary of what is watched. Shown in task panel and notification summaries |

**Optional fields**:

| Field | Description |
| :--- | :--- |
| `when` | `"always"` (default): starts at session start and on plugin reload. `"on-skill-invoke:<skill-name>"`: starts the first time the named skill in this plugin is dispatched |

`command` supports the same variable substitutions as MCP/LSP configs: `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`, `${CLAUDE_PROJECT_DIR}`, `${user_config.*}`, and any `${ENV_VAR}`. Prefix with `cd "${CLAUDE_PLUGIN_ROOT}" &&` if the script must run from the plugin's own directory.

Disabling a plugin mid-session does not stop already-running monitors — they stop when the session ends.

### Themes

Plugins can ship color themes that appear in `/theme` alongside built-in presets and local themes. A theme is a JSON file in `themes/` with a `base` preset and a sparse `overrides` map of color tokens. Themes are an experimental component.

```json
{
  "name": "Dracula",
  "base": "dark",
  "overrides": {
    "claude": "#bd93f9",
    "error": "#ff5555",
    "success": "#50fa7b"
  }
}
```

Selecting a plugin theme persists `custom:<plugin-name>:<slug>` in the user's config. Plugin themes are read-only; pressing `Ctrl+E` on one in `/theme` copies it into `~/.claude/themes/` for editing.

## Plugin installation scopes

| Scope | Settings file | Use case |
| :--- | :--- | :--- |
| `user` | `~/.claude/settings.json` | Personal plugins available across all projects (default) |
| `project` | `.claude/settings.json` | Team plugins shared via version control |
| `local` | `.claude/settings.local.json` | Project-specific plugins, gitignored |
| `managed` | Managed settings | Managed plugins (read-only, update only) |

## Skills-directory plugins

Any folder under a skills directory containing a `.claude-plugin/plugin.json` manifest loads as a plugin named `<name>@skills-dir` on the next session — no marketplace, no install step. Scaffold with `plugin init`. Unlike a marketplace install, the plugin is discovered in place, not copied into the plugin cache.

| What you have | What it is |
| :--- | :--- |
| `<skills-dir>/foo/SKILL.md` with no manifest | A plain skill named `foo` |
| `<skills-dir>/foo/.claude-plugin/plugin.json` | A plugin `foo@skills-dir`, can bundle its own skills, agents, hooks, and more |
| `<plugin>/skills/bar/SKILL.md` | A skill `bar` packaged inside a plugin |

**Choose where the plugin loads from**:

| Skills directory | Scope | Loads |
| :--- | :--- | :--- |
| `~/.claude/skills/` | personal | In every project (location is yours alone) |
| `<cwd>/.claude/skills/` | project | Only after accepting the workspace trust dialog for that folder |

A project-scope plugin is checked into the repo and reaches every collaborator on clone. Because content comes from the repo rather than the user, it loads only after the same trust gate governing `.claude/settings.json`, and code-running components are restricted further:

- MCP servers go through the same per-server approval as a project `.mcp.json`
- LSP servers start only after the workspace is trusted
- Background monitors do not load

Personal-scope plugins have none of these restrictions.

**Gotcha**: project-scope `@skills-dir` plugins load only from `.claude/skills/` of the directory where Claude Code is started. They do **not** walk up to the repository root the way plain skills/commands do — launching from a subdirectory misses a plugin at the repo root. Launch from the repo root, or run `/reload-plugins` after changing directories.

**Edit/reload/disable**: changes to a skill's `SKILL.md` take effect immediately in the current session. Changes to other components (`hooks/`, `.mcp.json`, `agents/`, `output-styles/`) do not — run `/reload-plugins` or restart to pick those up. No `uninstall` step (nothing was installed from a marketplace) — delete the folder or disable by name: `claude plugin disable my-tool@skills-dir`.

## Plugin manifest schema

`.claude-plugin/plugin.json` defines metadata and configuration. The manifest is optional — if omitted, Claude Code auto-discovers components in default locations and derives the plugin name from the directory name.

### Complete schema

```json
{
  "name": "plugin-name",
  "displayName": "Plugin Name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "skills": "./custom/skills/",
  "commands": ["./custom/commands/special.md"],
  "agents": ["./custom/agents/reviewer.md"],
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "outputStyles": "./styles/",
  "lspServers": "./.lsp.json",
  "experimental": {
    "themes": "./themes/",
    "monitors": "./monitors.json"
  },
  "dependencies": [
    "helper-lib",
    { "name": "secrets-vault", "version": "~2.1.0" }
  ]
}
```

### Required fields

`name` is the only required field if a manifest is included.

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `name` | string | Unique identifier (kebab-case, no spaces). When a marketplace entry lists the plugin under a different name, the marketplace entry name is what `enabledPlugins` keys and `/plugin` use | `"deployment-tools"` |

Used for namespacing components: agent `agent-creator` in plugin `plugin-dev` appears as `plugin-dev:agent-creator`.

### Unrecognized fields

Claude Code ignores top-level fields it doesn't recognize — you can keep metadata from another ecosystem (VS Code/Cursor extension manifest, npm `package.json`, MCPB/DXT bundle manifest) in the same `plugin.json`, and the plugin still loads.

`claude plugin validate` reports unrecognized fields as **warnings**, not errors. If a field is one or two characters off a recognized name, the warning suggests the likely intended name. A plugin with only unrecognized-field warnings still passes validation and loads at runtime.

Fields with the wrong type still fail (e.g. `keywords` as a string instead of an array is a load error, reported by `claude plugin validate`).

`--strict` treats warnings as errors — use in CI to catch a misspelled field name or leftover field from another tool's manifest before publishing:

```bash
claude plugin validate ./my-plugin --strict
```

### Metadata fields

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `$schema` | string | JSON Schema URL for editor autocomplete/validation. Ignored at load time | `"https://json.schemastore.org/claude-code-plugin-manifest.json"` |
| `displayName` | string | Human-readable name shown in `/plugin` picker and other UI. Falls back to `name` when omitted. May contain spaces/any casing, unlike `name`. Not used for namespacing or lookup. Requires Claude Code v2.1.143 or later | `"Deployment Tools"` |
| `version` | string | Optional semantic version. Setting this pins the plugin so users only receive updates on bump. If omitted, falls back to git commit SHA (every commit = new version). If also set in the marketplace entry, `plugin.json` wins | `"2.1.0"` |
| `description` | string | Brief explanation of plugin purpose | `"Deployment automation tools"` |
| `author` | object | Author information | `{"name": "Dev Team", "email": "dev@company.com"}` |
| `homepage` | string | Documentation URL | `"https://docs.example.com"` |
| `repository` | string | Source code URL | `"https://github.com/user/plugin"` |
| `license` | string | License identifier | `"MIT"`, `"Apache-2.0"` |
| `keywords` | array | Discovery tags | `["deployment", "ci-cd"]` |
| `defaultEnabled` | boolean | Whether the plugin starts enabled when the user hasn't set a state. Default `true`. Requires Claude Code v2.1.154 or later | `false` |

**Default enablement**: set `defaultEnabled: false` to ship a plugin that installs disabled — user turns it on with `claude plugin enable <plugin>` or `/plugin`. Use for plugins adding cost/scope a user should opt into (e.g. connects to an external service). Earlier than v2.1.154, the field is ignored and the plugin enables on install.

`defaultEnabled` is the fallback when nothing else has decided state. Two things take precedence:

- **User's setting**: an entry for the plugin in `enabledPlugins` at any settings scope. Once written, persists across updates/reinstalls — changing `defaultEnabled` in a later release does not flip an existing user.
- **Dependency requirement**: when a plugin is required by another active plugin, Claude Code writes `true` for it at install/enable time, giving it an explicit setting so its own default no longer applies.

The same field can appear in a plugin's marketplace entry, where it takes precedence over the value in `plugin.json`.

### Component path fields

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `skills` | string\|array | Custom skill directories containing `<name>/SKILL.md`. Adds to the default `skills/` scan (see marketplace-root exception under Path behavior rules) | `"./custom/skills/"` |
| `commands` | string\|array | Custom flat `.md` skill files or directories (replaces default `commands/`) | `"./custom/cmd.md"` or `["./cmd1.md"]` |
| `agents` | string\|array | Custom agent files (replaces default `agents/`) | `"./custom/agents/reviewer.md"` |
| `hooks` | string\|array\|object | Hook config paths or inline config | `"./my-extra-hooks.json"` |
| `mcpServers` | string\|array\|object | MCP config paths or inline config | `"./my-extra-mcp-config.json"` |
| `outputStyles` | string\|array | Custom output style files/directories (replaces default `output-styles/`) | `"./styles/"` |
| `lspServers` | string\|array\|object | LSP configs for code intelligence | `"./.lsp.json"` |
| `experimental.themes` | string\|array | Color theme files/directories (replaces default `themes/`) | `"./themes/"` |
| `experimental.monitors` | string\|array | Background Monitor configs that start automatically when active | `"./monitors.json"` |
| `userConfig` | object | User-configurable values prompted at enable time | see below |
| `channels` | array | Channel declarations for message injection (Telegram, Slack, Discord style) | see below |
| `dependencies` | array | Other plugins this plugin requires, optionally with semver constraints | `[{ "name": "secrets-vault", "version": "~2.1.0" }]` |

### Experimental components

Components under the `experimental` key (`themes`, `monitors`) have a manifest schema that may change between releases while they stabilize. Where you declare them is a separate migration: top-level still works, `claude plugin validate` warns, and a future release will require `experimental.*`.

### User configuration

`userConfig` declares values Claude Code prompts the user for when the plugin is enabled — avoids requiring users to hand-edit `settings.json`.

```json
{
  "userConfig": {
    "api_endpoint": {
      "type": "string",
      "title": "API endpoint",
      "description": "Your team's API endpoint"
    },
    "api_token": {
      "type": "string",
      "title": "API token",
      "description": "API authentication token",
      "sensitive": true
    }
  }
}
```

Keys must be valid identifiers. Each option:

| Field | Required | Description |
| :--- | :--- | :--- |
| `type` | Yes | One of `string`, `number`, `boolean`, `directory`, `file` |
| `title` | Yes | Label shown in the configuration dialog |
| `description` | Yes | Help text shown beneath the field |
| `sensitive` | No | If `true`, masks input and stores value in secure storage instead of `settings.json` |
| `required` | No | If `true`, validation fails when the field is empty |
| `default` | No | Value used when the user provides nothing |
| `multiple` | No | For `string` type, allow an array of strings |
| `min` / `max` | No | Bounds for `number` type |

**Substitution surfaces**: each value available as `${user_config.KEY}` in MCP and LSP server configs, hook commands, and monitor commands. Non-sensitive values can also be substituted in skill and agent content. All values are exported to plugin subprocesses as `CLAUDE_PLUGIN_OPTION_<KEY>` environment variables.

**Storage**: non-sensitive values stored in `settings.json` under `pluginConfigs[<plugin-id>].options`. Sensitive values go to the system keychain (or `~/.claude/.credentials.json` where the keychain is unavailable). Keychain storage is shared with OAuth tokens and has an approximately 2 KB total limit — keep sensitive values small.

### Channels

`channels` lets a plugin declare one or more message channels that inject content into the conversation. Each channel binds to an MCP server the plugin provides.

```json
{
  "channels": [
    {
      "server": "telegram",
      "userConfig": {
        "bot_token": {
          "type": "string",
          "title": "Bot token",
          "description": "Telegram bot token",
          "sensitive": true
        },
        "owner_id": {
          "type": "string",
          "title": "Owner ID",
          "description": "Your Telegram user ID"
        }
      }
    }
  ]
}
```

`server` is required and must match a key in the plugin's `mcpServers`. Optional per-channel `userConfig` uses the same schema as the top-level field, letting the plugin prompt for bot tokens/owner IDs when enabled.

## Path behavior rules

Whether a custom path **replaces** or **adds to** the plugin's default directory depends on the field:

- **Replaces the default**: `commands`, `agents`, `outputStyles`, `experimental.themes`, `experimental.monitors`. E.g. when the manifest specifies `commands`, the default `commands/` directory is not scanned. To keep the default and add more, list it explicitly: `"commands": ["./commands/", "./extras/"]`.
- **Adds to the default**: `skills`. The default `skills/` directory is always scanned, and directories listed in `skills` load alongside it. **Exception**: for a marketplace entry whose `source` resolves to the marketplace root, declaring specific subdirectories replaces the default `skills/` scan.
- **Own merge rules**: hooks, MCP servers, LSP servers — see each component section above for how multiple sources combine.

When a plugin has both a default folder and the matching manifest key, Claude Code v2.1.140+ warns about the ignored folder in `claude plugin list` and the `/plugin` detail view — the plugin still loads using the manifest paths. No warning when the manifest key points into the default folder (e.g. `"commands": ["./commands/deploy.md"]`), since that path names the folder explicitly.

**For all path fields**:

- All paths must be relative to the plugin root and **start with `./`**.
- Components from custom paths use the same naming/namespacing rules.
- Multiple paths can be specified as arrays.
- **Invocation-name rule** (authoritative): when a skill path points to a directory containing `SKILL.md` directly (e.g. `"skills": ["./"]` pointing to plugin root, or the auto-loaded single-skill case below), the frontmatter `name` field in `SKILL.md` determines the invocation name — stable regardless of install directory. If `name` is unset, the directory basename is the fallback (for a marketplace-installed plugin, that basename is a cache version string that changes on every update).

A plugin with a `SKILL.md` at its root, no `skills/` subdirectory, and no `skills` manifest field is automatically loaded as a single-skill plugin in Claude Code v2.1.142+ — no need to set `"skills": ["./"]`; the same invocation-name rule above applies.

## Environment variables

Three variables for referencing paths. All are substituted inline anywhere they appear in skill content, agent content, hook commands, monitor commands, and MCP/LSP server configs. All are also exported as environment variables to hook processes and MCP/LSP server subprocesses.

| Variable | Meaning | Stability contract |
| :--- | :--- | :--- |
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the plugin's installation directory. Use for scripts, binaries, config bundled with the plugin | Changes when the plugin updates. Previous version's directory remains on disk ~7 days post-update before cleanup — treat as ephemeral, do not write state here. When a plugin updates mid-session, hook commands, monitors, MCP servers, and LSP servers keep using the previous version's path until `/reload-plugins` (switches hooks/MCP/LSP to new path) or, for monitors, a session restart |
| `${CLAUDE_PLUGIN_DATA}` | Persistent directory for plugin state that survives updates. Use for installed deps (`node_modules`, Python venvs), generated code, caches | Created automatically the first time this variable is referenced |
| `${CLAUDE_PROJECT_DIR}` | The project root — same directory hooks receive as `CLAUDE_PROJECT_DIR`. Use for project-local scripts/config | Wrap in quotes for paths with spaces, e.g. `"${CLAUDE_PROJECT_DIR}/scripts/server.sh"` |

In hook commands, use exec form with `args` so `${CLAUDE_PLUGIN_ROOT}` is passed as one argument with no quoting. In shell-form hooks and monitor commands, wrap it in double quotes: `"${CLAUDE_PLUGIN_ROOT}"`.

MCP servers can also call `roots/list` to read the session's working directories at runtime.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/process.sh" }
        ]
      }
    ]
  }
}
```

### Persistent data directory

`${CLAUDE_PLUGIN_DATA}` resolves to `~/.claude/plugins/data/{id}/`, where `{id}` is the plugin identifier with characters outside `a-z`, `A-Z`, `0-9`, `_`, `-` replaced by `-`. For a plugin installed as `formatter@my-marketplace`, the directory is `~/.claude/plugins/data/formatter-my-marketplace/`.

Because the data directory outlives any single plugin version, a directory-existence check alone cannot detect when an update changes the plugin's dependency manifest. **Recommended pattern**: compare the bundled manifest against a copy in the data directory and reinstall when they differ.

**Install-on-diff `SessionStart` hook pattern** — installs `node_modules` on first run and again whenever an update changes `package.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "diff -q \"${CLAUDE_PLUGIN_ROOT}/package.json\" \"${CLAUDE_PLUGIN_DATA}/package.json\" >/dev/null 2>&1 || (cd \"${CLAUDE_PLUGIN_DATA}\" && cp \"${CLAUDE_PLUGIN_ROOT}/package.json\" . && npm install) || rm -f \"${CLAUDE_PLUGIN_DATA}/package.json\""
          }
        ]
      }
    ]
  }
}
```

`diff` exits nonzero when the stored copy is missing or differs — covers both first run and dependency-changing updates. If `npm install` fails, the trailing `rm` removes the copied manifest so the next session retries.

Scripts bundled in `${CLAUDE_PLUGIN_ROOT}` can then run against the persisted `node_modules` — e.g. an MCP server entry with `"env": { "NODE_PATH": "${CLAUDE_PLUGIN_DATA}/node_modules" }`.

The data directory is deleted automatically when you uninstall the plugin from the last scope where it's installed. `/plugin` shows directory size and prompts before deleting. The CLI deletes by default; pass `--keep-data` to preserve it.

## Plugin caching and file resolution

Plugins are specified either via `claude --plugin-dir`/`--plugin-url` (session duration), or via a marketplace (installed for future sessions).

For security and verification, Claude Code copies **marketplace** plugins to the local plugin cache (`~/.claude/plugins/cache`) rather than using them in-place. Matters when developing plugins that reference external files.

Each installed version is a separate cache directory. On update/uninstall, the previous version directory is marked orphaned and auto-removed 7 days later — the grace period lets concurrent sessions on the old version keep running without errors. Glob and Grep skip orphaned version directories, so results don't include outdated plugin code.

**Path traversal limitations**: installed plugins cannot reference files outside their directory. Paths that traverse outside the plugin root (e.g. `../shared-utils`) don't work after installation — external files aren't copied to the cache.

**Symlink rules** (sharing files within a marketplace):

| Symlink target | Handling when copied into cache |
| :--- | :--- |
| Within the plugin's own directory | Preserved as a relative symlink in the cache — keeps resolving to the copied target at runtime |
| Elsewhere within the same marketplace | Dereferenced — target's content copied into the cache in its place. Lets a meta-plugin's `skills/` link to skills defined by other plugins in the marketplace |
| Outside the marketplace | Skipped for security — prevents plugins pulling arbitrary host files (e.g. system paths) into the cache |

For plugins installed with `--plugin-dir` or from a local path, only symlinks resolving within the plugin's own directory are preserved; all others are skipped.

```bash
# from inside a marketplace plugin, link to a shared skill in a sibling plugin
ln -s ../../shared-plugin/skills/foo ./skills/foo
```

On Windows, use `mklink /D` from an elevated Command Prompt or enable Developer Mode.

## Plugin directory structure

### Standard plugin layout

```text
enterprise-plugin/
├── .claude-plugin/           # Metadata directory (optional)
│   └── plugin.json             # plugin manifest
├── skills/                   # Skills
│   ├── code-reviewer/
│   │   └── SKILL.md
│   └── pdf-processor/
│       ├── SKILL.md
│       └── scripts/
├── commands/                 # Skills as flat .md files
│   ├── status.md
│   └── logs.md
├── agents/                   # Subagent definitions
│   ├── security-reviewer.md
│   ├── performance-tester.md
│   └── compliance-checker.md
├── output-styles/            # Output style definitions
│   └── terse.md
├── themes/                   # Color theme definitions
│   └── dracula.json
├── monitors/                 # Background monitor configurations
│   └── monitors.json
├── hooks/                    # Hook configurations
│   ├── hooks.json           # Main hook config
│   └── security-hooks.json  # Additional hooks
├── bin/                      # Plugin executables added to PATH
│   └── my-tool               # Invokable as bare command in Bash tool
├── settings.json            # Default settings for the plugin
├── .mcp.json                # MCP server definitions
├── .lsp.json                # LSP server configurations
├── scripts/                 # Hook and utility scripts
│   ├── security-scan.sh
│   ├── format-code.py
│   └── deploy.js
├── LICENSE                  # License file
└── CHANGELOG.md             # Version history
```

**Common mistake**: `.claude-plugin/` contains only `plugin.json`. All other directories (`commands/`, `agents/`, `skills/`, `output-styles/`, `themes/`, `monitors/`, `hooks/`) must be at the plugin root, not inside `.claude-plugin/`.

A `CLAUDE.md` at the plugin root is **not** loaded as project context. Plugins contribute context through skills, agents, and hooks rather than CLAUDE.md. To ship instructions that load into Claude's context, put them in a skill.

### File locations reference

| Component | Default Location | Purpose |
| :--- | :--- | :--- |
| Manifest | `.claude-plugin/plugin.json` | Plugin metadata and configuration (optional) |
| Skills | `skills/` | Skills with `<name>/SKILL.md` structure |
| Commands | `commands/` | Skills as flat Markdown files. Use `skills/` for new plugins |
| Agents | `agents/` | Subagent Markdown files |
| Output styles | `output-styles/` | Output style definitions |
| Themes | `themes/` | Color theme definitions |
| Hooks | `hooks/hooks.json` | Hook configuration |
| MCP servers | `.mcp.json` | MCP server definitions |
| LSP servers | `.lsp.json` | Language server configurations |
| Monitors | `monitors/monitors.json` | Background monitor configurations |
| Executables | `bin/` | Executables added to the Bash tool's `PATH`. Invokable as bare commands in any Bash tool call while the plugin is enabled |
| Settings | `settings.json` | Default configuration applied when the plugin is enabled. Only `agent` and `subagentStatusLine` keys currently supported |

## CLI commands reference

| Command | Purpose | Key options |
| :--- | :--- | :--- |
| `claude plugin init <name> [options]` | Scaffold a new plugin at `~/.claude/skills/<name>/`. Loads next session as `<name>@skills-dir`, appears in `/plugin` and `claude plugin list` — no install step. Alias: `new` | `--description <text>`; `--author <name>` (default: `git config user.name`); `--author-email <email>` (default: `git config user.email`); `--with <components...>` (valid: `skills`, `agents`, `hooks`, `mcp`, `lsp`, `output-style`, `channel`); `-f, --force` (overwrite existing `.claude-plugin/`) |
| `claude plugin install <plugin> [options]` | Install from available marketplaces. `<plugin>` = name or `plugin-name@marketplace-name` | `-s, --scope <user\|project\|local>` (default `user`) |
| `claude plugin uninstall <plugin> [options]` | Remove an installed plugin. Aliases: `remove`, `rm` | `-s, --scope`; `--keep-data` (preserve `${CLAUDE_PLUGIN_DATA}`); `--prune` (also remove orphaned auto-installed deps); `-y, --yes` (skip `--prune` confirm; required if stdin/stdout not a TTY) |
| `claude plugin prune [options]` | Remove auto-installed plugin dependencies no longer required by any installed plugin. Directly-installed plugins are never touched. Alias: `autoremove`. Requires v2.1.121+ | `-s, --scope`; `--dry-run`; `-y, --yes` |
| `claude plugin enable <plugin> [options]` | Enable a disabled plugin. If it declares dependencies, enables them transitively at the same scope; fails if a dependency isn't installed | `-s, --scope` |
| `claude plugin disable <plugin> [options]` | Disable without uninstalling. Fails when another enabled plugin depends on the target — error message includes a chained command to disable dependents first | `-s, --scope` |
| `claude plugin update <plugin> [options]` | Update to the latest version | `-s, --scope <user\|project\|local\|managed>` |
| `claude plugin list [options]` | List installed plugins with version, source marketplace, enable status. Interactive `/plugin list` prints the same inline; accepts `--enabled`/`--disabled`, and `ls` shorthand | `--json`; `--available` (include available plugins from marketplaces, requires `--json`) |
| `claude plugin details <name>` | Show component inventory and projected token cost. Lists Skills (includes `skills/` + `commands/`), Agents, Hooks, MCP servers, LSP servers, with token cost per component | none beyond `-h` |
| `claude plugin tag [options]` | Create a release git tag for the plugin in the current directory. Run from inside the plugin's folder | `--push`; `--dry-run`; `-f, --force` (dirty tree or existing tag) |

**`plugin init --with` component scaffolds**:

| Component | What it scaffolds |
| :--- | :--- |
| `skills` | An extra namespaced `<name>:example` skill alongside the default one |
| `agents` | An `agents/` subagent definition |
| `hooks` | A `hooks/hooks.json` with a sample event handler |
| `mcp` | A `.mcp.json` with HTTP and stdio server examples |
| `lsp` | A `.lsp.json` language-server example |
| `output-style` | An `output-styles/<name>.md` applied automatically while enabled |
| `channel` | An MCP-based channel: a stdio server (`server.ts`), its `.mcp.json`, and a `package.json` |

The scaffolded plugin uses the `@skills-dir` source rather than a marketplace. Admins can block this source with `strictKnownMarketplaces` or by adding `{"source": "skills-dir"}` to `blockedMarketplaces` in managed settings — when blocked, `plugin init` fails before writing.

**`plugin details` token-cost output**: two figures per component — **Always-on** (tokens added to every session by listing text: skill descriptions, agent descriptions, command names — regardless of whether the component fires) and **On-invoke** (tokens a component costs when it fires; shown per component, not as a plugin total, since a session typically invokes only a subset).

```text
dependency-guard 1.2.0
  Source: dependency-guard@example-marketplace

Component inventory
  Skills (2)  scan-dependencies, review-changes
  Hooks (1)  (harness-only — no model context cost)

Projected token cost
  Always-on:   ~180 tok   added to every session

Per-component (rounded)
  component            always-on  on-invoke
  scan-dependencies        ~100      ~2400
```

The always-on total is computed via the `count_tokens` API for the active model; per-component numbers are proportionally scaled from that total. If the API is unreachable, falls back to a character-based estimate.

## Debugging and common issues

`claude --debug` shows plugin loading details: which plugins are loading, manifest errors, skill/agent/hook registration, MCP server initialization.

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| Plugin not loading | Invalid `plugin.json` | `claude plugin validate` or `/plugin validate` to check `plugin.json`, skill/agent/command frontmatter, `hooks/hooks.json` for syntax/schema errors |
| Skills not appearing | Wrong directory structure | Ensure `skills/` or `commands/` is at plugin root, not inside `.claude-plugin/` |
| Hooks not firing | Script not executable | `chmod +x script.sh` |
| MCP server fails | Missing `${CLAUDE_PLUGIN_ROOT}` | Use the variable for all plugin paths |
| Path errors | Absolute paths used | All paths must be relative and start with `./` |
| LSP `Executable not found in $PATH` | Language server not installed | Install the binary (e.g. `npm install -g typescript-language-server typescript`) |

**Example error messages** (manifest validation): `Invalid JSON syntax: Unexpected token } in JSON at position 142` (missing/extra comma or unquoted string); `Plugin has an invalid manifest file at .claude-plugin/plugin.json. Validation errors: name: Required` (missing required field); `Plugin has a corrupt manifest file at .claude-plugin/plugin.json. JSON parse error: ...` (JSON syntax error).

**Example error messages** (plugin loading): `Warning: No commands found in plugin my-plugin custom directory: ./cmds. Expected .md files or SKILL.md in subdirectories.` (path exists but has no valid command files); `Plugin directory not found at path: ./plugins/my-plugin. Check that the marketplace entry has the correct path.` (`source` path in marketplace.json points to a non-existent directory); `Plugin my-plugin has conflicting manifests: both plugin.json and marketplace entry specify components.` (remove duplicate component definitions or remove `strict: false` in marketplace entry).

**Hook script not executing**: 1) `chmod +x ./scripts/your-script.sh`; 2) verify shebang (`#!/bin/bash` or `#!/usr/bin/env bash`); 3) confirm path uses `${CLAUDE_PLUGIN_ROOT}` — `"command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/your-script.sh"`; 4) test the script manually.

**Hook not triggering on expected events**: 1) event name is case-sensitive (`PostToolUse`, not `postToolUse`); 2) matcher pattern matches your tools (`"matcher": "Write|Edit"`); 3) hook type is valid: `command`, `http`, `mcp_tool`, `prompt`, or `agent`.

**MCP server not starting**: 1) command exists and is executable; 2) all paths use `${CLAUDE_PLUGIN_ROOT}`; 3) `claude --debug` shows initialization errors; 4) test the server manually outside Claude Code.

**MCP server tools not appearing**: 1) server properly configured in `.mcp.json` or `plugin.json`; 2) server implements MCP protocol correctly; 3) check for connection timeouts in debug output.

**Directory structure mistakes** — symptom: plugin loads but components (skills, agents, hooks) are missing. Correct structure: components at plugin root, not inside `.claude-plugin/` (only `plugin.json` belongs there).

```text
my-plugin/
├── .claude-plugin/
│   └── plugin.json      ← Only manifest here
├── commands/            ← At root level
├── agents/              ← At root level
└── hooks/               ← At root level
```

**Debug checklist**: 1) `claude --debug`, look for "loading plugin" messages; 2) check each component directory is listed in debug output; 3) verify file permissions allow reading plugin files.

## Version management

Claude Code uses the plugin's version as the cache key determining whether an update is available. On `/plugin update` or auto-update, Claude Code computes the current version and skips the update if it matches what's installed.

Version resolved from the first of these that is set:

1. `version` field in the plugin's `plugin.json`
2. `version` field in the plugin's marketplace entry in `marketplace.json`
3. Git commit SHA of the plugin's source, for `github`, `url`, `git-subdir`, and relative-path sources in a git-hosted marketplace
4. `unknown`, for `npm` sources or local directories not inside a git repository

| Approach | How | Update behavior | Best for |
| :--- | :--- | :--- | :--- |
| Explicit version | Set `"version": "2.1.0"` in `plugin.json` | Users get updates only when you bump this field. Pushing new commits without bumping has no effect; `/plugin update` reports "already at the latest version" | Published plugins with stable release cycles |
| Commit-SHA version | Omit `version` from both `plugin.json` and the marketplace entry | Users get updates on every new commit to the plugin's git source | Internal or team plugins under active development |

**Gotcha**: if you set `version` in `plugin.json`, you must bump it every time you want users to receive changes — pushing new commits alone is not enough, since Claude Code sees the same version string and keeps the cached copy. If iterating quickly, leave `version` unset so the git commit SHA is used instead.

If using explicit versions, follow semantic versioning (`MAJOR.MINOR.PATCH`): MAJOR for breaking changes, MINOR for new features, PATCH for bug fixes. Document changes in `CHANGELOG.md`.
