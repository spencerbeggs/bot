# Plugin Setup — Layout Doctrine

> House doctrine — not an upstream mirror. Platform contracts live in ../anthropic-docs/references/.

The opinionated directory shape the `plugin-setup` skill scaffolds, and the `hook-scripts` / `plugin-manifest` enforcer skills audit against. The layout makes path-based skill triggering trivial because directory names ARE event names.

## Canonical directory tree

```text
<plugin>/
├── .claude-plugin/
│   ├── plugin.json                 manifest — schema: ../anthropic-docs/references/plugins-reference.md
│   └── marketplace.json            optional, for marketplace plugins
├── hooks/
│   ├── hooks.json                  registrations only — matcher + command per event
│   ├── pre-tool-use/               one subdirectory per hook event (kebab-case)
│   │   ├── bash-rewrite.sh
│   │   └── mcp-allowlist.sh
│   ├── post-tool-use/
│   │   ├── record.sh
│   │   └── tdd-artifact.sh
│   ├── session-start/
│   │   ├── env-export.sh
│   │   └── triage-inject.sh
│   ├── session-end/
│   ├── subagent-start/
│   ├── subagent-stop/
│   ├── user-prompt-submit/
│   ├── pre-compact/
│   ├── stop/
│   ├── lib/                        shared helpers — see references/session-env.md
│   │   ├── hook-output.sh          emit_noop, emit_allow, emit_deny, emit_context
│   │   ├── hook-debug.sh           hook_error, hook_debug
│   │   ├── source-session-env.sh   lateral env propagation
│   │   ├── gh-wrapper.sh           _gh() with namespaced-token + GH_PAGER hygiene
│   │   └── (other plugin-specific helpers)
│   └── fixtures/
│       ├── pretooluse.<scenario>.json
│       └── sessionstart.<scenario>.json
├── __test__/                       ALL tests — BATS + vitest side by side
│   ├── pre-tool-use-bash-rewrite.bats
│   └── record.test.ts
├── skills/
│   └── <skill-name>/SKILL.md
├── agents/
│   └── <agent-name>.md
├── commands/
│   └── <command-name>.md
└── bin/                            optional CLI/loader; added to the Bash tool's PATH
    └── start-<server>.sh
```

## Why subdirectory per event

The alternative naming convention some plugins use is `pre-tool-use-bash.sh` (event-kebab + scope suffix at one level). This house layout enforces the subdirectory form (`pre-tool-use/bash.sh`) instead because:

- **Unambiguous globbing.** `**/hooks/pre-tool-use/**/*.sh` matches every PreToolUse hook in any plugin that follows the convention. Path-based skills key off the directory cleanly.
- **No filename collisions.** Two PreToolUse hooks for different matchers don't share a namespace.
- **Room to grow.** A complex hook can become a subdirectory (`pre-tool-use/bash-rewrite/main.sh` + sibling support files) without breaking discovery.
- **Mirrors `hooks.json` structure.** The manifest groups by event; the filesystem now matches it.

## `hooks/hooks.json` registration shape

