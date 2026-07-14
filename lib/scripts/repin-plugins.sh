#!/usr/bin/env bash
# Re-pin the git-subdir plugin sources in .claude-plugin/marketplace.json to
# the current HEAD of each source repo. The sha field is the effective pin
# Claude Code checks out when installing or updating the plugin, so this
# script is how a plugin release reaches the marketplace. Run it after
# releasing a plugin, or let the repin-plugins workflow run it and open a PR.
#
# Usage: bash lib/scripts/repin-plugins.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$ROOT/.claude-plugin/marketplace.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

repin_plugin() {
	local name="$1"
	local url path sha version tmp
	url="$(jq -r --arg name "$name" '.plugins[] | select(.name == $name) | .source.url' "$MANIFEST")"
	path="$(jq -r --arg name "$name" '.plugins[] | select(.name == $name) | .source.path' "$MANIFEST")"
	git clone --quiet --depth 1 "$url" "$TMP/$name"
	sha="$(git -C "$TMP/$name" rev-parse HEAD)"
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
	echo "pinned $name@$version to $sha"
}

repin_plugin vitest-agent
repin_plugin design-docs
