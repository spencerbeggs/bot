---
name: skill-evals
description: Use when a skill needs to be proven rather than assumed — testing whether its description triggers on the right prompts and not the wrong ones, or whether its body actually improves output over no skill at all. Covers trigger evals with a train/validation split, output-quality evals against a without-skill baseline, writing assertions that can fail, and the analysis rules that separate a skill that helps from one that merely runs.
---

# Proving a skill instead of assuming it

A skill you wrote and never ran against real prompts is a hypothesis, not a
result. Two independent things can be wrong with it: the `description` might
not fire on the prompts it should (or might fire on ones it shouldn't), and
the body might not actually move the output — an agent that already handles
the task well produces the same answer with or without it. Trigger evals test
the first; output-quality evals test the second. A skill can pass either one
alone and still be worthless.

**Full methodology — query counts, the 60/40 split, the trigger-rate
threshold, the `evals.json` shape, and the grading discipline — lives in
`${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/skill-authoring-guidance.md`
§ Testing a description and § Evaluating skill output quality. Read both
before running either kind of eval; this skill does not restate them.** What
follows is what that reference does not cover: whether running an eval is
worth it here, the workspace loop, and the judgment calls a reader hits
mid-eval that no rule resolves for them.

## The two rules that decide whether an eval means anything

**Drop every assertion that passes in both the with-skill and without-skill
configurations.** An assertion that passes either way tells you the model
already did that without help — keeping it inflates the with-skill pass rate
while reflecting no skill value. The assertions that pass with the skill and
fail without it are the only ones measuring the skill itself. Do this review
after every run, not once at the end; a skill revision can turn a
skill-earning assertion back into a both-pass one.

The second rule that protects the first: **write assertions after reading the
first pair of outputs, not before.** You are guessing at "good" until you have
seen what the model actually produces with and without the skill — assertions
written from imagination tend to be the vague or brittle kind the grading
reference already tells you to avoid.

## Is an eval worth running here?

Not every skill needs both kinds, and neither is free — a full output-quality
pass burns a with/without pair per case per iteration. Reach for:

- **A trigger eval** when the skill's description could plausibly overlap
  with another skill's, when it names a domain broad enough to false-positive
  on casual mentions, or when its value depends on firing in cases where the
  user doesn't name the domain explicitly (the description is deliberately
  pushy — pushy descriptions are exactly the ones that also false-trigger).
- **An output-quality eval** when the skill's body makes a claim you have not
  watched an agent act on — a procedure, a gotcha, a script — especially one
  synthesized rather than extracted from a real corrected task. A skill that
  is nothing but a pointer to another reference, or that only reformats
  something the agent already does correctly, is a candidate to skip: the
  reference above says as much — "if the agent already handles the whole task
  well without the skill, the skill may not be adding value at all", and an
  eval is how you find out rather than guess.
- **Neither**, yet, for a skill still changing shape from edit to edit. Evals
  are for a body and description that have stabilized enough that a
  train-set failure is worth chasing rather than thrown away on the next
  rewrite.

## The operational loop

1. **Trigger eval.** Build the query set and harness per the methodology
   reference. `references/eval-operations.md` bundles a starting
   `scripts/trigger-harness.sh` and the client-swap point inside it.
2. **Output-quality eval.** Lay out `evals/evals.json` and the per-iteration
   workspace per `references/eval-operations.md` § Workspace layout, then run
   each case with-skill and without-skill.
3. **Run every configuration in a clean context.** Spawn each with-skill and
   without-skill run as its own fresh agent invocation — never a fork of the
   session that has been discussing the skill, and never two configurations
   in the same conversation. A fork inherits the parent's full context; if
   that context has been talking about the skill under test, the "without
   skill" run is not actually skill-free, and the comparison is void before
   the first assertion runs.
4. **Grade, then apply the drop-assertions rule above**, then read
   `benchmark.json` (timing and token cost) before deciding whether the
   skill's gain is worth what it costs — see `references/eval-operations.md`
   § Analyzing results for the cost/gain call and what each failure pattern
   (always-fail-both, high run-to-run variance) usually means.
5. Revise, and re-run only the failing train queries or cases — re-running
   everything every iteration is how an eval session stops being worth its
   cost.

## Read next

- `references/eval-operations.md` — `evals.json` schema, the
  `iteration-N/<eval>/{with_skill,without_skill}` workspace, the analysis
  matrix beyond the drop-both-pass rule above, and the bundled trigger-eval
  harness.
