#!/usr/bin/env bats
#
# Smoke tests for the four hooks/lib/*.sh templates that plugin-setup ships.
#
# These files are copied VERBATIM into every scaffolded plugin, so a defect in
# one is a defect in every downstream hook. Nothing executed them until this
# file existed: a Critical in hook-debug.sh — an override lookup that aborted
# the calling hook on any hyphenated prefix — survived a full header rewrite
# and two independent reviews because every check was a read, not a run. It
# also passed on bash 3.2 and failed on bash 4+, so it was invisible on the
# machine everyone develops on. Hence the two-major matrix below.
#
# Deliberately a smoke test, not a unit suite: does it load, does it run
# without aborting, does it write where it says it writes.

setup() {
	TEST_DIR="$(cd "${BATS_TEST_DIRNAME}" && pwd)"
	TARGET_DIR="$(dirname "$TEST_DIR")"
	LIB="${TARGET_DIR}/skills/plugin-setup/templates/hooks/lib"
	WORK="${BATS_TEST_TMPDIR}"
}

# Emits one absolute bash path per major version available, 3.2 first.
# `bash` on PATH is deliberately not consulted: it is whichever major the
# developer happens to have shadowing the system one, which is the exact
# blind spot this matrix exists to close.
bash_bins() {
	local seen_majors="" candidate major
	for candidate in /bin/bash /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash; do
		[ -x "$candidate" ] || continue
		major="$("$candidate" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null)" || continue
		case " $seen_majors " in *" $major "*) continue ;; esac
		seen_majors="$seen_majors $major"
		echo "$candidate"
	done
}

# Runs SCRIPT under BIN with a scrubbed environment. Usage:
#   in_bash <bin> <script> [NAME=VALUE ...] -- [positional ...]
in_bash() {
	local binary="$1" script="$2"
	shift 2
	local envs=()
	while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
		envs+=("$1")
		shift
	done
	[ "${1:-}" = "--" ] && shift
	env -i PATH="$PATH" HOME="${WORK}/home" "${envs[@]}" \
		"$binary" -c "$script" _ "$@"
}

