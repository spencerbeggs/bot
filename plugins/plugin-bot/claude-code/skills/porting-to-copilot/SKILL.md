---
name: porting-to-copilot
description: Use when porting a Claude Code plugin component to a copilot/ target workspace, when a source file has changed and its port must be brought current, or when deciding whether a component should be ported at all. Covers the re-authoring procedure, the divergence table, what has no Copilot equivalent, and the port-status ledger that pins whether a port is current.
---

# Porting to Copilot

## This is re-authoring, not transformation

Bodies legitimately differ per host. The procedure for one file is: **read the
source change, decide what it means in the target's dialect, write it, re-record
the hash.** A mechanical copy is a defect — it passes the ledger check while
carrying Claude-only instructions into a tree where they mean nothing.

## One-directional

`claude-code/` leads; `copilot/` trails. A change that originates in the port is
a defect: it means the two will diverge in **content**, not merely in format,
which is the failure this ordering exists to prevent. If you find yourself
improving prose while porting it, stop, make the improvement in `claude-code/`,
then port it.

## The procedure

1. `bash "${CLAUDE_SKILL_DIR}/scripts/port-status.sh" --source <src> --port <port> --ledger <ledger> --check`
2. For each problem in the JSON report, decide **port** or **claudeOnly** (below).
3. Apply the divergence table before writing: `references/divergence-table.md`
   answers *is this difference real work or a compatible fallback?* Load it the
   first time you touch a surface in a given port pass — every surface has at
   least one row, and three rows exist only to stop you making an edit.
4. Re-author the affected files in the port.
5. Re-run with `--record` to pin the new hashes. Use `--record --dry-run` first
   if you want to see which entries would change before writing.
6. Run the bats suite.

**A green `--check` means "every ported skill and agent is current", not "the
port is complete."** The ledger covers `skills/**/*.md` and `agents/**/*.md`,
and nothing else. It does not see `plugin.json`, `hooks.json` or `.mcp.json`,
and that scope is deliberate, not a gap to widen: a Claude `plugin.json` and a
Copilot `plugin.json` are different schemas with different fields, so a content
hash between them would be permanent false drift, and the only way to silence
it would be to stop checking. What covers the **manifest** instead is
`plugins/__test__/canonical-layout.bats`, which pins its existence and location
per host — `.claude-plugin/plugin.json` for Claude Code, root `plugin.json` for
Copilot. `hooks.json` and `.mcp.json` are covered by neither the ledger nor that
suite today, so after changing one in the source, port it and verify it by hand;
`--check` stays green either way.

## Deciding `claudeOnly`

A component is `claudeOnly` when its **subject matter** is a Claude-only
feature, not when its **host** is Claude. This is the distinction people get
wrong. A skill teaching how to author a Claude Code monitor is useful to a
Copilot user who is building a Claude Code plugin — so it **ports**, in full,
monitors and all. What would not port is a skill whose value depends on the
reader's session being a Claude Code session.

Mark `claudeOnly` sparingly and always with a `reason` a later reader can
evaluate; `--check` fails an entry that omits one. plugin-bot itself is expected
to use the escape hatch **zero** times.

## What does not port

Every Consequence cell is an edit to make, not a fact to note.

### Agent frontmatter

Restated here because the `agent-authoring` enforcer only fires once an agent
file is open, and these decisions are made before that. It is the authority if
the two ever disagree — `agent-authoring` § What does not port.

| Claude Code | Copilot | Consequence |
| :-- | :-- | :-- |
| `skills:` preload list | No documented equivalent | A capability loss, not a formatting difference: Claude injects the full skill **content** at every startup; a Copilot agent can only be told to go read a file. Because it is paid at every startup, `skills:` should carry only always-needed material — if the source list is long, trim it in the source first. **Action**: list each skill by name and path in prose in the agent body, near the top, before the boundaries section, with an explicit instruction to read it. |
| `model`, `effort`, `maxTurns` | No documented equivalent | **Action**: drop the fields; the host chooses. |
| `disallowedTools` | No documented equivalent | **Action**: re-express as an explicit prohibition in the agent body, grouped with the ported `skills:` prose above the boundaries section, so a reader meets "must read" and "must not do" together. |
| `memory`, `background`, `isolation` | No documented equivalent | **Action**: drop the fields; nothing to re-express. |
| `tools` identifiers | `["bash","edit","view"]` per the `plugins-creating` how-to, **or** `["read","edit","search"]` per a shipped port | **Unresolved, and it stays unresolved** — neither is schema-backed, because Copilot's CLI reference documents no `.agent.md` frontmatter at all. **Action**: emit **no `tools` key**, and leave a marker comment naming both candidates: `<!-- tools: unresolved — "bash","edit","view" per plugins-creating vs "read","edit","search" per a shipped port; neither is schema-backed -->`. An absent key with a visible marker is recoverable; a guessed key is invisible and permanent. |

### Hooks

