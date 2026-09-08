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
#
# THE RULE THAT KEEPS THIS SUITE ALIVE, and the reason it is short:
#
#   Assert on structure you control — frontmatter keys, and an allowlist over
#   a denylist wherever the permitted set is enumerable. Assert on tokens in
#   prose ONLY where a shape discriminator exists to separate a live
#   instruction from a documented example. Everything else is a GAP, and an
#   honest gap register beats a test that cries wolf.
#
# GAP REGISTER — considered, consciously left untested, not oversights:
#
#   ${CLAUDE_SKILL_DIR}    (7 occurrences)  Same class as the /skills/ pointer
#                          test below, but with NO shape discriminator: it has
#                          no path segment to check against a real directory,
#                          so nothing separates a live use from an exhibit.
#   ${CLAUDE_PLUGIN_DATA}  (40)
#   ${CLAUDE_PROJECT_DIR}  (37)
#   $CLAUDE_ENV_FILE       (34)
#   plus assorted singletons.
#
# The great majority of these are certainly legitimate doc-mirror content —
# these skills exist partly to DOCUMENT Claude Code — which is precisely why
# no generalised token assertion over them can work. A future maintainer who
# wants one needs a discriminator first, not a broader grep.
#
# KNOWN, DELIBERATE WEAKENING — the pointer test's host-label exemption:
#
#   The ${CLAUDE_PLUGIN_ROOT}/skills/ test below excuses any line carrying a
#   "Claude Code" host label. That is a real hole, not an oversight: a genuinely
#   missed conversion sitting on a line that happens to say "Claude Code" now
#   passes. It was taken knowingly, because porting-to-copilot's whole purpose
#   is to EXHIBIT Claude spellings, so without the exemption the test goes red
#   on correct content the first time a doc-mirror row quotes a real skill name
#   — and a suite that cries wolf gets deleted, and a deleted suite protects
#   nothing. Cries-wolf is the worse failure here. Anyone tightening this needs
#   a better discriminator, not a removed exemption.

setup() {
	PORT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	PLUGIN_DIR="$(dirname "${PORT_DIR}")"
	SOURCE_DIR="${PLUGIN_DIR}/claude-code"
	LEDGER="${PORT_DIR}/port-status.json"
	TOOL="${SOURCE_DIR}/skills/porting-to-copilot/scripts/port-status.sh"
}

# Emits the YAML frontmatter block of $1, exclusive of both `---` fences.
# A leading UTF-8 BOM is stripped before the fence is matched: without that, a
# BOM would make line 1 unequal to `---` and silently exempt the whole file
# from every frontmatter assertion below. Emits nothing when the file genuinely
# has no frontmatter — callers must treat that as a failure, not as a pass.
frontmatter() {
	awk 'NR == 1 { sub(/^\xef\xbb\xbf/, "") }
	     NR == 1 && $0 == "---" { inside = 1; next }
	     inside && $0 == "---" { exit }
	     inside { print }' "$1"
}

