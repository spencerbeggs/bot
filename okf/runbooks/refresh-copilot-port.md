---
type: Runbook
title: Refresh the Copilot port
description: Re-author stale Copilot skills and agents after the Claude Code source changes, then re-pin the port ledger.
status: draft
resource: ../../plugins/plugin-bot/claude-code/skills/porting-to-copilot/scripts/port-status.sh
tags:
  - portability
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: 8a57cbb17ed38ad0f7bb0f38c7b1984431869d0ba218a01b91807d26cdcf3d80
---

# Refresh the Copilot port

**Trigger:** a change under `plugins/plugin-bot/claude-code/` to skills or agents, or a failure of the `port-drift.bats` test.

## Steps

1. Read the `porting-to-copilot` skill before touching anything under `copilot/`; `claude-code/` leads and the port trails.
2. Report drift:

   ```bash
   bash plugins/plugin-bot/claude-code/skills/porting-to-copilot/scripts/port-status.sh \
     --source plugins/plugin-bot/claude-code \
     --port plugins/plugin-bot/copilot \
     --ledger plugins/plugin-bot/copilot/port-status.json \
     --check
   ```

3. Re-author each stale file under `plugins/plugin-bot/copilot/`.
4. Run the same command with `--record` in place of `--check` to pin the new hashes.
5. Run `pnpm test:bats`.

## End state

`--check` reports green.

## Caveat

Green means every ported skill and agent is current, not that the port is complete: the ledger does not cover manifests or hook registrations. See [port ledger coverage](../limitations/port-ledger-coverage.md).
