---
type: Decision
title: Each distributed target versions independently
description: Each distributed target has a private tracking package whose versionFiles entry bumps its own manifest, so targets are tagged and released without npm publishing.
status: draft
tags:
  - release
sources:
  - resource: ../../.changeset/config.json
  - resource: ../../plugins/plugin-bot/claude-code/package.json
  - resource: ../../plugins/plugin-bot/copilot/package.json
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: aac4138e8fda0ff7e870fcea1819aa294e8ed3c9a4b4157f5a2ec02d2fdc06cc
---

# Each distributed target versions independently

## Context

The Claude Code and Copilot targets change for different reasons and at different rates: a Copilot re-authoring pass is not a Claude Code feature. Changesets versions packages, and a plugin manifest is not a package, so each target needs something for changesets to version.

## Decision

Each distributed target carries a private tracking `package.json`: `@plugin-bot/claude-code-plugin` and `@plugin-bot/copilot-plugin`. Both set `"private": true` and have no `publishConfig`, which keeps them off npm. `.changeset/config.json` gives each a `versionFiles` entry pointing `$.version` at its own manifest (`.claude-plugin/plugin.json` and the root `plugin.json` respectively), so a changeset bumps the package and its manifest in lockstep, tags, and releases without publishing. Each manifest therefore carries an honest version and its own tag.

`plugins/dogfood/claude-code` has no tracking package, because it is a sandbox that is never distributed.

## Alternatives rejected

- **One shared version for both targets.** A change to one host would bump the other's manifest with no change behind it.
- **Publishing the tracking packages to npm.** It would produce an artifact nobody wants; `private` with no `publishConfig` gets the changesets machinery without one.
- **Hand-bumping manifests.** It drops the changelog, tagging and release flow that changesets already provides.

## Consequences

- Releases and tags are per target; see [release a plugin](../runbooks/release-a-plugin.md).
- Adding a distributed target means adding a tracking package and a `versionFiles` entry.
- A manifest whose path changes must be updated in `.changeset/config.json` too, or the bump silently misses it.
