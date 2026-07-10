---
name: shelling-out-from-plugins
description: Use when authoring or auditing Claude Code plugin scripts that invoke a third-party CLI like gh, aws, kubectl, docker, or gcloud — tool-canonical env vars in the user's shell silently override the auth, profile, or config the plugin assumed was in effect, and the failure surfaces as wrong-account writes, "not authenticated" false negatives, or commands targeting the wrong cluster, project, or repository
---

# Shelling Out From Plugins

## Overview

A plugin script's environment is **the user's interactive shell environment** plus whatever the plugin set. The user's shell almost always contains tool-canonical env vars (`GH_TOKEN`, `AWS_PROFILE`, `KUBECONFIG`, `DOCKER_HOST`, `GH_HOST`, `GH_REPO`, `CLOUDSDK_*`, …) left over from earlier sessions, CI scripts, mise/asdf shims, or shell-rc files the user no longer remembers writing.

**Tool CLIs respect their canonical env vars over their keyring, config file, or context.** If the plugin shells out to `gh` while a stale `GH_TOKEN` is in the env, `gh` uses that token — even if `gh auth login` set up a perfectly good keyring entry for the same account. The plugin thinks it's using the user's keyring auth. It isn't.

**Core principle: when a plugin shells out to a third-party CLI, treat the inherited env as hostile.** Either control the tool-canonical vars explicitly, or namespace your own and translate at the call site.

## When to Use

Use this skill when:

- Writing a plugin hook, bin, or skill step that invokes `gh`, `aws`, `kubectl`, `docker`, `gcloud`, `terraform`, `kubeseal`, `helm`, or any other CLI that authenticates against a service
- A plugin's `gh auth status` (or equivalent) reports "not authenticated" while the user's interactive shell can run `gh auth status` fine
- A `gh pr create` / `aws s3 cp` / `kubectl apply` from a plugin lands in the wrong account, profile, repo, or cluster
- A plugin documents an env var the user must export (e.g., "set GH_TOKEN before running") and you suspect that's wrong
- Auditing an existing plugin for env-var fragility before publishing

