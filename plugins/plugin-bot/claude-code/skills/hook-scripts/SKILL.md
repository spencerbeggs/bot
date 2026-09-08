---
name: hook-scripts
description: Enforces the house hook-script contract when a hook script or a hook registration is opened for authoring or review — Claude Code's hooks/hooks.json, Copilot's root hooks.json and .github/hooks/*.json, and any hooks/**/*.sh or hooks/**/*.bash. Covers the per-host exit-code contracts (which are not the same contract and not universal within a host), the registration-shape and event-vocabulary deltas, portable plugin-root resolution, subdirectory-per-event layout, lib helpers, fixtures, silent-truncation traps, and BATS coverage.
user-invocable: false
paths:
  - "**/hooks/**/*.sh"
  - "**/hooks/**/*.bash"
  - "**/hooks.json"
  - "**/hooks/*.json"
---

# Hook script checklist

Apply this to the file you just opened. The mistake that matters most: **treating exit 2 as a universal blocking signal.** It is not universal on either host — under Claude Code two events opt out of it entirely, and under Copilot it is a warning everywhere except two events. The second: writing state under the plugin root, which is ephemeral on plugin update.

Hooks fail *silently*. A wrong rule here does not throw — the gate simply never closes. Verify against the references below rather than from memory.

## Which layer are you in?

Read the target off the path before applying any rule. A rule marked for the other layer does not apply.

| Path shape | Layer | Registration file |
| :-- | :-- | :-- |
| `plugins/*/claude-code/**`, or `hooks/hooks.json` under a `.claude-plugin/` plugin | Claude Code | `hooks/hooks.json` |
| `plugins/*/copilot/**`, or `.github/hooks/*.json`, or `~/.copilot/hooks/*.json` | Copilot | for a plugin, root `hooks.json` or the path the manifest's `hooks` field names; for the repo and user scopes, the matched file itself |
| A JSON file whose top level is `{ "version": 1, …, "hooks": {…} }` | Copilot | that file |
| A JSON file whose top level is a bare event map | Claude Code | that file |

Hooks are **outside Agent Plugins 1.0 entirely** — the spec leaves them to the hosts, so there is no portable third dialect to write and no portable manifest can carry a hook. A plugin that must hook both hosts ships two registration files; only the script bodies are shared. See `agent-plugins-docs/references/agent-plugins-spec.md`.

The `**/hooks.json` and `**/hooks/*.json` globs are deliberately bare: between them they catch Claude's `hooks/hooks.json`, Copilot's root `hooks.json`, `.github/hooks/*.json` and `~/.copilot/hooks/*.json` without enumerating install layouts. The cost is false positives — confirm the file is a hook registration before applying a rule, because `hooks/*.json` also matches ordinary project JSON.

**Known blind spot: inline `hooks` blocks in settings files.** Copilot also reads hook registrations from a `hooks` block inside `.github/copilot/settings.json`, `~/.copilot/settings.json` or `.claude/settings.json` (`copilot-docs/references/hooks-reference.md` § Discovery), and Claude Code from its own settings files. No glob here matches those — `**/settings.json` would over-trigger on every unrelated settings file in a repo. **Every rule below still applies to a hook you author there; nothing will load this checklist for you.** Read it deliberately when editing an inline `hooks` block.

## Shared checklist

Applies to hook scripts under either host — these are house rules, not a host contract, except where a reference is named.

