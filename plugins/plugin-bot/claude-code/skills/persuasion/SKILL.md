---
name: persuasion
description: Use when writing or reviewing language meant to shape an agent's behavior — a hook's `additionalContext` payload, a SKILL.md body or description, an agent system prompt, or an enforcer checklist. Covers choosing the imperative force, structuring with XML tags, matching the urgency tier to the moment (the EXTREMELY_IMPORTANT / IMPORTANT / reminder / acceptable-anti-pattern gradient), the persuasion-principles foundation (Cialdini + Meincke), why XML beats markdown for hook injections, and concrete templates for SessionStart, PostToolUse, and PreToolUse nudges.
---

# Persuasion

Agent-directed prose is an instrument: its phrasing, structure and urgency calibration determine whether the agent actually complies. This skill covers that craft for every surface that carries it — hook `additionalContext` injections (its most detailed case, with templates), skill bodies and descriptions, agent system prompts and enforcer checklists. The hook injection *mechanism* is platform contract (`${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/hooks.md`); this skill is about the **content** — how to phrase it, how to structure it, and how to calibrate its force.

Three reasons nudges are unusually powerful:

1. **They arrive at the moment of relevance.** SessionStart fires before Claude reads anything; PostToolUse fires the instant after an action; PreToolUse fires before an action commits. A nudge in any of these slots reaches Claude when the behavior it's shaping is still mutable.
2. **They render as system reminders, not user messages.** Claude treats system-injected content as authoritative — closer to the system prompt than to user turns.
3. **They compose with skills.** A SessionStart hook can inject an entire skill body as `additionalContext`, turning the skill into a *guaranteed-loaded* context the agent cannot route around. This is how `superpowers:using-superpowers` achieves near-total compliance.

Use this skill when authoring the `additionalContext` payload of any hook, and equally when reviewing whether a SKILL.md body, agent prompt or checklist will actually land — the same force-calibration rules apply. For hook mechanics, pair with `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/hooks.md` (envelope, exit codes, JSON shape) and `hook-events.md` (per-event response shape).

## The four-tier urgency gradient

Every nudge has a level of imperative force. Match the level to the consequence of the agent ignoring it. **Don't run every nudge at maximum force** — agents desensitize, and high-force nudges lose their authority when overused.

| Tier | When to use | Language signature | XML tag |
| --- | --- | --- | --- |
| **TIER 1 — Non-negotiable** | Safety, correctness, or workflow gates where ignoring the instruction breaks the system. TDD discipline, anti-data-loss guards, gated tool sequences. | "YOU MUST", "Not optional", "Not negotiable", "Cannot rationalize", "No exceptions", "Even if you think..." | `<EXTREMELY_IMPORTANT>` / `<extremely-important>` |
| **TIER 2 — Strong recommendation** | Established best practices where the agent should default to the recommendation but a sufficiently good reason justifies deviation. Code conventions, test-first patterns, idiomatic tool choices. | "You SHOULD", "Best practice", "Recommended", "Strong default", "Unless [specific exception]" | `<important>` / `<recommended>` |
| **TIER 3 — Gentle reminder** | Soft anti-patterns and corrections. The agent did or is about to do something suboptimal; you want to nudge without blocking. | "You MAY continue, but...", "Consider...", "Next time...", "Heads up", "FYI" | `<reminder>` / `<note>` |
| **TIER 4 — Acceptable anti-pattern explainer** | The agent just did X that's suboptimal. You want to acknowledge it's tolerable, explain the better path, and document the exception case. | "You did X. Use Y instead, EXCEPT when..." (descriptive, not prescriptive). | `<acceptable_anti_pattern>` / `<observation>` |

## TIER 1 — Non-negotiable

The signature pattern: an `<EXTREMELY_IMPORTANT>` block wrapping a directive the agent absolutely must follow. Combine three persuasion principles:

- **Authority** — imperative language. Capital MUST, ABSOLUTELY, NEVER.
- **Commitment** — eliminate the rationalization escape route. "You cannot rationalize your way out of this."
- **Scarcity** — bind to a moment ("BEFORE any response").

Concrete template (the canonical strong form from `superpowers:using-superpowers`):

```text
<EXTREMELY_IMPORTANT>
You have <capability>.

If you think there is even a 1% chance that <rule> applies to what you are doing, you ABSOLUTELY MUST <action>.

IF <rule> APPLIES, YOU DO NOT HAVE A CHOICE. YOU MUST <action>.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY_IMPORTANT>
```

Reserve this tier for things where ignoring the rule produces user-visible failure. Examples that legitimately warrant TIER 1:

- **TDD discipline:** "If you write production code without a failing test first, delete it and start over."
- **Destructive-action gates:** "Before any `git push --force`, you MUST confirm with the user explicitly."
- **Required tool sequences:** "Before invoking the deploy tool, you MUST run the verification suite and report its output."

