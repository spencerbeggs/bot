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

Exit codes:
  0  completed (query trigger rates are printed regardless of pass/fail —
     this harness reports, it does not itself apply the 0.5 threshold)
  2  usage error
USAGE
}

die() {
	printf 'Error: %s\n' "$1" >&2
	exit 2
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
		--skill) SKILL="${2:-}"; shift 2 ;;
		--positives) POSITIVES="${2:-}"; shift 2 ;;
		--negatives) NEGATIVES="${2:-}"; shift 2 ;;
		--runs) RUNS="${2:-}"; shift 2 ;;
		--transcript-dir) TRANSCRIPT_DIR="${2:-}"; shift 2 ;;
		--dry-run) DRYRUN=1; shift ;;
		-h | --help) usage; exit 0 ;;
		*) die "Unknown argument '$1'. Run with --help for usage." ;;
	esac
done

[ -n "$SKILL" ] || die "--skill is required. Run with --help for usage."
[ -n "$POSITIVES" ] && [ -f "$POSITIVES" ] || die "--positives must name an existing file."
[ -n "$NEGATIVES" ] && [ -f "$NEGATIVES" ] || die "--negatives must name an existing file."
case "$RUNS" in '' | *[!0-9]*) die "--runs must be a positive integer." ;; esac
[ "$RUNS" -gt 0 ] || die "--runs must be a positive integer."
[ -n "$TRANSCRIPT_DIR" ] || die "--transcript-dir is required. Run with --help for usage."
mkdir -p "$TRANSCRIPT_DIR"

run_set() {
	# $1 = file of queries, $2 = expected ("true"/"false")
	local file="$1" expected="$2" query triggered total i transcript
	while IFS= read -r query; do
		case "$query" in '' | '#'*) continue ;; esac
		triggered=0
		total="$RUNS"
		for i in $(seq 1 "$RUNS"); do
			transcript="${TRANSCRIPT_DIR}/$(printf '%s' "$query" | cksum | cut -d' ' -f1)-${i}.jsonl"
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
		if [ "$DRYRUN" -eq 1 ]; then
			printf '{"query":%s,"expected":%s,"runs":%s,"dry_run":true}\n' \
				"$(printf '%s' "$query" | jq -Rs '. | rtrimstr("\n")')" "$expected" "$total"
		else
			awk -v q="$query" -v exp="$expected" -v t="$triggered" -v n="$total" \
				'BEGIN { printf "{\"query\":\"%s\",\"expected\":%s,\"triggered\":%d,\"runs\":%d,\"rate\":%.2f}\n", q, exp, t, n, t / n }'
		fi
	done <"$file"
}

run_set "$POSITIVES" true
run_set "$NEGATIVES" false