1. **Path is `hooks/<event-kebab>/<name>.sh`**, not flat `hooks/<event-kebab>-<name>.sh`. Subdirectory-per-event is the house layout — it makes `**/hooks/pre-tool-use/**/*.sh`-style globs unambiguous and lets sibling path-skills key off the directory name. Use the Claude event's kebab spelling for the directory even in a Copilot-targeted plugin, so one script tree serves both registrations.
2. **`set -euo pipefail`** present — and see § Common mistakes for the two command-substitution forms it silently does not cover; fails open when `jq` is missing — a hook that cannot parse its envelope must not block the user. Fail open means `emit_noop; exit 0`, never `exit 2` and never a bare non-zero.
3. **Sources shared helpers from `hooks/lib/`** (`hook-output.sh` for `emit_noop`/response emitters, `hook-debug.sh` for `hook_error`/`hook_debug`, `source-session-env.sh` for lateral env) rather than reimplementing them inline.
4. **Decision via JSON; the happy path exits 0.** Emit a response object (or plain-text context where the event accepts it) and let exit 0 carry it. Reserve non-zero exits for deliberate signaling — and only after checking the per-host, per-event rules below, because "non-zero" means four different things across the two hosts.
5. **No `cmd || true` followed by a `$?` check** — dead code, `true` always succeeds. Capture with `out=$(cmd 2>&1) || rc=$?`.
6. **Plugin-owned paths resolve through the portable chain below, never dirname-walking or bare relative paths.** State, cache and logs go in the plugin *data* directory, not the plugin install. Under Claude Code that is `${CLAUDE_PLUGIN_DATA}`, which resolves to `~/.claude/plugins/data/<plugin>-<marketplace>/` (e.g. `dogfood-inline`), NOT `~/.claude/plugins/data/<plugin>/` — never write the bare-plugin-name path into a fallback or comment. Copilot defines `${CLAUDE_PLUGIN_DATA}` as an alias of `${COPILOT_PLUGIN_DATA}`, so the data spelling *is* portable across those two; `${PLUGIN_DATA}` is Agent-Plugins-only and yields a literal unexpanded string on Copilot. See `agent-plugins-docs/references/cross-client-behavior.md` § Placeholder vocabulary.
7. **Third-party CLI calls (`gh`, `aws`, `kubectl`, …) reviewed against `shelling-out-from-plugins`** — env hygiene at every call site, not just the auth check.
8. **BATS coverage exists.** Every hook script has at least one fixture at `hooks/fixtures/<event>.<scenario>.json` — `<event>` lowercased, no separators (e.g. `posttooluse.write.json`, not `post-tool-use.write.json`) — and a `__test__/<event-kebab>-<name>.bats` at the plugin root asserting the happy path and the no-op path.
9. **Every `command` in a registration is quoted and anchored to a plugin-root placeholder** — bare relative paths break once the plugin is invoked from outside its own directory. Get the spelling from the layer's row in the placeholder table, not from memory.
10. **Prefer exec form over shell form for any registration referencing a path placeholder.** Claude Code's exec form is an `args` array; Copilot's is `exec` + `args`, which is mutually exclusive with `bash`/`powershell`/`command` and requires `args`. Exec form needs no quoting for spaces or special characters; shell form requires wrapping each placeholder in double quotes. Reserve shell form for pipes, `&&` and redirects.

## The exit-code contract — per host, per event, never universal

### Claude Code: four rules, and they only work as a unit

`anthropic-docs/references/hooks.md` § Exit-code contract states the contract; do not restate it from memory, and do not carry any one of these four without the other three.

1. **Exit 2 blocks on blocking events, and valid JSON cannot override it.**
2. **`PermissionRequest` ignores exit 2 entirely** — the permission flow proceeds unchanged. To deny, return a `decision` object.
3. **`WorktreeCreate` aborts on ANY non-zero exit**, whatever the JSON says.
4. **On standard-decision-model events only**, a non-zero exit other than 2 that carries valid JSON has its JSON honored and its exit code ignored.

Rule 4's opening scope qualifier is load-bearing. Drop it and rules 2 and 3 both break, along with `StopFailure` and the other events that discard hook output — those sit outside the standard decision model and keep their own rows in that reference's per-event exit-2 table. Read the row for your event before reaching for a non-zero exit.

> **Without valid JSON on stdout**, Claude Code treats exit 1 as a non-blocking error and the action proceeds, despite the Unix convention. With valid JSON, rule 4 applies and the JSON decides.