Each event entry is a list of `{ matcher, hooks: [{ type, command, … }] }` blocks. Reference relative paths under `hooks/<event>/`, always through `${CLAUDE_PLUGIN_ROOT}`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash",
            "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool-use/bash-rewrite.sh"],
            "timeout": 10
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash",
            "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/session-start/env-export.sh"]
          }
        ]
      }
    ]
  }
}
```

Exec form (`args` present) needs no quoting for the path placeholder. Full handler-field contract (`command`/`args`/`async`/`shell`, exec-vs-shell semantics): ../anthropic-docs/references/hooks.md § Command hook fields.

## Helpers in `hooks/lib/`

Every plugin scaffolded by this skill gets the four templates in the inventory table in `SKILL.md`, copied verbatim and namespace-substituted. Hook scripts source them by relative path from their own subdirectory (`. "$(dirname "$0")/../lib/hook-output.sh"`), never inline-reimplemented. Function signatures and sourcing points: `references/session-env.md`.

## Fixtures centralized

All fixtures live at `hooks/fixtures/`, not scattered across per-event subdirectories — one flat directory, named `<event>.<scenario>.json` where `<event>` is the event name lowercased with **no separators**: `pretooluse.rm-guard.json`, `posttooluse.write.json`, `sessionstart.resume.json`. (Not kebab-case — the dot already separates event from scenario, and the hyphen-free event name keeps `ls hooks/fixtures/<event>.*` globs trivial.) This keeps BATS tests portable (one `__test__/` tree, one fixture root) and makes it trivial to spot which scenarios exist for a given event with a single `ls`.

## Tests centralized in `__test__/`

Every test file lives at `<plugin>/__test__/` — BATS suites and vitest unit tests side by side:

- **BATS**: `__test__/<event-kebab>-<name>.bats` per hook script (e.g. `__test__/post-tool-use-record.bats`), run standalone with `bats <plugin>/__test__/*.bats`.
- **Vitest**: `__test__/<name>.test.ts`. Node ≥ 24.11 type-strips, so no build step. The per-plugin vitest project is registered in the repo-root `vitest.config.ts` by the repo owner — the plugin's only obligation is putting files in `__test__/`.

No `tests/`, no `test/`, no specs living next to the scripts they cover.

## `bin/` loaders

Optional. Scripts under `bin/` are added to the Bash tool's `PATH` while the plugin is enabled — invokable as bare commands in any Bash tool call, no `${CLAUDE_PLUGIN_ROOT}` prefix needed at the call site. Use for a plugin-bundled CLI or MCP-server loader script (`start-<server>.sh`). Full component-location table: ../anthropic-docs/references/plugins-reference.md § File locations reference.

## The dirname-walking anti-pattern

Wrong:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"      # walks plugin install, not user project!
DESIGN_DIR="$PROJECT_ROOT/.claude/design"
```

This computes `PROJECT_ROOT` relative to the script's own location. When the plugin is installed normally, the script lives at `~/.claude/plugins/cache/<plugin>/skills/<name>/scripts/<script>.sh`, so `../..` from `scripts/` lands in the plugin install, not the user's project. Works only when a developer happens to run the script from a clone — breaks for every real install.

Right:

```bash
# Prefer the namespaced var set by SessionStart (survives subshells via
# lib/source-session-env.sh). Fall back to CLAUDE_PROJECT_DIR (set by host
# in Bash-tool subprocs and hook subprocs). Fall back to git for standalone
# invocation outside Claude Code.
PROJECT_DIR="${MYPLUGIN_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
DESIGN_DIR="$PROJECT_DIR/.claude/design"
```

Same pattern applies when a script needs its own plugin's files — use `${CLAUDE_PLUGIN_ROOT}`, not dirname-walking. To invoke a sibling skill's bundled binary: `${CLAUDE_PLUGIN_ROOT}/skills/<other>/scripts/<bin>.sh`. Platform contract for the three `${CLAUDE_*}` path vars (stability, when each is set, what each is for): ../anthropic-docs/references/plugins-reference.md § Environment variables.

## Audit signals

When auditing a plugin's layout, flag:

- Hook scripts at `hooks/<event-kebab>-<scope>.sh` (flat naming) — propose migration to the subdirectory form.
- `hooks.json` that registers a hook command not present at the referenced path.
- Bare relative paths in `hooks.json` (no `${CLAUDE_PLUGIN_ROOT}`).
- Helpers living in `hooks/` root that should live in `hooks/lib/`.
- Fixtures scattered across per-event subdirectories — should be centralized under `hooks/fixtures/`.
- Fixture names with hyphens in the event segment (`pre-tool-use.<scenario>.json`) — should be the separator-free form (`pretooluse.<scenario>.json`).
- Test files under `tests/`, `test/`, or next to the scripts they cover — should be centralized under `__test__/`.
- `mcpServers` entry where `command` and `args` together don't reference `${CLAUDE_PLUGIN_ROOT}` — relative loader paths break under unusual cwd.
- A script computing `PROJECT_ROOT`/`PLUGIN_ROOT` by dirname-walking instead of using the env vars with namespaced fallback.
