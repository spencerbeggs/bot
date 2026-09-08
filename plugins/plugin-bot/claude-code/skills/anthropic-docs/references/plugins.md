# Create plugins

> Verified against <https://code.claude.com/docs/en/plugins.md> — 2026-07-10

## Contents

- [Standalone vs plugin decision](#standalone-vs-plugin-decision)
- [Quickstart contracts](#quickstart-contracts)
- [Skills-directory auto-load](#skills-directory-auto-load)
- [Plugin structure overview](#plugin-structure-overview)
- [Local testing](#local-testing)
- [/reload-plugins semantics](#reload-plugins-semantics)
- [Converting existing .claude/ config](#converting-existing-claude-config)
- [Marketplace submission](#marketplace-submission)

## Standalone vs plugin decision

| Approach | Skill names | Best for |
| :--- | :--- | :--- |
| Standalone (`.claude/` directory) | `/hello` | Personal workflows, project-specific customizations, quick experiments |
| Plugins (self-contained dirs with skills, agents, hooks, or a `.claude-plugin/plugin.json` manifest) | `/plugin-name:hello` | Sharing with teammates, distributing to community, versioned releases, reusable across projects |

Use standalone when: single-project customization, personal/unshared config, experimenting before packaging, want short skill names.

Use plugins when: sharing with team/community, need same skills/agents across projects, want version control + easy updates, distributing via marketplace, OK with namespaced skills (namespacing prevents cross-plugin name conflicts).

Recommended path: start standalone in `.claude/` for quick iteration, convert to a plugin when ready to share.

## Quickstart contracts

These are the load-bearing facts from the quickstart tutorial (skip the narrative):

- Manifest location: `.claude-plugin/plugin.json` (optional if components use default locations).
- Manifest fields shown: `name` (unique identifier and skill namespace — skills prefixed as `/name:hello`), `description` (shown in plugin manager), `version` (optional; if set, users get updates only on bump; if omitted and distributed via git, commit SHA is the version and every commit is a new version), `author` (optional, attribution).
- Skills live in `skills/` at plugin root; each is a folder with `SKILL.md`. **The folder name becomes the skill name**, namespaced by the plugin's `name` (e.g. `skills/hello/` in plugin `my-first-plugin` → `/my-first-plugin:hello`).
- `$ARGUMENTS` in SKILL.md body captures user-supplied text after the skill invocation.
- Plugin skills are always namespaced — prevents collisions between plugins with same-named skills. Change the namespace by changing `name` in `plugin.json`.
- `/help` lists skills under their plugin namespace.

## Skills-directory auto-load

`claude plugin init <name>` scaffolds a plugin at `~/.claude/skills/<name>/` with a `.claude-plugin/plugin.json` manifest and starter `SKILL.md`. Next session it loads automatically as `<name>@skills-dir` — no marketplace, no install step.

For auto-load rules, personal vs. project scope, the workspace-trust requirement, and update/removal — see plugins-reference.md § Skills-directory plugins.

## Plugin structure overview

| Directory | Location | Purpose |
| :--- | :--- | :--- |
| `.claude-plugin/` | Plugin root | Contains `plugin.json` manifest (optional if components use default locations) |
| `skills/` | Plugin root | Skills as `<name>/SKILL.md` directories |
| `commands/` | Plugin root | Skills as flat Markdown files. Use `skills/` for new plugins |
| `agents/` | Plugin root | Custom agent definitions |
| `hooks/` | Plugin root | Event handlers in `hooks.json` |
| `.mcp.json` | Plugin root | MCP server configurations |
| `.lsp.json` | Plugin root | LSP server configurations for code intelligence |
| `monitors/` | Plugin root | Background monitor configurations in `monitors.json` |
| `bin/` | Plugin root | Executables added to the Bash tool's `PATH` while the plugin is enabled |
| `settings.json` | Plugin root | Default settings applied when the plugin is enabled |

**Common mistake**: don't put `commands/`, `agents/`, `skills/`, or `hooks/` inside `.claude-plugin/`. Only `plugin.json` goes inside `.claude-plugin/`. All other directories must be at the plugin root level.

The plugin root is the individual plugin's own directory — the one containing `.claude-plugin/plugin.json`. It is never `~/.claude/`. Claude Code doesn't read a `.mcp.json` placed at `~/.claude/.mcp.json`.

**Single-skill rule**: a plugin that ships exactly one skill can place `SKILL.md` directly at the plugin root instead of creating a `skills/` directory. Claude Code loads it as a single skill and uses the frontmatter `name` field for the invocation name. Use `skills/` layout for plugins that may grow to more than one skill.

**`settings.json` at plugin root**: applies default settings when the plugin is enabled. Currently only `agent` and `subagentStatusLine` keys are supported. Setting `agent` activates one of the plugin's custom agents (from `agents/`) as the main thread — applies its system prompt, tool restrictions, and model, letting a plugin change Claude Code's default behavior when enabled:

```json settings.json
{
  "agent": "security-reviewer"
}
```

`settings.json` values take priority over `settings` declared in `plugin.json`. Unknown keys are silently ignored.

**Monitors**: `monitors/monitors.json` at plugin root, array of monitor entries. Claude Code starts each monitor automatically when the plugin is active — no need to instruct Claude to start the watch. Each stdout line from `command` is delivered to Claude as a notification during the session.

```json monitors/monitors.json
[
  {
    "name": "error-log",
    "command": "tail -F ./logs/error.log",
    "description": "Application error log"
  }
]
```

Full schema (including `when` trigger and variable substitution) — see plugins-reference.md § Monitors.

**LSP servers**: add `.lsp.json` at plugin root only when a language lacks an official LSP plugin (prefer installing pre-built LSP plugins for TypeScript, Python, Rust, etc. from the official marketplace). Users installing the plugin must have the language server binary installed separately. Full config options — see plugins-reference.md § LSP servers.

## Local testing

- `claude --plugin-dir ./my-plugin` loads a plugin directly without installation.
- Accepts a `.zip` archive of the plugin directory: `claude --plugin-dir ./my-plugin.zip`. Requires Claude Code v2.1.128 or later.
- **Name-shadowing precedence**: when a `--plugin-dir` plugin has the same name as an installed marketplace plugin, the local copy takes precedence for that session — lets you test changes to an already-installed plugin without uninstalling it first. Exception: plugins that managed settings force-enable or force-disable cannot be overridden by `--plugin-dir`.
- Multiple plugins: repeat the flag — `claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two`.
- `--plugin-url` loads a `.zip` archive hosted at a URL (e.g. a CI build artifact). Claude Code fetches it at startup and loads it for that session only. If the fetch fails or the archive is invalid, Claude Code reports a plugin load error and starts without it. Same trust considerations as any plugin source apply — only point this at archives you control or trust.
- Multiple URLs: repeat `--plugin-url` for each, or pass space-separated URLs as one quoted argument: `claude --plugin-url "https://example.com/a.zip https://example.com/b.zip"`.

Verify components after loading:

- Skills: `/plugin-name:skill-name`
- Agents: check `/context` under Custom Agents, or @-mention by scoped name
- Hooks: verify they trigger as expected

## /reload-plugins semantics

Run `/reload-plugins` to pick up changes without restarting. **Reloads**: plugins, skills, agents, hooks, plugin MCP servers, and plugin LSP servers.

Not covered by this list in this doc — see plugins-reference.md for finer-grained per-component reload behavior.

## Converting existing .claude/ config

Migration steps:

1. Create plugin dir + manifest: `mkdir -p my-plugin/.claude-plugin`, then `my-plugin/.claude-plugin/plugin.json` with `name`, `description`, `version`.
2. Copy existing files: `cp -r .claude/commands my-plugin/`, `cp -r .claude/agents my-plugin/`, `cp -r .claude/skills my-plugin/`.
3. Migrate hooks: `mkdir my-plugin/hooks`, create `my-plugin/hooks/hooks.json` — copy the `hooks` object from `.claude/settings.json` or `settings.local.json` verbatim (same format). Hook commands receive hook input as JSON on stdin; use `jq` to extract fields, e.g. `jq -r '.tool_input.file_path' | xargs npm run lint:fix`.
4. Test: `claude --plugin-dir ./my-plugin` — run commands, check agents in `/context`, verify hooks trigger.

| Standalone (`.claude/`) | Plugin |
| :--- | :--- |
| Only available in one project | Can be shared via marketplaces |
| Files in `.claude/commands/` | Files in `plugin-name/commands/` |
| Hooks in `settings.json` | Hooks in `hooks/hooks.json` |
| Must manually copy to share | Install with `/plugin install` |

**Gotcha**: project and user `.claude/agents/` definitions **override** same-named plugin agents. After migrating, remove the original files from `.claude/` — the plugin version only takes effect once the originals are removed. This applies until removed; simply installing the plugin does not supersede the standalone config.

## Marketplace submission

Anthropic maintains two public marketplaces:

- **`claude-plugins-official`**: curated by Anthropic. Registered automatically on first interactive Claude Code launch. A non-interactive script running before that first launch must add it explicitly: `claude plugin marketplace add anthropics/claude-plugins-official`.
- **`claude-community`**: public community marketplace for third-party submissions after review. Users add with `/plugin marketplace add anthropics/claude-plugins-community`, install as `@claude-community`.

**Community marketplace submission** (review path):

- Submit via in-app forms: claude.ai (`claude.ai/admin-settings/directory/submissions/plugins/new` — requires Team/Enterprise org + directory management access; Owners have this by default) or Console (`platform.claude.com/plugins/submit` — for individual authors not in a Team/Enterprise org).
- **Validate before submit**: run `claude plugin validate` locally. The review pipeline runs the same check on every submission, plus automated safety screening.
- Approved plugins are pinned to a specific commit SHA in the `anthropics/claude-plugins-community` catalog; CI bumps the pin automatically as you push new commits. The public catalog syncs nightly from the review pipeline — delay possible between approval and appearing in `marketplace.json`. Check installability by searching the plugin name in the community catalog's `marketplace.json`.

**Official marketplace path**: curated separately, at Anthropic's discretion. No application process — the community submission form does **not** add plugins to the official marketplace. If Anthropic lists your plugin there, your CLI can prompt users to install it (see Recommend your plugin from your CLI / plugin-hints doc).

To keep a plugin internal to your team instead of public, host the marketplace in a private repository.
