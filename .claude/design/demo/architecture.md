---
status: draft
module: demo
category: architecture
created: 2026-07-10
updated: 2026-07-10
last-synced: never
completeness: 40
related:
  - ../plugin-dev/architecture.md
dependencies: []
---

# demo - Architecture

A minimal hello-world package (`@spencerbeggs/demo`, `packages/demo`) that proves out the repo's standard Node.js build and test pipeline.

## Table of contents

1. [Overview](#overview)
2. [Current State](#current-state)
3. [Rationale](#rationale)
4. [Related Documentation](#related-documentation)

---

## Overview

This repo carries the standard spencerbeggs build system for publishable Node packages under `packages/*`. demo is the known-good package that exercises that pipeline end to end: source, tests, typecheck, bundling and publish layout. It is private and not itself a deliverable.

**When to reference this document:** when adding a new package under `packages/*`, when debugging the build or test pipeline, or when creating a companion Node module for a Claude Code plugin.

---

## Current State

- Source is a single entry point at `packages/demo/src/index.ts`; the package exports raw TypeScript (`exports` maps to `./src/index.ts`) and the bundler produces the publishable artifact.
- Builds run through `savvy.build.ts` with `@savvy-web/bundler` (`build:dev` / `build:prod` targets); publishing uses `publishConfig.directory: dist/dev/pkg`.
- Typecheck is `tsgo --noEmit` (`types:check`).
- Tests live in `packages/demo/__test__/` (unit, integration, e2e, fixtures) and run through the vitest-agent MCP reporter — see `__test__/CLAUDE.md` there for suite conventions.

See `packages/demo/package.json` for the authoritative scripts, exports and publish configuration.

---

## Rationale

**Why keep a demo package:** pipeline changes (bundler upgrades, turbo task graph, publish flow) need a low-stakes package to validate against before real packages exist. demo is that canary.

**Why it matters for plugins:** Claude Code plugins developed in this repo (`plugins/*`) can be paired with companion Node modules built by this same pipeline — demo is the template for that pattern. See [plugin-dev architecture](../plugin-dev/architecture.md).

---

## Related Documentation

- [plugin-dev architecture](../plugin-dev/architecture.md) — the first repo-native plugin and prospective consumer of the companion-module pattern.
- `packages/demo/package.json` — authoritative build/publish configuration.

---

**Document Status:** draft — accurate as of initial scaffold; expand if demo grows beyond a pipeline canary.

**Next Steps:** update when the first real companion module is created from this pattern.
