// Capability vector cache (Epic 25b slice 2).
//
// Per-engine LRU of capability vectors keyed by their canonical sha256 hash.
// The cache is the server-side anchor of the 412 retry protocol:
//
//   1. Every SDK request carries an X-Orca-Caps-Hash header.
//   2. Engine looks the hash up in this cache.
//   3. Hit  → attach the vector to RequestInfo.clientCapabilities.vector and
//             proceed with the pipeline (including the capability filter).
//   4. Miss → if the request body carries `_orcaCapsVector`, hash it,
//             `put()` it into the cache, and continue. Otherwise return
//             HTTP 412 `{error: "caps_vector_unknown", hash}` — the SDK will
//             retry once with the full vector in the body.
//
// Why not SQLite/Redis? Vectors are small (~5KB), the cache is per-pod, and
// the miss path (single 412 round-trip) is already cheap. Persistence buys
// nothing the retry path doesn't already handle, and it would introduce a
// cross-pod consistency concern that's not worth the surface area.
//
// Canonicalization: hashes are computed over a deterministic JSON shape
// (keys in a fixed order, arrays lex-sorted). This MUST match the Dart SDK's
// hash computation bit-for-bit — the shared algorithm is documented in
// `canonicalizeVector()` below, and `orca_client.dart` mirrors it.

import { createHash } from "crypto";
import type { CapabilityVector } from "../types/context";

export interface CapabilityVectorCache {
  /** Look up a vector by its canonical hash. Returns undefined on miss or
   *  if the cached entry has expired. */
  get(hash: string): CapabilityVector | undefined;

  /** Insert a vector under its canonical hash. Idempotent: calling put with
   *  the same hash/vector pair just refreshes the TTL and LRU position. */
  put(hash: string, vector: CapabilityVector): void;

  /** SHA-256 of the canonical serialization of `vector`. The result is a
   *  lowercase hex string (64 chars). This method is exposed so callers can
   *  verify a client-sent hash matches the vector body before accepting it,
   *  which guards against a broken client that sends a stale hash alongside
   *  a newer vector. */
  computeHash(vector: CapabilityVector): string;

  /** Test-only. Returns the current entry count. */
  size(): number;
}

export interface CapabilityVectorCacheOptions {
  /** Maximum number of distinct vectors to retain. LRU eviction when full.
   *  Default 1000 — enough for ~50 distinct SDK versions × 20 tenant apps on
   *  a single pod before churn starts. */
  maxEntries?: number;

  /** Time-to-live for each entry in milliseconds. Default 24 hours.
   *  Expired entries are treated as misses on the next get(). */
  ttlMs?: number;

  /** Injected clock for tests. Defaults to `Date.now`. */
  now?: () => number;
}

interface Entry {
  vector: CapabilityVector;
  insertedAt: number;
}

export function createInMemoryVectorCache(
  opts: CapabilityVectorCacheOptions = {},
): CapabilityVectorCache {
  const maxEntries = opts.maxEntries ?? 1000;
  const ttlMs = opts.ttlMs ?? 24 * 60 * 60 * 1000;
  const now = opts.now ?? (() => Date.now());

  // JS Maps iterate in insertion order — re-inserting a key moves it to the
  // end, which gives us an O(1) LRU for free. On eviction we drop the oldest
  // entry (the first key in iteration order).
  const entries = new Map<string, Entry>();

  return {
    get(hash: string): CapabilityVector | undefined {
      const entry = entries.get(hash);
      if (!entry) return undefined;
      if (now() - entry.insertedAt > ttlMs) {
        entries.delete(hash);
        return undefined;
      }
      // Refresh LRU position.
      entries.delete(hash);
      entries.set(hash, entry);
      return entry.vector;
    },

    put(hash: string, vector: CapabilityVector): void {
      if (entries.has(hash)) {
        entries.delete(hash);
      } else if (entries.size >= maxEntries) {
        // Drop oldest — the first key in insertion order.
        const oldest = entries.keys().next().value;
        if (oldest !== undefined) entries.delete(oldest);
      }
      entries.set(hash, { vector, insertedAt: now() });
    },

    computeHash(vector: CapabilityVector): string {
      return sha256Hex(canonicalizeVector(vector));
    },

    size(): number {
      return entries.size;
    },
  };
}

/**
 * Canonical serialization of a CapabilityVector.
 *
 * Rules (MUST match sdk/lib/src/client/orca_client.dart):
 *  1. Keys appear in exactly this order: protocolVersion, sdkSemver, widgets,
 *     valueKinds, actionKinds, transformKinds, boolExprOps.
 *  2. All arrays are lex-sorted ascending.
 *  3. JSON.stringify with no whitespace (default Node behavior).
 *
 * A one-byte divergence between client and server canonicalization breaks
 * every request permanently (hash-only requests perma-412-retry). Both sides
 * have a pinned-hash test that would fail on the same day if the algorithms
 * drift — see `capability-vector-cache.test.ts` and `caps_canonicalization_test.dart`.
 */
export function canonicalizeVector(vector: CapabilityVector): string {
  const canonical = {
    protocolVersion: vector.protocolVersion,
    sdkSemver: vector.sdkSemver,
    widgets: [...vector.widgets].sort(),
    valueKinds: [...vector.valueKinds].sort(),
    actionKinds: [...vector.actionKinds].sort(),
    transformKinds: [...vector.transformKinds].sort(),
    boolExprOps: [...vector.boolExprOps].sort(),
  };
  return JSON.stringify(canonical);
}

function sha256Hex(input: string): string {
  return createHash("sha256").update(input).digest("hex");
}

/**
 * Validate a parsed JSON blob looks like a CapabilityVector. Used when the
 * client retries with `_orcaCapsVector` in the body — we refuse to put bad
 * shapes into the cache because that could let a malformed client poison
 * the cache for every subsequent client sharing its hash.
 */
export function isCapabilityVector(value: unknown): value is CapabilityVector {
  if (!value || typeof value !== "object") return false;
  const v = value as Record<string, unknown>;
  if (typeof v.protocolVersion !== "string") return false;
  if (typeof v.sdkSemver !== "string") return false;
  const stringArrays: (keyof CapabilityVector)[] = [
    "widgets",
    "valueKinds",
    "actionKinds",
    "transformKinds",
    "boolExprOps",
  ];
  for (const key of stringArrays) {
    const arr = v[key];
    if (!Array.isArray(arr)) return false;
    for (const item of arr) {
      if (typeof item !== "string") return false;
    }
  }
  return true;
}
