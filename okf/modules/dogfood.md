---
type: Module
kind: harness
title: dogfood sandbox
description: A sandbox plugin loaded by pnpm claude and never distributed, into which dogfood cycles build capabilities to exercise plugin-bot.
resource: ../../plugins/dogfood/claude-code
status: draft
tags:
  - dx
  - testing
generated:
  by: okfit/claude-code
  at: 2026-10-01T02:17:55Z
  body_sha256: aa168ae018ed2cdced0aeb7e63f785b973fc7fd253c1e3de6bf455cca7694875
sources:
  - resource: ../../.claude/skills/dogfood/SKILL.md
    id: dogfood-skill
    title: Repo-local dogfood skill
  - resource: ../../plugins/dogfood/claude-code/.claude-plugin/plugin.json
    id: sandbox-manifest
    title: Sandbox manifest
---

# dogfood sandbox

`plugins/dogfood/claude-code` is a disposable sandbox plugin. At rest it contains only `.claude-plugin/plugin.json`.[^sandbox-manifest] `pnpm claude` loads it alongside [plugin-bot](plugin-bot-claude-code.md) ([local dev loop](../runbooks/local-plugin-dev-loop.md)). It is never distributed through the marketplace, so it deliberately has no tracking package: nothing versions or releases it.

## The dogfood workflow

The repo-local `/dogfood` skill (`.claude/skills/dogfood`) exercises plugin-bot by making it do its job.[^dogfood-skill] A cycle:

1. Confirm the sandbox is clean.
2. Task the `plugin-engineer` agent with building the requested capability inside the sandbox, using `plugin-setup`.
3. Validate with `claude plugin validate plugins/dogfood/claude-code --strict`.
4. Reload with `/reload-plugins` and observe the components live.
5. Evaluate: skill-creator evals for skills, hook fixtures and BATS for hooks, a representative task for agents and commands.
6. Harvest rough edges: each place plugin-bot's guidance was wrong, missing, ambiguous or ignored becomes a note naming what happened, the owning plugin-bot file and the proving artifact.
7. Reset the sandbox with confirmation.

Harvest and fix are deliberately separate passes. The cycle never edits plugin-bot; fixes happen in a later pass that takes the notes as input. That separation is what keeps the harvest honest, because the sandbox is disposable and plugin-bot is not.

[^dogfood-skill]: `../../.claude/skills/dogfood/SKILL.md`
[^sandbox-manifest]: `../../plugins/dogfood/claude-code/.claude-plugin/plugin.json`