| Claude Code | Copilot | Consequence |
| :-- | :-- | :-- |
| Claude-only hook events | 14 events, camelCase | **Action**: remap per `hook-scripts` § Registration deltas and drop the events with no counterpart. Renames are not mechanical — check each one there. |
| `mcp_tool` and `agent` handler types | `command`, `http`, `prompt` only | **Action**: re-express each as a `command` handler that performs the same work from a script; there is nothing else to port them to. |
| `if` permission filters | No documented equivalent | **Action**: move the condition into the handler script — it reads the same event payload and exits early with the permissive decision when the filter would not have matched. Deleting the `if` without moving it widens the hook silently. |
| `async`, `asyncRewake` | No documented equivalent | **Action**: make the handler synchronous and fast enough for the timeout. If it cannot be, it does not port: omit the hook from the port's `hooks.json` and record the omission in the port's README, since the ledger does not track `hooks.json`. |

### Manifest and components

| Claude Code | Copilot | Consequence |
| :-- | :-- | :-- |
| `userConfig` | No documented equivalent | **Action**: drop the block and replace every `${user_config.*}` reference with a plain `${ENV_VAR}` the handler reads, documented in the port's README. A left-behind `${user_config.*}` token has nothing to expand it. |
| `channels`, `dependencies`, `workflows`, output styles, monitors, themes | No documented equivalent | **Action**: omit the manifest keys and do not create the directories. Where one carried behavior a user depends on, re-express it as a **skill** under `skills/` — the one component both hosts read the same way. Where that is not possible, it is a real capability loss: record it in the port's README rather than leaving the reader to infer it from an absence. |
| `${CLAUDE_PLUGIN_ROOT}` inside SKILL.md **body prose** | Claude Code documents it: `plugins-reference.md` § Environment variables gives `Skill and agent content` as substituting **anywhere the placeholder appears**. Copilot documents no such thing — its CLI reference substitution table has exactly three rows and this is not one | So every such cross-reference, live in the source, may render **literally** in a ported skill. **Action**: for a file inside the same skill, write a plain relative path (`references/divergence-table.md`). For a file in a sibling skill, name the skill and the file in prose — "the `anthropic-docs` skill's `references/plugins-reference.md`" — because a `../` chain violates the one-level-deep file-reference rule in `skill-authoring`. Expect several per skill: `plugin-manifest/SKILL.md` alone carries seven, all in its closing reference list. |

## Available scripts

`scripts/port-status.sh` — decides whether the port is current, over
`skills/**/*.md` and `agents/**/*.md`.

```text
bash port-status.sh --source DIR --port DIR --ledger FILE (--check | --record) [--dry-run]
```

- `--check` prints `{"problems":[…],"ok":bool}` on stdout. Problem kinds:
  `unclassified`, `missing-port`, `orphan`, `stale`, `no-reason`,
  `contradiction`.
- `--record` rewrites the ledger from the source's current contents, preserving
  `claudeOnly` entries and dropping entries whose source file is gone. Prints a
  JSON summary with `added`/`updated`/`removed`. `--dry-run` computes it and
  writes nothing.
- Exit codes: `0` clean or recorded, `1` drift, `2` usage or environment error.
- Run `--help` for the full interface. It needs `jq` and one of
  `sha256sum`/`shasum`.

Ledger schema — a JSON object with an `entries` map keyed by **source-relative
path**, each value one of:

```json
{
  "entries": {
    "skills/plugin-manifest/SKILL.md": { "sourceHash": "sha256:…" },
    "skills/some-skill/SKILL.md": { "claudeOnly": true, "reason": "…" }
  }
}
```

Hashes, not git SHAs: squash-merges rewrite SHAs and collapse commit timestamps.
`agents/<name>.md` is expected at `agents/<name>.agent.md` in the port;
everything else maps one-to-one.

## Common mistakes

- Copying a source body verbatim into the port and re-recording the hash — the
  ledger goes green while the port carries instructions that mean nothing there.
- Editing the port first, then back-porting. The ledger cannot detect it; the
  ordering is the only defence.
- Marking a skill `claudeOnly` because its subject is a Claude Code feature.
- Porting an agent's `skills:` list as a frontmatter field — there is nothing to
  preload into.
- Guessing a Copilot `tools` identifier set instead of emitting no key.
- Rewriting `${CLAUDE_PLUGIN_DATA}` or moving `.claude-plugin/plugin.json` in a
  Copilot tree — both are `No` rows in the divergence table.
- Changing `plugin.json`, `hooks.json` or `.mcp.json` in the source and trusting
  a green `--check`; the ledger does not see them, and `canonical-layout.bats`
  covers only the manifest.

## Read for the full contract

- `references/divergence-table.md` — the twelve surfaces with the **Real
  divergence?** column, the placeholder vocabulary, and why hook script bodies
  need no placeholder rewrite. Load it on the first surface you touch in a port
  pass.
- `${CLAUDE_PLUGIN_ROOT}/skills/agent-authoring/SKILL.md` — the authority for
  the agent frontmatter table above, plus the Copilot `.agent.md` dialect.
- `${CLAUDE_PLUGIN_ROOT}/skills/hook-scripts/SKILL.md` — the registration
  deltas, the event remap, and the portable plugin-root chain.
- `${CLAUDE_PLUGIN_ROOT}/skills/plugin-manifest/SKILL.md` — the manifest and
  marketplace deltas behind the last two divergence rows.
- `${CLAUDE_PLUGIN_ROOT}/skills/agent-plugins-docs/references/cross-client-behavior.md`
  — the placeholder matrix and each token's expansion sites.
