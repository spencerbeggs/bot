# Skill authoring guidance

> Verified against <https://agentskills.io/skill-creation/best-practices.md> — 2026-09-07
> Verified against <https://agentskills.io/skill-creation/optimizing-descriptions.md> — 2026-09-07
> Verified against <https://agentskills.io/skill-creation/evaluating-skills.md> — 2026-09-07
> Verified against <https://agentskills.io/skill-creation/using-scripts.md> — 2026-09-07

Quality rules for skill content, host-independent. The spec says what a skill *may* contain; this says what makes one worth activating.

## Ground the skill in real expertise

Asking an LLM to generate a skill from general training knowledge produces vague procedures — "handle errors appropriately", "follow best practices for authentication" — instead of the specific API patterns, edge cases and project conventions that make a skill valuable. Two sources of real material:

- **Extract from a hands-on task.** Complete a real task with an agent, then extract the reusable pattern. Watch for: the steps that worked, the corrections you made, the input/output formats, and the project-specific context the agent did not already have.
- **Synthesize from project artifacts.** Runbooks, style guides, API specs and schemas, code review comments, version-control history (patches and fixes reveal patterns through what actually changed), and real failure cases with their resolutions.

Then **refine with real execution**: run the skill against real tasks and feed all results back — not only the failures. Ask what triggered false positives, what was missed, what could be cut. Read the execution traces, not just the final outputs: an agent wasting turns usually means instructions that are too vague, instructions that do not apply to this task, or too many options with no clear default.

## Spending context wisely

Once a skill activates, its whole `SKILL.md` body competes for attention with conversation history, system context and every other active skill.

### Add what the agent lacks, omit what it knows

Focus on what the agent *would not* know: project conventions, domain procedures, non-obvious edge cases, the particular tools or APIs to use. Do not explain what a PDF is, how HTTP works, or what a database migration does.

The test for every piece of content:

> "Would the agent get this wrong without this instruction?"

If the answer is no, **cut it**. If you are unsure, test it. And if the agent already handles the whole task well without the skill, the skill may not be adding value at all.

### Design coherent units

Scoping a skill is like scoping a function: it should encapsulate a coherent unit of work that composes with other skills. Too narrow forces several skills to load for one task, risking overhead and conflicting instructions. Too broad makes it hard to activate precisely.

### Aim for moderate detail

Overly comprehensive skills hurt: the agent struggles to extract what is relevant and pursues unproductive paths triggered by instructions that do not apply. Concise, stepwise guidance with a working example beats exhaustive documentation. When you find yourself covering every edge case, consider whether most are better left to the agent's judgment.

### Structure large skills with progressive disclosure

Keep `SKILL.md` under 500 lines and 5000 tokens — the core instructions needed on every run. Move detail into `references/`.

The key is telling the agent **when** to load each file. "Read `references/api-errors.md` if the API returns a non-200 status code" is far more useful than "see references/ for details". Without the guard, progressive disclosure does not work: the agent cannot judge whether a file is worth a read from its filename alone.

## Calibrating control

### Match specificity to fragility

**Give the agent freedom** where multiple approaches are valid and the task tolerates variation. For flexible instructions, explaining *why* beats a rigid directive — an agent that understands the purpose makes better context-dependent decisions.

**Be prescriptive** where operations are fragile, consistency matters, or a specific sequence must be followed ("Run exactly this sequence… Do not modify the command or add additional flags").

Most skills mix both. **Calibrate each part independently.**

### Provide defaults, not menus

When several tools could work, pick one and mention alternatives briefly rather than presenting equals.

```markdown
<!-- Too many options -->
You can use pypdf, pdfplumber, PyMuPDF, or pdf2image...

<!-- Clear default with escape hatch -->
Use pdfplumber for text extraction. For scanned PDFs requiring OCR, use
pdf2image with pytesseract instead.
```

### Favor procedures over declarations

A skill teaches the agent *how to approach* a class of problems, not *what to produce* for one instance.

```markdown
<!-- Specific answer — only useful for this exact task -->
Join the `orders` table to `customers` on `customer_id`, filter where
`region = 'EMEA'`, and sum the `amount` column.

<!-- Reusable method — works for any analytical query -->
1. Read the schema from `references/schema.yaml` to find relevant tables
2. Join tables using the `_id` foreign key convention
3. Apply any filters from the user's request as WHERE clauses
4. Aggregate numeric columns as needed and format as a markdown table
```

Specific details are still allowed — output templates, constraints like "never output PII", tool-specific instructions. The point is that the *approach* generalizes even when the details do not.

## Patterns for effective instructions

### Gotchas sections

The highest-value content in many skills. Not general advice but concrete corrections to mistakes the agent will make without being told:

```markdown
## Gotchas

- The `users` table uses soft deletes. Queries must include
  `WHERE deleted_at IS NULL` or results will include deactivated accounts.
- The `/health` endpoint returns 200 as long as the web server is running,
  even if the database connection is down. Use `/ready` instead.
```

**Keep gotchas in `SKILL.md`, not in a reference.** A reference works only if you tell the agent when to load it — and for non-obvious issues the agent may not recognise the trigger. When you have to correct an agent, add the correction here; it is the most direct way to improve a skill.

### Other patterns

