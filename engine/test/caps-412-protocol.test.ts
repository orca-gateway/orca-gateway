// End-to-end test for the capability 412 retry protocol (Epic 25b slice 2).
//
// Boots a real Engine on an ephemeral port, registers a single-page app,
// and exercises the dance between the SDK's two call shapes and the server:
//
//   A. Request with no caps headers         → 200 (unversioned, no filter)
//   B. Request with unknown caps hash       → 412 caps_vector_unknown
//   C. Retry with _orcaCapsVector in body   → 200 + vector cached
//   D. Later request with same hash (hit)   → 200 (no retry needed)
//   E. Retry body with mismatched hash      → 412 (refused)

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import {
  App,
  Engine,
  Flow,
  PageDefinition,
  canonicalizeVector,
  createInMemoryVectorCache,
} from "../src/core";
import type { CapabilityVector } from "../src/types/context";
import { Text } from "../src/components";
import { createHash } from "crypto";

type BunServer = import("bun").Server<undefined>;

// Inline sha256-hex matching the vector cache's internal algorithm — we use
// it here so the test controls what hash it claims to have without depending
// on the server's own computation.
function sha256Hex(input: string): string {
  return createHash("sha256").update(input).digest("hex");
}

const TEST_VECTOR: CapabilityVector = {
  protocolVersion: "1.0.0",
  sdkSemver: "0.1.0",
  widgets: ["Text", "FallbackPrompt"],
  valueKinds: ["static"],
  actionKinds: [],
  transformKinds: [],
  boolExprOps: [],
};

const TEST_VECTOR_HASH = sha256Hex(canonicalizeVector(TEST_VECTOR));

let server: BunServer;
let engine: Engine;
let port: number;

beforeAll(async () => {
  const homePage = PageDefinition.create({
    id: "home",
    title: "Home",
    render: () => Text.new({ data: "hi" }),
  });
  const flow = Flow.create({
    name: "main",
    routes: [{ path: "home", page: homePage }],
  });
  const app = App.create({
    id: "capstest",
    name: "Caps Test",
    flows: [flow],
  });

  engine = new Engine();
  engine.registerApp(app);
  // Use port 0 → Bun picks an ephemeral free port, avoiding collisions with
  // other test files that bind port 8080.
  server = await engine.start({ port: 0, cache: false });
  port = server.port;
});

afterAll(() => {
  engine.stop();
});

function url(path = "home"): string {
  return `http://localhost:${port}/api/v1/app/capstest/page/${path}`;
}

describe("capability negotiation 412 protocol (Epic 25b slice 2)", () => {
  test("A. no caps headers → 200 (unversioned client path)", async () => {
    const res = await fetch(url());
    expect(res.status).toBe(200);
    const body = (await res.json()) as { components: unknown[] };
    expect(Array.isArray(body.components)).toBe(true);
  });

  test("B. unknown caps hash → 412 with caps_vector_unknown", async () => {
    const unknownHash = "deadbeef".repeat(8); // sha256 is 64 chars
    const res = await fetch(url(), {
      headers: {
        "x-orca-sdk-version": "0.1.0",
        "x-orca-caps-hash": unknownHash,
      },
    });
    expect(res.status).toBe(412);
    const body = (await res.json()) as { error: string; hash: string };
    expect(body.error).toBe("caps_vector_unknown");
    expect(body.hash).toBe(unknownHash);
  });

  test("C. retry with _orcaCapsVector body → 200 and vector cached", async () => {
    // Confirm the engine's cache doesn't already have our hash. This is
    // isolated from test B because B used a different (arbitrary) hash.
    expect(engine.getVectorCache().get(TEST_VECTOR_HASH)).toBeUndefined();

    const res = await fetch(url(), {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-orca-sdk-version": "0.1.0",
        "x-orca-caps-hash": TEST_VECTOR_HASH,
      },
      body: JSON.stringify({ _orcaCapsVector: TEST_VECTOR }),
    });
    expect(res.status).toBe(200);

    // After a successful retry, the engine must have stashed the vector so
    // later requests with the same hash hit the fast path.
    expect(engine.getVectorCache().get(TEST_VECTOR_HASH)).toEqual(TEST_VECTOR);
  });

  test("D. later request with same hash hits fast path (200, no retry)", async () => {
    // Hash is now warm in the cache from test C. A plain GET with just the
    // hash header should succeed without a body.
    const res = await fetch(url(), {
      headers: {
        "x-orca-sdk-version": "0.1.0",
        "x-orca-caps-hash": TEST_VECTOR_HASH,
      },
    });
    expect(res.status).toBe(200);
  });

  test("E. retry with mismatched hash is refused (still 412)", async () => {
    // Client sends the correct vector body but claims a different hash.
    // The server MUST verify and refuse — otherwise a broken client could
    // poison the cache for every other client sharing the claimed hash.
    const wrongHash = "cafebabe".repeat(8);
    // Confirm the wrong hash is not in cache.
    expect(engine.getVectorCache().get(wrongHash)).toBeUndefined();
    const res = await fetch(url(), {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-orca-sdk-version": "0.1.0",
        "x-orca-caps-hash": wrongHash,
      },
      body: JSON.stringify({ _orcaCapsVector: TEST_VECTOR }),
    });
    expect(res.status).toBe(412);
    // And crucially: the cache must NOT have been updated with this vector
    // under the wrong hash.
    expect(engine.getVectorCache().get(wrongHash)).toBeUndefined();
  });
});

describe("vector cache canonicalization (Epic 25b slice 2)", () => {
  test("canonicalizeVector is deterministic across equal-but-reordered vectors", () => {
    const v1: CapabilityVector = {
      ...TEST_VECTOR,
      widgets: ["FallbackPrompt", "Text"], // reversed
    };
    const v2: CapabilityVector = {
      ...TEST_VECTOR,
      widgets: ["Text", "FallbackPrompt"],
    };
    expect(canonicalizeVector(v1)).toBe(canonicalizeVector(v2));
  });

  test("the cache's computeHash matches an independent sha256 of the canonical form", () => {
    // Sanity check that computeHash and canonicalizeVector are consistent
    // with each other — if someone "optimizes" one without the other, the
    // 412 retry protocol breaks.
    const cache = createInMemoryVectorCache();
    expect(cache.computeHash(TEST_VECTOR)).toBe(
      sha256Hex(canonicalizeVector(TEST_VECTOR)),
    );
  });
});
