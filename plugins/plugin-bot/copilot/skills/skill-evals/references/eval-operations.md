# Eval operations

The methodology (query counts, split ratios, thresholds, assertion-writing
discipline, grading rules) lives in
the `agent-plugins-docs` skill's `references/skill-authoring-guidance.md`
§ Testing a description and § Evaluating skill output quality. This file
covers what that reference does not: the on-disk shapes, a starting harness,
and how to read results once you have them.

## `evals/evals.json`

Store output-quality test cases beside the skill under test, at
`<skill-dir>/evals/evals.json`, as an array of case objects:

```json
{
  "id": "csv-with-missing-headers",
  "prompt": "Here's sales_q3.csv, can you total the revenue column?",
  "expected_output": "A single number, plus a note about which rows (if any) were skipped and why.",
  "files": ["sales_q3.csv"],
  "assertions": []
}
```

- `id` — short, stable, kebab-case; used as the per-case directory name below.
- `prompt` — the realistic user turn, not a synopsis of the task.
- `expected_output` — a human-readable description of success, not the
  literal output.
- `files` — optional; input files the prompt references.
- `assertions` — starts empty. Fill it in only after the first with/without
  run, per the rule in `SKILL.md`.

When you are evaluating a *revision* to an existing skill rather than a skill
against no skill at all, snapshot the previous `SKILL.md` (and its
`references/`) as the baseline instead of running "without skill" — copy it
to a scratch path before editing and point the baseline run's context at the
copy. Comparing against no skill at all would tell you the skill helps
in general, which you already knew; comparing against the prior version
tells you whether the revision helped.

## Workspace layout

One directory per iteration, one subdirectory per case, one per
configuration:

```text
iteration-1/
  csv-with-missing-headers/
    with_skill/
      outputs/
      timing.json
      grading.json
    without_skill/
      outputs/
      timing.json
      grading.json
  benchmark.json
iteration-2/
  ...
```

- `outputs/` — whatever the run produced (files, transcript, final message).
- `timing.json` — wall-clock and token counts for that one run, the raw
  material `benchmark.json` aggregates.
- `grading.json` — the assertion results for that run, each with the
  concrete evidence the grading discipline requires, not a bare PASS/FAIL.
- `benchmark.json` — one per iteration, aggregating pass rate, timing and
  token deltas between `with_skill` and `without_skill` across all cases in
  that iteration. This is the file the cost/gain call in `SKILL.md` reads.

Keep completed iterations rather than overwriting them — the validation-set
selection rule in the methodology reference ("select the iteration with the
best validation pass rate, which may not be the last one") only works if
earlier iterations are still on disk to compare against.

## Analyzing results

Beyond the drop-both-pass rule in `SKILL.md`, a per-assertion pattern across
the with/without pair tells you something different each time:

| Pattern | Reading |
| :-- | :-- |
| Pass with, pass without | No skill value on this assertion — drop it. |
| Pass with, fail without | The skill is earning its keep here — keep it. |
| Fail with, pass without | Regression: the skill made this case worse. Treat as a bug in the skill body, not noise. |
| Fail with, fail without | Neither configuration clears the bar. Investigate the assertion itself before the skill — it may be unverifiable, out of scope for what a skill can fix, or simply wrong. |

Run-to-run variance — a case's result flipping between otherwise-identical
runs — deserves the same reading here as in a trigger eval: treat it as a
sign the prompt or the skill's instructions are ambiguous, not as model noise
to average away. Ambiguity is fixable; noise invites re-running until you
like the result.

Read `benchmark.json` last, after assertions are settled, to weigh the
trade-off it exists to expose: a skill that costs 13 extra seconds for a
50-point pass-rate gain is worth shipping; one that doubles token usage for a
2-point gain is not, and reads as evidence the body has grown padding rather
than value.

## Bundled trigger-eval harness

`scripts/trigger-harness.sh` runs the query set built per the methodology
reference from a plain text file (one query per line, positives and
negatives in separate files) against a client, some number of times per
query, and reports a per-query trigger rate. Read
`scripts/trigger-harness.sh --help` for the current flags.

The part every client swaps: `check_triggered()`, one function, called once
per run with that run's transcript path. As shipped it looks for a `Skill`
tool invocation naming the skill under test in a Claude Code transcript.
Porting the harness to another client means replacing that one function with
whatever that client exposes as evidence a skill fired — a log line, an
exported trace, a marker string the client's own eval tooling emits — and
leaving the query loop, the run-count, and the trigger-rate arithmetic
untouched.