# Emits one path per ported component file carrying YAML frontmatter.
ported_components() {
	ls "${PORT_DIR}"/skills/*/SKILL.md "${PORT_DIR}"/agents/*.agent.md 2> /dev/null
}

# --- portness -------------------------------------------------------------

@test "every ported component's frontmatter carries only name and description" {
	# This is an ALLOWLIST, and it replaced a denylist of the three Claude-only
	# keys the port was warned about (paths, user-invocable,
	# disable-model-invocation). The inversion is strictly stronger, and its
	# ALLOWLIST is shorter than the denylist it replaced — the union of
	# frontmatter keys across every ported component is exactly
	# {name, description}, two permitted keys against three forbidden ones — but
	# it cost a LONGER TEST BODY: extracting column-0 keys and looping is more
	# machinery than one alternation grep (measured: 23 non-comment lines before,
	# 31 after). The trade is worth it and is not free.
	#
	# What it buys: enumerating what is banned could only ever catch leaks
	# somebody had already thought of, and the characteristic failure of an
	# enumeration is the entry nobody thought of. argument-hint:, allowed-tools:,
	# model:, license: and whatever Copilot documents next all fail here without
	# an edit.
	#
	# It carries no cry-wolf risk for the same reason the denylist did not: only
	# the frontmatter block is read, so the ~25 legitimate appearances of these
	# strings in port prose and doc-mirror tables stay invisible.
	#
	# Scope is SKILL.md and agent files ONLY. Do NOT widen it to references/ —
	# `allowed-tools:` and `model:` appear there as quoted spec text
	# (agent-skills-spec.md:84, plugins-reference.md:57) and widening turns a
	# clean assertion into exactly the cries-wolf case it avoids.
	#
	# When Copilot documents a third key, add one line below. That edit is a
	# decision worth forcing, not one a test should wave through.
	found=0
	while IFS= read -r component; do
		[ -f "$component" ] || continue
		found=$((found + 1))
		fm="$(frontmatter "$component")"
		# No frontmatter at all is a failure, never an exemption: every
		# assertion in this test is a claim about a block that must exist.
		[ -n "$fm" ] || {
			echo "${component}: no YAML frontmatter block found"
			echo "   Every ported component must open with a --- fence on line 1."
			return 1
		}
		# Only column-0 keys are top-level; a folded description's continuation
		# lines are indented and must not be read as keys.
		while IFS= read -r key; do
			[ -n "$key" ] || continue
			case "${key%:}" in
				name | description) ;;
				*)
					echo "${component}: frontmatter key '${key%:}' is not permitted"
					echo "   Copilot documents only name: and description:."
					echo "   fix: drop the key and absorb what it did into description:,"
					echo "        or — if Copilot now documents it — add it to the"
					echo "        allowlist in this test, deliberately."
					return 1
					;;
			esac
		done < <(printf '%s\n' "$fm" | grep -oE '^[A-Za-z_][A-Za-z0-9_-]*:' || true)
	done < <(ported_components)
	[ "$found" -gt 0 ] || {
		echo "no ported components found — test would pass vacuously"
		return 1
	}
}

@test "no live \${CLAUDE_PLUGIN_ROOT}/skills/<real-skill>/ pointer survives in the port" {
	# Task 16 rewrote 64 of these and left 62 placeholders verbatim; nothing
	# guards the rewrites. Copilot substitutes no token in skill content, so a
	# surviving pointer renders literally and the instruction silently dies.
	#
	# Two conditions make a pointer a violation, and both are shape, not path:
	#
	#   1. The segment after skills/ names a directory that actually exists
	#      under the source workspace — `<name>`, the taught-pattern
	#      placeholder in skill-scripts, names none and is left alone by
	#      construction. No allowlist is needed and none is kept.
	#   2. The LINE carries no explicit "Claude Code" host label. porting-to-
	#      copilot's whole job is to EXHIBIT Claude spellings, so a doc-mirror
	#      row quoting a real skill name is correct content, and firing on it
	#      is the cries-wolf failure this suite avoids elsewhere by asserting
	#      on keys rather than substrings. A label is the house convention for
	#      such an exhibit and is what the one live occurrence already carries.
	#
	# The label was chosen over scoping the sweep past fenced examples because
	# the occurrence that exists today sits in inline backticks inside a prose
	# paragraph, not a fence — fence-scoping would not have seen it at all.
	# Note the sweep must therefore read WHOLE LINES (grep -n, no -o): the
	# label lives in the prose around the pointer, never inside the match.
	while IFS= read -r hit; do
		[ -n "$hit" ] || continue
		file="${hit%%:*}"
		rest="${hit#*:}"
		lineno="${rest%%:*}"
		text="${rest#*:}"
		# One line may carry several pointers; check each.
		while IFS= read -r ptr; do
			[ -n "$ptr" ] || continue
			name="${ptr#*/skills/}"
			name="${name%%/*}"
			[ -d "${SOURCE_DIR}/skills/${name}" ] || continue
			case "$text" in *"Claude Code"*) continue ;; esac
			echo "${file}:${lineno}: live Claude pointer into real skill '${name}'"
			echo "   Copilot substitutes no token in skill content; it renders literally."
			echo "   fix: write the path the reader resolves themselves, or — if this"
			echo "        is a deliberate exhibit — label the host on the same line."
			return 1
		done < <(printf '%s\n' "$text" |
			grep -o '\${CLAUDE_PLUGIN_ROOT}/skills/[^/]*/' || true)
	done < <(grep -rn --exclude-dir=__test__ \
		'\${CLAUDE_PLUGIN_ROOT}/skills/' "$PORT_DIR" || true)

	# Non-vacuity: prove the sweep actually reached the corpus. Without this a
	# wrong PORT_DIR, a broken pattern, or a future grep change passes silently
	# — the exact failure this plan has now shipped twice. __test__ is excluded
	# from both the sweep and the count so the test never inspects itself.
	swept="$(grep -rl --exclude-dir=__test__ 'CLAUDE_PLUGIN_ROOT' "$PORT_DIR" | wc -l | tr -d ' ')"
	[ "$swept" -gt 0 ] || {
		echo "no ported file mentions CLAUDE_PLUGIN_ROOT — the sweep found no corpus"
		echo "   Either PORT_DIR is wrong or the port lost every pointer at once."
		return 1
	}
	echo "swept ${swept} ported files mentioning CLAUDE_PLUGIN_ROOT"
}

