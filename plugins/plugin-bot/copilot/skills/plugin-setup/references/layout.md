# Plugin Setup — Layout Doctrine

> House doctrine — not an upstream mirror. Platform contracts live in the `anthropic-docs` skill's `references/`, the `copilot-docs` skill's `references/` and the `agent-plugins-docs` skill's `references/`.

The opinionated directory shape the `plugin-setup` skill scaffolds, and the `hook-scripts` / `plugin-manifest` enforcer skills audit against. Two layers: **where the target workspaces sit** under `plugins/`, and **what one target workspace contains**.

## Target workspaces

Every plugin component lives inside a *target workspace* — a directory named exactly `claude-code` or `copilot`. Two shapes, chosen by how many plugins the repo ships:

```text
plugins/claude-code/            single-plugin repo
plugins/copilot/

plugins/<plugin>/claude-code/   multi-plugin repo
plugins/<plugin>/copilot/
```

**The target-workspace directory name is the context signal.** An agent that sees `claude-code` or `copilot` in a path knows which host's contract governs the file before opening it — which manifest schema, which hook event names, which placeholder vocabulary. Nothing else in the tree carries that signal, which is why component directories never sit directly under `plugins/<plugin>/`: a `skills/` there would belong to no host in particular.

Start single-target. Add `copilot/` only when you actually intend to ship it; an empty second workspace is a promise the port ledger will hold you to.

## Canonical tree, per target

```text
plugins/<plugin>/
├── claude-code/
│   ├── .claude-plugin/plugin.json      manifest — the `anthropic-docs` skill's `references/plugins-reference.md`
│   ├── package.json                    @<plugin>/claude-code-plugin, private, no publishConfig
│   ├── hooks/
│   │   ├── hooks.json                  registrations only — PascalCase event names
│   │   ├── pre-tool-use/               one subdirectory per hook event (kebab-case)
│   │   │   ├── bash-rewrite.sh
│   │   │   └── mcp-allowlist.sh
│   │   ├── post-tool-use/
│   │   ├── session-start/
│   │   ├── user-prompt-submit/
│   │   ├── lib/                        shared helpers — see references/session-env.md
│   │   │   ├── hook-output.sh          emit_noop, emit_allow, emit_deny, emit_context
│   │   │   ├── hook-debug.sh           hook_error, hook_debug
│   │   │   ├── source-session-env.sh   lateral env propagation
│   │   │   └── gh-wrapper.sh           _gh() with namespaced-token + GH_PAGER hygiene
│   │   └── fixtures/
│   │       ├── pretooluse.<scenario>.json
│   │       └── sessionstart.<scenario>.json
│   ├── skills/<skill-name>/SKILL.md
│   ├── agents/<agent-name>.md
│   ├── commands/<command-name>.md
│   ├── bin/                            optional; added to the Bash tool's PATH
│   └── __test__/                       host-specific tests, BATS + vitest side by side
└── copilot/
    ├── plugin.json                     manifest at the workspace root, not under a dot-dir
    ├── package.json                    @<plugin>/copilot-plugin, private, no publishConfig
    ├── hooks.json                      at the root; camelCase event names, flat output
    ├── hooks/
    ├── skills/<skill-name>/SKILL.md
    ├── agents/<agent-name>.agent.md    the `.agent.md` suffix is load-bearing
    ├── __test__/
    └── port-status.json                the port ledger — porting-to-copilot skill
```

The two manifest locations are not interchangeable: Claude Code reads `.claude-plugin/plugin.json`, Copilot searches four locations in its own order (the `copilot-docs` skill's `references/plugin-reference.md` § Manifest search order). `plugins/__test__/canonical-layout.bats` pins one per target workspace.

Copilot's `hooks.json` is a different schema, not a relocated one: `bash`/`powershell`/`command`/`exec`+`args` handler fields, camelCase event names, and **flat** output objects with no `hookSpecificOutput` wrapper (the `copilot-docs` skill's `references/hooks-reference.md` § Handler types, § Output schemas). Port it by re-authoring, never by copying.

