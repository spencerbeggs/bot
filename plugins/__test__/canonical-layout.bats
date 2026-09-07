#!/usr/bin/env bats
#
# Host-agnostic pins on the canonical multi-target plugin layout.
# A target workspace is a directory named `claude-code` or `copilot`, at depth
# 1 or 2 under plugins/. Everything else here follows from that definition.

setup() {
	PLUGINS_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	REPO_ROOT="$(dirname "${PLUGINS_DIR}")"
}

# Emits one absolute path per line, sorted. Consumed by every test below.
target_workspaces() {
	find "${PLUGINS_DIR}" -mindepth 1 -maxdepth 2 -type d \
		\( -name claude-code -o -name copilot \) | sort
}

@test "at least one target workspace exists" {
	run target_workspaces
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "every directory under plugins/ is a plugin dir or the shared test dir" {
	for entry in "${PLUGINS_DIR}"/*/; do
		[ -d "$entry" ] || continue
		name="$(basename "${entry%/}")"
		[ "$name" = "__test__" ] && continue
		# A plugin dir must itself contain at least one target workspace.
		if ! find "${entry%/}" -mindepth 1 -maxdepth 1 -type d \
			\( -name claude-code -o -name copilot \) | grep -q .; then
			echo "plugins/${name} contains no target workspace"
			return 1
		fi
	done
}

@test "no plugin component directory sits outside a target workspace" {
	for entry in "${PLUGINS_DIR}"/*/; do
		[ -d "$entry" ] || continue
		name="$(basename "${entry%/}")"
		[ "$name" = "__test__" ] && continue
		for child in "${entry%/}"/*/; do
			[ -d "$child" ] || continue
			cname="$(basename "${child%/}")"
			case "$cname" in
				claude-code | copilot | __test__) ;;
				*)
					echo "plugins/${name}/${cname} is neither a target workspace nor __test__"
					return 1
					;;
			esac
		done
	done
}

@test "every target workspace carries its host's manifest in the right place" {
	while IFS= read -r ws; do
		case "$(basename "$ws")" in
			claude-code)
				[ -f "${ws}/.claude-plugin/plugin.json" ] || {
					echo "missing .claude-plugin/plugin.json in ${ws}"
					return 1
				}
				;;
			copilot)
				[ -f "${ws}/plugin.json" ] || {
					echo "missing plugin.json in ${ws}"
					return 1
				}
				;;
		esac
	done < <(target_workspaces)
}
