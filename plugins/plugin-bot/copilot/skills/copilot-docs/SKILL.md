---
name: copilot-docs
description: Use when authoring or auditing anything under a copilot/ target workspace, porting a Claude Code plugin to Copilot, or verifying a Copilot claim instead of recalling it. Distilled, verification-stamped reference for the GitHub Copilot plugin contract — the plugin.json and marketplace.json schemas, the copilot plugin CLI commands, agents as .agent.md, LSP servers, the hooks.json event roster and handler types, and the repository customization surfaces. Covers only what Copilot adds to the portable layer — settle portable questions in agent-plugins-docs first.
---

# Copilot docs

Distilled references for the **Copilot layer** of the plugin contract: what GitHub Copilot adds on top of the portable Agent Skills / Agent Plugins base. Each file opens with a stamp naming the exact URL and date it was verified against.

This skill is a delta, not a whole. The portable layer — `SKILL.md` format and frontmatter, the Agent Plugins 1.0 manifest, `skills/` discovery, the cross-host placeholder vocabulary and the two manifest search orders — is settled in the sibling `agent-plugins-docs` skill. Ask there first. Come here only once you know the capability is Copilot's own.

## What Copilot adds to the portable layer

Agent Plugins 1.0 defines exactly two component types, skills and MCP servers. Everything below is Copilot's own extension of that base, and none of it ports:

| Addition | Where it lives | Reference |
| :-- | :-- | :-- |
| Manifest fields beyond the closed Agent Plugins schema — `category`, `tags`, and the component-path fields `commands`, `hooks`, `extensions`, `mcpServers`, `lspServers` | `plugin.json` | [plugin-reference.md](references/plugin-reference.md) |
| **Custom agents** — one `.agent.md` file per agent | `agents/` (default) | [plugin-reference.md](references/plugin-reference.md) |
| **Hooks** — 14 lifecycle events, three handler types | `hooks.json` or `hooks/hooks.json`; `.github/hooks/*.json` at repo scope | [hooks-reference.md](references/hooks-reference.md) |
| **LSP servers** — language servers launched by the plugin | `lspServers` in `plugin.json` | [plugin-reference.md](references/plugin-reference.md) |
| **Marketplaces** — a registry manifest plus `copilot plugin marketplace` commands | `marketplace.json` | [plugin-reference.md](references/plugin-reference.md) |
| **Repository customization surfaces** — instructions, prompt files, repo/org/enterprise agents, skill locations | `.github/**` and user scope, *outside* any plugin | [customization-surfaces.md](references/customization-surfaces.md) |

Note the last row: several Copilot capabilities are **not** plugin components at all. Deciding whether a capability belongs in a plugin or in a repository-level file is the first question to answer, and `customization-surfaces.md` is the file that answers it.

## Evidence ladder

Apply this for every Copilot claim, in order. Never skip to memory.

1. **Use the reference.** Read the matching file below. It carries the contract: field tables, defaults, exact event and token spellings, exit-code semantics.
2. **Escalate to the live doc** when the reference is silent, when the claim is version-sensitive, or when the stamp date looks old. WebFetch the stamped URL at the top of the reference file — never a URL from memory. Copilot's plugin surface is unversioned vendor documentation that changes without notice, so a stale stamp is a stronger reason to refetch here than it is in the portable layer.
3. **Never guess.** If neither the reference nor the live doc settles the claim, say so and stop. Two questions are already known to be unsettled — see below — and the correct move on both is to record the ambiguity, not to pick a side.

## References

All files live in `references/` beside this file. Load only what the task needs.

| File | Load when |
| :-- | :-- |
| [plugin-reference.md](references/plugin-reference.md) | Manifest and distribution questions: `plugin.json` required and optional fields, component paths and their defaults, `marketplace.json` and its entry fields including `strict`, source objects and `sha` pinning, the CLI manifest search order, install locations on disk, loading precedence between plugins and project files, the `lspServers` field table, `.agent.md` agents, and the `copilot plugin` subcommands |
| [hooks-reference.md](references/hooks-reference.md) | Anything touching `hooks.json`: the top-level shape, all 14 events and their PascalCase variants, the `command`/`http`/`prompt` handler fields, matcher compilation and which value each event matches on, the per-event output schemas, exit-code and timeout semantics including where Copilot is fail-closed, the fact that hook sources accumulate rather than override, and the cloud-agent restrictions |
| [customization-surfaces.md](references/customization-surfaces.md) | Deciding whether a capability belongs in a plugin at all: the full path/scope table for instructions, `AGENTS.md`, prompt files, repo/org/enterprise/personal agents, every skill location, hooks and MCP — and which Copilot clients honor each |

## No plugin validator

Copilot ships no counterpart to `claude plugin validate --strict`. The `copilot plugin` commands documented by the CLI reference (reproduced as a table in [plugin-reference.md](references/plugin-reference.md)) has no `validate` verb, and `copilot` was not on `PATH` when this was last checked (2026-09-07) to confirm at the binary. Structural correctness for a `copilot/` target workspace therefore rests on this repo's bats suites — there is no upstream tool to lean on.

## Open questions

Recorded deliberately. Do not resolve either by picking the more plausible side; a later task settles them against a first-party source.

- **Agent `tools` identifiers.** The `plugins-creating` how-to shows `tools: ["bash", "edit", "view"]`. A shipped port in another repo uses `["read", "edit", "search"]`. At most one is right, and the CLI plugin reference does not specify `.agent.md` frontmatter at all. Re-checked 2026-09-07: no Copilot CLI available to install and inspect, and a real installed agent under `~/.copilot/installed-plugins/` carries no `tools:` key to arbitrate. The Agent Plugins spec explicitly puts agents outside its v1 scope, so no portable schema will settle this either.
- **Manifest search order is Copilot's own.** Copilot's CLI order puts `.plugin/plugin.json` first and includes `.github/plugin/plugin.json`; VS Code's detection order does neither. Agent Plugins 1.0 defines no order. Never merge the two hosts' orders into one list — see `agent-plugins-docs/references/cross-client-behavior.md`.

## Stamp policy

Every reference opens with `> Verified against <url> — YYYY-MM-DD`. Where a file distills several pages, it carries one stamp line per page. When you correct or extend a reference after checking the live doc, update its stamp date in the same edit. Never edit a reference from memory.

Where a reference records a claim it could **not** verify against a first-party source, it says so in place rather than dropping the claim silently. Leave those notes intact until a live doc settles them.
