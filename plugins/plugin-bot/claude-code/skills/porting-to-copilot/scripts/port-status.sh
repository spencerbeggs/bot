#!/usr/bin/env bash
#
# port-status.sh — check or record the port ledger between a source plugin
# target workspace and its port. Content hashes are used rather than git SHAs
# because squash-merges rewrite SHAs and collapse commit timestamps.
#
# Self-contained by design: every input arrives as a flag, so the script runs
# identically when an agent invokes it and when a developer runs it standalone.
# It reads no CLAUDE_* / PLUGIN_* variable and writes nothing outside the ledger
# named on the command line.
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage: port-status.sh --source DIR --port DIR --ledger FILE (--check | --record)

Compares a source-of-truth plugin target workspace against its port, using a
ledger of content hashes to decide whether the port is current. Tracks
skills/**/*.md and agents/**/*.md only.

Options:
  --source DIR   Source-of-truth workspace (e.g. plugins/x/claude-code)
  --port DIR     Ported workspace (e.g. plugins/x/copilot)
  --ledger FILE  Path to port-status.json
  --check        Report drift. Prints a JSON report on stdout.
  --record       Rewrite the ledger from the source's current contents.
  --dry-run      With --record, print what would change; write nothing.
  -h, --help     Show this message.

Each of --source, --port and --ledger takes exactly one value and may be given
only once. --check and --record are mutually exclusive; pass exactly one.

Ledger entries are keyed by source-relative path. Each value is either:
  {"sourceHash": "sha256:..."}           a real port, currency tracked
  {"claudeOnly": true, "reason": "..."}  deliberately not ported

Both modes print JSON on stdout and human-readable diagnostics on stderr.
Output is one line per problem, so it is bounded by the source file count.

Exit codes:
  0  check passed, or record succeeded
  1  drift found: missing port, orphaned port, stale hash, or unclassified file
  2  usage or environment error

Examples:
  bash port-status.sh --source plugins/p/claude-code --port plugins/p/copilot \
    --ledger plugins/p/copilot/port-status.json --check
  bash port-status.sh --source plugins/p/claude-code --port plugins/p/copilot \
    --ledger plugins/p/copilot/port-status.json --record --dry-run
USAGE
}

die() {
	printf 'Error: %s\n' "$1" >&2
	exit 2
}

# Reject an option whose value is missing or is itself a flag, rather than
# silently consuming the next flag as a path.
need_value() {
	# $1 flag, $2 remaining argc, $3 candidate value
	[ "$2" -ge 2 ] || die "$1 requires a value (a path). Run with --help for usage."
	case "$3" in
		-*) die "$1 requires a value (a path) but got the flag '$3'. Run with --help for usage." ;;
	esac
}

# Reject a repeated option rather than letting the last one silently win.
set_once() {
	# $1 variable name, $2 flag, $3 value
	if [ -n "${!1}" ]; then
		die "$2 was given more than once (already '${!1}'). Pass it exactly once."
	fi
	printf -v "$1" '%s' "$3"
}

SOURCE="" PORT="" LEDGER="" MODE="" DRYRUN=0
while [ $# -gt 0 ]; do
	case "$1" in
		--source) need_value "$1" "$#" "${2:-}"; set_once SOURCE --source "$2"; shift 2 ;;
		--port) need_value "$1" "$#" "${2:-}"; set_once PORT --port "$2"; shift 2 ;;
		--ledger) need_value "$1" "$#" "${2:-}"; set_once LEDGER --ledger "$2"; shift 2 ;;
		--check | --record)
			want="${1#--}"
			if [ -n "$MODE" ] && [ "$MODE" != "$want" ]; then
				die "--check and --record are mutually exclusive; pass exactly one."
			fi
			MODE="$want"; shift ;;
		--dry-run) DRYRUN=1; shift ;;
		-h | --help) usage; exit 0 ;;
		*) die "unknown argument '$1'. Run with --help for usage." ;;
	esac
done

[ -n "$SOURCE" ] || die "--source is required."
[ -n "$PORT" ] || die "--port is required."
[ -n "$LEDGER" ] || die "--ledger is required."
[ -n "$MODE" ] || die "one of --check or --record is required."
[ -d "$SOURCE" ] || die "--source is not a directory: $SOURCE"
[ -d "$PORT" ] || die "--port is not a directory: $PORT"
if [ "$MODE" = "check" ] && [ "$DRYRUN" -eq 1 ]; then
	die "--dry-run applies to --record only; --check never writes."
fi
command -v jq >/dev/null 2>&1 || die "jq is required but was not found on PATH."
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
	die "one of sha256sum or shasum is required but neither was found on PATH."
fi

TMPDIR_RUN="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_RUN"' EXIT

hash_of() {
	if command -v sha256sum >/dev/null 2>&1; then
		printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
	else
		printf 'sha256:%s' "$(shasum -a 256 "$1" | awk '{print $1}')"
	fi
}

