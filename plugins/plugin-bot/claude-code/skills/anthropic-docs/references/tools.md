# Tools reference

> Verified against <https://code.claude.com/docs/en/tools-reference.md> — 2026-07-10

Tool names are the exact strings used in permission rules, subagent `tools`/`disallowedTools` lists, skill `allowed-tools`, and hook `matcher` fields. Add a tool name to a `deny` array to disable it entirely.

## Contents

- [Built-in tools](#built-in-tools)
- [Permission rule formats](#permission-rule-formats)
- [Agent tool behavior](#agent-tool-behavior)
- [Bash tool behavior](#bash-tool-behavior)
- [Edit tool behavior](#edit-tool-behavior)
- [Glob tool behavior](#glob-tool-behavior)
- [Grep tool behavior](#grep-tool-behavior)
- [LSP tool behavior](#lsp-tool-behavior)
- [Monitor tool](#monitor-tool)
- [NotebookEdit tool behavior](#notebookedit-tool-behavior)
- [PowerShell tool](#powershell-tool)
- [Read tool behavior](#read-tool-behavior)
- [WebFetch tool behavior](#webfetch-tool-behavior)
- [WebSearch tool behavior](#websearch-tool-behavior)
- [Write tool behavior](#write-tool-behavior)

## Built-in tools

| Tool | Purpose | Permission |
| :--- | :--- | :--- |
| `Agent` | Spawns a subagent with its own context window. See [Agent tool behavior](#agent-tool-behavior) | No |
| `Artifact` | Publishes HTML/Markdown as a private claude.ai page, shareable org-wide on Team/Enterprise. Requires Pro/Max/Team/Enterprise + `/login` | Yes |
| `AskUserQuestion` | Multiple-choice questions. No idle timeout by default; `askUserQuestionTimeout` setting (`60s`/`5m`/`10m`) auto-continues after idle, submitting selections and telling Claude to proceed on judgment; 20s countdown; any keypress/focus resets timer. Only this dialog auto-resolves — permission prompts never do. Requires v2.1.200. In v2.1.198–2.1.199, default was 60s auto-continue via `CLAUDE_AFK_TIMEOUT_MS` | No |
| `Bash` | Executes shell commands. See [Bash tool behavior](#bash-tool-behavior) | Yes |
| `CronCreate` | Schedules a recurring/one-shot session-scoped prompt; restored on `--resume`/`--continue` if unexpired | No |
| `CronDelete` | Cancels a scheduled task by ID | No |
| `CronList` | Lists scheduled tasks in the session | No |
| `Edit` | Targeted string-replacement edits. See [Edit tool behavior](#edit-tool-behavior) | Yes |
| `EnterPlanMode` | Switches to plan mode | No |
| `EnterWorktree` | Creates/switches into a git worktree. v2.1.203+: on first entry, target may be a worktree of the current repo or (multi-repo) a nested repo (before: nested-repo worktrees rejected). From inside a worktree session, or an `isolation: worktree` subagent, only the `path` form works and target must be under `.claude/worktrees/` | No |
| `ExitPlanMode` | Presents plan for approval, exits plan mode | Yes |
| `ExitWorktree` | Exits worktree session, returns to original dir. Unavailable to subagents with a pinned cwd (e.g. `isolation: worktree`) | No |
| `Glob` | Finds files by name pattern. See [Glob tool behavior](#glob-tool-behavior) | No |
| `Grep` | Searches file contents. See [Grep tool behavior](#grep-tool-behavior) | No |
| `ListMcpResourcesTool` | Lists resources exposed by connected MCP servers | No |
| `LSP` | Code intelligence via language servers. See [LSP tool behavior](#lsp-tool-behavior) | No |
| `Monitor` | Runs a background command or WebSocket, feeding output back as events. See [Monitor tool](#monitor-tool) | Yes |
| `NotebookEdit` | Modifies Jupyter notebook cells. See [NotebookEdit tool behavior](#notebookedit-tool-behavior) | Yes |
| `PowerShell` | Executes PowerShell natively. See [PowerShell tool](#powershell-tool) | Yes |
| `PushNotification` | Desktop notification + phone push via Remote Control. Not accessible on Bedrock, Google Cloud's Agent Platform, or Microsoft Foundry | No |
| `Read` | Reads file contents. See [Read tool behavior](#read-tool-behavior) | No |
| `ReadMcpResourceTool` | Reads a specific MCP resource by URI | No |
| `RemoteTrigger` | Creates/updates/runs/lists Routines on claude.ai; backs `/schedule`. Requires Pro/Max/Team/Enterprise; not on Bedrock/Google Cloud's Agent Platform/Microsoft Foundry | No |
| `ReportFindings` | Reports structured code-review findings (file, summary, failure scenario). Requires v2.1.196+. As of v2.1.199, a finding can carry an optional `category` slug | No |
| `ScheduleWakeup` | Reschedules the next self-paced `/loop` iteration (1min–1hr out); Claude calls it, not you. `stop: true` cancels the pending wakeup (requires v2.1.202+). Pending wakeup appears in `session_crons` in Stop hook input. Not on Bedrock/Google Cloud's Agent Platform/Microsoft Foundry (fixed schedule instead) | No |
| `SendMessage` | Sends a message to an agent-team teammate or resumes a subagent by ID/name; stopped subagents auto-resume in background. As of v2.1.198, a message from the launching agent is treated as task direction, not a peer request. As of v2.1.199, sending to a name that now resolves to a different agent is refused, not delivered | No |
| `SendUserFile` | Sends session files to the user with an optional caption. As of v2.1.196, `display` input controls presentation (`render`/`attach`/unset=client decides). Available with Remote Control connected or in a managed cloud env. Not on Bedrock/Google Cloud's Agent Platform/Microsoft Foundry | No |
| `ShareOnboardingGuide` | Uploads `ONBOARDING.md`, returns a share link; called from `/team-onboarding`. Pro/Max/Team/Enterprise only | Yes |
| `Skill` | Executes a skill within the main conversation | Yes |
| `TaskCreate` | Creates a task in the task list | No |
| `TaskGet` | Retrieves full details for a task | No |
| `TaskList` | Lists all tasks with status | No |
| `TaskOutput` | Retrieves background task output. Deprecated in favor of `Read` on the output file path. As of v2.1.203, a no-match error lists running background agents by ID/description (before: only the missing ID) | No |
| `TaskStop` | Stops a running background task by ID. As of v2.1.198, also accepts an agent-team teammate or named background agent by ID/name (before: only a background task ID). As of v2.1.203, a no-match error also lists background agents spawned by another agent (before: it didn't) | No |
| `TaskUpdate` | Updates task status/dependencies/details, or deletes tasks | No |
| `TodoWrite` | Manages the session task checklist. Disabled by default as of v2.1.142 in favor of `TaskCreate`/`TaskGet`/`TaskList`/`TaskUpdate`; set `CLAUDE_CODE_ENABLE_TASKS=0` to re-enable | No |
| `ToolSearch` | Searches for and loads deferred tools when tool search is enabled | No |
| `WaitForMcpServers` | Waits for MCP servers still connecting in the background. Only appears when tool search is disabled (`ToolSearch` handles the wait when enabled) | No |
| `WebFetch` | Fetches URL content. See [WebFetch tool behavior](#webfetch-tool-behavior) | Yes |
| `WebSearch` | Performs web searches. See [WebSearch tool behavior](#websearch-tool-behavior) | Yes |
| `Workflow` | Runs a dynamic workflow: a script orchestrating many subagents in the background, returning one consolidated result | Yes |
| `Write` | Creates/overwrites files. See [Write tool behavior](#write-tool-behavior) | Yes |

Custom tools come from connecting an [MCP server](/en/mcp). Reusable prompt-based workflows are [skills](/en/skills), which run through `Skill` rather than adding a new tool entry. The [advisor tool](/en/advisor) is an API server tool, not a Claude-Code-implemented tool — it has no name referenceable in permission rules or hook matchers.

Tool names are referenced in: `permissions.allow`/`permissions.deny` in settings (and `/permissions`); `--allowedTools`/`--disallowedTools` CLI flags; Agent SDK `allowedTools`/`disallowedTools`; a subagent's `tools`/`disallowedTools` frontmatter; a skill's `allowed-tools` frontmatter; a hook's `if` condition.

## Permission rule formats

All contexts above accept the same rule format, `ToolName(specifier)`. Several tools share a specifier format:

| Rule format | Applies to | Notes |
| :--- | :--- | :--- |
| `Bash(npm run *)` | Bash, Monitor | Command pattern matching |
| `PowerShell(Get-ChildItem *)` | PowerShell | Command pattern matching |
| `Read(~/secrets/**)` | Read, Grep, Glob, LSP | Path pattern matching |
| `Edit(/src/**)` | Edit, Write, NotebookEdit | Path pattern matching |
| `Skill(deploy *)` | Skill | Skill name matching |
| `Agent(Explore)` | Agent | Subagent type matching |
| `WebFetch(domain:example.com)` | WebFetch | Domain matching |
| `WebSearch` | WebSearch | No specifier — allow/deny the whole tool |

- Tools not listed here (e.g. `ExitPlanMode`, `ShareOnboardingGuide`) accept **only the bare tool name**, no specifier.
- An `Edit(...)` allow rule also grants read access to the same path — no separate `Read(...)` rule needed.
- Hook `matcher` fields use **bare tool names**, not the parenthesized rule format.

## Agent tool behavior

Subagent works autonomously in a separate context window; parent sees only the final text result, not intermediate tool calls. Cap turns via `maxTurns` in the subagent definition.

Fork mode uses the same Agent tool: a fork inherits the full parent conversation, always runs in the background, and still surfaces permission prompts in your terminal.

Tool access resolution (named subagents):

| `tools` set | `disallowedTools` set | Result |
| :--- | :--- | :--- |
| No | No | Inherits every parent tool |
| Yes | No | Only the listed tools |
| No | Yes | Every parent tool except the listed ones |
| Yes | Yes | `disallowedTools` wins; a tool in both is removed |

Launching a subagent itself never prompts for permission — Claude Code checks the subagent's own tool calls against permission rules as it runs.

As of v2.1.198, subagents run in the background by default; foreground only when Claude needs the result before continuing.

- **Foreground**: same permission prompts as the main conversation, at the moment of each tool call.
- **Background**: as of v2.1.186, prompts surface in your main session, naming the asking subagent; Esc denies just that call without stopping the subagent. Before v2.1.186, background subagents silently auto-denied any prompting tool call and continued without it.

## Bash tool behavior

Each command runs in a separate process.

- **cwd carry-over**: a `cd` in the main session carries to later Bash commands as long as it stays inside the project dir or an added directory (`--add-dir`, `/add-dir`, `additionalDirectories`). Subagent sessions never carry over cwd changes. Landing outside those dirs resets to the project dir and appends `Shell cwd was reset to <dir>` to the result. Disable carry-over entirely with `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1`.
- **Env vars don't persist** across commands — an `export` in one command isn't visible to the next.
- **Aliases/functions persist**: at session start, Claude Code sources `~/.zshrc`, `~/.bashrc`, or `~/.profile` (by shell), captures aliases/functions/shell options, and applies them to every Bash command.
- To persist env vars across commands, set `CLAUDE_ENV_FILE` to a shell script before launch, or populate it dynamically via a SessionStart hook.
- **Timeout**: 2 minutes default; Claude can request up to 10 minutes via `timeout` param. Override default/ceiling with `BASH_DEFAULT_TIMEOUT_MS`/`BASH_MAX_TIMEOUT_MS`.
- **Output length**: 30,000 chars default; beyond that, full output saved to a file with a path + short preview given to Claude. Raise with `BASH_MAX_OUTPUT_LENGTH`, hard ceiling 150,000 chars.
- Long-running commands can set `run_in_background: true`; list/stop via `/tasks`.

## Edit tool behavior

Exact string replacement (`old_string` → `new_string`); no regex, no fuzzy matching. Three checks, in order:

1. **Read-before-edit**: file must have been Read in the current conversation and unchanged on disk since. Viewing via Bash also satisfies this when the command is `cat`, `head`, `tail`, `sed -n 'X,Yp'`, `grep`, `egrep`, or `fgrep` on a single file with no pipes/redirects — piped output and other Bash commands don't count.
2. **Match**: `old_string` must appear exactly as written; a single whitespace/indentation difference misses.
3. **Uniqueness**: `old_string` must appear exactly once, or Claude supplies more context, or sets `replace_all: true`.

This affects edit eligibility only, not permissions. Read/Edit deny rules also apply to file-reading Bash commands Claude Code recognizes (`cat`, `head`, `tail`, `sed`, `grep`) but not to arbitrary subprocesses (e.g. a Python/Node script opening files itself). The recognized-command set differs from the read-before-edit set: `egrep`/`fgrep` count for read-before-edit but aren't checked against Read deny rules. For OS-level enforcement covering every process, enable the [sandbox](/en/sandboxing).

## Glob tool behavior

Standard glob syntax incl. `**` for recursive matching (`**/*.js`, `src/**/*.ts`, `*.{json,yaml}`). Results sorted by modification time, **capped at 100 files** — a truncation flag signals when the cap was hit, so Claude can narrow the pattern.

**Does not respect `.gitignore` by default** — finds gitignored files alongside tracked ones. Set `CLAUDE_CODE_GLOB_NO_IGNORE=false` to make it respect `.gitignore`.

## Grep tool behavior

Built on ripgrep — **ripgrep regex syntax, not POSIX grep** (e.g. `interface\{\}` to match `interface{}` in Go).

Three output modes: `files_with_matches` (default, paths only), `content` (matching lines + file/line number), `count` (match count per file). Scope with `glob` (e.g. `**/*.tsx`) or `type` (e.g. `py`, `rust`); `multiline: true` matches across line boundaries (default: single-line).

**Respects `.gitignore`** — gitignored files are skipped by default; pass a gitignored file's path directly to search it.

## LSP tool behavior

Code intelligence from a running language server. After each edit, automatically reports type errors/warnings. Direct calls: jump to definition, find references, get type info, list file symbols, search symbols workspace-wide, find interface implementations, trace call hierarchies. Inactive until a [code intelligence plugin](/en/discover-plugins#code-intelligence) is installed for the language (plugin bundles server config; server binary installed separately).

## Monitor tool

Requires Claude Code v2.1.98+. Watches a background command or WebSocket and interjects with events without pausing the conversation (tail logs, poll CI/PR status, watch a directory, track long-running scripts). For most watches Claude writes/runs a small script and gets each output line; for servers that already push events, it can open a WebSocket instead.

- **Permission rules**: a Monitor command reuses the [same Bash permission rules](/en/permissions#tool-specific-permission-rules) (`allow`/`deny` patterns set for Bash apply here too).
- **Unavailable**: on Amazon Bedrock, Google Cloud's Agent Platform, Microsoft Foundry, or when `DISABLE_TELEMETRY` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` is set.
- Plugins can declare monitors that auto-start when the plugin is active (`monitors/monitors.json`) — no need to ask Claude to start them.

**WebSocket source** (requires v2.1.195+): takes a `ws` input in place of `command` (can't combine in one call).

| Field | Required | Description |
| :--- | :--- | :--- |
| `url` | Yes | `ws://` or `wss://` endpoint; no embedded credentials/whitespace, ASCII only |
| `protocols` | No | Subprotocol names offered during handshake; no duplicates |

- Text messages: one event each, even multiline.
- Binary messages: not passed through — Claude gets a placeholder (`[binary frame, 512 bytes]`).
- Messages >1 MiB: watch ends — subscribe to a filtered feed instead.
- Socket close: watch ends, Claude receives the close code.
- `timeout_ms`/`persistent`/`TaskStop` behave same as for a command.
- Opening a WebSocket **prompts for approval every time** — no "don't ask again for this host" option.
- **Private-address denial**: Claude Code denies URLs pointing at a private, link-local, or cloud-metadata address (incl. hostnames resolving to one), hosts in `sandbox.network.deniedDomains`, and — when `allowManagedDomainsOnly` is set in managed settings — any host outside the managed allowlist.

## NotebookEdit tool behavior

Modifies a notebook one cell at a time, targeting by `cell_id` — not string replacement across the notebook like Edit. Three modes: `replace` (default, overwrite cell source), `insert` (add cell after target; no `cell_id` → inserts at notebook start; requires `cell_type: code|markdown`), `delete` (remove target cell).

**Permission rules use the `Edit(...)` path format** — e.g. `Edit(notebooks/**)` covers NotebookEdit calls on files in that directory.

## PowerShell tool

Enablement matrix:

| Platform | Default | Opt in/out |
| :--- | :--- | :--- |
| Windows without Git Bash | Enabled automatically | `CLAUDE_CODE_USE_POWERSHELL_TOOL=0` to disable |
| Windows with Git Bash | Rolling out progressively | `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`/`0` |
| Linux, macOS, WSL | Opt-in | `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`; requires `pwsh` (PowerShell 7+) on `PATH` |

```json
{
  "env": {
    "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1"
  }
}
```

On Windows, auto-detects `pwsh.exe` (7+) with fallback to `powershell.exe` (5.1). When enabled, PowerShell becomes the primary shell; Bash stays available for POSIX scripts if Git Bash is installed.

**Execution policy**: spawned with `-ExecutionPolicy Bypass` at **process scope only** — doesn't override Group Policy `MachinePolicy`/`UserPolicy` (enterprise policies still apply). Set `CLAUDE_CODE_POWERSHELL_RESPECT_EXECUTION_POLICY=1` to respect the machine's effective policy instead.

**Shell selection elsewhere**:

| Setting | Effect | Requires |
| :--- | :--- | :--- |
| `"defaultShell": "powershell"` in settings.json | Routes interactive `!` commands through PowerShell | PowerShell tool enabled |
| `"shell": "powershell"` on a command hook | That hook runs in PowerShell | Nothing — hooks spawn PowerShell directly regardless of `CLAUDE_CODE_USE_POWERSHELL_TOOL` |
| `shell: powershell` in skill frontmatter | `` !`command` `` blocks run in PowerShell | PowerShell tool enabled |

Same main-session cwd-reset behavior as Bash applies, including `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR`. As of v2.1.196, PowerShell matches Bash's exit-code handling: exit 1 from `grep`/`egrep`/`fgrep`/`git grep` means no matches, exit 1 from `git diff` means differences exist — neither reported as a command failure.

**Preview limitations**: PowerShell profiles not loaded; sandboxing not supported on Windows.

## Read tool behavior

Takes a file path, returns contents with line numbers. Claude is instructed to always pass absolute paths.

- **Partial view**: default returns from the start. A whole-file read exceeding the token limit returns the first page with a `PARTIAL view` notice (how much was received, how to get more via `offset`/`limit`). A read with an explicit `offset`/`limit` that still exceeds the limit errors instead.
- **Images**: returned as visual content, not raw bytes; large images resized/recompressed to fit model image-size limits. As of v2.1.196, an image still >500KB after resize is re-encoded as reduced-quality JPEG (pixel dimensions unchanged). For fine pixel detail, crop first (e.g. via ImageMagick over Bash).
- **PDFs**: short files read whole; files >10 pages read in ranges via `pages` param (e.g. `"1-5"`), up to 20 pages at a time.
- **Notebooks**: `.ipynb` returns all cells with outputs (code, markdown, visualizations).
- Files only, not directories — use `ls` via Bash for directory listings.

## WebFetch tool behavior

Fetches a URL + extraction prompt; converts HTML responses to Markdown, runs the prompt against the content using a small fast model. Claude normally receives that model's answer, not the raw page — **lossy by design**. A result saying a page doesn't mention something may only mean the prompt didn't ask about it; re-fetch with a more specific prompt, or use `curl` via Bash for the unprocessed page. The conversion step is not configurable.

- HTTP auto-upgraded to HTTPS; large pages truncated to a fixed char limit; responses cached 15 minutes.
- **Redirects to a different host are not followed** — WebFetch returns a text result naming the original URL and the redirect target; Claude issues a second WebFetch call for the new URL.
- **Domain approval**: in default/`acceptEdits` modes, prompts the first time it reaches a new domain, except a built-in preapproved set of documentation domains. Add `WebFetch(domain:example.com)` to allow a domain without prompting. `auto`/`bypassPermissions` modes skip the prompt entirely.
- An explicit `WebFetch(domain:...)` rule in `deny`/`ask`/`allow` **takes precedence over the preapproved set** — can block a preapproved domain or force a prompt for it.
- Sets `User-Agent: Claude-User...` and an `Accept` header preferring Markdown.
- Sandbox network rules are configured separately — a domain WebFetch can reach still needs its own sandbox permission rule for sandboxed processes.

## WebSearch tool behavior

Queries Anthropic's web search backend; returns result titles/URLs only, doesn't fetch pages (follow up with WebFetch). Up to 8 backend searches per call, refined internally. Scope with `allowed_domains` or `blocked_domains` — the two lists can't be combined in one call. Backend isn't configurable; add an MCP server for a different search provider.

**Permission rule takes no specifier** — bare `WebSearch` in `allow`/`deny` is the only form.

Availability: Claude API, Claude Platform on AWS, Microsoft Foundry. Google Cloud's Agent Platform: Claude 4+ models only. Amazon Bedrock: not exposed.

## Write tool behavior

Creates a new file, or fully overwrites an existing one — no append/merge. If the target path already exists, Claude must have Read it at least once in the current conversation first; an unread-file overwrite errors. Doesn't apply to new files. Viewing via Bash satisfies this under the same rules as [Edit's read-before-edit](#edit-tool-behavior). For partial changes to an existing file, use Edit instead.