That callout is only true with its opening qualifier and only alongside the four rules above. **Never lift it out on its own** — detached, it reads as an unconditional claim about exit 1 and is then wrong for `WorktreeCreate` and for every standard-decision-model event that prints JSON.

The practical consequence for a script: reach for exit 2 to enforce a policy through the exit code alone, but check the event's row first, and prefer emitting the event's decision JSON at exit 0 — that path is the one whose meaning does not shift per event.

### Copilot: a different contract with a different shape

`copilot-docs/references/hooks-reference.md` § Exit codes is the source. Summarised, not restated in full:

- `0` — success; stdout is parsed as the hook output JSON.
- `2` — **a warning by default**, not a block: stderr is surfaced and the run continues. It is a **denial for `preToolUse` and `permissionRequest` only** (for `permissionRequest`, stdout is merged with `{"behavior":"deny"}`), and on `postToolUseFailure` it is read as `additionalContext` with stdout appended.
- Other non-zero — logged, execution continues, **except `preToolUse`, which is fail-closed** on non-zero exits and on crashes.
- Timeout — **always fails open, even for `preToolUse`**.

The asymmetry to memorise: a `preToolUse` policy hook blocks when it *fails* but not when it *hangs*. It cannot wedge the agent, and equally cannot be relied on as a hard gate.

**Do not carry a Claude exit-code habit across.** Exit 2 from a ported `PostToolUse` warning hook still warns under Copilot; exit 2 from a ported blocking `Stop` hook does not block, because `agentStop` is not one of the two events that read 2 as denial.

## Portable plugin-root resolution

Resolve a chain; do not trust one variable. No single spelling resolves on all three layers.

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-${MYPLUGIN_PLUGIN_ROOT:-}}}"
```

The reason, not just the rule:

- `${CLAUDE_PLUGIN_ROOT}` is defined by Claude Code, which also exports it into the spawned process's environment. Copilot accepts it per the VS Code page, but it is **absent from the Copilot CLI reference's substitution table** — so treat Copilot coverage as the weaker of the two claims and let the next element catch it.
- `${PLUGIN_ROOT}` is defined by Copilot and by Agent Plugins 1.0, and is not defined by Claude Code.
- **Their intersection is empty**, which is the whole reason for the chain: neither one alone spans the layers.
- The third element is the namespaced fallback your own `SessionStart` hook exported (`export MYPLUGIN_PLUGIN_ROOT=…` into `$CLAUDE_ENV_FILE`), for subshells and later Bash-tool calls that inherit neither host variable. Name it after your plugin; a generic third element collides with another plugin's.

Substitute your plugin's own prefix for `MYPLUGIN`. See `agent-plugins-docs/references/cross-client-behavior.md` § Placeholder vocabulary for the full matrix and for which sites each token expands in — under Agent Plugins these are `mcp.json` expansions rather than general environment variables, though `PLUGIN_ROOT` and `PLUGIN_DATA` are additionally set in the launched subprocess's environment.

**The corollary worth acting on: a Claude-authored hook script written with this chain needs no placeholder rewrite to run under Copilot.** The port work is the registration wrapper and the event vocabulary — not the script bodies. Budget the port accordingly: rewrite `hooks.json`, keep `hooks/**/*.sh`.

## Layer deltas

### Registration shape — what to change when porting

Every cell in the Copilot column is an edit to make, not a fact to note. Rosters and handler lists here are enumerations; the citations beside them are the authority.

| | Claude Code | Copilot — do this |
| :-- | :-- | :-- |
| Location | `hooks/hooks.json` | Move it to root `hooks.json` and point the manifest's `hooks` field at it (`plugin-reference.md` § component paths) |
| Shape | bare event map | Wrap the map: `{ "version": 1, "hooks": {…} }`. `version` is required and must be `1`; `disableAllHooks` is optional and defaults to `false` |
| Events | 33, PascalCase (`hooks.md` § Event table and cadence) | Remap to the 14 camelCase names in `hooks-reference.md` § The 14 events, and **drop the events with no counterpart**. Do not assume a rename is mechanical: `UserPromptSubmit` → `userPromptSubmitted`, `Stop` → `agentStop` |
| Event spelling | — | You may keep the PascalCase alias where one exists, but then **Claude matcher semantics apply** to that entry (`hooks-reference.md` § Matcher semantics). Pick one spelling per entry deliberately; do not mix within a file by accident |
| Handlers | `command`, `http`, `mcp_tool`, `prompt`, `agent` (`hooks.md` § Hook handler types) | `command`, `http`, `prompt` only (`hooks-reference.md` § Handler types). **Re-express an `mcp_tool` or `agent` handler as a `command` handler** — there is nothing to port them to |
| `prompt` handlers | Fire on the matched event | Fire **only on a new interactive session** — not on resume, not in pipe mode (`-p`), CLI only. If the behavior must be reliable, rewrite it as a `command` handler |
| Output | nested `hookSpecificOutput.*`, `updatedInput` | Flatten it: `permissionDecision` / `modifiedArgs` (`preToolUse`), `modifiedResult` (`postToolUse`), `behavior` (`permissionRequest`). Field-by-field roster in `hooks-reference.md` § Output schemas |
| Timeout key | `timeout` | Rename to `timeoutSec` (default 30; a `timeout` alias is accepted only when `timeoutSec` is absent) |
| `http` URLs | Governed by the `allowedHttpHookUrls` allowlist | Ensure the URL is `https://`. `http://localhost`, `http://127.*` and `http://[::1]` are exempt **only** with `COPILOT_HOOK_ALLOW_LOCALHOST=1`; setting `allowedEnvVars` forces `https://` regardless, localhost included; and on `preToolUse` and `permissionRequest` the requirement is **unconditional** — the loopback exemption does not reach those two, because the response can grant tool permissions (`hooks-reference.md` § `http`) |

