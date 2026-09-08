---
name: skill-scripts
description: Enforces the house contract for scripts bundled inside a skill's scripts/ directory when one is opened for authoring or review — portable plugin-root resolution across hosts, project-root resolution, plugin-data persistence, the dirname-walking anti-pattern, and the agentic script-interface rules that decide whether an agent can actually drive the script.
user-invocable: false
paths:
  - "**/skills/**/scripts/**/*.sh"
---

# Skill script checklist

Apply this to the file you just opened. The mistake that matters most: dirname-walking from the script's own location to find the user's project root or plugin root. It works only when the plugin happens to be a local checkout — it breaks the moment the plugin runs from a cache install, which is the normal case.

This is not a hook script — no JSON envelope on stdin, no JSON response on stdout, no host-managed exit-code semantics. It runs as ordinary bash, invoked by the skill's own markdown via `` bash "${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/<script>.sh" `` or via `` !`...` `` using `${CLAUDE_SKILL_DIR}`.

## Checklist

1. **No `cd "$(dirname "${BASH_SOURCE[0]}")/../.."`-style walk to find the project root, the plugin root, or a sibling skill.** Flag any `dirname`/`BASH_SOURCE` walk that isn't explicitly gated as the standalone-invocation fallback (see below) — replace with the env vars.
2. **Project root resolved via the three-tier fallback**, not a bare `pwd`:

   ```bash
   PROJECT_DIR="${MYPLUGIN_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
   ```

   Tier 1: the plugin's own namespaced var (set by its `SessionStart` hook, survives subshells via `lib/source-session-env.sh`). Tier 2: `${CLAUDE_PROJECT_DIR}`, set by the host in every Bash-tool subprocess. Tier 3: `git rev-parse`/`pwd`, for standalone invocation outside Claude Code.
3. **Plugin root resolved via the portable chain**, not a bare `${CLAUDE_PLUGIN_ROOT}` or `${PLUGIN_ROOT}`:

   ```bash
   PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-${MYPLUGIN_PLUGIN_ROOT:-}}}"
   ```

   `${CLAUDE_PLUGIN_ROOT}` covers Claude Code and Copilot; `${PLUGIN_ROOT}` covers Agent Plugins 1.0 and Copilot. The two sets meet at Copilot, the one host that answers to either spelling, so Copilot alone never forces a choice. What does is the pair at the ends: Claude Code and Agent Plugins 1.0 share no spelling at all, so a script that must resolve under both has no single token available and needs the chain rather than either bare spelling. The third element is the namespaced `SessionStart`-exported fallback, for subshells that inherit neither host variable. Caveat: `${CLAUDE_PLUGIN_ROOT}` working under Copilot rests on the VS Code page alone — the Copilot CLI reference documents only `${PLUGIN_ROOT}`. The chain is correct either way. Full reasoning and the placeholder matrix: `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/cross-client-behavior.md` § Placeholder vocabulary.
4. **This skill's own bundled files referenced via `${CLAUDE_SKILL_DIR}`** (this skill's subdirectory, not the plugin root); **another skill's bundled files via the plugin-root chain above joined to `/skills/<other>/...`**. Never a relative walk to a sibling.
5. **Persistent state written to `${CLAUDE_PLUGIN_DATA}/`, never `${CLAUDE_PLUGIN_ROOT}/`.** The plugin install directory is replaced wholesale on update and purged ~7 days after — anything written there is lost. `${CLAUDE_PLUGIN_DATA}` is the better spelling: Copilot's CLI reference substitution table documents it as an alias of `${COPILOT_PLUGIN_DATA}` — that is a host-substitution fact, and neither reference states whether the alias is separately exported into a bundled script's subprocess environment the way Agent Plugins documents `${PLUGIN_ROOT}`/`${PLUGIN_DATA}`. `${PLUGIN_DATA}` is Agent-Plugins-only — a bundled script only ever sees it as a shell variable exported into the subprocess environment, never as a host-substituted token, so under Copilot (which does not set it) it is simply unset and expands empty. Do not reach for it in a script meant to run there.
6. **`cwd` never assumed to be the project root.** The script's cwd is whatever the agent last `cd`-ed to, not guaranteed to be anything in particular. Resolve via the fallback chain in point 2, not `pwd` alone.
7. **Standalone invocation has a defensive fallback, or the skill body states "invoke only via the agent."** If a developer might run the script directly outside Claude Code, `CLAUDE_*` vars are unset — the dirname-walk fallback is the one place it's legitimate, guarded behind an `if [ -z "$VAR" ]` check.
8. **`set -euo pipefail`** present — skill scripts should be as defensive as hook scripts about strict mode.
9. **Third-party CLI calls reviewed against `shelling-out-from-plugins`** — env hygiene at every call site.
10. **No `export FOO=bar` expecting a later, separately-invoked Bash-tool call to see it.** Bash-tool subprocesses don't inherit each other's env; only `SessionStart`/`Setup`/`CwdChanged`/`FileChanged` writes to `$CLAUDE_ENV_FILE` propagate.

