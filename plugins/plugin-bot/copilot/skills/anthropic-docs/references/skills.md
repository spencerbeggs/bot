# Skills (Claude Code)

> Verified against <https://code.claude.com/docs/en/skills.md> — 2026-07-10

Custom commands (`.claude/commands/*.md`) and skills (`.claude/skills/<name>/SKILL.md`) both produce `/name`. Skills add: a directory for supporting files, invocation-control frontmatter, and automatic loading when relevant. If a skill and a command share a name, the skill wins.

## Contents

- Where skills live
- Live change detection
- Nested `.claude/skills/` and directory-qualified names
- Skills from additional directories
- Skill directory layout
- Types of skill content
- Frontmatter reference
- How a skill gets its command name
- Available string substitutions
- Control who invokes a skill (invocation matrix)
- Skill content lifecycle
- Pre-approve tools (`allowed-tools` / `disallowed-tools`)
- Pass arguments / skill stacking
- Inject dynamic context
- Run skills in a subagent (`context: fork`)
- Restrict Claude's skill access (Skill permission rules)
- Override skill visibility (`skillOverrides`)
- Skill listing budget
- Bundled skills
- Troubleshooting

## Where skills live

| Location | Path | Applies to |
| --- | --- | --- |
| Enterprise | See managed settings | All users in your organization |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<skill-name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin is enabled |

**Precedence when names collide:** enterprise overrides personal, personal overrides project. A skill at any of these levels overrides a bundled skill of the same name (e.g. a project `code-review` skill replaces the bundled `/code-review`). Plugin skills use a `plugin-name:skill-name` namespace, so they never conflict with other levels.

A `<skill-name>` entry at enterprise/personal/project can be a symlink to a directory elsewhere on disk; Claude Code follows it and reads `SKILL.md` from the target, loading the skill once even if the same target is reachable from more than one location. Plugin skills handle symlinks differently (see plugins-reference: share files with symlinks).

Adding `.claude-plugin/plugin.json` to a skill folder turns it into a plugin named `<name>@skills-dir`, letting it bundle agents, hooks, and MCP servers. In a project's `.claude/skills/`, this requires accepting the workspace trust dialog first.

### Nested `.claude/skills/` and directory-qualified names

Skills also load from nested `.claude/skills/` directories below the working directory. Editing a file in `packages/frontend/` makes skills in `packages/frontend/.claude/skills/` available, even if the session started at the repo root. Project skills also load from `.claude/skills/` in every parent directory up to the repo root.

If a nested skill shares a name with another skill, **both stay available**:

- The nested one appears under a directory-qualified name: `apps/web:deploy`.
- Its description states which directory it applies to.
- Claude picks the variant matching the files it's working on.
- Typing `/deploy` runs the project-root skill; `/apps/web:deploy` runs the nested variant explicitly.
- Invoking the unqualified name loads the project-root skill, and Claude Code appends a list of directory-qualified variants with an instruction to also invoke any variant whose directory holds the files Claude is working on. Requires Claude Code v2.1.203 or later.

### Live change detection

Claude Code watches skill directories for file changes.

| Change | Effect |
| --- | --- |
| Add/edit/remove a skill under `~/.claude/skills/`, project `.claude/skills/`, or a `.claude/skills/` inside an `--add-dir` dir | Takes effect within the current session, no restart |
| Create a **new top-level skills directory** that didn't exist when the session started | Requires restarting Claude Code |
| Changes to `hooks/`, `.mcp.json`, `agents/`, `output-styles/` inside a skill folder that is also a plugin | Requires `/reload-plugins`; live detection only covers `SKILL.md` text |

### Skills from additional directories

`--add-dir` / `/add-dir` normally grant file access only, but `.claude/skills/` within an added directory is an exception: it loads automatically. The `permissions.additionalDirectories` setting in `settings.json` grants file access only and does **not** load skills. Other `.claude/` config (commands, output styles) is not loaded from additional directories. CLAUDE.md files from `--add-dir` are not loaded by default — set `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` to load them.

