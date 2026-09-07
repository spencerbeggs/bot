---
name: agent-plugins-docs
description: Distilled, verification-stamped reference for the portable agent-plugin layer — the Agent Skills specification (SKILL.md frontmatter, progressive disclosure, references/scripts/assets), the Agent Plugins 1.0 manifest standard, and the cross-client manifest and placeholder vocabulary. Use when authoring or auditing any SKILL.md, when deciding whether a capability is portable or host-specific, when a claim needs to hold on more than one host, or before reaching for a Claude-only or Copilot-only feature. This is the base layer — settle a portable question here before consulting anthropic-docs or copilot-docs.
---

# Agent plugins docs

Distilled references for the layer of the plugin contract that holds on **every** host: the Agent Skills specification, the Agent Plugins 1.0 manifest standard, and the places where clients diverge in spite of them. Each file opens with a stamp naming the exact URL and date it was verified against.

This is the base layer. A claim settled here holds on Claude Code, Copilot and any other conformant client. A claim settled in `anthropic-docs` or `copilot-docs` holds on one host only — so ask here first, and escalate to a host skill only once you know the capability is not portable.

## The three layers

| Layer | Defined by | Carries | Holds on |
| :-- | :-- | :-- | :-- |
| 1. Portable | Agent Skills spec; Agent Plugins 1.0 | `SKILL.md` format and frontmatter, `scripts/`/`references/`/`assets/`, `plugin.json` manifest, `skills/` discovery, `mcp.json` | Every conformant client |
| 2. Host family | A vendor's plugin contract (Claude Code; GitHub Copilot) | Agents, hooks, slash commands, rules, marketplaces, LSP servers, that vendor's manifest extras | That vendor's clients |
| 3. Host-specific | One client | A single client's own surfaces and extras | One client |

The boundary between layer 1 and layer 2 is not a matter of taste: Agent Plugins v1 defines exactly two component types, skills and MCP servers, and states that commands, hooks, agents, rules and LSP servers "remain too client-specific for a stable portable contract and are outside the v1 format until their formats converge". Everything in layers 2 and 3 must be authored once per host.

The authoring rule follows: **write to the narrowest layer that carries the capability, and reach up only deliberately, knowing what the reach costs in portability.**

## Evidence ladder

Apply this for every portable-layer claim, in order. Never skip to memory.

1. **Use the reference.** Read the matching file below. It carries the contract: field tables, constraints, exact values, conformance rules.
2. **Escalate to the live doc** when the reference is silent, when the claim is version-sensitive, or when the stamp date looks old relative to the feature. WebFetch the stamped URL at the top of the reference file — never a URL from memory.
3. **Never guess.** If neither the reference nor the live doc settles the claim, say so and stop. A confident wrong answer about a frontmatter constraint or a placeholder spelling ships a plugin that silently fails to load on one host and looks fine on the other.

Two of these documents move at different speeds. The Agent Skills specification and the Agent Plugins 1.0 spec are versioned and stable; the client behavior in `cross-client-behavior.md` is vendor documentation that changes without a version bump. Treat a stale stamp on that file as a stronger reason to refetch.

## References

All files live in `references/` beside this file. Load only what the task needs.

| File | Load when |
| :-- | :-- |
| [agent-skills-spec.md](references/agent-skills-spec.md) | Writing or auditing a `SKILL.md`: frontmatter fields and their exact constraints, the `name` rules (directory match, no consecutive hyphens), the 1024-character `description` limit, the `scripts`/`references`/`assets` layout, progressive-disclosure tiers and the 500-line / 5000-token budget, file-reference depth, `skills-ref validate` |
| [skill-authoring-guidance.md](references/skill-authoring-guidance.md) | Judging or improving skill *quality* rather than validity: what to cut, defaults versus menus, procedures versus declarations, calibrating prescriptiveness, where gotchas belong, description phrasing and trigger evals, output-quality evals, and the interface rules a bundled script must satisfy for an agent to drive it |
| [agent-plugins-spec.md](references/agent-plugins-spec.md) | Manifest questions: required and optional `plugin.json` fields, plugin `name` constraints (periods allowed, unlike a skill name), which failures are fatal versus skipped, the `extensions` reverse-domain escape hatch, fixed component locations, `mcp.json` transports, `${PLUGIN_ROOT}`/`${PLUGIN_DATA}` expansion sites, client conformance |
| [cross-client-behavior.md](references/cross-client-behavior.md) | A claim that must survive moving between hosts: the two manifest search orders and where they disagree, the placeholder vocabulary table, skill discovery locations per host and the `.agents/skills/` convention, precedence and trust gating, and the portable-versus-client-specific component split |

## Gotchas

Facts that defy a reasonable assumption. They live here rather than in a reference because you may not recognise the trigger to load the reference.

- **A skill `name` and a plugin `name` obey different rules.** Skill names allow hyphens only; plugin names also allow periods (`acme.tools`). Neither allows consecutive separators, and a skill `name` must match its parent directory.
- **There is no universal plugin-root placeholder.** `${CLAUDE_PLUGIN_ROOT}` is Claude's; `${PLUGIN_ROOT}` is Agent Plugins' and Copilot's. Copilot is said to answer to both per the VS Code page, but Copilot's own CLI reference documents only `${PLUGIN_ROOT}` — so prefer that one when targeting Copilot. `${COPILOT_PLUGIN_ROOT}` is defined by nothing; if you see it, it is a bug.
- **`${PLUGIN_DATA}` is Agent-Plugins-only and does not expand on Copilot.** Copilot's data spelling is `${COPILOT_PLUGIN_DATA}`, with `${CLAUDE_PLUGIN_DATA}` as its documented alias — which makes the Claude spelling the one that is safe on both hosts.
- **VS Code and the Copilot CLI search for the manifest in different orders.** A repository carrying two manifests resolves differently on each. Ship one.
- **Agent Plugins defines no manifest search order at all** — the manifest is at `plugin.json` in the plugin root, and no other file may supplement or override it. The search orders belong to the hosts, not the standard.
- **A skill loading is not proof it conforms.** Clients are advised to validate leniently, warning but loading when `name` mismatches its directory or exceeds 64 characters. Validate with `skills-ref`, not by observing that nothing broke.
- **`allowed-tools` is experimental** and support varies between implementations. A skill that depends on it is not portable.

## Stamp policy

Every reference opens with `> Verified against <url> — YYYY-MM-DD`. Where a file distills several pages, it carries one stamp line per page. When you correct or extend a reference after checking the live doc, update its stamp date in the same edit. Never edit a reference from memory.

Where a reference records a claim it could **not** verify against a first-party source, it says so in place rather than dropping the claim silently. Leave those notes intact until a live doc settles them.