@test "the ported agent carries no tools: key, and still explains why" {
	agent="${PORT_DIR}/agents/plugin-engineer.agent.md"
	[ -f "$agent" ]
	# The key half of this claim is now also covered by the allowlist in test 1,
	# which would reject `tools:` like any other unpermitted key. Kept anyway:
	# this test's unique contribution is the SECOND assertion, and the pair
	# reads as one decision. If test 1's allowlist ever gains `tools`, this is
	# the test that must still fail.
	#
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
			# NOTE the asymmetry: the ledger's only excuse key is `claudeOnly`,
			# because the ledger is keyed by SOURCE-relative path and its source
			# is always claude-code. Excusing a Copilot-only file therefore means
			# recording it as `claudeOnly` too, which reads backwards. Renaming
			# the key is a port-status.sh change and out of scope here; this
			# comment is the mitigation. Whoever adds the first such file should
			# reconsider the key name rather than work around it.
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

# The ledger tracks skills/**/*.md and agents/**/*.md only — its --help says so.
# That leaves every non-Markdown file in both targets outside currency checking:
# scaffolded templates and bundled scripts. `--check` is green on a source
# script edited without its port, and the currency test above would not notice.
#
# Byte-identity is the WRONG contract for the .md bodies (they are re-authored
# per host by design, which is why the ledger hashes only the source side). It
# is the RIGHT contract here: these files are host-agnostic code and data,
# copied rather than re-authored, so any difference between the two copies is
# drift by definition.
@test "every non-Markdown file is byte-identical across the two targets" {
	found=0
	drift=0
	while IFS= read -r rel; do
		found=$((found + 1))
		if [ ! -f "${PORT_DIR}/${rel}" ]; then
			echo "missing from the port: ${rel}"
			drift=$((drift + 1))
			continue
		fi
		if ! cmp -s "${SOURCE_DIR}/${rel}" "${PORT_DIR}/${rel}"; then
			echo "differs between targets: ${rel}"
			drift=$((drift + 1))
		fi
	done < <(cd "$SOURCE_DIR" && find skills agents -type f ! -name '*.md' | sort)

	# The ledger's blind spot is exactly why this cannot be allowed to pass
	# vacuously: zero files found would look identical to zero files drifting.
	[ "$found" -gt 0 ] || {
		echo "no non-Markdown files found under ${SOURCE_DIR}/{skills,agents}"
		return 1
	}
	[ "$drift" -eq 0 ] || {
		echo "--- fix: copy the source file over its port. These are not"
		echo "         re-authored per host; they are the same file twice. ---"
		return 1
	}
}

@test "the port carries no non-Markdown file the source lacks" {
	found=0
	while IFS= read -r rel; do
		found=$((found + 1))
		[ -f "${SOURCE_DIR}/${rel}" ] || {
			echo "orphaned in the port, absent from the source: ${rel}"
			return 1
		}
	done < <(cd "$PORT_DIR" && find skills agents -type f ! -name '*.md' | sort)
	[ "$found" -gt 0 ] || {
		echo "no non-Markdown files found under ${PORT_DIR}/{skills,agents}"
		return 1
	}
}
