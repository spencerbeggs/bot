---
name: plugin-setup
description: Use when scaffolding a brand-new agent plugin for Claude Code, GitHub Copilot, or both, retrofitting the house target-workspace layout into a plugin that predates it, or bootstrapping hooks infrastructure (hooks.json registrations, fixtures, BATS coverage) for a plugin that has none. Covers the plugins/<plugin>/<target>/ shape, the per-target release plumbing a scaffolded plugin needs before it can ship (tracking package, workspace glob, versionFiles, marketplace entry, port ledger), the bats-placement rule, and the bundled hooks/lib/*.sh templates (hook-output.sh, hook-debug.sh, source-session-env.sh, gh-wrapper.sh).
---

# Plugin Setup

Walks a plugin from nothing (or from a non-conforming layout) to the house shape: one **target workspace** per host, the manifest that host reads, subdirectory-per-event `hooks/`, shared `hooks/lib/` helpers, centralized fixtures, BATS coverage, and the release plumbing that makes it shippable. Invoke it directly — user or model — whenever the task is "scaffold a new plugin" or "this plugin doesn't have the house scaffolding yet."

## Decide the target set first

Every component lives inside a directory named exactly `claude-code` or `copilot`; that name is the only thing telling a later reader which host's contract governs the file. Pick the shape before creating anything:

- One plugin in the repo → `plugins/<target>/`
- More than one → `plugins/<plugin>/<target>/`

Scaffold a second target only when you intend to ship it. Full doctrine, both trees, and the audit signals: `references/layout.md`.

## Bootstrap workflow

Steps 1–8 run per target workspace. Steps 5–6 repeat per hook script.

1. **Create the workspace** at `plugins/<plugin>/<target>/` and the manifest inside it: `.claude-plugin/plugin.json` for `claude-code`, root `plugin.json` for `copilot`. Minimum `name` + `description`. Don't hand-bump `version` if CI manages it — see `plugin-manifest` (auto-loads on `plugin.json`).
2. **Lay out component directories** per the canonical tree in `references/layout.md`. Copilot agents need the `.agent.md` suffix; Copilot's `hooks.json` sits at the workspace root, not under `hooks/`.
3. **Copy the lib templates the plugin's hook set actually needs** from `${CLAUDE_PLUGIN_ROOT}/skills/plugin-setup/templates/hooks/lib/` into `<workspace>/hooks/lib/` verbatim, then substitute the `<PLUGIN>_` namespace prefix per each script's own header comment:
   - `hook-output.sh` and `hook-debug.sh` — always; every hook script sources both. In `hook-debug.sh`, edit `: "${HOOK_LOG_PREFIX:=unconfigured-plugin}"` to the plugin's short name. `hook-output.sh` needs no customization.
   - `source-session-env.sh` — only when the plugin has a `SessionStart` producer whose exports a later hook reads back (see `references/session-env.md`). No producer, no copy.
   - `gh-wrapper.sh` — only when a script shells out to `gh`. Edit `: "${GH_WRAPPER_TOKEN_VAR:=UNCONFIGURED_PLUGIN_GH_TOKEN}"` to the plugin's namespaced token var (e.g. `MYPLUGIN_GH_TOKEN`).

   An unused helper is dead code the next audit flags, not forward-looking scaffolding — scope the copy.
4. **Resolve paths through the portable chains, never by dirname-walking.** A bundled script gets its plugin root from `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-${MYPLUGIN_PLUGIN_ROOT:-}}}"` and the project root from `"${MYPLUGIN_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"`. Rationale, the no-shared-spelling argument, and the shell-vs-manifest layer split: `references/layout.md` § The dirname-walking anti-pattern.
5. **Author the hook scripts** under `hooks/<event-kebab>/<name>.sh`, sourcing the lib helpers via relative paths (`. "$(dirname "$0")/../lib/hook-output.sh"`). Write the BATS test FIRST — RED, then implement, then GREEN.
6. **Register hooks** in the target's `hooks.json` using exec form (`args` array) whenever the command references a path placeholder — no quoting needed for spaces or special characters. Reserve shell form for pipes/`&&`/redirects. Copilot's file is a different schema, not a relocated one (`references/layout.md` § Canonical tree).
7. **Create fixtures + BATS tests.** One envelope per scenario at `hooks/fixtures/<event>.<scenario>.json`, where `<event>` is the event name lowercased with no separators (`posttooluse.write.json`, `sessionstart.resume.json`). One `__test__/<event-kebab>-<name>.bats` per script asserting the happy path and the no-op path.
8. **Validate.** `claude plugin validate <workspace> --strict` — `--strict` promotes manifest warnings to errors that non-strict mode lets slide.

## Release plumbing — the plugin is not finished without it

A scaffolded workspace runs from a local checkout the moment step 8 passes, and is still undistributable. Per **distributed** target workspace:

1. **Tracking `package.json`** in the workspace root, named `@<plugin-name>/<target>-plugin`, `"private": true`, **no `publishConfig`**. It publishes nothing; it exists to give changesets something to version so the manifest is bumped, tagged and released in lockstep. A workspace with no `package.json` is undistributed by design — that is a legitimate state, not an omission.
2. **Workspace glob** in `pnpm-workspace.yaml` covering the depth you chose (`plugins/*/*` for the multi-plugin shape, `plugins/*` for the single-plugin one).
3. **`versionFiles` entry** in `.changeset/config.json`, keyed by the tracking package's name, whose `glob` points at that target's manifest and whose `paths` names the version field. Without it the package version moves and the manifest silently does not.
4. **Marketplace entry** in the manifest the target's host reads, with `source.path` pointing at the workspace directory.
5. **Port ledger and drift suite**, once a second target exists: the `porting-to-copilot` skill owns `port-status.json` and the `--check`/`--record` cycle. A green check means every ported skill and agent is current, not that the port is complete.

## Test placement

Host-agnostic claims — layout, naming, the plumbing above — go in `plugins/__test__/`. Host-specific claims go in `plugins/<plugin>/<target>/__test__/`. `bats --recursive plugins` collects every level with no per-suite registration, so adding a file is the whole of adding a test. Rationale and the failure mode: `references/layout.md` § Test placement.

## Environment contract

Assume these hold; do not probe for them or scaffold detection around them.

**Authoring environment (this repo):**

- `jq` and `bats` are installed and on `PATH`.
- Node.js ≥ 24.11 (type stripping is native) — `node file.ts` runs TypeScript directly; never add a compile step for plugin scripts or tests.
- Vitest is wired once at the repo root (`vitest.config.ts` via `@vitest-agent/plugin`), one project per plugin. Registering a new plugin's project there is the repo owner's job — just put `*.test.ts` files in the workspace's `__test__/` and don't create per-plugin vitest configs.

**Runtime environment (hosts running a shipped plugin):**

- Node.js ≥ 24.11 — plugin-bundled scripts may ship as `.ts` and be invoked as `node script.ts`.
- `jq` is expected but not guaranteed — every hook script fails open without it (`hook-scripts` checklist item 2), never blocks.

## Template inventory

| Template | Provides | Copy destination |
| --- | --- | --- |
| `hook-output.sh` | `emit_noop`, `emit_allow`, `emit_deny`, `emit_context` — the four JSON response emitters | `<workspace>/hooks/lib/hook-output.sh` |
| `hook-debug.sh` | `hook_error` (always logs), `hook_debug` (gated by `<PREFIX>_HOOK_DEBUG`) | `<workspace>/hooks/lib/hook-debug.sh` |
| `source-session-env.sh` | `source_session_env` — lateral env-propagation reader for non-producer hooks | `<workspace>/hooks/lib/source-session-env.sh` |
| `gh-wrapper.sh` | `_gh`, `_gh_auth_ok` — env-hygiene wrapper around the `gh` CLI | `<workspace>/hooks/lib/gh-wrapper.sh` |

Two of these are Claude Code shaped, not host-neutral. `hook-output.sh` emits the `hookSpecificOutput` wrapper, which Copilot's hook output schemas do not use — a `copilot/` workspace needs re-authored emitters, not this file. `source-session-env.sh` implements the `$CLAUDE_ENV_FILE` gap-closing pattern, which is a Claude Code channel. `hook-debug.sh` and `gh-wrapper.sh` are ordinary bash and port unchanged.

Every variable these templates read — `HOOK_LOG_PREFIX`, `GH_WRAPPER_TOKEN_VAR`, `<PREFIX>_HOOK_DEBUG` — is read from the script's process environment. A bundled `.sh` is never passed through a host substitution pass, so setting one of them as a `${…}` placeholder in a manifest sets nothing.

Full function signatures, sourcing points, and the SessionStart producer pattern these readers pair with live in `references/session-env.md`.

## Pointers

- **Target-workspace shape, canonical trees, `hooks.json` registration, dirname-walking anti-pattern, test placement, audit signals** → `references/layout.md`.
- **Env-var propagation doctrine** (SessionStart producer pattern, the two propagation surfaces, idempotent writes, consumer fallback order, per-helper usage contracts) → `references/session-env.md`.
- **Claude Code contracts** (hook event schemas, manifest schema, the `${CLAUDE_*}` path vars, subagent frontmatter) → `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/`.
- **Copilot contracts** (manifest fields and search order, hook events, handler types, output schemas) → `${CLAUDE_PLUGIN_ROOT}/skills/copilot-docs/references/`.
- **Cross-host placeholder matrix** → `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/cross-client-behavior.md`.

This skill scaffolds *against* those contracts — it doesn't restate them.

## What this skill is not

Not a per-event hook-writing tutorial (that's `hook-scripts`, auto-loads on `hooks/**/*.sh`). Not a manifest field reference (that's `plugin-manifest`, auto-loads on `plugin.json`). Not the porting procedure (that's `porting-to-copilot`). Not the platform doc mirrors (`anthropic-docs`, `copilot-docs`, `agent-plugins-docs`).