## Skill directory layout

```text
my-skill/
├── SKILL.md           # Main instructions (required)
├── template.md         # Template for Claude to fill in
├── examples/
│   └── sample.md       # Example output showing expected format
└── scripts/
    └── validate.sh      # Script Claude can execute
```

Only `SKILL.md` is required. Reference other files from `SKILL.md` so Claude knows what they contain and when to load them.

## Types of skill content

- **Reference content**: knowledge Claude applies inline (conventions, patterns, style guides). Runs alongside conversation context.
- **Task content**: step-by-step instructions for a specific action (deploy, commit, codegen). Usually paired with `disable-model-invocation: true` so Claude doesn't trigger it automatically.

Skill body content stays in context for the rest of the session once loaded — every line is a recurring token cost. State what to do, not how/why.

## Frontmatter reference

All fields optional; only `description` is recommended.

| Field | Description |
| --- | --- |
| `name` | Display name in skill listings. Defaults to directory name. Does not change what you type after `/`, except for a plugin-root `SKILL.md`. |
| `description` | What the skill does and when to use it. Used for auto-invocation matching. Defaults to first markdown paragraph if omitted. Put the key use case first — combined with `when_to_use`, truncated at 1,536 characters in the skill listing. |
| `when_to_use` | Additional trigger phrases/examples. Appended to `description` in the listing; counts toward the same 1,536-char cap. |
| `argument-hint` | Autocomplete hint for expected arguments, e.g. `[issue-number]` or `[filename] [format]`. |
| `arguments` | Named positional arguments for `$name` substitution. Space-separated string or YAML list; names map to positions in order. |
| `disable-model-invocation` | `true` prevents Claude from auto-loading the skill (manual `/name` only). Also prevents preloading into subagents. `{min-version: 2.1.196}` also prevents the skill running when a scheduled task fires with it as the prompt. Default: `false`. |
| `user-invocable` | `false` hides from `/` menu. Use for background knowledge. Default: `true`. |
| `allowed-tools` | Tools Claude can use without asking permission while skill is active. Space-, comma-separated string, or YAML list. |
| `disallowed-tools` | Tools removed from the available pool while skill is active. Same accepted formats. Restriction clears on your next message. |
| `model` | Model override for the rest of the current turn only (not saved to settings). Accepts `/model` values or `inherit`. A model excluded by org `availableModels` allowlist is ignored, session keeps current model. |
| `effort` | Effort override while skill active: `low`, `medium`, `high`, `xhigh`, `max` (availability depends on model). Default: inherits from session. |
| `context` | `fork` runs the skill in a forked subagent context. |
| `agent` | Subagent type to use when `context: fork` is set. |
| `hooks` | Hooks scoped to this skill's lifecycle (see hooks reference: hooks-in-skills-and-agents). |
| `paths` | Glob patterns limiting auto-activation to matching files. Comma-separated string or YAML list. Same format as memory path-specific rules. |
| `shell` | Shell for `` !`command` `` / ` ```! ` blocks. `bash` (default) or `powershell`. `powershell` requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`. |

### How a skill gets its command name

`name` sets the *display label*, not the typed command — except the plugin-root case.

| Skill location | Command name source | Example |
| --- | --- | --- |
| `~/.claude/skills/` or `.claude/skills/` | Directory name | `.claude/skills/deploy-staging/SKILL.md` → `/deploy-staging` |
| Nested `.claude/skills/`, name clashes with another skill | Subdirectory path + skill directory name | `apps/web/.claude/skills/deploy/SKILL.md` → `/apps/web:deploy` |
| `.claude/commands/` | File name without extension | `.claude/commands/deploy.md` → `/deploy` |
| Plugin `skills/` subdirectory | Directory name, namespaced by plugin | `my-plugin/skills/review/SKILL.md` → `/my-plugin:review` |
| Plugin root `SKILL.md` | Frontmatter `name`, falls back to plugin directory name | `my-plugin/SKILL.md` with `name: review` → `/my-plugin:review` |

