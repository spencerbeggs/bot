# Decision

* [Authoring flows one way, claude-code first](one-directional-authoring.md) - claude-code/ leads and copilot/ trails; a change that originates in the port is a defect, so drift has a direction the ledger can measure.
* [Each distributed target versions independently](per-target-versioning.md) - Each distributed target has a private tracking package whose versionFiles entry bumps its own manifest, so targets are tagged and released without npm publishing.
* [Every component lives in a target workspace](target-workspace-layout.md) - Components live under plugins/\<plugin\>/\<target\>/ with target exactly claude-code or copilot, so the governing host contract is legible from the path.
* [Fetch first, with stamped per-layer references as the middle ground](fetch-first-stamped-references.md) - Plugin-component claims are settled by fetching the official docs, backed by stamped distillations kept one skill per layer, never by copied snapshots or a merged reference pile.
* [One plugin-engineer agent, bash as a specialization](single-plugin-engineer-agent.md) - A single plugin-engineer agent with bash discipline as a named specialization, because all agents would share the same context skills.
* [The plugin is named plugin-bot](plugin-bot-name.md) - The plugin is named plugin-bot to avoid colliding with Anthropic's official plugin-dev plugin.
