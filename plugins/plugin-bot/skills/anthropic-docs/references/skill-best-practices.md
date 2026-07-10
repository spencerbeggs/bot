# Skill authoring best practices

> Verified against <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md> — 2026-07-10

## Contents

- Conciseness principle
- Degrees of freedom
- Test with all models
- YAML frontmatter validation rules
- Naming conventions
- Writing effective descriptions
- Progressive disclosure patterns
- One-level-deep reference rule
- Table of contents for long reference files
- 500-line SKILL.md cap
- Workflows with checklists
- Feedback loops
- Content guidelines
- Common patterns (template / examples / conditional workflow)
- Eval-first development
- Iterate with Claude (A/B loop)
- Observe how Claude navigates skills
- Anti-patterns
- Scripts: solve-don't-punt and voodoo constants
- Scripts: execute vs read-as-reference intent
- Plan-validate-execute pattern
- Package dependencies
- Runtime environment
- MCP tool references
- Pre-share checklist

## Conciseness principle

The context window is a public good — a skill shares it with the system prompt, conversation history, other skills' metadata, and the user's actual request. Only metadata (name + description) preloads at startup; `SKILL.md` loads when the skill becomes relevant, other files load only as needed. But once loaded, every token in `SKILL.md` competes with everything else.

**Default assumption: Claude is already very smart.** Challenge each piece of information: does Claude really need this explanation? Can I assume Claude knows this? Does this paragraph justify its token cost?

Good (~50 tokens) — states the library and shows minimal code, no PDF/library explainer:

````markdown
## Extract PDF text

Use pdfplumber for text extraction:

```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```
````

Bad (~150 tokens) — explains what a PDF is and why libraries exist before getting to the point. The concise version assumes Claude already knows what PDFs are and how libraries work.

## Degrees of freedom

Match specificity to the task's fragility and variability — think of Claude as a robot on a path: a narrow bridge with cliffs needs exact guardrails (low freedom); an open field needs only general direction (high freedom).

| Freedom | Use when | Form |
| --- | --- | --- |
| High | Multiple valid approaches; decisions depend on context; heuristics guide the approach | Text-based instructions (e.g. a numbered code-review checklist) |
| Medium | A preferred pattern exists; some variation acceptable; configuration affects behavior | Pseudocode or scripts with parameters (e.g. `generate_report(data, format="markdown", include_charts=True)`) |
| Low | Operations are fragile/error-prone; consistency is critical; a specific sequence must be followed | Specific scripts, few/no parameters, explicit "do not modify" instruction (e.g. exact `python scripts/migrate.py --verify --backup` invocation) |

## Test with all models

Skills are additions to models — test with every model you plan to use.

| Model | Check |
| --- | --- |
| Haiku (fast, economical) | Does the skill provide enough guidance? |
| Sonnet (balanced) | Is the skill clear and efficient? |
| Opus (powerful reasoning) | Does the skill avoid over-explaining? |

What works for Opus may need more detail for Haiku. If targeting multiple models, aim for instructions that work across all of them.

## YAML frontmatter validation rules

Two required fields:

| Field | Rules |
| --- | --- |
| `name` | Max 64 characters. Lowercase letters, numbers, hyphens only. No XML tags. No reserved words (`"anthropic"`, `"claude"`). |
| `description` | Non-empty. Max 1024 characters. No XML tags. Should state what the skill does and when to use it. |

## Naming conventions

Prefer **gerund form** (verb + -ing): `processing-pdfs`, `analyzing-spreadsheets`, `managing-databases`, `testing-code`, `writing-documentation`.

Acceptable alternatives: noun phrases (`pdf-processing`, `spreadsheet-analysis`), action-oriented (`process-pdfs`, `analyze-spreadsheets`).

Avoid:

- Vague names: `helper`, `utils`, `tools`
- Overly generic: `documents`, `data`, `files`
- Reserved words: `anthropic-helper`, `claude-tools`
- Inconsistent patterns within your skill collection

## Writing effective descriptions

`description` is injected into the system prompt and is the primary signal Claude uses to select among potentially 100+ skills — it's the only description field, so it must carry both *what* and *when*.

**Always write in third person.** Inconsistent point-of-view causes discovery problems.

- Good: "Processes Excel files and generates reports."
- Avoid: "I can help you process Excel files." / "You can use this to process Excel files."

**Be specific, include key terms** — both what the skill does and the specific triggers/contexts for using it:

```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

```yaml
description: Analyze Excel spreadsheets, create pivot tables, generate charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.
```

```yaml
description: Generate descriptive commit messages by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.
```

Avoid vague descriptions: `Helps with documents`, `Processes data`, `Does stuff with files`.

## Progressive disclosure patterns

`SKILL.md` is an overview that points to detailed materials as needed — like a table of contents. Keep the body under 500 lines; split into separate files as you approach that limit.

**Pattern 1 — high-level guide with references.** `SKILL.md` has a quick-start plus links to `FORMS.md`, `REFERENCE.md`, `EXAMPLES.md`; each loads only when needed.

**Pattern 2 — domain-specific organization.** For multi-domain skills, split by domain so a query about one domain doesn't load the others' context:

```text
bigquery-skill/
├── SKILL.md (overview and navigation)
└── reference/
    ├── finance.md (revenue, billing metrics)
    ├── sales.md (opportunities, pipeline)
    ├── product.md (API usage, features)
    └── marketing.md (campaigns, attribution)
```

`SKILL.md` links to each file and can suggest a `grep` search across the reference directory for specific metrics.

**Pattern 3 — conditional details.** Show basic content inline (e.g. simple edits), link out for the deep case (e.g. "For tracked changes: see REDLINING.md").

## One-level-deep reference rule

Claude may partially read a file that is referenced *from another referenced file* — using something like `head -100` to preview rather than reading it fully — which yields incomplete information. **Keep references one level deep from `SKILL.md`**: all reference files link directly from `SKILL.md`, not from each other, so Claude reads complete files when needed.

Bad: `SKILL.md` → `advanced.md` → `details.md` (details.md never gets a full read). Good: `SKILL.md` links directly to `advanced.md`, `reference.md`, and `examples.md`.

## Table of contents for long reference files

Reference files longer than **100 lines** need a `## Contents` section at the top, so Claude sees the full scope of available information even on a partial read, and can jump to a specific section or read the complete file as needed.

## 500-line SKILL.md cap

Keep `SKILL.md` body under 500 lines for optimal performance. Exceeding it means split into separate files using the progressive disclosure patterns above.

## Workflows with checklists

Break complex operations into clear sequential steps. For particularly complex workflows, provide a checklist Claude can copy into its response and check off as it progresses:

```text
Task Progress:
- [ ] Step 1: Analyze the form (run analyze_form.py)
- [ ] Step 2: Create field mapping (edit fields.json)
- [ ] Step 3: Validate mapping (run validate_fields.py)
- [ ] Step 4: Fill the form (run fill_form.py)
- [ ] Step 5: Verify output (run verify_output.py)
```

This pattern applies both to code-driven workflows (run scripts at each step) and non-code workflows (e.g. a research-synthesis checklist: read sources → identify themes → cross-reference claims → structured summary → verify citations). Clear steps prevent skipping critical validation, and the checklist helps both Claude and the user track progress.

## Feedback loops

Common pattern: **run validator → fix errors → repeat.** This significantly improves output quality. Works with a script validator (`python ooxml/scripts/validate.py unpacked_dir/` → fix → re-run → only proceed once it passes → rebuild → test) or a reference-document "validator" (compare draft against `STYLE_GUIDE.md`, note issues by section, revise, re-check, only finalize once all requirements are met).

## Content guidelines

**Avoid time-sensitive information.** Don't write "before August 2025 use the old API, after use the new API" — it becomes wrong. Instead, state the current method plainly and move anything legacy into an "old patterns" collapsible section:

```markdown
## Current method

Use the v2 API endpoint: `api.example.com/v2/messages`

## Old patterns

<details>
<summary>Legacy v1 API (deprecated 2025-08)</summary>

The v1 API used: `api.example.com/v1/messages`

This endpoint is no longer supported.
</details>
```

**Use consistent terminology.** Pick one term and use it throughout: always "API endpoint" (not URL / API route / path), always "field" (not box / element / control), always "extract" (not pull / get / retrieve). Consistency helps Claude follow instructions.

## Common patterns

**Template pattern** — match strictness to need. Strict (API responses, data formats): "ALWAYS use this exact template structure" with a literal template. Flexible: "Here is a sensible default format, but use your best judgment" with adaptable sections.

**Examples pattern** — for skills where output quality depends on seeing examples, give input/output pairs (e.g. 3 commit-message examples showing `type(scope): description` style). Examples convey desired style/detail level more clearly than descriptions alone.

**Conditional workflow pattern** — guide Claude through decision points: "Creating new content? → Follow 'Creation workflow'. Editing existing content? → Follow 'Editing workflow'." If workflows get large or complicated, push them into separate files and tell Claude to read the appropriate one based on the task.