### Hook sources accumulate on both hosts — nothing is shadowed

Under Copilot: *"When the same event appears in multiple sources, all hook entries from all sources are run."* There is no shadowing. A repository- or user-scope hook does **not** replace a plugin's hook on the same event; both fire. Two consequences bite:

- **A `preToolUse` deny in *any* source wins.** You cannot relax a stricter hook by shipping a permissive one at a different scope.
- **A side-effecting hook registered at two scopes runs twice** — ship a `postToolUse` logger that the repo also ships, and every tool call is logged twice.

**Copilot's load order is stated inconsistently upstream and is recorded as unresolved** — the prose says policy, user, project, plugins; the page's own enumeration puts repository before user. Neither is marked authoritative; assert neither. It does not matter for whether a hook fires, because every entry runs regardless. If you catch yourself reasoning "mine loads later, so theirs is ignored", the premise is wrong whichever order is right. See `copilot-docs/references/hooks-reference.md` § Discovery.

Claude Code merges rather than replaces too, with one wrinkle that is not Copilot's rule: the same handler defined in more than one **settings file** runs once, while a plugin's or skill's copy of that handler stays separate and runs on its own (`anthropic-docs/references/hooks.md` § Hook locations, § Hook handler types). So the "runs twice" hazard exists on both hosts for a plugin hook; only Claude's settings-file dedupe differs.

### Silent truncation — the plugin `SessionEnd` budget

Claude Code's `SessionEnd` hooks share a **1.5-second budget**, and **a `timeout` set on a plugin-provided hook does not raise it.** A plugin `SessionEnd` hook with `"timeout": 10` still gets 1.5 s, and the failure is silent: the hook is cancelled and its output discarded, so it renders no decision and reports no error. Only the user's `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` raises the budget, and a plugin cannot set that on its own behalf. Design plugin `SessionEnd` work to finish inside 1.5 s or hand it to a detached process. Full statement in `anthropic-docs/references/hooks.md` § Timeouts.