Don't use TIER 1 for style preferences, tone guidance, or "would be nice if" rules. Overuse kills the authority signal.

## TIER 2 — Strong recommendation

The signature pattern: an `<important>` block with should/recommended language and a clearly-named exception case. Authority is dialed down; commitment is preserved; the escape route is **labeled**, not closed.

```text
<important>
You SHOULD use the `mcp__myplugin__run_tests` tool to execute tests in this project — it captures
attribution, persists artifacts, and feeds the dogfood loop.

Use the bare `vitest` command only when:
  • Debugging the MCP tool itself
  • Running outside an active Claude Code session
  • Explicitly testing a fixture in isolation
</important>
```

The labeled exception ("Use the bare command only when...") is load-bearing. Without it, an agent under pressure may rationalize that *this* case is special and follow the lesser path silently. With it, the agent has a checklist of legitimate exceptions and either matches one or follows the default.

Use TIER 2 for:

- Tool-choice preferences with rare legitimate alternatives
- Conventional patterns the codebase enforces but tolerates exceptions to
- Workflows the agent should default to but isn't blocked from skipping

## TIER 3 — Gentle reminder

The signature pattern: a `<reminder>` block flagging something for awareness, often after the agent already took an action. Force is minimal — the goal is to update Claude's model of "what good looks like here" without scolding.

```text
<reminder>
You ran `pnpm vitest run` directly in the last turn. The plugin's preferred path is the
`mcp__myplugin__run_tests` MCP tool, which captures session attribution and records artifacts.

You MAY continue with the bare command if it's working for your current goal — no action required.
The next time you want to run tests, prefer the MCP tool.
</reminder>
```

The "MAY continue, no action required" phrasing matters. A TIER-3 nudge that reads as "you must immediately switch" is actually a TIER-2 nudge with weak phrasing — pick the right tier.

Use TIER 3 for:

- One-time post-hoc corrections where redoing the action isn't worth it
- "FYI" context that improves future turns without demanding current changes
- Onboarding-style guidance — "in this codebase, X is how we typically do Y"

## TIER 4 — Acceptable anti-pattern explainer

The signature pattern: an `<acceptable_anti_pattern>` block that names what the agent did, names the better path, and documents the exception space. Tone is descriptive — observing, not commanding.

```text
<acceptable_anti_pattern>
You used `cat playground/src/lifecycle.ts | head -20` to read the file.

The Read tool is the preferred way to look at a known file path:
  • It returns content with line numbers (easier to reference back)
  • It tracks the file as "read" for state continuity
  • It handles binary files and large files better than cat

`cat | head` (or `head` directly) remains appropriate when:
  • You need only the first few lines and Read's default limit is overkill
  • The file is generated/streamed and may not exist as a stable path
  • You're piping the output into another shell command in the same line

No action needed — the next time you want to peek at a known file, prefer Read.
</acceptable_anti_pattern>
```

TIER 4 is essentially a *teaching* nudge — it builds the agent's mental model of the codebase's conventions without forcing a current correction. Used well, TIER 4 nudges accumulate across a session into a richer model of "how things work here."

Use TIER 4 for:

- Cases where the agent's choice is acceptable in this instance but suboptimal at scale
- Convention onboarding — first time the agent encounters a pattern that has codebase-specific guidance
- Acknowledging legitimate trade-offs ("this approach is fine, here's when the other is fine")

## Why XML beats plain markdown

Anthropic's official guidance: *"XML tags help Claude parse complex prompts unambiguously, especially when your prompt mixes instructions, context, examples, and variable inputs."* Source: <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices.md>

For hook `additionalContext`, this matters even more than for normal prompts because:

1. **Hooks fire during in-progress conversation.** The injection lands alongside user messages, tool results, and the agent's own thinking. XML tags create unambiguous boundaries — Claude can attribute each chunk to its source.
2. **Tag names carry semantic weight.** `<EXTREMELY_IMPORTANT>` doesn't just delimit content; it labels it with an imperative-force signal Claude weights against other context.
3. **Nesting communicates structure.** A `<reminder>` containing `<observation>` and `<suggestion>` sub-tags reads as a structured note, not freeform prose.

Tag naming conventions for nudge hooks:

- **All-caps for strongest force:** `<EXTREMELY_IMPORTANT>`, `<CRITICAL>`, `<MUST_FOLLOW>`. Reserve for TIER 1.
- **Lowercase for normal force:** `<important>`, `<reminder>`, `<note>`, `<observation>`. Use for TIER 2–4.
- **Underscores over hyphens for compound tags:** `<acceptable_anti_pattern>` not `<acceptable-anti-pattern>`. The official Anthropic examples and the superpowers patterns both use underscores; consistency wins over style.
- **Descriptive over abstract:** `<verification_required>` beats `<note1>`. The tag itself documents the intent.

