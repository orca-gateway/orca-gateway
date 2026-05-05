// Unit tests for the capability vector cache (Epic 25b slice 2).
//
// Scope:
//   - put / get round-trips
//   - hash stability across canonical-form-equivalent vectors
//   - hash mismatch detection (different arrays → different hashes)
//   - LRU eviction when maxEntries is exceeded
//   - TTL expiry via an injected clock
//   - isCapabilityVector() validates shape strictly

import { describe, test, expect } from "bun:test";
import {
  createInMemoryVectorCache,
  canonicalizeVector,
  isCapabilityVector,
} from "../src/core/capability-vector-cache";
import type { CapabilityVector } from "../src/types/context";

function makeVector(overrides: Partial<CapabilityVector> = {}): CapabilityVector {
  return {
    protocolVersion: "1.0.0",
    sdkSemver: "0.1.0",
    widgets: ["Column", "Text"],
    valueKinds: ["static", "state"],
    actionKinds: ["navigate"],
    transformKinds: ["toString"],
    boolExprOps: ["eq"],
    ...overrides,
  };
}

describe("createInMemoryVectorCache", () => {
  test("put + get round-trips", () => {
    const cache = createInMemoryVectorCache();
    const vector = makeVector();
    const hash = cache.computeHash(vector);
    cache.put(hash, vector);
    expect(cache.get(hash)).toEqual(vector);
  });

  test("get on an unknown hash returns undefined", () => {
    const cache = createInMemoryVectorCache();
    expect(cache.get("deadbeef".repeat(8))).toBeUndefined();
  });

  test("two canonically-equivalent vectors hash to the same value", () => {
    // Array order shouldn't matter — canonicalization sorts.
    const cache = createInMemoryVectorCache();
    const a = makeVector({ widgets: ["Text", "Column"] }); // reverse order
    const b = makeVector({ widgets: ["Column", "Text"] });
    expect(cache.computeHash(a)).toBe(cache.computeHash(b));
  });

  test("vectors differing in any field hash differently", () => {
    const cache = createInMemoryVectorCache();
    const base = makeVector();
    expect(cache.computeHash(base)).not.toBe(
      cache.computeHash(makeVector({ protocolVersion: "1.1.0" })),
    );
    expect(cache.computeHash(base)).not.toBe(
      cache.computeHash(makeVector({ widgets: ["Column"] })),
    );
    expect(cache.computeHash(base)).not.toBe(
      cache.computeHash(makeVector({ actionKinds: ["navigate", "setState"] })),
    );
  });

  test("LRU evicts the oldest entry when maxEntries is reached", () => {
    const cache = createInMemoryVectorCache({ maxEntries: 2 });
    const v1 = makeVector({ sdkSemver: "0.1.0" });
    const v2 = makeVector({ sdkSemver: "0.2.0" });
    const v3 = makeVector({ sdkSemver: "0.3.0" });
    const h1 = cache.computeHash(v1);
    const h2 = cache.computeHash(v2);
    const h3 = cache.computeHash(v3);
    cache.put(h1, v1);
    cache.put(h2, v2);
    expect(cache.size()).toBe(2);
    cache.put(h3, v3);
    expect(cache.size()).toBe(2);
    // v1 was inserted first → oldest → evicted.
    expect(cache.get(h1)).toBeUndefined();
    expect(cache.get(h2)).toEqual(v2);
    expect(cache.get(h3)).toEqual(v3);
  });

  test("get() refreshes LRU position — recently accessed survives eviction", () => {
    const cache = createInMemoryVectorCache({ maxEntries: 2 });
    const v1 = makeVector({ sdkSemver: "0.1.0" });
    const v2 = makeVector({ sdkSemver: "0.2.0" });
    const v3 = makeVector({ sdkSemver: "0.3.0" });
    const h1 = cache.computeHash(v1);
    const h2 = cache.computeHash(v2);
    const h3 = cache.computeHash(v3);
    cache.put(h1, v1);
    cache.put(h2, v2);
    // Touch v1 so it's the most recently used, not the oldest.
    cache.get(h1);
    // Now v2 is the oldest and should be evicted when we add v3.
    cache.put(h3, v3);
    expect(cache.get(h2)).toBeUndefined();
    expect(cache.get(h1)).toEqual(v1);
    expect(cache.get(h3)).toEqual(v3);
  });

  test("TTL expiry treats stale entries as misses", () => {
    let now = 1_000_000;
    const cache = createInMemoryVectorCache({
      ttlMs: 1000,
      now: () => now,
    });
    const vector = makeVector();
    const hash = cache.computeHash(vector);
    cache.put(hash, vector);
    expect(cache.get(hash)).toEqual(vector);
    // Advance 500ms — still valid.
    now += 500;
    expect(cache.get(hash)).toEqual(vector);
    // Advance past TTL — should miss.
    now += 600;
    expect(cache.get(hash)).toBeUndefined();
  });

  test("canonicalizeVector produces stable output for equal vectors", () => {
    const a = makeVector({ widgets: ["Text", "Column", "FallbackPrompt"] });
    const b = makeVector({ widgets: ["Column", "FallbackPrompt", "Text"] });
    expect(canonicalizeVector(a)).toBe(canonicalizeVector(b));
  });

  test("known pinned-hash: smoke test for canonicalization drift", () => {
    // Pinning a known hash guards against silent canonicalization changes
    // that would break the SDK⇄server handshake. The Dart test at
    // sdk/test/caps_canonicalization_test.dart has the matching assertion —
    // if both tests fail together on the same day, the algorithms drifted.
    const vector: CapabilityVector = {
      protocolVersion: "1.0.0",
      sdkSemver: "0.1.0",
      widgets: ["a", "b"],
      valueKinds: ["static"],
      actionKinds: [],
      transformKinds: [],
      boolExprOps: [],
    };
    const cache = createInMemoryVectorCache();
    // Computed once and pinned. If you regenerate, also update the Dart
    // test's pinned value below the same form or the two will drift.
    expect(cache.computeHash(vector)).toMatchSnapshot();
  });
});

describe("isCapabilityVector", () => {
  test("accepts a valid vector", () => {
    expect(isCapabilityVector(makeVector())).toBe(true);
  });

  test("rejects null / undefined / non-object", () => {
    expect(isCapabilityVector(null)).toBe(false);
    expect(isCapabilityVector(undefined)).toBe(false);
    expect(isCapabilityVector("string")).toBe(false);
    expect(isCapabilityVector(42)).toBe(false);
  });

  test("rejects missing required fields", () => {
    const valid = makeVector() as Record<string, unknown>;
    for (const key of Object.keys(valid)) {
      const broken = { ...valid };
      delete broken[key];
      expect(isCapabilityVector(broken)).toBe(false);
    }
  });

  test("rejects non-string array members", () => {
    const broken = { ...makeVector(), widgets: ["Text", 42 as unknown as string] };
    expect(isCapabilityVector(broken)).toBe(false);
  });

  test("rejects non-array values for array fields", () => {
    const broken = { ...makeVector(), actionKinds: "navigate" as unknown as string[] };
    expect(isCapabilityVector(broken)).toBe(false);
  });
});
