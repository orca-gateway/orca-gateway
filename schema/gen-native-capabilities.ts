#!/usr/bin/env bun
/**
 * Native SDK capability vector codegen (Epic 23b, task 23b.13).
 *
 * Emits sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift, the
 * Swift twin of sdk/lib/src/capabilities/generated.dart, plus the vector's
 * X-Orca-Caps-Hash computed with the engine's own `canonicalizeVector`, so
 * the Swift test (T1.6) can prove its canonicalisation hashes the same.
 *
 * Unlike the Flutter SDK, which draws every widget and runs every action, the
 * Swift SDK grows a slice at a time. Advertising a widget it cannot draw would
 * stop the server from degrading it, so the vector lists only what
 * sdk-swift/capabilities.json says the build implements:
 *   widgets       = capabilities.json widgets; each must exist in the manifest
 *                   with the "ios" target, or this script fails
 *   actionKinds   = capabilities.json actionKinds; each must be an engine kind
 *   valueKinds, transformKinds, boolExprOps = scraped from the engine, as the
 *                   Dart generator does (the Swift resolver ports all of them)
 *
 * Inputs (read-only, all under open-source/):
 *   schema/protocol.json, schema/widget-registry.json, engine/src/types/*.ts,
 *   sdk-swift/VERSION, sdk-swift/capabilities.json
 *
 * Run after gen-widget-registry.ts:  bun run schema/gen-native-capabilities.ts
 * CI (.github/workflows/schema.yml) regenerates and fails on drift.
 */

import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join, dirname, relative } from "path";
import { createHash } from "crypto";
import {
  OSS_ROOT,
  minus,
  readManifestWidgets,
  readProtocolVersion,
  scrapeEngineKinds,
} from "./caps-sources";
import { canonicalizeVector } from "../engine/src/core/capability-vector-cache";

const SWIFT_ROOT = join(OSS_ROOT, "sdk-swift");
const VERSION_FILE = join(SWIFT_ROOT, "VERSION");
const CAPABILITIES_JSON = join(SWIFT_ROOT, "capabilities.json");
const OUT_SWIFT = join(SWIFT_ROOT, "Sources/OrcaGatewayCore/Capabilities/Generated.swift");

const PLATFORM = "ios";

function readSwiftSemver(): string {
  const v = readFileSync(VERSION_FILE, "utf8").trim();
  if (!/^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/.test(v)) {
    throw new Error(`gen-native-capabilities: ${VERSION_FILE} must hold one semver, got "${v}"`);
  }
  return v;
}

interface ImplementedList {
  widgets: string[];
  actionKinds: string[];
}

function readImplemented(): ImplementedList {
  const raw = JSON.parse(readFileSync(CAPABILITIES_JSON, "utf8")) as Partial<ImplementedList>;
  if (!Array.isArray(raw.widgets) || !Array.isArray(raw.actionKinds)) {
    throw new Error(`gen-native-capabilities: ${CAPABILITIES_JSON} needs "widgets" and "actionKinds" arrays`);
  }
  return { widgets: raw.widgets, actionKinds: raw.actionKinds };
}

function sortUtf16(xs: Iterable<string>): string[] {
  // Array.prototype.sort compares UTF-16 code units, like the engine and Dart.
  return [...new Set(xs)].sort();
}

function swiftString(s: string): string {
  return JSON.stringify(s); // valid Swift for the identifiers involved
}

function swiftArray(name: string, values: readonly string[]): string {
  if (values.length === 0) return `    public static let ${name}: [String] = []\n`;
  const body = values.map((v) => `        ${swiftString(v)},`).join("\n");
  return `    public static let ${name}: [String] = [\n${body}\n    ]\n`;
}

/**
 * The vector the Swift build advertises and its X-Orca-Caps-Hash. Exported so
 * tools that talk to a server as the Swift SDK (the page recorder for the
 * Swift tests) send exactly what the SDK sends.
 */