## Per-event pointer table — Claude Code

Read `hooks.md` for the system-wide rules that apply to every event; read `hook-events.md` for the specific event's input/output schema. Group first, then follow the row:

| Event group | Events | Read in `hook-events.md` |
| --- | --- | --- |
| Session lifecycle | `SessionStart`, `Setup`, `InstructionsLoaded`, `SessionEnd` | matching `##` heading; for `SessionStart` and `Setup` only, also `hooks.md` § CLAUDE_ENV_FILE — `$CLAUDE_ENV_FILE` is available to exactly four events, and `InstructionsLoaded` and `SessionEnd` are **not** among them |
| Prompt / display | `UserPromptSubmit`, `UserPromptExpansion`, `MessageDisplay` | matching `##` heading |
| Tool-use control | `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `PermissionDenied` | matching `##` heading; also `hooks.md` § Decision-control summary and § Rewrite capabilities |
| Subagent | `SubagentStart`, `SubagentStop` | matching `##` heading; also `hooks.md` § Hooks in skills and agents |
| Task | `TaskCreated`, `TaskCompleted` | matching `##` heading |
| Turn end | `Stop`, `StopFailure`, `TeammateIdle` | matching `##` heading |
| Environment change | `ConfigChange`, `CwdChanged`, `FileChanged`, `WorktreeCreate`, `WorktreeRemove` | matching `##` heading; for `CwdChanged` and `FileChanged` only, also `hooks.md` § CLAUDE_ENV_FILE. Note `WorktreeCreate` sits outside the standard decision model — see rule 3 above |
| Compaction | `PreCompact`, `PostCompact` | matching `##` heading |
| Elicitation | `Elicitation`, `ElicitationResult` | matching `##` heading |
| Notification | `Notification` | matching `##` heading |

For matcher syntax, handler types and the exit-code contract itself, read `hooks.md` regardless of event — those are shared across events, not per-event. Copilot's equivalents live in `hooks-reference.md`; its matcher rules and its per-event matcher subjects are not Claude's.

## Claude Code JSON-output rules

- **`hookSpecificOutput.hookEventName` is required whenever `hookSpecificOutput` is populated**, and must match the firing event.
- **`updatedInput` is a full replacement.** Every unchanged field must be echoed back or it is dropped. There is no merge.
- Copilot has neither field. Its output is flat, and an empty output means "no opinion" and falls through to the default.

## Subagent-hook gotcha

Under `context: fork`, Claude Code **reuses the parent's `session_id`** — a `SubagentStart`/`SubagentStop` hook that keys storage on `session_id` alone collides across dispatches. House fix: at `SubagentStart`, mint a synthetic per-dispatch key (`${session_id}-subagent-$(date +%s)-$$`) and persist an `agent_id → key` mapping (state file). `SubagentStop` payloads carry only `agent_type`/`agent_id`, never the synthetic key, so `SubagentStop` must look the key up via that mapping, not regenerate it.

## Common mistakes

