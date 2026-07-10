---
name: hook-scripts
description: Enforces the house hook-script contract when a `hooks/**/*.sh`, `hooks/**/*.bash`, or `hooks/hooks.json` file is opened for authoring or review — envelope/exit-code/JSON discipline, subdirectory-per-event layout, lib helpers, fixtures, and BATS coverage.
user-invocable: false
paths:
  - "**/hooks/**/*.sh"
  - "**/hooks/**/*.bash"
  - "**/hooks/hooks.json"
---

# Hook script checklist

Apply this to the file you just opened. The mistake that matters most: `exit 1` to block a tool call — it doesn't block, it's a non-blocking error. Blocking requires `exit 2`. The second: writing state under `${CLAUDE_PLUGIN_ROOT}` — that directory is ephemeral on plugin update.

## Checklist

1. **Path is `hooks/<event-kebab>/<name>.sh`**, not flat `hooks/<event-kebab>-<name>.sh`. Subdirectory-per-event is the house layout — it makes `**/hooks/pre-tool-use/**/*.sh`-style globs unambiguous and lets sibling path-skills key off the directory name.
2. **`set -euo pipefail`** present; fails open (not exit 2) when `jq` is missing — a hook that can't parse its envelope should not block the user.
3. **Sources shared helpers from `hooks/lib/`** (`hook-output.sh` for `emit_noop`/response emitters, `hook-debug.sh` for `hook_error`/`hook_debug`, `source-session-env.sh` for lateral env) rather than reimplementing them inline.
4. **Exit-code discipline**: any `exit 1` intended to block is wrong — use `exit 2`. Any silent `exit 1` should be `emit_noop; exit 0` instead.
5. **Decision via JSON, process always exits 0 on the happy path.** The house convention: emit a JSON response object (or plain-text context where the event accepts it) and let exit 0 carry it. Reserve non-zero exits for genuine block (`2`) or non-blocking error (`1`) signaling, not as the primary decision channel.
6. **`hookSpecificOutput.hookEventName` set whenever `hookSpecificOutput` is populated** — required, validated against the firing event.
7. **No `cmd || true` followed by a `$?` check** — dead code, `true` always succeeds. Capture with `out=$(cmd 2>&1) || rc=$?`.
8. **Plugin-owned paths use `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}`, never dirname-walking or bare relative paths.** State/cache/logs go in `${CLAUDE_PLUGIN_DATA}`, not the plugin install. The data dir resolves to `~/.claude/plugins/data/<plugin>-<marketplace>/` (e.g. `dogfood-inline`), NOT `~/.claude/plugins/data/<plugin>/` — never write the bare-plugin-name path into a fallback or comment.
9. **Third-party CLI calls (`gh`, `aws`, `kubectl`, …) reviewed against `shelling-out-from-plugins`** — env hygiene at every call site, not just the auth check.
10. **BATS coverage exists.** Every hook script has at least one fixture at `hooks/fixtures/<event>.<scenario>.json` — `<event>` lowercased, no separators (e.g. `posttooluse.write.json`, not `post-tool-use.write.json`) — and a `__test__/<event-kebab>-<name>.bats` at the plugin root asserting the happy path and the no-op path.
11. **In `hooks.json`, every `command` is quoted and anchored to `${CLAUDE_PLUGIN_ROOT}`** — bare relative paths break once the plugin is invoked from outside its own directory.
12. **Prefer exec form (`args` array) over shell form for any registration referencing a path placeholder.** Exec form needs no quoting for spaces/special characters; shell form requires wrapping each placeholder in double quotes. Reserve shell form for pipes/`&&`/redirects.

## Per-event pointer table

Read `hooks.md` for system-wide rules that apply to every event; read `hook-events.md` for the specific event's input/output schema. Group first, then follow the row:

| Event group | Events | Read in `hook-events.md` |
| --- | --- | --- |
| Session lifecycle | `SessionStart`, `Setup`, `InstructionsLoaded`, `SessionEnd` | matching `##` heading; also `hooks.md` § CLAUDE_ENV_FILE — these are the only events (plus CwdChanged/FileChanged) that can export env for later Bash subprocs |
| Prompt / display | `UserPromptSubmit`, `UserPromptExpansion`, `MessageDisplay` | matching `##` heading |
| Tool-use control | `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `PermissionDenied` | matching `##` heading; also `hooks.md` § Decision-control summary and § Rewrite capabilities |
| Subagent | `SubagentStart`, `SubagentStop` | matching `##` heading; also `hooks.md` § Hooks in skills and agents |
| Task | `TaskCreated`, `TaskCompleted` | matching `##` heading |
| Turn end | `Stop`, `StopFailure`, `TeammateIdle` | matching `##` heading |
| Environment change | `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove` | matching `##` heading; also `hooks.md` § CLAUDE_ENV_FILE |
| Compaction | `PreCompact`, `PostCompact` | matching `##` heading |
| Elicitation | `Elicitation`, `ElicitationResult` | matching `##` heading |
| Notification | `Notification` | matching `##` heading |

For matcher syntax, handler types (`command`/`http`/`mcp_tool`), and the exit-code contract itself, read `hooks.md` regardless of event — those are shared, not per-event.

## Subagent-hook gotcha

Under `context: fork`, Claude Code **reuses the parent's `session_id`** — a `SubagentStart`/`SubagentStop` hook that keys storage on `session_id` alone collides across dispatches. House fix: at `SubagentStart`, mint a synthetic per-dispatch key (`${session_id}-subagent-$(date +%s)-$$`) and persist an `agent_id → key` mapping (state file). `SubagentStop` payloads carry only `agent_type`/`agent_id`, never the synthetic key, so `SubagentStop` must look the key up via that mapping, not regenerate it.

## Common mistakes

- `exit 1` to block — doesn't block, use `exit 2`.
- Empty stdout instead of an explicit `emit_noop` — both work, but `emit_noop` survives schema tightening.
- `permissionDecision: "block"` — not a valid value, it's `"deny"`.
- Helper logic written inline in the hook body instead of `hooks/lib/<helper>.sh`.
- `export FOO=bar` expecting a later Bash-tool call to see it — only `SessionStart`/`Setup`/`CwdChanged`/`FileChanged` writes to `$CLAUDE_ENV_FILE` propagate; everything else needs `lib/source-session-env.sh`.
- `SessionStart` writing to `$CLAUDE_ENV_FILE` without a grep guard — `/resume` re-fires `SessionStart`, so ungated `export` lines accumulate duplicates. Guard every write: `grep -q "^export FOO=" "$CLAUDE_ENV_FILE" 2>/dev/null || printf 'export FOO=%q\n' "$val" >> "$CLAUDE_ENV_FILE"`.
- MCP `tool_response` treated as a single object in `PostToolUse` — it's an array.

## Read for the full contract

- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/hooks.md` — locations, matcher rules, handler types, exit-code contract, JSON output fields, `CLAUDE_ENV_FILE`, async hooks, debugging.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/hook-events.md` — per-event input/output schema, matcher values, decision-control fields.

Scaffolding a new plugin or retrofitting the layout and `hooks/lib/` helpers? Invoke the `plugin-setup` skill — it ships the tested lib templates and the bootstrap checklist.
