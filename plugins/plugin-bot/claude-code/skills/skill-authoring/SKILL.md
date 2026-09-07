---
name: skill-authoring
description: Enforces SKILL.md frontmatter and body conventions when a skill file (or command markdown file) is opened for authoring or review — description quality, user-invocable vs model-invocable choice, archetype fit, progressive disclosure, and the 500-line body cap.
user-invocable: false
paths:
  - "**/skills/**/SKILL.md"
  - "**/.claude/skills/**/SKILL.md"
  - "**/commands/*.md"
---

# Skill authoring checklist

Apply this to the file you just opened, top to bottom. The two mistakes that break triggering most often: a description that summarizes the workflow instead of stating trigger conditions, and a `paths:` glob broad enough to auto-load on unrelated files.

## Checklist

1. **Description is trigger-only, third person, "Use when...".** If it narrates steps ("reads the diff, then writes a message, then runs tests"), Claude follows the description as a shortcut and skips the body. Rewrite to state only when the skill applies.
2. **`description` alone stays under the 1,024-char platform hard cap; combined `description` + `when_to_use` stays under the 1,536-char listing cap.** Lead with the strongest trigger phrase first — it's what gets matched.
3. **Invocation field is deliberate, not defaulted.** Pick one:
   - Default (no field) — Claude auto-loads by description match; user can also `/invoke`.
   - `user-invocable: false` — background/enforcement knowledge, no meaningful `/name` command. Use this for all five path-based skills in this family.
   - `disable-model-invocation: true` — side-effecting actions (`/deploy`, `/commit`) the user must trigger deliberately; description is excluded from context.
4. **Archetype matches shape.** See taxonomy below — a skill built as the wrong archetype fights its own frontmatter.
5. **Progressive disclosure enforced.** Every `references/*.md` pointer in the body is preceded by an explicit "Load when:" guard. No reference is inlined wholesale into SKILL.md.
6. **References are one level deep.** `references/foo.md` must not itself point to `references/foo/bar.md`. Flatten instead.
7. **Body stays under 500 lines.** Over that, split into references and leave SKILL.md as the index.
8. **`paths:` glob is as narrow as the file shape actually is.** `**/*.md` is almost always wrong — say what kind of markdown file.
9. **`allowed-tools` (if set) lists only what the skill's body actually invokes**, scoped (`Bash(git *)`), never a bare `Bash`.

## House archetype taxonomy

Every skill in this plugin family is one of four shapes. Naming a skill's archetype up front resolves most frontmatter arguments:

| Archetype | Shape | Invocation | Example in this repo |
| --- | --- | --- | --- |
| **Context** | `SKILL.md` index + `references/` deep dives, no execution | `user-invocable: false` typically; description carries the index's own trigger | `anthropic-docs` |
| **Workflow** | User-invoked with `arguments:`/`argument-hint:`, orchestrates a multi-step procedure | `disable-model-invocation: true` for side-effecting workflows | out of scope this phase |
| **Pattern** | Ships scripts/helpers under `scripts/` that do a concrete thing | default or `user-invocable: false` depending on whether Claude should decide to run it | planned (nudge design, bash templates) |
| **Path-based** | `paths:` glob, auto-loads as an enforcer the moment a matching file is opened, no execution of its own | always `user-invocable: false` | this skill, and its four siblings |

A context skill that also declares `paths:` is doing double duty — fine, but be sure the description alone is strong enough for description-triggered loads too, since the two mechanisms compose rather than replace each other.

## Common mistakes

- Description recapping the body — becomes the shortcut Claude takes instead of reading further.
- `paths:` set on a skill that should be description-triggered (task-kind-specific, not file-shape-specific) — it'll never fire when no matching file is open.
- Inlining a reference's field table into SKILL.md "for convenience" — duplicated content drifts out of sync with the reference; point instead.
- Missing `argument-hint` on a user-invokable workflow skill that takes arguments.
- `user-invocable: false` skill that still declares `argument-hint` — dead field, users can't invoke it.

## Read for the full contract

- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/skills.md` — every frontmatter field, invocation matrix, substitution variables, lifecycle.
- `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/skill-best-practices.md` — conciseness, degrees of freedom, naming, description rules, progressive-disclosure patterns, eval-first iteration, the pre-share checklist.

Reviewing whether the body's language will actually land — imperative force, urgency tiers, XML structure? Invoke the `persuasion` skill.
