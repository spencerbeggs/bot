---
name: plugin-setup
description: Use when scaffolding a brand-new Claude Code plugin, retrofitting the house directory layout and hooks/lib helpers into an existing plugin that doesn't yet follow it, or bootstrapping hooks infrastructure (hooks.json registrations, fixtures, BATS coverage) for a plugin that has none. Ships the bootstrap checklist plus the tested hooks/lib/*.sh templates (hook-output.sh, hook-debug.sh, source-session-env.sh, gh-wrapper.sh).
---

# Plugin Setup

The one skill that walks a plugin from nothing (or from a non-conforming layout) to the house shape: `.claude-plugin/plugin.json`, subdirectory-per-event `hooks/`, shared `hooks/lib/` helpers, centralized `hooks/fixtures/`, and BATS coverage. Invoke it directly — user or model — whenever the task is "scaffold a new plugin" or "this plugin doesn't have the house hooks scaffolding yet."

## Bootstrap workflow

Work the checklist top to bottom. Steps 4–5 repeat per hook script.

1. **Create the manifest.** `.claude-plugin/plugin.json` with at minimum `name` + `description`. Don't hand-bump `version` if this repo's CI manages it — see the `plugin-manifest` skill (auto-loads on `plugin.json`).
2. **Lay out component directories** per the canonical tree. Read `references/layout.md` first — it's the full doctrine, including the subdirectory-per-event rationale and the dirname-walking anti-pattern.
3. **Copy the lib templates the plugin's hook set actually needs** from `${CLAUDE_PLUGIN_ROOT}/skills/plugin-setup/templates/hooks/lib/` into `<target-plugin>/hooks/lib/` verbatim, then substitute the `<PLUGIN>_` namespace prefix per each script's own header comment:
   - `hook-output.sh` and `hook-debug.sh` — always; every hook script sources both. In `hook-debug.sh`, edit `: "${HOOK_LOG_PREFIX:=unconfigured-plugin}"` to the plugin's short name. `hook-output.sh` needs no customization.
   - `source-session-env.sh` — only when the plugin has a `SessionStart` producer whose exports a later hook reads back (see `references/session-env.md`). No producer, no copy.
   - `gh-wrapper.sh` — only when a script shells out to `gh`. Edit `: "${GH_WRAPPER_TOKEN_VAR:=UNCONFIGURED_PLUGIN_GH_TOKEN}"` to the plugin's namespaced token var (e.g. `MYPLUGIN_GH_TOKEN`).

   An unused helper is dead code the next audit flags, not forward-looking scaffolding — scope the copy.
4. **Author the hook scripts** under `hooks/<event-kebab>/<name>.sh`, sourcing the lib helpers via relative paths (`. "$(dirname "$0")/../lib/hook-output.sh"`). Write the BATS test FIRST — RED, then implement, then GREEN.
5. **Register hooks in `hooks/hooks.json`** using exec form (`args` array) whenever the command references a path placeholder — no quoting needed for spaces/special characters. Reserve shell form for pipes/`&&`/redirects.
6. **Create fixtures + BATS tests.** One envelope per scenario at `hooks/fixtures/<event>.<scenario>.json`, where `<event>` is the event name lowercased with no separators (`posttooluse.write.json`, `sessionstart.resume.json`). One `__test__/<event-kebab>-<name>.bats` per script asserting the happy path and the no-op path.
7. **Validate.** `claude plugin validate <path> --strict` before calling the plugin done — `--strict` promotes manifest warnings to errors that non-strict mode lets slide.

## Environment contract

Assume these hold; do not probe for them or scaffold detection around them.

**Authoring environment (this repo):**

- `jq` and `bats` are installed and on `PATH`.
- Node.js ≥ 24.11 (type stripping is native) — `node file.ts` runs TypeScript directly; never add a compile step for plugin scripts or tests.
- Vitest is wired once at the repo root (`vitest.config.ts` via `@vitest-agent/plugin`), one project per plugin. Registering a new plugin's project there is the repo owner's job — just put `*.test.ts` files in `<plugin>/__test__/` and don't create per-plugin vitest configs.

**Runtime environment (hosts running a shipped plugin):**

- Node.js ≥ 24.11 — plugin-bundled scripts may ship as `.ts` and be invoked as `node script.ts`.
- `jq` is expected but not guaranteed — every hook script fails open without it (`hook-scripts` checklist item 2), never blocks.

## Template inventory

| Template | Provides | Copy destination |
| --- | --- | --- |
| `hook-output.sh` | `emit_noop`, `emit_allow`, `emit_deny`, `emit_context` — the four JSON response emitters | `<plugin>/hooks/lib/hook-output.sh` |
| `hook-debug.sh` | `hook_error` (always logs), `hook_debug` (gated by `<PREFIX>_HOOK_DEBUG`) | `<plugin>/hooks/lib/hook-debug.sh` |
| `source-session-env.sh` | `source_session_env` — lateral env-propagation reader for non-producer hooks | `<plugin>/hooks/lib/source-session-env.sh` |
| `gh-wrapper.sh` | `_gh`, `_gh_auth_ok` — env-hygiene wrapper around the `gh` CLI | `<plugin>/hooks/lib/gh-wrapper.sh` |

Full function signatures, sourcing points, and the SessionStart producer pattern these readers pair with live in `references/session-env.md`.

## Pointers

- **Directory layout, `hooks.json` registration shape, dirname-walking anti-pattern, audit signals** → `references/layout.md`.
- **Env-var propagation doctrine** (SessionStart producer pattern, the two propagation surfaces, idempotent writes, consumer fallback order, per-helper usage contracts) → `references/session-env.md`.
- **Platform contracts** (hook event schemas, manifest schema, the three `${CLAUDE_*}` path vars, subagent frontmatter) → `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/`. This skill scaffolds *against* that contract — it doesn't restate it.

## What this skill is not

Not a per-event hook-writing tutorial (that's `hook-scripts`, which auto-loads on `hooks/**/*.sh`). Not a manifest field reference (that's `plugin-manifest`, auto-loads on `plugin.json`). Not the platform doc mirror (that's `anthropic-docs`).
