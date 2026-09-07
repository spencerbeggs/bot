# Copilot hooks reference

> Verified against <https://docs.github.com/en/copilot/reference/hooks-reference> — 2026-09-07

Hooks are shell commands, HTTP calls or prompts fired at agent lifecycle points. They are **outside the portable layer entirely** — Agent Plugins 1.0 leaves hooks to the hosts until their formats converge — so nothing here holds on any other client, and a Claude Code hook file is not a Copilot hook file even where the event names rhyme.

## Top-level shape

```json
{
  "version": 1,
  "disableAllHooks": false,
  "hooks": {
    "preToolUse": [
      { "type": "command", "bash": "./scripts/guard.sh", "matcher": "bash" }
    ]
  }
}
```

`version` is required and must be `1`. `disableAllHooks` defaults to `false`; setting it `true` skips every hook in that file. A repository `settings.json` flag (CLI only) disables all sources except policy hooks. **Policy hooks stay active regardless.**

## The 14 events

| camelCase | PascalCase variant |
| :-- | :-- |
| `sessionStart` | `SessionStart` |
| `sessionEnd` | `SessionEnd` |
| `userPromptSubmitted` | `UserPromptSubmit` |
| `userPromptTransformed` | — |
| `preToolUse` | `PreToolUse` |
| `postToolUse` | `PostToolUse` |
| `postToolUseFailure` | `PostToolUseFailure` |
| `preCompact` | `PreCompact` |
| `agentStop` | `Stop` |
| `subagentStart` | — |
| `subagentStop` | `SubagentStop` |
| `permissionRequest` | `PermissionRequest` |
| `notification` | — (none documented; **Copilot CLI only**) |
| `errorOccurred` | `ErrorOccurred` |

The PascalCase spellings exist for VS Code / Claude-format compatibility, and they are not merely aliases: **under a PascalCase event name, Claude matcher semantics apply** (see below). Note that the two spellings diverge in more than case — `userPromptSubmitted` pairs with `UserPromptSubmit`, `agentStop` with `Stop`.

**Three events have no documented PascalCase form: `userPromptTransformed`, `subagentStart` and `notification`.** `notification` is documented in camelCase only, and it is **Copilot CLI only** — the page states it does not fire under the Copilot cloud agent.

## Handler types

### `command`

| Field | Notes |
| :-- | :-- |
| `bash` | Shell command. The only field the cloud agent honors. |
| `powershell` | PowerShell command. Ignored on the cloud agent. |
| `command` | Cross-platform fallback. |
| `exec` + `args` | Executable plus argument array, **no shell interpretation**. Mutually exclusive with the three shell fields; `exec` requires `args`. |
| `cwd` | Working directory. |
| `env` | Environment variables. |
| `timeoutSec` | **Default 30.** A `timeout` alias is accepted when `timeoutSec` is absent. |
| `matcher` | See matcher semantics. |

Specify exactly one of `bash`, `powershell`, `command`, or `exec`.

### `http`

| Field | Notes |
| :-- | :-- |
| `url` | Required. Must be `https://`, except `http://localhost`, `http://127.*` and `http://[::1]` when `COPILOT_HOOK_ALLOW_LOCALHOST=1` is set. **On `preToolUse` and `permissionRequest` the `https://` requirement is unconditional** — see below. |
| `headers` | Request headers; environment variables expand into values. |
| `allowedEnvVars` | Restricts which environment variables may expand in `headers`. **Setting it forces the `https://` requirement**, localhost exemption included. |
| `timeoutSec` | Default 30. |
| `matcher` | Matches `toolName`. |

**Two events opt out of the localhost exemption entirely.** For `preToolUse` and `permissionRequest`, the URL *"must use `https://` because the response can grant tool permissions"* — an additional, unconditional requirement layered on the general default above, not a restatement of it. `COPILOT_HOOK_ALLOW_LOCALHOST=1` does not relax it, so a loopback endpoint that works for a `postToolUse` logger is rejected on those two events. `allowedEnvVars` forces `https://` on every event, loopback included, by a separate route.

### `prompt`

```json
{ "type": "prompt", "prompt": "/review-diff" }
```

CLI only, and it fires **only on a new interactive session** — not on resume, and not in pipe mode (`-p`). The cloud agent may not fire prompt handlers reliably.

## Matcher semantics

A standard matcher compiles as `^(?:PATTERN)$` — anchored, case-sensitive, and it must match the **full** value. An invalid pattern silently skips that hook entry.

Under a **Claude-format (PascalCase) event name** the rules change: `*`, `**` or an empty string match every tool; a literal name or a `|`-separated alternation (`Bash|Edit`) matches Claude tool names; anything else is treated as `^(?:PATTERN)$` against Claude tool names. Copilot maps its own tool names onto Claude's for this — `bash`/`powershell` → `Bash`, `view` → `Read`, `create` → `Write`, `edit` → `Edit`.

What each event matches on:

| Event | Matcher matches |
| :-- | :-- |
| `preToolUse`, `postToolUse`, `permissionRequest` | `toolName` |
| `notification` | `notification_type` |
| `preCompact` | `trigger` — `"manual"` or `"auto"` |
| `subagentStart` | `agentName` |

