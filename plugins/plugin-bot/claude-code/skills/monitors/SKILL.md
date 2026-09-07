---
name: monitors
description: Use when authoring, auditing, or registering a Claude Code plugin monitor — a monitors/monitors.json entry or the background watch script it runs. Ships the typed TypeScript poll-monitor harness (self-scheduling loop, stable-streak debounce, notify-once dedup, --once mode) plus the registration rules and notification-copy doctrine; auto-loads as the enforcer when a monitors/ file is opened.
paths:
  - "**/monitors/monitors.json"
  - "**/monitors/**/*.ts"
  - "**/monitors/**/*.mts"
  - "**/monitors/**/*.js"
  - "**/monitors/**/*.mjs"
---

# Monitors

House style for plugin monitors: background processes Claude Code starts automatically while the plugin is active, whose every stdout line lands in the session as a notification. Monitors are experimental and need Claude Code v2.1.105+; the platform contract (fields, `when:` values, substitution variables, constraints) is `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/plugins-reference.md` § Monitors — this skill builds on it, it doesn't restate it.

Monitors are written in TypeScript and run directly with `node script.ts` — the environment contract (see `plugin-setup`) guarantees Node ≥ 24.11 with native type stripping, so there is no build step. Consequence: relative imports in monitor code use the real `.ts` extension (`./lib/poll-monitor.ts`) — type stripping does not rewrite specifiers, so an emitted-`.js` specifier crashes at runtime with `ERR_MODULE_NOT_FOUND` even though vitest would happily resolve it. In repos whose Biome config enforces `forceJsExtensions`, the `**/monitors/**` and `**/__test__/**` globs carry a documented override (see this repo's `biome.jsonc`).

## Bootstrap workflow

1. **Copy the harness verbatim**: `${CLAUDE_PLUGIN_ROOT}/skills/monitors/templates/monitors/lib/poll-monitor.ts` → `<plugin>/monitors/lib/poll-monitor.ts`. Never customize it and never reimplement the loop, debounce, or dedup inline in a monitor script.
2. **Write the monitor** at `<plugin>/monitors/watch-<thing>.ts`, starting from `templates/monitors/watch-example.ts`: a sample type, a `scan()` holding ALL the I/O, and the four pure handlers (`key`, `fingerprint`, `isClear`, `notify`). Namespace every env knob `<PLUGIN>_<MONITOR>_*`.
3. **Register it** in `<plugin>/monitors/monitors.json` (start from `templates/monitors/monitors.json`): unique `name`, mandatory `description`, and a shell-form `command` — quote the placeholder, `node "${CLAUDE_PLUGIN_ROOT}/monitors/watch-<thing>.ts"`. Choose `when:` deliberately: `always` (default) for project-state watches, `on-skill-invoke:<skill>` for watches only relevant once a workflow starts.
4. **Test it** at `<plugin>/__test__/watch-<thing>.test.ts` (vitest, from `templates/__test__/watch-example.test.ts`): drive the exported handlers through the pure `debounceStep` — assert the hold-back, the notify-once, and the clear-then-regress re-fire. No BATS for monitors.
5. **Verify live**: `node <plugin>/monitors/watch-<thing>.ts --once` prints current findings immediately (no quiet period) and exits. Then `claude plugin validate <plugin> --strict`. A new or edited monitor needs a session restart to pick up — `/reload-plugins` alone does not restart monitors.

## Checklist

Apply to any monitor script or `monitors.json` you have open:

1. **The script uses the shared harness** (`monitors/lib/poll-monitor.ts`) — a hand-rolled `setInterval`, inline debounce, or inline dedup is a defect, not a style choice. `setInterval` overlaps ticks and corrupts debounce state; the harness's self-scheduling loop is the fix.
2. **`scan()` owns all I/O; the four handlers are pure.** Anything filesystem/network-touching inside `key`/`fingerprint`/`isClear`/`notify` breaks testability through `debounceStep`.
3. **Partial reads are skipped, not thrown** — a JSON artifact mid-write fails parse; omit the sample and let the next poll retry.
4. **The loop is guarded by `invokedDirectly(import.meta.url)`** so tests can import the handlers without starting a poll. The harness's realpath comparison handles symlinked plugin roots — don't replace it with a naive `argv[1]` equality.
5. **stdout discipline**: stdout is the notification channel — every line printed is injected into the session. Debug output goes to stderr, never stdout. No banners, no startup messages, no progress lines.
6. **Notification copy is agent-directed**: one line, self-contained, names the action to take AND the hold-back condition for when not to act. Read `references/notification-copy.md` — Load when: writing or reviewing a `notify` handler's line, or considering a stream/tail monitor.
7. **Debounce is on**: `stablePolls` ≥ 1 for any `when: always` monitor watching build artifacts or agent-mutated state, read from a namespaced env var (`<PLUGIN>_<MONITOR>_STABLE_POLLS`) so users can tune or zero it.
8. **Project paths resolve as `CLAUDE_PROJECT_DIR ?? cwd`**; plugin-owned paths use `${CLAUDE_PLUGIN_ROOT}`; anything persisted goes in `${CLAUDE_PLUGIN_DATA}` (mind the `<plugin>-<marketplace>` directory suffix). Never dirname-walk.
9. **`monitors.json` commands are shell form — quote the placeholder**: `node "${CLAUDE_PLUGIN_ROOT}/monitors/<script>.ts"`. Monitors have no exec form; an unquoted `${CLAUDE_PLUGIN_ROOT}` breaks on paths with spaces.
10. **`name` is unique within the plugin and `description` is present** — `name` is the dedup key that prevents duplicate processes on reload; `description` is what the task panel and notification summaries show.
11. **Vitest coverage exists** in `<plugin>/__test__/` asserting at minimum: hold-back until stable, notify-once per stable value, re-fire after clear-then-regress.
12. **Platform constraints acknowledged where they matter**: monitors run only in interactive CLI sessions (never rely on one for correctness in headless runs), run unsandboxed at hook trust level, keep running after the plugin is disabled mid-session, and keep the OLD `${CLAUDE_PLUGIN_ROOT}` after a mid-session plugin update until session restart.

## Template inventory

| Template | Provides | Copy destination |
| --- | --- | --- |
| `templates/monitors/lib/poll-monitor.ts` | `runPollMonitor`, `debounceStep`, `invokedDirectly`, the option/handler types | `<plugin>/monitors/lib/poll-monitor.ts` (verbatim) |
| `templates/monitors/watch-example.ts` | Worked exemplar: sample type + `scan()` + handlers + entrypoint guard | `<plugin>/monitors/watch-<thing>.ts` (adapt) |
| `templates/monitors/monitors.json` | Registration exemplar with quoted shell-form command | `<plugin>/monitors/monitors.json` (adapt) |
| `templates/__test__/watch-example.test.ts` | Handler tests through `debounceStep` — hold-back, dedup, re-fire | `<plugin>/__test__/watch-<thing>.test.ts` (adapt) |

The template tree mirrors the destination tree, so relative imports survive the copy unchanged and the templates themselves stay testable in place.

## What this skill is not

Not the platform contract for the `monitors.json` schema or the Monitor tool (that's `anthropic-docs`). Not hook guidance — a monitor pushes notifications on its own schedule; if the trigger is a tool call or session event, you want a hook (`hook-scripts`), not a monitor. Not for one-off watches an agent starts manually with the Monitor tool.
