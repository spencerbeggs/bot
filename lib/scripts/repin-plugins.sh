#!/usr/bin/env bash
# Re-pin the git-subdir plugin sources in .claude-plugin/marketplace.json.
# The sha field is the effective pin Claude Code checks out when installing
# or updating the plugin, so this script is how a plugin release reaches the
# marketplace.
#
# Pins land on release commits, never branch HEADs. When the repin-plugins
# workflow is triggered by a plugin-release dispatch it passes the released
# repository and its release commit sha through, and the matching plugin is
# pinned to that exact sha (in a monorepo every package tagged in the release
# shares one commit). Every other plugin — and all plugins on cron/manual
# runs — is resolved from its repo's latest GitHub release tag via `gh api`,
# so a repo with no releases yet keeps its current pin.
#
# Usage: bash lib/scripts/repin-plugins.sh [repository] [sha]
#   repository  owner/repo from the release event (optional)
#   sha         release commit sha from the release event (optional)
# Requires GH_TOKEN for the latest-release lookup.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/.claude-plugin/marketplace.json"
EVENT_REPO="${1:-}"
EVENT_SHA="${2:-}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

repin_plugin() {
	local name="$1"
	local url path repo ref tag sha version tmp
	url="$(jq -r --arg name "$name" '.plugins[] | select(.name == $name) | .source.url' "$MANIFEST")"
	path="$(jq -r --arg name "$name" '.plugins[] | select(.name == $name) | .source.path' "$MANIFEST")"
	repo="${url#https://github.com/}"

	if [ "$repo" = "$EVENT_REPO" ] && [ -n "$EVENT_SHA" ]; then
		ref="$EVENT_SHA"
	elif tag="$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>/dev/null)" && [ -n "$tag" ]; then
		ref="refs/tags/$tag"
	else
		echo "skipping $name: $repo has no releases yet, keeping current pin" >&2
		return 0
	fi

	git init --quiet "$TMP/$name"
	git -C "$TMP/$name" fetch --quiet --depth 1 "$url" "$ref"
	sha="$(git -C "$TMP/$name" rev-parse 'FETCH_HEAD^{commit}')"
	git -C "$TMP/$name" checkout --quiet "$sha"
	if [ ! -f "$TMP/$name/$path/.claude-plugin/plugin.json" ]; then
		echo "refusing to pin $name: $path/.claude-plugin/plugin.json missing at $sha" >&2
		return 1
	fi
	version="$(jq -r .version "$TMP/$name/$path/.claude-plugin/plugin.json")"
	tmp="$(mktemp)"
	jq --tab --arg name "$name" --arg sha "$sha" \
		'(.plugins[] | select(.name == $name) | .source).sha = $sha' \
		"$MANIFEST" > "$tmp"
	mv "$tmp" "$MANIFEST"
	echo "pinned $name@$version to $sha ($ref)"
}

repin_plugin vitest-agent
repin_plugin design-docs
repin_plugin effected
