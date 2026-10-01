---
type: Gotcha
title: Skill hot-reload is documented for @skills-dir plugins, not --plugin-dir
description: The upstream docs say a SKILL.md edit takes effect immediately, but that note is scoped to @skills-dir plugins, so it is unverified for the pnpm claude loop.
status: draft
tags:
  - dx
stale_after: 2026-12-29T00:00:00Z
sources:
  - resource: ../../plugins/plugin-bot/claude-code/skills/anthropic-docs/references/plugins-reference.md
    id: plugins-reference-note
    title: Distilled plugins reference, skills-directory plugins section
  - resource: https://code.claude.com/docs/en/plugins-reference.md
    id: plugins-reference-upstream
    title: Claude Code plugins reference
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: 9c08539e68345da43a8e4da3eafaf91ec6b7907ffab0b8eae5457814804ab5fe
---

# Skill hot-reload is documented for @skills-dir plugins, not --plugin-dir

## What a reader sees

The Claude Code plugins reference says that changes to a skill's `SKILL.md` take effect immediately in the current session, while hooks, `.mcp.json`, agents and output styles need `/reload-plugins` or a restart.[^plugins-reference-note]

## What they will wrongly conclude

That the same holds for the `pnpm claude` loop, which loads plugins with `--plugin-dir`.

## What is true

The statement sits in the "Skills-directory plugins" section (line 311 of the distilled note), so it is scoped to `@skills-dir` plugins, which are discovered in place. The upstream page is the authority.[^plugins-reference-upstream] Nothing in this repository has verified that a `--plugin-dir` load hot-reloads skills.

Treat skill hot-reload as unverified for this loop: if a skill edit does not land, run `/reload-plugins`. See [the local dev loop](../runbooks/local-plugin-dev-loop.md). The signal comes from the upstream documentation, so this concept names no `resource` in this repository.

[^plugins-reference-note]: `plugins/plugin-bot/claude-code/skills/anthropic-docs/references/plugins-reference.md`, the Edit/reload/disable note.
[^plugins-reference-upstream]: <https://code.claude.com/docs/en/plugins-reference.md>
