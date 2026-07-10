#!/usr/bin/env node
// watch-example.ts — poll-monitor exemplar. Copy alongside lib/poll-monitor.ts,
// rename to watch-<thing>.ts, and replace the sample type, scan(), and the
// handlers with your own. The harness owns the loop, debounce, and dedup — a
// monitor script should only ever contain I/O plus judgement.
//
// Namespace substitution when copying:
//   EXAMPLE_WATCHER_STABLE_POLLS → <PLUGIN>_<MONITOR>_STABLE_POLLS
import { globSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import type { PollSampleHandlers } from "./lib/poll-monitor.ts";
import { invokedDirectly, runPollMonitor } from "./lib/poll-monitor.ts";

const ROOT = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();
const POLL_MS = 2000;
// With POLL_MS=2000 the default (3) is a ~6s quiet period: a value still
// changing build-to-build resets the streak, so mid-fix churn never fires.
// 0 restores fire-immediately.
const STABLE_POLLS = Math.max(0, Number(process.env.EXAMPLE_WATCHER_STABLE_POLLS ?? 3) || 0);

export interface ArtifactSample {
	path: string;
	name: string;
	errorCount: number;
}

// All I/O lives here. Tolerate partial writes by skipping the sample — the
// next poll retries; a skipped sample also resets its streak, which is the
// conservative behavior while an artifact is mid-write.
export async function scan(): Promise<ArtifactSample[]> {
	const files = globSync("**/.monitor-demo/*.json", {
		cwd: ROOT,
		exclude: (p: string) => p.includes("node_modules"),
	});
	const current: ArtifactSample[] = [];
	for (const rel of files) {
		const path = join(ROOT, rel);
		try {
			const parsed = JSON.parse(await readFile(path, "utf8")) as { name?: string; errors?: unknown[] };
			current.push({
				path,
				name: typeof parsed.name === "string" ? parsed.name : rel,
				errorCount: Array.isArray(parsed.errors) ? parsed.errors.length : 0,
			});
		} catch {
			// partial write / parse error — skip and let the next poll retry
		}
	}
	return current;
}

// Pure judgement — exported so __test__/watch-example.test.ts can drive these
// through debounceStep without touching the filesystem.
export const handlers: PollSampleHandlers<ArtifactSample> = {
	key: (sample) => sample.path,
	fingerprint: (sample) => String(sample.errorCount),
	isClear: (sample) => sample.errorCount === 0,
	notify: (sample) => {
		const plural = sample.errorCount === 1 ? "" : "s";
		return `example-watcher: ${sample.name} has ${sample.errorCount} error${plural} — fix them, unless an agent is already working on ${sample.name}: if a build or fixing agent is in flight, let it finish before dispatching another rather than acting on this line immediately`;
	},
};

if (invokedDirectly(import.meta.url)) {
	await runPollMonitor({ scan, pollMs: POLL_MS, stablePolls: STABLE_POLLS, ...handlers });
}
