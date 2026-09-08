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
	found=0
	while IFS= read -r ws; do
		found=$((found + 1))
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
	# Same guard as every other iterating test here: without it this passes
	# vacuously the moment target_workspaces stops finding anything.
	[ "$found" -gt 0 ] || {
		echo "no target workspaces found"
		return 1
	}
}

@test "tracking packages are named @<plugin>/<target>-plugin, private, unpublishable" {
	found=0
	while IFS= read -r ws; do
		pkg="${ws}/package.json"
		# A workspace with no package.json is undistributed by design (dogfood).
		[ -f "$pkg" ] || continue
		found=$((found + 1))
		plugin="$(basename "$(dirname "$ws")")"
		target="$(basename "$ws")"
		expected="@${plugin}/${target}-plugin"
		actual="$(jq -r '.name' "$pkg")"
		[ "$actual" = "$expected" ] || {
			echo "${pkg}: name is '${actual}', expected '${expected}'"
			return 1
		}
		[ "$(jq -r '.private' "$pkg")" = "true" ] || {
			echo "${pkg}: must be private"
			return 1
		}
		[ "$(jq -r 'has("publishConfig")' "$pkg")" = "false" ] || {
			echo "${pkg}: must not carry publishConfig"
			return 1
		}
	done < <(target_workspaces)
	# Without this guard the test passes vacuously when no tracking package
	# exists yet, which is exactly the state it is written to reject.
	[ "$found" -gt 0 ] || {
		echo "no tracking packages found"
		return 1
	}
}

@test "every tracking package has a versionFiles entry whose glob resolves" {
	cfg="${REPO_ROOT}/.changeset/config.json"
	found=0
	while IFS= read -r ws; do
		pkg="${ws}/package.json"
		[ -f "$pkg" ] || continue
		found=$((found + 1))
		name="$(jq -r '.name' "$pkg")"
		globs="$(jq -r --arg n "$name" \
			'.changelog[1].packages[$n].versionFiles[]?.glob // empty' "$cfg")"
		[ -n "$globs" ] || {
			echo "no versionFiles entry for ${name} in .changeset/config.json"
			return 1
		}
		while IFS= read -r g; do
			[ -f "${REPO_ROOT}/${g}" ] || {
				echo "versionFiles glob does not resolve: ${g}"
				return 1
			}
		done <<< "$globs"
	done < <(target_workspaces)
	[ "$found" -gt 0 ] || {
		echo "no tracking packages found"
		return 1
	}
}

@test "marketplace entries pointing into this repo resolve to a target workspace" {
	found=0
	for mf in "${REPO_ROOT}/.claude-plugin/marketplace.json" \
		"${REPO_ROOT}/.github/plugin/marketplace.json"; do
		[ -f "$mf" ] || continue
		# basename is "marketplace.json" for BOTH manifests, so a failure would
		# not say which file is wrong. Report the path relative to the repo.
		rel="${mf#"${REPO_ROOT}/"}"
		while IFS= read -r p; do
			[ -n "$p" ] || continue
			found=$((found + 1))
			[ -d "${REPO_ROOT}/${p}" ] || {
				echo "${rel}: source.path does not resolve: ${p}"
				return 1
			}
			case "$(basename "$p")" in
				claude-code | copilot) ;;
				*)
					echo "${rel}: ${p} is not a target workspace"
					return 1
					;;
			esac
		done < <(jq -r '
			.plugins[]
			| select(
				(.source.url // .source.repo // "")
				# Anchored: a bare "spencerbeggs/bot" substring would also match a
				# future "spencerbeggs/bot2". The value is an owner/repo pair in
				# .github/plugin/marketplace.json and a full URL in
				# .claude-plugin/marketplace.json, so accept either shape.
				| test("(^|/)spencerbeggs/bot(\\.git)?$")
			)
			| .source.path // empty
		' "$mf")
	done
	[ "$found" -gt 0 ] || {
		echo "no self-referencing marketplace entries found — test would pass vacuously"
		return 1
	}
}