## Eval-first development

**Create evaluations BEFORE writing extensive documentation** — this ensures the skill solves real problems, not imagined ones.

Evaluation-driven development, in order:

1. **Identify gaps** — run Claude on representative tasks without the skill; document specific failures/missing context.
2. **Create evaluations** — build three scenarios testing those gaps.
3. **Establish baseline** — measure performance without the skill.
4. **Write minimal instructions** — just enough to address the gaps and pass evaluations.
5. **Iterate** — execute evaluations, compare against baseline, refine.

Evaluation structure (data-driven, simple rubric — no built-in runner; users build their own eval system; evaluations are the source of truth for measuring effectiveness):

```json
{
  "skills": ["pdf-processing"],
  "query": "Extract all text from this PDF file and save it to output.txt",
  "files": ["test-files/document.pdf"],
  "expected_behavior": [
    "Successfully reads the PDF file using an appropriate PDF processing library or command-line tool",
    "Extracts text content from all pages in the document without missing any pages",
    "Saves the extracted text to a file named output.txt in a clear, readable format"
  ]
}
```

## Iterate with Claude (A/B loop)

Work with one instance ("Claude A") to design/refine a skill, and a fresh instance ("Claude B", skill loaded) to test it in real tasks. Effective because Claude A understands how to write agent instructions, the human provides domain expertise, and Claude B reveals gaps through real usage.

**Creating a new skill:**

1. Complete a task without a skill using Claude A via normal prompting; notice what context you repeatedly provide.
2. Identify the reusable pattern from that session (e.g. table names, filtering rules, common query patterns).
3. Ask Claude A to create a skill capturing the pattern — Claude models understand the skill format natively, no special meta-skill needed.
4. Review for conciseness — ask Claude A to remove explanations of things Claude already knows.
5. Improve information architecture — e.g. "put the table schema in a separate reference file, we'll add more tables later."
6. Test on similar tasks with Claude B (fresh instance, skill loaded); observe whether it finds the right info, applies rules, succeeds.
7. Iterate — bring specific observed failures back to Claude A ("it forgot to filter by date for Q4 — should we add a section about date filtering?").

**Iterating on existing skills** — the same three-role loop (Claude A refines / Claude B tests / you observe), continuous:

1. Use the skill in real workflows with Claude B, not test scenarios.
2. Observe Claude B's behavior — where it struggles, succeeds, or makes unexpected choices.
3. Return to Claude A with the specific observation and the current `SKILL.md`.
4. Review Claude A's suggestions — may include reorganizing for prominence or using stronger language ("MUST filter" instead of "always filter").
5. Apply and test again with Claude B.
6. Repeat as an observe-refine-test cycle — improve based on observed behavior, not assumptions.

**Team feedback:** share the skill with teammates; ask whether it activates when expected, whether instructions are clear, what's missing; incorporate feedback to catch blind spots in your own usage patterns.

## Observe how Claude navigates skills

Watch for, and iterate based on observation rather than assumption:

- **Unexpected exploration paths** — reading files in an order you didn't anticipate may mean the structure isn't as intuitive as you thought.
- **Missed connections** — failing to follow a reference may mean the link needs to be more explicit/prominent.
- **Overreliance on certain sections** — repeatedly reading the same file may mean that content belongs in the main `SKILL.md`.
- **Ignored content** — a bundled file that's never accessed may be unnecessary or poorly signaled.

`name` and `description` are the most critical fields for this — Claude uses them to decide whether to trigger the skill at all.

## Anti-patterns

**Windows-style paths.** Always use forward slashes, even on Windows: `scripts/helper.py`, not `scripts\helper.py`. Unix-style paths work everywhere; Windows-style paths error on Unix systems.

**Too many options.** Don't present multiple approaches unless necessary. Bad: "You can use pypdf, or pdfplumber, or PyMuPDF, or pdf2image, or...". Good: provide a default with an escape hatch — "Use pdfplumber for text extraction: `import pdfplumber`. For scanned PDFs requiring OCR, use pdf2image with pytesseract instead."

## Scripts: solve-don't-punt and voodoo constants

**Solve, don't punt** — handle error conditions in scripts explicitly rather than letting Claude figure it out from a raw failure. Good: `try/except FileNotFoundError` creates a default file and continues; `except PermissionError` falls back to a default instead of crashing. Bad: `return open(path).read()` with no error handling.