export function swiftCapabilityVector() {
  const protocolVersion = readProtocolVersion();
  const sdkSemver = readSwiftSemver();
  const implemented = readImplemented();
  const engine = scrapeEngineKinds();

  // Widgets: listed, and drawable on iOS according to the manifest.
  const manifest = new Map(readManifestWidgets().map((w) => [w.type, w]));
  const problems: string[] = [];
  for (const type of implemented.widgets) {
    const entry = manifest.get(type);
    if (!entry) problems.push(`widget "${type}" is not in schema/widget-registry.json`);
    else if (!(entry.targets ?? []).includes(PLATFORM)) {
      problems.push(`widget "${type}" lacks the "${PLATFORM}" target in schema/widget-registry.json`);
    }
  }
  for (const kind of implemented.actionKinds) {
    if (!engine.actionKinds.has(kind)) problems.push(`action kind "${kind}" is not in engine/src/types/action.ts`);
  }
  if (problems.length > 0) {
    throw new Error(`gen-native-capabilities: sdk-swift/capabilities.json is invalid:\n  - ${problems.join("\n  - ")}`);
  }

  const vector = {
    protocolVersion,
    sdkSemver,
    widgets: sortUtf16(implemented.widgets),
    valueKinds: minus(engine.valueKinds, new Set()),
    actionKinds: sortUtf16(implemented.actionKinds),
    transformKinds: minus(engine.transformKinds, new Set()),
    boolExprOps: minus(engine.boolExprOps, new Set()),
  };
  const canonical = canonicalizeVector(vector);
  const capsHash = createHash("sha256").update(canonical).digest("hex");
  return { vector, capsHash };
}

function main() {
  const { vector, capsHash } = swiftCapabilityVector();
  const { protocolVersion, sdkSemver } = vector;

  const out =
    `// Code generated by open-source/schema/gen-native-capabilities.ts — DO NOT EDIT.\n` +
    `// Regenerate via: bun run schema/gen-native-capabilities.ts\n` +
    `//\n` +
    `// What this Swift build advertises to the server (X-Orca-Caps-Hash, and the\n` +
    `// full vector on a 412 retry). Widgets and action kinds come from\n` +
    `// sdk-swift/capabilities.json (each widget checked against the manifest's\n` +
    `// "${PLATFORM}" target); value kinds, transforms and BoolExpr ops are scraped\n` +
    `// from the engine like the Dart SDK's generated.dart.\n` +
    `//\n` +
    `// Sources (all under open-source/):\n` +
    `//   schema/protocol.json          → protocolVersion\n` +
    `//   sdk-swift/VERSION             → sdkSemver\n` +
    `//   sdk-swift/capabilities.json   → widgets, actionKinds\n` +
    `//   engine/src/types/value.ts     → valueKinds, transformKinds, boolExprOps\n\n` +
    `public enum GeneratedCapabilities {\n` +
    `    public static let protocolVersion = ${swiftString(protocolVersion)}\n` +
    `    public static let sdkSemver = ${swiftString(sdkSemver)}\n\n` +
    swiftArray("widgets", vector.widgets) +
    `\n` +
    swiftArray("valueKinds", vector.valueKinds) +
    `\n` +
    swiftArray("actionKinds", vector.actionKinds) +
    `\n` +
    swiftArray("transformKinds", vector.transformKinds) +
    `\n` +
    swiftArray("boolExprOps", vector.boolExprOps) +
    `\n` +
    `    /// sha256 of the engine's canonicalizeVector() of the vector above.\n` +
    `    public static let capsHash = ${swiftString(capsHash)}\n` +
    `}\n`;

  mkdirSync(dirname(OUT_SWIFT), { recursive: true });
  writeFileSync(OUT_SWIFT, out);

  console.log(`✔  native capabilities generated (${PLATFORM})`);
  console.log(`   protocol: ${protocolVersion} / sdk-swift: ${sdkSemver}`);
  console.log(
    `   widgets=${vector.widgets.length} values=${vector.valueKinds.length} ` +
      `actions=${vector.actionKinds.length} transforms=${vector.transformKinds.length} ` +
      `boolExprOps=${vector.boolExprOps.length}`,
  );
  console.log(`   hash: ${capsHash}`);
  console.log(`   → ${relative(process.cwd(), OUT_SWIFT)}`);
}

if (import.meta.main) main();
