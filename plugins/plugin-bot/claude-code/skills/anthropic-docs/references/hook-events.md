# Hook events reference — per-event schemas

> Verified against <https://code.claude.com/docs/en/hooks.md> — 2026-07-10
> Companion file: hooks.md covers the shared hook system contract (locations, matcher rules, handler types, exit codes, JSON output, async, prompt/agent hooks, debugging). This file covers per-event input fields, matcher values, and decision-control output for every hook event.

## Contents

- [Common input fields](#common-input-fields)
- [SessionStart](#sessionstart)
- [Setup](#setup)
- [InstructionsLoaded](#instructionsloaded)
- [UserPromptSubmit](#userpromptsubmit)
- [UserPromptExpansion](#userpromptexpansion)
- [MessageDisplay](#messagedisplay)
- [PreToolUse](#pretooluse)
- [PermissionRequest](#permissionrequest)
- [PostToolUse](#posttooluse)
- [PostToolUseFailure](#posttoolusefailure)
- [PostToolBatch](#posttoolbatch)
- [PermissionDenied](#permissiondenied)
- [Notification](#notification)
- [SubagentStart](#subagentstart)
- [SubagentStop](#subagentstop)
- [TaskCreated](#taskcreated)
- [TaskCompleted](#taskcompleted)
- [Stop](#stop)
- [StopFailure](#stopfailure)
- [TeammateIdle](#teammateidle)
- [ConfigChange](#configchange)
- [CwdChanged](#cwdchanged)
- [FileChanged](#filechanged)
- [WorktreeCreate](#worktreecreate)
- [WorktreeRemove](#worktreeremove)
- [PreCompact](#precompact)
- [PostCompact](#postcompact)
- [SessionEnd](#sessionend)
- [Elicitation](#elicitation)
- [ElicitationResult](#elicitationresult)

## Common input fields

Every hook receives these, plus event-specific fields:

| Field | Description |
| :--- | :--- |
| `session_id` | Current session identifier |
| `prompt_id` | UUID of the user prompt currently being processed. Matches the `prompt.id` OpenTelemetry attribute. Absent until the first user input. Requires Claude Code v2.1.196 or later |
| `transcript_path` | Path to conversation JSON. Written asynchronously — may lag the current turn's most recent messages. For the final assistant text of the current turn, use `last_assistant_message` on Stop/SubagentStop instead |
| `cwd` | Current working directory when the hook is invoked |
| `permission_mode` | `"default"`, `"plan"`, `"acceptEdits"`, `"auto"`, `"dontAsk"`, or `"bypassPermissions"`. The **Manual** mode arrives as `"default"`, never `"manual"`. Not all events receive this field |
| `effort` | Object with `level`: `"low"`, `"medium"`, `"high"`, `"xhigh"`, `"max"`. Downgraded level if requested effort exceeds model support. Ultracode reports as `"xhigh"`. Present for events firing within a tool-use context (PreToolUse, PostToolUse, Stop, SubagentStop) when the model supports the effort parameter. Also exposed to hook commands and Bash as `$CLAUDE_EFFORT` |
| `hook_event_name` | Name of the event that fired |

When running with `--agent` or inside a subagent, two more fields:

| Field | Description |
| :--- | :--- |
| `agent_id` | Unique subagent identifier. Present only when the hook fires inside a subagent call |
| `agent_type` | Agent name (e.g. `"Explore"`, `"security-reviewer"`). Present when the session uses `--agent` or the hook fires inside a subagent — the subagent's type takes precedence over the session's `--agent` value. For custom subagents, the frontmatter `name`, not the filename. For plugin-shipped subagents, the plugin-scoped identifier like `my-plugin:reviewer` |

Only `SessionStart` hooks can receive a `model` field, and it isn't guaranteed present. No `$CLAUDE_MODEL` env var exists; a hook process inherits the parent environment so it can read `$ANTHROPIC_MODEL` if set in the shell, but that doesn't change when you switch models with `/model` mid-session.

```json
{
  "session_id": "abc123",
  "prompt_id": "550e8400-e29b-41d4-a716-446655440000",
  "transcript_path": "/home/user/.claude/projects/.../transcript.jsonl",
  "cwd": "/home/user/my-project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "npm test" }
}
```

## SessionStart

Runs on every session start/resume — keep these hooks fast. Only `type: "command"` and `type: "mcp_tool"` supported.

**Matcher** (`source`):

| Matcher | When it fires |
| :--- | :--- |
| `startup` | New session |
| `resume` | `--resume`, `--continue`, or `/resume` |
| `clear` | `/clear` |
| `compact` | Auto or manual compaction |

**Input** — adds `source` and optionally `model`, `agent_type`, `session_title`:

| Field | Description |
| :--- | :--- |
| `source` | `"startup"`, `"resume"`, `"clear"`, `"compact"` |
| `model` | Active model identifier. May be omitted (e.g. after `/clear`, or conversation recovery) |
| `agent_type` | Agent name, present when started with `claude --agent <name>` |
| `session_title` | Current session title if already set (e.g. via `--name`/`/rename`). A hook emitting `sessionTitle` can check this first to avoid overwriting a user-set title |

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "hook_event_name": "SessionStart",
  "source": "startup",
  "model": "claude-sonnet-5"
}
```

**Decision control** — any stdout is added as context. Event-specific fields:

| Field | Description |
| :--- | :--- |
| `additionalContext` | String added at the start of the conversation, before the first prompt |
| `initialUserMessage` | First user message of the session. Applies in `-p` non-interactive mode — becomes the first turn even if no prompt given; if a prompt is given, it follows as the next turn. Unlike `additionalContext` (attaches to an existing turn), this creates the turn |
| `sessionTitle` | Sets the session title, same effect as `/rename`. Applies only when `source` is `"startup"` or `"resume"`; ignored on `"clear"`/`"compact"` |
| `watchPaths` | Array of absolute paths to watch for `FileChanged` events during this session |
| `reloadSkills` | Boolean. `true` re-scans skill/command directories after SessionStart hooks complete, so skills the hook installed are available starting with the first prompt (skill discovery normally runs before SessionStart hooks finish) |

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Current branch: feat/auth-refactor\nUncommitted changes: src/auth.ts",
    "sessionTitle": "auth-refactor"
  }
}
```

**Env persistence:** `SessionStart` hooks have `$CLAUDE_ENV_FILE` — write `export` statements (append `>>`) to persist env vars into subsequent Bash commands for the session. See hooks.md § CLAUDE_ENV_FILE.

## Setup

Fires **only** with `--init-only`, or `--init`/`--maintenance` combined with `-p`. Doesn't fire on normal startup. `--init-only` also runs `SessionStart` with the `startup` matcher, then exits without starting a conversation. In an interactive session, `--init`/`--maintenance` don't currently fire Setup. Only `type: "command"` and `type: "mcp_tool"` supported.

Since Setup doesn't fire on every launch, a plugin needing a dependency installed should check-on-first-use-and-install-on-miss rather than rely on Setup alone (e.g. test for `${CLAUDE_PLUGIN_DATA}/node_modules`, run `npm install` if absent).

**Matcher** (`trigger`):

| Matcher | When it fires |
| :--- | :--- |
| `init` | `claude --init-only` or `claude -p --init` |
| `maintenance` | `claude -p --maintenance` |

**Input** — adds `trigger`: `"init"` or `"maintenance"`.

```json
{ "session_id": "abc123", "cwd": "/Users/...", "hook_event_name": "Setup", "trigger": "init" }
```

**Decision control:** can't block. Any non-zero exit (incl. 2) surfaces stderr to the user as `<hook name> hook error`; execution continues. In `-p` mode, hook output appears only with `--verbose`.

| Field | Description |
| :--- | :--- |
| `additionalContext` | Added to Claude's context; plain stdout is written to debug log only. Multiple hooks' values concatenated |

Has `$CLAUDE_ENV_FILE` access, same as SessionStart.

## InstructionsLoaded

Fires when a `CLAUDE.md` or `.claude/rules/*.md` file loads into context — at session start for eager files, and again on lazy loads (e.g. accessing a subdirectory with a nested `CLAUDE.md`, or conditional rules with `paths:` frontmatter matching). Runs async, for observability only — no blocking or decision control.

**Matcher** (`load_reason`), e.g. `"session_start"` or `"path_glob_match|nested_traversal"`.

**Input:**

| Field | Description |
| :--- | :--- |
| `file_path` | Absolute path to the instruction file loaded |
| `memory_type` | `"User"`, `"Project"`, `"Local"`, or `"Managed"` |
| `load_reason` | `"session_start"`, `"nested_traversal"`, `"path_glob_match"`, `"include"`, or `"compact"` (fires when instruction files are re-loaded after compaction) |
| `globs` | Path glob patterns from the file's `paths:` frontmatter, if any. Present only for `path_glob_match` loads |
| `trigger_file_path` | Path to the file whose access triggered this load, for lazy loads |
| `parent_file_path` | Path to the parent instruction file that included this one, for `include` loads |

```json
{
  "session_id": "abc123",
  "cwd": "/Users/my-project",
  "hook_event_name": "InstructionsLoaded",
  "file_path": "/Users/my-project/CLAUDE.md",
  "memory_type": "Project",
  "load_reason": "session_start"
}
```

## UserPromptSubmit

Runs when the user submits a prompt, before Claude processes it. Default timeout 30s for `command`/`http`/`mcp_tool` (shorter than the 600s default elsewhere) since it blocks model processing until it completes. On timeout, the hook is canceled and its output (incl. `additionalContext`) is discarded — the prompt still reaches Claude without it. As of v2.1.196, the transcript shows a notice naming the hook and timeout; earlier versions cancel silently.

No matcher support.

**Input** — adds `prompt` (the submitted text).

```json
{ "session_id": "abc123", "cwd": "/Users/...", "permission_mode": "default", "hook_event_name": "UserPromptSubmit", "prompt": "Write a function to calculate the factorial of a number" }
```

**Decision control:** two ways to add context on exit 0 — plain non-JSON stdout (shown as hook output in transcript), or JSON `additionalContext` (injected as a system reminder, no visible transcript entry).

| Field | Description |
| :--- | :--- |
| `decision` | `"block"` prevents the prompt from being processed and erases it from context. Omit to allow |
| `reason` | Shown to the user when blocked. Not added to context |
| `additionalContext` | String added alongside the submitted prompt |
| `sessionTitle` | Sets the session title based on prompt content |
| `suppressOriginalPrompt` | If `true` when blocked, omits the original prompt text from the block message shown to the user |

```json
{
  "decision": "block",
  "reason": "Explanation for decision",
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "My additional context here",
    "sessionTitle": "My session title"
  }
}
```

## UserPromptExpansion

Runs when a user-typed command expands into a prompt, before reaching Claude — covers the path `PreToolUse` doesn't: a `PreToolUse` hook matching `Skill` only fires when Claude *calls* the tool, but typing `/skillname` directly bypasses `PreToolUse`. Use to block direct slash-command invocation or inject context for a specific skill.

**Matcher**: `command_name`. Empty matcher fires on every prompt-type command.

**Input** — adds `expansion_type` (`"slash_command"` for skill/custom commands, `"mcp_prompt"` for MCP server prompts), `command_name`, `command_args`, `command_source`, and the original `prompt`.

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "UserPromptExpansion",
  "expansion_type": "slash_command",
  "command_name": "example-skill",
  "command_args": "arg1 arg2",
  "command_source": "plugin",
  "prompt": "/example-skill arg1 arg2"
}
```

**Decision control:**

| Field | Description |
| :--- | :--- |
| `decision` | `"block"` prevents the command from expanding. Omit to allow |
| `reason` | Shown to the user when blocked |
| `additionalContext` | String added alongside the expanded prompt |

```json
{
  "decision": "block",
  "reason": "This slash command is not available",
  "hookSpecificOutput": { "hookEventName": "UserPromptExpansion", "additionalContext": "Additional context for this expansion" }
}
```

## MessageDisplay

Runs while an assistant message streams to the screen — once per batch of newly completed lines (a long message → several calls; a short one → maybe one). Claude Code holds each batch until the hook returns, so keep it fast; default timeout 10s. If the hook fails or times out, the original text is displayed.

**Display-only**: replacement text changes only what's rendered. Transcript and what Claude sees keep the original — Claude never sees the replacement; verbose mode shows the original. Fires only for messages with text (tool-call-only responses don't trigger it). No matcher support.

In non-interactive runs (Agent SDK, `claude -p`): fires once per assistant message (not per batch), after the message completes, with `index: 0`, `final: true`, and `delta` holding the full message text.

**Input:**

| Field | Description |
| :--- | :--- |
| `turn_id` | UUID of the current turn |
| `message_id` | UUID of the assistant message, stable across every batch of the same message. Not the API `msg_…` id — can't be correlated with transcript message ids |
| `index` | Zero-based index of this batch within the message |
| `final` | `true` on the message's last batch (exactly one per message) |
| `delta` | Newly completed lines since the prior batch, terminating newlines included. Always whole lines except the final batch, which may end mid-line. In interactive runs, the final batch's `delta` is empty when the message ends on a newline — use `final`, not non-empty `delta`, as the end-of-message signal. In Agent SDK/`claude -p`, the single call carries the entire message |

```json
{
  "session_id": "abc123",
  "cwd": "/Users/my-project",
  "hook_event_name": "MessageDisplay",
  "turn_id": "0c9e6a2f-7d41-4f4e-9a15-3f4f7c2b8d10",
  "message_id": "5b2a9c8e-1f63-4d8a-b7c4-9e0d2a6f1c3b",
  "index": 0,
  "final": false,
  "delta": "Here is the plan:\n"
}
```

**Output:**

| Field | Description |
| :--- | :--- |
| `displayContent` | Text displayed in place of the delta. Omit to display the original |

No decision control — can't block the message or change what's stored in the transcript or sent to Claude.

## PreToolUse

Runs after Claude creates tool parameters, before processing the tool call. Matches tool name: `Bash`, `Edit`, `Write`, `Read`, `Glob`, `Grep`, `Agent`, `WebFetch`, `WebSearch`, `AskUserQuestion`, `ExitPlanMode`, and any MCP tool names.

> Only fires when Claude calls a tool. Files referenced with `@` in a prompt are inserted without a tool call, so no `PreToolUse` fires (including `Read`-matched hooks). To block specific `@`-referenced paths, use a `Read` deny permission rule instead.

**Input** — adds `tool_name`, `tool_input`, `tool_use_id`. `tool_input` shape depends on the tool:

**Bash:**

| Field | Type | Example | Description |
| :--- | :--- | :--- | :--- |
| `command` | string | `"npm test"` | The shell command to execute |
| `description` | string | `"Run test suite"` | Optional description |
| `timeout` | number | `120000` | Optional timeout in ms |
| `run_in_background` | boolean | `false` | Whether to run in background |

**Write:**

| Field | Type | Example |
| :--- | :--- | :--- |
| `file_path` | string | `"/path/to/file.txt"` |
| `content` | string | `"file content"` |

**Edit:**

| Field | Type | Example |
| :--- | :--- | :--- |
| `file_path` | string | `"/path/to/file.txt"` |
| `old_string` | string | `"original text"` |
| `new_string` | string | `"replacement text"` |
| `replace_all` | boolean | `false` |

**Read:**

| Field | Type | Example |
| :--- | :--- | :--- |
| `file_path` | string | `"/path/to/file.txt"` |
| `offset` | number | `10` (optional start line) |
| `limit` | number | `50` (optional line count) |

**Glob:**

| Field | Type | Example |
| :--- | :--- | :--- |
| `pattern` | string | `"**/*.ts"` |
| `path` | string | `"/path/to/dir"` (optional, defaults to cwd) |

**Grep:**

| Field | Type | Example |
| :--- | :--- | :--- |
| `pattern` | string | `"TODO.*fix"` |
| `path` | string | optional file/dir |
| `glob` | string | optional file filter |
| `output_mode` | string | `"content"`, `"files_with_matches"` (default), `"count"` |
| `-i` | boolean | case insensitive |
| `multiline` | boolean | enable multiline matching |

**WebFetch:**

| Field | Type | Example |
| :--- | :--- | :--- |
| `url` | string | `"https://example.com/api"` |
| `prompt` | string | `"Extract the API endpoints"` |

**WebSearch:**

| Field | Type | Example |
| :--- | :--- | :--- |
| `query` | string | `"react hooks best practices"` |
| `allowed_domains` | array | optional |
| `blocked_domains` | array | optional |

**Agent** (spawns a subagent):

| Field | Type | Example |
| :--- | :--- | :--- |
| `prompt` | string | `"Find all API endpoints"` |
| `description` | string | short task description |
| `subagent_type` | string | `"Explore"` |
| `model` | string | optional model alias override |

In `PostToolUse`, a completed Agent call's `tool_response` carries final text + usage telemetry:

| Field | Type | Example | Description |
| :--- | :--- | :--- | :--- |
| `status` | string | `"completed"` | `"completed"` (foreground) or `"async_launched"` (background). As of v2.1.198, subagents run in the background by default, so an omitted `run_in_background` also produces `"async_launched"` |
| `agentId` | string | `"a4d2c8f1e0b3a297"` | Identifier for the subagent run |
| `content` | array | `[{"type": "text", "text": "..."}]` | Subagent's final text blocks |
| `resolvedModel` | string | `"claude-sonnet-4-5"` | Model actually used, may differ from requested. Requires v2.1.174+ |
| `totalTokens` | number | `12450` | Total tokens billed across the subagent's turns |
| `totalDurationMs` | number | `48211` | Wall-clock duration |
| `totalToolUseCount` | number | `7` | Count of tool calls made |
| `usage` | object | `{"input_tokens": 8320, ...}` | Per-type breakdown: `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens` |

For background subagents, `tool_response` returns immediately with no usage fields: `status: "async_launched"`, `agentId`, `description`, `prompt`, `outputFile`, `resolvedModel`.

**AskUserQuestion** (asks 1–4 multiple-choice questions):

| Field | Type | Example | Description |
| :--- | :--- | :--- | :--- |
| `questions` | array | `[{"question": "Which framework?", "header": "Framework", "options": [{"label": "React"}], "multiSelect": false}]` | Each has `question`, short `header`, `options` array, optional `multiSelect` |
| `answers` | object | `{"Which framework?": "React"}` | Optional. Maps question text → selected option label; multi-select answers join labels with commas. Claude doesn't set this — supply via `updatedInput` to answer programmatically |

**ExitPlanMode** (presents a plan, asks approval before leaving plan mode). Claude writes the plan to a file first, so literal `tool_input` from the model is typically empty; Claude Code injects `plan` and `planFilePath` before passing to hooks:

| Field | Type | Example | Description |
| :--- | :--- | :--- | :--- |
| `plan` | string | `"## Refactor auth\n1. Extract..."` | Plan content in Markdown, injected from disk |
| `planFilePath` | string | `"/Users/.../plans/refactor-auth.md"` | Path to the plan file, injected |
| `allowedPrompts` | array | `[{"tool": "Bash", "prompt": "run tests"}]` | Deprecated as of v2.1.205 — field accepted but ignored. Before that, carried prompt-based permissions Claude requested to implement the plan |

In `PostToolUse`, `tool_response` is `{ plan, filePath, ...internal status flags }` — read `tool_response.plan` rather than re-reading the file.

### PreToolUse decision control

Unlike other events' top-level `decision`, PreToolUse returns its decision inside `hookSpecificOutput` — four outcomes plus input rewrite:

| Field | Description |
| :--- | :--- |
| `permissionDecision` | `"allow"` skips the prompt (except tools requiring user interaction — see below). `"deny"` prevents the call. `"ask"` prompts the user to confirm. `"defer"` exits gracefully so the tool can be resumed later. Deny/ask permission rules are still evaluated regardless of what the hook returns |
| `permissionDecisionReason` | For `"allow"`/`"ask"`: shown to the user, not Claude. For `"deny"`: shown to Claude. For `"defer"`: ignored |
| `updatedInput` | Modifies the tool's input parameters before execution. **Replaces the entire input object** — include unchanged fields alongside modified ones. Combine with `"allow"` to auto-approve, or `"ask"` to show modified input to the user. Ignored for `"defer"` |
| `additionalContext` | String added alongside the tool result. Ignored when `permissionDecision` is `"defer"` |

Precedence when multiple PreToolUse hooks return different decisions: `deny` > `defer` > `ask` > `allow`.

When a hook returns `"ask"`, the permission prompt shows a source label: `[User]`, `[Project]`, `[Plugin]`, or `[Local]`.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "My reason here",
    "updatedInput": { "field_to_modify": "new value" },
    "additionalContext": "Current environment: production. Proceed with caution."
  }
}
```

**Interactive-tools allow+updatedInput rule:** `AskUserQuestion` and `ExitPlanMode` require user interaction and normally block in `-p` non-interactive mode. Returning `permissionDecision: "allow"` **together with `updatedInput`** satisfies that requirement — the hook reads the tool's stdin input, collects the answer through its own UI, and returns it in `updatedInput` so the tool runs without prompting. `"allow"` alone is **not** sufficient. For `AskUserQuestion`, echo back the original `questions` array plus an `answers` object mapping each question's text to the chosen answer.

As of v2.1.199, an MCP tool marked with `_meta["anthropic/requiresUserInteraction"]` is stricter: a hook can't skip its approval prompt with `"allow"`, with or without `updatedInput` — Claude Code can't confirm the hook collected the interaction the tool needs.

> PreToolUse previously used top-level `decision`/`reason`, deprecated for this event. Deprecated values `"approve"`/`"block"` map to `"allow"`/`"deny"`. Other events (PostToolUse, Stop) continue to use top-level `decision`/`reason` as current format.

### Defer round-trip summary

`"defer"` requires Claude Code v2.1.89+; earlier versions ignore it and the tool proceeds normally. Honored only in `-p` non-interactive mode — in interactive sessions it logs a warning and is ignored. For integrations running `claude -p` as a subprocess (Agent SDK app, custom UI) that need to pause Claude at a tool call, collect input via their own UI, and resume.

Round trip:

1. Claude calls a tool (e.g. `AskUserQuestion`); `PreToolUse` fires.
2. Hook returns `permissionDecision: "defer"`. Tool doesn't execute; process exits with `stop_reason: "tool_deferred"`, pending call preserved in the transcript.
3. Calling process reads `deferred_tool_use` from the SDK result (`id`, `name`, `input`), surfaces the question in its own UI.
4. Calling process runs `claude -p --resume <session-id>`; the same tool call fires `PreToolUse` again.
5. Hook returns `permissionDecision: "allow"` with the answer in `updatedInput`; the tool executes and Claude continues.

```json
{
  "type": "result",
  "subtype": "success",
  "stop_reason": "tool_deferred",
  "session_id": "abc123",
  "deferred_tool_use": {
    "id": "toolu_01abc",
    "name": "AskUserQuestion",
    "input": { "questions": [{ "question": "Which framework?", "header": "Framework", "options": [{"label": "React"}, {"label": "Vue"}], "multiSelect": false }] }
  }
}
```

No timeout or retry limit — session stays on disk until resumed, subject to `cleanupPeriodDays` (30-day default). If not ready, the hook can `"defer"` again. `"defer"` only works when Claude makes a **single** tool call in the turn — with several parallel calls, `"defer"` is ignored with a warning and the tool proceeds normally (resume can only re-run one tool). If the deferred tool is no longer available on resume (e.g. its MCP server isn't connected), the process exits with `stop_reason: "tool_deferred_unavailable"` and `is_error: true` before the hook fires, `deferred_tool_use` still included.

`--resume` restores the permission mode active when deferred (no need to pass `--permission-mode` again), except `plan` and `bypassPermissions`, which are never carried over. Explicit `--permission-mode` on resume overrides the restored value.

## PermissionRequest

Runs when a permission dialog is about to be shown to the user (vs. `PreToolUse`, which runs before tool execution regardless of permission status). Matches on tool name, same values as PreToolUse.

**Input** — `tool_name`, `tool_input` (like PreToolUse, but no `tool_use_id`), and optional `permission_suggestions` array with the "always allow" options the dialog would show.

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "PermissionRequest",
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf node_modules", "description": "Remove node_modules directory" },
  "permission_suggestions": [
    { "type": "addRules", "rules": [{ "toolName": "Bash", "ruleContent": "rm -rf node_modules" }], "behavior": "allow", "destination": "localSettings" }
  ]
}
```

**Decision control** — return a `decision` object:

| Field | Description |
| :--- | :--- |
| `behavior` | `"allow"` grants, `"deny"` denies. Deny/ask permission rules are still evaluated — an `"allow"` from a hook doesn't override a matching deny rule |
| `updatedInput` | `"allow"` only: modifies the tool's input parameters. **Replaces the entire input object.** The modified input is re-evaluated against deny/ask rules |
| `updatedPermissions` | `"allow"` only: array of permission update entries to apply (see table below) |
| `message` | `"deny"` only: tells Claude why denied |
| `interrupt` | `"deny"` only: if `true`, stops Claude |

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": { "behavior": "allow", "updatedInput": { "command": "npm run lint" } }
  }
}
```

### Permission update entries

Both `updatedPermissions` (output) and `permission_suggestions` (input) use this entry shape:

| `type` | Fields | Effect |
| :--- | :--- | :--- |
| `addRules` | `rules`, `behavior`, `destination` | Adds permission rules. `rules`: array of `{toolName, ruleContent?}`; omit `ruleContent` to match the whole tool. `behavior`: `"allow"`, `"deny"`, `"ask"` |
| `replaceRules` | `rules`, `behavior`, `destination` | Replaces all rules of the given `behavior` at `destination` with `rules` |
| `removeRules` | `rules`, `behavior`, `destination` | Removes matching rules of the given `behavior` |
| `setMode` | `mode`, `destination` | Changes permission mode: `default`, `auto`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`, and (v2.1.200+) `manual` as an alias for `default` |
| `addDirectories` | `directories`, `destination` | Adds working directories (array of path strings) |
| `removeDirectories` | `directories`, `destination` | Removes working directories |

> `setMode` with `bypassPermissions` only takes effect if the session was launched with bypass mode already available (`--dangerously-skip-permissions`, `--permission-mode bypassPermissions`, `--allow-dangerously-skip-permissions`, or `permissions.defaultMode: "bypassPermissions"`), and not disabled by `permissions.disableBypassPermissionsMode`. Otherwise the update is a no-op. `bypassPermissions` is never persisted as `defaultMode` regardless of `destination`.

`destination` values:

| `destination` | Writes to |
| :--- | :--- |
| `session` | in-memory only, discarded when session ends |
| `localSettings` | `.claude/settings.local.json` |
| `projectSettings` | `.claude/settings.json` |
| `userSettings` | `~/.claude/settings.json` |

A hook can echo one of the received `permission_suggestions` back as `updatedPermissions` — equivalent to the user picking that "always allow" option.

## PostToolUse

Runs immediately after a tool completes successfully. Matches on tool name, same values as PreToolUse.

**Input** — adds `tool_input` (arguments sent) and `tool_response` (result returned); exact schema depends on the tool.

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": { "file_path": "/path/to/file.txt", "content": "file content" },
  "tool_response": { "filePath": "/path/to/file.txt", "success": true },
  "tool_use_id": "toolu_01ABC123...",
  "duration_ms": 12
}
```

| Field | Description |
| :--- | :--- |
| `duration_ms` | Optional. Tool execution time in ms. Excludes time in permission prompts and PreToolUse hooks |

**Decision control:**

| Field | Description |
| :--- | :--- |
| `decision` | `"block"` adds `reason` next to the tool result. Claude still sees the original output — use `updatedToolOutput` to replace it |
| `reason` | Explanation shown to Claude when blocked |
| `additionalContext` | String added alongside the tool result |
| `updatedToolOutput` | Replaces the tool's output before it's sent to Claude. **Must match the tool's output shape** |
| `updatedMCPToolOutput` | Replaces output for MCP tools only. Prefer `updatedToolOutput`, which works for all tools |

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Additional information for Claude",
    "updatedToolOutput": { "stdout": "[redacted]", "stderr": "", "interrupted": false, "isImage": false }
  }
}
```

> **`updatedToolOutput` shape-matching warning:** only changes what Claude sees — the tool has already run, so files written / commands executed / network requests sent have already taken effect. Telemetry (OTel tool spans, analytics) also captures the original output before the hook runs. Built-in tools return structured objects (e.g. `Bash` returns `{stdout, stderr, interrupted, isImage}`); a replacement value that doesn't match the tool's output schema is **ignored** and the original output is used. MCP tool output is passed through without schema validation. Stripping error details Claude needs can cause it to proceed on a false assumption. To prevent/modify a call before it runs, use `PreToolUse` instead.

## PostToolUseFailure

Runs when a tool execution fails (throws or returns a failure result). Matches on tool name, same values as PreToolUse.

**Input** — same `tool_name`/`tool_input` as PostToolUse, plus error fields:

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_input": { "command": "npm test", "description": "Run test suite" },
  "tool_use_id": "toolu_01ABC123...",
  "error": "Command exited with non-zero status code 1",
  "is_interrupt": false,
  "duration_ms": 4187
}
```

| Field | Description |
| :--- | :--- |
| `error` | String describing what went wrong |
| `is_interrupt` | Optional boolean — whether the failure was caused by user interruption |
| `duration_ms` | Optional. Execution time in ms, excluding permission prompts / PreToolUse hooks |

**Decision control:**

| Field | Description |
| :--- | :--- |
| `additionalContext` | String added alongside the error |

```json
{ "hookSpecificOutput": { "hookEventName": "PostToolUseFailure", "additionalContext": "Additional information about the failure for Claude" } }
```

## PostToolBatch

Runs once after every tool call in a batch has resolved, before the next model call — unlike `PostToolUse` which fires once per tool (concurrently for parallel calls). No matcher.

**Input** — adds `tool_calls`, an array of every call in the batch:

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "PostToolBatch",
  "tool_calls": [
    { "tool_name": "Read", "tool_input": {"file_path": "/.../ledger/accounts.py"}, "tool_use_id": "toolu_01...", "tool_response": "     1\tfrom __future__ import annotations\n     2\t..." },
    { "tool_name": "Read", "tool_input": {"file_path": "/.../ledger/transactions.py"}, "tool_use_id": "toolu_02...", "tool_response": "     1\tfrom __future__ import annotations\n     2\t..." }
  ]
}
```

`tool_response` is the same content the model receives in the corresponding `tool_result` block — a serialized string or content-block array exactly as the tool emitted it (for `Read`, line-number-prefixed text, not raw file contents). Responses can be large — parse only needed fields.

> **`tool_response` shape differs from `PostToolUse`'s**: `PostToolUse` passes the tool's structured `Output` object (e.g. `{filePath: "...", success: true}` for `Write`); `PostToolBatch` passes the serialized `tool_result` content the model sees.

**Decision control:**

| Field | Description |
| :--- | :--- |
| `additionalContext` | Context string injected once before the next model call |

```json
{ "hookSpecificOutput": { "hookEventName": "PostToolBatch", "additionalContext": "These files are part of the ledger module. Run pytest before marking the task complete." } }
```

`decision: "block"` or `continue: false` stops the agentic loop before the next model call.

## PermissionDenied

Fires **only** when the auto mode classifier denies a tool call — not on manual dialog denial, `PreToolUse` blocks, or a matching `deny` rule. Matches on tool name, same values as PreToolUse.

**Input** — adds `tool_name`, `tool_input`, `tool_use_id`, `reason`:

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "auto",
  "hook_event_name": "PermissionDenied",
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf /tmp/build", "description": "Clean build directory" },
  "tool_use_id": "toolu_01ABC123...",
  "reason": "Auto mode denied: command targets a path outside the project"
}
```

| Field | Description |
| :--- | :--- |
| `reason` | The classifier's explanation for the denial |

**Decision control — retry:**

```json
{ "hookSpecificOutput": { "hookEventName": "PermissionDenied", "retry": true } }
```

`retry: true` adds a message telling the model it may retry the call — the denial itself is **not** reversed. No JSON, or `retry: false`, leaves the original rejection message standing.

## Notification

Fires when Claude Code sends notifications. Omit matcher to run for all types.

| Matcher | When it fires |
| :--- | :--- |
| `permission_prompt` | Claude needs you to approve a tool use |
| `idle_prompt` | Claude is done and waiting for your next prompt |
| `auth_success` | Authentication completes |
| `elicitation_dialog` | An MCP server opens an elicitation form |
| `elicitation_complete` | An MCP elicitation form is submitted or dismissed |
| `elicitation_response` | An MCP elicitation response is sent back to the server |
| `agent_needs_input` | A background session starts waiting on your input. Requires v2.1.198+. Fires only while agent view is open in a terminal |
| `agent_completed` | A background session finishes or fails. Requires v2.1.198+. Fires only while agent view is open in a terminal |

**Input** — adds `message`, optional `title`, `notification_type`:

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "hook_event_name": "Notification",
  "message": "Claude needs your permission",
  "title": "Permission needed",
  "notification_type": "permission_prompt"
}
```

No decision control — can't block or modify notifications; use for side effects (e.g. forwarding to an external service). Universal JSON output fields like `systemMessage` apply.

## SubagentStart

Fires when a subagent is spawned via the Agent tool. Matches agent type name: built-in name (`general-purpose`, `Explore`, `Plan`), or for custom subagents, the frontmatter `name` (not filename). For plugin-shipped subagents, the plugin-scoped identifier (e.g. `my-plugin:reviewer`) — the colon puts it on the regex path, so anchor with `^...$` for an exact match: `^my-plugin:reviewer$`.

**Input** — adds `agent_id`, `agent_type`:

```json
{ "session_id": "abc123", "cwd": "/Users/...", "hook_event_name": "SubagentStart", "agent_id": "agent-abc123", "agent_type": "Explore" }
```

Can't block subagent creation, but can inject context:

| Field | Description |
| :--- | :--- |
| `additionalContext` | String added to the subagent's context at the start of its conversation, before its first prompt |

```json
{ "hookSpecificOutput": { "hookEventName": "SubagentStart", "additionalContext": "Follow security guidelines for this task" } }
```

## SubagentStop

Fires when a subagent finishes responding. Matches on agent type, same values as SubagentStart.

**Input** — adds `stop_hook_active`, `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`. `transcript_path` is the main session's transcript; `agent_transcript_path` is the subagent's own transcript in a nested `subagents/` folder. `last_assistant_message` is the subagent's final response text, readable without parsing the transcript file.

Also receives `background_tasks` and `session_crons` (v2.1.145+, see [Stop](#stop) for field tables) — both scoped to the **parent session**, not the subagent.

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "SubagentStop",
  "stop_hook_active": false,
  "agent_id": "def456",
  "agent_type": "Explore",
  "agent_transcript_path": "~/.claude/projects/.../abc123/subagents/agent-def456.jsonl",
  "last_assistant_message": "Analysis complete. Found 3 potential issues...",
  "background_tasks": [],
  "session_crons": []
}
```

Uses the same decision-control format as [Stop](#stop-decision-control), including `hookSpecificOutput.additionalContext` (with `hookEventName: "SubagentStop"`) for non-error feedback that keeps the subagent running. `decision: "block"` + `reason` keeps the subagent running, delivering `reason` as its next instruction. To inject context into the **parent** session after a subagent returns, use a `PostToolUse` hook on the `Agent` tool instead.

## TaskCreated

Fires when a task is created via `TaskCreate`. No matcher support.

**Input** — adds `task_id`, `task_subject`, optional `task_description`, `teammate_name`, `team_name`:

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "TaskCreated",
  "task_id": "task-001",
  "task_subject": "Implement user authentication",
  "task_description": "Add login and signup endpoints",
  "teammate_name": "implementer",
  "team_name": "session-a1b2c3d4"
}
```

| Field | Description |
| :--- | :--- |
| `task_id` | Identifier of the task being created |
| `task_subject` | Title of the task |
| `task_description` | Detailed description. May be absent |
| `teammate_name` | Name of the teammate creating the task. May be absent |
| `team_name` | Deprecated. Session-derived; will be removed |

**Decision control:** exit code 2 → task not created, stderr fed back as feedback. JSON `{"continue": false, "stopReason": "..."}` → stops the teammate entirely, matching `Stop` behavior; `stopReason` shown to the user.

## TaskCompleted

Fires when a task is marked completed — either explicitly via `TaskUpdate`, or when an agent team teammate finishes its turn with in-progress tasks. No matcher support.

**Input** — same shape as TaskCreated (`task_id`, `task_subject`, optional `task_description`, `teammate_name`, `team_name`):

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "TaskCompleted",
  "task_id": "task-001",
  "task_subject": "Implement user authentication",
  "task_description": "Add login and signup endpoints",
  "teammate_name": "implementer",
  "team_name": "session-a1b2c3d4"
}
```

**Decision control:** exit code 2 → task not marked completed, stderr fed back as feedback. JSON `{"continue": false, "stopReason": "..."}` → stops the teammate entirely, matching `Stop` behavior.

## Stop

Fires when the main agent finishes responding. Does not fire on a user interrupt. API errors fire `StopFailure` instead. No matcher support.

> `/goal` is a built-in shortcut for a session-scoped prompt-based Stop hook.

**Input** — adds `stop_hook_active`, `last_assistant_message`, `background_tasks`, `session_crons`.

`stop_hook_active` is `true` when Claude Code is already continuing as a result of a stop hook — check it (or process the transcript) to avoid blocking on a condition that never resolves. **Claude Code overrides the hook and ends the turn after 8 consecutive blocks.**

`last_assistant_message` holds Claude's final response text — use this rather than `transcript_path` for hooks acting on the just-completed turn (the transcript file isn't guaranteed to include the final message at Stop time on all versions).

`background_tasks`/`session_crons` (v2.1.145+) let hooks distinguish "session is done" from "session is paused waiting for background work". Both present when the task registry is reachable, empty when nothing is in flight/scheduled.

`background_tasks` entries:

| Field | Description |
| :--- | :--- |
| `id` | Task identifier |
| `type` | Friendly label: `shell`, `subagent`, `monitor`, `workflow`, `teammate`, `cloud session`, `MCP task`. Falls back to the raw discriminant for unrecognized types |
| `status` | Current task status |
| `description` | Free text, capped at 1000 chars with `… [+N chars]` marker when clipped |
| `command` | Shell command line, capped at 1000 chars. Present only for `shell` tasks |
| `agent_type` | Subagent type name. Present only for `subagent` tasks |
| `server` | MCP server name. Present only for `monitor`/`MCP task` tasks |
| `tool` | MCP tool name. Present only for `monitor`/`MCP task` tasks |
| `name` | Workflow name. Present only for `workflow` tasks |

`session_crons` entries (sourced from `CronCreate`, `ScheduleWakeup`, `/loop`):

| Field | Description |
| :--- | :--- |
| `id` | Cron task identifier |
| `schedule` | Cron expression, e.g. `0 9 * * 1-5` |
| `recurring` | `false` for one-shot wakeups; `true` for tasks that re-fire on every match |
| `prompt` | Prompt submitted when the cron fires, capped at 1000 chars with the same clip marker |

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": true,
  "last_assistant_message": "I've completed the refactoring. Here's a summary...",
  "background_tasks": [
    { "id": "task-001", "type": "shell", "status": "running", "description": "tail logs", "command": "tail -f /var/log/syslog" }
  ],
  "session_crons": [
    { "id": "cron-001", "schedule": "0 9 * * 1-5", "recurring": true, "prompt": "check the build" }
  ]
}
```

### Stop decision control

| Field | Description |
| :--- | :--- |
| `decision` | `"block"` prevents Claude from stopping. Omit to allow it to stop |
| `reason` | Required when blocked. Tells Claude why it should continue |
| `hookSpecificOutput.additionalContext` | Non-error feedback — conversation continues so Claude can act on it, but (unlike `decision: "block"`) shown in transcript as hook feedback rather than a hook error |

```json
{ "decision": "block", "reason": "Must be provided when Claude is blocked from stopping" }
```

**`additionalContext` vs. `decision: "block"`:** use `additionalContext` when the hook is working as designed and giving guidance (e.g. "run the test suite before finishing"). Goes through the same loop protections as `decision: "block"` (`stop_hook_active` input, the 8-consecutive-continuation cap), but the transcript labels it `Stop hook feedback` with no hook error notice shown:

```json
{ "hookSpecificOutput": { "hookEventName": "Stop", "additionalContext": "Please run the test suite before finishing" } }
```

## StopFailure

Fires instead of `Stop` when the turn ends due to an API error. **Output and exit code are ignored** — no decision control; notification/logging only.

**Matcher** — `error` field, e.g. `rate_limit`, `overloaded`, `authentication_failed`, `oauth_org_not_allowed`, `billing_error`, `invalid_request`, `model_not_found`, `server_error`, `max_output_tokens`, `unknown`.

**Input:**

| Field | Description |
| :--- | :--- |
| `error` | Error type (same enum as matcher values) |
| `error_details` | Additional error details, when available |
| `last_assistant_message` | The rendered error text shown in the conversation. Unlike `Stop`/`SubagentStop` (where this holds conversational output), for `StopFailure` it's the API error string itself, e.g. `"API Error: Rate limit reached"` |

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "hook_event_name": "StopFailure",
  "error": "rate_limit",
  "error_details": "429 Too Many Requests",
  "last_assistant_message": "API Error: Rate limit reached"
}
```

## TeammateIdle

Fires when an agent team teammate is about to go idle after finishing its turn. No matcher support.

**Input** — adds `teammate_name`, `team_name`:

```json
{ "session_id": "abc123", "cwd": "/Users/...", "permission_mode": "default", "hook_event_name": "TeammateIdle", "teammate_name": "researcher", "team_name": "session-a1b2c3d4" }
```

| Field | Description |
| :--- | :--- |
| `teammate_name` | Name of the teammate about to go idle |
| `team_name` | Deprecated. Session-derived; will be removed |

**Decision control:** exit code 2 → teammate receives stderr as feedback, continues working instead of going idle. JSON `{"continue": false, "stopReason": "..."}` → stops the teammate entirely, matching `Stop` behavior; `stopReason` shown to the user.

## ConfigChange

Fires when a configuration file changes during a session (settings files, managed policy settings, skill files).

**Matcher** (`source`):

| Matcher | When it fires |
| :--- | :--- |
| `user_settings` | `~/.claude/settings.json` changes |
| `project_settings` | `.claude/settings.json` changes |
| `local_settings` | `.claude/settings.local.json` changes |
| `policy_settings` | Managed policy settings change |
| `skills` | A skill file in `.claude/skills/` changes |

**Input** — adds `source`, optional `file_path`:

```json
{ "session_id": "abc123", "cwd": "/Users/...", "hook_event_name": "ConfigChange", "source": "project_settings", "file_path": "/Users/.../my-project/.claude/settings.json" }
```

**Decision control:**

| Field | Description |
| :--- | :--- |
| `decision` | `"block"` prevents the change from being applied. Omit to allow |
| `reason` | Shown to the user when blocked |

```json
{ "decision": "block", "reason": "Configuration changes to project settings require admin approval" }
```

`policy_settings` changes **can't be blocked** — hooks still fire (for audit logging), but any blocking decision is ignored, so enterprise-managed settings always take effect.

## CwdChanged

Fires when the working directory changes (e.g. Claude executes `cd`). Pairs with `FileChanged` for tools like direnv. No matcher support — fires on every directory change. Has `$CLAUDE_ENV_FILE` access.

**Input** — adds `old_cwd`, `new_cwd`:

```json
{ "session_id": "abc123", "cwd": "/Users/my-project/src", "hook_event_name": "CwdChanged", "old_cwd": "/Users/my-project", "new_cwd": "/Users/my-project/src" }
```

**Output:**

| Field | Description |
| :--- | :--- |
| `watchPaths` | Array of absolute paths. **Replaces** the current dynamic watch list. Paths from `matcher` configuration are always watched. An empty array clears the dynamic list — typical when entering a new directory |

No decision control — can't block the directory change.

## FileChanged

Fires when a watched file changes on disk. Useful for reloading env vars when project config files change. Has `$CLAUDE_ENV_FILE` access.

**Matcher — dual role, doesn't follow the standard matcher-charset rules:**

- **Builds the watch list**: the value is split on `|` and each segment registered as a **literal filename** in the working directory — `".envrc|.env"` watches exactly those two files. Regex is not useful here: a value like `^\.env` watches a file literally named `^\.env`.
- **Filters which hooks run**: when a watched file changes, the same value filters which hook groups run using the standard matcher rules against the changed file's basename.

**Input** — adds `file_path`, `event`:

| Field | Description |
| :--- | :--- |
| `file_path` | Absolute path to the file that changed |
| `event` | `"change"` (modified), `"add"` (created), `"unlink"` (deleted) |

```json
{ "session_id": "abc123", "cwd": "/Users/my-project", "hook_event_name": "FileChanged", "file_path": "/Users/my-project/.envrc", "event": "change" }
```

**Output:**

| Field | Description |
| :--- | :--- |
| `watchPaths` | Array of absolute paths. **Replaces** the current dynamic watch list. Paths from `matcher` are always watched. Use when the hook discovers additional files to watch based on the changed file |

No decision control — can't block the file change.

## WorktreeCreate

Fires when a worktree is being created (`claude --worktree` or a subagent with `isolation: "worktree"`). By default Claude Code uses `git worktree`; configuring this hook **replaces** that default entirely, letting you use SVN, Perforce, Mercurial, etc.

Because the hook replaces default behavior, `.worktreeinclude` is not processed — copy local files like `.env` inside the hook script if needed.

**Input** — adds `name`, a slug identifier for the new worktree (user-specified or auto-generated, e.g. `bold-oak-a3f2`):

```json
{ "session_id": "abc123", "cwd": "/Users/...", "hook_event_name": "WorktreeCreate", "name": "feature-auth" }
```

**Path-return contract:** doesn't use the standard allow/block model — the hook's success/failure and returned path determine the outcome. The hook **must** return the path to the created worktree directory:

- **Command hooks**: print the path as the **last non-empty line of stdout**. Claude Code strips ANSI escape codes before reading that line, so shell startup banners printed before the `echo` are ignored. Redirect other output to stderr.
- **HTTP hooks**: return `{ "hookSpecificOutput": { "hookEventName": "WorktreeCreate", "worktreePath": "/absolute/path" } }` in the response body.

If the hook fails or produces no path, worktree creation fails with an error. Claude Code resolves a relative path against the directory the hook ran in; if the result isn't an enterable directory, the session prints an error and exits with code 1. Before v2.1.205, a relative or nonexistent path crashed the session at startup, and with `-p` it stalled ~30 seconds before exiting with code 0.

```json
{
  "type": "command",
  "command": "bash -c 'NAME=$(jq -r .name); DIR=\"$HOME/.claude/worktrees/$NAME\"; svn checkout https://svn.example.com/repo/trunk \"$DIR\" >&2 && echo \"$DIR\"'"
}
```

## WorktreeRemove

Fires when a worktree is being removed — exiting a `--worktree` session (with removal chosen), or a subagent with `isolation: "worktree"` finishing. Cleanup counterpart to WorktreeCreate.

For git-based worktrees, Claude Code cleans up automatically with `git worktree remove`. If you configured a WorktreeCreate hook for a non-git VCS, pair it with a WorktreeRemove hook — without one, the worktree directory is left on disk.

**Input** — adds `worktree_path` (the absolute path returned by WorktreeCreate):

```json
{ "session_id": "abc123", "cwd": "/Users/...", "hook_event_name": "WorktreeRemove", "worktree_path": "/Users/.../my-project/.claude/worktrees/feature-auth" }
```

No decision control — can't block removal, but can perform cleanup (removing VCS state, archiving changes). Hook failures are logged in debug mode only.

## PreCompact

Fires before a compact operation.

| Matcher | When it fires |
| :--- | :--- |
| `manual` | `/compact` |
| `auto` | Auto-compact when the context window is full |

**Decision control:** exit code 2 blocks compaction (for manual `/compact`, stderr shown to the user); JSON `"decision": "block"` also blocks. Blocking automatic compaction has different effects by trigger timing: if triggered **proactively** before the context limit, Claude Code skips it and the conversation continues uncompacted; if triggered to **recover from a context-limit error already returned by the API**, the underlying error surfaces and the current request fails.

**Input** — adds `trigger`, `custom_instructions`. For `manual`, `custom_instructions` holds what the user passed to `/compact`; for `auto`, it's empty.

```json
{ "session_id": "abc123", "cwd": "/Users/...", "hook_event_name": "PreCompact", "trigger": "manual", "custom_instructions": "" }
```

## PostCompact

Fires after a compact operation completes. Same matcher values as PreCompact (`manual`/`auto`, describing what triggered it).

**Input** — adds `trigger`, `compact_summary` (the conversation summary generated by the compact operation):

```json
{ "session_id": "abc123", "cwd": "/Users/...", "hook_event_name": "PostCompact", "trigger": "manual", "compact_summary": "Summary of the compacted conversation..." }
```

No decision control — can't affect the compaction result, but can perform follow-up tasks.

## SessionEnd

Fires when a session terminates. Useful for cleanup, logging session stats, saving state.

**Matcher** (`reason`):

| Reason | Description |
| :--- | :--- |
| `clear` | Session cleared with `/clear` |
| `resume` | Session switched via interactive `/resume` |
| `logout` | User logged out |
| `prompt_input_exit` | User exited while prompt input was visible |
| `bypass_permissions_disabled` | Bypass permissions mode was disabled |
| `other` | Other exit reasons |

**Input** — adds `reason` (values above):

```json
{ "session_id": "abc123", "cwd": "/Users/...", "hook_event_name": "SessionEnd", "reason": "other" }
```

No decision control — can't block termination, but can perform cleanup.

**Timeout/budget rules:** default timeout is **1.5 seconds**, applying to session exit, `/clear`, and switching sessions via interactive `/resume`. Set a per-hook `timeout` for more time. The overall budget auto-raises to the highest per-hook timeout configured in settings files, **up to 60 seconds** — timeouts on plugin-provided hooks don't raise the budget. Override the budget explicitly with `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (milliseconds):

```bash
CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=5000 claude
```

## Elicitation

Fires when an MCP server requests user input mid-task. By default Claude Code shows an interactive dialog; hooks can intercept and respond programmatically, skipping the dialog. Matcher matches the MCP server name.

**Input** — adds `mcp_server_name`, `message`, optional `mode`, `url`, `elicitation_id`, `requested_schema`.

Form-mode (most common):

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "Elicitation",
  "mcp_server_name": "my-mcp-server",
  "message": "Please provide your credentials",
  "mode": "form",
  "requested_schema": { "type": "object", "properties": { "username": { "type": "string", "title": "Username" } } }
}
```

URL-mode (browser-based auth):

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "Elicitation",
  "mcp_server_name": "my-mcp-server",
  "message": "Please authenticate",
  "mode": "url",
  "url": "https://auth.example.com/login"
}
```

**Output** — respond programmatically without showing the dialog:

```json
{ "hookSpecificOutput": { "hookEventName": "Elicitation", "action": "accept", "content": { "username": "alice" } } }
```

| Field | Values | Description |
| :--- | :--- | :--- |
| `action` | `accept`, `decline`, `cancel` | Whether to accept, decline, or cancel |
| `content` | object | Form field values to submit. Only used when `action` is `accept` |

Exit code 2 denies the elicitation and shows stderr to the user.

## ElicitationResult

Fires after a user responds to an MCP elicitation — hooks can observe, modify, or block the response before it's sent to the server. Matcher matches the MCP server name.

**Input** — adds `mcp_server_name`, `action`, optional `mode`, `elicitation_id`, `content`:

```json
{
  "session_id": "abc123",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "ElicitationResult",
  "mcp_server_name": "my-mcp-server",
  "action": "accept",
  "content": { "username": "alice" },
  "mode": "form",
  "elicitation_id": "elicit-123"
}
```

**Output** — override the user's response:

```json
{ "hookSpecificOutput": { "hookEventName": "ElicitationResult", "action": "decline", "content": {} } }
```

| Field | Values | Description |
| :--- | :--- | :--- |
| `action` | `accept`, `decline`, `cancel` | Overrides the user's action |
| `content` | object | Overrides form field values. Only meaningful when `action` is `accept` |

Exit code 2 blocks the response, changing the effective action to `decline`.
