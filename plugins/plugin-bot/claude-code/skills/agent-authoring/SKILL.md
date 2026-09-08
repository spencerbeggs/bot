---
name: agent-authoring
description: Enforces subagent frontmatter and system-prompt conventions when an agent file is opened for authoring or review — Claude Code's agents/<name>.md and Copilot's agents/<name>.agent.md. Covers plugin-scope ignored fields, description quality, tool-restriction shape, skills preload, the required boundaries section, and what is lost when a Claude agent is ported to Copilot.
user-invocable: false
paths:
  - "**/agents/**/*.md"
  - "**/agents/**/*.agent.md"
  - "**/.claude/agents/**/*.md"
  - "**/.github/agents/**/*.md"
---

# Agent authoring checklist

Apply this to the file you just opened. The two mistakes that matter most: authoring `hooks`/`mcpServers`/`permissionMode` into a Claude agent that only ever ships as a plugin (silently ignored at load), and a description that narrates the agent's steps instead of stating when to delegate to it.

## Which dialect are you in?

| File shape | Layer |
| :-- | :-- |
| `*.agent.md`, anywhere (including a consumer repo's `.github/agents/`) | Copilot |
| `agents/**/*.md` not ending `.agent.md`, or `.claude/agents/**/*.md` | Claude Code |

`**/agents/**/*.md` already matches `*.agent.md` — the second glob and the `.github/agents/` glob in this skill's frontmatter exist so a reader scanning the path list sees both dialects named, not because the matcher needs them.

## Host-agnostic craft

Identical across both dialects — apply regardless of which frontmatter table below governs the file:

1. **`name` and `description` present.** Claude Code requires both. Copilot's CLI plugin reference documents no `.agent.md` frontmatter at all — including no required-field list — so treat both as required by house convention there too, not by a documented Copilot rule.
2. **Description is "Use when...", third person, trigger-only.** No workflow summary — that belongs in the body.
3. **`tools` matches what the system prompt actually calls.** Prefer an explicit allowlist over omitting it — on Claude Code, omitting `tools` inherits every tool, which makes a plugin agent unauditable. Copilot's `.agent.md` frontmatter is undocumented beyond the `tools` field itself, so no inheritance-on-omission behavior is documented there either way — the same discipline still applies as house convention.
4. **The system prompt includes a boundaries section — "What this agent does NOT do."** Subagents receive only their own system prompt, not the main conversation's; without an explicit boundary list, an agent overshoots into work another agent or the main thread owns.
5. **System prompt doesn't assume shared context** ("continue what we were doing") — subagents start cold.

## Layer deltas

### Claude Code frontmatter

Fields: `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation` (only `"worktree"` is a valid value). Only `name` and `description` are required. See `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/subagents.md` § Frontmatter fields for the full per-field contract.

- **Plugin agents may not set `hooks`, `mcpServers` or `permissionMode`.** Claude Code drops all three at load time for plugin-scoped subagents, for security — see `subagents.md` § Plugin subagent restriction. Only flag them if (a) they're load-bearing for the agent's intended behavior and (b) plugin scope is the only delivery path — then propose moving the hook to `<plugin>/hooks/hooks.json` (matcher scoped to `agent_type`) or the MCP server to the plugin manifest's `mcpServers` block. Otherwise they're harmless portability leftovers; don't strip them reflexively.
- **Agents are auto-named `<plugin-name>:<agent-name>`** (nested paths extend the name further, e.g. `agents/review/security.md` in `my-plugin` registers as `my-plugin:review:security`).
- **A missing `name` and an unparseable frontmatter are two different fallbacks — don't conflate them.** Missing `name` alone: Claude Code names the agent after the file (`agents/reviewer.md` in `my-plugin` loads as `my-plugin:reviewer`) and every other field — `tools`, `model`, `skills` — still applies. Frontmatter that doesn't parse at all: Claude Code names it after the file *and* gives it the description `Agent from my-plugin plugin`, ignoring every field. Both are plugin-scope fallbacks; a **project, user or managed** agent with either defect is skipped entirely instead — so the two cases diverge only for plugin agents, and all three outcomes are silent. See `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/plugins-reference.md` § Agents.
- **`skills:` preloads only always-needed content.** Each entry injects full skill content at every startup — expensive. Conditional knowledge belongs in description- or path-triggered skills the agent discovers on demand, not here.
- **Model choice is intentional**, not just an omitted default: `haiku` for read-only search, `sonnet` for mechanistic work, `opus`/`inherit` for reasoning-heavy tasks.
- **`isolation: worktree`** set for agents that make destructive or exploratory changes to the working tree.
- **`memory:` scope, if set, has consult-before/update-after instructions in the body** — otherwise the memory directory exists but goes unused.
- `disable-model-invocation` or `paths:` in agent frontmatter — those are skill fields, not agent fields.

### Copilot frontmatter

File must be `*.agent.md`. Copilot's CLI plugin reference documents **no `.agent.md` frontmatter at all** — the only source for it is the `plugins-creating` how-to, which shows `name`, `description`, `tools`. Treat the undocumented surface as far wider than `tools`: any field beyond these three has no reference behind it either way.

- **The `tools` identifiers are unresolved — do not pick one.** The `plugins-creating` how-to's example uses `["bash", "edit", "view"]`; a shipped port in another repo uses `["read", "edit", "search"]`. At most one is right, and neither is schema-backed, because no reference documents `.agent.md` frontmatter. Record both candidates and the fact that neither is confirmed; asserting a mapping here is a defect, not a judgment call.
- A repository-level agent (`.github/agents/`) silently overrides a plugin's agent of the same ID — see `copilot-docs/references/plugin-reference.md`.

## Claude tool-name gotcha

`tools` takes canonical tool names. The current roster includes `Agent`, `AskUserQuestion`, `Bash`, `Edit`, `Glob`, `Grep`, `Read`, `Write`, `Skill`, `ToolSearch`, `TodoWrite`, `WebFetch`, `WebSearch`, `SendMessage`, `ReportFindings`, `Task*`, `LSP`, `NotebookEdit`, `PowerShell` — this list drifts as tools ship, so verify it against `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/tools.md` rather than trusting it as final. A skill name appearing in a `tools` list is a common and silent error — it satisfies any test that merely greps the file for the name while granting nothing.

## What does not port — Claude Code → Copilot

The table below is what a port must account for; a Copilot agent produced without reading it silently drops capability.

| Claude Code | Copilot | Consequence |
| :-- | :-- | :-- |
| `skills:` preload list | No documented equivalent | This is a capability loss, not a formatting difference — Claude injects full skill content at startup; a Copilot agent can only be told to go read a file. **Action**: list each skill by name and path in prose, near the top of the body, before the boundaries section, with an explicit instruction to read it. |
| `model`, `effort`, `maxTurns` | No documented equivalent | **Action**: drop the fields; the host chooses. |
| `disallowedTools` | No documented equivalent | **Action**: re-express as an explicit prohibition in the body, near the top, before the boundaries section — group it with the ported `skills:` prose so a reader sees both "must read" and "must not do" together. |
| `memory`, `background`, `isolation` | No documented equivalent | **Action**: drop the fields; nothing to re-express. |
| `tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, …` | `tools: ["bash", "edit", "view"]` per `plugins-creating`, OR `["read", "edit", "search"]` per a shipped port | **Unresolved** — see the Copilot frontmatter section above. **Action**: emit no `tools` key at all; leave a marker comment naming both candidates and the fact that neither is schema-backed, e.g. `<!-- tools: unresolved — "bash","edit","view" per plugins-creating vs "read","edit","search" per a shipped port; neither is schema-backed -->`. An absent key with a visible marker is recoverable later; a guessed key is invisible and permanent. |

## House conventions

- **Preload domain skills via `skills:`** on Claude Code only. An agent that will always need a domain skill should list it in `skills:` rather than relying on discovery via path-trigger mid-task — startup cost is worth it for skills the agent needs on turn one. Copilot has no equivalent field; a ported agent names the skill in prose instead (see the port table above).
- **Boundaries section is not optional.** Every agent body ends with a short "What this agent does NOT do" list, even a one-liner, regardless of dialect.
- **Plugin agents must not rely on `hooks`/`mcpServers`/`permissionMode` frontmatter.** Design the agent's behavior assuming these three are inert at Claude Code plugin scope. If a capability genuinely requires one of them, it does not belong in a plugin-shipped agent — ship it at project/user scope instead, or move the mechanism to the plugin's own `hooks.json` / `plugin.json`.

## Common mistakes

- Reflexively stripping `hooks`/`mcpServers`/`permissionMode` from a Claude agent that also ships at project/user scope, where they're live.
- Asserting a `tools` identifier mapping for Copilot instead of recording both candidates as unresolved.
- Treating Copilot's undocumented `.agent.md` surface as limited to the `tools` field — the CLI reference documents none of it.
- `tools: Bash` unscoped when the agent only runs `git` and `npm` — tighten to `Bash(git *), Bash(npm *)`.
- Description naming a specific user phrase instead of the task class it covers.
- Porting a Claude agent's `skills:` list to Copilot as a frontmatter field instead of prose — there is nothing to preload into.

## Read for the full contract

Claude Code layer:

- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/subagents.md` — every frontmatter field, plugin-scope restrictions, model resolution order, tool-restriction syntax, memory scopes, `hooks`/`mcpServers` inline schemas, naming and discovery order.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/plugins-reference.md` — the plugin-agent frontmatter fallbacks (missing `name` vs. unparseable) and the project/user/managed contrast.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/tools.md` — the canonical tool-name roster.

Copilot layer:

- `${CLAUDE_PLUGIN_ROOT}/skills/copilot-docs/references/plugin-reference.md` — the `.agent.md` component path, the `plugins-creating` frontmatter example, the `tools`-identifier ambiguity, agent-ID derivation from filename, and the repository-agent override rule.
- `${CLAUDE_PLUGIN_ROOT}/skills/copilot-docs/references/customization-surfaces.md` — the four agent scopes, why plugin `agents/*.agent.md` is a fifth route, and why subagents have no authoring surface at all.

Portable layer:

- `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/agent-plugins-spec.md` — agents are explicitly outside the Agent Plugins 1.0 format; there is no portable spelling to write one in, and no manifest work makes one host's agent file load in another.

Reviewing whether the system prompt's language will actually land — imperative force, urgency calibration, structure? Invoke the `persuasion` skill.
