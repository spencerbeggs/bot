# Plugin development (plugins/)

Context for developing agent plugins in this repo — Claude Code and GitHub Copilot. Applies to all work under `plugins/`.

## Layout, and why the directory name is the point

```text
plugins/<target>/            # single-plugin repo
plugins/<plugin>/<target>/   # multi-plugin repo — this one
```

`<target>` is exactly `claude-code` or `copilot`. **That name is the context signal**: an agent seeing `plugins/*/copilot/**` knows which contract governs the file before reading it. The whole design rests on it, so never put a component directory outside a target workspace — `plugins/__test__/canonical-layout.bats` fails if you do.

Here that means `plugins/plugin-bot/{claude-code,copilot}` and `plugins/dogfood/claude-code`. The manifest location differs per host: `.claude-plugin/plugin.json` for `claude-code`, root `plugin.json` for `copilot`. Each target workspace carries a private `package.json` named `@<plugin>/<target>-plugin` so changesets version the two manifests independently.

## The three layers

| Layer | Skill | Adds |
| :-- | :-- | :-- |
| Portable floor — Agent Skills spec | `agent-plugins-docs` | `SKILL.md` and its frontmatter, progressive disclosure, `references/`, `scripts/`, `assets/` |
| GitHub Copilot | `copilot-docs` | manifest fields beyond the portable schema, `.agent.md` agents, 14 hook events, 3 handler types |
| Claude Code | `anthropic-docs` | 33 hook events, 5 handler types, `paths:` auto-load, `userConfig`, `channels`, monitors, output styles |

**Write to the narrowest layer that carries the capability, and reach up only deliberately, knowing the reach costs portability.**

## Fetch-first, three ways

Both hosts ship features faster than training data goes stale. Before authoring or auditing a component, read the reference in the skill for your layer, then escalate to the URL stamped at the top of that reference (`Verified against <url> — <date>`) when it is silent, the claim is version-sensitive, or the stamp looks old. Never answer from memory.

| Layer | Escalation index |
| :-- | :-- |
| Portable | <https://agentskills.io/specification.md> |
| Copilot | <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference> |
| Claude Code | <https://code.claude.com/docs/llms.txt> |

**A portable claim settled by a Claude-only page is not settled.** `anthropic-docs` describes Claude Code and `copilot-docs` describes Copilot; only `agent-plugins-docs` answers "does this survive the other host?"

## One-directional authoring

`claude-code/` leads, `copilot/` trails. A change originating in the port is a defect — read `porting-to-copilot` before editing anything under `copilot/`.

```bash
bash plugins/plugin-bot/claude-code/skills/porting-to-copilot/scripts/port-status.sh \
  --source plugins/plugin-bot/claude-code \
  --port plugins/plugin-bot/copilot \
  --ledger plugins/plugin-bot/copilot/port-status.json \
  --check
```

Swap `--check` for `--record` once the port is re-authored, to pin the new hashes.

**A green `--check` does not mean the port is complete.** The ledger tracks `skills/**/*.md` and `agents/**/*.md` and nothing else, so `plugin.json`, `hooks.json` and `.mcp.json` can drift while it stays green. Green means "every ported skill and agent is current".

## Tests

- `plugins/__test__/` — host-agnostic claims, such as the layout itself.
- `plugins/<plugin>/<target>/__test__/` — host-specific claims.

`pnpm test:bats` runs `bats --recursive plugins`, collecting every level with no registration step.

## Local development loop

- `pnpm claude` loads both plugins from source (`--plugin-dir ./plugins/plugin-bot/claude-code --plugin-dir ./plugins/dogfood/claude-code`), shadowing any same-named marketplace install for that session. This is the only loop that serves local edits: the `.claude-plugin/marketplace.json` entry is a `git-subdir` source that always resolves from GitHub, so it never reflects the working tree.
- After editing hooks, `.mcp.json` or agents, have the user run `/reload-plugins`. `SKILL.md` text is documented to take effect immediately, but that statement is scoped to `@skills-dir` plugins rather than `--plugin-dir` loads — so reload anyway if a skill edit does not seem to land.
- `claude plugin validate <target-workspace> --strict` before calling Claude Code plugin work done. Copilot documents no validate subcommand; `copilot plugin install ./<workspace>` caches components, so reinstall after each edit.
- A CLAUDE.md at a plugin's own root is NOT loaded as plugin context — plugins ship context via skills. That is why this guidance lives at the `plugins/` level.

## Knowledge bundle

- Claude Code target → `../okf/modules/plugin-bot-claude-code.md` — Load when: changing plugin-bot's skills, agent or structure.
- Copilot target → `../okf/modules/plugin-bot-copilot.md` — Load when: editing anything under `copilot/` or reasoning about the port.
- Layer and fetch-first rule → `../okf/conventions/narrowest-layer-fetch-first.md` — Load when: authoring or auditing a plugin component, or deciding which official doc to fetch.
- One-directional authoring → `../okf/decisions/one-directional-authoring.md` — Load when: a change seems to belong in `copilot/` first.
- Port ledger limits → `../okf/limitations/port-ledger-coverage.md` — Load when: interpreting a `port-status.sh --check` result.
- Local dev loop → `../okf/runbooks/local-plugin-dev-loop.md` — Load when: loading, reloading or validating plugins locally.
- Refresh the port → `../okf/runbooks/refresh-copilot-port.md` — Load when: Claude Code skills or agents changed and the Copilot port is stale.
