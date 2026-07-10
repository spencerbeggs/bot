# Plugin Setup — Session Env Doctrine

> House doctrine — not an upstream mirror. Platform contracts live in ../anthropic-docs/references/.

How a plugin's SessionStart hook persists path/identity state so later hooks, skill scripts, and Bash-tool subprocesses can recover it — and the four `hooks/lib/*.sh` templates that implement the reader/writer halves of the pattern.

## Why this exists

`$CLAUDE_ENV_FILE` (the platform's own env-propagation channel — see ../anthropic-docs/references/hooks.md § CLAUDE_ENV_FILE) reaches Bash-tool subprocesses but **not** other hook subprocesses. A `PreToolUse` or `PostToolUse` hook never sees exports a `SessionStart` hook wrote there. This doctrine closes that gap with a second, plugin-owned propagation surface.

## The two propagation surfaces

| Surface | Reaches | Written by | Read by |
| --- | --- | --- | --- |
| `$CLAUDE_ENV_FILE` | Bash-tool subprocesses (auto-sourced by the host) and MCP subprocesses | Producer events only: `SessionStart`, `Setup`, `CwdChanged`, `FileChanged` | Nothing explicit — the host sources it automatically |
| `~/.claude/session-env/<session_id>/<plugin>-hook.sh` | Hook subprocesses (any event) | Same producer events, via the same write | `lib/source-session-env.sh`'s `source_session_env` function, called explicitly at the top of a reader hook |

A producer hook writes the **same exports to both** locations in the same run. Reader hooks that need the state call `source_session_env "$session_id"` after sourcing the lib file — the file does not auto-invoke on source.

## SessionStart producer pattern

Every SessionStart hook in this toolchain persists at least the three canonical paths as namespaced env vars, since direct env inheritance into subshells isn't guaranteed:

- `<PLUGIN>_PROJECT_DIR` — from `$CLAUDE_PROJECT_DIR` (the user's project root)
- `<PLUGIN>_DATA_DIR` — from `$CLAUDE_PLUGIN_DATA` (persists across plugin updates)
- `<PLUGIN>_PLUGIN_ROOT` — from `$CLAUDE_PLUGIN_ROOT` (the currently-active install; useful when a mid-session update rotates the path under `/reload-plugins`)

Plus whatever plugin-specific identity the plugin owns (`<PLUGIN>_SESSION_ID`, `<PLUGIN>_AGENT_ID`, `<PLUGIN>_GH_TOKEN`, etc.).

Condensed shape (full working version lives in the generated plugin at `hooks/session-start/env-export.sh`, authored per-plugin — not one of the four templates):

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/../lib/hook-output.sh"
. "$(dirname "$0")/../lib/hook-debug.sh"

hook_json=$(cat)
session_id=$(jq -r '.session_id // ""' <<< "$hook_json")
project_dir="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<< "$hook_json")}"

env_dir="${HOME}/.claude/session-env/${session_id}"
mkdir -p "$env_dir"
hook_env_file="${env_dir}/myplugin-hook.sh"

{
 printf 'export MYPLUGIN_PROJECT_DIR=%q\n' "$project_dir"
 printf 'export MYPLUGIN_DATA_DIR=%q\n' "${CLAUDE_PLUGIN_DATA:-}"
 printf 'export MYPLUGIN_PLUGIN_ROOT=%q\n' "${CLAUDE_PLUGIN_ROOT:-}"
} > "$hook_env_file"

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
 for var in MYPLUGIN_PROJECT_DIR MYPLUGIN_DATA_DIR MYPLUGIN_PLUGIN_ROOT; do
  grep -q "^export ${var}=" "$CLAUDE_ENV_FILE" 2>/dev/null || \
   grep "^export ${var}=" "$hook_env_file" >> "$CLAUDE_ENV_FILE"
 done
fi

emit_noop
```

## Idempotent grep-guarded writes

`/resume` re-fires `SessionStart` — an ungated `>>` append to `$CLAUDE_ENV_FILE` accumulates duplicate `export` lines across resumes. Guard every write with a `grep -q` check before appending, as in the snippet above. The per-session file (`$hook_env_file`) is safe to overwrite wholesale each run (`>`, not `>>`) since it's scoped to one session; `$CLAUDE_ENV_FILE` is shared across every producer hook in the session (this plugin's and others'), so it must only ever be appended to, and only after the guard.

Use `printf '%q'` for every exported value, never bare interpolation — it safely quotes values containing spaces, quotes, or shell metacharacters so the sourced file can't break or, worse, execute injected content.

## Three-tier consumer fallback

Any script needing the project root resolves it in this order, never by dirname-walking (see `references/layout.md` § The dirname-walking anti-pattern):

1. **Namespaced var** (`<PLUGIN>_PROJECT_DIR`) — survives subshells that don't inherit the parent's env, recovered via `source_session_env`.
2. **Host-set var** (`$CLAUDE_PROJECT_DIR`) — set directly by the host in hook subprocesses and Bash-tool subprocesses; the common case.
3. **Standalone fallback** (`git rev-parse --show-toplevel` or `pwd`) — only for a script invoked outside Claude Code entirely.

```bash
PROJECT_DIR="${MYPLUGIN_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
```

## Lib helper usage contracts

### `hook-output.sh`

Source: `. "$(dirname "$0")/../lib/hook-output.sh"`. No customization needed — generic across plugins.

| Function | Signature | Use when |
| --- | --- | --- |
| `emit_noop` | `emit_noop` | The hook decided not to act; prints `{}` |
| `emit_allow` | `emit_allow [updated_input_json]` | `PreToolUse` approval, with optional `updatedInput` rewrite. Invalid JSON in `$1` falls back to plain allow with a stderr warning rather than silently emitting nothing |
| `emit_deny` | `emit_deny [reason]` | `PreToolUse` denial; `reason` is shown to Claude, not the user |
| `emit_context` | `emit_context <event_name> [ctx]` | Any event accepting `additionalContext`; `event_name` must match the firing event exactly (required first arg) |

### `hook-debug.sh`

Source: `. "$(dirname "$0")/../lib/hook-debug.sh"`. Requires editing `HOOK_LOG_PREFIX` at scaffold time — the default (`unconfigured-plugin`) is deliberately unmemorable so an unedited copy is obvious.

| Function | Signature | Use when |
| --- | --- | --- |
| `hook_error` | `hook_error <hook-name> <message...>` | Always logs to `${XDG_STATE_HOME:-~/.local/state}/<prefix>/hook-error-log.log` (or the `<PREFIX>_HOOK_ERROR_LOG` override) — failures a maintainer needs to see |
| `hook_debug` | `hook_debug <hook-name> <message...>` | Only logs when `<PREFIX>_HOOK_DEBUG=1` — tracing, not failures |

### `source-session-env.sh`

Source: `. "$(dirname "$0")/../lib/source-session-env.sh"`. No customization needed. **Does not auto-invoke on source** — call the function explicitly, and always pass `session_id` explicitly rather than relying on a script-level `$1` (a prior version that read the caller's positional args this way false-fired).

| Function | Signature | Use when |
| --- | --- | --- |
| `source_session_env` | `source_session_env "$session_id"` | At the top of any reader hook (`PreToolUse`, `PostToolUse`, `SubagentStart`, …) needing state a producer event wrote. Validates `session_id` against path-traversal/newline injection before touching the filesystem. Sources every `*hook*.sh` file under the session's env dir, so multiple plugins' exports coexist without filename collision |

### `gh-wrapper.sh`

Source: `. "$(dirname "$0")/../lib/gh-wrapper.sh"`. Requires editing `GH_WRAPPER_TOKEN_VAR` at scaffold time to the plugin's namespaced token var (e.g. `MYPLUGIN_GH_TOKEN`) — the default placeholder warns loudly on every source until changed.

| Function | Signature | Use when |
| --- | --- | --- |
| `_gh` | `_gh <gh-args...>` | Every `gh` invocation, in place of the bare `gh` command — resolves the namespaced token (falling back to `GH_TOKEN`/`GITHUB_TOKEN` for CI), scrubs `GH_PAGER`, and runs fresh |
| `_gh_auth_ok` | `_gh_auth_ok` | Auth checks — disambiguates env-token failures from keyring-success failures by controlling the env at the check site itself, not just downstream calls |

Underlying rationale for the wrapper (stale `GH_TOKEN` overriding keyring, exit-code conflation, check-site/use-site agreement): `shelling-out-from-plugins` skill.