## Why subdirectory per event

The alternative naming convention some plugins use is `pre-tool-use-bash.sh` (event-kebab + scope suffix at one level). This house layout enforces the subdirectory form (`pre-tool-use/bash.sh`) instead because:

- **Unambiguous globbing.** `**/hooks/pre-tool-use/**/*.sh` matches every PreToolUse hook in any plugin that follows the convention. Path-based skills key off the directory cleanly.
- **No filename collisions.** Two PreToolUse hooks for different matchers don't share a namespace.
- **Room to grow.** A complex hook can become a subdirectory (`pre-tool-use/bash-rewrite/main.sh` + sibling support files) without breaking discovery.
- **Mirrors `hooks.json` structure.** The manifest groups by event; the filesystem now matches it.

## `hooks/hooks.json` registration shape (Claude Code)

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

Exec form (`args` present) needs no quoting for the path placeholder. Full handler-field contract (`command`/`args`/`async`/`shell`, exec-vs-shell semantics): the `anthropic-docs` skill's `references/hooks.md` § Command hook fields.

The bare `${CLAUDE_PLUGIN_ROOT}` above is right **in this file**, which the Claude Code host substitutes before running anything. It is the wrong habit to carry into a bundled `.sh`, where no substitution pass runs at all — see § The dirname-walking anti-pattern.

## Helpers in `hooks/lib/`

Every plugin scaffolded by this skill gets the templates in the inventory table in `SKILL.md`, copied verbatim and namespace-substituted. Hook scripts source them by relative path from their own subdirectory (`. "$(dirname "$0")/../lib/hook-output.sh"`), never inline-reimplemented — a sibling under the same `hooks/` tree is the one place a relative path is correct, because both files move together as one unit. Function signatures and sourcing points: `references/session-env.md`.

## Fixtures centralized

All fixtures live at `<target>/hooks/fixtures/`, not scattered across per-event subdirectories — one flat directory, named `<event>.<scenario>.json` where `<event>` is the event name lowercased with **no separators**: `pretooluse.rm-guard.json`, `posttooluse.write.json`, `sessionstart.resume.json`. (Not kebab-case — the dot already separates event from scenario, and the hyphen-free event name keeps `ls hooks/fixtures/<event>.*` globs trivial.) This keeps BATS tests portable (one `__test__/` tree per target, one fixture root) and makes it trivial to spot which scenarios exist for a given event with a single `ls`.

## Test placement — by the claim's scope, not the file's

A test lives at the level its **claim** belongs to:

| Claim | Lives at |
| --- | --- |
| Host-agnostic — layout, naming, release plumbing, anything true of every target | `plugins/__test__/` |
| Host-specific — one target's hook scripts, manifest fields, emitters | `plugins/<plugin>/<target>/__test__/` |

`bats --recursive plugins` collects every level with no per-suite registration, so adding a file is the whole of adding a test. A host-specific assertion parked in `plugins/__test__/` is the failure mode to watch for: it passes today and turns into false drift the moment a second target arrives.

Within a target workspace, BATS suites and vitest unit tests sit side by side:

- **BATS**: `__test__/<event-kebab>-<name>.bats` per hook script (e.g. `__test__/post-tool-use-record.bats`).
- **Vitest**: `__test__/<name>.test.ts`. Node ≥ 24.11 type-strips, so no build step. The per-plugin vitest project is registered in the repo-root `vitest.config.ts` by the repo owner — the plugin's only obligation is putting files in `__test__/`.

No `tests/`, no `test/`, no specs living next to the scripts they cover.

## `bin/` loaders

Optional. Scripts under `bin/` are added to the Bash tool's `PATH` while the plugin is enabled — invokable as bare commands in any Bash tool call, no plugin-root prefix needed at the call site. Use for a plugin-bundled CLI or MCP-server loader script (`start-<server>.sh`). Full component-location table: the `anthropic-docs` skill's `references/plugins-reference.md` § File locations reference.

## The dirname-walking anti-pattern