The plugin-root case is the only place `name` sets the command name, because there's no skill directory to derive it from.

## Available string substitutions

| Variable | Description |
| --- | --- |
| `$ARGUMENTS` | All arguments passed at invocation. If absent from content, arguments are appended as `ARGUMENTS: <value>`. |
| `$ARGUMENTS[N]` | Specific argument by 0-based index, e.g. `$ARGUMENTS[0]`. |
| `$N` | Shorthand for `$ARGUMENTS[N]`, e.g. `$0`, `$1`. |
| `$name` | Named argument from the `arguments` frontmatter list; names map to positions in order (`arguments: [issue, branch]` → `$issue`=1st, `$branch`=2nd). |
| `${CLAUDE_SESSION_ID}` | Current session ID. |
| `${CLAUDE_EFFORT}` | Current effort level: `low`, `medium`, `high`, `xhigh`, `max`. Ultracode is not a distinct level, reports as `xhigh`. |
| `${CLAUDE_SKILL_DIR}` | Directory containing this skill's `SKILL.md`. For plugin skills, the skill's subdirectory, not plugin root. Use for referencing bundled scripts regardless of cwd. |
| `${CLAUDE_PROJECT_DIR}` | Project root directory — same value hooks/MCP servers receive as `CLAUDE_PROJECT_DIR`. Requires Claude Code v2.1.196+. Applies to both skill body **and** `allowed-tools` (e.g. `Bash(${CLAUDE_PROJECT_DIR}/scripts/lint.sh *)` resolves to the same path). |

**Argument quoting:** indexed arguments use shell-style quoting — `/my-skill "hello world" second` → `$0` = `hello world`, `$1` = `second`. `$ARGUMENTS` always expands to the full string as typed.

**Escaping:** a literal `$` before a digit, `ARGUMENTS`, or a declared argument name (e.g. `$1.00` in prose) is escaped with a backslash: `\$1.00`. A backslash before any other `$` is left unchanged. Only a single backslash directly before the token escapes it; a doubled backslash (`\\$1`) leaves both backslashes and `$1` still expands.

## Control who invokes a skill (invocation matrix)

| Frontmatter | You can invoke | Claude can invoke | When loaded into context |
| --- | --- | --- | --- |
| (default) | Yes | Yes | Description always in context; full skill loads when invoked |
| `disable-model-invocation: true` | Yes | No | Description not in context; full skill loads only when you invoke |
| `user-invocable: false` | No | Yes | Description always in context; full skill loads when invoked |

Use `disable-model-invocation: true` for workflows with side effects or timing you control (`/commit`, `/deploy`). Use `user-invocable: false` for background knowledge that isn't a meaningful user action.

In a regular session only descriptions preload; full content loads on invocation. Subagents with preloaded skills (`skills` field) work differently — full skill content is injected at startup.

## Skill content lifecycle

- Rendered `SKILL.md` content enters the conversation as a single message and stays for the rest of the session. Claude Code does **not** re-read the file on later turns — write standing instructions, not one-time steps.
- **Re-invocation dedupe:** if the rendered content is identical to what's already in context, Claude Code adds a short "already loaded" note instead of duplicating it. If content differs (args changed, or dynamic-context command produced new output), the full content is appended again. Before v2.1.202, every re-invocation appended a full duplicate copy.
- **Compaction budgets:** auto-compaction re-attaches the most recent invocation of each skill after the summary, keeping the first **5,000 tokens** of each. Re-attached skills share a combined budget of **25,000 tokens**, filled starting from the most-recently invoked skill — older skills can be dropped entirely if many were invoked in one session.
- If a skill stops influencing behavior, its content is usually still present but the model is choosing other approaches — strengthen `description`/instructions, use hooks for deterministic enforcement, or re-invoke the skill after compaction to restore full content.

