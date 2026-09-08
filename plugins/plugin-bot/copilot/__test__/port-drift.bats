#!/usr/bin/env bats
#
# Pins on the Copilot port of plugin-bot.
#
# Two kinds of claim live here, and the distinction matters:
#
#   1. Currency — is the port abreast of its source? `port-status.sh --check`
#      answers that by comparing SOURCE content hashes to RECORDED hashes.
#      It never opens a port file, so it cannot see what the port SAYS.
#   2. Portness — is the port actually re-authored for the other host? Every
#      assertion below that greps `copilot/**` exists because --check is blind
#      to it: after any legitimate re-port plus `--record`, a Claude-only key
#      or a live Claude token in the port is green under currency alone.
#
# Bodies diverge per host by design, so identity is the wrong contract for
# either question.

setup() {
	PORT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	PLUGIN_DIR="$(dirname "${PORT_DIR}")"
	SOURCE_DIR="${PLUGIN_DIR}/claude-code"
	LEDGER="${PORT_DIR}/port-status.json"
	TOOL="${SOURCE_DIR}/skills/porting-to-copilot/scripts/port-status.sh"
}

# Emits the YAML frontmatter block of $1, exclusive of both `---` fences.
# Empty when the file opens with anything other than a fence.
frontmatter() {
	awk 'NR == 1 && $0 == "---" { inside = 1; next }
	     inside && $0 == "---" { exit }
	     inside { print }' "$1"
}

# --- portness -------------------------------------------------------------

@test "no Claude-only frontmatter key survives in a ported skill" {
	# paths:, user-invocable: and disable-model-invocation: are Claude Code
	# skill fields with no Copilot equivalent. All three also appear legitimately
	# in port bodies — inside quoted doc-mirror tables and in prose teaching what
	# Claude Code does — so a substring grep over the file would fire on correct
	# content. The claim is about frontmatter KEYS, and only frontmatter is read.
	found=0
	for skill in "${PORT_DIR}"/skills/*/SKILL.md; do
		[ -f "$skill" ] || continue
		found=$((found + 1))
		if frontmatter "$skill" |
			grep -nE '^[[:space:]]*(paths|user-invocable|disable-model-invocation)[[:space:]]*:'; then
			echo "^^ ${skill}: Claude-only key in frontmatter"
			echo "   fix: drop the key and absorb its trigger into description:"
			return 1
		fi
	done
	[ "$found" -gt 0 ] || {
		echo "no ported SKILL.md files found — test would pass vacuously"
		return 1
	}
}

@test "no live \${CLAUDE_PLUGIN_ROOT}/skills/<real-skill>/ pointer survives in the port" {
	# Task 16 rewrote 64 of these and left 62 placeholders verbatim; nothing
	# guards the rewrites. The discriminator is shape, not path: a pointer is
	# LIVE when the segment after skills/ names a directory that actually exists
	# under the source workspace. `<name>` — the taught-pattern placeholder in
	# skill-scripts — names no such directory and is left alone by construction,
	# so no allowlist is needed and none is kept.
	while IFS= read -r hit; do
		[ -n "$hit" ] || continue
		file="${hit%%:*}"
		match="${hit#*:}"
		name="${match#*skills/}"
		name="${name%%/*}"
		if [ -d "${SOURCE_DIR}/skills/${name}" ]; then
			echo "${file}: live Claude pointer into real skill '${name}'"
			echo "   Copilot substitutes no token in skill content; it renders literally."
			echo "   fix: write the path the reader resolves themselves."
			return 1
		fi
	done < <(grep -ro '\${CLAUDE_PLUGIN_ROOT}/skills/[^/]*/' "$PORT_DIR" || true)
}

@test "the ported agent carries no tools: key, and still explains why" {
	agent="${PORT_DIR}/agents/plugin-engineer.agent.md"
	[ -f "$agent" ]
	# The absence is deliberate: neither candidate identifier set is schema-backed.
	if frontmatter "$agent" | grep -nE '^[[:space:]]*tools[[:space:]]*:'; then
		echo "^^ ${agent}: tools: key present"
		echo "   fix: the identifiers are unresolved; leave the key out."
		return 1
	fi
	# An unexplained absence is indistinguishable from an oversight, so the
	# marker naming both candidate sets is part of the contract.
	grep -q '<!-- tools: unresolved' "$agent" || {
		echo "${agent}: the tools-unresolved marker comment is gone."
		echo "   Without it nothing records that the absence is a decision."
		return 1
	}
}

# --- host-config parity ---------------------------------------------------

@test "hooks.json and .mcp.json are matched across targets or ledgered claudeOnly" {
	# Neither file is tracked by the ledger's own file sweep (skills/**/*.md and
	# agents/**/*.md only) nor mentioned in canonical-layout.bats, so a hooks.json
	# added to one target and forgotten on the other is invisible to both.
	checked=0
	for base in hooks.json .mcp.json; do
		for pair in "${SOURCE_DIR}|${PORT_DIR}" "${PORT_DIR}|${SOURCE_DIR}"; do
			here="${pair%%|*}"
			there="${pair##*|}"
			hit="$(find "$here" -maxdepth 2 -type f -name "$base" | head -1)"
			[ -n "$hit" ] || continue
			checked=$((checked + 1))
			find "$there" -maxdepth 2 -type f -name "$base" | grep -q . && continue
			# A missing sibling is legal only when the ledger says so, with a reason.
			rel="${hit#"${here}"/}"
			excused="$(jq -r --arg k "$rel" '
				(.entries[$k] // {})
				| select(.claudeOnly == true and ((.reason // "") | length > 0))
				| "yes"
			' "$LEDGER")"
			[ "$excused" = "yes" ] || {
				echo "${hit} has no counterpart in ${there}"
				echo "   fix: port it, or add a claudeOnly entry with a reason for"
				echo "        '${rel}' to ${LEDGER}"
				return 1
			}
		done
	done
	# This test is conditional by nature. Say so out loud rather than reporting a
	# pass nobody earned: plugin-bot ships neither file today.
	[ "$checked" -gt 0 ] || skip "no target ships hooks.json or .mcp.json — nothing to check"
}

# --- currency -------------------------------------------------------------

@test "the port-status tool is present and self-documenting" {
	[ -f "$TOOL" ]
	run bash "$TOOL" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"--check"* ]]
	[[ "$output" == *"--record"* ]]
}

@test "the ledger exists and is valid JSON with a non-empty entries map" {
	[ -f "$LEDGER" ]
	run jq -e '.entries | type == "object"' "$LEDGER"
	[ "$status" -eq 0 ]
	run jq -r '.entries | length' "$LEDGER"
	[ "$status" -eq 0 ]
	[ "$output" -gt 0 ]
}

@test "the port is current: no missing, stale, orphaned or unclassified files" {
	run bash "$TOOL" --source "$SOURCE_DIR" --port "$PORT_DIR" \
		--ledger "$LEDGER" --check
	if [ "$status" -ne 0 ]; then
		echo "--- port problems ---"
		echo "$output"
		echo "--- fix: port the change, or mark it claudeOnly with a reason,"
		echo "         then re-run port-status.sh --record ---"
	fi
	[ "$status" -eq 0 ]
}
