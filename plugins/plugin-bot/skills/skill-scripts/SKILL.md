---
name: skill-scripts
description: Enforces the house contract for scripts bundled inside a skill's `scripts/` directory when one is opened for authoring or review — canonical project-root resolution, plugin-data persistence, and the dirname-walking anti-pattern.
user-invocable: false
paths:
  - "**/skills/**/scripts/**/*.sh"
---

# Skill script checklist

Apply this to the file you just opened. The mistake that matters most: dirname-walking from the script's own location to find the user's project root. It works only when the plugin happens to be a local checkout — it breaks the moment the plugin runs from `~/.claude/plugins/cache/<plugin>/...`, which is the normal case.

This is not a hook script — no JSON envelope on stdin, no JSON response on stdout, no host-managed exit-code semantics. It runs as ordinary bash, invoked by the skill's own markdown via `` bash "${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/<script>.sh" `` or via `` !`...` `` using `${CLAUDE_SKILL_DIR}`.

## Checklist

1. **No `cd "$(dirname "${BASH_SOURCE[0]}")/../.."`-style walk to find the project root, the plugin root, or a sibling skill.** Flag any `dirname`/`BASH_SOURCE` walk that isn't explicitly gated as the standalone-invocation fallback (see below) — replace with the env vars.
2. **Project root resolved via the three-tier fallback**, not a bare `pwd`:

   ```bash
   PROJECT_DIR="${MYPLUGIN_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
   ```

   Tier 1: the plugin's own namespaced var (set by its `SessionStart` hook, survives subshells via `lib/source-session-env.sh`). Tier 2: `${CLAUDE_PROJECT_DIR}`, set by the host in every Bash-tool subprocess. Tier 3: `git rev-parse`/`pwd`, for standalone invocation outside Claude Code.
3. **This skill's own bundled files referenced via `${CLAUDE_SKILL_DIR}`** (this skill's subdirectory, not the plugin root); **another skill's bundled files via `${CLAUDE_PLUGIN_ROOT}/skills/<other>/...`**. Never a relative walk to a sibling.
4. **Persistent state written to `${CLAUDE_PLUGIN_DATA}/`, never `${CLAUDE_PLUGIN_ROOT}/`.** The plugin install directory is replaced wholesale on update and purged ~7 days after — anything written there is lost.
5. **`cwd` never assumed to be the project root.** The script's cwd is whatever the agent last `cd`-ed to, not guaranteed to be anything in particular. Resolve via the fallback chain in point 2, not `pwd` alone.
6. **Standalone invocation has a defensive fallback, or the skill body states "invoke only via the agent."** If a developer might run the script directly outside Claude Code, `CLAUDE_*` vars are unset — the dirname-walk fallback is the one place it's legitimate, guarded behind an `if [ -z "$VAR" ]` check.
7. **`set -euo pipefail`** present — skill scripts should be as defensive as hook scripts about strict mode.
8. **Third-party CLI calls reviewed against `shelling-out-from-plugins`** — env hygiene at every call site.
9. **No `export FOO=bar` expecting a later, separately-invoked Bash-tool call to see it.** Bash-tool subprocesses don't inherit each other's env; only `SessionStart`/`Setup`/`CwdChanged`/`FileChanged` writes to `$CLAUDE_ENV_FILE` propagate.

## Common mistakes

- `cd "$SCRIPT_DIR/../.."` to find the project root — walks into the plugin install, not the user's repo.
- `cd "$SCRIPT_DIR/../../<other-skill>"` to invoke a sibling script — same failure mode; use `${CLAUDE_PLUGIN_ROOT}/skills/<other>/scripts/<bin>.sh`.
- Writing a cache/log file next to the script itself instead of under `${CLAUDE_PLUGIN_DATA}`.
- Hard-coding `~/.claude/plugins/data/<id>/` instead of `${CLAUDE_PLUGIN_DATA}` — the `<id>` form is implementation-defined and shouldn't be reconstructed by hand.
- `cmd || true` followed by a `$?` check — dead code, `true` always succeeds; capture with `out=$(cmd 2>&1) || rc=$?`.

## Read for the full contract

- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/plugins-reference.md` — `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_DATA}`/`${CLAUDE_PROJECT_DIR}` contracts, stability guarantees, plugin caching.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/skills.md` — `${CLAUDE_SKILL_DIR}` and the other skill-content substitution variables.
