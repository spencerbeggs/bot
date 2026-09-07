# Copilot customization surfaces

> Verified against <https://docs.github.com/en/copilot/reference/customization-cheat-sheet> — 2026-09-07

Not every Copilot capability belongs in a plugin. Instructions, prompt files, repository agents and repository hooks are **repository- or user-scoped files that exist with no plugin at all**. Read this file before deciding to ship something as a plugin component: if the capability already has a repository surface, a plugin is the wrong container unless you need it in more than one repository.

Nothing on this page is portable. The Agent Skills specification deliberately says nothing about where skill directories live (see `agent-plugins-docs/references/agent-skills-spec.md`); the paths below are Copilot's answer to that question, not the standard's.

## The path/scope table

Support column key: **✓** supported, **(P)** preview.

| Capability | Path | Scope | Supported on |
| :-- | :-- | :-- | :-- |
| Repository custom instructions | `.github/copilot-instructions.md` | Repository | VS Code ✓, Visual Studio ✓, JetBrains (P), Eclipse (P), Xcode (P), GitHub.com ✓, Copilot CLI ✓ |
| Path-specific instructions | `.github/instructions/*.instructions.md` | Repository | Same as repository custom instructions |
| `AGENTS.md` | `AGENTS.md` | Repository, for third-party agent integration | Same as repository custom instructions |
| Personal / organization custom instructions | Set through the GitHub UI, not a file | Personal, Organization | Same as repository custom instructions |
| Prompt files | `.github/prompts/*.prompt.md` | Repository | VS Code ✓, Visual Studio ✓, JetBrains (P), Xcode (P) |
| Custom agents — repository | `.github/agents/AGENT-NAME.md` | Repository | VS Code ✓, Visual Studio ✓, JetBrains (P), Eclipse (P), Xcode (P), GitHub.com ✓, Copilot CLI ✓ |
| Custom agents — organization | `/agents/AGENT-NAME.md` in the org's `.github` or `.github-private` repository | Organization | Same as repository agents |
| Custom agents — enterprise | `/agents/AGENT-NAME.md` in the designated `.github-private` repository | Enterprise | Same as repository agents |
| Custom agents — personal | User profile, through the UI | Personal | Same as repository agents |
| Agent skills — project | `.github/skills/<skill-name>/SKILL.md`, `.claude/skills/<skill-name>/SKILL.md`, `.agents/skills/<skill-name>/SKILL.md` | Repository | VS Code ✓, Visual Studio ✓, JetBrains (P), GitHub.com ✓, Copilot CLI ✓ |
| Agent skills — personal | `~/.copilot/skills/<skill-name>/SKILL.md`, `~/.agents/skills/<skill-name>/SKILL.md` | Personal | Same as project skills |
| Hooks | `.github/hooks/*.json` | Repository | VS Code (P), GitHub.com ✓, Copilot CLI ✓ |
| MCP configuration | `mcp.json` (location varies by IDE), repository MCP settings on GitHub, or an agent's `mcp-servers` property | Repository, Organization, Personal | VS Code ✓, Visual Studio ✓, JetBrains ✓, Eclipse ✓, Xcode ✓, GitHub.com ✓, Copilot CLI ✓ |

## Reading the table

**Skill locations: five, split three project and two personal.** Project scope lists `.github/skills/`, `.claude/skills/` and `.agents/skills/`; personal scope lists `~/.copilot/skills/` and `~/.agents/skills/`. Two consequences follow. First, `.agents/skills/` is a **first-class Copilot location at both scopes**, not merely an interoperability convention — though it is that too, per the Agent Skills client-implementation guidance. Second, `.claude/skills/` is read at project scope, which is why a Claude Code repository's skills are often already visible to Copilot with nothing moved. For the ordering among these — first-found-wins, project then parents then user then plugins — see `agent-plugins-docs/references/cross-client-behavior.md`.

**Agents exist at four scopes, and only one is a file in the working repository.** The org and enterprise forms live in a *different* repository (`.github` or `.github-private`) under a bare `/agents/` path, not under `.github/agents/`. A plugin's `agents/*.agent.md` is a fifth, separate route — and recall from `plugin-reference.md` that a repository-level agent silently overrides a plugin's agent of the same ID.

**Hooks have exactly one repository path**: `.github/hooks/*.json`. That is also the only hook source the cloud agent reads at all.

**Support is not uniform.** Prompt files are the narrowest row — no GitHub.com, no Copilot CLI — so a capability written as a prompt file is invisible to CLI and cloud workflows. Hooks are still preview in VS Code. If a capability must work on the CLI *and* in an IDE, check the row before choosing the surface.

## Choosing a container

1. **Does the capability need to travel between repositories?** If no, use the repository surface above. A plugin adds install, versioning and cache-invalidation cost for nothing.
2. **Is it a skill or an MCP server?** Then it is portable — author it once against `agent-plugins-docs` and it works on Copilot, Claude Code and any conformant client.
3. **Is it an agent, hook, command or LSP server?** It is host-specific by definition; Agent Plugins 1.0 excludes all four. Expect to author it once per host, and put the Copilot copy in a plugin only if step 1 said yes.
