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

repin_plugin() {
	local name="$1"
	local url sha version tmp
	url="$(jq -r --arg name "$name" '.plugins[] | select(.name == $name) | .source.url' "$MANIFEST")"
	sha="$(git ls-remote "$url" HEAD | awk '{print $1}')"
	if [ -z "$sha" ]; then
		echo "could not resolve HEAD of $url" >&2
		return 1
	fi
	tmp="$(mktemp)"
	jq --tab --arg name "$name" --arg sha "$sha" \
		'(.plugins[] | select(.name == $name) | .source).sha = $sha' \
		"$MANIFEST" > "$tmp"
	mv "$tmp" "$MANIFEST"
	echo "pinned $name to $sha"
}

repin_plugin vitest-agent
repin_plugin design-docs