@test "every shipped lib template is exercised by this file" {
	# Guards against a fifth template landing with no coverage at all.
	found=0
	for f in "$LIB"/*.sh; do
		[ -f "$f" ] || continue
		found=$((found + 1))
		grep -q "$(basename "$f")" "${BATS_TEST_FILENAME}" || {
			echo "$(basename "$f") is shipped but never named in this test file"
			return 1
		}
	done
	[ "$found" -gt 0 ] || {
		echo "no lib templates found at ${LIB} — test would pass vacuously"
		return 1
	}
}

@test "the bash matrix covers both majors, or says which one it does not" {
	run bash_bins
	[ "$status" -eq 0 ]
	[ -n "$output" ]
	local majors=""
	while IFS= read -r b; do
		majors="${majors}$("$b" -c 'echo ${BASH_VERSINFO[0]}') "
	done <<< "$output"
	echo "bash majors exercised: ${majors}"
	# One major is enough to run, but never enough to claim coverage — say so
	# in the report rather than letting a single-major run read as a matrix.
	case "$majors" in
		*3*) [[ "$majors" == *4* || "$majors" == *5* ]] || skip "only bash 3.x found; 4+ behaviour unverified here" ;;
		*) skip "no bash 3.x found; 3.2 behaviour unverified here" ;;
	esac
}

# --- hook-debug.sh --------------------------------------------------------

@test "hook-debug.sh: hook_error logs under every prefix shape, on every major" {
	local checked=0 binary prefix upper state log
	while IFS= read -r binary; do
		# The default prefix is hyphenated, so the shipped, unedited template is
		# itself the case that used to abort. Keep it first.
		for pair in "unconfigured-plugin|UNCONFIGURED_PLUGIN" \
			"my-plugin|MY_PLUGIN" "my_plugin|MY_PLUGIN" "myplugin|MYPLUGIN"; do
			prefix="${pair%%|*}"
			upper="${pair##*|}"
			state="${WORK}/err-$("$binary" -c 'echo ${BASH_VERSINFO[0]}')-${prefix}"
			run in_bash "$binary" \
				'set -eu; . "$1"; hook_error probe-hook "smoke message"' \
				"XDG_STATE_HOME=${state}" "HOOK_LOG_PREFIX=${prefix}" \
				-- "${LIB}/hook-debug.sh"
			[ "$status" -eq 0 ] || {
				echo "${binary} prefix='${prefix}': hook_error exited ${status}"
				echo "$output"
				return 1
			}
			# The log DIRECTORY keeps the original spelling; only the override
			# VARIABLE name is mangled to a legal identifier.
			log="${state}/${prefix}/hook-error-log.log"
			[ -f "$log" ] || {
				echo "${binary} prefix='${prefix}': no log at ${log}"
				return 1
			}
			grep -q "probe-hook: smoke message" "$log" 2> /dev/null || {
				echo "${binary} prefix='${prefix}': log written but message missing"
				cat "$log"
				return 1
			}
			# And the mangled override name is honoured.
			run in_bash "$binary" \
				'set -eu; . "$1"; hook_error probe-hook "override message"' \
				"XDG_STATE_HOME=${state}" "HOOK_LOG_PREFIX=${prefix}" \
				"${upper}_HOOK_ERROR_LOG=${state}/custom.log" \
				-- "${LIB}/hook-debug.sh"
			[ "$status" -eq 0 ]
			grep -q "override message" "${state}/custom.log" 2> /dev/null || {
				echo "${binary} prefix='${prefix}': ${upper}_HOOK_ERROR_LOG ignored"
				return 1
			}
			checked=$((checked + 1))
		done
	done < <(bash_bins)
	[ "$checked" -gt 0 ] || {
		echo "no bash interpreters found — test would pass vacuously"
		return 1
	}
}

@test "hook-debug.sh: hook_debug is silent off, logs on, under every prefix shape" {
	local checked=0 binary prefix upper state log
	while IFS= read -r binary; do
		for pair in "unconfigured-plugin|UNCONFIGURED_PLUGIN" \
			"my-plugin|MY_PLUGIN" "my_plugin|MY_PLUGIN" "myplugin|MYPLUGIN"; do
			prefix="${pair%%|*}"
			upper="${pair##*|}"
			state="${WORK}/dbg-$("$binary" -c 'echo ${BASH_VERSINFO[0]}')-${prefix}"
			log="${state}/${prefix}/hook-debug-log.log"

			# Off by default: must return 0 and write nothing.
			run in_bash "$binary" \
				'set -eu; . "$1"; hook_debug probe-hook "quiet message"' \
				"XDG_STATE_HOME=${state}" "HOOK_LOG_PREFIX=${prefix}" \
				-- "${LIB}/hook-debug.sh"
			[ "$status" -eq 0 ] || {
				echo "${binary} prefix='${prefix}': hook_debug exited ${status} while off"
				echo "$output"
				return 1
			}
			[ ! -f "$log" ] || {
				echo "${binary} prefix='${prefix}': hook_debug logged while off"
				return 1
			}

			# On via the mangled flag name.
			run in_bash "$binary" \
				'set -eu; . "$1"; hook_debug probe-hook "loud message"' \
				"XDG_STATE_HOME=${state}" "HOOK_LOG_PREFIX=${prefix}" \
				"${upper}_HOOK_DEBUG=1" \
				-- "${LIB}/hook-debug.sh"
			[ "$status" -eq 0 ] || {
				echo "${binary} prefix='${prefix}': hook_debug exited ${status} while on"
				echo "$output"
				return 1
			}
			grep -q "probe-hook: loud message" "$log" 2>/dev/null || {
				echo "${binary} prefix='${prefix}': ${upper}_HOOK_DEBUG=1 did not enable logging"
				return 1
			}
			checked=$((checked + 1))
		done
	done < <(bash_bins)
	[ "$checked" -gt 0 ] || {
		echo "no bash interpreters found"
		return 1
	}
}

# --- hook-output.sh -------------------------------------------------------

@test "hook-output.sh: every emitter runs and prints its documented shape" {
	command -v jq > /dev/null || skip "jq not on PATH; every emitter but emit_noop needs it"
	local checked=0 binary
	while IFS= read -r binary; do
		run in_bash "$binary" 'set -eu; . "$1"; emit_noop' -- "${LIB}/hook-output.sh"
		[ "$status" -eq 0 ]
		# Not `${lines[-1]}`: a negative subscript needs bash 4.2+ in the BATS
		# host, and on empty output it aborts with "bad array subscript" — a
		# raw bash error in place of the diagnostic whoever trips this needs.
		[ "${#lines[@]}" -gt 0 ] || {
			echo "${binary}: emit_noop printed nothing; expected {}"
			return 1
		}
		[ "${lines[$((${#lines[@]} - 1))]}" = "{}" ] || {
			echo "${binary}: emit_noop printed '${output}'; expected {}"
			return 1
		}

		run in_bash "$binary" 'set -eu; . "$1"; emit_allow' -- "${LIB}/hook-output.sh"
		[ "$status" -eq 0 ]
		echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' > /dev/null

		run in_bash "$binary" \
			'set -eu; . "$1"; emit_allow "{\"command\":\"ls\"}"' \
			-- "${LIB}/hook-output.sh"
		[ "$status" -eq 0 ]
		echo "$output" | jq -e '.hookSpecificOutput.updatedInput.command == "ls"' > /dev/null

		# Invalid JSON must degrade to a plain allow, not to empty stdout.
		run in_bash "$binary" 'set -eu; . "$1"; emit_allow "not json"' \
			-- "${LIB}/hook-output.sh"
		[ "$status" -eq 0 ]
		echo "$output" | grep -v '^emit_allow:' |
			jq -e '.hookSpecificOutput | .permissionDecision == "allow" and (has("updatedInput") | not)' > /dev/null

		run in_bash "$binary" 'set -eu; . "$1"; emit_deny "because"' \
			-- "${LIB}/hook-output.sh"
		[ "$status" -eq 0 ]
		echo "$output" | jq -e '
			.hookSpecificOutput.permissionDecision == "deny"
			and .hookSpecificOutput.permissionDecisionReason == "because"' > /dev/null

		run in_bash "$binary" 'set -eu; . "$1"; emit_context PostToolUse "ctx"' \
			-- "${LIB}/hook-output.sh"
		[ "$status" -eq 0 ]
		echo "$output" | jq -e '
			.hookSpecificOutput.hookEventName == "PostToolUse"
			and .hookSpecificOutput.additionalContext == "ctx"' > /dev/null

		checked=$((checked + 1))
	done < <(bash_bins)
	[ "$checked" -gt 0 ] || {
		echo "no bash interpreters found"
		return 1
	}
}

# --- source-session-env.sh ------------------------------------------------

@test "source-session-env.sh: recovers exports, refuses unsafe ids, never aborts" {
	local checked=0 binary home
	while IFS= read -r binary; do
		home="${WORK}/sse-$("$binary" -c 'echo ${BASH_VERSINFO[0]}')"
		mkdir -p "${home}/.claude/session-env/sess-1"
		echo 'export RECOVERED=yes' > "${home}/.claude/session-env/sess-1/demo-hook.sh"
		# A neighbouring plugin's malformed file must not take the caller down.
		echo 'this is not ( valid shell' > "${home}/.claude/session-env/sess-1/broken-hook.sh"

		run env -i PATH="$PATH" HOME="$home" "$binary" -c \
			'set -eu; . "$1"; source_session_env "sess-1"; echo "got=${RECOVERED:-none}"' \
			_ "${LIB}/source-session-env.sh"
		[ "$status" -eq 0 ] || {
			echo "${binary}: aborted with ${status}"
			echo "$output"
			return 1
		}
		[[ "$output" == *"got=yes"* ]] || {
			echo "${binary}: exports not recovered: ${output}"
			return 1
		}

		# No id, and a traversal id, are both silent no-ops returning 0.
		for bad in "" "../../etc" "."; do
			run env -i PATH="$PATH" HOME="$home" "$binary" -c \
				'set -eu; . "$1"; source_session_env "$2"; echo ok' \
				_ "${LIB}/source-session-env.sh" "$bad"
			[ "$status" -eq 0 ] || {
				echo "${binary}: id '${bad}' aborted with ${status}"
				return 1
			}
			[[ "$output" == *"ok"* ]]
		done

		# Sourcing the file must NOT auto-invoke on the caller's positional args.
		run env -i PATH="$PATH" HOME="$home" "$binary" -c \
			'set -eu; . "$1"; echo "got=${RECOVERED:-none}"' \
			_ "${LIB}/source-session-env.sh" "sess-1"
		[ "$status" -eq 0 ]
		[[ "$output" == *"got=none"* ]] || {
			echo "${binary}: file auto-invoked on the caller's \$1"
			return 1
		}
		checked=$((checked + 1))
	done < <(bash_bins)
	[ "$checked" -gt 0 ] || {
		echo "no bash interpreters found"
		return 1
	}
}

# --- gh-wrapper.sh --------------------------------------------------------

@test "gh-wrapper.sh: _gh translates the namespaced token and scrubs the pager" {
	local checked=0 binary shim
	shim="${WORK}/shim"
	mkdir -p "$shim"
	cat > "${shim}/gh" << 'SHIM'
#!/bin/sh
echo "argv:$*"
echo "token:${GH_TOKEN:-<unset>}"
echo "pager:${GH_PAGER:-<unset>}"
exit "${FAKE_GH_EXIT:-0}"
SHIM
	chmod +x "${shim}/gh"

	while IFS= read -r binary; do
		# Namespaced token wins over the user's stale GH_TOKEN.
		run env -i PATH="${shim}:$PATH" HOME="${WORK}/home" \
			GH_WRAPPER_TOKEN_VAR=MYPLUGIN_GH_TOKEN MYPLUGIN_GH_TOKEN=ns-secret \
			GH_TOKEN=stale GH_PAGER=less \
			"$binary" -c 'set -eu; . "$1"; _gh api /rate_limit' _ "${LIB}/gh-wrapper.sh"
		[ "$status" -eq 0 ] || {
			echo "${binary}: _gh exited ${status}"
			echo "$output"
			return 1
		}
		[[ "$output" == *"argv:api /rate_limit"* ]]
		[[ "$output" == *"token:ns-secret"* ]] || {
			echo "${binary}: namespaced token not used: ${output}"
			return 1
		}
		[[ "$output" == *"pager:cat"* ]]

		# No token anywhere: GH_TOKEN must be UNSET, not empty, so gh reaches
		# the keyring instead of authenticating with an empty string.
		run env -i PATH="${shim}:$PATH" HOME="${WORK}/home" \
			GH_WRAPPER_TOKEN_VAR=MYPLUGIN_GH_TOKEN \
			"$binary" -c 'set -eu; . "$1"; _gh api /x' _ "${LIB}/gh-wrapper.sh"
		[ "$status" -eq 0 ]
		[[ "$output" == *"token:<unset>"* ]] || {
			echo "${binary}: empty token leaked into the env: ${output}"
			return 1
		}

		# _gh_auth_ok mirrors gh's own exit code and prints nothing.
		run env -i PATH="${shim}:$PATH" HOME="${WORK}/home" \
			"$binary" -c 'set -eu; . "$1"; _gh_auth_ok && echo AUTHED' _ "${LIB}/gh-wrapper.sh"
		[ "$status" -eq 0 ]
		[[ "$output" == *"AUTHED"* ]]

		run env -i PATH="${shim}:$PATH" HOME="${WORK}/home" FAKE_GH_EXIT=1 \
			"$binary" -c '. "$1"; if _gh_auth_ok; then echo AUTHED; else echo DENIED; fi' \
			_ "${LIB}/gh-wrapper.sh"
		[ "$status" -eq 0 ]
		[[ "$output" == *"DENIED"* ]] || {
			echo "${binary}: _gh_auth_ok did not surface gh's failure: ${output}"
			return 1
		}
		checked=$((checked + 1))
	done < <(bash_bins)
	[ "$checked" -gt 0 ] || {
		echo "no bash interpreters found"
		return 1
	}
}
