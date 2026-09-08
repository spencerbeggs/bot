---
"@plugin-bot/claude-code-plugin": minor
"@plugin-bot/copilot-plugin": minor
---

## Features

- Canonicalize the plugin layout as `plugins/<plugin>/(claude-code|copilot)/`, one pnpm workspace per target, each with a private tracking package whose only job is to give changesets something to version. `versionFiles` bumps the tracking `package.json` and the plugin manifest in lockstep, so a release produces a git tag and a GitHub release without publishing to npm.
- Make the target directory name a context signal in its own right: a file under `copilot/` is governed by Copilot's contract before anything reads it.
- Teach `plugin-bot` to author and review both hosts. Three layered documentation skills — the portable Agent Skills/Agent Plugins floor, Copilot, and Claude Code — carry the rule that binds them: write to the narrowest layer that carries the capability, because reaching up costs portability. Six path-triggered enforcers, the `plugin-engineer` agent, and the authoring skills now cover both targets.
- Add a `porting-to-copilot` skill and a content-hash ledger tracking the Claude-to-Copilot port, which survives the squashes and rebases that defeat timestamps and git SHAs.

## Other

- Bodies diverge per host by design, so the ledger checks currency rather than identity. Byte-identity is asserted only for the bundled scripts and templates, which are copied rather than re-authored.
