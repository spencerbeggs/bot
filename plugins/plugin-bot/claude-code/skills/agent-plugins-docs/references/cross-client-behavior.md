# Cross-client behavior

> Verified against <https://code.visualstudio.com/docs/agent-customization/agent-plugins> — 2026-09-07
> Verified against <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference> — 2026-09-07
> Verified against <https://agentskills.io/client-implementation/adding-skills-support.md> — 2026-09-07

Where the hosts actually differ once a plugin leaves the portable layer: which manifest a host looks for, which placeholder spellings it answers to, and where it hunts for skills.

## Manifest search order

Hosts disagree on this, so there is no single "the" order. Both first-party orders, as documented:

**VS Code** auto-detects the plugin format by the root manifest it finds:

| Format | Manifest path |
| :-- | :-- |
| Agent Plugins 1.0 | `plugin.json` declaring `$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json` |
| Copilot | `plugin.json` (default) |
| Claude | `.claude-plugin/plugin.json` |
| Legacy OpenPlugin | `.plugin/plugin.json` |

**Copilot CLI** searches in a different sequence, and includes a location VS Code does not list:

1. `.plugin/plugin.json`
2. `plugin.json`
3. `.github/plugin/plugin.json`
4. `.claude-plugin/plugin.json`

Marketplace manifests follow the same shape: `marketplace.json`, `.plugin/marketplace.json`, `.github/plugin/marketplace.json`, `.claude-plugin/marketplace.json`.

Agent Plugins itself defines **no** search order — the spec requires the manifest at `plugin.json` in the plugin root and nowhere else.

**The consequence worth stating: a well-formed Claude Code plugin is already nearly a valid Copilot plugin.** Both VS Code and the Copilot CLI look inside `.claude-plugin/`, so a Claude Code plugin is discovered without moving a file. What is left is not discovery but content — the components that do not port at all (see below).

**Gotcha:** the two orders resolve differently for a repository carrying more than one manifest. A repo with both `.plugin/plugin.json` and root `plugin.json` is read as Agent Plugins or Copilot by VS Code and as legacy OpenPlugin by the Copilot CLI. Ship one manifest, or verify against both hosts.

## Placeholder vocabulary

| Placeholder | Claude Code | Copilot | Agent Plugins 1.0 |
| :-- | :-- | :-- | :-- |
| `${CLAUDE_PLUGIN_ROOT}` | Defined | Accepted per the VS Code page; undocumented in the CLI reference | Not defined |
| `${PLUGIN_ROOT}` | Not defined | Defined | Defined (`args`, `env` values, `cwd` in `mcp.json`) |
| `${CLAUDE_PLUGIN_DATA}` | Defined | Defined, as an alias of `${PLUGIN_DATA}` | Not defined |
| `${PLUGIN_DATA}` | Not defined | Defined | Defined (same expansion sites) |
| `${COPILOT_PLUGIN_ROOT}` | Not defined | Not defined | Not defined |

**Copilot is the overlap.** It is the only host that answers to both vocabularies, which is why a Copilot-targeted file can use either spelling and a portable file cannot. **No spelling is universal** — there is no token that resolves on Claude Code, Copilot and a bare Agent Plugins client alike, so a script that needs its plugin root on more than one host resolves a chain rather than trusting one variable. And **`${COPILOT_PLUGIN_ROOT}` is defined by nothing**: it appears in no specification and no host's documentation. If you see it in a file, it is a bug, not a dialect.

Two further cautions:

- The root spelling is the contested one. `${CLAUDE_PLUGIN_DATA}` is safe on both Claude Code and Copilot because Copilot aliases it explicitly; `${CLAUDE_PLUGIN_ROOT}` rests on the VS Code page alone, and the Copilot CLI reference documents only `${PLUGIN_ROOT}`. Prefer `${PLUGIN_ROOT}` when targeting Copilot CLI.
- Under Agent Plugins these are `mcp.json` expansions, not general environment variables: they expand in `args`, `env` values and `cwd`, and never in `command`, `env` keys, component locations, `url` or `headers`. `PLUGIN_ROOT` and `PLUGIN_DATA` are additionally set in the launched subprocess's environment, which is what a bundled script can read.

## Where each host looks for skills

| Host | Locations |
| :-- | :-- |
| Agent Plugins 1.0 (in-plugin) | `skills/`, immediate subdirectories only |
| Claude Code (in-plugin) | `skills/` |
| VS Code / Copilot (in-plugin) | `skills/` |
| Copilot CLI (project) | `<project>/.github/skills/`, `<project>/.claude/skills/`, then the same names in parent directories for monorepo inheritance |
| Copilot CLI (user) | `~/.copilot/skills/`, `~/.agents/skills/` |
| Copilot CLI (other) | Each plugin's configured skills paths; then `COPILOT_SKILLS_DIRS` and config settings |

Copilot CLI resolves these **first-found-wins**, in the order listed: project, then parents, then user, then plugins, then environment-configured.

`.agents/skills/` is the **cross-client convention**. The Agent Skills specification deliberately does not mandate where skill directories live — it defines only what goes inside them — but the client-implementation guide recommends every client scan both its own native directory and `.agents/skills/`, at both project and user scope, so that skills installed by one compliant client are visible to the others. Several implementations also scan `.claude/skills/` for pragmatic compatibility, since many existing skills already live there.

Client guidance worth knowing when reasoning about why a skill did or did not load:

- **Precedence:** project-level skills override user-level skills. That is the universal convention. Within one scope, first-found or last-found is client's choice.
- **Trust:** project-level skills come from the repository being worked on, which may be untrusted; clients are advised to gate them on a trust check, so a freshly cloned repo's skills may silently not load.
- **Lenient validation:** clients are advised to warn but still load when `name` mismatches the directory or exceeds 64 characters, and to skip only when the description is missing or the YAML is unparseable. Do not read a skill loading successfully as proof it conforms to the spec.

## Portability split

VS Code states the division plainly:

- **Portable — standard across clients:** skills (instructions, scripts and resources) and MCP servers.
- **Client-specific:** custom agents, hooks (shell commands at lifecycle points), slash commands, and rules — carried under the `com.github.copilot` namespace in VS Code.

This matches the Agent Plugins scope statement, which leaves commands, hooks, agents, rules and LSP servers outside v1 until their formats converge. So the split is not a VS Code policy; it is the boundary of the standard.

Component discovery beyond skills, for reference: MCP servers come from `mcp.json` (Agent Plugins) or `.mcp.json` (Claude/Copilot format); hooks vary by format — `com.github.copilot/hooks/hooks.json`, `hooks/hooks.json`, or root `hooks.json`.

**Authoring consequence:** a capability in the client-specific column must be authored once per host, and a claim about it holds only for the host it was verified against. Verify those against `anthropic-docs` or `copilot-docs`, never here.
