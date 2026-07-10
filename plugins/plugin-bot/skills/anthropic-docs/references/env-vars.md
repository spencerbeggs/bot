# Environment variables

> Verified against <https://code.claude.com/docs/en/env-vars.md> — 2026-07-10

**This file is a curated subset.** The source page catalogs ~290 environment variables covering auth, model routing, telemetry, UI, and more. This file distills only the subset relevant to plugin development: subprocess detection, the plugin system, skills/commands, subagents, Bash/tool behavior, MCP, and hooks/session lifecycle, plus the notable kill switches. For anything not covered here, fetch the stamped URL directly — do not assume absence means "doesn't exist."

## Contents

- [Setting env vars](#setting-env-vars)
- [Precedence](#precedence)
- [Subprocess detection](#subprocess-detection)
- [Plugin system](#plugin-system)
- [Skills and commands](#skills-and-commands)
- [Subagents](#subagents)
- [Bash and tool behavior](#bash-and-tool-behavior)
- [MCP](#mcp)
- [Hooks and session lifecycle](#hooks-and-session-lifecycle)
- [Kill switches](#kill-switches)

## Setting env vars

Two mechanisms:

- **Shell**: `export VAR=value` before launching `claude` (macOS/Linux/WSL), `$env:VAR = "value"` (PowerShell), or `set VAR=value` (CMD). Lasts for that terminal session unless added to a shell profile / persisted with `setx`.
- **Settings file, `env` key**: read directly from the file at startup regardless of how `claude` was launched.

```json
{
  "env": {
    "API_TIMEOUT_MS": "1200000",
    "BASH_DEFAULT_TIMEOUT_MS": "300000"
  }
}
```

| File | Applies to |
| :--- | :--- |
| `~/.claude/settings.json` | You, in every project |
| `.claude/settings.json` | Everyone in the project, checked into source control |
| `.claude/settings.local.json` | You, this project only (gitignore it) |
| Managed settings | Everyone in the org, admin-deployed |

## Precedence

- **Env var beats settings field** for the same behavior. Example: `ANTHROPIC_MODEL` overrides the `model` setting; `CLAUDE_CODE_AUTO_CONNECT_IDE` overrides `autoConnectIde`. The settings field applies only when the env var is unset.
- **Interaction with CLI flags / in-session commands varies per feature** — no blanket rule. Example: `--model` and `/model` override `ANTHROPIC_MODEL`, but `CLAUDE_CODE_EFFORT_LEVEL` overrides `/effort`. When a variable interacts with another config source, its meaning must be checked per-variable (see rows below); don't assume one direction.
- Env vars are read at startup — changes take effect on the next `claude` launch.

## Subprocess detection

| Variable | Purpose |
| :--- | :--- |
| `CLAUDECODE` | Set to `1` in every subprocess Claude Code spawns (Bash/PowerShell tools, tmux sessions, hook commands, status line commands, stdio MCP server subprocesses). IDE extensions also set this in integrated terminals — so it does not reliably distinguish a Claude-Code-launched subprocess from an IDE terminal. Use `CLAUDE_CODE_CHILD_SESSION` for that distinction. |
| `CLAUDE_CODE_CHILD_SESSION` | Set to `1` in subprocesses spawned via Bash, PowerShell, Monitor, hook commands, and status line commands. **Not** set for stdio MCP server subprocesses (long-lived, outlive the spawning session). Unlike `CLAUDECODE`, only Claude Code itself sets this — reliably distinguishes a nested session from a top-level `claude` in an IDE terminal. A nested interactive `claude` TUI is auto-excluded from `--resume`/`--continue`/history/`claude agents` list; non-interactive `claude -p` still persists. Override exclusion with `CLAUDE_CODE_FORCE_SESSION_PERSISTENCE=1`. Requires v2.1.172+. |
| `CLAUDE_CODE_SESSION_ID` | Auto-set to the current session ID in Bash/PowerShell tool subprocesses, hook command subprocesses, and stdio MCP server subprocesses. For Bash/PowerShell/hooks, matches the hook JSON `session_id` field and updates on `/clear`. An MCP server subprocess retains the ID it was spawned with. On `--resume <id>` receives the resumed ID; on `--continue`/bare `--resume` may receive the initial startup ID instead. Use to correlate external tooling with the launching session. |
| `CLAUDE_EFFORT` | Auto-set in Bash tool subprocesses and hook commands to the active effort level for the turn: `low`, `medium`, `high`, `xhigh`, or `max` (Ultracode reports as `xhigh`, not a distinct level). Matches the `effort.level` field passed to hooks. Only set when the current model supports the effort parameter. |
| `CLAUDE_ENV_FILE` | Path to a shell script Claude Code runs before each Bash command in the same shell process — exports become visible to the command. Use to persist virtualenv/conda activation across commands. Also populated dynamically by SessionStart, Setup, CwdChanged, and FileChanged hooks. |

## Plugin system

| Variable | Purpose |
| :--- | :--- |
| `CLAUDE_CODE_PLUGIN_CACHE_DIR` | Overrides the plugins **root** directory (despite the name, not the cache itself — marketplaces and the plugin cache live in subdirectories under this path). Default: `~/.claude/plugins`. |
| `CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS` | Timeout (ms) for git operations during plugin install/update. Default `120000`. Raise for large repos or slow networks. |
| `CLAUDE_CODE_PLUGIN_SEED_DIR` | Path(s) to read-only plugin seed directories, `:`-separated (Unix) or `;`-separated (Windows). Bundles a pre-populated plugins dir into a container image; Claude Code registers marketplaces from these dirs at startup and uses pre-cached plugins without re-cloning. |
| `CLAUDE_CODE_PLUGIN_PREFER_HTTPS` | Set to `1` to clone GitHub `owner/repo` shorthand sources over HTTPS instead of SSH. Applies to plugin install/update and `/plugin marketplace add`/`update`. Useful in CI/containers without a configured SSH key for `github.com`. |
| `FORCE_AUTOUPDATE_PLUGINS` | Set to `1` to force plugin auto-updates even when `DISABLE_AUTOUPDATER` disables the main auto-updater. |
| `CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL` | Set to `1` to skip automatic addition of the official plugin marketplace on first run. |
| `CLAUDE_CODE_SYNC_PLUGIN_INSTALL` | Set to `1` in non-interactive mode (`-p`) to wait for plugin installation before the first query. Without it, plugins install in the background and may be unavailable on the first turn. |
| `CLAUDE_CODE_SYNC_PLUGIN_INSTALL_TIMEOUT_MS` | Timeout (ms) for synchronous plugin installation (pairs with the var above). When exceeded, Claude Code proceeds without plugins and logs an error. No default — without this, sync install waits until complete. |

## Skills and commands

| Variable | Purpose |
| :--- | :--- |
| `CLAUDE_CODE_DISABLE_BUNDLED_SKILLS` | Set to `1` to disable skills/workflows shipped with Claude Code: removed entirely, though built-in commands like `/init` stay typable but hidden from the model (`/doctor` also stays typable — hide it separately with `DISABLE_DOCTOR_COMMAND`). Skills from plugins, `.claude/skills/`, and `.claude/commands/` are unaffected. Equivalent to the `disableBundledSkills` setting; `0` does not override that setting. |
| `SLASH_COMMAND_TOOL_CHAR_BUDGET` | Overrides the character budget for skill metadata shown to the `Skill` tool. Budget scales dynamically at 1% of the context window, fallback 8,000 chars. Legacy name kept for back-compat. |
| `CLAUDE_CODE_SYNC_SKILLS` | Set to `1` to download enabled claude.ai skills into `~/.claude/skills/` before the first query and resync every 10 minutes. Non-interactive mode (`-p`) only; requires claude.ai auth. Claude Code on the web receives enabled skills automatically — don't need this there. |
| `CLAUDE_CODE_SYNC_SKILLS_INSTALL_TIMEOUT_MS` | Timeout (ms) for a mid-session skills resync when `CLAUDE_CODE_SYNC_SKILLS` is set. Default `30000`. Bounds the download triggered by a host-requested skill reload; on timeout the resync stops and remaining downloads continue in the background. |
| `CLAUDE_CODE_SYNC_SKILLS_WAIT_TIMEOUT_MS` | Timeout (ms) for the first query to wait on the initial skills sync when `CLAUDE_CODE_SYNC_SKILLS` is set. Default `5000`. On timeout, the query proceeds and remaining downloads continue in the background. |

## Subagents

| Variable | Purpose |
| :--- | :--- |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Sets the model subagents use — see model-config doc for values. As of v2.1.196, setting `inherit` is the same as leaving it unset; before that, `inherit` forced every subagent onto the main conversation's model. |
| `CLAUDE_CODE_FORK_SUBAGENT` | Set to `1` to let Claude spawn forked subagents, `0` to disable, overriding any server-side rollout. When enabled, Claude can request the `fork` subagent type — a subagent that inherits the full conversation instead of starting fresh. Spawns without an explicit type still use the general-purpose subagent; all subagent spawns run in the background. The explicit `/fork` command works regardless of this var. Works interactively and via SDK/`claude -p`. |
| `CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS` | Set to `1` to disable all built-in subagent types (e.g. Explore, Plan). Only applies in non-interactive mode (`-p`). For SDK users wanting a blank slate. |
| `CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS` | Set to `1` to disable the built-in Explore and Plan subagents specifically. Claude explores with search tools or the general-purpose subagent instead; plan mode reads files directly instead of launching Explore/Plan. Custom subagents named `Explore`/`Plan` are unaffected. To remove every built-in type instead, use `CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS`. Requires v2.1.198+. |
| `CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS` | Stall timeout (ms) for background subagents. Default `600000` (10 min). Timer resets on each streaming progress event; if no progress arrives within the window, the subagent is aborted and the task marked failed, surfacing any partial result to the parent. |
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | Set to `1` to disable all background task functionality: the `run_in_background` param on Bash and subagent tools, auto-backgrounding, and the Ctrl+B shortcut. |

## Bash and tool behavior

| Variable | Purpose |
| :--- | :--- |
| `BASH_DEFAULT_TIMEOUT_MS` | Default timeout for long-running Bash commands. Default `120000` (2 min). |
| `BASH_MAX_TIMEOUT_MS` | Maximum timeout the model can request for a Bash command. Default `600000` (10 min). |
| `BASH_MAX_OUTPUT_LENGTH` | Max chars in Bash output before the full output is saved to a file and Claude gets the path plus a short preview. |
| `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR` | Returns to the original working directory after each Bash/PowerShell command in the main session — disables the normal cwd carry-over. |
| `CLAUDE_CODE_USE_POWERSHELL_TOOL` | Controls the PowerShell tool. Windows without Git Bash: enabled by default, `0` disables. Windows with Git Bash: rolling out, `1`/`0` opts in/out. Linux/macOS/WSL: `1` enables (requires `pwsh` on `PATH`). |
| `CLAUDE_CODE_GLOB_NO_IGNORE` | Set to `false` to make Glob respect `.gitignore` (default: Glob returns all matching files including gitignored ones). Does not affect `@` file autocomplete, which has its own `respectGitignore` setting. |
| `USE_BUILTIN_RIPGREP` | Set to `0` to use system-installed `rg` instead of the `rg` bundled with Claude Code. |

## MCP

| Variable | Purpose |
| :--- | :--- |
| `MCP_TIMEOUT` | Timeout (ms) for MCP server startup. Default `30000` (30s). |
| `MCP_TOOL_TIMEOUT` | Timeout (ms) for MCP tool execution. Default `100000000` (~28 hours). A per-server `timeout` in `.mcp.json` overrides for that server. As of v2.1.203, a per-server `timeout` ≥1000 also floors that server's tool-call idle window so `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT` never aborts sooner. Values below 1000 are floored to one second (env var) or ignored (per-server field). |
| `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT` | Idle timeout (ms) for MCP tool calls — aborts if a stdio/HTTP/SSE/WebSocket/claude.ai-connector server sends no response and no progress notification for this long, instead of waiting for `MCP_TOOL_TIMEOUT`. Overrides per-transport defaults: `300000` (5 min) network, `1800000` (30 min) stdio. `0` disables the idle check; values <1000 raised to 1s; capped at effective `MCP_TOOL_TIMEOUT`. A per-server `timeout` ≥1000 in `.mcp.json` raises that server's idle window to at least that value. Doesn't apply to IDE servers or SDK in-process servers. Requires v2.1.187+. Before v2.1.203, stdio servers were exempt from the idle timeout entirely. |
| `MAX_MCP_OUTPUT_TOKENS` | Max tokens allowed in MCP tool responses. Claude Code warns past 10,000 tokens. Tools declaring `anthropic/maxResultSizeChars` use that char limit for text content instead, but image content from those tools is still subject to this var. Default `25000`. |
| `ENABLE_TOOL_SEARCH` | Controls MCP tool search. Unset: all MCP tools deferred by default, except loaded upfront on Google Cloud's Agent Platform or when `ANTHROPIC_BASE_URL` points at a non-first-party host. `true`: always defer + send beta header (fails on Agent Platform models earlier than Sonnet 4.5/Opus 4.5, or proxies without `tool_reference` support). `auto`: threshold mode, loads upfront if tools fit within 10% of context. `auto:N`: custom threshold (e.g. `auto:5` = 5%). `false`: load all upfront. |
| `MCP_CONNECTION_NONBLOCKING` | Controls whether startup waits for MCP servers to connect before the first query. As of v2.1.142, MCP startup is non-blocking by default (servers connect in background, tools appear as they finish). `0` restores the blocking 5-second wait. Servers with `alwaysLoad: true` always block startup regardless. |
| `MCP_CONNECT_TIMEOUT_MS` | How long **blocking** MCP startup waits (ms) for the connection batch before snapshotting the tool list. Default `5000`. Applies when `MCP_CONNECTION_NONBLOCKING=0` or for `alwaysLoad: true` servers. Servers still pending at the deadline keep connecting in background but don't appear until the next query. Distinct from `MCP_TIMEOUT`, which bounds an individual server's connect attempt. |
| `ENABLE_CLAUDEAI_MCP_SERVERS` | Set to `false` to disable claude.ai MCP servers in Claude Code. Enabled by default for logged-in users. To disable per-project/per-org instead, use the `disableClaudeAiConnectors` setting. |
| `CLAUDE_CODE_MCP_ALLOWLIST_ENV` | Set to `1` to spawn stdio MCP servers with only a safe baseline environment plus the server's configured `env`, instead of inheriting your full shell environment. |

## Hooks and session lifecycle

| Variable | Purpose |
| :--- | :--- |
| `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` | Overrides the time budget (ms) for SessionEnd hooks. Applies on session exit, `/clear`, and switching sessions via interactive `/resume`. Default budget 1.5s, auto-raised to the highest per-hook `timeout` configured in settings files, up to 60s. Timeouts on plugin-provided hooks do not raise the budget. |
| `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` | Max consecutive times a Stop or SubagentStop hook may block the turn from ending before Claude Code overrides it and ends the turn anyway. Default `8`. `0` disables the cap — raise if a hook legitimately needs more iterations. |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | Sets the percentage (1–100) of the auto-compaction window at which auto-compaction triggers; lower values (e.g. `50`) compact earlier. Only causes earlier compaction when Claude Code compacts proactively: when `CLAUDE_CODE_AUTO_COMPACT_WINDOW` is set, in cloud sessions, and on Sonnet 4.6/Opus 4.6 without extended context (which compact at the 200K boundary by default). On Sonnet 5, proactive compaction uses the model's default threshold. Otherwise (e.g. local session on Opus 4.8), auto-compaction triggers at the model's context limit. Can only lower the threshold — values above default have no effect. Applies to main conversations and subagents. |
| `CLAUDE_CODE_DISABLE_CRON` | Set to `1` to disable scheduled tasks. The `/loop` skill and cron tools become unavailable; already-scheduled tasks stop firing, including ones already running mid-session. |

## Kill switches

| Variable | Purpose |
| :--- | :--- |
| `DISABLE_TELEMETRY` | Set to `1` to opt out of telemetry. Telemetry events don't include user data like code, file paths, or bash commands. Also disables feature-flag fetching (same effect as `DISABLE_GROWTHBOOK`) — some flagged features may become unavailable. |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Equivalent to setting `DISABLE_AUTOUPDATER`, `DISABLE_FEEDBACK_COMMAND`, `DISABLE_ERROR_REPORTING`, and `DISABLE_TELEMETRY` all at once. Also disables the Monitor tool (see tools.md). |
| `DISABLE_AUTOUPDATER` | Set to `1` to disable automatic background updates. Manual `claude update` still works — use `DISABLE_UPDATES` to block both. |
| `DISABLE_FEEDBACK_COMMAND` | Set to `1` to disable `/feedback`. Older name `DISABLE_BUG_COMMAND` also accepted. |
| `DISABLE_ERROR_REPORTING` | Set to `1` to opt out of Sentry error reporting. |
