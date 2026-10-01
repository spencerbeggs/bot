---
type: Runbook
title: Release a plugin
description: How a merged changeset against a plugin's tracking package becomes a bumped manifest, a release, and a pinned marketplace entry for the Claude Code target.
resource: ../../.github/workflows/release.yml
tags:
  - release
  - ci
  - github
status: draft
sources:
  - id: release-workflow
    resource: ../../.github/workflows/release.yml
    title: Release workflow
  - id: repin-workflow
    resource: ../../.github/workflows/repin-plugins.yml
    title: Repin workflow
  - id: changeset-config
    resource: ../../.changeset/config.json
    title: Changesets configuration
  - id: claude-tracking-package
    resource: ../../plugins/plugin-bot/claude-code/package.json
    title: Claude Code tracking package
  - id: copilot-tracking-package
    resource: ../../plugins/plugin-bot/copilot/package.json
    title: Copilot tracking package
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: ebc1e2190dcf45b0ab703be4d8e5eeb50f1fee51b6801a4ab8f5fa24660c90bd
---

# Release a plugin

## Trigger

A changeset naming `@plugin-bot/claude-code-plugin` or `@plugin-bot/copilot-plugin` is merged to `main`. Each of those packages is private and never published to npm; it exists so changesets has something to version, and the plugin manifest is bumped alongside it.[^claude-tracking-package][^copilot-tracking-package] The versioning rationale is in [per-target versioning](../decisions/per-target-versioning.md).

## Steps

1. Write a changeset against the tracking package of each target that changed. A human decides whether to write it and when; an agent does not create one.
2. The `Silk` workflow runs on pushes to `main` and on pull requests, and delegates to a reusable release workflow in `spencerbeggs/.github`.[^release-workflow] Everything past this point inside that reusable workflow is not visible in this repository, so the exact mechanics of the release pull request, tagging and release creation are not documented here. The call passes `auto-merge: "squash"`, and `privatePackages` is configured with `tag: true` and `version: true`, so private packages are versioned and tagged.[^changeset-config]
3. When changesets applies the version, `versionFiles` rewrites `$.version` in the plugin manifest next to the package version: `plugins/plugin-bot/claude-code/.claude-plugin/plugin.json` for the Claude Code package and `plugins/plugin-bot/copilot/plugin.json` for the Copilot package.[^changeset-config]
4. A `plugin-release` repository dispatch triggers the `Repin Claude Code Plugins` workflow.[^repin-workflow] That the reusable release workflow is what sends the dispatch cannot be confirmed from this repository's YAML; the receiving side is the only part visible here. The workflow can also be run by hand with optional `name`, `marketplace`, `sha`, `path` and `json` inputs.
5. The repin job checks out the repository and runs `spencerbeggs/ai-plugin-marketplace-manager` in `commit` mode, passing the dispatch payload's `json` when triggered by dispatch. The `marketplace` input defaults to `claude-code`. The action writes the released commit's sha into `.claude-plugin/marketplace.json`.[^repin-workflow] The commit history of that file shows repin commits titled `ai(marketplace): repinned <plugin>@spencerbeggs`, which is the visible result. What the action does when a dispatch carries no `marketplace` input is not stated in the YAML.
6. Bump the Copilot entry by hand. The `plugin-bot` entry in `.github/plugin/marketplace.json` is a `github` source with no `sha`, and nothing in this repository's workflows repins it on the automatic path. The manual dispatch exposes `marketplace: copilot` as an option, but whether that works for plugin-bot is unverified; see [plugin-bot next steps](../roadmaps/plugin-bot-next.md).

## End state

The `plugin-bot` entry in `.claude-plugin/marketplace.json` is a `git-subdir` source whose `sha` is the released commit, and the manifest `version` in the plugin directory matches the tracking package. Check both in the repository; the Copilot entry is pinned only if step 6 was done. The manifest shapes are in [marketplace manifests](../interfaces/marketplace-manifests.md), and why a marketplace never serves the working tree is in [the marketplace gotcha](../gotchas/marketplace-never-serves-working-tree.md).

[^release-workflow]: `../../.github/workflows/release.yml`
[^repin-workflow]: `../../.github/workflows/repin-plugins.yml`
[^changeset-config]: `../../.changeset/config.json`
[^claude-tracking-package]: `../../plugins/plugin-bot/claude-code/package.json`
[^copilot-tracking-package]: `../../plugins/plugin-bot/copilot/package.json`