**No "voodoo constants"** (Ousterhout's law) — justify and document config parameters; if the value's rationale isn't known, Claude can't determine the right one either.

- Good: `REQUEST_TIMEOUT = 30  # HTTP requests typically complete within 30 seconds`, `MAX_RETRIES = 3  # balances reliability vs speed`.
- Bad: `TIMEOUT = 47  # Why 47?`, `RETRIES = 5  # Why 5?`

**Provide utility scripts even when Claude could write the code.** Benefits: more reliable than generated code, saves tokens (no code in context), saves time (no codegen), ensures consistency across uses.

## Scripts: execute vs read-as-reference intent

Make explicit in instructions whether Claude should:

- **Execute the script** (most common, more reliable/efficient): "Run `analyze_form.py` to extract fields."
- **Read it as reference** (for complex logic): "See `analyze_form.py` for the field extraction algorithm."

**Visual analysis** — when inputs can be rendered as images (e.g. `pdf_to_images.py`), have Claude analyze the rendered images directly; vision capabilities help with layout/structure understanding.

## Plan-validate-execute pattern

For complex, open-ended, high-stakes tasks (e.g. updating 50 form fields from a spreadsheet), insert a validated intermediate plan file between analysis and execution: **analyze → create plan file → validate plan → execute → verify.**

Why it works:

- Catches errors early — validation finds problems before changes are applied.
- Machine-verifiable — scripts provide objective verification.
- Reversible planning — Claude iterates on the plan without touching originals.
- Clear debugging — error messages point to specific problems.

**When to use:** batch operations, destructive changes, complex validation rules, high-stakes operations.

**Implementation tip:** make validation scripts verbose with specific error messages, e.g. `"Field 'signature_date' not found. Available fields: customer_name, order_total, signature_date_signed"`.

## Package dependencies

Skills run in the code execution environment with platform-specific limits:

- **claude.ai**: can install packages from npm and PyPI, and pull from GitHub repositories.
- **Claude API**: no network access, no runtime package installation.

List required packages in `SKILL.md` and verify they're available in the code execution tool documentation.

## Runtime environment

Skills run with filesystem access, bash commands, and code execution.

- **Metadata pre-loaded** — at startup, `name` + `description` from every skill's YAML frontmatter load into the system prompt.
- **Files read on-demand** — Claude uses bash/Read tools to access `SKILL.md` and other files from the filesystem when needed.
- **Scripts executed efficiently** — utility scripts run via bash without loading their full contents into context; only the script's output consumes tokens.
- **No context penalty for large files** — reference files, data, documentation cost zero tokens until actually read.

Authoring implications:

- File paths: forward slashes only (`reference/guide.md`), never backslashes.
- Name files descriptively: `form_validation_rules.md`, not `doc2.md`.
- Organize by domain for discovery: `reference/finance.md`, `reference/sales.md` — not `docs/file1.md`, `docs/file2.md`.
- Bundle comprehensive resources (complete API docs, extensive examples, large datasets) — no penalty until accessed.
- Prefer scripts for deterministic operations: write `validate_form.py` rather than asking Claude to generate validation code each time.
- Test file access patterns with real requests to confirm Claude can navigate the directory structure.

## MCP tool references

Always use fully qualified tool names — `ServerName:tool_name` — to avoid "tool not found" errors, especially when multiple MCP servers are available:

```markdown
Use the BigQuery:bigquery_schema tool to retrieve table schemas.
Use the GitHub:create_issue tool to create issues.
```

Without the server prefix, Claude may fail to locate the tool.

**Don't assume tools/packages are installed.** Bad: "Use the pdf library to process the file." Good: "Install required package: `pip install pypdf`" followed by the usage code.

## Pre-share checklist

### Core quality

- [ ] Description is specific and includes key terms
- [ ] Description includes both what the skill does and when to use it
- [ ] SKILL.md body is under 500 lines
- [ ] Additional details are in separate files (if needed)
- [ ] No time-sensitive information (or in "old patterns" section)
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract
- [ ] File references are one level deep
- [ ] Progressive disclosure used appropriately
- [ ] Workflows have clear steps

### Code and scripts

- [ ] Scripts solve problems rather than punt to Claude
- [ ] Error handling is explicit and helpful
- [ ] No "voodoo constants" (all values justified)
- [ ] Required packages listed in instructions and verified as available
- [ ] Scripts have clear documentation
- [ ] No Windows-style paths (all forward slashes)
- [ ] Validation/verification steps for critical operations
- [ ] Feedback loops included for quality-critical tasks

### Testing

- [ ] At least three evaluations created
- [ ] Tested with Haiku, Sonnet, and Opus
- [ ] Tested with real usage scenarios
- [ ] Team feedback incorporated (if applicable)
