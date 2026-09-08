---
name: skill-authoring
description: Read before creating or editing any SKILL.md or command markdown file — skills/**/SKILL.md, .claude/skills/**/SKILL.md, or commands/*.md. Nothing loads this skill automatically on this host, so reach for it yourself the moment one of those files comes into scope. Enforces SKILL.md frontmatter and body conventions — the Agent Skills specification floor that holds on every host, then each host's additions. Covers name and description constraints, description quality and trigger accuracy, the Claude-only invocation fields and what replaces them elsewhere, archetype fit, progressive disclosure, and the body-size cap.
---

# Skill authoring checklist

Apply this to the file you are about to create or edit, top to bottom. This host fires no skill on a file being opened, so you are reading this because you reached for it — finish it before the first edit, not after. The two mistakes that break triggering most often: a description that summarizes the workflow instead of stating trigger conditions, and a `paths:` glob broad enough to auto-load on unrelated files.

**Scope note**: the spec-floor rules below (name grammar, directory match, description length, body cap) are the Agent Skills specification and apply only to `SKILL.md`. A command markdown file under `**/commands/*.md` has its own, unrelated frontmatter schema — it is in scope for the trigger-quality and description rules in this checklist, not for the spec floor.

## Checklist

1. **Description is trigger-only, third person, "Use when...".** If it narrates steps ("reads the diff, then writes a message, then runs tests"), Claude follows the description as a shortcut and skips the body. Rewrite to state only when the skill applies.
2. **`description` alone stays under the 1,024-char platform hard cap; combined `description` + `when_to_use` stays under the 1,536-char listing cap.** Lead with the strongest trigger phrase first — it's what gets matched.
3. **Invocation field is deliberate, not defaulted — on Claude Code.** All three below are Claude Code frontmatter fields. Copilot's reference documents none of them, so on a Copilot target there is nothing to pick: the `description` is the only trigger the skill has, and it must carry the whole of it. When the target is Claude Code, pick one:
   - Default (no field) — Claude auto-loads by description match; user can also `/invoke`.
   - `user-invocable: false` — background/enforcement knowledge, no meaningful `/name` command. The five enforcer skills in this family use it on their Claude Code target.
   - `disable-model-invocation: true` — side-effecting actions (`/deploy`, `/commit`) the user must trigger deliberately; description is excluded from context.
4. **Archetype matches shape.** See taxonomy below — a skill built as the wrong archetype fights its own frontmatter.
5. **Progressive disclosure enforced** — see the dedicated section below; it's stricter than "point to references/".
6. **References are one level deep.** `references/foo.md` must not itself point to `references/foo/bar.md`. Flatten instead.
7. **Body stays under the spec cap** — see below.
8. **`paths:` glob is as narrow as the file shape actually is** — Claude Code only. Copilot documents no `paths:` key and no open-a-file trigger of any kind, so on a Copilot target this item does not apply and the trigger must be spelled out in the `description` instead. Where the key is live, `**/*.md` is almost always wrong — say what kind of markdown file.
9. **`allowed-tools` (if set) lists only what the skill's body actually invokes**, scoped (`Bash(git *)`), never a bare `Bash`.

## The spec floor (Agent Skills specification)

`SKILL.md` is a portable format: every host that claims Agent Skills support reads the same frontmatter contract before any host adds its own. These are hard, checkable numbers, not house style — cited so a reader can verify them rather than take this file's word for it. Full detail: the `agent-plugins-docs` skill's `references/agent-skills-spec.md`.

- **`name`**: 1–64 characters. Lowercase alphanumerics and hyphens only. No leading or trailing hyphen. **No consecutive hyphens.** **Must match the parent directory name.** The last two are the ones that get missed — neither is visible from a one-line field description.
- **`description`**: 1–1024 characters, non-empty. States **what** the skill does **and when** to use it — see Description quality below.
- **Body**: under 500 lines and under ~5000 tokens (the spec's own recommendation, not a hard cutoff like the frontmatter fields above).
- **Optional spec fields**: `license` (name or reference to a bundled file); `compatibility` (≤500 chars, environment requirements — most skills don't need it); `metadata` (a string-to-string map for client-defined properties); `allowed-tools` (space-separated, **experimental** — a skill depending on it is not portable).
- **File references**: relative to the skill root, **one level deep**. A reference that points at another reference is a chain the agent will not follow reliably.

### Host additions above the floor

Everything above is the whole contract on a host that implements nothing else. Each host layers its own fields on top:

- **Claude Code** adds a substantial set of non-floor fields — see the `anthropic-docs` skill's `references/skills.md` § Frontmatter reference for the full roster; do not treat any field absent from the spec floor above as portable. Two worth naming because a specific rule below depends on them: frontmatter `hooks`, whose `once: true` is honored only in skill frontmatter, not agent frontmatter or settings files (the `anthropic-docs` skill's `references/hooks.md`); and boolean fields such as `disable-model-invocation`, which since v2.1.218 also accept `yes`/`no`/`on`/`off`/`1`/`0` in any letter case, in addition to `true`/`false` (the `anthropic-docs` skill's `references/plugins-reference.md` § Skills).
- **Copilot's own reference documents no `SKILL.md` frontmatter fields beyond the spec floor** — `copilot-docs` covers where skill directories live (five locations, project and personal) and load precedence, never a frontmatter schema. Treat this as an absence of a documented extension, not confirmation that Copilot rejects extra fields.

**The payoff:** a skill written using only the floor fields runs on every host that claims Agent Skills support, VS Code included, with no port required. Reaching for a host addition is a deliberate portability trade, not a default.

## Description quality

The `description` is the entire triggering mechanism — an under-specified one means the skill never fires, because at startup an agent sees only `name` and `description`, never the body. Full rules: the `agent-plugins-docs` skill's `references/skill-authoring-guidance.md` § Description rules.

- **Imperative phrasing** — "Use when…", not "This skill does…". The agent is deciding whether to act.
- **User intent over implementation** — match what the user asked for, not the skill's internals.
- **Err toward pushy** — name the contexts where the skill applies even when the user doesn't name the domain, e.g. "even if they don't explicitly mention 'CSV' or 'analysis.'"

A concrete before/after, from the upstream guidance:

- Poor: `Helps with PDFs.`
- Good: `Extracts text and tables from PDF files, fills PDF forms, and merges multiple PDFs. Use when working with PDF documents or when the user mentions PDFs, forms, or document extraction.`

## Progressive disclosure, with teeth

Three tiers, each with its own cost — spend the cheap one generously, the expensive ones sparingly:

1. **Metadata** (`name` + `description`, ~100 tokens) — loaded at startup for every installed skill, always.
2. **Body** — loaded once the skill activates. Keep it lean; see the spec floor above.
3. **Resources** (`scripts/`, `references/`, `assets/`) — loaded only on demand.

Tier 3 only works if two rules hold:

1. **A reference is only loadable on demand if `SKILL.md` says when to load it.** "See `references/` for details" defeats the mechanism — the agent has nothing to match the trigger against. "Read `references/api-errors.md` if the API returns a non-200" preserves it.
2. **Gotchas belong in `SKILL.md`, not a reference.** A reference works only if the agent recognizes the trigger to load it — and for a non-obvious problem, the agent may not recognize that trigger at all. Put the correction where it's guaranteed to be read.

## Self-audit (run before finishing)

```bash
# description length in characters, not bytes (must be < 1024)
awk -F': ' '/^description:/{print substr($0, length($1)+3); exit}' SKILL.md | wc -m
# body length in lines (must be < 500)
awk 'c==2{print} /^---$/{c++}' SKILL.md | wc -l
# name matches directory
diff <(awk -F': ' '/^name:/{print $2; exit}' SKILL.md) <(basename "$(dirname SKILL.md)")
```

## House archetype taxonomy

Every skill in this plugin family is one of four shapes. Naming a skill's archetype up front resolves most frontmatter arguments. **The Invocation column below is written in Claude Code frontmatter**, the only host that documents these fields; on a Copilot target the archetype still describes the skill's shape, but the whole column collapses into what the `description` has to say.

| Archetype | Shape | Invocation | Example in this repo |
| --- | --- | --- | --- |
| **Context** | `SKILL.md` index + `references/` deep dives, no execution | `user-invocable: false` typically; description carries the index's own trigger | `anthropic-docs` |
| **Workflow** | User-invoked with `arguments:`/`argument-hint:`, orchestrates a multi-step procedure | `disable-model-invocation: true` for side-effecting workflows | out of scope this phase |
| **Pattern** | Ships scripts/helpers under `scripts/` that do a concrete thing | default or `user-invocable: false` depending on whether Claude should decide to run it | planned (nudge design, bash templates) |
| **Path-based** | `paths:` glob — **on Claude Code** it auto-loads as an enforcer the moment a matching file is opened; on Copilot there is no such trigger, and the description must name the file shapes outright. No execution of its own | `user-invocable: false` on Claude Code; no equivalent field elsewhere | this skill, and its four siblings |

On Claude Code, a context skill that also declares `paths:` is doing double duty — fine, but be sure the description alone is strong enough for description-triggered loads too, since the two mechanisms compose rather than replace each other. That care is not optional on a host without `paths:`: there the description is the only mechanism.

## Common mistakes

- Description recapping the body — becomes the shortcut Claude takes instead of reading further.
- `paths:` set on a skill that should be description-triggered (task-kind-specific, not file-shape-specific) — on Claude Code it'll never fire when no matching file is open, and on a host that reads no `paths:` key it never fires at all.
- Inlining a reference's field table into SKILL.md "for convenience" — duplicated content drifts out of sync with the reference; point instead.
- A reference nobody is told when to load — "see references/ for details" instead of naming the trigger condition.
- A gotcha filed under `references/` instead of `SKILL.md` — the agent has no reason to go looking for it.
- Missing `argument-hint` on a user-invokable workflow skill that takes arguments.
- `user-invocable: false` skill that still declares `argument-hint` — dead field, users can't invoke it. (Claude Code only; neither field is documented elsewhere.)
- Assuming a Claude Code-only field (`hooks`, `paths`, `disable-model-invocation`) ports to Copilot — its behavior there is undocumented; do not rely on it either way.

## Read for the full contract

- the `agent-plugins-docs` skill's `references/agent-skills-spec.md` — the portable frontmatter contract: every field, the full `name` constraint list, progressive disclosure, file references.
- the `agent-plugins-docs` skill's `references/skill-authoring-guidance.md` — description rules and testing, context budgeting, gotchas sections, script design for agentic use.
- the `anthropic-docs` skill's `references/skills.md` — every Claude Code frontmatter field, invocation matrix, substitution variables, lifecycle.
- the `anthropic-docs` skill's `references/skill-best-practices.md` — conciseness, degrees of freedom, naming, description rules, progressive-disclosure patterns, eval-first iteration, the pre-share checklist.

Reviewing whether the body's language will actually land — imperative force, urgency tiers, XML structure? Invoke the `persuasion` skill.
