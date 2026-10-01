---
type: Decision
title: Every component lives in a target workspace
description: Components live under plugins/<plugin>/<target>/ with target exactly claude-code or copilot, so the governing host contract is legible from the path.
status: draft
tags:
  - architecture
  - portability
sources:
  - resource: ../../plugins/plugin-bot/claude-code/.claude-plugin/plugin.json
  - resource: ../../plugins/plugin-bot/copilot/plugin.json
  - resource: ../../plugins/__test__/canonical-layout.bats
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: ababf9f88341c16a931008f76a8ce3ea703439b6abd5684b010666aa2e177503
---

# Every component lives in a target workspace

## Context

plugin-bot serves two hosts, Claude Code and GitHub Copilot, and the two disagree on the manifest location (`.claude-plugin/plugin.json` versus a root `plugin.json`), the agent file extension, the hook roster and the frontmatter keys. A single plugin directory cannot say which host's contract governs its contents. This was decided at the point the plugin grew a second host; the layout is now enforced rather than aspirational.

## Decision

Every component lives under `plugins/<plugin>/<target>/`, where `<target>` is exactly `claude-code` or `copilot` (see [target](../glossary/target.md)). An agent that sees `plugins/*/copilot/**` knows which host's contract governs the file before it reads a byte of it. Nothing else in the tree carries that signal, so nothing may sit outside a target workspace. The rule is held by [the canonical layout invariant](../invariants/canonical-layout.md).

## Alternatives rejected

- **One plugin directory serving both hosts.** The path would say nothing about which contract applies, and the manifest, agent extension and hook files would collide or need per-host naming conventions inside one tree.
- **A build step that emits per-host output from a neutral source.** It would add tooling and a generated tree to review, where encoding the host in the path lets one plugin serve two hosts with no build step.

## Consequences

- The contract is legible before a file is opened, so path-based guidance and review can key on `claude-code` or `copilot`.
- Adding a host means adding a sibling target workspace, not restructuring.
- Some guidance is duplicated across the two workspaces; [one-directional authoring](./one-directional-authoring.md) keeps that duplication governed.