# agents/<name>.md is agents/<name>.agent.md in the port; everything else maps
# one-to-one.
port_rel_for() {
	case "$1" in
		agents/*.md) printf '%s.agent.md' "${1%.md}" ;;
		*) printf '%s' "$1" ;;
	esac
}

list_md() {
	(cd "$1" && find skills agents -type f -name '*.md' 2>/dev/null | sort)
}

if [ "$MODE" = "record" ]; then
	ledger_dir="$(dirname "$LEDGER")"
	[ -d "$ledger_dir" ] || die "--ledger directory does not exist: $ledger_dir"
	old="${TMPDIR_RUN}/old.json"
	if [ -f "$LEDGER" ]; then
		jq -e 'type == "object" and (.entries | type == "object")' "$LEDGER" >/dev/null 2>&1 ||
			die "ledger is not a JSON object with an 'entries' object: $LEDGER"
		cp "$LEDGER" "$old"
	else
		printf '{"entries":{}}\n' > "$old"
	fi

	tmp="${TMPDIR_RUN}/next.json"
	cp "$old" "$tmp"
	while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		claude_only="$(jq -r --arg k "$rel" '.entries[$k].claudeOnly // false' "$tmp")"
		if [ "$claude_only" = "true" ]; then
			continue
		fi
		h="$(hash_of "${SOURCE}/${rel}")"
		jq --arg k "$rel" --arg h "$h" \
			'.entries[$k] = {sourceHash: $h}' "$tmp" > "${tmp}.w"
		mv "${tmp}.w" "$tmp"
	done < <(list_md "$SOURCE")
	# Drop entries whose source file no longer exists.
	while IFS= read -r key; do
		[ -n "$key" ] || continue
		[ -f "${SOURCE}/${key}" ] && continue
		jq --arg k "$key" 'del(.entries[$k])' "$tmp" > "${tmp}.w"
		mv "${tmp}.w" "$tmp"
	done < <(jq -r '.entries | keys[]' "$tmp")

	new="${TMPDIR_RUN}/sorted.json"
	jq -S '.' "$tmp" > "$new"
	[ "$DRYRUN" -eq 1 ] || cp "$new" "$LEDGER"

	jq -n --slurpfile a "$old" --slurpfile b "$new" \
		--arg ledger "$LEDGER" --argjson dry "$DRYRUN" '
		($a[0].entries // {}) as $A | ($b[0].entries // {}) as $B |
		{
			mode: "record",
			dryRun: ($dry == 1),
			ledger: $ledger,
			entries: ($B | length),
			claudeOnly: [$B | to_entries[] | select(.value.claudeOnly == true) | .key],
			added: [$B | keys[] | select($A[.] == null)],
			updated: [$B | keys[] | select($A[.] != null and $A[.] != $B[.])],
			removed: [$A | keys[] | select($B[.] == null)]
		}'

	if [ "$DRYRUN" -eq 1 ]; then
		printf 'Dry run: %s would hold %s entries. Nothing written.\n' \
			"$LEDGER" "$(jq '.entries | length' "$new")" >&2
	else
		printf 'Recorded %s entries in %s\n' \
			"$(jq '.entries | length' "$LEDGER")" "$LEDGER" >&2
	fi
	exit 0
fi

# --check
[ -f "$LEDGER" ] || die "ledger not found: $LEDGER (run with --record first)"
jq -e 'type == "object" and (.entries | type == "object")' "$LEDGER" >/dev/null 2>&1 ||
	die "ledger is not a JSON object with an 'entries' object: $LEDGER"

problems=0
REPORT="${TMPDIR_RUN}/report.tsv"
: > "$REPORT"
report_add() {
	printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$REPORT"
	problems=$((problems + 1))
}

while IFS= read -r rel; do
	[ -n "$rel" ] || continue
	entry="$(jq -c --arg k "$rel" '.entries[$k] // empty' "$LEDGER")"
	if [ -z "$entry" ]; then
		report_add unclassified "$rel" "no ledger entry; port it or mark it claudeOnly with a reason"
		continue
	fi
	if [ "$(printf '%s' "$entry" | jq -r '.claudeOnly // false')" = "true" ]; then
		reason="$(printf '%s' "$entry" | jq -r '.reason // ""')"
		[ -n "$reason" ] || report_add no-reason "$rel" "claudeOnly entries must carry a reason"
		if [ -f "${PORT}/$(port_rel_for "$rel")" ]; then
			report_add contradiction "$rel" "marked claudeOnly but a port file exists"
		fi
		continue
	fi
	prel="$(port_rel_for "$rel")"
	if [ ! -f "${PORT}/${prel}" ]; then
		report_add missing-port "$rel" "expected ${prel} in the port"
		continue
	fi
	recorded="$(printf '%s' "$entry" | jq -r '.sourceHash // ""')"
	actual="$(hash_of "${SOURCE}/${rel}")"
	[ "$recorded" = "$actual" ] || report_add stale "$rel" \
		"source changed since the port was recorded; port the change or re-record"
done < <(list_md "$SOURCE")

# Orphan check: every port file must map back to a source file.
while IFS= read -r prel; do
	[ -n "$prel" ] || continue
	case "$prel" in
		agents/*.agent.md) srel="${prel%.agent.md}.md" ;;
		*) srel="$prel" ;;
	esac
	[ -f "${SOURCE}/${srel}" ] || report_add orphan "$prel" \
		"no counterpart at ${srel}; the source of truth leads, the port trails"
done < <(list_md "$PORT")

jq -Rn '
	{ problems: [inputs | split("\t") | {kind: .[0], path: .[1], detail: .[2]}] }
	| .ok = (.problems | length == 0)
' < "$REPORT"

if [ "$problems" -gt 0 ]; then
	printf '%s port problem(s) found. See the JSON report on stdout.\n' \
		"$problems" >&2
	exit 1
fi
exit 0