## Pre-approve tools (`allowed-tools` / `disallowed-tools`)

`allowed-tools` **grants, does not restrict**: it pre-approves the listed tools (no prompt) while the skill is active. Every other tool remains callable; your permission settings still govern tools not listed.

**Trust gate:** for skills in a project's `.claude/skills/`, `allowed-tools` takes effect only after you accept the workspace trust dialog for that folder, same as permission rules in `.claude/settings.json`. Review project skills before trusting a repo — a skill can grant itself broad tool access.

`disallowed-tools` removes tools from Claude's available pool while the skill is active; the restriction clears on your next message. To block tools across all skills/prompts, use deny rules in permission settings.

## Pass arguments / skill stacking

Arguments are available via `$ARGUMENTS` (see substitutions table). If a skill is invoked with arguments but doesn't include `$ARGUMENTS`, Claude Code appends `ARGUMENTS: <your input>`.

**Stacking:** you can stack several skills at the start of one message. As of v2.1.199, `/code-review /fix-issue 123` loads both skills and passes the trailing text `123` as `$ARGUMENTS` to each. Before v2.1.199, only the first skill loaded and received `/fix-issue 123` as literal argument text.

- Claude Code expands the first skill plus up to five more stacked after it (max 6).
- Expansion stops at the first token that isn't an inline user-invocable skill — a skill running as a forked subagent, or one whose arguments may themselves start with a slash command (e.g. `/loop`), ends the run there. That token and everything after it become the argument text for every expanded skill.

## Inject dynamic context

`` !`<command>` `` runs shell commands before the skill content is sent to Claude; the output replaces the placeholder. This is preprocessing — Claude never executes it, it only sees the rendered result.

