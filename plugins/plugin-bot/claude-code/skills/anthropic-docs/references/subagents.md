# Subagents

> Verified against <https://code.claude.com/docs/en/sub-agents.md> — 2026-07-10

## Contents

- [Built-in subagents](#built-in-subagents)
- [Scope and priority](#scope-and-priority)
- [Frontmatter fields](#frontmatter-fields)
- [Plugin subagent restriction](#plugin-subagent-restriction)
- [Model resolution](#model-resolution)
- [Tools and disallowedTools](#tools-and-disallowedtools)
- [Tools unavailable to subagents](#tools-unavailable-to-subagents)
- [Restricting spawnable subagents (Agent(type))](#restricting-spawnable-subagents-agenttype)
- [Permission modes](#permission-modes)
- [Skills preload semantics](#skills-preload-semantics)
- [Memory scopes](#memory-scopes)
- [Hooks](#hooks)
- [Foreground / background execution](#foreground--background-execution)
- [API errors in subagents](#api-errors-in-subagents)
- [What loads at startup](#what-loads-at-startup)
- [Resume and SendMessage](#resume-and-sendmessage)
- [Nested subagents and depth limit](#nested-subagents-and-depth-limit)
- [Fork mode](#fork-mode)
- [Example subagent file](#example-subagent-file)

## Built-in subagents

Each inherits the parent conversation's permissions plus additional tool restrictions. Explore and Plan have a startup-context exception — see [What loads at startup](#what-loads-at-startup).

| Agent | Model | Tools | Purpose |
| :--- | :--- | :--- | :--- |
| Explore | Inherits main conversation's model, capped at Opus on the Claude API. On non-Claude-API providers (Bedrock, Google Cloud Agent Platform, Microsoft Foundry, Claude Platform on AWS) inherits directly, uncapped. Requires v2.1.198+ for model inheritance — earlier versions always ran Haiku | Read-only; Write/Edit denied | File discovery, code search, codebase exploration. Invocation specifies thoroughness: quick / medium / very thorough |
| Plan | Inherits from main conversation | Read-only; Write/Edit denied | Codebase research during plan mode |
| general-purpose | Inherits from main conversation | All tools | Complex research, multi-step ops, code modifications |
| statusline-setup | Sonnet | — | Runs when user invokes `/statusline` |
| claude-code-guide | Haiku | — | Answers Claude Code feature questions |

A user or project subagent named `Explore` overrides the built-in one and keeps its own `model` field — define `model: haiku` explicitly to keep exploration cheap.

Restricting built-ins:

- Block one type: add `Agent(<name>)` to `permissions.deny`.
- Block all delegation: deny the `Agent` tool itself.
- Remove only Explore/Plan (v2.1.198+): set `CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS=1`. Claude reads/explores directly instead.
- Remove all built-ins in headless/SDK: set `CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1`.

v2.1.198+: `/agents` no longer opens the interactive wizard; it prints a reminder to ask Claude or edit `.claude/agents/` directly. File locations and frontmatter are unchanged. (v2.1.197 and earlier: `/agents` opens a wizard with Running/Library tabs.)

## Scope and priority

| Location | Scope | Priority | How to create |
| :--- | :--- | :--- | :--- |
| Managed settings | Organization-wide | 1 (highest) | Deployed via managed settings |
| `--agents` CLI flag | Current session | 2 | JSON at launch |
| `.claude/agents/` | Current project | 3 | Ask Claude, or write manually |
| `~/.claude/agents/` | All your projects | 4 | Ask Claude, or write manually |
| Plugin `agents/` directory | Where plugin is enabled | 5 (lowest) | Installed with plugins |

When multiple subagents share a `name`, the higher-priority location wins.

- **Project subagents** are discovered by walking up from cwd — every `.claude/agents/` between cwd and repo root is scanned. v2.1.178+: when nested directories define the same `name`, the definition closest to the working directory wins.
- `--add-dir` directories are also scanned for `.claude/agents/`.
- **User and project scopes** are scanned recursively (subfolders like `agents/review/` allowed); subfolder path does not affect identity — identity comes only from the `name` field. If two files in the same tree declare the same name, only one loads, chosen by filesystem read order (undocumented). `/doctor` (v2.1.205+) reports same-directory name collisions and proposes a fix; before v2.1.205 `/doctor` opened a diagnostics screen listing duplicates.
- **Plugin scopes** are also scanned recursively, but subfolders DO affect identity: a file at `agents/review/security.md` in plugin `my-plugin` registers as `my-plugin:review:security`.
- **CLI-defined (`--agents`)** subagents are session-only, not saved to disk. JSON accepts the same fields as file frontmatter: `description`, `prompt` (= markdown body), `tools`, `disallowedTools`, `model`, `permissionMode`, `mcpServers`, `hooks`, `maxTurns`, `skills`, `initialPrompt`, `memory`, `effort`, `background`, `isolation`, `color`.
- **Managed subagents**: markdown files in `.claude/agents/` inside the managed settings directory, same frontmatter format; take precedence over project/user subagents with the same name.
- **Plugin subagents** load alongside custom subagents, appear in @-mention typeahead under their scoped name. See [plugins-reference.md](plugins-reference.md) for agent component details.
- Subagent definitions from any scope are also usable as agent-team teammate definitions: the teammate uses the definition's `tools` and `model`, with the body appended as additional instructions.

## Frontmatter fields

Only `name` and `description` are required.

| Field | Req | Description |
| :--- | :--- | :--- |
| `name` | Yes | Lowercase letters and hyphens, unique. Hooks receive this as `agent_type`. Filename need not match |
| `description` | Yes | When Claude should delegate to this subagent |
| `tools` | No | Allowlist. Inherits all tools if omitted. Use `skills` (not `Skill` in `tools`) to preload skill content |
| `disallowedTools` | No | Denylist, removed from inherited/specified list |
| `model` | No | `sonnet`, `opus`, `haiku`, `fable`, a full model ID (e.g. `claude-opus-4-8`), or `inherit`. Default: `inherit` |
| `permissionMode` | No | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`, or `manual` (alias for `default`, requires v2.1.200+). Ignored for plugin subagents |
| `maxTurns` | No | Max agentic turns before the subagent stops |
| `skills` | No | Skills to preload — full content injected, not just description. Subagent can still invoke unlisted skills via the Skill tool |
| `mcpServers` | No | MCP servers available to this subagent: server name string (reuse existing config) or inline server config — inline configs accept `stdio`, `http`, `sse` and `ws` types. Ignored for plugin subagents |
| `hooks` | No | Lifecycle hooks scoped to this subagent. Ignored for plugin subagents |
| `memory` | No | Persistent memory scope: `user`, `project`, or `local` |
| `background` | No | `true` = always run as background task. Unset = Claude chooses; as of v2.1.198 default is background |
| `effort` | No | `low`, `medium`, `high`, `xhigh`, `max` (model-dependent availability). Default: inherits from session |
| `isolation` | No | `worktree` = run in a temporary git worktree branched from the default branch (not parent's HEAD). Auto-cleaned if no changes made |
| `color` | No | `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan` |
| `initialPrompt` | No | Auto-submitted as first user turn when this agent runs as the main session agent (via `--agent`/`agent` setting). Commands/skills processed. Prepended to any user-provided prompt |

Notes:

- If both `tools` and `disallowedTools` are set, `disallowedTools` applies first, then `tools` resolves against the remainder; a tool in both is removed.
- Subagents receive only their own system prompt + basic environment details (cwd etc.), **not** the full Claude Code system prompt.
- `cd` in a subagent's Bash/PowerShell calls doesn't persist across tool calls and doesn't affect the main conversation's cwd. Use `isolation: worktree` for an isolated repo copy.
- v2.1.203+: a subagent with `isolation: worktree` runs Bash/PowerShell inside its worktree; if the resolved cwd falls back to the main checkout (e.g. worktree removed mid-run), the command errors instead of silently running in the main checkout (pre-2.1.203 behavior).
- File-watching: Claude Code watches `~/.claude/agents/` and `.claude/agents/` and picks up edits within seconds, no restart needed — EXCEPT: (a) a brand-new `agents` directory that didn't exist at session start requires a restart, (b) sessions started with `--disable-slash-commands` don't watch at all.
- Headless `--append-subagent-system-prompt` (v2.1.205+) appends text to every subagent's system prompt, including nested ones.

## Plugin subagent restriction

**For security reasons, plugin subagents ignore the `hooks`, `mcpServers`, and `permissionMode` frontmatter fields entirely** — these are dropped at load time. Workarounds: copy the agent file into `.claude/agents/` or `~/.claude/agents/`, or add rules to `permissions.allow` in `settings.json`/`settings.local.json` (these apply session-wide, not just to the plugin subagent).

## Model resolution

Resolution order when Claude invokes a subagent:

1. `CLAUDE_CODE_SUBAGENT_MODEL` env var (model alias or ID)
2. Per-invocation `model` parameter
3. Subagent's `model` frontmatter
4. Main conversation's model

- v2.1.196+: `CLAUDE_CODE_SUBAGENT_MODEL=inherit` behaves as if unset (falls through to steps 2–3). Before v2.1.196, `inherit` forced the main conversation's model and skipped steps 2–3.
- Each candidate value (env var, per-invocation, frontmatter) is checked against the org's `availableModels` allowlist; an excluded value is skipped and the subagent falls back to the inherited model.
- v2.1.198+: subagents inherit the main conversation's extended-thinking on/off setting; no per-subagent thinking config exists. Before v2.1.198, subagents always ran with extended thinking disabled.

## Tools and disallowedTools

Subagents inherit internal tools and MCP tools available in the main conversation by default.

Both `tools` and `disallowedTools` accept MCP server-level patterns in addition to exact names:

- `mcp__<server>` or `mcp__<server>__*` — grants/removes every tool from that server.
- `mcp__*` in `disallowedTools` — removes every MCP tool from every server.

```yaml
---
name: local-only
description: Inherits every tool except those from the github MCP server
disallowedTools: mcp__github
---
```

## Tools unavailable to subagents

These depend on main-conversation UI/session state and are unavailable to subagents even if listed in `tools`:

- `AskUserQuestion`
- `EnterPlanMode`
- `ExitPlanMode` — unless the subagent's `permissionMode` is `plan`
- `ScheduleWakeup`
- `WaitForMcpServers`

## Restricting spawnable subagents (Agent(type))

Applies **only** to an agent running as the main thread via `claude --agent`. (Task tool renamed to Agent in v2.1.63; `Task(...)` references still work as aliases.)

```yaml
tools: Agent(worker, researcher), Read, Bash
```

- Allowlist semantics: only `worker` and `researcher` may be spawned; other spawn requests fail and the agent's prompt lists only the allowed types.
- `Agent` (no parens) = spawn any subagent, unrestricted.
- `Agent` omitted from `tools` entirely = can't spawn any subagent.
- To block specific agents while allowing the rest, use `permissions.deny` (`Agent(<name>)`) instead.
- In a **subagent definition** (not main-thread `--agent`), listing `Agent` in `tools` enables spawning nested subagents, but any type list in parentheses is ignored there.

`mcpServers` scoping: inline definitions connect at subagent start and disconnect at finish; string references share the parent session's connection. Applies both when the agent file runs as a subagent (via Agent tool/@-mention) and as the main session (via `--agent`). v2.1.153+: `--strict-mcp-config`, `--bare`, enterprise managed MCP config, and `allowedMcpServers`/`deniedMcpServers` policies also filter servers declared in subagent frontmatter (blocked servers are skipped with a warning naming them). Managed-settings restrictions apply regardless of how the subagent is defined; `--strict-mcp-config` does NOT filter servers passed inline via `--agents` or the SDK `agents` option (explicit caller input).

## Permission modes

| Mode | Behavior |
| :--- | :--- |
| `default` | Standard permission checking with prompts |
| `acceptEdits` | Auto-accept file edits and common filesystem commands for paths in cwd or `additionalDirectories` |
| `auto` | Background classifier reviews commands and protected-directory writes |
| `dontAsk` | Auto-deny permission prompts (explicitly allowed tools still work) |
| `bypassPermissions` | Skip permission prompts |
| `plan` | Plan mode (read-only exploration) |

`bypassPermissions` still skips prompts for writes to `.git`, `.config/git`, `.claude`, `.vscode`, `.idea`, `.husky`, `.cargo`, `.devcontainer`, `.yarn`, `.mvn` — use with caution. Explicit `ask` rules and root/home directory removals (e.g. `rm -rf /`) still prompt even under `bypassPermissions`.

**Parent-mode precedence**: if the parent uses `bypassPermissions` or `acceptEdits`, that takes precedence and cannot be overridden by the subagent's `permissionMode`. If the parent uses `auto` mode, the subagent inherits `auto` and its own `permissionMode` frontmatter is ignored — the classifier evaluates the subagent's tool calls with the same block/allow rules as the parent session.

## Skills preload semantics

`skills` field injects **full content** (not just the description) of each listed skill into the subagent's context at startup.

- This controls what's *preloaded*, not what's *invocable* — without `skills`, the subagent can still discover/invoke project, user, and plugin skills via the Skill tool during execution.
- To block skill invocation entirely, omit `Skill` from `tools` or add it to `disallowedTools`.
- **You cannot preload a skill that sets `disable-model-invocation: true`** — preloading draws from the same invocable set. A missing or disabled listed skill is skipped with a warning to the debug log.
- Inverse relationship to `context: fork` in a skill (see skills.md): `skills` in a subagent = subagent controls the system prompt and loads skill content; `context: fork` in a skill = skill content injected into the agent you specify. Same underlying system.

## Memory scopes

`memory` gives the subagent a persistent directory surviving across conversations.

| Scope | Location | Use when |
| :--- | :--- | :--- |
| `user` | `~/.claude/agent-memory/<name-of-agent>/` | Memory should apply across all projects |
| `project` | `.claude/agent-memory/<name-of-agent>/` | Project-specific, shareable via version control |
| `local` | `.claude/agent-memory-local/<name-of-agent>/` | Project-specific, not checked into version control |

When memory is enabled:

- System prompt includes instructions for reading/writing the memory directory.
- System prompt also includes the first 200 lines OR 25KB of `MEMORY.md` (whichever limit hits first), with instructions to curate it if it exceeds that.
- Read, Write, Edit tools are auto-enabled to manage memory files.

`project` is the recommended default (shareable). Ask the subagent to consult memory before starting and to update it after finishing; include memory-maintenance instructions directly in the markdown body for proactive curation.

## Hooks

### Frontmatter hooks (per-subagent)

Fire when the agent is spawned as a subagent (via Agent tool/@-mention) AND when it runs as the main session (via `--agent`/`agent` setting) — in the main-session case, alongside `settings.json` hooks.

| Event | Matcher input | When it fires |
| :--- | :--- | :--- |
| `PreToolUse` | Tool name | Before the subagent uses a tool |
| `PostToolUse` | Tool name | After the subagent uses a tool |
| `Stop` | (none) | When the subagent finishes — **converted to `SubagentStop` at runtime** |

All hook events are supported; the table lists the most common. See hooks.md for the complete event list and I/O schema.

### Settings.json hooks (main-session, subagent lifecycle)

| Event | Matcher input | When it fires |
| :--- | :--- | :--- |
| `SubagentStart` | Agent type name | When a subagent begins execution |
| `SubagentStop` | Agent type name | When a subagent completes |

Matcher value = the subagent's frontmatter `name` for project/user subagents, or the plugin-scoped identifier (e.g. `my-plugin:db-agent`) for plugin subagents. **A scoped name contains a colon, so it's evaluated as an unanchored regex** — anchor with `^...$` (e.g. `^my-plugin:db-agent$`) to match only that agent.

A hyphenated matcher like `db-agent` matches exactly on v2.1.195+. Before that it's an unanchored regex and also fires for names containing it (e.g. `prod-db-agent`) — anchor as `^db-agent$` on older versions.

```json
{
  "hooks": {
    "SubagentStart": [
      { "matcher": "db-agent", "hooks": [{ "type": "command", "command": "./scripts/setup-db-connection.sh" }] }
    ],
    "SubagentStop": [
      { "hooks": [{ "type": "command", "command": "./scripts/cleanup-db-connection.sh" }] }
    ]
  }
}
```

## Foreground / background execution

- **Foreground**: blocks the main conversation until complete; permission prompts pass through to the user as they come up.
- **Background**: runs concurrently. v2.1.186+: when a background subagent hits a tool call needing permission, the prompt surfaces in the main session naming the subagent; approve to continue or Esc to deny that one call without stopping the subagent. Before v2.1.186, background subagents auto-denied any prompting tool call.
- v2.1.198+: subagents run in the **background by default**; Claude runs foreground only when it needs the result immediately. This only changes *where* it runs, not what's allowed — background subagents still surface every permission prompt in the main session. Before v2.1.198, Claude chose fg/bg per task.
- User control: ask Claude to run fg/bg explicitly, or press **Ctrl+B** to background a running task.
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` disables all background task functionality.
- When `CLAUDE_CODE_FORK_SUBAGENT=1` (see [Fork mode](#fork-mode)), every subagent spawn runs in the background and the frontmatter `background` field has no effect (fork mode removes `run_in_background` from the Agent tool). `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` takes precedence over fork mode and forces spawns back to foreground.

## API errors in subagents

v2.1.199+: a subagent run that ends on an API error (usage limit, repeated server error) reports the failure back to Claude instead of surfacing the raw error text as if it were the subagent's findings.

- **Foreground**: if the error cuts off a subagent that already produced text output, the Agent tool returns that partial output plus a note that the subagent was cut off. v2.1.200+: a subagent that produced nothing (or only tool calls) fails with `Agent terminated early due to an API error` plus error detail. In v2.1.199 exactly, the tool-calls-only shape instead returned an empty partial result containing only the cut-off note.
- **Background**: the subagent is marked failed; the message Claude receives names the API error and includes the subagent's last output so partial work isn't lost.

Once the API error clears, retry the task or resume the subagent.

## What loads at startup

Each subagent gets a fresh, isolated context — no conversation history, no already-invoked skills, no already-read files. Claude composes a delegation message summarizing the task. **Exception: a fork inherits the parent conversation instead of starting fresh.**

A non-fork subagent's initial context contains:

- **System prompt**: the agent's own prompt + environment details Claude Code appends — NOT the full Claude Code system prompt. Custom subagents define theirs in the markdown body or `prompt` field; built-ins have predefined prompts.
- **Task message**: the delegation prompt Claude writes at handoff.
- **CLAUDE.md and memory**: every level of the memory hierarchy the main conversation loads (`~/.claude/CLAUDE.md`, project rules, `CLAUDE.local.md`, managed policy files) — **except Explore and Plan, which skip this**.
- **Git status**: a snapshot taken at parent-session start. Absent if cwd isn't a git repo or `includeGitInstructions` is `false`. Explore and Plan skip it regardless.
- **Preloaded skills**: full content of any skill in the agent's `skills` field. Built-in agents don't preload skills.

No frontmatter field or setting changes which agents skip CLAUDE.md/git status (see above). Since the main conversation already has full CLAUDE.md context when reading Explore/Plan results, most rules don't need to reach the subagent — but rules the subagent itself must obey (e.g. "ignore `vendor/`") need to be restated in the delegation prompt.

## Resume and SendMessage

- Each subagent invocation creates a fresh-context instance; resuming continues an existing instance with full prior tool calls, results, and reasoning intact.
- On completion, Claude receives the subagent's agent ID. **Explore and Plan are one-shot and return no agent ID — they cannot be resumed.** Use `general-purpose` or a custom subagent when continuation is needed.
- Resume mechanism: Claude uses `SendMessage` with the agent's ID or name as `to`. `SendMessage` doesn't require agent teams to be enabled (only structured team-protocol messages like `shutdown_request`/`plan_approval_response` do).
- A stopped subagent that receives a `SendMessage` auto-resumes in the background without a new `Agent` invocation.
- Resuming starts a new run under the same ID: a previously failed/completed subagent shows as running again in the task list and SDK task events. Before v2.1.205, it kept showing its earlier failed/completed status while the resumed run worked.
- v2.1.199+: `SendMessage` verifies a name still refers to the same agent reached earlier in the conversation; if a newer agent reused the name (e.g. re-spawned background agent), the send is refused and the error names which agent the name now reaches. To reach the earlier agent while it's still running, address it by agent ID. Check is scoped to the current conversation and resets on `/clear`.
- v2.1.198+: a subagent treats messages from its launching agent as normal task direction (including mid-task course corrections) and acts on them within its own permission settings. Two limits hold regardless of sender: **no agent message counts as approval for a pending permission prompt**, and **no agent message can change a subagent's permission settings, CLAUDE.md, or configuration** — only the permission system or the user's own messages can grant approval.
- Transcript files: `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`.
- Transcripts persist independently: unaffected by main-conversation compaction (separate files); persist within their session (resumable after Claude Code restart by resuming the same session); auto-cleaned per `cleanupPeriodDays` setting (default 30 days).
- **Auto-compaction**: subagents use the same compaction logic and triggers as the main conversation; `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` applies to subagents too. Compaction events log in the transcript as `{"type": "system", "subtype": "compact_boundary", "compactMetadata": {"trigger": "auto", "preTokens": N}}`.

## Nested subagents and depth limit

v2.1.172+: a subagent can spawn its own subagents, resolved from the same scopes as top-level ones. Only the top-level subagent's summary returns to the user; intermediate output never reaches the main conversation.

- Depth = number of subagent levels below the main conversation, regardless of foreground/background at each level.
- **A subagent at depth five doesn't receive the Agent tool and can't spawn further. The limit is fixed and not configurable.**
- v2.1.187+: a background subagent's depth is fixed at first spawn; resuming later doesn't change it. E.g. main spawns A, A spawns background B at depth two — B stays at depth two even when resumed directly from the main conversation.
- To prevent a subagent from spawning others: omit `Agent` from its `tools` or add it to `disallowedTools`.
- A fork can't spawn another fork, but can spawn other subagent types, which count toward the depth limit.

## Fork mode

Requires Claude Code v2.1.117+. `/fork` command enabled by default from v2.1.161; before that, requires `CLAUDE_CODE_FORK_SUBAGENT=1`. Claude spawning forks itself is experimental. May be enabled in interactive sessions as part of a staged rollout.

A fork is a subagent that **inherits the entire conversation so far** instead of starting fresh — same system prompt, tools, model, and message history as the main session. Its own tool calls stay out of the main conversation; only the final result returns.

Control regardless of staged rollout: `CLAUDE_CODE_FORK_SUBAGENT=1` to force-enable, `=0` to force-disable (honored in interactive mode, SDK, `claude -p`).

Enabling fork mode changes two things:

1. Claude can spawn a fork by explicitly requesting the `fork` subagent type. Spawns without a type still use `general-purpose`; named subagents (e.g. Explore) still spawn as before.
2. Every subagent spawn runs in the background, fork or named. `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` keeps spawns synchronous.

Start manually with `/fork <directive>` (works with or without the env var set); Claude Code names the fork from the directive's first words.

### Fork vs named subagent

| | Fork | Named subagent |
| :--- | :--- | :--- |
| Context | Full conversation history | Fresh, prompt-only |
| System prompt/tools | Same as main session | From the subagent's definition file |
| Model | Same as main session | From the subagent's `model` field |
| Permissions | Prompts surface in the terminal | Prompts surface in the main session when backgrounded |
| Prompt cache | Shared with main session | Separate cache |

Because a fork's system prompt and tool definitions are identical to the parent, its first request reuses the parent's prompt cache — cheaper than spawning a fresh subagent for same-context tasks.

Claude spawning a fork via the Agent tool can pass `isolation: "worktree"` so fork edits land in a separate git worktree instead of the main checkout.

**Limitations**: `CLAUDE_CODE_FORK_SUBAGENT=1` enables fork mode in interactive, headless, and SDK contexts; `=0` disables it everywhere, including server-side rollout. **A fork cannot spawn further forks.**

## Example subagent file

```markdown
---
name: code-reviewer
description: Reviews code for quality, security, maintainability. Use proactively after writing or modifying code.
tools: Read, Grep, Glob, Bash
---

Senior code reviewer. Run git diff, focus on modified files, report by priority (critical / warnings / suggestions) with fix examples.
```

Design guidance from the source: focused single-purpose subagents, detailed descriptions (Claude uses `description` to decide when to delegate — include phrases like "use proactively" to encourage automatic delegation), minimal tool grants, check project subagents into version control.
