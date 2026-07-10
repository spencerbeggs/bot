---
name: dogfood
description: Runs a dogfood cycle against plugin-bot — tasks the plugin-engineer agent with building a plugin capability inside the plugins/dogfood sandbox, validates and reloads it, evaluates the result (skill-creator evals for skills, fixtures/BATS for hooks), and harvests rough edges in plugin-bot's own skills and agent as improvement notes. Use after changing plugin-bot to exercise it end to end.
disable-model-invocation: true
argument-hint: "<what the sandbox plugin should do>"
---

# Dogfood cycle

Exercise plugin-bot by making it do its job: build a real plugin capability in the `plugins/dogfood` sandbox, then grade both the artifact and the guidance system that produced it. This is a repo-local skill (like effected's `improve`): it may assume this repo's layout, which shipped plugins never can.

The build target: **$ARGUMENTS**

## Cycle checklist

Copy this checklist and track your progress:

```text
Dogfood progress:
- [ ] 1. Sandbox clean
- [ ] 2. Build dispatched to plugin-engineer
- [ ] 3. Artifact validated (--strict)
- [ ] 4. Reloaded and observed live
- [ ] 5. Evaluated (skill-creator evals / BATS)
- [ ] 6. Rough edges harvested
- [ ] 7. Sandbox reset
```

**1. Sandbox clean.** `plugins/dogfood` must contain only `.claude-plugin/plugin.json`. If a prior cycle left components behind, ask the user whether to reset before building.

**2. Dispatch the build.** Send the task to the `plugin-bot:plugin-engineer` agent: build, inside `plugins/dogfood`, a plugin that does what $ARGUMENTS describes, using the `plugin-setup` skill for scaffolding. Do not build it yourself in the main context — the point is exercising the agent, its preloads and the path enforcers. While it works, note which skills fire and which references it reads.

**3. Validate the artifact.** `claude plugin validate plugins/dogfood --strict` must pass before anything else counts.

**4. Reload and observe.** Ask the user to run `/reload-plugins`, then exercise the built components live (invoke its skills, trigger its hooks with matching actions).

**5. Evaluate.**

- Skills the cycle produced: run a skill-creator eval cycle per skill — ask it to evaluate the skill, let it write `evals/evals.json` in the skill directory, run the isolated with/without comparison, and read the grading and benchmark output.
- Hooks the cycle produced: pipe each `hooks/fixtures/*.json` envelope through its script and run the BATS suite.
- Agents/commands: dispatch them on one representative task each.

**6. Harvest rough edges.** The real product of the cycle. For every point where plugin-bot's guidance was wrong, missing, ambiguous or ignored — an enforcer that didn't fire or misled, a reference that lacked a needed contract, a plugin-setup step that didn't survive contact, agent behavior that contradicted its prompt — record one note: what happened, which plugin-bot file owns it, and the artifact that proves it (the built file, the eval result, the transcript moment). Harvest only; do NOT edit plugin-bot mid-cycle. Fixes happen in a follow-up pass with the notes as input.

**7. Reset the sandbox.** With user confirmation, remove everything under `plugins/dogfood` except `.claude-plugin/plugin.json`, so the next cycle starts clean.

## Rules

- The sandbox is disposable; plugin-bot is not. Nothing in this cycle edits `plugins/plugin-bot` — that separation is what makes the harvest honest.
- If step 2's agent stalls on missing guidance, that IS a harvest finding — record it, unblock the agent with the answer, and keep going.
- Time-box evals: one skill-creator cycle per produced skill is enough; this is a smoke-and-grade loop, not a benchmark suite.
