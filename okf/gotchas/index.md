# Gotcha

* [Skill hot-reload is documented for @skills-dir plugins, not --plugin-dir](skill-hot-reload-scope.md) - The upstream docs say a SKILL.md edit takes effect immediately, but that note is scoped to @skills-dir plugins, so it is unverified for the pnpm claude loop.
* [The marketplace install never serves the working tree](marketplace-never-serves-working-tree.md) - plugin-bot is installable from this repo's own marketplace, but that entry resolves from GitHub at a pinned sha, so local edits are never live through it.
