---
type: Limitation
title: The port ledger tracks only skill and agent markdown
description: port-status.sh --check covers skills/**/*.md and agents/**/*.md, so a green check means the ported skills and agents are current, not that the port is complete.
status: draft
bounds: ../modules/plugin-bot-copilot.md
tags:
  - portability
  - testing
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: bc50493c05c0983afe125e69fa66205292318d40dfaadd3f73d6ec60595ce5ad
sources:
  - resource: ../../plugins/plugin-bot/claude-code/skills/porting-to-copilot/scripts/port-status.sh
    title: The ledger tool; its file sweep is a find over skills and agents for .md files
  - resource: ../../plugins/plugin-bot/copilot/__test__/port-drift.bats
    title: The suite that covers part of what the ledger cannot see
---

# The port ledger tracks only skill and agent markdown

## Condition and symptom

`port-status.sh` hashes the source side of the Copilot port and records it in `port-status.json`. Its file sweep is `find skills agents -type f -name '*.md'`, so it tracks `skills/**/*.md` and `agents/**/*.md` and nothing else. `plugin.json`, `hooks.json` and `.mcp.json` can drift between the two targets while `--check` stays green.

So green means "every ported skill and agent is current". It does not mean "the port is complete". `--check` also never reads a port file; it compares source hashes to recorded hashes, so it cannot see what a port says either.

## What covers the gap today

`plugins/plugin-bot/copilot/__test__/port-drift.bats` adds checks the ledger lacks. It asserts that `hooks.json` and `.mcp.json` are matched across targets or ledgered as `claudeOnly`, and that every non-Markdown file under `skills`, `agents` and `__test__` is byte-identical across the two targets. Neither check compares `plugin.json`, whose two copies differ by host by design, and neither compares the content of a `hooks.json` or `.mcp.json` that exists on both sides.

## Why it is acceptable

The Markdown bodies are re-authored per host, so a content hash on the source is the right currency signal for them. The manifests are few and small, and the bats suite catches the cheapest failures.

## What a fix would take

Either extend the ledger globs in `port-status.sh` to include the manifest and host-config files, or add a companion check, in the script or the bats suite, for `plugin.json`, `hooks.json` and `.mcp.json` content. The manifests legitimately differ, so any such check has to compare the fields that should match, not whole files. The module this bounds is [the Copilot plugin](../modules/plugin-bot-copilot.md).
