#!/usr/bin/env bash
#
# trigger-harness.sh — run a positive/negative query set against a client N
# times each and report a per-query trigger rate. Starting point, not a
# finished tool: the check_triggered() function below is the one part every
# client swaps. Everything else (the query loop, the run count, the
# trigger-rate arithmetic) is client-independent and should not need editing.
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage: trigger-harness.sh --skill NAME --positives FILE --negatives FILE
                           --runs N --transcript-dir DIR [--dry-run]

Runs every query in --positives and --negatives against the client under
test, --runs times each, and prints one JSON line per query:
  {"query":"...","expected":true,"triggered":2,"runs":3,"rate":0.67}

Each line of --positives and --negatives is one query; blank lines and lines
starting with # are skipped. --transcript-dir is where this run's transcripts
are written before check_triggered() inspects them — the shape of a
transcript, and how a run is actually invoked, is client-specific and left as
a TODO below; there is no portable "run the client" primitive to script here.

Options:
  --skill NAME          Skill name being evaluated (passed to check_triggered).
  --positives FILE      Should-trigger queries, one per line.
  --negatives FILE      Should-not-trigger queries, one per line.
  --runs N              Runs per query (methodology default: 3).
  --transcript-dir DIR  Directory to write/read per-run transcripts.
  --dry-run             Print the query plan without invoking the client.
  -h, --help            Show this message.

Requires jq.

Exit codes:
  0  completed (query trigger rates are printed regardless of pass/fail —
     this harness reports, applying any pass threshold is the caller's job)
  2  usage error, or a required tool (jq) is missing

READ THIS BEFORE TRUSTING A RATE. Invoking the client is a TODO in the run
loop below — nothing here actually runs a query, so no transcript is ever
written, so check_triggered() finds no file and every query reports "rate":0
whether or not the skill would have fired. A run of all-zeroes therefore means
"not wired up yet", NOT "the skill never triggers", and the two are
indistinguishable from this output alone. Fill in the invocation first, then
confirm on a query you know should fire that this harness reports a non-zero
rate, before reading any result as a finding.
USAGE
}

die() {
	printf 'Error: %s\n' "$1" >&2
	exit 2
}

# Reject an option whose value is missing or is itself a flag, rather than
# letting `shift 2` run off the end of the argument list under set -e with no
# message, or silently consuming the next flag as a value.
require_value() {
	# $1 = flag name, $2 = remaining arg count (from "$#" before shifting),
	# $3 = candidate value (pass "${2-}" from the caller; may be unset/empty)
	[ "$2" -ge 2 ] || die "$1 requires a value. Run with --help for usage."
	# Only reject a value that is itself one of this script's own flags — not
	# every token starting with '-', which would also catch a negative
	# --runs value or a '-'-prefixed --positives/--negatives filename and
	# report the wrong problem for both.
	case "$3" in
		--skill | --positives | --negatives | --runs | --transcript-dir | --dry-run | -h | --help)
			die "$1 requires a value but got the flag '$3'. Run with --help for usage."
			;;
	esac
	[ -n "$3" ] || die "$1 was given an empty value; it requires a value. Run with --help for usage."
}

# ---------------------------------------------------------------------------
# The one function to swap per client. As shipped it assumes a Claude Code
# transcript (JSONL) and looks for a Skill tool invocation naming $skill.
# For another client, replace the body with whatever that client exposes as
# evidence a skill fired: a log line, an exported trace, a marker string its
# own eval tooling emits. Keep the signature and the 0/1 exit contract.
# ---------------------------------------------------------------------------
check_triggered() {
	# $1 = skill name, $2 = path to this run's transcript
	local skill="$1" transcript="$2"
	[ -f "$transcript" ] || return 1
	grep -q "\"name\":\"Skill\"[^}]*\"skill\":\"${skill}\"" "$transcript"
}

SKILL="" POSITIVES="" NEGATIVES="" RUNS="" TRANSCRIPT_DIR="" DRYRUN=0
while [ $# -gt 0 ]; do
	case "$1" in
		--skill) require_value --skill "$#" "${2-}"; SKILL="$2"; shift 2 ;;
		--positives) require_value --positives "$#" "${2-}"; POSITIVES="$2"; shift 2 ;;
		--negatives) require_value --negatives "$#" "${2-}"; NEGATIVES="$2"; shift 2 ;;
		--runs) require_value --runs "$#" "${2-}"; RUNS="$2"; shift 2 ;;
		--transcript-dir) require_value --transcript-dir "$#" "${2-}"; TRANSCRIPT_DIR="$2"; shift 2 ;;
		--dry-run) DRYRUN=1; shift ;;
		-h | --help) usage; exit 0 ;;
		*) die "Unknown argument '$1'. Run with --help for usage." ;;
	esac
done

command -v jq >/dev/null 2>&1 || die "jq is required but was not found in PATH."
[ -n "$SKILL" ] || die "--skill is required. Run with --help for usage."
[ -n "$POSITIVES" ] && [ -f "$POSITIVES" ] || die "--positives must name an existing file."
[ -n "$NEGATIVES" ] && [ -f "$NEGATIVES" ] || die "--negatives must name an existing file."
case "$RUNS" in '' | *[!0-9]*) die "--runs must be a positive integer." ;; esac
[ "$RUNS" -gt 0 ] || die "--runs must be a positive integer."
[ -n "$TRANSCRIPT_DIR" ] || die "--transcript-dir is required. Run with --help for usage."
mkdir -p "$TRANSCRIPT_DIR"

run_set() {
	# $1 = file of queries, $2 = expected ("true"/"false")
	local file="$1" expected="$2" query triggered total i transcript digest
	while IFS= read -r query; do
		case "$query" in '' | '#'*) continue ;; esac
		triggered=0
		total="$RUNS"
		digest="$(printf '%s' "$query" | cksum | cut -d' ' -f1)"
		for i in $(seq 1 "$RUNS"); do
			transcript="${TRANSCRIPT_DIR}/${digest}-${i}.jsonl"
			if [ "$DRYRUN" -eq 1 ]; then
				continue
			fi
			# TODO: invoke the client under test on $query, writing its
			# transcript to $transcript. There is no portable way to script
			# this step — it depends on the client's CLI or API surface.
			if check_triggered "$SKILL" "$transcript"; then
				triggered=$((triggered + 1))
			fi
		done
		# jq owns every byte of the JSON below: --arg/--argjson escape the
		# query and compute the rate, so a query containing quotes,
		# backslashes or newlines can never produce malformed output, and
		# there is no bareword "expected"/"exp" for a shell or awk builtin to
		# shadow.
		if [ "$DRYRUN" -eq 1 ]; then
			jq -nc --arg query "$query" --argjson expected "$expected" --argjson runs "$total" \
				'{query: $query, expected: $expected, runs: $runs, dry_run: true}'
		else
			jq -nc --arg query "$query" --argjson expected "$expected" \
				--argjson triggered "$triggered" --argjson runs "$total" \
				'{query: $query, expected: $expected, triggered: $triggered, runs: $runs,
				  rate: (($triggered / $runs * 100 | round) / 100)}'
		fi
	done <"$file"
}

run_set "$POSITIVES" true
run_set "$NEGATIVES" false
