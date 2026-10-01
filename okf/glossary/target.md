---
type: Glossary
title: target
description: In this repo a target is a host directory under plugins/<plugin>/<target>/, which is not the dev or prod build target of turbo.json and Silk tooling.
status: draft
tags:
  - architecture
  - portability
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:28:01Z
  body_sha256: 48a177009959a6f0a5b7cda9ef208b72167cc51fd8eda1db18f5877a8ead8ea1
sources:
  - resource: ../../turbo.json
    id: turbo-config
    title: Turborepo task definitions
  - resource: Silk plugin guidance and tsdoc-diagnostics monitor
    id: silk-convention
    title: Silk build convention
---

# target

## Meaning in this repository

A target is a host directory under `plugins/<plugin>/<target>/`. The name is exactly `claude-code` or `copilot`, and it tells a reader which host's contract governs every file beneath it ([layout decision](../decisions/target-workspace-layout.md), [invariant](../invariants/canonical-layout.md)). Examples: [plugin-bot for Claude Code](../modules/plugin-bot-claude-code.md), [plugin-bot for Copilot](../modules/plugin-bot-copilot.md) and the [dogfood sandbox](../modules/dogfood.md).

## The collision

Build tooling uses the same word for something unrelated. `turbo.json` defines `build:dev` and `build:prod` tasks whose outputs are `dist/dev/**` and `dist/prod/**`.[^turbo-config] Sibling Silk repositories drive those with `savvy.build.ts --target dev|prod`, and the silk plugin's guidance and its tsdoc-diagnostics monitor (which watches `dist/<target>/issues.json`) assume that convention in sessions here.[^silk-convention] This repository has no `savvy.build.ts`, and no workspace package defines the two tasks, so the root `build` and `ci:build` scripts run no tasks. The collision therefore lives in tooling vocabulary that agents here read, not in a build this repository runs. A build `--target` selects a build output (development or production), not a host.

| | Plugin target | Build target |
| --- | --- | --- |
| Values | `claude-code`, `copilot` | `dev`, `prod` |
| Where it appears | a path segment under `plugins/` | `--target` in Silk builds, `dist/<target>/` paths, `turbo.json` task names |
| What it selects | which agent host's contract applies | which build output to produce |

## Telling them apart

If the word sits in a path, a plugin name such as `@plugin-bot/copilot-plugin`, or prose about hosts, it means a host directory. If it follows `--` on a build command line or sits in a `dist/<target>/` path, it means a build output. Plugin targets involve no build step at all ([project non-goals](../project.md)), so a build `--target` never applies to anything under `plugins/`.

[^turbo-config]: `../../turbo.json`
[^silk-convention]: Silk plugin guidance and the tsdoc-diagnostics monitor, outside this repository
