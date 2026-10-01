---
type: Convention
title: Place BATS tests by how host-specific the claim is
description: Host-agnostic claims go in plugins/__test__/; host-specific claims go in the owning target workspace's __test__/, and bats collects both with no registration.
status: draft
stale_after: 2026-12-29T00:00:00Z
tags:
  - testing
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:28:01Z
  body_sha256: f015d8ccca472746c9343d3a8be419d5877ca7c0e7a8513d82930134d0c2d8b2
sources:
  - resource: ../../package.json
    title: The test:bats script
  - resource: ../../plugins/__test__/canonical-layout.bats
    title: The host-agnostic suite
  - resource: ../../plugins/plugin-bot/copilot/__test__/port-drift.bats
    title: A host-specific suite
---

# Place BATS tests by how host-specific the claim is

Put a test where its claim lives.

- A host-agnostic claim, one true of every target, goes in `plugins/__test__/`. The canonical layout is the example: `canonical-layout.bats` pins the target-workspace structure for every plugin and host.
- A host-specific claim goes in `plugins/<plugin>/<target>/__test__/`, written for that target alone. `plugins/plugin-bot/copilot/__test__/port-drift.bats` pins the Copilot port, and `plugins/plugin-bot/claude-code/__test__/lib-templates.bats` pins Claude Code's bundled templates. Suites at this level are meant to differ between targets.

`pnpm test:bats` runs `bats --recursive plugins`, which collects every level with no registration step. Adding a `.bats` file at either level is enough for it to run, so there is no list to update. `bats --count plugins` reports the current number of tests.

Because the location signals the scope, a reader who sees a test under `copilot/__test__/` knows it constrains only the Copilot port. The reasoning for the directory structure is in [the target-workspace layout decision](../decisions/target-workspace-layout.md).
