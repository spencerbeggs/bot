# Connect Claude Code to tools via MCP

> Verified against <https://code.claude.com/docs/en/mcp.md> — 2026-07-10

## Contents

- [Transports](#transports)
- [.mcp.json entry shapes](#mcpjson-entry-shapes)
- [Environment variable expansion](#environment-variable-expansion)
- [Installation scopes and precedence](#installation-scopes-and-precedence)
- [Plugin-provided MCP servers](#plugin-provided-mcp-servers)
- [Reserved server names](#reserved-server-names)
- [Timeouts](#timeouts)
- [OAuth](#oauth)
- [Output limits](#output-limits)
- [_meta anthropic/requiresUserInteraction](#_meta-anthropicrequiresuserinteraction)
- [Root-level schema combinator flattening](#root-level-schema-combinator-flattening)
- [Tool search](#tool-search)
- [Dynamic tool updates and reconnection](#dynamic-tool-updates-and-reconnection)
- [Server management](#server-management)
- [Resources, prompts, elicitation](#resources-prompts-elicitation)
- [claude.ai connectors](#claudeai-connectors)
- [Channels (push messages)](#channels-push-messages)

## Transports

| Transport | Add command | Notes |
| :--- | :--- | :--- |
| `http` | `claude mcp add --transport http <name> <url>` | Recommended for remote servers. `type` also accepts `streamable-http` as an alias for `http` (MCP spec name) — configs copied from server docs work unmodified. |
| `sse` | `claude mcp add --transport sse <name> <url>` | **Deprecated.** Use `http` where available. |
| `stdio` | `claude mcp add [options] <name> -- <command> [args...]` | Local process. |
| `ws` | `claude mcp add-json <name> '{"type":"ws",...}'` | Persistent bidirectional connection; no `claude mcp add --transport ws` form exists. |

**url-without-type error**: a JSON entry with `url` but no `type` is read as a stdio server — a configuration error. Claude Code skips it and reports `MCP server "<name>" has a "url" but no "type"; add "type": "http" (or "sse" / "ws") to this entry`. Before v2.1.202 this was reported as `command: expected string, received undefined`.

**stdio `--` separator**: everything after `--` is passed to the server untouched, separating it from Claude's own flags (`--transport`, `--env`, `--scope`).

- `claude mcp add --transport stdio myserver -- npx server` → runs `npx server`
- `claude mcp add --env KEY=value --transport stdio myserver -- python server.py --port 8080` → runs `python server.py --port 8080` with `KEY=value` in env
- `--env` accepts multiple `KEY=value` pairs; place at least one other option between `--env` and the server name or the CLI reads the name as another pair.

**stdio `CLAUDE_PROJECT_DIR`**: Claude Code sets `CLAUDE_PROJECT_DIR` in the *spawned server's* environment (not Claude Code's own env) to the project root — same value hooks receive. Stable across `--add-dir` changes mid-session. Read via `process.env.CLAUDE_PROJECT_DIR` / `os.environ["CLAUDE_PROJECT_DIR"]`. Referencing it via `${VAR}` expansion in a project/user-scoped `.mcp.json` `command`/`args` needs a default: `${CLAUDE_PROJECT_DIR:-.}`. Plugin-provided MCP configs substitute `${CLAUDE_PROJECT_DIR}` directly, no default needed.

**stdio `roots/list`**: a server that limits its own filesystem access to allowed directories should implement the MCP `roots/list` request. Claude Code answers with the session's launch directory plus every additional working directory granted via `--add-dir`, `/add-dir`, or `additionalDirectories`. Sends `notifications/roots/list_changed` when that set changes. Before v2.1.203, `roots/list` returned only the launch directory and no `list_changed` notification was sent.

**ws header-only auth**: `type: "ws"` accepts the same `url`, `headers`, `headersHelper`, `timeout`, `alwaysLoad` fields as `http`. Authentication is header-only — static token in `headers` or generated per-connect via `headersHelper`.

## .mcp.json entry shapes

```json
{
  "mcpServers": {
    "stdio-example": { "command": "/path/to/server", "args": [], "env": {} },
    "http-example": { "type": "http", "url": "https://mcp.example.com/mcp", "headers": { "Authorization": "Bearer TOKEN" } },
    "ws-example": { "type": "ws", "url": "wss://mcp.example.com/socket", "headers": { "Authorization": "Bearer TOKEN" } }
  }
}
```

An entry with no `type` field is read as stdio.

## Environment variable expansion

Syntax: `${VAR}` expands to the env var value; `${VAR:-default}` uses `default` if `VAR` unset.

Expansion locations: `command`, `args`, `env`, `url` (http type), `headers`.

If a required variable isn't set and has no default, Claude Code fails to parse the config.

## Installation scopes and precedence

| Scope | Loads in | Shared with team | Stored in |
| :--- | :--- | :--- | :--- |
| Local (default) | Current project only | No | `~/.claude.json` (under project path) |
| Project | Current project only | Yes, via version control | `.mcp.json` in project root |
| User | All your projects | No | `~/.claude.json` |

Older versions called local scope `project` and user scope `global`. "Local scope" MCP servers (`~/.claude.json`) differ from general local settings (`.claude/settings.local.json`).

**Precedence** (same server defined in multiple places → highest-precedence definition used whole, fields not merged across scopes):

1. Local scope
2. Project scope
3. User scope
4. Plugin-provided servers
5. claude.ai connectors

The three scopes match duplicates **by name**. Plugins and claude.ai connectors match **by endpoint** — a plugin/connector pointing at the same URL or command as a higher-precedence server is treated as a duplicate.

**Project-scope approval**: Claude Code prompts for approval before using project-scoped `.mcp.json` servers. `claude mcp reset-project-choices` resets choices. Pending servers show as `⏸ Pending approval` in `claude mcp list`/`claude mcp get`; rejected as `✗ Rejected`.

As of v2.1.196, `claude mcp list`/`claude mcp get` read `.mcp.json` approvals only from settings files not checked into the repo, until the workspace-trust dialog is accepted. `enableAllProjectMcpServers`/`enabledMcpjsonServers` committed to project `.claude/settings.json` is **ignored** in an untrusted folder — server stays `⏸ Pending approval`.

Approvals from these sources still apply in an untrusted folder: user `~/.claude/settings.json`, managed settings, `--settings`, `.claude/settings.local.json` (if not git-tracked). A `disabledMcpjsonServers` entry in any settings file still rejects the server regardless of trust state.

## Plugin-provided MCP servers

Plugins bundle MCP servers that start automatically when the plugin is enabled, appearing alongside manually configured servers and managed through plugin install/enable — not `/mcp` commands.

**Declaration** — `.mcp.json` at plugin root:

```json
{
  "mcpServers": {
    "database-tools": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": { "DB_URL": "${DB_URL}" }
    }
  }
}
```

Or inline in `plugin.json`:

```json
{
  "name": "my-plugin",
  "mcpServers": {
    "plugin-api": { "command": "${CLAUDE_PLUGIN_ROOT}/servers/api-server", "args": ["--port", "8080"] }
  }
}
```

**Substitution variables**: `${CLAUDE_PLUGIN_ROOT}` for bundled plugin files, `${CLAUDE_PLUGIN_DATA}` for persistent state that survives plugin updates, `${CLAUDE_PROJECT_DIR}` for the stable project root. Plugin servers also get access to the same user environment variables as manually configured servers, and support stdio, SSE, HTTP, and WebSocket transports (support may vary by server).

**Lifecycle**: servers for enabled plugins connect automatically at session startup. Enabling/disabling a plugin mid-session requires `/reload-plugins` to connect/disconnect its MCP servers.

**Tool naming**: `mcp__plugin_<plugin-name>_<server-name>__<tool-name>`, where any character outside `A-Z`, `a-z`, `0-9`, `_`, `-` is replaced with `_`. Example — `query` tool on `database-tools` server in plugin `my-plugin`:

```text
mcp__plugin_my-plugin_database-tools__query
```

Use this full name in permission rules, a skill's `allowed-tools`, a subagent's `tools` field, or a hook matcher. **A hook matcher against the bare server key (`mcp__database-tools__.*`) never fires for a plugin-bundled server.**

**Scoped server name**: the server itself registers as `plugin:<plugin-name>:<server-name>`, e.g. `plugin:my-plugin:database-tools`. Use this where a configured server name is expected, such as an `mcp_tool` hook's `server` field.

## Reserved server names

`workspace`, `claude-in-chrome`, `computer-use`, `Claude Preview`, `Claude Browser` — all built-in. A user config defining one of these is skipped at load with a warning; `claude mcp add` rejects it with an error. `Claude Preview`/`Claude Browser` both name the desktop app's preview-pane server. Before v2.1.205, `Claude Browser` wasn't reserved, so a user server could register under that name.

## Timeouts

| Setting | Scope | Default | Notes |
| :--- | :--- | :--- | :--- |
| `MCP_TIMEOUT` env var | Server startup | — | e.g. `MCP_TIMEOUT=10000 claude` for 10s |
| `timeout` field in `.mcp.json` entry (ms) | Per-server tool call, hard wall clock | `MCP_TOOL_TIMEOUT` (~28h if unset) | Overrides `MCP_TOOL_TIMEOUT` for that server only. Progress notifications don't extend it. |
| `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT` env var (ms) | Idle timeout (no response/progress) | 5 min (HTTP/SSE/WS/claude.ai connector), 30 min (stdio) | `0` disables the check. |

- Per-server `timeout` values below 1000 are ignored, falling through to `MCP_TOOL_TIMEOUT`. Before v2.1.162, sub-1000 values were floored to one second instead.
- A per-server `timeout` of at least 1000 also floors the idle timeout — Claude Code never aborts that server's calls for idleness sooner than the per-server `timeout`. Requires v2.1.203+.
- HTTP/SSE per-request fetch first-byte budget has a 60-second minimum.
- Idle timeout requires v2.1.187+; applies to every server type **except** IDE servers and SDK in-process servers. Before v2.1.203, stdio servers were exempt.

## OAuth

- **401/403 flagging**: either status code flags a remote server as needing auth in `/mcp`. As of v2.1.195, a failed token refresh (rejected refresh token) shows an immediate notice pointing at `/mcp` with a Re-authenticate option. A `WWW-Authenticate` header pointing to an authorization server triggers the same auto-discovery as any remote server. As of v2.1.193, a startup notice lists servers needing auth.
- **Non-interactive mode**: no `/mcp` panel exists. As of v2.1.196, when a configured server needs auth during `claude -p`/Agent SDK with tool search enabled (default), Claude Code tells Claude the server's tools are unavailable until authorized, instead of behaving as if unconfigured. Sign in from an interactive session with `/mcp` or `claude mcp login <name>`.
- If `headers.Authorization` is configured and the server rejects it, Claude Code reports connection failure instead of falling back to OAuth.
- **`claude mcp login <name>`** (v2.1.186+): runs OAuth flow from the shell without opening `/mcp`. `claude mcp logout <name>` clears stored credentials. As of v2.1.191, when no local browser is available (SSH, headless Linux), it prints the authorization URL instead; paste the redirect URL back at the prompt (needs an interactive terminal — use `ssh -t`). `--no-browser` forces the URL prompt.
- **`--callback-port`**: fixes the OAuth callback port to match a pre-registered redirect URI `http://localhost:PORT/callback`. Usable alone (dynamic client registration) or with `--client-id`.
- **Pre-configured credentials**: `claude mcp add --transport http --client-id <id> --client-secret --callback-port <port> <name> <url>` (secret prompts with masked input), or `claude mcp add-json` with an `oauth` object (`{"clientId":..., "callbackPort":...}`) plus a separate `--client-secret` flag. `MCP_CLIENT_SECRET` env var skips the interactive prompt (CI). Client ID Metadata Document (CIMD) servers are discovered automatically as an alternative to Dynamic Client Registration. Secret is stored in the system keychain (macOS) or a credentials file. These flags apply only to HTTP and SSE — no effect on stdio.
- **`authServerMetadataUrl`** (`oauth` object field): bypasses the default discovery chain (RFC 9728 `/.well-known/oauth-protected-resource` → RFC 8414 `/.well-known/oauth-authorization-server`). Must use `https://`. Requires v2.1.64+. Its `scopes_supported` overrides the upstream server's advertised scopes.

```json
{
  "mcpServers": {
    "my-server": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "oauth": { "authServerMetadataUrl": "https://auth.example.com/.well-known/openid-configuration" }
    }
  }
}
```

- **`oauth.scopes`**: pins the requested scopes as a single space-separated string (RFC 6749 §3.3 format) — the supported way to restrict a server to an approved subset. Takes precedence over `authServerMetadataUrl` and `/.well-known` discovery.

```json
{ "mcpServers": { "slack": { "type": "http", "url": "https://mcp.slack.com/mcp", "oauth": { "scopes": "channels:read chat:write search:read" } } } }
```

  As of v2.1.196, when `oauth.scopes` is unset, Claude Code requests only the scope from the server's `WWW-Authenticate` header or protected resource metadata, sending no `scope` parameter if neither provides one — it no longer requests the full `scopes_supported` catalog from auto-discovered metadata (that caused `invalid_scope` rejections from IdPs advertising admin-only scopes). Metadata from a configured `authServerMetadataUrl` still supplies `scopes_supported` as requested scopes. If the auth server advertises `offline_access`, it's appended to pinned scopes automatically. A 403 `insufficient_scope` on a tool call triggers re-auth with the same pinned scopes — widen `oauth.scopes` to fix.

- **`headersHelper`** — dynamic headers for non-OAuth auth (Kerberos, short-lived tokens, internal SSO):

```json
{ "mcpServers": { "internal-api": { "type": "http", "url": "https://mcp.internal.example.com", "headersHelper": "/opt/bin/get-mcp-auth-headers.sh" } } }
```

  Contract: the command must write a JSON object of string key-value pairs to stdout; runs in a shell with a **10-second timeout**; dynamic headers override static `headers` with the same name; runs fresh on every connection (session start + reconnect) — **no caching**, the script owns token reuse. As of v2.1.193, a `401`/`403` tool-call response re-runs the helper, reconnects, and retries once; the server is marked needing auth in `/mcp` only if the retry also fails.

  Env vars set when executing the helper:

  | Variable | Value |
  | :--- | :--- |
  | `CLAUDE_CODE_MCP_SERVER_NAME` | the MCP server's name |
  | `CLAUDE_CODE_MCP_SERVER_URL` | the MCP server's URL |
  | `CLAUDE_PLUGIN_ROOT` | plugin root dir — set only when a plugin provides the server |

  **Plugin cwd rule**: for a plugin-provided server, the helper's working directory is set to the plugin root, so a relative `headersHelper` path resolves inside the plugin directory rather than the session's cwd. Requires v2.1.195+.

  `headersHelper` executes arbitrary shell commands. At project/local scope, it only runs after the workspace-trust dialog is accepted.

## Output limits

- Warning threshold: any MCP tool output over 10,000 tokens shows a warning.
- `MAX_MCP_OUTPUT_TOKENS` env var: default **25,000**. Applies to tools that don't declare their own limit. Tools that return image data are always subject to this limit regardless of any per-tool annotation.
- **`_meta["anthropic/maxResultSizeChars"]`** in a tool's `tools/list` entry: raises that tool's threshold for *text content* to the annotated value, up to a hard ceiling of **500,000 characters**, independent of `MAX_MCP_OUTPUT_TOKENS`. Without the annotation, results exceeding the default threshold are persisted to disk and replaced with a file reference.

```json
{ "name": "get_schema", "description": "Returns the full database schema", "_meta": { "anthropic/maxResultSizeChars": 200000 } }
```

## _meta anthropic/requiresUserInteraction

Set `_meta["anthropic/requiresUserInteraction"]: true` (must be the JSON boolean `true`; any other value ignored) in a tool's `tools/list` entry to force a permission prompt on every call:

```json
{ "name": "grant_access", "description": "Requests access to a protected resource", "_meta": { "anthropic/requiresUserInteraction": true } }
```

- Prompts even in `acceptEdits`, `auto`, and `bypassPermissions` modes; no "don't ask again" option; allow rules don't skip it.
- `dontAsk` mode (never prompts) **denies** the call instead.
- Non-interactive `--permission-prompt-tool`: an `allow` result is converted to deny with `MCP tool requires user interaction; not supported via --permission-prompt-tool`. The Agent SDK's `canUseTool` callback does receive these calls (SDK host expected to surface them to a user).
- Requires v2.1.199+; earlier versions apply standard permission flow.
- On Remote Control or an SDK host, the request is marked as requiring user interaction, so the client shows the prompt instead of a one-tap approve.

## Root-level schema combinator flattening

The Claude API rejects `anyOf`/`oneOf`/`allOf` at a tool's schema **root** (nested inside `properties` is fine and passed unchanged).

As of v2.1.195, Claude Code flattens a root-level combinator into a single object and prepends a sentence to the tool description naming which parameter groups belong together:

- `allOf`: properties from every branch merged; each branch's `required` list still enforced.
- `anyOf`/`oneOf`: properties from every branch merged; each branch's `required` list is described in the tool description instead of schema-enforced. Servers must still validate the combination server-side.

If Claude Code can't produce an API-accepted schema, or the deployment lacks the remote config enabling the rewrite (e.g. offline), it skips that one tool, logs the reason, and leaves the server's other tools available. Before v2.1.195, every tool with a root-level combinator was skipped.

## Tool search

Enabled by default: MCP tool schemas are deferred (only names + server instructions load at session start) and discovered via search when needed.

| `ENABLE_TOOL_SEARCH` value | Behavior |
| :--- | :--- |
| (unset) | All deferred; falls back to upfront loading on Google Cloud's Agent Platform or when `ANTHROPIC_BASE_URL` is non-first-party |
| `true` | All deferred; sends beta header even on GCP Agent Platform/proxies — fails on GCP models earlier than Sonnet 4.5/Opus 4.5, or proxies without `tool_reference` support |
| `auto` | Threshold mode: loads upfront if schemas fit within 10% of the context window, else deferred |
| `auto:N` | Threshold mode with custom percentage `N` (0-100), e.g. `auto:5` |
| `false` | All loaded upfront, no deferral |

Requires a model supporting `tool_reference` blocks; Haiku models don't support it. On GCP Agent Platform, supported for Sonnet 4.5+/Opus 4.5+. Disabled by default on GCP Agent Platform and when `ANTHROPIC_BASE_URL` is non-first-party (most proxies don't forward `tool_reference` blocks) — set `ENABLE_TOOL_SEARCH` explicitly to override. The `ToolSearch` tool itself can be disabled via `permissions.deny: ["ToolSearch"]`.

**`alwaysLoad` server field** — exempts a server's tools from deferral entirely:

```json
{ "mcpServers": { "core-tools": { "type": "http", "url": "https://mcp.example.com/mcp", "alwaysLoad": true } } }
```

Available on all server types; requires v2.1.121+. An individual tool can set `_meta["anthropic/alwaysLoad"]: true` for the same effect on just that tool. Setting `alwaysLoad: true` also **blocks startup** until the server connects, capped at the standard 5-second connect timeout — other servers continue connecting in the background.

**Server instructions matter for discovery**: with tool search on, the server's `instructions` field helps Claude decide when to search for its tools — explain the task category, when to search, and key capabilities, similar to a skill description.

**2KB truncation**: tool descriptions and server instructions are truncated at 2KB each — keep critical details near the start.

If a request needs tools from a server still connecting, Claude waits: inside the `ToolSearch` call when tool search is enabled (default), or via the `WaitForMcpServers` tool when it isn't (e.g. `ENABLE_TOOL_SEARCH=false`, GCP Agent Platform, custom `ANTHROPIC_BASE_URL`).

## Dynamic tool updates and reconnection

- **`list_changed`**: MCP servers can dynamically update tools/prompts/resources via `list_changed` notifications; Claude Code auto-refreshes without requiring disconnect/reconnect.
- **Reconnection**: an HTTP or SSE server that disconnects mid-session auto-reconnects with exponential backoff — up to 5 attempts, starting at 1s and doubling each time. Shows as pending in `/mcp` during reconnection; after 5 failed attempts it's marked failed (retry manually from `/mcp`). Stdio servers are local processes and are **not** auto-reconnected.
- Same backoff applies to initial connection failure at startup. As of v2.1.121, transient errors (5xx, connection refused, timeout) retry up to 3 times before marking failed; auth and not-found errors are not retried.
- As of v2.1.191, post-connection capability discovery (`tools/list`, `prompts/list`, `resources/list`) also retries transient network/server errors up to 3 times with short backoff. Auth errors, 4xx responses, and request timeouts are not retried.
- A failed server: Claude Code tells Claude which server failed and its connection error, including inside `ToolSearch` results that find no matching tool — requires tool search (default enabled). Without tool search (custom `ANTHROPIC_BASE_URL`, `ENABLE_TOOL_SEARCH=false`, Haiku model, Amazon Bedrock, GCP Agent Platform, Microsoft Foundry), Claude Code doesn't report failed connections and Claude may respond as if the server were never configured. Before v2.1.205, connection errors were never passed to Claude.

## Server management

```bash
claude mcp list                  # list all configured servers
claude mcp get <name>            # details for a specific server
claude mcp remove <name>         # remove a server
claude mcp add-json <name> '<json>'
claude mcp add-from-claude-desktop  # import from Claude Desktop (macOS, WSL only)
/mcp                             # within Claude Code: check server status, tool counts, auth
```

`/mcp` shows the tool count per connected server and flags servers that advertise the tools capability but expose no tools. `-s`/`--scope` selects `local`/`project`/`user`; `-e`/`--env` sets `KEY=value` pairs; `--transport`/`--header` have `-t`/`-H` short forms.

**Claude Desktop import**: server names via `claude mcp` commands may contain only letters, numbers, hyphens, underscores. A Claude Desktop server name with any other character (e.g. a space) can't be imported — the import reports and skips it, still importing the rest. Before v2.1.205, the first invalid name stopped the whole import. Name collisions get a numeric suffix (`server_1`).

**Claude Code as an MCP server**: `claude mcp serve` starts Claude as a stdio MCP server exposing its own tools (View, Edit, LS, etc.) to another MCP client — that client is responsible for its own tool-call confirmation UI.

## Resources, prompts, elicitation

- **Resources**: `@server:protocol://resource/path` references an MCP resource inline, e.g. `@github:issue://123`. Auto-fetched and included as attachments; fuzzy-searchable in `@` autocomplete.
- **Prompts as commands**: MCP prompts appear as `/mcp__servername__promptname`; arguments passed space-separated after the command. Server/prompt names are normalized (spaces → underscores).
- **Elicitation**: a server can request structured input mid-task (form mode with defined fields, or URL mode opening a browser flow). No client-side config needed — dialogs appear automatically. To auto-respond without a dialog, use the `Elicitation` hook.

## claude.ai connectors

Servers added at `claude.ai/customize/connectors` (Team/Enterprise: admin-only) appear automatically in `/mcp` when the active authentication method is the claude.ai subscription — **not** loaded when `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `apiKeyHelper`, or a third-party provider (Bedrock, GCP Agent Platform) is active, even after a prior `/login`.

From v2.1.161, never-signed-in connectors collapse behind a "Show unused connectors" row. A locally configured server takes precedence over a same-endpoint claude.ai connector (per [precedence](#installation-scopes-and-precedence)); `/mcp` lists the connector as hidden.

Some Anthropic-hosted connectors (Microsoft 365, Gmail, Google Calendar) don't support local OAuth — from v2.1.162, `/mcp` directs you to Settings → Connectors on claude.ai instead.

**Disable**: set `disableClaudeAiConnectors: true` in any settings scope (any-source-true semantics — a project-level `false` can't re-enable connectors a user/policy-level `true` disabled), or set `ENABLE_CLAUDEAI_MCP_SERVERS=false` for the shell session. Servers passed via `--mcp-config` are unaffected. Individual connectors: add to `deniedMcpServers` by name or URL pattern. These client-side settings don't apply in Claude Code on the web — connectors there are provisioned by the remote host as explicit `--mcp-config` entries, and `deniedMcpServers` URL patterns won't match rewritten connector URLs.

## Channels (push messages)

An MCP server can push messages into a session (CI results, monitoring alerts, chat messages) by declaring the `claude/channel` capability; opt in at startup with the `--channels` flag. See `channels.md` for the full server contract (notification format, reply tools, sender gating, permission relay).
