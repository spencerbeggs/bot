---
type: Invariant
title: No component directory exists outside a target workspace
description: Every directory under a plugin dir is a claude-code or copilot target workspace or __test__, pinned by canonical-layout.bats.
status: draft
resource: ../../plugins/__test__/canonical-layout.bats
tags:
  - architecture
  - testing
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: c556b1670d2071ea34f69d752f1127aa481af2cdbbd77bc2f33514c1e6179aa0
sources:
  - resource: ../../plugins/__test__/canonical-layout.bats
    title: The test that pins the property
---

# No component directory exists outside a target workspace

## Property

Under `plugins/`, a component directory (skills, agents, hooks and the like) only ever sits inside a target workspace: a directory named exactly `claude-code` or `copilot`, at depth 1 or 2 below `plugins/`. The directory name tells an agent which host's contract governs a file before it reads a byte, so nothing may sit outside one. The rationale is in [the target-workspace layout decision](../decisions/target-workspace-layout.md).

## Mechanism

`plugins/__test__/canonical-layout.bats` pins it. It is a test, not a type, so it holds only while the suite runs. What it asserts:

- At least one target workspace exists.
- Every entry directly under `plugins/`, other than `__test__`, is a plugin directory that itself contains at least one target workspace.
- Every directory inside such a plugin directory is `claude-code`, `copilot` or `__test__`; anything else, such as a stray `skills/`, fails with a message naming the path.
- Each target carries its host's manifest: `.claude-plugin/plugin.json` for `claude-code`, a root `plugin.json` for `copilot`.
- A tracking `package.json`, where one exists, is named `@<plugin>/<target>-plugin`, is private and has no `publishConfig`. A workspace without one is undistributed by design, as `dogfood` is.
- Each tracking package has a `versionFiles` entry in `.changeset/config.json` whose glob resolves to a file.
- Marketplace entries in `.claude-plugin/marketplace.json` and `.github/plugin/marketplace.json` that point into this repository resolve to a directory that is a target workspace.

The iterating tests carry a found-count guard so they cannot pass vacuously when nothing is discovered.

## What would break it

The property stops holding if a refactor adds a plugin-level directory next to the targets (for example a shared `plugins/plugin-bot/skills/`), flattens a target out of `plugins/<plugin>/<target>/`, renames a target away from the `claude-code` or `copilot` names, or deletes or weakens the bats file. A new host would need to be added to the target-name pattern in the test, so that its directory is recognised rather than rejected. The test checks directory names and manifests, not what lies inside a target, so it does not stop a component being misplaced within one.