## Agentic script-interface rules

These decide whether an agent can use the script at all — not whether it runs, but whether an agent driving it non-interactively can succeed. The roster below is the full list from the source; if it and the source ever disagree on count, the source wins. Source: `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/skill-authoring-guidance.md` § Script design for agentic use.

- **Never block on interactive input.** Agents run in non-interactive shells; a TTY prompt hangs forever. Accept input via flags, env vars or stdin, and fail with a message naming the missing flag and its options.
- **`--help` is the interface documentation** an agent reads. Brief description, flags, examples. Keep it short — it enters the context window.
- **Structured stdout, diagnostics on stderr.** JSON/CSV/TSV over whitespace-aligned text, so the agent and `jq` can both consume it.
- **Errors say what was expected**, not just that something failed.
- **Idempotency** — agents retry. "Create if not exists" over "create and fail".
- **Constrain input.** Reject ambiguous input with a clear error rather than guessing; use enums and closed sets over free text.
- **Distinct, documented exit codes** per failure class.
- **`--dry-run`** for destructive or stateful operations.
- **Predictable output size** — many harnesses truncate beyond 10–30K characters. Default to a summary, support `--offset`, or require an explicit `--output`.

## Common mistakes

- `cd "$SCRIPT_DIR/../.."` to find the project root — walks into the plugin install, not the user's repo.
- `cd "$SCRIPT_DIR/../../<other-skill>"` to invoke a sibling script — same failure mode; use the plugin-root chain joined to `/skills/<other>/scripts/<bin>.sh`.
- Trusting a bare `${CLAUDE_PLUGIN_ROOT}` or a bare `${PLUGIN_ROOT}` in a script meant to run on more than one host — resolve the chain.
- Writing a cache/log file next to the script itself instead of under `${CLAUDE_PLUGIN_DATA}`.
- Hard-coding `~/.claude/plugins/data/<id>/` instead of `${CLAUDE_PLUGIN_DATA}` — the `<id>` form is implementation-defined and shouldn't be reconstructed by hand.
- `${PLUGIN_DATA}` in a script meant to run under Copilot — a shell script only ever reads it as a subprocess environment variable, never as a host-substituted token, so under Copilot (which never sets it) it is unset and expands **empty**: `mkdir -p "${PLUGIN_DATA}/cache"` silently becomes `mkdir -p "/cache"`. (A different rule holds in a host-parsed file such as `plugin.json` or `mcp.json`, where the same token is left as a literal unexpanded string — that is a manifest-layer fact, not a shell-script one.) Use `${CLAUDE_PLUGIN_DATA}`.
- Writing `${COPILOT_PLUGIN_ROOT}` — defined by nothing, expands to nothing, and the script fails silently rather than erroring. This does **not** generalize to the `COPILOT_*` prefix: `${COPILOT_PLUGIN_DATA}` is real and documented.
- `cmd || true` followed by a `$?` check — dead code, `true` always succeeds; capture with `out=$(cmd 2>&1) || rc=$?`.
- `local out="$(cmd)"`, or a substitution passed as an argument (`printf '%s' "$(cmd)"`) — **`set -e` does not see either one fail**, because the status it checks is `local`'s or the outer command's, not the substitution's. Both survive with an empty string that then flows on as data. A bare `out="$(cmd)"` on its own line *is* caught, so the fix is to split the declaration from the assignment: `local out=""` then `out="$(cmd)" || die "..."`, plus a non-empty guard wherever empty is not a valid result. This plugin shipped and fixed exactly this bug — an unhashable file recorded an empty digest, and every later check then validated it as clean.
- A script that prompts for confirmation with no flag to skip it — an agent cannot answer the prompt and the invocation hangs.
- No `--help`, or a `--help` that dumps the whole man page — either leaves the agent guessing at the interface.
- Human-readable, whitespace-aligned output with no structured mode — forces the agent to parse prose instead of `jq`-ing a field.

## Read for the full contract

- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/plugins-reference.md` — `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_DATA}`/`${CLAUDE_PROJECT_DIR}` contracts, stability guarantees, plugin caching.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/skills.md` — `${CLAUDE_SKILL_DIR}` and the other skill-content substitution variables.
- `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/cross-client-behavior.md` — the placeholder vocabulary matrix behind the plugin-root chain, and which sites each token expands in.
- `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/skill-authoring-guidance.md` — the full script-design-for-agentic-use rule set, plan-validate-execute, and bundling guidance.
