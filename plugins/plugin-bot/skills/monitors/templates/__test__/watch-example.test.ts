// watch-example.test.ts — vitest template for a poll monitor. Copy to
// <plugin>/__test__/watch-<thing>.test.ts. Tests drive the monitor's exported
// handlers through the pure debounceStep — no filesystem, no polling loop.
import { describe, expect, it } from "vitest";
import type { DebounceState } from "../monitors/lib/poll-monitor.ts";
import { debounceStep } from "../monitors/lib/poll-monitor.ts";
import type { ArtifactSample } from "../monitors/watch-example.ts";
import { handlers } from "../monitors/watch-example.ts";

const STABLE_POLLS = 3;

function sample(errorCount: number, path = "/proj/.monitor-demo/app.json"): ArtifactSample {
	return { path, name: "app", errorCount };
}

function pollTimes(counts: number[], minStablePolls: number): { lines: string[]; state: DebounceState } {
	let state: DebounceState = new Map();
	const lines: string[] = [];
	for (const count of counts) {
		const result = debounceStep([sample(count)], state, minStablePolls, handlers);
		state = result.next;
		lines.push(...result.lines);
	}
	return { lines, state };
}

describe("watch-example handlers through debounceStep", () => {
	it("holds a non-zero count back until it is stable for minStablePolls", () => {
		const { lines } = pollTimes([2, 2, 2], STABLE_POLLS);
		expect(lines).toEqual([]);
	});

	it("notifies exactly once when a non-zero count settles", () => {
		const { lines } = pollTimes([2, 2, 2, 2, 2, 2], STABLE_POLLS);
		expect(lines).toHaveLength(1);
		expect(lines[0]).toContain("app has 2 errors");
	});

	it("never notifies while the count keeps changing", () => {
		const { lines } = pollTimes([1, 2, 3, 4, 5, 6, 7], STABLE_POLLS);
		expect(lines).toEqual([]);
	});

	it("re-fires after the sample clears and then regresses", () => {
		const { lines } = pollTimes([2, 2, 2, 2, 0, 2, 2, 2, 2], STABLE_POLLS);
		expect(lines).toHaveLength(2);
	});

	it("does not re-fire for the same stable value", () => {
		const { lines } = pollTimes([2, 2, 2, 2, 2, 2, 2, 2], STABLE_POLLS);
		expect(lines).toHaveLength(1);
	});

	it("fires immediately with minStablePolls 0 (--once mode)", () => {
		const { lines } = pollTimes([1], 0);
		expect(lines).toHaveLength(1);
		expect(lines[0]).toContain("app has 1 error");
	});

	it("stays silent while clear", () => {
		const { lines } = pollTimes([0, 0, 0, 0, 0], STABLE_POLLS);
		expect(lines).toEqual([]);
	});
});