Inside the tag, prose can still use markdown (lists, bold for inline emphasis), but the **structural** scaffolding is XML.

## Composing tiers across hooks in a session

A complete plugin typically fires nudges at several hook events. Plan the tier mix so the overall pressure curve makes sense:

| Hook event | Typical tier | Example |
| --- | --- | --- |
| SessionStart | TIER 1 — sets non-negotiable disciplines for the whole session | "You have superpowers. If a skill might apply, invoke it." |
| PreToolUse (sensitive tool) | TIER 1 or 2 — gates the call | "Before deploy, you MUST run verification." |
| PreToolUse (informational) | TIER 3 — heads-up before action | "FYI: this Bash command will modify the database." |
| PostToolUse (anti-pattern) | TIER 3 or 4 — after-the-fact correction | "You used `cat` — prefer Read next time." |
| PostToolUse (success) | No nudge — silence is fine | (don't congratulate; just emit a no-op) |
| SubagentStop | TIER 2 — wrap-up reminder | "Before reporting done, you should run the BATS suite." |

**Don't fire TIER 1 nudges on every event.** A session that opens with `<EXTREMELY_IMPORTANT>` for skill invocation, then `<EXTREMELY_IMPORTANT>` on every PreToolUse, then `<EXTREMELY_IMPORTANT>` on every PostToolUse, desensitizes the agent. Reserve TIER 1 for the moments that actually warrant it.

## SessionStart-specific patterns

SessionStart is the highest-leverage nudge slot. It's the first thing Claude sees in the session and the cheapest moment to set rules.

**Pattern: inject a whole skill body.** Wrap the skill content in `<EXTREMELY_IMPORTANT>` so it functions as a guaranteed-loaded discipline rather than a discoverable one:

```bash
# hooks/session-start/inject-discipline.sh
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<EXTREMELY_IMPORTANT>\nYou have <plugin> capabilities. The full content of the <plugin>:<skill-name> skill is below — read it now and follow its rules for the rest of the session.\n\n---\n<full skill body here>\n---\n\nIf any rule below applies to your task, you MUST follow it. This is not negotiable.\n</EXTREMELY_IMPORTANT>"
  }
}
EOF
```

**Pattern: inject a slim ruleset, defer detail to discoverable skills.** When the SessionStart payload would otherwise be huge:

```text
<EXTREMELY_IMPORTANT>
This project enforces these disciplines:
1. TDD — invoke the `tdd` skill before writing any test
2. Hypothesis-first — record a hypothesis before any non-test edit during red phase
3. Use MCP tools, not Bash, to invoke vitest

The full procedure for each lives in its skill. Invoke skills via the Skill tool when relevant.
</EXTREMELY_IMPORTANT>
```

This is cheaper context-wise — Claude loads only the skills it needs — but relies on Claude actually invoking the skill. Use this form when the discipline is robust enough to survive a discoverable load.

## PostToolUse-specific patterns

PostToolUse nudges are the strongest *teaching* slot — they fire immediately after Claude sees the result of an action, when the connection between action and consequence is still fresh.

**Pattern: anti-pattern callout (TIER 3 or 4).** After detecting the agent did something suboptimal:

```text
<reminder>
You ran the test suite via `pnpm vitest run` in the last turn. This plugin provides
`mcp__myplugin__run_tests` which records the run as a TDD artifact (visible in
`tdd_artifact_list`) and links it to the active phase for the red→green gate.

You MAY continue with the bare command for this turn. For the next test invocation, prefer the MCP tool.
</reminder>
```

**Pattern: silent on success.** If the tool call did the right thing, emit `{}` (no-op) and exit 0. Don't congratulate — that's noise.

**Pattern: TIER 2 for repeated anti-patterns.** If the same anti-pattern fires twice in a session, the second nudge can escalate from `<reminder>` to `<important>` with stronger language. Track via a state file in `${HOME}/.claude/session-env/${session_id}/` so the escalation persists across hook subprocesses.

## PreToolUse-specific patterns

PreToolUse nudges arrive before the call commits — the highest-leverage moment to gate or reshape an action.

**Pattern: gate with TIER 1 + actually deny.** If the gate is hard, return `permissionDecision: "deny"` AND inject the explanation via `permissionDecisionReason`:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Before any `git push --force`, you MUST confirm with the user. Ask: 'Do you want to force-push? Yes/no.' Wait for the user's reply. Then retry with `git push --force-with-lease` or `git push` if they said no."
  }
}
```

The denial reason is what Claude sees — write it as a TIER-1 directive.

**Pattern: TIER 2 reshape via `updatedInput`.** When the agent's call is mostly right but should be steered:

```text
<important>
You're about to run `vitest run --update` which regenerates snapshots. In this plugin,
snapshot updates require the `--accept-snapshots` confirmation flag. I've rewritten your
command to include it; review below before approving.
</important>
```

Combined with `updatedInput` that adds the flag, this teaches the agent the convention while reshaping the call.

## Persuasion principles — what works, what doesn't

From Meincke et al. (2025) testing seven Cialdini principles with N=28,000 LLM conversations. Compliance rates jumped from 33% to 72% with these techniques. The principles map to nudge design:

| Principle | Use in nudges | Avoid |
| --- | --- | --- |
| **Authority** — imperative language, non-negotiable framing | TIER 1 nudges. "You MUST", "Not negotiable", "No exceptions" | Authority-stacking — five TIER 1 nudges in one session dilutes each |
| **Commitment** — eliminate rationalization escape routes | All tiers. "Even if you think this is the exception, the rule still applies because..." | Leaving the escape route ambiguous — agents under pressure will widen it |
| **Scarcity** — bind to a moment | "BEFORE any response", "IMMEDIATELY after writing the test" | Manufactured urgency — false time-boundedness lowers signal |
| **Social proof** — name the universal pattern | "Every codebase that does X also does Y" — for established conventions | Social proof for unproven patterns reads as bluffing |
| **Unity** — collaborative framing | TIER 3 + TIER 4. "We" / "our codebase" / "we both want this to work" | TIER 1 with unity language ("we MUST") — undermines authority |
| **Reciprocity** | Almost never. Skill content is given, not exchanged. | Always avoid in nudges |
| **Liking** | Never for compliance. | Always avoid — creates sycophancy |

The combination that works for discipline-enforcing nudges: **Authority + Commitment + Scarcity**. Plus closed-loophole framing ("Even if X, the rule still applies"). Plus a single concrete action ("MUST invoke the X skill before Y").

## Anti-patterns in nudge design

- **Vague nudges.** "Be careful with deletes." → Better: "Before any `rm -rf`, you MUST confirm the path with the user."
- **Scolding nudges.** "You did this wrong." → Better: TIER 3 observation + the right path forward + the exception case.
- **Same-message nudge on every event.** Agents detect repetition and discount. Rotate language, escalate force on repeat anti-patterns.
- **Conflicting nudges across hooks.** SessionStart says "always use Tool A"; PostToolUse says "next time use Tool B". Coordinate.
- **TIER 1 for style preferences.** "You MUST use 4-space indents." That's a Tier 3 reminder at most.
- **Markdown-only formatting in `additionalContext`.** XML beats markdown for hook injections — the tag scaffolding is the imperative-force signal.
- **No exception case in TIER 2.** "You SHOULD do X." (no exception clause) → reads as TIER 1 with weak language. Either label the exceptions or commit to TIER 1 framing.
- **Nudges that demand action without telling the agent how.** "Be more careful" — useless. "Run `pnpm test` before claiming done" — actionable.

## Audit checklist for a nudge hook

When reviewing a hook script that emits `additionalContext`:

1. **Tier matches consequence.** Is the imperative force calibrated to what happens if the agent ignores it? TIER 1 should be reserved for moments where ignoring breaks the system.
2. **XML structure used.** Is the content wrapped in a tag whose name signals the tier (`<EXTREMELY_IMPORTANT>` vs `<reminder>`)?
3. **Imperative language for TIER 1.** MUST / NOT NEGOTIABLE / NO EXCEPTIONS / CANNOT RATIONALIZE present?
4. **Exception case named for TIER 2.** "Use bare command only when..." explicit?
5. **Actionable for the agent.** Does the nudge tell the agent *what to do*, not just *what's wrong*?
6. **Rationalization loopholes closed.** "Even if you think X, the rule still applies because Y."
7. **Tier mix across the plugin's hooks.** Not every event TIER 1; not every event TIER 3. Coordinated escalation.
8. **No conflicting directives** between SessionStart, PreToolUse, PostToolUse.
9. **No congratulatory PostToolUse on success.** Emit `{}` and exit 0.
10. **Persuasion principles applied appropriately.** Authority + Commitment + Scarcity for discipline; Unity + Social Proof for collaborative; Liking + Reciprocity never.

## Cross-references

- Hook I/O contract (envelope, response, exit codes): `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/hooks.md`.
- Per-event `hookSpecificOutput` shape for SessionStart / PostToolUse / PreToolUse: `${CLAUDE_PLUGIN_ROOT}/skills/anthropic-docs/references/hook-events.md`.
- Skill content authoring (the same imperative-language rules apply to SKILL.md bodies): the `skill-authoring` enforcer, plus `superpowers:writing-skills` and its `persuasion-principles.md` reference where that plugin is installed.
- Anthropic's XML guidance: <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices.md> (search "Structure prompts with XML tags").