**Do NOT** use for: shell scripts that aren't part of a plugin (those run in a single known environment — different problem). Or for in-process API calls from a plugin's MCP server (those don't shell out — different layer).

## The two patterns

### Pattern A — Namespace your own env vars and translate at the call site

**This is the right default.** A plugin should never tell the user "set `GH_TOKEN`." It should document its own namespaced var (`MYPLUGIN_GH_TOKEN`) and pass it to `gh` explicitly *only inside the subshell that invokes `gh`*.

```bash
# At the call site:
if [ -n "${MYPLUGIN_GH_TOKEN:-}" ]; then
  # Pass the namespaced token through to gh via the canonical var,
  # scoped to this single command. The canonical var does not survive
  # into any subshell that follows.
  GH_TOKEN="$MYPLUGIN_GH_TOKEN" gh pr create --title "$title" --body "$body"
else
  # No plugin-specific token — fall back to keyring auth, but kill any
  # stale canonical var in the user's env so it cannot override the
  # keyring entry that gh would otherwise pick.
  GH_TOKEN= gh pr create --title "$title" --body "$body"
fi
```

Why this works:

- The user's `GH_TOKEN` (if any) never reaches `gh` from the plugin's call.
- Tokens are scoped to the single invocation. They don't leak into other commands.
- The plugin's documented surface (`MYPLUGIN_GH_TOKEN`) doesn't conflict with what the user already has set for `gh` use outside the plugin.
- Other plugins using `gh` won't accidentally consume this plugin's token.

The same shape works for AWS, kubectl, docker, gcloud — see the table below for the canonical var to translate to.

### Pattern B — Unset before invoking, when the plugin doesn't own a token

When the plugin is just delegating to the tool's normal auth (keyring, default profile, current context) and doesn't carry a token of its own, scrub the canonical vars in the subshell that runs the tool:

```bash
# Equivalent inline forms — pick whichever reads cleaner in context:
GH_TOKEN= GITHUB_TOKEN= gh pr create ...

# or, when several commands run in sequence:
(
  unset GH_TOKEN GITHUB_TOKEN GH_HOST GH_REPO
  gh pr view ...
  gh pr create ...
)
```

The subshell form (with `( ... )`) is preferable over `unset` in the script body — it bounds the scope to those few commands instead of mutating the rest of the script.

## Per-tool gotcha table

The vars most likely to bite a plugin, and what to override or unset at the call site:

| Tool | Canonical vars to control | What goes wrong if you don't |
| --- | --- | --- |
| `gh` | `GH_TOKEN`, `GITHUB_TOKEN`, `GH_HOST`, `GH_REPO`, `GH_PAGER` | Wrong account, wrong host, wrong repo, or `gh pr view` hangs on a TTY pager |
| `aws` | `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`, `AWS_DEFAULT_REGION` | Wrong account profile; static keys silently outrank SSO config; commands run in the wrong region |
| `kubectl`, `helm` | `KUBECONFIG`, `KUBE_CONTEXT`, `KUBE_NAMESPACE` | Operations target the wrong cluster; `KUBECONFIG` is colon-separated and may merge configs the plugin didn't expect |
| `docker` | `DOCKER_HOST`, `DOCKER_CONTEXT`, `DOCKER_TLS_VERIFY`, `DOCKER_CERT_PATH` | Pushes go to a remote daemon, or local builds attempt to use a context that no longer exists |
| `gcloud` | `CLOUDSDK_CORE_PROJECT`, `CLOUDSDK_ACTIVE_CONFIG_NAME`, `GOOGLE_APPLICATION_CREDENTIALS` | Operations land in the wrong project; service-account JSON path overrides the user's gcloud-login identity |
| `git` itself | `GIT_DIR`, `GIT_WORK_TREE`, `GIT_TERMINAL_PROMPT`, `GIT_AUTHOR_*`, `GIT_COMMITTER_*` | Operations resolve against the wrong worktree; `git push` blocks on a credential prompt that has nowhere to surface |
| `terraform` | `TF_VAR_*`, `TF_CLI_CONFIG_FILE`, `TF_WORKSPACE` | Plans run against the wrong workspace; user-set `TF_VAR_*` overrides plugin-provided variables silently |

For any tool not on this table, the rule of thumb is: read `man <tool>` or `<tool> --help | grep -i env` once and write down which vars matter, then namespace anything the plugin needs and scrub anything it doesn't.

## The exit-code conflation gotcha (CLI auth checks)

A separate failure mode worth knowing because the failure is silent: when a tool's auth-check subcommand (e.g., `gh auth status`) finds *both* a configured env token and a configured keyring entry, and the env token is invalid while the keyring entry is valid, the command writes both states to stderr and **exits non-zero**. Scripts that test the exit code as a boolean read this as "not authenticated" and skip auth-gated work — even though the user's interactive auth is fine and the keyring entry would succeed if the env token were not in the way.

```bash
# WRONG — exit-code-as-boolean misclassifies the env-token-overrides-keyring case
if ! gh auth status >/dev/null 2>&1; then
  echo "Not authenticated; skipping PR step"
  return
fi

# RIGHT — control the env first, then check
(
  unset GH_TOKEN GITHUB_TOKEN
  gh auth status >/dev/null 2>&1
) || {
  echo "Not authenticated; skipping PR step"
  return
}
```

## Every call site must agree (the "check-site / use-site" rule)

**The most common partial-fix pattern: scrubbing the env at the auth check but leaving the actual write call exposed.** A plugin that scrubs `GH_TOKEN` before `gh auth status` but does *not* scrub before `gh pr create` is worse than one that scrubs nowhere — the auth probe now passes against the keyring while the actual write attempts the stale env token, posts to the wrong account, or fails with a confusing 403. The probe lied.

Apply the same env hygiene at **every** `gh` (or `aws`, `kubectl`, `docker`, `gcloud`) call site, not only the probe. If you scrub at the check site, scrub at the use site. If you translate via `GH_TOKEN="$MYPLUGIN_GH_TOKEN" gh ...` at the check site, do the same at the use site. The rule has no exceptions — every invocation in the same flow is "the use site" for the auth state the check verified.

Concretely, an end-to-end finalize flow that scrubs in step 0.6 (auth check) but invokes `gh pr view` / `gh pr create` later without scrubbing has done half the work and left the user worse off than if the check had been removed entirely.

A useful audit technique: list every line in the plugin that invokes `gh` (or any other third-party CLI) and confirm the env hygiene prefix is identical at all of them. If line N has `GH_TOKEN=… gh …` and line M has bare `gh …`, line M is a bug regardless of whether line N looks right in isolation.

## Audit checklist

When auditing an existing plugin's shell-out paths, scan for:

1. **Every call site of each third-party CLI.** Run `grep -nE '(^|[^a-z_])gh ' <files>` (and equivalents for `aws`, `kubectl`, `docker`, `gcloud`) and confirm the env hygiene prefix is consistent across every line. A scrub or translation that's present at the auth check but missing at the actual write is the most common partial fix and the most damaging.
2. Direct invocations without any env-var hygiene in front of them.
3. README or skill prose that tells the user to "export `GH_TOKEN`" (or any other tool-canonical token name) — that's the namespacing violation. The plugin should document its own var.
4. Auth-check subcommands tested as `if cmd >/dev/null 2>&1; then` — the exit-code conflation case.
5. `gh` calls without `GH_PAGER=cat` in front, or with stdin/stdout connected to a TTY — those can hang.
6. `kubectl` or `helm` calls without an explicit `--context` or `--kubeconfig` flag when the plugin assumes a specific cluster.
7. `aws` calls without an explicit `--profile` when the plugin assumes a specific account.

## Common mistakes

- **Telling the user to set the canonical var.** "Set `GH_TOKEN` before running this plugin." That's exactly the conflict this skill exists to prevent. Document `MYPLUGIN_GH_TOKEN` (or similar) and translate.
- **Scrubbing at the check site but not at the use site.** Step 0.6 wraps `gh auth status` in a `GH_TOKEN= gh ...` scrub; step 7.3 calls bare `gh pr create`. Now the probe passes against the keyring while the actual write tries the stale env token — the worst-of-both case. Fix by applying the same hygiene at every call site in the same flow, not just the probe.
- **`unset` at script top.** Mutates the script's env for the whole run, including commands that didn't ask for scrubbing. Prefer a per-call inline override (`VAR= cmd`) or a bounded subshell (`( unset VAR; cmd )`).
- **Capturing exit code after `|| true`.** `cmd || true` always succeeds, so `$?` afterward is 0 — the helper-status check that follows is dead code. Capture into a variable: `out=$(cmd 2>&1) || rc=$?`. Audit checklist item: grep for `|| true` followed by `$?` or `rc=$?` capture.
- **Trusting `gh auth status`-style exit codes as booleans without first controlling the env.** See exit-code conflation above.
- **Plugin-specific token names that still match the upstream namespace.** `GITHUB_TOKEN` is already canonical for `gh`. Naming your plugin's var `MY_GITHUB_TOKEN` is fine; naming it `GITHUB_TOKEN` and "hoping it doesn't conflict" is not.