- Treating exit 2 as a universal block. It is not universal under Claude Code (`PermissionRequest` ignores it; `WorktreeCreate` blocks on any non-zero) and it is a warning by default under Copilot.
- Quoting the exit-1 callout without its "Without valid JSON on stdout" qualifier, or without the four rules it belongs to.
- Carrying rule 4 without "on standard-decision-model events only" — which silently re-breaks `PermissionRequest`, `WorktreeCreate` and `StopFailure`.
- `exit 1` in a Copilot `preToolUse` hook expecting it to be logged and ignored — that event is fail-closed.
- Assuming a repository-scope Copilot hook shadows the plugin's. Both run.
- Pointing a Copilot `preToolUse` or `permissionRequest` `http` handler at a loopback URL. `COPILOT_HOOK_ALLOW_LOCALHOST=1` does not reach those two events; the endpoint that serves your `postToolUse` logger in development is rejected there.
- Writing `${COPILOT_PLUGIN_ROOT}` — defined by nothing, expands to nothing, and the hook fails silently rather than erroring. This does **not** generalize to the `COPILOT_*` prefix: `${COPILOT_PLUGIN_DATA}` is real and documented.
- Trusting a bare `${CLAUDE_PLUGIN_ROOT}` or a bare `${PLUGIN_ROOT}` in a script meant to run on more than one host — resolve the chain.
- Rewriting script bodies during a Claude → Copilot port. Rewrite the registration; the bodies port as-is once they resolve the chain.
- A plugin `SessionEnd` hook with a raised `timeout` — silently truncated at 1.5 s.
- Empty stdout instead of an explicit `emit_noop` — both work, but `emit_noop` survives schema tightening.
- `permissionDecision: "block"` — not a valid value, it's `"deny"`.
- `local out="$(cmd)"`, or a substitution passed as an argument (`emit_context PostToolUse "$(build_ctx)"`) — **`set -e` does not see either one fail.** The status it checks is `local`'s, or the outer command's, never the substitution's, so a failed command yields an empty string that flows onward as the hook's decision data. A bare `out="$(cmd)"` on its own line *is* caught. Split the declaration from the assignment — `local out=""`, then `out="$(cmd)" || { hook_error <name> "..."; emit_noop; exit 0; }` — and add a non-empty guard wherever empty is not a valid result. This is where checklist item 2 stops protecting you: a hook that already fails silently now fails twice over, and the gate reports a clean decision it never computed. Full treatment: `skill-scripts` § Common mistakes.
- Helper logic written inline in the hook body instead of `hooks/lib/<helper>.sh`.
- `export FOO=bar` expecting a later Bash-tool call to see it — `$CLAUDE_ENV_FILE` is available to exactly four events (`SessionStart`, `Setup`, `CwdChanged`, `FileChanged`); every other event needs `lib/source-session-env.sh`.
- `SessionStart` writing to `$CLAUDE_ENV_FILE` without a grep guard — `/resume` re-fires `SessionStart`, so ungated `export` lines accumulate duplicates. Guard every write: `grep -q "^export FOO=" "$CLAUDE_ENV_FILE" 2>/dev/null || printf 'export FOO=%q\n' "$val" >> "$CLAUDE_ENV_FILE"`.
- MCP `tool_response` treated as a single object in `PostToolUse` — it's an array.

## Read for the full contract

Claude Code layer:

- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/hooks.md` — locations and merge rules, matcher rules, the five handler types, the four-rule exit-code contract and the per-event exit-2 table, JSON output fields, timeouts and the plugin `SessionEnd` budget, `CLAUDE_ENV_FILE`, async hooks, debugging.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/hook-events.md` — per-event input/output schema, matcher values, decision-control fields.

Copilot layer:

- `${CLAUDE_PLUGIN_ROOT}/skills/copilot-docs/references/hooks-reference.md` — the wrapped `hooks.json` shape, the 14 events and their PascalCase variants, the three handler types, matcher semantics under both spellings, output schemas, the exit-code table, the accumulate rule and the unresolved load order, cloud-agent constraints.
- `${CLAUDE_PLUGIN_ROOT}/skills/copilot-docs/references/plugin-reference.md` — the manifest's `hooks` field and where a plugin's registration file may live.

Portable layer:

- `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/agent-plugins-spec.md` — hooks are outside Agent Plugins 1.0; there is no portable registration to write.
- `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/cross-client-behavior.md` — the placeholder vocabulary matrix behind the resolution chain, and which sites each token expands in.

Scaffolding a new plugin or retrofitting the layout and `hooks/lib/` helpers? Invoke the `plugin-setup` skill — it ships the tested lib templates and the bootstrap checklist.
