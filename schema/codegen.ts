#!/usr/bin/env bun
/**
 * Umbrella codegen runner.
 *
 * Schema-driven artifacts in this repo are produced by three scripts that
 * MUST run in a specific order:
 *
 *   1. gen-widget-registry.ts   — scans engine/src/components/ and emits
 *                                 engine/src/core/widget-registry-gen.ts
 *                                 plus schema/widget-registry.json.
 *   2. gen-sdk-capabilities.ts  — reads the manifest produced by step 1,
 *                                 plus schema/protocol.json and the action /
 *                                 value type files, and emits
 *                                 sdk/lib/src/capabilities/generated.dart.
 *   3. gen-native-capabilities.ts — reads the same manifest plus
 *                                 sdk-swift/VERSION and capabilities.json,
 *                                 and emits the Swift capability vector
 *                                 (sdk-swift/.../Capabilities/Generated.swift).
 *
 * Steps 2 and 3 read what step 1 writes, so order is load-bearing — running
 * them out of order leaves the SDK capability vectors stale.
 *
 * Run from the repo root:
 *
 *   bun run schema/codegen.ts
 */
import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

const steps = [
  resolve(here, "gen-widget-registry.ts"),
  resolve(here, "gen-sdk-capabilities.ts"),
  resolve(here, "gen-native-capabilities.ts"),
];

for (const script of steps) {
  console.log(`→ bun run ${script}`);
  const result = spawnSync("bun", ["run", script], { stdio: "inherit" });
  if (result.status !== 0) {
    console.error(`✗ ${script} exited with status ${result.status}`);
    process.exit(result.status ?? 1);
  }
}

console.log("✓ codegen complete");
