# Hooks reference — system contract

> Verified against <https://code.claude.com/docs/en/hooks.md> — 2026-09-07
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
- [Timeouts](#timeouts)
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
- **every tool call in the agentic loop**: `PreToolUse`, `PostToolUse` — except `EndConversation` calls, which skip both

All 33 events, with when each fires:

| Event | When it fires |
| :--- | :--- |
| `SessionStart` | When a session begins or resumes |
| `Setup` | When you start Claude Code with `--init-only`, or with `--init` or `--maintenance` in `-p` mode. For one-time preparation in CI or scripts |
| `UserPromptSubmit` | When you submit a prompt, before Claude processes it |
| `UserPromptExpansion` | When a user-typed command expands into a prompt, before it reaches Claude. Can block the expansion |
| `PreToolUse` | Before a tool call executes. Can block it |
| `PermissionRequest` | When a tool call needs a permission decision |
| `PermissionDenied` | When auto mode denies a tool call, including denials without a classifier verdict. Return `hookSpecificOutput.retry: true` to tell the model it may retry; ignored when the classifier produced no verdict |
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
| `StopFailure` | When the turn ends due to an API error |
| `TeammateIdle` | When an agent team teammate is about to go idle |
| `InstructionsLoaded` | When a CLAUDE.md or `.claude/rules/*.md` file is loaded into context. Fires at session start and when files are lazily loaded during a session |
| `ConfigChange` | When a configuration file changes during a session |
| `CwdChanged` | When the working directory changes, e.g. when Claude executes a `cd` command. Useful for reactive environment management with tools like direnv |
| `DirectoryAdded` | When a working directory is added mid-session via `/add-dir` or the SDK `register_repo_root` control request |
| `FileChanged` | When a watched file changes on disk. The `matcher` field specifies which filenames to watch |
| `WorktreeCreate` | When a worktree is being created via `--worktree`, `isolation: "worktree"`, or for a background session. Replaces default git behavior |
| `WorktreeRemove` | When a worktree is being removed at session exit, when a subagent finishes, or when you delete a background session |
| `PreCompact` | Before context compaction |
| `PostCompact` | After context compaction completes |
| `PreModelSwitch` | Before Claude Code applies a model switch that you or a client requested. Can block the switch |
| `PostModelSwitch` | After the session's model changes, including changes Claude Code makes on its own, such as restoring the model when you resume a session |
| `Elicitation` | When an MCP server requests user input during a tool call |
| `ElicitationResult` | After a user responds to an MCP elicitation, before the response is sent back to the server |
| `SessionEnd` | When a session terminates |

## Hook locations

| Location | Scope | Shareable |
| :--- | :--- | :--- |
| `~/.claude/settings.json` | All your projects | No, local to your machine |
| `.claude/settings.json` | Single project | Yes, can be committed to the repo |
| `.claude/settings.local.json` | Single project | No, gitignored when Claude Code saves a setting to it |
| Managed policy settings | Organization-wide | Yes, admin-controlled |
| Plugin `hooks/hooks.json` | When plugin is enabled | Yes, bundled with the plugin |
| Skill frontmatter | The rest of the session once the skill is invoked | Yes, defined in the skill file |
| Subagent frontmatter | While that subagent is running | Yes, defined in the subagent file |

Hook entries **merge** across settings levels rather than replacing each other. Hooks from settings files, managed policy settings, and plugins also run inside subagents; tool events fire the same configured hooks there, with `agent_id` and `agent_type` in the input.

`allowManagedHooksOnly` (enterprise) blocks user, project, local, and plugin hooks. Hooks from plugins force-enabled in managed settings `enabledPlugins` are exempt — lets admins distribute vetted hooks through an org marketplace. It also narrows `statusLine`, `fileSuggestion` and `subagentStatusLine` to managed settings, and disables plugins with a `command` source (and marketplace `headersHelper` commands) unless `disableCommandPluginSources` is explicitly `false`. `command` sources require Claude Code v2.1.229 or later.

Two HTTP-hook allowlists apply to hooks from every source, managed policy included: `allowedHttpHookUrls` (an HTTP handler runs only if its URL matches the merged allowlist) and `httpHookAllowedEnvVars` (only listed vars are interpolated into hook headers).

`disableAllHooks: true` in a settings file disables all hooks without removing them; no way to disable an individual hook while keeping it configured. Claude Code reads the value left **after settings precedence applies**, so `"disableAllHooks": false` in a project's `.claude/settings.json` overrides a `true` in user settings. To turn hooks off for one run whatever the project says, pass `--settings '{"disableAllHooks": true}'`. Respects the managed hierarchy: `disableAllHooks` in user/project/local settings can't disable managed-policy hooks — only the managed level can. Direct edits to hooks in settings files are normally picked up automatically by the file watcher.

`/hooks` opens a read-only browser of configured hooks, labeled `[type]` with a source: `User Settings`, `Project Settings`, `Local Settings`, `Plugin Hooks`, `Session Hooks` (registered in memory for the session).

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
| `SessionStart` | how the session started | `startup`, `resume`, `clear`, `compact`, `fork` |
| `Setup` | which CLI flag triggered setup | `init`, `maintenance` |
| `SessionEnd` | why the session ended | `clear`, `resume`, `logout`, `prompt_input_exit`, `other` |
| `Notification` | notification type | `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`, `elicitation_url_dialog`, `elicitation_complete`, `elicitation_response`, `agent_needs_input`, `agent_completed`, `quota_auto_resume_fired`, `quota_auto_resume_stale`, `quota_auto_resume_disabled` |
| `SubagentStart` | agent type | `general-purpose`, `Explore`, `Plan`, custom agent names, plugin-scoped names like `^my-plugin:reviewer$` |
| `PreCompact`, `PostCompact` | what triggered compaction | `manual`, `auto` |
| `PreModelSwitch`, `PostModelSwitch` | canonical name of the model the session switches to, derived from `to_model` | `claude-opus-5`, `claude-opus-4-6\|claude-opus-5`, `.*opus.*` |
| `SubagentStop` | agent type | same values as `SubagentStart` |
| `ConfigChange` | configuration source | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` |
| `CwdChanged` | no matcher support | always fires on every directory change |
| `DirectoryAdded` | how the directory was added | `slash_command`, `register_repo_root` |
| `FileChanged` | literal filenames to watch | `.envrc\|.env` |
| `StopFailure` | error type | `rate_limit`, `overloaded`, `authentication_failed`, `oauth_org_not_allowed`, `account_on_hold`, `billing_error`, `invalid_request`, `model_not_found`, `server_error`, `max_output_tokens`, `unknown` |
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

Note the two different spellings of the same plugin-bundled server: the **tool name** uses underscores (`mcp__plugin_<plugin-name>_<server-name>__<tool>`), while an `mcp_tool` handler's `server` field uses the colon-scoped form `plugin:<plugin-name>:<server-name>` — see [MCP tool hook fields](#mcp-tool-hook-fields).

## Hook handler types

Five handler types per matched group:

| Type | Behavior |
| :--- | :--- |
| `command` | Runs a shell command. Script receives JSON input on stdin; communicates via exit codes and stdout |
| `http` | Sends JSON input as an HTTP POST body. Endpoint communicates via response body using the same JSON output format as command hooks |
| `mcp_tool` | Calls a tool on an already-connected MCP server. Tool's text output treated like command-hook stdout |
| `prompt` | Sends a prompt to a Claude model (Haiku by default) for single-turn evaluation; model returns a yes/no JSON decision |
| `agent` | Spawns a subagent with tool access (Read, Grep, Glob) to verify conditions before returning a decision. Experimental |

All matching hooks run in parallel. The same handler defined in more than one settings file runs once; a plugin's or skill's copy of the same handler stays separate.

Handlers run in the current directory with Claude Code's environment. If the current directory no longer exists (a worktree or temp directory another shell deleted mid-session), Claude Code runs command hooks from the first of these that still exists: the session's starting directory, the project root, your home directory, the system temp directory — and records a warning naming the fallback in the debug log.

`$CLAUDE_CODE_REMOTE` is `"true"` in remote web environments, unset locally. As of v2.1.199, `$CLAUDE_CODE_BRIDGE_SESSION_ID` is set to the Remote Control session ID while the local session has an active Remote Control connection.

## Common handler fields

Apply to all hook types:

| Field | Required | Description |
| :--- | :--- | :--- |
| `type` | yes | `"command"`, `"http"`, `"mcp_tool"`, `"prompt"`, or `"agent"` |
| `if` | no | Permission rule syntax filtering when this hook runs, e.g. `"Bash(git *)"` or `"Edit(*.ts)"`. Only evaluated on tool events: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`. On other events, a hook with `if` set never runs |
| `timeout` | no | Seconds before canceling. Not enforced on an `async` command hook. Defaults and per-event overrides — including the `SessionEnd` budget, which a plugin hook's `timeout` cannot raise — are in [Timeouts](#timeouts) |
| `statusMessage` | no | Custom spinner message while the hook runs |
| `once` | no | If `true`, removed after its **first successful run**. A run that fails, blocks with exit code 2, or times out leaves the hook in place, so it runs again on the next matching event. Only honored for hooks declared in skill frontmatter; ignored in settings files and agent frontmatter |

`if` holds exactly one permission rule — no `&&`, `\|\|`, or list syntax. Define a separate hook handler per condition.

In an `if` condition for a file tool, a single-segment directory pattern like `"Edit(src/**)"` matches only the `src` directory in the working directory and files under it. To match a directory named `src` at any depth, write `"Edit(**/src/**)"`. Before v2.1.214, `"Edit(src/**)"` matched a `src` directory at any depth under the working directory.

**Bash `if` matching** (leading `VAR=value` assignments are stripped before matching):

| `if` pattern | Bash command | Hook runs? | Why |
| :--- | :--- | :--- | :--- |
| `Bash(git *)` | `FOO=bar git push` | yes | leading assignments stripped; `git push` matches |
| `Bash(git *)` | `npm test && git push` | yes | each subcommand checked; `git push` matches |
| `Bash(rm *)` | `echo $(rm -rf /)` | yes | commands inside `$()`/backticks are checked; `rm -rf /` matches |
| `Bash(rm *)` | `echo $(date)` | no | no subcommand matches `rm *` |
| `Bash(cat *)` | `echo before $(date) after` | no | a substitution can sit at any argument position, so the full command and `date` are both checked; neither matches `cat *` |
| `Bash(git *)` | `$TOOL git push` | yes | Claude Code can't tell what the command name expands to, so it runs the hook |
| `Bash(git push *)` | `echo $(date)` | yes | patterns specifying more than the command name run the hook anyway on `$()`, backticks, or `$VAR` |

The filter **fails open** — runs the hook regardless of pattern — when the Bash command can't be parsed. Because `if` is best-effort, use the permission system rather than a hook for a hard allow/deny.

## Command hook fields

| Field | Required | Description |
| :--- | :--- | :--- |
| `command` | yes | Shell command to execute. With `args`, the executable to spawn directly |
| `args` | no | Argument list. When present, `command` resolves as an executable spawned directly with `args` as argv, no shell involved |
| `async` | no | If `true`, runs in background without blocking. `type: "command"` only |
| `asyncRewake` | no | If `true`, runs in background and wakes Claude on exit code 2. Hook's stderr (or stdout if stderr empty) shown to Claude as a system reminder so it can react to a long-running background failure |
| `shell` | no | `"bash"` or `"powershell"`. Defaults to `"bash"`, or `"powershell"` on Windows when Git Bash isn't installed. Doesn't require `CLAUDE_CODE_USE_POWERSHELL_TOOL` — hooks spawn PowerShell directly. Ignored when `args` is set |

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
| `${CLAUDE_PROJECT_DIR}` | Project root where the session started. Also set in the environment of stdio MCP servers and plugin LSP servers |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin's installation directory, for scripts bundled with a plugin. Changes on each plugin update |
| `${CLAUDE_PLUGIN_DATA}` | Plugin's persistent data directory, for dependencies/state that should survive plugin updates |

Prefer exec form for any hook referencing a path placeholder — no shell tokenization means paths with spaces need no quoting. In shell form, wrap each placeholder in double quotes.

Both forms export placeholders as environment variables `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA` on the spawned process (readable as e.g. `process.env.CLAUDE_PLUGIN_ROOT` regardless of launch form).

**Worktrees:** if Claude enters a worktree during the session, `${CLAUDE_PROJECT_DIR}` **stays put** at the session's original project root, so `${CLAUDE_PROJECT_DIR}/.claude/hooks/check.sh` still runs the script in the main checkout. The `cwd` field in the hook's input JSON is what follows Claude — it is the worktree root after Claude enters a worktree, and the new directory after a `cd`. Read `cwd` when the hook needs to know where Claude is actually working.

**The `${user_config.*}` trap (plugin hooks):** plugin hooks substitute `${user_config.*}` values **in exec form only** — the value is substituted into `command` and into each `args` element as a plain string, so no shell re-parses it. A **shell-form** plugin hook whose `command` references `${user_config.*}` **fails with an error instead of running**. To use an option value from a shell-form hook, read the `$CLAUDE_PLUGIN_OPTION_<KEY>` environment variable (e.g. `$CLAUDE_PLUGIN_OPTION_WEBHOOK_URL` for a `webhook_url` option), or set `args` to switch the hook to exec form. Before v2.1.207, shell-form plugin hook commands also substituted `${user_config.*}`.

## Hooks in skills and agents

Hooks can be defined directly in skill or subagent YAML frontmatter:

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

All hook events are supported. Same configuration format as settings-based hooks. Lifetime differs by component:

- **Subagent hooks** run only while that subagent is running and are removed when it finishes. A `Stop` hook here is converted to `SubagentStop` (the event that fires when a subagent completes).
- **Skill hooks** are registered when you or Claude invoke the skill and **keep running for the rest of the session**, on turns after the skill's own turn as well. Set `once: true` to have Claude Code remove the hook after its first successful run instead. `once` is only honored here (skill frontmatter), not in agent frontmatter or settings files.

**Workspace trust differs between the two.** Frontmatter hooks in a project *skill* follow the same workspace-trust rule as settings-file hooks — registered on invocation, including in a `-p` run in a folder you haven't trusted. Frontmatter hooks in a project *subagent* run only after you accept the workspace trust dialog for the folder the agent file came from; a `-p` session doesn't count as accepting it. Before v2.1.218, these subagent hooks could run from untrusted folders.

## Disable hooks

Delete a hook's entry from settings JSON to remove it. See [Hook locations](#hook-locations) for `disableAllHooks`.

## Exit-code contract

The exit code doesn't act alone. **Claude Code reads JSON output fields from stdout on every exit code, not just 0**, and for events that use the standard decision model, a parsed object that passes schema validation takes effect alongside the code. Exit 2's block is the one outcome JSON can't override.

**The four rules — get these right. Older guidance treated exit 2 as the sole blocking signal; that model is wrong in three separate ways, all corrected below:**

1. **Exit 2 blocks on blocking events, and valid JSON cannot override it.** On events that can block, exit 2 blocks whether or not you print JSON — even a JSON `permissionDecision` of `"allow"` can't override it. Claude Code still reads any valid JSON on stdout. The blocking message is the reason from your JSON's blocking decision when it makes one, and your stderr text otherwise.
2. **`PermissionRequest` ignores exit 2 entirely.** Exit code 2 isn't honored for this event; the permission flow proceeds unchanged. To deny, return a `decision` object (`hookSpecificOutput.decision.behavior: "deny"`).
3. **`WorktreeCreate` aborts on ANY non-zero exit**, no matter what the JSON says.
4. **On standard-decision-model events, a non-zero exit other than 2 carrying valid JSON has its JSON honored and its exit code ignored.** Each field the event supports is honored — `permissionDecision`, `additionalContext`, `updatedInput`, `systemMessage` — and the hook isn't reported as an error.

> **Without valid JSON on stdout**, Claude Code treats exit code 1 as a non-blocking error and the action proceeds, even though 1 is the conventional Unix failure code. (With valid JSON, rule 4 applies and the JSON decides.) Use `exit 2` to enforce a policy through the exit code alone. Exception: `WorktreeCreate`, where any non-zero exit code aborts worktree creation.

**Exit 0**: success, and the intended code when printing JSON for structured control. For most events stdout goes to the debug log, not the transcript; the exceptions — `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, `PostModelSwitch` — add plain-text stdout as context Claude can see and act on. Stderr from a hook that exits 0 goes to the debug log only; Claude never sees it. To surface a warning to Claude from `PostToolUse`/`PostToolUseFailure`, exit 2 instead.

**How stdout is classified** (ignoring surrounding whitespace):

- Starts with `{` and ends with `}` → parsed as JSON. When the output is two or more lines that each parse as JSON on their own and none sets a JSON-output field, the whole output is treated as plain text; when one of them does set a field, the whole output is a parse failure.
- Starts with `{` but doesn't end with `}` → plain text.
- Starts with anything else → plain text, a JSON array or quoted JSON string included.

**Error outcomes on standard-decision-model events.** A parsed object that fails schema validation, or stdout Claude Code tries to parse as JSON and can't, is a non-blocking error on **every exit code other than 2**: the action proceeds and the transcript shows a `<hook name> hook error` notice carrying the validation or parse message. On the events that add plain-text stdout as context, the text isn't added. Before v2.1.248, Claude Code treated unparseable stdout as plain text. A hook that exits 2 while printing schema-failing JSON **still blocks**: stderr becomes the blocking reason and the validation failure goes to the debug log. Before v2.1.214, that combination was a non-blocking error and the action proceeded.

**Plain text or empty stdout on any other non-zero code** is a non-blocking error for most events: the action proceeds and the transcript shows a `<hook name> hook error` notice followed by the first line of stderr, prefixed `Failed with non-blocking status code:`. A hook that can't start lands in the same bucket — a mistyped path exits 127 and produces e.g. `Failed with non-blocking status code: /bin/sh: /path/to/hook.sh: No such file or directory`. **Watch for this notice on a policy hook's first run: a mistyped path leaves the gate silently disabled.**

**Events outside the standard decision model** keep their own rows in the table below: `WorktreeCreate` (rule 3), and events that discard hook output entirely, like `StopFailure`, which ignore JSON on every exit code apart from side-effect fields such as `terminalSequence`. On `Elicitation` and `ElicitationResult`, an exit-2 hook's `hookSpecificOutput` is ignored.

### Exit code 2 behavior per event

| Hook event | Can block? | What happens on exit 2 |
| :--- | :--- | :--- |
| `PreToolUse` | Yes | Blocks the tool call |
| `PermissionRequest` | **No** | Exit code 2 isn't honored for this event and the permission flow proceeds unchanged. Deny through the `decision` object instead |
| `UserPromptSubmit` | Yes | Blocks prompt processing and erases the prompt |
| `UserPromptExpansion` | Yes | Blocks the expansion |
| `Stop` | Yes | Prevents Claude from stopping, continues the conversation |
| `SubagentStop` | Yes | Prevents the subagent from stopping |
| `TeammateIdle` | Yes | Prevents the teammate from going idle, so it continues working |
| `TaskCreated` | Yes | Rolls back the task creation |
| `TaskCompleted` | Yes | Prevents the task from being marked as completed |
| `ConfigChange` | Yes | Blocks the configuration change from taking effect (except `policy_settings`) |
| `StopFailure` | No | Output and exit code are ignored, except `terminalSequence` |
| `PostToolUse` | No | Shows stderr to Claude; the tool already ran |
| `PostToolUseFailure` | No | Shows stderr to Claude; the tool already failed |
| `PostToolBatch` | Yes | Stops the agentic loop before the next model call |
| `PermissionDenied` | No | Exit code and stderr are ignored because the denial already occurred. Use JSON `hookSpecificOutput.retry: true` to tell the model it may retry; ignored for no-verdict denials |
| `Notification` | No | Exit code and stderr are ignored |
| `SubagentStart` | No | Shows stderr to user only |
| `SessionStart` | No | Shows stderr to user only |
| `Setup` | No | Exit code and stderr are ignored |
| `SessionEnd` | No | Shows stderr to user only |
| `CwdChanged` | No | Shows stderr to user only |
| `DirectoryAdded` | No | Stderr goes to the debug log; the directory is already added |
| `FileChanged` | No | Shows stderr to user only |
| `PreCompact` | Yes | Blocks compaction |
| `PostCompact` | No | Shows stderr to user only |
| `PreModelSwitch` | Yes | Blocks the model switch and shows stderr to the user |
| `PostModelSwitch` | No | Shows stderr to user only; the model already switched |
| `Elicitation` | Yes | Denies the elicitation |
| `ElicitationResult` | Yes | Blocks the response (action becomes decline) |
| `WorktreeCreate` | Yes | **Any non-zero exit code** causes worktree creation to fail |
| `WorktreeRemove` | No | Failures are logged in debug mode only |
| `InstructionsLoaded` | No | Exit code is ignored |
| `MessageDisplay` | No | The original text is displayed |

For `SessionStart`, `SubagentStart`, and `PostModelSwitch`, exit-2 stderr renders in the transcript as a `<hook name> hook error` notice, the same way a non-blocking error renders. Claude doesn't see it, and the session or subagent proceeds. For `SubagentStart`, the notice appears in the subagent's own transcript, not the parent conversation.

## Timeouts

| Handler type | Default timeout |
| :--- | :--- |
| `command`, `http`, `mcp_tool` | 600 s |
| `prompt` | 30 s |
| `agent` | 60 s |

Per-event overrides of the `command`/`http`/`mcp_tool` default: **30 s** on `UserPromptSubmit`, `PreModelSwitch`, `PostModelSwitch`; **10 s** on `MessageDisplay`. `SessionEnd` hooks share a **1.5-second budget**, applying to session exit, `/clear`, and switching sessions via interactive `/resume`.

> **Plugin authors: the budget-raise does not apply to you.** The shared `SessionEnd` budget is raised to the highest per-hook `timeout` **configured in settings files**, up to 60 seconds — but **a `timeout` set on a plugin-provided hook does not raise the budget.** A plugin `SessionEnd` hook that sets `"timeout": 10` still gets **1.5 seconds**, and the failure mode is **silent**: as with any timeout, Claude Code cancels the hook and **discards its output**, so it renders no decision and reports no blocking error — the work simply does not finish. (The live doc does not say whether the debug log names the budget as the cause; assume it does not help you.) Design plugin `SessionEnd` work to finish inside 1.5 s, or hand it to a detached process. The only way to raise the budget for a plugin hook is the user's environment: `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (milliseconds), which a plugin cannot set on its own behalf.

```bash
CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=5000 claude
```

Apart from a command hook run with `async: true`, Claude Code cancels a `command`, `http`, or `mcp_tool` hook that reaches its `timeout` and **discards its output**, so on most events a timed-out hook renders no decision. Two exceptions:

- On `PreModelSwitch`, a hook canceled at its timeout **blocks** the model switch.
- On `PreToolUse`, a timed-out `command`/`http`/`mcp_tool` hook **does not** block the tool call — the call continues through the normal permission flow, so don't count on a stalled hook to act as a gate. (An Agent SDK callback hook that exceeds its timeout does block.)

## HTTP response handling

| Response | Effect |
| :--- | :--- |
| 2xx, empty body | success, equivalent to exit 0 with no output |
| 2xx, JSON object body | parsed using the same JSON output schema as command hooks; a body that fails schema validation is a non-blocking error |
| 2xx, any other body (e.g. plain text) | **non-blocking error**, handled the same as a non-2xx status. The text is **not** added to Claude's context |
| Non-2xx status | non-blocking error, execution continues |
| Connection failure | non-blocking error, execution continues |
| Timeout | the hook is canceled — see [Timeouts](#timeouts) |

HTTP hooks can't signal a blocking error through status codes alone — return a 2xx response with the appropriate JSON decision fields. An event with its own failure contract in the per-event table, such as `WorktreeCreate`, applies that contract to a failed HTTP hook too.

## JSON output — universal fields

Choose one approach per hook: exit codes alone for signaling, or exit 0 and print JSON for structured control. **If you mix them, exit 2 keeps its blocking effect and Claude Code still reads the JSON fields** (the elicitation exception is noted in the [exit-code contract](#exit-code-contract)). Stdout must contain only the JSON object (a shell profile that prints text on startup can break parsing).

Three kinds of fields: **universal** (table below — every event accepts them, though some discard them or deliver `systemMessage` elsewhere), top-level **`decision`/`reason`** (used by some events), and **`hookSpecificOutput`** (nested object requiring `hookEventName`, for richer per-event control).

| Field | Default | Description |
| :--- | :--- | :--- |
| `continue` | `true` | If `false`, Claude stops processing entirely after the hook runs. Takes precedence over any event-specific decision fields |
| `stopReason` | none | Message shown to the user when `continue` is `false`. Not shown to Claude |
| `suppressOutput` | `false` | **Has no effect.** Claude Code accepts the field but doesn't act on it. A successful hook's stdout is never shown in the transcript and is recorded in the debug log |
| `systemMessage` | none | Warning message shown to the user. In Agent SDK and `--output-format stream-json` output it can arrive as an `SDKInformationalMessage` |
| `terminalSequence` | none | Terminal escape sequence for Claude Code to emit on your behalf (desktop notification, window title, bell). Restricted to OSC `0`/`1`/`2`/`9`/`99`/`777` and BEL; a value with anything outside the allowlist is ignored |

Stop Claude entirely regardless of event: `{ "continue": false, "stopReason": "Build failed, fix errors before continuing" }`. For `PreToolUse` and `PostToolUse`, the stop applies even when the tool call fails or completes while Claude is still streaming.

**`terminalSequence`** (requires v2.1.141+): hooks run without a controlling terminal, so `/dev/tty` writes fail; this field is emitted through Claude Code's own terminal write path instead (race-free, works in tmux/screen, works on Windows). Allowlist: OSC `0`/`1`/`2` (window/icon titles), OSC `9` (iTerm2/ConEmu/Windows Terminal/WezTerm notifications incl. `9;4` taskbar progress), OSC `99` (Kitty notifications), OSC `777` (urxvt/Ghostty/Warp notifications), bare BEL. Sequences may terminate with BEL or ST. Anything else (CSI cursor/color, OSC palette, OSC 8 hyperlinks, OSC 52 clipboard, OSC 1337) is rejected and the field ignored. Because Claude Code writes the sequence itself, the field works even on events that discard `systemMessage` and `continue`, such as `Notification` and `StopFailure`. Two limits: it is written only in an interactive session while the interface is on screen (ignored under `-p` and in the Agent SDK), and a `WorktreeCreate` **command** hook can't return JSON at all because its stdout is read as the worktree path — an HTTP `WorktreeCreate` hook can include the field.

Hook output strings (`additionalContext`, `systemMessage`, plain stdout) are capped at **10,000 characters**; output exceeding this is saved to a file and replaced with a preview and file path, the same way large tool results are handled.

## additionalContext delivery

`additionalContext` passes a string from your hook into Claude's context window, wrapped in a system reminder and inserted at the point where the hook fired. Claude reads it on the next model request; it doesn't appear as a chat message. Return it inside `hookSpecificOutput` alongside `hookEventName`.

Delivery point depends on the event:

| Events | Delivered |
| :--- | :--- |
| `SessionStart`, `SubagentStart` | At the start of the conversation, before the first prompt |
| `UserPromptSubmit`, `UserPromptExpansion` | Alongside the submitted prompt |
| `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch` | Next to the tool result |
| `Stop`, `SubagentStop` | At the end of the turn — conversation continues so Claude can act on it |
| `PostModelSwitch` | With the next request after the switch |

When several hooks return `additionalContext` for the same event, Claude receives all values. A value exceeding 10,000 characters is written to a file in the session directory; Claude gets the file path with a short preview.

**Use for:** environment state (branch, deployment target, active flags), conditional project rules (which test command applies, which dirs are read-only), external data (open issues, CI results, fetched content). **Prefer CLAUDE.md** for static instructions that never change — it loads without running a script.

> Write the text as factual statements rather than imperative system instructions. Phrasing like "The deployment target is production" or "This repo uses `bun test`" reads as project information. Text framed as out-of-band system commands can trigger Claude's prompt-injection defenses, causing Claude to surface the text to you instead of treating it as context.

Once injected, the text is saved in the session transcript. For mid-session events (`PostToolUse`, `UserPromptSubmit`), resuming with `--continue`/`--resume` replays the saved text rather than re-running the hook for past turns — values like timestamps or commit SHAs go stale on resume. `SessionStart` hooks run again on resume with `source: "resume"`, or `"fork"` with `--fork-session`, so they can refresh their context.

## Decision-control summary

| Events | Decision pattern | Key fields |
| :--- | :--- | :--- |
| UserPromptSubmit, UserPromptExpansion, PostToolUse, PostToolUseFailure, PostToolBatch, Stop, SubagentStop, ConfigChange, PreCompact | Top-level `decision` | `decision: "block"`, `reason`. Stop/SubagentStop also accept `hookSpecificOutput.additionalContext` for non-error feedback that continues the conversation |
| TeammateIdle, TaskCompleted | Exit code or `continue: false` | Exit code 2 blocks the action with stderr feedback. JSON `{"continue": false, "stopReason": "..."}` also stops the teammate entirely, matching `Stop` hook behavior; TaskCompleted ignores it when the `TaskUpdate` tool triggered the event |
| TaskCreated | Exit code or top-level `decision` | Exit code 2 or `decision: "block"` cancels the task and returns the message to Claude. `continue: false` is ignored |
| PreToolUse | `hookSpecificOutput` | `permissionDecision` (allow/deny/ask/defer), `permissionDecisionReason` |
| PreModelSwitch | `hookSpecificOutput` or top-level `decision` | `permissionDecision` (allow/deny/ask), `permissionDecisionReason`. `decision: "block"` also cancels the switch |
| PermissionRequest | `hookSpecificOutput` | `decision.behavior` (allow/deny). Exit 2 is not honored here |
| PermissionDenied | `hookSpecificOutput` | `retry: true` tells the model it may retry the denied tool call; ignored for no-verdict denials |
| WorktreeCreate | path return | Command hook prints path on stdout; HTTP hook returns `hookSpecificOutput.worktreePath`. Hook failure or missing path fails creation |
| Elicitation | `hookSpecificOutput` | `action` (accept/decline/cancel), `content` (form field values for accept) |
| ElicitationResult | `hookSpecificOutput` | `action` (accept/decline/cancel), `content` (form field values override) |
| MessageDisplay | `hookSpecificOutput` | `displayContent` replaces the displayed text on screen. Display-only: transcript and what Claude sees keep the original |
| SessionStart, SubagentStart, PostModelSwitch | Context only | `hookSpecificOutput.additionalContext`. SessionStart also accepts `initialUserMessage`, `watchPaths`, `sessionTitle`, `reloadSkills`. No blocking or decision control |
| Setup, WorktreeRemove, Notification, SessionEnd, PostCompact, InstructionsLoaded, StopFailure, CwdChanged, DirectoryAdded, FileChanged | None | No decision control. Side effects only (logging, cleanup) |

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

**Support `command`, `http`, `mcp_tool` only** (no `prompt`/`agent`): `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `Elicitation`, `ElicitationResult`, `FileChanged`, `InstructionsLoaded`, `MessageDisplay`, `Notification`, `PostCompact`, `PostModelSwitch`, `PreCompact`, `PreModelSwitch`, `SessionEnd`, `StopFailure`, `SubagentStart`, `WorktreeCreate`, `WorktreeRemove`.

**`SessionStart` and `Setup`** support `command` and `mcp_tool` only — no `http`, `prompt`, or `agent`.

How prompt hooks work: (1) send hook input + your prompt to a Claude model; (2) LLM responds with structured JSON containing a decision; (3) Claude Code processes the decision automatically.

### Prompt hook configuration

Set `type: "prompt"`, provide `prompt` (use `$ARGUMENTS` for the hook input JSON; if absent, input JSON is appended).

| Field | Required | Description |
| :--- | :--- | :--- |
| `type` | yes | Must be `"prompt"` |
| `prompt` | yes | Prompt text; `$ARGUMENTS` placeholder for hook input JSON |
| `model` | no | Defaults to a fast model |
| `timeout` | no | Default: 30 seconds |
| `continueOnBlock` | no | On the events it applies to, `true` feeds an `ok: false` reason back to Claude and continues instead of ending the turn. Default `false` |

### Response schema

```json
{
  "ok": true,
  "reason": "Explanation for the decision",
  "impossible": false
}
```

| Field | Description |
| :--- | :--- |
| `ok` | `true` allows. `false` produces a block — see per-event behavior below |
| `reason` | Required when `ok` is `false`. Used as the block reason |
| `impossible` | Optional. The model returns it with `ok: false` when it judges the condition can never be satisfied. On `Stop` and `SubagentStop`, Claude Code then lets the turn end instead of feeding the reason back. Agent hooks and other events ignore it |

Per-event behavior on `ok: false`:

- `Stop`, `SubagentStop`: reason fed back to Claude as its next instruction and the turn continues — unless the response also sets `impossible: true`, in which case the stop is allowed and the turn ends.
- `PreToolUse`: the tool call is denied; **by default the turn ends** and the deny reason appears in the chat as a warning line. Set `continueOnBlock: true` to return the reason to Claude as the tool error instead so it can adjust and continue (equivalent to a command hook's `permissionDecision: "deny"`). Before v2.1.210, the deny reason was returned as the tool error and the turn continued.
- `PostToolUse`: by default the turn ends and the reason appears as a warning line. `continueOnBlock: true` feeds the reason back to Claude and continues the turn.
- `PostToolBatch`, `UserPromptSubmit`, `UserPromptExpansion`: the turn ends and the reason appears as a warning line. These events end the turn on `decision: "block"` regardless of `continue`.
- `PostToolUseFailure`, `TaskCreated`: reason returned to Claude as a tool error and the turn continues, regardless of `continueOnBlock`.
- `TaskCompleted`: when it fires because a task is marked completed during a turn, the reason is returned as a tool error and the turn continues, regardless of `continueOnBlock`. When it fires because a teammate stops, it behaves like `TeammateIdle`.
- `TeammateIdle`: by default the teammate stops and the reason appears as a warning line. `continueOnBlock: true` feeds the reason back and keeps the teammate working.
- `PermissionRequest`: `ok: false` has no effect. To deny, use a command hook returning `hookSpecificOutput.decision.behavior: "deny"`.
- `PermissionDenied`: `ok: false` has no effect (denial already happened). This event only reads `hookSpecificOutput.retry`, which prompt/agent hooks can't set — their output is discarded. Use a command hook to return `retry`.

For finer control on any event, use a command hook with the per-event fields in hook-events.md.

## Agent-based hooks

> Experimental. Behavior and configuration may change. Prefer command hooks for production workflows.

`type: "agent"` is like a prompt hook but with multi-turn tool access: (1) Claude Code spawns a subagent with your prompt and the hook's JSON input; (2) the subagent uses tools like Read, Grep, Glob to investigate; (3) after up to 50 turns, it returns `{ "ok": true/false }`; (4) Claude Code allows the action if `ok` is `true`. Agent hooks support the same events as prompt hooks.

| Field | Required | Description |
| :--- | :--- | :--- |
| `type` | yes | Must be `"agent"` |
| `prompt` | yes | Prompt describing what to verify; `$ARGUMENTS` placeholder |
| `model` | no | Defaults to a fast model |
| `timeout` | no | Default: 60 seconds |

On `ok: false`, Claude Code handles an agent hook the way it handles a **prompt hook with `continueOnBlock: true`** on the same event. Agent hooks have no `continueOnBlock` field and don't support the prompt-hook `impossible` field.

## Async hooks

`"async": true` on a `type: "command"` hook (only) runs it in the background without blocking Claude — for deployments, test suites, external API calls. Async hooks **can't** block or control behavior: `decision`, `permissionDecision`, `continue` have no effect because the action they'd control has already completed.

**Execution:** Claude Code starts the process and continues immediately; the hook receives the same stdin JSON as a sync hook. After the process exits, the `additionalContext` **and `systemMessage`** fields from its JSON response are delivered to Claude on the **next conversation turn**. Unlike a synchronous hook's `systemMessage`, neither field is shown to you.

Claude Code validates the JSON response against the standard output schema and **drops any field with the wrong type** (e.g. a non-string `systemMessage`) instead of delivering it; `--debug` shows a warning naming each dropped field. Before v2.1.202, malformed JSON output from an async hook could crash the session, recurring on every resume.

Async hook completion notifications are suppressed by default — enable with `Ctrl+O` or `--verbose`.

**`asyncRewake`**: wakes Claude immediately (even when idle) on exit code 2; stderr, or stdout if stderr is empty, is shown to Claude as a system reminder.

**Timeout:** once an async hook is running in the background, Claude Code **doesn't enforce `timeout` on it**. It *does* still enforce `timeout` on a hook run with `asyncRewake`.

**Limitations:**

- Only `type: "command"` supports `async` — prompt-based hooks can't run asynchronously.
- Can't block tool calls or return decisions; the triggering action has already proceeded by completion time.
- Output delivered on the next conversation turn; if the session is idle it waits for the next user interaction (exception: `asyncRewake` on exit 2).
- Each execution is a separate background process — no deduplication across firings of the same async hook.
- In non-interactive `-p` mode, Claude Code kills any async hook still running at teardown and finalizes it with outcome `cancelled`. Work that must outlive a `claude -p` session needs a fully detached process.

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

**Workspace trust.** Claude Code checks workspace trust before running any hook from a settings file. In an interactive session it holds back hooks from *every* settings file — including your own `~/.claude/settings.json` — until you accept the workspace trust dialog for the folder or a parent whose trust extends to it. In a `-p` or SDK session it never shows the dialog and treats the folder as trusted, so hooks committed in a repository's `.claude/settings.json` **run in a folder you have never trusted**. Before scripting `claude -p` over a repository you didn't write, review its `.claude/` settings files, start with `--bare`, or pass `--settings '{"disableAllHooks": true}'`.

Best practices: validate/sanitize all inputs; always quote shell variables (`"$VAR"` not `$VAR`); block path traversal (`..` in file paths); use absolute paths (exec form: `${CLAUDE_PROJECT_DIR}` needs no quoting; shell form: wrap in double quotes); skip sensitive files (`.env`, `.git/`, keys).

## Debug hooks

`claude --debug-file <path>` writes the debug log (which hooks matched, exit codes, full stdout/stderr) to a known location, or `claude --debug` writes to `~/.claude/debug/<session-id>.txt`. `--debug` doesn't print to the terminal.

```text
2026-07-19T02:03:24.382Z [DEBUG] Hook output does not start with {, treating as plain text
2026-07-19T02:03:24.382Z [DEBUG] Hook PostToolUse:Write (PostToolUse) success:
hook-ran
```

Set `CLAUDE_CODE_DEBUG_LOG_LEVEL=verbose` for more granular matching details (hook matcher counts, query matching).