Wrong:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"      # walks plugin install, not user project!
DESIGN_DIR="$PROJECT_ROOT/.claude/design"
```

This computes `PROJECT_ROOT` relative to the script's own location. When the plugin is installed normally, the script lives under a cache install directory, not the user's project, so `../..` from `scripts/` lands inside the plugin. Works only when a developer happens to run the script from a clone — breaks for every real install.

Right:

```bash
# Prefer the namespaced var set by SessionStart (survives subshells via
# lib/source-session-env.sh). Fall back to CLAUDE_PROJECT_DIR (set by host
# in Bash-tool subprocs and hook subprocs). Fall back to git for standalone
# invocation outside Claude Code.
PROJECT_DIR="${MYPLUGIN_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
DESIGN_DIR="$PROJECT_DIR/.claude/design"
```

Same shape when a script needs its own plugin's files — resolve the portable chain rather than dirname-walking:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-${MYPLUGIN_PLUGIN_ROOT:-}}}"
```

`${CLAUDE_PLUGIN_ROOT}` covers Claude Code and Copilot; `${PLUGIN_ROOT}` covers Agent Plugins 1.0 and Copilot. Those two sets **overlap at Copilot**, which is the only host answering to spellings from both vocabularies. What is empty is the intersection of the *host vocabularies* at the ends: **Claude Code and Agent Plugins 1.0 share no spelling at all**, so a script that must resolve on both has no single token available and needs the chain. The third element is the namespaced `SessionStart`-exported fallback for subshells that inherit neither. Caveat: `${CLAUDE_PLUGIN_ROOT}` working under Copilot rests on the VS Code page alone. Full matrix and per-site expansion rules: the `agent-plugins-docs` skill's `references/cross-client-behavior.md` § Placeholder vocabulary.

**In a bundled `.sh` these are ordinary shell variables**, read from the process environment. No host runs a substitution pass over a script it merely executes, so a name the running host does not set expands to the **empty string** — under Copilot, which sets no `${PLUGIN_DATA}`, `mkdir -p "${PLUGIN_DATA}/cache"` becomes `mkdir -p "/cache"`. That is the opposite of the manifest layer, where an unrecognised `${…}` in a host-parsed file such as `plugin.json`, `mcp.json` or `hooks.json` survives as a literal string. Guard a resolved root for emptiness before joining a path onto it.

Platform contract for the `${CLAUDE_*}` path vars (stability, when each is set, what each is for): the `anthropic-docs` skill's `references/plugins-reference.md` § Environment variables.

## Audit signals

When auditing a plugin's layout, flag:

- A component directory (`skills/`, `agents/`, `hooks/`) directly under `plugins/<plugin>/` instead of inside a `claude-code/` or `copilot/` workspace — no host context.
- A target workspace directory named anything but `claude-code` or `copilot`.
- Hook scripts at `hooks/<event-kebab>-<scope>.sh` (flat naming) — propose migration to the subdirectory form.
- `hooks.json` that registers a hook command not present at the referenced path.
- Bare relative paths in a Claude Code `hooks.json` (no `${CLAUDE_PLUGIN_ROOT}`).
- Helpers living in `hooks/` root that should live in `hooks/lib/`.
- Fixtures scattered across per-event subdirectories — should be centralized under `hooks/fixtures/`.
- Fixture names with hyphens in the event segment (`pre-tool-use.<scenario>.json`) — should be the separator-free form (`pretooluse.<scenario>.json`).
- Test files under `tests/`, `test/`, or next to the scripts they cover — should be centralized under `__test__/`.
- A host-specific assertion sitting in `plugins/__test__/`, or a host-agnostic one duplicated into each target's `__test__/`.
- `mcpServers` entry where `command` and `args` together don't reference the plugin root — relative loader paths break under unusual cwd.
- A script computing `PROJECT_ROOT`/`PLUGIN_ROOT` by dirname-walking instead of resolving the chains above.
- A copilot workspace whose agents lack the `.agent.md` suffix, or whose `plugin.json` sits under `.claude-plugin/`.
