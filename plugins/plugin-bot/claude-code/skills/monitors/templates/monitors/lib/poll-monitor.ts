#!/usr/bin/env node
// poll-monitor.ts — the house harness for polling plugin monitors.
//
// Copy verbatim to <plugin>/monitors/lib/poll-monitor.ts; do not customize.
// A monitor script supplies scan() (all I/O) and four small judgement
// handlers; this harness owns everything that is easy to get subtly wrong:
//
//   - self-scheduling loop, never setInterval — each scan finishes before the
//     next starts. Overlapping ticks would both read the same state snapshot
//     before either writes it back, losing streak increments and corrupting
//     the debounce state.
//   - stable-streak debounce — a changing value (a build in progress, an agent
//     mid-fix) never notifies; only a value that holds still across
//     `stablePolls` consecutive polls fires.
//   - notify-once dedup — a stable value fires exactly once; a return to the
//     clear state resets the dedup so a later regression fires again.
//   - --once mode — single-shot check with no polling history to build a
//     quiet period from, so it reports current findings immediately.
//   - never-crash ticks — a monitor must outlive transient errors; a failed
//     tick is skipped and retried, never thrown.
//
// stdout is the notification channel: every line printed lands in the
// session as a notification. Debug output must go to stderr, never stdout.
import { realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

// The judgement half a monitor script must supply. Keep every handler pure —
// I/O belongs in scan(), so tests can drive these through debounceStep
// without touching the filesystem.
export interface PollSampleHandlers<T> {
	/** Stable identity of a sample across polls (e.g. its file path). */
	key(sample: T): string;
	/** Change detection for the streak — two samples with equal fingerprints count as "holding still". */
	fingerprint(sample: T): string;
	/** True when the sample is healthy. Clears the dedup so a later regression fires again. */
	isClear(sample: T): boolean;
	/** The notification line. One line, agent-directed — see references/notification-copy.md. */
	notify(sample: T): string;
}

export interface PollMonitorOptions<T> extends PollSampleHandlers<T> {
	/** Gather the current samples. All I/O lives here; tolerate partial reads by omitting the sample. */
	scan(): Promise<readonly T[]>;
	/** Delay between the end of one scan and the start of the next. */
	pollMs: number;
	/**
	 * Consecutive polls a non-clear fingerprint must hold, unchanged, before
	 * notifying. 0 fires immediately. Monitors should read this from a
	 * namespaced env var (<PLUGIN>_<MONITOR>_STABLE_POLLS) so users can tune it.
	 */
	stablePolls: number;
}

export interface TrackedState {
	fingerprint: string;
	streak: number;
	/** Fingerprint last notified for this key; undefined once the sample clears. */
	notified: string | undefined;
}

export type DebounceState = Map<string, TrackedState>;

export interface DebounceResult {
	lines: string[];
	next: DebounceState;
}

// Pure debounce step: current samples + previous state in, notification lines
// + next state out. Exported separately from the loop so vitest can exercise
// a monitor's handlers without starting a poll.
export function debounceStep<T>(
	current: readonly T[],
	prev: DebounceState,
	minStablePolls: number,
	handlers: PollSampleHandlers<T>,
): DebounceResult {
	const lines: string[] = [];
	const next: DebounceState = new Map();
	for (const sample of current) {
		const key = handlers.key(sample);
		const fingerprint = handlers.fingerprint(sample);
		const before = prev.get(key);
		const streak = before && before.fingerprint === fingerprint ? before.streak + 1 : 0;
		let notified = before?.notified;
		if (handlers.isClear(sample)) {
			notified = undefined;
		} else if (streak >= minStablePolls && notified !== fingerprint) {
			lines.push(handlers.notify(sample));
			notified = fingerprint;
		}
		next.set(key, { fingerprint, streak, notified });
	}
	return { lines, next };
}

export async function runPollMonitor<T>(options: PollMonitorOptions<T>): Promise<void> {
	const once = process.argv.includes("--once");
	const minStablePolls = once ? 0 : options.stablePolls;
	let prev: DebounceState = new Map();
	const tick = async (): Promise<void> => {
		try {
			const { lines, next } = debounceStep(await options.scan(), prev, minStablePolls, options);
			prev = next;
			for (const line of lines) {
				console.log(line);
			}
		} catch {
			// Never crash the monitor — skip this tick and retry on the next.
		}
	};
	await tick();
	if (once) {
		return;
	}
	const loop = async (): Promise<void> => {
		await tick();
		setTimeout(loop, options.pollMs);
	};
	setTimeout(loop, options.pollMs);
}

// True when the calling script is the process entrypoint — the guard that
// lets tests import a monitor's handlers without starting its loop. Compare
// via realpathSync: with a symlinked plugin root, argv[1] is the symlink and
// import.meta.url the resolved real path, and a naive comparison would make
// the monitor silently never start.
export function invokedDirectly(scriptUrl: string): boolean {
	const entry = process.argv[1];
	if (!entry) {
		return false;
	}
	try {
		return realpathSync(entry) === realpathSync(fileURLToPath(scriptUrl));
	} catch {
		return false;
	}
}
