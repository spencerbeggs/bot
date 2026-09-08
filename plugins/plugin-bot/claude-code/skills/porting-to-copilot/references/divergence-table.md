# Claude Code → Copilot divergence table

Stamped **2026-09-07**. Load this when deciding whether a difference between the
two trees is a real port obligation or a compatible fallback you should leave
alone. The three `No` rows are the point of the document.

## The twelve surfaces

| Surface | Claude Code | Copilot | Real divergence? |
| :-- | :-- | :-- | :-- |
| Manifest location | `.claude-plugin/plugin.json` | root `plugin.json` preferred, `.claude-plugin/` accepted | **No** — compatible fallback |
| Manifest fields | `displayName`, `defaultEnabled`, `workflows`, `outputStyles`, `experimental.*`, `userConfig`, `channels`, `dependencies` | `category`, `tags`, `extensions`, `strict`, `$schema` | Partial — mostly additive both ways |
| Skills | `skills/<name>/SKILL.md` | same | **No** |
| Agents | `agents/*.md`; `tools`, `skills`, `model`, `effort`, `maxTurns`, `memory`, `background`, `isolation` | `agents/*.agent.md`; `tools` with a different identifier set | **Yes** |
| Hooks location | `hooks/hooks.json` | root `hooks.json` or `hooks/` | **Yes** |
| Hooks shape | bare event map | `{version: 1, disableAllHooks?, hooks: {...}}` | **Yes** |
| Hook events | 33 | 14, with PascalCase aliases carrying Claude matcher semantics | **Yes** (superset) |
| Hook handlers | `command`, `http`, `mcp_tool`, `prompt`, `agent` | `command`, `http`, `prompt` | **Yes** (superset) |
| Hook output | `hookSpecificOutput.*`, `updatedInput` | flat `permissionDecision`, `modifiedArgs`, `modifiedResult` | **Yes** |
| Plugin root var | `${CLAUDE_PLUGIN_ROOT}` | `${PLUGIN_ROOT}` **or** `${CLAUDE_PLUGIN_ROOT}` | Partial — see below |
| Plugin data var | `${CLAUDE_PLUGIN_DATA}` | `${COPILOT_PLUGIN_DATA}`, aliased as `${CLAUDE_PLUGIN_DATA}` | **No** |
| Marketplace | `.claude-plugin/marketplace.json`, `source: "git-subdir"` | `.github/plugin/marketplace.json`, `source: "github"` | **Yes** |

Those three rows — manifest location, skills, plugin data var — mean: do not
"fix" a `.claude-plugin/plugin.json` found in a Copilot tree, do not restructure
a skill directory, and do not rewrite `${CLAUDE_PLUGIN_DATA}` when you see it in
a Copilot-targeted file. Each of those edits costs review time and changes
nothing.

Per-row authority lives with the enforcer that owns the surface — the
`plugin-manifest` skill for the manifest and marketplace rows, the
`hook-scripts` skill for the four hook rows, the `agent-authoring` skill for
the agents row. Read those before acting on a row; this table says *whether*
there is work, not *what* the work is.

## Placeholder vocabulary

| Placeholder | Defined by | Accepted by |
| :-- | :-- | :-- |
| `${PLUGIN_ROOT}` | Agent Plugins 1.0 | Agent Plugins 1.0, Copilot, legacy OpenPlugin |
| `${PLUGIN_DATA}` | Agent Plugins 1.0 | Agent Plugins 1.0 |
| `${CLAUDE_PLUGIN_ROOT}` | Claude format | Claude Code, Copilot (VS Code page only) |
| `${CLAUDE_PLUGIN_DATA}` | Claude format | Claude Code, Copilot (as an alias of `${COPILOT_PLUGIN_DATA}`) |

`${COPILOT_PLUGIN_ROOT}` is defined by nothing — no specification and no host's
documentation. **This does not generalize to the `COPILOT_*` prefix**:
`${COPILOT_PLUGIN_DATA}` is real and documented.

No single spelling resolves on Claude Code, Copilot and a bare Agent Plugins
client alike. Full matrix, including which sites each token expands in and the
caveat behind the `${CLAUDE_PLUGIN_ROOT}` Copilot cell: the
`agent-plugins-docs` skill's `references/cross-client-behavior.md`,
§ Placeholder vocabulary.

## Corollary: hook script bodies need no placeholder rewrite

A hook **script** resolves its plugin root through the fallback chain in the
`hook-scripts` skill, and a shell script reads these names as ordinary
environment variables rather than as host-substituted tokens. So a
Claude-authored `hooks/**/*.sh` written to that chain runs unchanged under
Copilot. The port work in the hook layer is the **registration wrapper** and
the **event vocabulary** — rewrite `hooks.json`, keep the scripts. Budget the
port accordingly.
