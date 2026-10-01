---
type: Measurement
title: plugin-bot target divergence, 2026-09-30
description: How far plugin-bot's claude-code and copilot targets have diverged, file by file, and what kind of difference each one is.
tags:
  - portability
  - architecture
status: draft
stale_after: 2026-12-29T00:00:00Z
justifies: ../roadmaps/single-source-plugin-builds.md
sources:
  - id: claude-code-target
    resource: ../../plugins/plugin-bot/claude-code
    title: plugin-bot Claude Code target
  - id: copilot-target
    resource: ../../plugins/plugin-bot/copilot
    title: plugin-bot Copilot target
generated:
  by: okfit/claude-code
  at: 2026-10-01T03:45:35Z
  body_sha256: 100ef7af5767130ea1b99d776bc00614649d5f7aaac893d74b482abf4a8e4ea8
---

# plugin-bot target divergence, 2026-09-30

## Method

On 2026-09-30, at commit `d7b11dd` on `docs/expore-multi-build`, every file under the two plugin-bot targets was listed relative to its target root, excluding `node_modules`.[^claude-code-target][^copilot-target] The two lists were intersected with `comm`, each common file was compared byte for byte with `cmp`, and every differing file was read with `diff` to classify the difference.

## Numbers

| Measure | Count |
| :-- | --: |
| Files in `claude-code/` | 53 |
| Files in `copilot/` | 54 |
| Files present in both | 50 |
| Byte-identical | 33 |
| Differing | 17 |

The differing files are `CHANGELOG.md` and `package.json`, plus fifteen skill markdown files. The largest diffs are in `skill-authoring`, `plugin-manifest`, `hook-scripts`, `skill-scripts` and `agent-authoring`. The files that exist in only one target are the manifests (`.claude-plugin/plugin.json` against a root `plugin.json`), the agent file under each host's naming (`plugin-engineer.md` against `plugin-engineer.agent.md`), one host-specific bats test each, and the Copilot port ledger `port-status.json`.

## What kinds of difference

- **Mechanical rewrites, the bulk of the lines.** `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/references/<file>.md` in the Claude Code copy becomes "the `<skill>` skill's `references/<file>.md`" in the Copilot copy. Claude-only frontmatter (`paths:`, `user-invocable`, and agent `tools`, `skills`, `color`, `model`) is dropped or reshaped.
- **Fallbacks for a missing host feature.** Copilot has no `paths:` trigger, so the Copilot copy of each path-based skill moves the trigger into the `description` and tells the reader to load the skill themselves. The Claude Code agent's `skills:` frontmatter becomes a "Skills to load before you start" section in the Copilot agent body.
- **Genuinely host-specific prose.** Some passages explain that a field or behaviour exists only on Claude Code. These would stay authored per host in any single-source scheme.

## What this rules in and out

Two thirds of the shared files are already identical, and most of the remaining differences are either mechanical or a recurring fallback pattern. A build that renders one source per host can produce both targets, with only the third category left as explicitly marked per-host passages. It does not rule out that a future host divergence is too large to express as marked passages, and it says nothing about hosts beyond these two.

[^claude-code-target]: `../../plugins/plugin-bot/claude-code`
[^copilot-target]: `../../plugins/plugin-bot/copilot`