- Substitution runs **once** over the original file. Output is inserted as plain text and is **not re-scanned** — a command's output cannot emit a placeholder for a later pass to expand.
- Inline form is recognized only when `!` is at the start of a line or immediately after whitespace. If `!` follows another character (e.g. `` KEY=!`cmd` ``), it's left as literal text and the command does not run.
- For multi-line commands, use a fenced block opened with ` ```! ` instead of the inline form.
- `"disableSkillShellExecution": true` in settings disables this for skills/custom commands from user, project, plugin, or additional-directory sources. Each command is replaced with `[shell command execution disabled by policy]`. Bundled and managed skills are **not** affected. Most useful in managed settings, where users can't override it.
- Include `ultrathink` anywhere in skill content to request deeper reasoning for that invocation.

## Run skills in a subagent (`context: fork`)

`context: fork` runs the skill in an isolated subagent; the skill content becomes the subagent's prompt. It has no access to conversation history. Only makes sense for skills with explicit instructions — a guideline-only skill (no task) gives the subagent guidance but no actionable prompt, and returns without meaningful output.

| Approach | System prompt | Task | Also loads |
| --- | --- | --- | --- |
| Skill with `context: fork` | From agent type | `SKILL.md` content | CLAUDE.md, except when agent is `Explore` or `Plan` |
| Subagent with `skills` field | Subagent's markdown body | Claude's delegation message | Preloaded skills + CLAUDE.md |

Built-in `Explore` and `Plan` agents **skip CLAUDE.md and git status** to keep context small — a forked skill using `agent: Explore` sees only the `SKILL.md` content plus the agent's own system prompt.

`agent` field: which subagent config to run — built-ins (`Explore`, `Plan`, `general-purpose`) or any custom subagent from `.claude/agents/`. If omitted, uses `general-purpose`.

## Restrict Claude's skill access (Skill permission rules)

Skills exposing `allowed-tools` grant Claude access to those tools without per-use approval while active; other permission settings still govern baseline approval for everything else. A few built-in commands are also reachable through the Skill tool — `/init`, `/review`, `/security-review`. Others (e.g. `/compact`) are not.

Three controls:

1. **Disable all skills**: deny the `Skill` tool in `/permissions`.
2. **Allow/deny specific skills** via permission rules:
   - `Skill(name)` — exact match.
   - `Skill(name *)` — prefix match with any arguments.
3. **Hide individual skills**: `disable-model-invocation: true` in frontmatter removes the skill from Claude's context entirely.

`user-invocable` only controls `/` menu visibility, **not** Skill tool access — use `disable-model-invocation: true` to block programmatic invocation.

## Override skill visibility (`skillOverrides`)

`skillOverrides` (a settings key) controls skill visibility without editing the skill's own frontmatter — useful for shared/checked-in or MCP-provided skills. The `/skills` menu writes it: highlight a skill, `Space` to cycle states, `Enter` to save to `.claude/settings.local.json`.

| Value | Listed to Claude | In `/` menu |
| --- | --- | --- |
| `"on"` | Name and description | Yes |
| `"name-only"` | Name only | Yes |
| `"user-invocable-only"` | Hidden | Yes |
| `"off"` | Hidden | Hidden |

- As of v2.1.199, `"off"` also hides the skill from Remote Control and Agent SDK slash-command lists, not just the terminal `/` menu. Invoking a hidden skill by full name still returns the `skillOverrides` error instead of running it.
- A skill absent from `skillOverrides` is treated as `"on"`.
- Plugin skills are **not** affected by `skillOverrides` — manage those through `/plugin`.

```json
{
  "skillOverrides": {
    "legacy-context": "name-only",
    "deploy": "off"
  }
}
```

## Skill listing budget

Claude Code loads a listing of every skill's name + description into context.

- Combined `description` + `when_to_use` text is capped at **1,536 characters** per skill in the listing (configurable via `skillListingMaxDescChars`). Put the key use case first.
- Listing budget scales at **1% of the model's context window** by default. Raise it with `skillListingBudgetFraction` (e.g. `0.02` = 2%) or the `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var for a fixed character count.
- When the listing overflows, Claude Code drops descriptions starting with the **least-invoked** skills first, so frequently used skills keep full text. The listing always contains every skill *name*.
- Set low-priority skills to `"name-only"` in `skillOverrides` to free budget for others.
- `/doctor` estimates the listing's context cost and biggest contributors; overflow also logs a warning visible with `--debug`.
- The Skills row in `/context` reports the listing size **after** the budget is applied. Before v2.1.196, that row counted the full text of every description and could show a value several times the configured budget.

## Bundled skills

Bundled skills (`/doctor`, `/code-review`, `/batch`, `/debug`, `/loop`, `/claude-api`, etc.) are available every session unless disabled via `disableBundledSkills`. Unlike most built-in commands (fixed logic), bundled skills are **prompt-based**: Claude orchestrates with its tools per detailed instructions.

- In v2.1.205+, `/doctor` is the one exception to `disableBundledSkills` — it stays typable. Hide it via `DISABLE_DOCTOR_COMMAND` env var or `skillOverrides: {"doctor": "off"}`. Before v2.1.205, `/doctor` was a built-in command, not a bundled skill.

Run/verify-app skill trio (requires Claude Code v2.1.145+):

| Skill | Purpose |
| --- | --- |
| `/run` | Launch and drive your app to see a change working |
| `/verify` | Build and run your app to confirm a code change does what it should, without falling back to tests/type checks |
| `/run-skill-generator` | Teach `/run` and `/verify` how to build and launch your project; records a recipe as a per-project skill at `.claude/skills/run-<name>/` |

## Troubleshooting

- **Not triggering**: check description keywords match natural phrasing; verify it appears in "What skills are available?"; invoke directly with `/skill-name`. Malformed frontmatter YAML loads the skill body with empty metadata — `/skill-name` still works but there's no `description` to match against (see with `--debug`).
- **Triggers too often**: make description more specific, or add `disable-model-invocation: true`.
- **Descriptions cut short**: see listing budget above.
