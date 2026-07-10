---
name: agent-authoring
description: Enforces subagent frontmatter and system-prompt conventions when a `<name>.md` agent file is opened for authoring or review — plugin-scope ignored fields, description quality, tool-restriction shape, skills preload, and the required boundaries section.
user-invocable: false
paths:
  - "**/agents/**/*.md"
  - "**/.claude/agents/**/*.md"
---

# Agent authoring checklist

Apply this to the file you just opened. The two mistakes that matter most: authoring `hooks`/`mcpServers`/`permissionMode` into an agent that only ever ships as a plugin (silently ignored at load), and a description that narrates the agent's steps instead of stating when to delegate to it.

## Checklist

1. **`name` and `description` present** — the only required fields.
2. **Description is "Use when...", third person, trigger-only.** No workflow summary — that belongs in the body's "Approach" section.
3. **If this agent installs via plugin scope, `hooks`, `mcpServers`, and `permissionMode` in its frontmatter are dead.** Claude Code ignores all three when the agent file loads from `<plugin>/agents/`. Only flag them if (a) they're load-bearing for the agent's intended behavior and (b) plugin scope is the only delivery path — then propose moving the hook to `<plugin>/hooks/hooks.json` (matcher scoped to `agent_type`) or the MCP server to the plugin manifest's `mcpServers` block. Otherwise the fields are harmless portability leftovers for project/user/CLI scope; don't strip them reflexively.
4. **`tools:` matches what the system prompt actually calls.** Prefer an explicit allowlist or `disallowedTools` over omitting `tools:` — inheriting everything makes a plugin agent unauditable.
5. **`skills:` preloads only always-needed content.** Each entry injects full skill content at every startup — expensive. Conditional knowledge belongs in description- or path-triggered skills the agent discovers on demand, not here.
6. **The system prompt includes a boundaries section — "What this agent does NOT do."** Subagents receive only their own system prompt, not the main conversation's. Without an explicit boundary list, agents overshoot into work another agent or the main thread owns.
7. **Model choice is intentional**, not just an omitted default: `haiku` for read-only search, `sonnet` for mechanistic work, `opus`/`inherit` for reasoning-heavy tasks.
8. **`isolation: worktree`** set for agents that make destructive or exploratory changes to the working tree.
9. **`memory:` scope, if set, has consult-before/update-after instructions in the body** — otherwise the memory directory exists but goes unused.

## House conventions

- **Preload domain skills via `skills:`.** An agent that will always need `hook-scripts` or `skill-scripts` context should list it in `skills:` rather than relying on the agent discovering it via path-trigger mid-task — startup cost is worth it for skills the agent needs on turn one.
- **Boundaries section is not optional.** Every agent body ends with a short "What this agent does NOT do" list, even a one-liner. This is what keeps a narrowly-scoped agent narrowly scoped when a caller's prompt is broader than the agent's job.
- **Plugin agents must not rely on `hooks`/`mcpServers`/`permissionMode` frontmatter.** Design the agent's behavior assuming these three are inert at plugin scope. If a capability genuinely requires one of them, it does not belong in a plugin-shipped agent — ship it at project/user scope instead, or move the mechanism to the plugin's own `hooks.json` / `plugin.json`.

## Common mistakes

- System prompt assumes shared context ("continue what we were doing") — subagents start cold.
- `tools: Bash` unscoped when the agent only runs `git` and `npm` — tighten to `Bash(git *), Bash(npm *)`.
- `disable-model-invocation` or `paths:` in agent frontmatter — those are skill fields, not agent fields.
- Description naming a specific user phrase instead of the task class it covers.

## Read for the full contract

- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/subagents.md` — every frontmatter field, plugin-scope restrictions, model resolution order, tool-restriction syntax, memory scopes, `hooks`/`mcpServers` inline schemas.

Reviewing whether the system prompt's language will actually land — imperative force, urgency calibration, structure? Invoke the `persuasion` skill.