## Output schemas

Fields are **flat, not nested under a wrapper key**. Empty output means "no opinion" and falls through to the default behavior.

| Event | Output |
| :-- | :-- |
| `preToolUse` | `{ permissionDecision, permissionDecisionReason, modifiedArgs }` — decision is `allow`, `deny` or `ask` |
| `postToolUse` | `{ modifiedResult: { resultType, textResultForLlm }, additionalContext }` |
| `agentStop` / `subagentStop` | `{ decision, reason, modifiedResponse }` — decision is `block` or `allow`; `modifiedResponse` is `subagentStop` only |
| `permissionRequest` | `{ behavior, message, interrupt }` — behavior is `allow` or `deny` |
| `userPromptSubmitted` | `{ modifiedPrompt }` — **honored only by SDK programmatic hooks**, never by config-file `command` or `http` handlers |
| `userPromptTransformed` | `{ modifiedTransformedPrompt }` — replaces what reaches the model and what is stored in history; the timeline display is unaffected |
| `notification` | `{ additionalContext }` — injected as a user message; fire-and-forget, never blocks |
| `sessionStart`, `sessionEnd`, `errorOccurred`, `preCompact`, `subagentStart` | No structured output |

`decision: "block"` on a stop event forces continuation, capped at **8 consecutive blocks** before the CLI overrides.

## Exit codes

| Code | Behavior |
| :-- | :-- |
| `0` | Success; stdout is parsed as the hook output JSON. |
| `2` | Warning by default. **`preToolUse` and `permissionRequest` treat it as a denial** — for `permissionRequest`, stdout is merged with `{"behavior":"deny"}`. On `postToolUseFailure` it is read as `additionalContext`. |
| Other non-zero | Logged; execution continues — **except `preToolUse`, which is fail-closed** on non-zero exits and on crashes. |
| Timeout | **Always fails open, even for `preToolUse`**, which then proceeds to the normal permission flow. |

That last asymmetry is the one worth memorizing: a `preToolUse` policy hook blocks when it fails, but *not* when it hangs. A slow or unreachable hook cannot silently wedge the agent, and equally cannot be relied on as a hard gate.

## Discovery — sources accumulate, they do not override

**The single most important fact about hook sources, and the one most likely to be assumed backwards:**

> "When the same event appears in multiple sources, all hook entries from all sources are run."

There is no shadowing. A repository-level hook does **not** replace a plugin's hook on the same event; both fire. Two consequences follow directly, and both bite:

- **A `preToolUse` deny in *any* source wins.** You cannot relax a stricter hook by shipping a permissive one at a different scope.
- **A side-effecting hook registered at two scopes runs twice.** If your plugin ships a `postToolUse` logger and the repository ships one too, every tool call is logged twice.

The sources themselves:

- **Policy files**, non-disableable: `/etc/github-copilot/policy.d/*.json` (Linux/macOS) or `C:\ProgramData\GitHub\Copilot\policy.d\*.json` (Windows). On POSIX these must be owned by root and neither group- nor world-writable.
- **Repository**: `.github/hooks/*.json`, plus an inline `hooks` block in `.github/copilot/settings.json` or `.claude/settings.json`.
- **User**: `~/.copilot/hooks/*.json`, plus an inline `hooks` block in `~/.copilot/settings.json`.
- **Plugins**: the plugin's declared `hooks.json` or `hooks/hooks.json`.

**Load order is stated inconsistently upstream and is recorded here as unresolved.** The page's prose says the sources load "policy, then user, then project, then plugins", while the page's own enumeration below that sentence puts repository-level files ahead of user-level files. Both readings are on the page; neither is marked authoritative, and this reference does not pick one.

**That ambiguity does not matter for whether a hook fires.** Because every entry from every source runs, load order determines nothing about precedence. Do not let a claim about ordering smuggle in a claim about shadowing — if you find yourself reasoning "mine loads later, so theirs is ignored", the premise is wrong regardless of which order is correct.

## Cloud agent constraints

The cloud agent is a materially smaller surface. Do not assume a working CLI hook runs there.

- **Only `.github/hooks/*.json` loads.** User-level hooks, plugin hooks and `settings.json` hooks are unavailable.
- Linux only: **`bash` is honored, `powershell` is ignored**; `command` acts as the fallback.
- **`permissionRequest` never fires** — the agent pre-approves. Use `preToolUse` instead, where `"ask"` is treated as `"deny"`.
- `notification` never fires; there is no user to notify. `preCompact` fires on automatic compaction only.
- Working directory is `/workspace` when a repository is cloned, otherwise `/root`. The filesystem is ephemeral and hook output is discarded at job end.
- Restricted network egress; GitHub and Copilot hostnames are allowed by default.
- `GITHUB_COPILOT_API_TOKEN`, `GITHUB_COPILOT_GIT_TOKEN` and `COPILOT_AGENT_PROMPT` are available. **`GITHUB_TOKEN` is not set.**
