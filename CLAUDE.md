# bot

This repository develops and distributes agent plugins for Claude Code and GitHub Copilot, and publishes them through its own marketplace manifests. plugin-bot, a plugin for developing agent plugins, is the first plugin that originates here. Project knowledge lives in the `okf/` bundle; this file only routes into it.

- Bundle map → `okf/index.md` — Load when: looking for where a topic is documented.
- Purpose, boundaries and non-goals → `okf/project.md` — Load when: starting work or deciding whether something is in scope.
- Layout rule → `okf/invariants/canonical-layout.md` — Load when: adding or moving a directory under `plugins/`.
- Marketplace manifests → `okf/interfaces/marketplace-manifests.md` — Load when: editing `.claude-plugin/marketplace.json` or `.github/plugin/marketplace.json`.
- Release flow → `okf/runbooks/release-a-plugin.md` — Load when: releasing a plugin or touching changesets and repin workflows.
- Plugin work → `plugins/CLAUDE.md` — Load when: working under `plugins/`.