- **Templates for output format** — agents pattern-match against concrete structures better than against prose descriptions. Short templates inline; long or conditional ones in `assets/`.
- **Checklists for multi-step workflows** — an explicit progress list keeps the agent from skipping steps with dependencies or validation gates.
- **Validation loops** — do the work, run a validator, fix issues, repeat until it passes. A reference document can serve as the validator.
- **Plan–validate–execute** — for batch or destructive operations: produce an intermediate plan in a structured format, validate it against a source of truth with a script, then execute. The validation step is the ingredient that matters; its error messages should name what was expected and what is available.
- **Bundling reusable scripts** — if traces show the agent reinventing the same logic each run, write it once and bundle it in `scripts/`.

## Description rules

The `description` carries the entire burden of triggering — at startup the agent sees only `name` and `description`.

- **Use imperative phrasing.** "Use this skill when…", not "This skill does…". The agent is deciding whether to act; tell it when to act.
- **Focus on user intent, not implementation.** The agent matches against what the user asked for, not the skill's internals.
- **Err on the side of being pushy.** List the contexts where the skill applies, including cases where the user does not name the domain: "even if they don't explicitly mention 'CSV' or 'analysis.'"
- **Keep it concise.** A few sentences to a short paragraph. The **hard limit is 1024 characters**; descriptions tend to grow during optimization, so re-check it.

One nuance worth knowing: agents typically consult skills only for tasks needing knowledge beyond what they can handle alone. A one-step "read this PDF" may not trigger a PDF skill however well the description matches.

### Testing a description

Build ~20 eval queries, 8–10 that should trigger and 8–10 that should not. Vary phrasing, explicitness, detail and complexity; include realistic file paths, personal context and typos. The valuable negatives are **near-misses** that share keywords but need something else — "obviously irrelevant" queries test nothing.

Run each query ~3 times and compute a trigger rate; 0.5 is a reasonable pass threshold. Split the query set train (~60%) / validation (~40%) and use only train failures to guide edits, or you overfit to phrasings. Avoid adding literal keywords from failed queries — find the general category they represent. Five iterations is usually enough; select the iteration with the best validation pass rate, which may not be the last one.

## Evaluating skill output quality

Run each test case twice — **with the skill and without it** (or against the previous version) — so you have a baseline. A test case is a realistic prompt, a human-readable description of success, and any input files; store them in `evals/evals.json`. Start with 2–3 cases before over-investing.

Write **assertions** after you see the first outputs, not before. Good assertions are programmatically verifiable, specific and observable, or countable. Weak ones are vague ("the output is good") or brittle (requiring an exact phrase). Not everything needs an assertion — style and "feels right" belong to human review.

When grading, require concrete evidence for a PASS and do not give the benefit of the doubt; a section titled "Summary" with one vague sentence is a FAIL. Review the assertions themselves as you go, and drop the ones that pass in both configurations — they inflate the with-skill rate without reflecting any skill value. The assertions that pass with the skill and fail without are where the skill is earning its keep.

Feed failed assertions, human feedback and execution transcripts back into the next revision. Generalize rather than patching specific examples, keep the skill lean (if pass rates plateau while rules accumulate, try *removing* instructions), and explain the why — "Do X because Y tends to cause Z" outperforms "ALWAYS do X, NEVER do Y".

## Script design for agentic use

When an agent runs a script it reads stdout and stderr to decide what to do next. These rules decide whether an agent can drive the script at all.

- **Never block on interactive input.** A hard requirement: agents run in non-interactive shells and cannot answer TTY prompts, password dialogs or confirmation menus. A script that blocks hangs indefinitely. Accept input via flags, environment variables or stdin, and fail with a message naming the missing flag and its options.
- **Document usage with `--help`.** This is the primary way an agent learns the interface: brief description, flags, usage examples. Keep it short — it enters the context window.
- **Use structured output, with diagnostics separated.** Prefer JSON/CSV/TSV over whitespace-aligned text so both the agent and `jq`/`cut`/`awk` can consume it. Send structured data to **stdout** and progress messages, warnings and diagnostics to **stderr**.
- **Write helpful errors.** Say what went wrong, what was expected, and what to try: `Error: --format must be one of: json, csv, table. Received: "xml"`. An opaque "invalid input" wastes a turn.
- **Be idempotent.** Agents retry commands; "create if not exists" is safer than "create and fail on duplicate".
- **Constrain input.** Reject ambiguous input with a clear error rather than guessing. Use enums and closed sets.
- **Support `--dry-run`** for destructive or stateful operations, and consider explicit `--confirm`/`--force` safeguards.
- **Use meaningful, documented exit codes** — distinct codes per failure class (not found, invalid arguments, auth failure), documented in `--help`.
- **Keep output size predictable.** Many agent harnesses truncate tool output past a threshold (e.g. 10–30K characters), silently losing information. Default to a summary or a sane limit and support `--offset` for more; or require an explicit `--output` naming a file, or `-` to opt into stdout.

Reference bundled scripts by **relative path from the skill root** — the agent resolves them and runs commands from there. The same convention holds inside `references/*.md`. List available scripts in `SKILL.md` so the agent knows they exist.

For one-off commands, pin versions (`npx eslint@9.0.0`) and state prerequisites in `SKILL.md` or the `compatibility` field rather than assuming the environment. Move a command into a script once it grows complex enough to be hard to get right first try.
