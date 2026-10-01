---
type: Roadmap
title: Single-source plugin builds
description: Planned move from hand-ported per-host plugin copies to one source per plugin, built by an Effect-based bundler into committed per-host outputs under builds/.
tags:
  - architecture
  - portability
  - release
  - dx
status: draft
stale_after: 2026-12-29T00:00:00Z
gate: plugin-bot builds its claude-code and copilot outputs from one source under plugins/plugin-bot/, both marketplaces serve those outputs, and the Decisions this layout replaces are superseded.
sources:
  - id: owner-direction
    resource: conversation with the repository owner
    author: human:spencer
    last_modified: 2026-09-30T00:00:00Z
    title: Layout, versioning and scope set by the repository owner while planning
  - id: impeccable
    resource: https://github.com/pbakaus/impeccable/tree/c74755d920985f7a92cef691ca970ba95f90126e
    title: impeccable, the prior art surveyed
  - id: impeccable-providers
    resource: https://github.com/pbakaus/impeccable/blob/c74755d920985f7a92cef691ca970ba95f90126e/scripts/lib/transformers/providers.js
    title: impeccable's per-host configuration table
  - id: impeccable-plugin-paths
    resource: https://github.com/pbakaus/impeccable/blob/c74755d920985f7a92cef691ca970ba95f90126e/scripts/lib/plugin-paths.js
    title: impeccable's post-build rewrite of the Claude Code plugin copy
  - id: changeset-config
    resource: ../../.changeset/config.json
    title: Changesets config with per-package versionFiles
  - id: workspace-globs
    resource: ../../pnpm-workspace.yaml
    title: pnpm workspace globs
generated:
  by: okfit/claude-code
  at: 2026-10-01T03:45:35Z
  body_sha256: 938671640ccca74697ea43192f4f0b118d5015821bc8bd9317ce5484e2c0733f
---

# Single-source plugin builds

This is planned intent, not a decision, and no work has started on it. The work is to stop keeping a hand-ported copy of each plugin per host. Each plugin would have one source, and a build would render it into every host's format. When the gate holds, deprecate this concept and record what the work produced as Decisions.

## Why

Today each plugin keeps a full copy per host, kept in step by hand-porting and a ledger that sees only skill and agent markdown. The [divergence measurement](../measurements/plugin-bot-target-divergence.md) found most differences between plugin-bot's two copies are mechanical or a recurring fallback pattern, which a build can produce. The few host-specific passages that remain would be marked inside one file instead of living in two.

## Target layout

The repository owner set this shape:[^owner-direction]

```text
packages/ai-bundler/            the bundler, developed here first
plugins/<name>/
  ai-plugin.config.ts           targets and per-target rules for this plugin
  package.json                  the only package for the plugin
  skills/  agents/  hooks/ ...  host-neutral source
  builds/
    claude-code/                generated, committed
    copilot/                    generated, committed
```

- **One package and one build per plugin.** `plugins/<name>/` is the workspace, so the workspace glob changes from `plugins/*/*` to `plugins/*`, plus `packages/*`.[^workspace-globs] The build reads the source and writes every target into `builds/`.
- **Build output is committed.** Marketplaces load a plugin from a subdirectory and need the complete, transformed output there. Each host has its own rules for a plugin reaching into other directories, so one build that writes a self-contained folder per host is the portable choice. Plugins are built locally and the changes to `builds/` are committed, so the output is always present in git.
- **The folder name still names the host.** `plugins/<name>/builds/<target>/` keeps the host name in the path of every shipped file. The source folders are host-neutral by definition.

## Versioning

The repository owner set this, and it replaces per-target versioning:[^owner-direction]

- Changesets track `plugins/<name>/package.json`, and every target of a plugin shares that version, even when a change touched only one host.
- The build copies the version from `plugins/<name>/package.json` into each target manifest under `builds/`.
- In CI, the plugin package's `versionFiles` entries bump the manifests under `builds/` directly. This uses the Silk Suite changesets support the repository already has.[^changeset-config]
- The bundler does nothing about versioning beyond that copy. Another consumer of the package handles its own versioning.

## Prior art: impeccable

impeccable builds one design skill into about 18 hosts from a single source tree.[^impeccable] What carries over:

- **Hosts as data.** One config table gives each host its directory, the frontmatter fields it keeps, its agent file format and its hook file location. A single transformer factory runs every host.[^impeccable-providers]
- **Two ways to vary content per host.** `{{placeholder}}` tokens are filled from a per-host table, and `<host>...</host>` blocks are kept for one host and stripped for the rest.
- **Fallbacks for a missing feature.** For hosts without subagents, each agent is also emitted as a reference file whose preamble tells the model to play the role inline.
- **Build checks.** These cover agreement of versions across manifests, frontmatter shape, and an allowlist of manifest keys known to load. The allowlist exists because a manifest key once shipped that silently loaded zero agents and `claude plugin validate` did not flag it. An end-to-end test installs the output into a sandboxed Claude Code.

What to avoid: impeccable's main output is a project install, and the Claude Code plugin is derived afterwards by copying it and rewriting it with regexes, guarded by checks that the rewrite worked.[^impeccable-plugin-paths] The config describes formatting rather than what each host can do, so special cases (one host checked by name, a hard-coded set of hosts) leak into the factory.

## Design direction for the bundler

The plan is a package, `@effected/ai-bundler`, built on Effect v4 and Effect Schema. It is developed under `packages/ai-bundler/` and extracted once a second plugin repository adopts it.

- **Targets described by capability.** A `Target` schema says which frontmatter keys each component kind accepts, the manifest location and keys, how plugin-relative paths are spelled, which hook events exist, and whether `paths:` auto-loading exists. An unknown key fails decoding. Facts the host documentation leaves unresolved, such as Copilot's agent tool names, are encoded as unresolved, not guessed.
- **Declared fallbacks.** A component declares per target whether a missing capability means omit, degrade to a named form (description suffix, body section, inline role) or fail.
- **Typed references instead of free-text placeholders.** A reference to another skill's file resolves per target and must exist, so an unresolved reference is a build error, never shipped text.
- **Pipeline.** Read, decode, validate, transform per target, emit, then check. A `check` mode rebuilds and compares with the committed `builds/` so CI catches output that was not rebuilt. The `@effected` markdown, yaml, jsonc, glob, walker and memfs packages cover most of the building blocks.

## Phases

1. **Design.** Settle the open questions below and sketch the `ai-plugin.config.ts` and `Target` schemas.
2. **Bundler.** Build `packages/ai-bundler/` with the pipeline, the Claude Code and Copilot targets, and `check` mode.
3. **Migrate plugin-bot.** Collapse its two targets into one source and confirm the generated `builds/` matches today's targets except for intended changes. Repoint both marketplace manifests and the repin workflow at `builds/<target>`, move to one tracking package, and rewrite `canonical-layout.bats` for the new shape.
4. **Migrate dogfood.** It becomes a plugin with one target in its config, so no exception to the layout is needed.
5. **Guards and docs.** Wire `check` into CI. Teach plugin-bot the pattern, including a hook that blocks direct edits under `plugins/*/builds/**`. Supersede the Decisions listed below.

## Open questions

- **Files only one host gets.** For example, hook scripts only Claude Code runs, or a Copilot-only agent. The candidates are a per-component `targets:` field, host blocks inside shared files, and a small `overrides/<target>/` folder copied verbatim. To be decided in design.
- **The local dev loop.** `pnpm claude` would load `builds/claude-code`, so source edits need a rebuild (or a watch mode) before they show.
- **Where tests live.** Source and schema tests would sit at the plugin root. Host-specific checks (`claude plugin validate --strict`, install tests) would run against `builds/<target>/`.

## What it replaces when the gate holds

- [Every component lives in a target workspace](../decisions/target-workspace-layout.md), and the [canonical layout invariant](../invariants/canonical-layout.md) it rests on.
- [Authoring flows one way, claude-code first](../decisions/one-directional-authoring.md), with the [refresh the Copilot port](../runbooks/refresh-copilot-port.md) runbook and the [port ledger coverage](../limitations/port-ledger-coverage.md) limitation, since the build replaces porting.
- [Each distributed target versions independently](../decisions/per-target-versioning.md), replaced by one version per plugin.
- The ledger-coverage item in [plugin-bot next steps](plugin-bot-next.md) becomes moot.

[^owner-direction]: conversation with the repository owner, 2026-09-30
[^impeccable]: <https://github.com/pbakaus/impeccable/tree/c74755d920985f7a92cef691ca970ba95f90126e>
[^impeccable-providers]: <https://github.com/pbakaus/impeccable/blob/c74755d920985f7a92cef691ca970ba95f90126e/scripts/lib/transformers/providers.js>
[^impeccable-plugin-paths]: <https://github.com/pbakaus/impeccable/blob/c74755d920985f7a92cef691ca970ba95f90126e/scripts/lib/plugin-paths.js>
[^changeset-config]: `../../.changeset/config.json`
[^workspace-globs]: `../../pnpm-workspace.yaml`
