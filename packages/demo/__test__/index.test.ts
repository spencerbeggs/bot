import { describe, expect, it } from "vitest";
import type { Foo } from "../src/index.ts";
import { Bar } from "../src/index.ts";

describe("Bar class", () => {
	it("should create an instance of Bar", () => {
		const bar = new Bar();
		const result: Foo = bar.qux();
		expect(result).toEqual({ baz: 42 });
	});
});
