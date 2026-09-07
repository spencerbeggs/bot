# Hooks reference — system contract

> Verified against <https://code.claude.com/docs/en/hooks.md> — 2026-07-10
> Companion file: hook-events.md covers per-event input/output schemas and decision-control fields for every event. This file covers the shared contract — locations, matcher rules, handler types, exit codes, JSON output, and cross-cutting mechanics (async, `CLAUDE_ENV_FILE`, prompt/agent hooks, debugging).

## Contents

- [Event table and cadence](#event-table-and-cadence)
- [Hook locations](#hook-locations)
- [Matcher evaluation rules](#matcher-evaluation-rules)
- [Per-event matcher fields](#per-event-matcher-fields)
- [Match MCP tools](#match-mcp-tools)
- [Hook handler types](#hook-handler-types)
- [Common handler fields](#common-handler-fields)
- [Command hook fields](#command-hook-fields)
- [HTTP hook fields](#http-hook-fields)
- [MCP tool hook fields](#mcp-tool-hook-fields)
- [Path placeholders](#path-placeholders)
- [Hooks in skills and agents](#hooks-in-skills-and-agents)
- [Disable hooks](#disable-hooks)
- [Exit-code contract](#exit-code-contract)
- [HTTP response handling](#http-response-handling)
- [JSON output — universal fields](#json-output--universal-fields)
- [additionalContext delivery](#additionalcontext-delivery)
- [Decision-control summary](#decision-control-summary)
- [Rewrite capabilities](#rewrite-capabilities)
- [Prompt-based hooks](#prompt-based-hooks)
- [Agent-based hooks](#agent-based-hooks)
- [Async hooks](#async-hooks)
- [CLAUDE_ENV_FILE](#claude_env_file)
- [Windows PowerShell](#windows-powershell)
- [Security considerations](#security-considerations)
- [Debug hooks](#debug-hooks)

## Event table and cadence

Three cadence buckets are named explicitly by the source:

- **once per session**: `SessionStart`, `SessionEnd`
- **once per turn**: `UserPromptSubmit`, `Stop`, `StopFailure`
- **every tool call in the agentic loop**: `PreToolUse`, `PostToolUse`

All events, with when each fires:

| Event | When it fires |
| :--- | :--- |
| `SessionStart` | When a session begins or resumes |
| `Setup` | When you start Claude Code with `--init-only`, or with `--init` or `--maintenance` in `-p` mode. For one-time preparation in CI or scripts |
| `UserPromptSubmit` | When you submit a prompt, before Claude processes it |
| `UserPromptExpansion` | When a user-typed command expands into a prompt, before it reaches Claude. Can block the expansion |
| `PreToolUse` | Before a tool call executes. Can block it |
| `PermissionRequest` | When a permission dialog appears |
| `PermissionDenied` | When a tool call is denied by the auto mode classifier. Return `{retry: true}` to tell the model it may retry the denied tool call |
| `PostToolUse` | After a tool call succeeds |
| `PostToolUseFailure` | After a tool call fails |
| `PostToolBatch` | After a full batch of parallel tool calls resolves, before the next model call |
| `Notification` | When Claude Code sends a notification |
| `MessageDisplay` | While assistant message text is displayed |
| `SubagentStart` | When a subagent is spawned |
| `SubagentStop` | When a subagent finishes |
| `TaskCreated` | When a task is being created via `TaskCreate` |
| `TaskCompleted` | When a task is being marked as completed |
| `Stop` | When Claude finishes responding |
| `StopFailure` | When the turn ends due to an API error. Output and exit code are ignored |
| `TeammateIdle` | When an agent team teammate is about to go idle |
| `InstructionsLoaded` | When a CLAUDE.md or `.claude/rules/*.md` file is loaded into context. Fires at session start and when files are lazily loaded during a session |
| `ConfigChange` | When a configuration file changes during a session |
| `CwdChanged` | When the working directory changes, e.g. when Claude executes a `cd` command. Useful for reactive environment management with tools like direnv |
| `FileChanged` | When a watched file changes on disk. The `matcher` field specifies which filenames to watch |
| `WorktreeCreate` | When a worktree is being created via `--worktree` or `isolation: "worktree"`. Replaces default git behavior |
| `WorktreeRemove` | When a worktree is being removed, either at session exit or when a subagent finishes |
| `PreCompact` | Before context compaction |
| `PostCompact` | After context compaction completes |
| `Elicitation` | When an MCP server requests user input during a tool call |
| `ElicitationResult` | After a user responds to an MCP elicitation, before the response is sent back to the server |
| `SessionEnd` | When a session terminates |

## Hook locations

| Location | Scope | Shareable |
| :--- | :--- | :--- |
| `~/.claude/settings.json` | All your projects | No, local to your machine |
| `.claude/settings.json` | Single project | Yes, can be committed to the repo |
| `.claude/settings.local.json` | Single project | No, gitignored when Claude Code creates it |
| Managed policy settings | Organization-wide | Yes, admin-controlled |
| Plugin `hooks/hooks.json` | When plugin is enabled | Yes, bundled with the plugin |
| Skill or agent frontmatter | While the component is active | Yes, defined in the component file |

`allowManagedHooksOnly` (enterprise) blocks user, project, and plugin hooks. Hooks from plugins force-enabled in managed settings `enabledPlugins` are exempt — lets admins distribute vetted hooks through an org marketplace.

`disableAllHooks: true` in a settings file disables all hooks without removing them; no way to disable an individual hook while keeping it configured. Respects the managed hierarchy: `disableAllHooks` in user/project/local settings can't disable managed-policy hooks — only the managed level can do that. Direct edits to hooks in settings files are picked up automatically by the file watcher.

`/hooks` opens a read-only browser of configured hooks, labeled `[type]` with a source: `User`, `Project`, `Local`, `Plugin`, `Session` (registered in memory for the session), `Built-in` (registered internally).

## Matcher evaluation rules

| Matcher value | Evaluated as | Example |
| :--- | :--- | :--- |
| `"*"`, `""`, or omitted | Match all | fires on every occurrence of the event |
| Only letters, digits, `_`, `-`, spaces, `,`, and `\|` | Exact string, or list of exact strings separated by `\|` or `,` with optional surrounding whitespace | `Bash` matches only Bash; `Edit\|Write` and `Edit, Write` each match either tool exactly; `code-reviewer` matches only that agent type |
| Contains any other character | JavaScript regular expression, unanchored, tested with `RegExp.prototype.test` | `^Notebook` matches any tool name starting with `Notebook`; `mcp__memory__.*` matches every tool from the `memory` server |

`Edit.*` matches both `Edit` and `NotebookEdit` (unanchored) — wrap in `^...$` for whole-string match.

**Version gates (load-bearing):**

- Comma separators and surrounding-whitespace tolerance require Claude Code v2.1.191 or later.
- Hyphens in the exact-match charset require Claude Code v2.1.195 or later. On earlier versions a hyphenated name like `code-reviewer` is evaluated as an unanchored regex, so it also fires for `senior-code-reviewer`; anchor as `^code-reviewer$` on those versions to match only that name.

**Narrower charset for two events:** `FileChanged` and `StopFailure` use exact-match charset letters, digits, `_`, and `|` only. A hyphen, space, or comma in a matcher for those two events keeps it on the regex path, and only `|` (not `,`) separates alternatives. Every other event with matcher support accepts `|` or `,`. `FileChanged` additionally doesn't follow these rules when building its watch list — see hook-events.md § FileChanged.

## Per-event matcher fields

| Event | What the matcher filters | Example matcher values |
| :--- | :--- | :--- |
| `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied` | tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| `SessionStart` | how the session started | `startup`, `resume`, `clear`, `compact` |
| `Setup` | which CLI flag triggered setup | `init`, `maintenance` |
| `SessionEnd` | why the session ended | `clear`, `resume`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other` |
| `Notification` | notification type | `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`, `elicitation_complete`, `elicitation_response`, `agent_needs_input`, `agent_completed` |
| `SubagentStart` | agent type | `general-purpose`, `Explore`, `Plan`, custom agent names, plugin-scoped names like `^my-plugin:reviewer$` |
| `PreCompact`, `PostCompact` | what triggered compaction | `manual`, `auto` |
| `SubagentStop` | agent type | same values as `SubagentStart` |
| `ConfigChange` | configuration source | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` |
| `CwdChanged` | no matcher support | always fires on every directory change |
| `FileChanged` | literal filenames to watch | `.envrc\|.env` |
| `StopFailure` | error type | `rate_limit`, `overloaded`, `authentication_failed`, `oauth_org_not_allowed`, `billing_error`, `invalid_request`, `model_not_found`, `server_error`, `max_output_tokens`, `unknown` |
| `InstructionsLoaded` | load reason | `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact` |
| `UserPromptExpansion` | command name | your skill or command names |
| `Elicitation` | MCP server name | your configured MCP server names |
| `ElicitationResult` | MCP server name | same values as `Elicitation` |
| `UserPromptSubmit`, `PostToolBatch`, `Stop`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`, `MessageDisplay` | no matcher support | always fires on every occurrence |

The matcher runs against a field from the JSON input (for tool events: `tool_name`). A `matcher` added to one of the no-matcher-support events above is silently ignored.

For tool events, filter more narrowly with the `if` field on individual hook handlers — see [Common handler fields](#common-handler-fields).

## Match MCP tools

MCP tools appear as regular tools in tool events (`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`) and follow the naming pattern `mcp__<server>__<tool>`, e.g. `mcp__memory__create_entities`, `mcp__filesystem__read_file`.

To match every tool from a server, append `.*` — required, since a matcher like `mcp__memory` contains only exact-match characters and is compared as an exact string (matching no tool):

- `mcp__memory__.*` matches all tools from the `memory` server
- `mcp__brave-search__.*` matches all tools from a server whose name contains a hyphen
- `mcp__.*__write.*` matches any tool whose name starts with `write` from any server

Hyphens in the exact-match set require Claude Code v2.1.195 or later. On earlier versions a bare hyphenated prefix like `mcp__brave-search` is evaluated as an unanchored regex and matches every tool from that server; `mcp__brave-search__.*` works on every version.

**Plugin-scoped servers and the bare-server-key gotcha:** tools from a plugin-bundled MCP server use a scoped segment that includes the plugin name: `mcp__plugin_<plugin-name>_<server-name>__<tool>`. **A matcher written against the bare server key never fires for these tools.** For plugin `my-plugin` bundling server key `db`, tool `query` appears as `mcp__plugin_my-plugin_db__query`; the matcher for every tool from that server is `mcp__plugin_my-plugin_db__.*`. Use the same scoped tool name in a handler's `if` field.

## Hook handler types

Five handler types per matched group:

| Type | Behavior |
| :--- | :--- |
| `command` | Runs a shell command. Script receives JSON input on stdin; communicates via exit codes and stdout |
| `http` | Sends JSON input as an HTTP POST body. Endpoint communicates via response body using the same JSON output format as command hooks |
| `mcp_tool` | Calls a tool on an already-connected MCP server. Tool's text output treated like command-hook stdout |
| `prompt` | Sends a prompt to a Claude model (Haiku by default) for single-turn evaluation; model returns a yes/no JSON decision |
| `agent` | Spawns a subagent with tool access (Read, Grep, Glob) to verify conditions before returning a decision. Experimental |

All matching hooks run in parallel. Identical handlers are deduplicated: command hooks by command string + `args`, HTTP hooks by URL.

Handlers run in the current directory with Claude Code's environment. `$CLAUDE_CODE_REMOTE` is `"true"` in remote web environments, unset locally. As of v2.1.199, `$CLAUDE_CODE_BRIDGE_SESSION_ID` is set to the Remote Control session ID while the local session has an active Remote Control connection.

## Common handler fields

Apply to all hook types:

| Field | Required | Description |
| :--- | :--- | :--- |
| `type` | yes | `"command"`, `"http"`, `"mcp_tool"`, `"prompt"`, or `"agent"` |
| `if` | no | Permission rule syntax filtering when this hook runs, e.g. `"Bash(git *)"` or `"Edit(*.ts)"`. Only evaluated on tool events: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`. On other events, a hook with `if` set never runs |
| `timeout` | no | Seconds before canceling. Defaults: 600 for `command`/`http`/`mcp_tool`; 30 for `prompt`; 60 for `agent`. `UserPromptSubmit` lowers the `command`/`http`/`mcp_tool` default to 30; `MessageDisplay` lowers it to 10 |
| `statusMessage` | no | Custom spinner message while the hook runs |
| `once` | no | If `true`, runs once per session then is removed. Only honored for hooks declared in skill frontmatter; ignored in settings files and agent frontmatter |

`if` holds exactly one permission rule — no `&&`, `\|\|`, or list syntax. Define a separate hook handler per condition.

**Bash `if` matching** (leading `VAR=value` assignments are stripped before matching):

| `if` pattern | Bash command | Hook runs? | Why |
| :--- | :--- | :--- | :--- |
| `Bash(git *)` | `FOO=bar git push` | yes | leading assignments stripped; `git push` matches |
| `Bash(git *)` | `npm test && git push` | yes | each subcommand checked; `git push` matches |
| `Bash(rm *)` | `echo $(rm -rf /)` | yes | commands inside `$()`/backticks are checked; `rm -rf /` matches |
| `Bash(rm *)` | `echo $(date)` | no | no subcommand matches `rm *` |
| `Bash(git push *)` | `echo $(date)` | yes | patterns specifying more than the command name run the hook anyway on `$()`, backticks, or `$VAR` |

The filter **fails open** — runs the hook regardless of pattern — when the Bash command can't be parsed. Because `if` is best-effort, use the permission system rather than a hook for a hard allow/deny.

## Command hook fields

| Field | Required | Description |
| :--- | :--- | :--- |
| `command` | yes | Shell command to execute. With `args`, the executable to spawn directly |
| `args` | no | Argument list. When present, `command` resolves as an executable spawned directly with `args` as argv, no shell involved |
| `async` | no | If `true`, runs in background without blocking. `type: "command"` only |
| `asyncRewake` | no | If `true`, runs in background and wakes Claude on exit code 2. Implies `async`. Hook's stderr (or stdout if stderr empty) shown to Claude as a system reminder |
| `shell` | no | `"bash"` or `"powershell"`. Defaults to `"bash"`, or `"powershell"` on Windows when Git Bash isn't installed. Ignored when `args` is set |

**Exec form vs shell form:** exec form runs when `args` is present; shell form when `args` is omitted.

- **Exec form**: Claude Code resolves `command` as an executable on `PATH`, spawns it directly with `args` as argv. No shell — each `args` element is one argument exactly as written; path placeholders substitute into `command` and each `args` element as plain strings. Special characters (apostrophes, `$`, backticks) pass through verbatim. No shell tokenization on any platform.
- **Shell form**: `command` string passed to a shell (`sh -c` on macOS/Linux, Git Bash on Windows, or PowerShell when Git Bash isn't installed; `shell` field chooses explicitly). Shell tokenizes, expands variables, interprets pipes/`&&`/redirects/globs.

Set `args` whenever the hook references a path placeholder — exec form needs no quoting for spaces/special characters. Omit `args` for shell features (pipes, `&&`) or when neither concern applies.

**Windows `.cmd`/`.bat` caveat:** exec form requires `command` to resolve to a real executable (e.g. `.exe`). The `.cmd`/`.bat` shims npm, npx, eslint etc. install in `node_modules/.bin` aren't executables and can't be spawned without a shell. Invoke the underlying script with `node` directly instead, e.g. `"command": "node", "args": ["${CLAUDE_PLUGIN_ROOT}/node_modules/eslint/bin/eslint.js"]` — works on every platform since `node.exe` is a real binary. To run a `.cmd`/`.bat` shim by name, use shell form.

Exec form example (path passed as one argument, no quoting):

```json
{
  "type": "command",
  "command": "node",
  "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/format.js", "--fix"]
}
```

Equivalent shell form (needs quoting for spaces/special characters):

```json
{
  "type": "command",
  "command": "node \"${CLAUDE_PLUGIN_ROOT}\"/scripts/format.js --fix"
}
```

In exec form, `command` is the executable name/path only. If `command` is a bare name with no path separator and contains whitespace alongside `args`, Claude Code logs a warning (spawn will fail — no executable named `node script.js`); move extra tokens into `args`. Absolute paths with spaces (`C:\Program Files\nodejs\node.exe`) are a single valid executable and don't trigger the warning.

## HTTP hook fields

| Field | Required | Description |
| :--- | :--- | :--- |
| `url` | yes | URL to send the POST request to |
| `headers` | no | Additional HTTP headers as key-value pairs. Values support `$VAR_NAME`/`${VAR_NAME}` interpolation. Only variables listed in `allowedEnvVars` are resolved |
| `allowedEnvVars` | no | List of env var names that may be interpolated into header values. References to unlisted variables are replaced with empty strings. Required for any interpolation to work |

Sends the hook's JSON input as the POST body (`Content-Type: application/json`). Response body uses the same JSON output format as command hooks. Error handling differs from command hooks: non-2xx responses, connection failures, and timeouts are all non-blocking errors that allow execution to continue. To block a tool call or deny a permission, return a 2xx response with a JSON body containing `decision: "block"` or `hookSpecificOutput.permissionDecision: "deny"`.

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "timeout": 30,
  "headers": { "Authorization": "Bearer $MY_TOKEN" },
  "allowedEnvVars": ["MY_TOKEN"]
}
```

## MCP tool hook fields

| Field | Required | Description |
| :--- | :--- | :--- |
| `server` | yes | Name of a configured MCP server. For a plugin-bundled server, this is the scoped name `plugin:<plugin-name>:<server-name>` (e.g. `plugin:my-plugin:db`), not the bare server key. The server must already be connected; the hook never triggers OAuth or a connection flow |
| `tool` | yes | Name of the tool to call on that server |
| `input` | no | Arguments passed to the tool. String values support `${path}` substitution from the hook's JSON input, e.g. `"${tool_input.file_path}"` |

Tool's text content is treated like command-hook stdout: valid JSON output is processed as a decision, otherwise shown as plain text. If the named server isn't connected, or the tool returns `isError: true`, the hook produces a non-blocking error and execution continues.

Available on every hook event once Claude Code has connected to MCP servers. `SessionStart` and `Setup` typically fire before servers finish connecting, so hooks on those events should expect a "not connected" error on first run.

```json
{
  "type": "mcp_tool",
  "server": "my_server",
  "tool": "security_scan",
  "input": { "file_path": "${tool_input.file_path}" }
}
```

Prompt/agent hook fields (`prompt`, `model`, plus `type`-specific config like `timeout` and `continueOnBlock`) are covered in [Prompt-based hooks](#prompt-based-hooks) and [Agent-based hooks](#agent-based-hooks).

## Path placeholders

| Placeholder | Resolves to |
| :--- | :--- |
| `${CLAUDE_PROJECT_DIR}` | Project root. Also set in the environment of stdio MCP servers and plugin LSP servers |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin's installation directory, for scripts bundled with a plugin. Changes on each plugin update |
| `${CLAUDE_PLUGIN_DATA}` | Plugin's persistent data directory, for dependencies/state that should survive plugin updates |

Prefer exec form for any hook referencing a path placeholder — no shell tokenization means paths with spaces need no quoting. In shell form, wrap each placeholder in double quotes.

Both forms export placeholders as environment variables `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA` on the spawned process (readable as e.g. `process.env.CLAUDE_PLUGIN_ROOT` regardless of launch form). Plugin hooks additionally substitute `${user_config.*}` values.

## Hooks in skills and agents

Hooks can be defined directly in skill or subagent YAML frontmatter, scoped to the component's lifecycle:

```yaml
---
name: secure-operations
description: Perform operations with security checks
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---
```

All hook events are supported. For subagents, `Stop` hooks are automatically converted to `SubagentStop` (the event that fires when a subagent completes). Same configuration format as settings-based hooks; cleaned up when the component finishes. `once: true` is only honored here (skill frontmatter), not in agent frontmatter or settings files.

## Disable hooks

Delete a hook's entry from settings JSON to remove it. See [Hook locations](#hook-locations) for `disableAllHooks`.

## Exit-code contract

**Exit 0**: success. Claude Code parses stdout for JSON output fields — JSON is only processed on exit 0. For most events, stdout is written to the debug log but not shown in the transcript; exceptions: `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, where stdout is added as context Claude can see and act on.

**Exit 2**: blocking error. Claude Code ignores stdout and any JSON in it. stderr text is fed back to Claude as an error message. Effect depends on event — see the table below.

**Any other exit code**: non-blocking error for most events. Transcript shows a `<hook name> hook error` notice with the first line of stderr; execution continues; full stderr goes to the debug log.

> Exit code 1 is treated as a non-blocking error and the action proceeds, even though 1 is the conventional Unix failure code. Use `exit 2` to enforce a policy. Exception: `WorktreeCreate`, where any non-zero exit code aborts worktree creation.

### Exit code 2 behavior per event

| Hook event | Can block? | What happens on exit 2 |
| :--- | :--- | :--- |
| `PreToolUse` | Yes | Blocks the tool call |
| `PermissionRequest` | Yes | Denies the permission |
| `UserPromptSubmit` | Yes | Blocks prompt processing and erases the prompt |
| `UserPromptExpansion` | Yes | Blocks the expansion |
| `Stop` | Yes | Prevents Claude from stopping, continues the conversation |
| `SubagentStop` | Yes | Prevents the subagent from stopping |
| `TeammateIdle` | Yes | Prevents the teammate from going idle, so it continues working |
| `TaskCreated` | Yes | Rolls back the task creation |
| `TaskCompleted` | Yes | Prevents the task from being marked as completed |
| `ConfigChange` | Yes | Blocks the configuration change (except `policy_settings`) |
| `StopFailure` | No | Output and exit code are ignored |
| `PostToolUse` | No | Shows stderr to Claude; the tool already ran |
| `PostToolUseFailure` | No | Shows stderr to Claude; the tool already failed |
| `PostToolBatch` | Yes | Stops the agentic loop before the next model call |
| `PermissionDenied` | No | Exit code and stderr ignored (denial already occurred). Use JSON `hookSpecificOutput.retry: true` instead |
| `Notification` | No | Shows stderr to user only |
| `SubagentStart` | No | Shows stderr to user only |
| `SessionStart` | No | Shows stderr to user only |
| `Setup` | No | Shows stderr to user only |
| `SessionEnd` | No | Shows stderr to user only |
| `CwdChanged` | No | Shows stderr to user only |
| `FileChanged` | No | Shows stderr to user only |
| `PreCompact` | Yes | Blocks compaction |
| `PostCompact` | No | Shows stderr to user only |
| `Elicitation` | Yes | Denies the elicitation |
| `ElicitationResult` | Yes | Blocks the response (action becomes decline) |
| `WorktreeCreate` | Yes | Any non-zero exit code causes worktree creation to fail |
| `WorktreeRemove` | No | Failures logged in debug mode only |
| `InstructionsLoaded` | No | Exit code is ignored |
| `MessageDisplay` | No | The original text is displayed |

For `SessionStart`, `Setup`, `SubagentStart`: exit code 2 stderr renders as a `<hook name> hook error` notice, same as a non-blocking error. Claude doesn't see it. For `SubagentStart`, the notice appears in the subagent's own transcript. As of v2.1.199, these three events show exit code 2 stderr in the transcript; earlier versions wrote it to the debug log only.

## HTTP response handling

| Response | Effect |
| :--- | :--- |
| 2xx, empty body | success, equivalent to exit 0 with no output |
| 2xx, plain text body | success, text added as context |
| 2xx, JSON body | success, parsed using the same JSON output schema as command hooks |
| Non-2xx status | non-blocking error, execution continues |
| Connection failure or timeout | non-blocking error, execution continues |

HTTP hooks can't signal a blocking error through status codes alone — return a 2xx response with the appropriate JSON decision fields.

## JSON output — universal fields

Choose one approach per hook: exit codes alone, or exit 0 + print JSON. Claude Code only processes JSON on exit 0. Stdout must contain only the JSON object (a shell profile that prints text on startup can break parsing).

Three kinds of fields: **universal** (table below, work across all events), top-level **`decision`/`reason`** (used by some events), and **`hookSpecificOutput`** (nested object requiring `hookEventName`, for richer per-event control).

| Field | Default | Description |
| :--- | :--- | :--- |
| `continue` | `true` | If `false`, Claude stops processing entirely after the hook runs. Takes precedence over any event-specific decision fields |
| `stopReason` | none | Message shown to the user when `continue` is `false`. Not shown to Claude |
| `suppressOutput` | `false` | If `true`, hides the hook's stdout from the transcript (still in debug log) |
| `systemMessage` | none | Warning message shown to the user |
| `terminalSequence` | none | Terminal escape sequence for Claude Code to emit on your behalf (desktop notification, window title, bell). Restricted to OSC `0`/`1`/`2`/`9`/`99`/`777` and BEL; a value with anything outside the allowlist is ignored |

Stop Claude entirely regardless of event: `{ "continue": false, "stopReason": "Build failed, fix errors before continuing" }`.

**`terminalSequence`** (requires v2.1.141+): hooks run without a controlling terminal, so `/dev/tty` writes fail; this field is emitted through Claude Code's own terminal write path instead (race-free, works in tmux/screen, works on Windows). Allowlist: OSC `0`/`1`/`2` (window/icon titles), OSC `9` (iTerm2/ConEmu/Windows Terminal/WezTerm notifications incl. `9;4` taskbar progress), OSC `99` (Kitty notifications), OSC `777` (urxvt/Ghostty/Warp notifications), bare BEL. Sequences may terminate with BEL or ST. Anything else (CSI cursor/color, OSC palette, OSC 8 hyperlinks, OSC 52 clipboard, OSC 1337) is rejected and the field ignored.

Hook output strings (`additionalContext`, `systemMessage`, plain stdout) are capped at **10,000 characters**; output exceeding this is saved to a file and replaced with a preview and file path, the same way large tool results are handled.

## additionalContext delivery

`additionalContext` passes a string from your hook into Claude's context window, wrapped in a system reminder and inserted at the point where the hook fired. Claude reads it on the next model request; it doesn't appear as a chat message. Return it inside `hookSpecificOutput` alongside `hookEventName`.

Delivery point depends on the event:

| Events | Delivered |
| :--- | :--- |
| `SessionStart`, `Setup`, `SubagentStart` | At the start of the conversation, before the first prompt |
| `UserPromptSubmit`, `UserPromptExpansion` | Alongside the submitted prompt |
| `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch` | Next to the tool result |
| `Stop`, `SubagentStop` | At the end of the turn — conversation continues so Claude can act on it |

When several hooks return `additionalContext` for the same event, Claude receives all values. A value exceeding 10,000 characters is written to a file in the session directory; Claude gets the file path with a short preview.

**Use for:** environment state (branch, deployment target, active flags), conditional project rules (which test command applies, which dirs are read-only), external data (open issues, CI results, fetched content). **Prefer CLAUDE.md** for static instructions that never change — it loads without running a script.

> Write the text as factual statements rather than imperative system instructions. Phrasing like "The deployment target is production" or "This repo uses `bun test`" reads as project information. Text framed as out-of-band system commands can trigger Claude's prompt-injection defenses, causing Claude to surface the text to you instead of treating it as context.

Once injected, the text is saved in the session transcript. For mid-session events (`PostToolUse`, `UserPromptSubmit`), resuming with `--continue`/`--resume` replays the saved text rather than re-running the hook for past turns — values like timestamps or commit SHAs go stale on resume. `SessionStart` hooks run again on resume with `source: "resume"`, so they can refresh their context.

## Decision-control summary

| Events | Decision pattern | Key fields |
| :--- | :--- | :--- |
| UserPromptSubmit, UserPromptExpansion, PostToolUse, PostToolUseFailure, PostToolBatch, Stop, SubagentStop, ConfigChange, PreCompact | Top-level `decision` | `decision: "block"`, `reason`. Stop/SubagentStop also accept `hookSpecificOutput.additionalContext` for non-error feedback that continues the conversation |
| TeammateIdle, TaskCreated, TaskCompleted | Exit code or `continue: false` | Exit code 2 blocks the action with stderr feedback. JSON `{"continue": false, "stopReason": "..."}` stops the teammate entirely, matching `Stop` hook behavior |
| PreToolUse | `hookSpecificOutput` | `permissionDecision` (allow/deny/ask/defer), `permissionDecisionReason` |
| PermissionRequest | `hookSpecificOutput` | `decision.behavior` (allow/deny) |
| PermissionDenied | `hookSpecificOutput` | `retry: true` tells the model it may retry the denied tool call |
| WorktreeCreate | path return | Command hook prints path on stdout; HTTP hook returns `hookSpecificOutput.worktreePath`. Hook failure or missing path fails creation |
| Elicitation | `hookSpecificOutput` | `action` (accept/decline/cancel), `content` (form field values for accept) |
| ElicitationResult | `hookSpecificOutput` | `action` (accept/decline/cancel), `content` (form field values override) |
| MessageDisplay | `hookSpecificOutput` | `displayContent` replaces the displayed text on screen. Display-only: transcript and what Claude sees keep the original |
| SessionStart, Setup, SubagentStart | Context only | `hookSpecificOutput.additionalContext`. SessionStart also accepts `initialUserMessage`, `watchPaths`, `sessionTitle`, `reloadSkills`. No blocking or decision control |
| WorktreeRemove, Notification, SessionEnd, PostCompact, InstructionsLoaded, StopFailure, CwdChanged, FileChanged | None | No decision control. Side effects only (logging, cleanup) |

For the top-level pattern, `"block"` is the only value; omit `decision` (or exit 0 with no JSON) to allow.

## Rewrite capabilities

A few events rewrite content rather than only allow/block:

- `PreToolUse`: `updatedInput` directly under `hookSpecificOutput` replaces a tool's arguments before it runs.
- `PermissionRequest`: `updatedInput` inside the `decision` object.
- `PostToolUse`: `updatedToolOutput` replaces the tool's result.
- `UserPromptSubmit`: can't replace the prompt — only injects `additionalContext` alongside it.

For redaction/transformation: intercept at `PreToolUse` for outbound tool inputs, `PostToolUse` for inbound tool results. Full field semantics (replace-vs-merge, interactive-tool rules, output-shape matching) are in hook-events.md under each event.

## Prompt-based hooks

`type: "prompt"` uses an LLM (Haiku by default) to evaluate allow/block. `type: "agent"` spawns a subagent with tool access. Not all events support every hook type.

**Support all five types** (`command`, `http`, `mcp_tool`, `prompt`, `agent`): `PermissionDenied`, `PermissionRequest`, `PostToolBatch`, `PostToolUse`, `PostToolUseFailure`, `PreToolUse`, `Stop`, `SubagentStop`, `TaskCompleted`, `TaskCreated`, `TeammateIdle`, `UserPromptExpansion`, `UserPromptSubmit`.

**Support `command`, `http`, `mcp_tool` only** (no `prompt`/`agent`): `ConfigChange`, `CwdChanged`, `Elicitation`, `ElicitationResult`, `FileChanged`, `InstructionsLoaded`, `Notification`, `PostCompact`, `PreCompact`, `SessionEnd`, `StopFailure`, `SubagentStart`, `WorktreeCreate`, `WorktreeRemove`.

**`SessionStart` and `Setup`** support `command` and `mcp_tool` only — no `http`, `prompt`, or `agent`.

How prompt hooks work: (1) send hook input + your prompt to a Claude model; (2) LLM responds with structured JSON containing a decision; (3) Claude Code processes the decision automatically.

### Prompt hook configuration

Set `type: "prompt"`, provide `prompt` (use `$ARGUMENTS` for the hook input JSON; if absent, input JSON is appended). Escape `\$1.00` for literal `$1.00`.

| Field | Required | Description |
| :--- | :--- | :--- |
| `type` | yes | Must be `"prompt"` |
| `prompt` | yes | Prompt text; `$ARGUMENTS` placeholder for hook input JSON |
| `model` | no | Defaults to a fast model |
| `timeout` | no | Default: 30 seconds |
| `continueOnBlock` | no | When `ok: false`, feed the reason back to Claude and continue the turn instead of stopping. Default `false`. Implemented as `continue: true` on the resulting `decision: "block"` |

### Response schema

```json
{
  "ok": true,
  "reason": "Explanation for the decision"
}
```

| Field | Description |
| :--- | :--- |
| `ok` | `true` allows. `false` produces a `decision: "block"` — see per-event behavior below |
| `reason` | Required when `ok` is `false`. Used as the block reason |

Per-event behavior on `ok: false`:

- `Stop`, `SubagentStop`: reason fed back to Claude as its next instruction; turn continues.
- `PreToolUse`: tool call denied, reason returned to Claude as the tool error (equivalent to `permissionDecision: "deny"`).
- `PostToolUse`: by default the turn ends and the reason appears as a warning line. `continueOnBlock: true` feeds the reason back to Claude and continues the turn.
- `PostToolBatch`, `UserPromptSubmit`, `UserPromptExpansion`: the turn ends and the reason appears as a warning line. These events end the turn on `decision: "block"` regardless of `continue`.
- `PostToolUseFailure`, `TaskCreated`, `TaskCompleted`: reason returned to Claude as a tool error, similar to `PreToolUse`.
- `TeammateIdle`: by default the teammate stops and the reason appears as a warning line. `continueOnBlock: true` feeds the reason back and keeps the teammate working.
- `PermissionRequest`: `ok: false` has no effect. To deny, use a command hook returning `hookSpecificOutput.decision.behavior: "deny"`.
- `PermissionDenied`: `ok: false` has no effect (denial already happened). This event only reads `hookSpecificOutput.retry`, which prompt/agent hooks can't set — their output is discarded. Use a command hook to return `retry`.

For finer control on any event, use a command hook with the per-event fields in hook-events.md.

## Agent-based hooks

> Experimental. Behavior and configuration may change. Prefer command hooks for production workflows.

`type: "agent"` is like a prompt hook but with multi-turn tool access: (1) Claude Code spawns a subagent with your prompt and the hook's JSON input; (2) the subagent uses tools like Read, Grep, Glob to investigate; (3) after up to 50 turns, it returns `{ "ok": true/false }`; (4) Claude Code processes the decision the same way as a prompt hook.

| Field | Required | Description |
| :--- | :--- | :--- |
| `type` | yes | Must be `"agent"` |
| `prompt` | yes | Prompt describing what to verify; `$ARGUMENTS` placeholder |
| `model` | no | Defaults to a fast model |
| `timeout` | no | Default: 60 seconds |

Response schema is identical to prompt hooks.

## Async hooks

`"async": true` on a `type: "command"` hook (only) runs it in the background without blocking Claude — for deployments, test suites, external API calls. Async hooks **can't** block or control behavior: `decision`, `permissionDecision`, `continue` have no effect because the action they'd control has already completed.

**Execution:** Claude Code starts the process and continues immediately; the hook receives the same stdin JSON as a sync hook. After the process exits, a JSON response's `additionalContext` field is delivered to Claude as context on the **next conversation turn** (if the session is idle, it waits until the next user interaction — except `asyncRewake`, see below). `systemMessage` is shown to the user, not Claude.

Claude Code validates the JSON response against the standard output schema and **drops any field with the wrong type** (e.g. a non-string `systemMessage`) instead of delivering it; `--debug` shows a warning naming each dropped field. Before v2.1.202, malformed JSON output from an async hook could crash the session, recurring on every resume.

Async hook completion notifications are suppressed by default — enable with `Ctrl+O` or `--verbose`.

**`asyncRewake`**: implies `async`; wakes Claude immediately (even when idle) on exit code 2; stderr, or stdout if stderr is empty, is shown to Claude as a system reminder.

**Limitations:**

- Only `type: "command"` supports `async` — prompt-based hooks can't run asynchronously.
- Can't block tool calls or return decisions; the triggering action has already proceeded by completion time.
- Output delivered on the next conversation turn (exception: `asyncRewake` on exit 2).
- Each execution is a separate background process — no deduplication across firings of the same async hook.

`timeout` sets the max seconds for the background process; unspecified defaults to the same 10-minute default as sync hooks.

## CLAUDE_ENV_FILE

Available **only** to these events: `SessionStart`, `Setup`, `CwdChanged`, `FileChanged`. Other hook types don't have access to this variable.

Write `export` statements to the path in `$CLAUDE_ENV_FILE` (append with `>>` to preserve variables set by other hooks); the exported variables become available to all subsequent Bash commands Claude Code executes during the session:

```bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=production' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

To capture all environment changes from setup commands, diff `export -p` before/after and append the delta with `comm -13`.

## Windows PowerShell

Set `"shell": "powershell"` on a command hook to run it in PowerShell — works regardless of `CLAUDE_CODE_USE_POWERSHELL_TOOL` since hooks spawn PowerShell directly. Claude Code auto-detects `pwsh.exe` (PowerShell 7+) and falls back to `powershell.exe` (Windows PowerShell 5.1).

Reference the project root in shell-form PowerShell as `${CLAUDE_PROJECT_DIR}` or `$env:CLAUDE_PROJECT_DIR`. As of v2.1.198, Claude Code rewrites `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}` placeholders in a PowerShell shell-form command to PowerShell's `${env:NAME}` form — regardless of whether the hook is in `settings.json`, a plugin, or a skill. This works inside double-quoted strings but **not** inside single-quoted strings (PowerShell never expands variables there).

Before v2.1.198, the rewrite applied only to plugin hooks; on earlier versions a `settings.json` hook needs the `$env:` form or exec form.

> Don't write the bare `$CLAUDE_PROJECT_DIR` spelling in a PowerShell hook — PowerShell parses it as an undefined local variable, resolving to `$null`. Claude Code doesn't rewrite that form; it logs a warning in the debug log instead.

Works on every version: `"command": "& \"$env:CLAUDE_PROJECT_DIR\\.claude\\hooks\\check.ps1\""`.

## Security considerations

Command hooks execute shell commands with your system user's **full permissions** — they can modify, delete, or access any file your account can access. Review and test all hook commands before adding them.

Best practices: validate/sanitize all inputs; always quote shell variables (`"$VAR"` not `$VAR`); block path traversal (`..` in file paths); use absolute paths (exec form: `${CLAUDE_PROJECT_DIR}` needs no quoting; shell form: wrap in double quotes); skip sensitive files (`.env`, `.git/`, keys).

## Debug hooks

`claude --debug-file <path>` writes the debug log (which hooks matched, exit codes, full stdout/stderr) to a known location, or `claude --debug` writes to `~/.claude/debug/<session-id>.txt`. `--debug` doesn't print to the terminal.

```text
[DEBUG] Executing hooks for PostToolUse:Write
[DEBUG] Found 1 hook commands to execute
[DEBUG] Executing hook command: <Your command> with timeout 600000ms
[DEBUG] Hook command completed with status 0: <Your stdout>
```

Set `CLAUDE_CODE_DEBUG_LOG_LEVEL=verbose` for more granular matching details (hook matcher counts, query matching).
