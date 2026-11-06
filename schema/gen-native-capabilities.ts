#!/usr/bin/env bun
/**
 * Native SDK capability vector codegen (Epic 23b, tasks 23b.13 and 23b.27a).
 *
 * Emits, for each native SDK, the twin of sdk/lib/src/capabilities/generated.dart
 * plus the vector's X-Orca-Caps-Hash computed with the engine's own
 * `canonicalizeVector`, so each SDK's test (T1.6, T6.1.6) can prove its
 * canonicalisation hashes the same:
 *   sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift  (ios)
 *   sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt  (android)
 *
 * Unlike the Flutter SDK, which draws every widget and runs every action, the
 * native SDKs grow a slice at a time. Advertising a widget an SDK cannot draw
 * would stop the server from degrading it, so each vector lists only what that
 * SDK's capabilities.json says the build implements:
 *   widgets       = capabilities.json widgets; each must exist in the manifest
 *                   with the SDK's platform target, or this script fails
 *   actionKinds   = capabilities.json actionKinds; each must be an engine kind
 *   valueKinds, transformKinds, boolExprOps = scraped from the engine, as the
 *                   Dart generator does (both native resolvers port all of them)
 *
 * Inputs (read-only, all under open-source/):
 *   schema/protocol.json, schema/widget-registry.json, engine/src/types/*.ts,
 *   sdk-swift/VERSION, sdk-swift/capabilities.json,
 *   sdk-kotlin/VERSION, sdk-kotlin/capabilities.json
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

interface NativeSdk {
  /** Directory under open-source/, also the name in error messages. */
  dir: string;
  /** The widget-registry target a listed widget must carry. */
  platform: "ios" | "android";
  /** The generated file, under `dir`. */
  out: string;
  render: (vector: NativeVector, capsHash: string) => string;
}

interface NativeVector {
  protocolVersion: string;
  sdkSemver: string;
  widgets: string[];
  valueKinds: string[];
  actionKinds: string[];
  transformKinds: string[];
  boolExprOps: string[];
}

function readSemver(sdk: NativeSdk): string {
  const file = join(OSS_ROOT, sdk.dir, "VERSION");
  const v = readFileSync(file, "utf8").trim();
  if (!/^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/.test(v)) {
    throw new Error(`gen-native-capabilities: ${file} must hold one semver, got "${v}"`);
  }
  return v;
}

interface ImplementedList {
  widgets: string[];
  actionKinds: string[];
}

function readImplemented(sdk: NativeSdk): ImplementedList {
  const file = join(OSS_ROOT, sdk.dir, "capabilities.json");
  const raw = JSON.parse(readFileSync(file, "utf8")) as Partial<ImplementedList>;
  if (!Array.isArray(raw.widgets) || !Array.isArray(raw.actionKinds)) {
    throw new Error(`gen-native-capabilities: ${file} needs "widgets" and "actionKinds" arrays`);
  }
  return { widgets: raw.widgets, actionKinds: raw.actionKinds };
}

function sortUtf16(xs: Iterable<string>): string[] {
  // Array.prototype.sort compares UTF-16 code units, like the engine and Dart.
  return [...new Set(xs)].sort();
}

/**
 * The vector a native SDK advertises and its X-Orca-Caps-Hash. Exported (as
 * swiftCapabilityVector and kotlinCapabilityVector) so tools that talk to a
 * server as that SDK (the page recorder for the SDK tests) send exactly what
 * the SDK sends.
 */
function nativeCapabilityVector(sdk: NativeSdk): { vector: NativeVector; capsHash: string } {
  const protocolVersion = readProtocolVersion();
  const sdkSemver = readSemver(sdk);
  const implemented = readImplemented(sdk);
  const engine = scrapeEngineKinds();

  // Widgets: listed, and drawable on the platform according to the manifest.
  const manifest = new Map(readManifestWidgets().map((w) => [w.type, w]));
  const problems: string[] = [];
  for (const type of implemented.widgets) {
    const entry = manifest.get(type);
    if (!entry) problems.push(`widget "${type}" is not in schema/widget-registry.json`);
    else if (!(entry.targets ?? []).includes(sdk.platform)) {
      problems.push(`widget "${type}" lacks the "${sdk.platform}" target in schema/widget-registry.json`);
    }
  }
  for (const kind of implemented.actionKinds) {
    if (!engine.actionKinds.has(kind)) problems.push(`action kind "${kind}" is not in engine/src/types/action.ts`);
  }
  if (problems.length > 0) {
    throw new Error(`gen-native-capabilities: ${sdk.dir}/capabilities.json is invalid:\n  - ${problems.join("\n  - ")}`);
  }

  const vector: NativeVector = {
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

// ─── Swift ──────────────────────────────────────────────────────────────────

function swiftString(s: string): string {
  return JSON.stringify(s); // valid Swift for the identifiers involved
}

function swiftArray(name: string, values: readonly string[]): string {
  if (values.length === 0) return `    public static let ${name}: [String] = []\n`;
  const body = values.map((v) => `        ${swiftString(v)},`).join("\n");
  return `    public static let ${name}: [String] = [\n${body}\n    ]\n`;
}

function renderSwift(vector: NativeVector, capsHash: string): string {
  const { protocolVersion, sdkSemver } = vector;
  return (
    `// Code generated by open-source/schema/gen-native-capabilities.ts — DO NOT EDIT.\n` +
    `// Regenerate via: bun run schema/gen-native-capabilities.ts\n` +
    `//\n` +
    `// What this Swift build advertises to the server (X-Orca-Caps-Hash, and the\n` +
    `// full vector on a 412 retry). Widgets and action kinds come from\n` +
    `// sdk-swift/capabilities.json (each widget checked against the manifest's\n` +
    `// "ios" target); value kinds, transforms and BoolExpr ops are scraped\n` +
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
    `}\n`
  );
}

// ─── Kotlin ─────────────────────────────────────────────────────────────────

function kotlinString(s: string): string {
  // JSON escapes are valid Kotlin escapes; `$` would start a template.
  return JSON.stringify(s).replace(/\$/g, "\\$");
}

function kotlinList(name: string, values: readonly string[]): string {
  if (values.length === 0) return `    public val ${name}: List<String> = emptyList()\n`;
  const body = values.map((v) => `        ${kotlinString(v)},`).join("\n");
  return `    public val ${name}: List<String> = listOf(\n${body}\n    )\n`;
}

function renderKotlin(vector: NativeVector, capsHash: string): string {
  const { protocolVersion, sdkSemver } = vector;
  return (
    `// Code generated by open-source/schema/gen-native-capabilities.ts — DO NOT EDIT.\n` +
    `// Regenerate via: bun run schema/gen-native-capabilities.ts\n` +
    `//\n` +
    `// What this Kotlin build advertises to the server (X-Orca-Caps-Hash, and the\n` +
    `// full vector on a 412 retry). Widgets and action kinds come from\n` +
    `// sdk-kotlin/capabilities.json (each widget checked against the manifest's\n` +
    `// "android" target); value kinds, transforms and BoolExpr ops are scraped\n` +
    `// from the engine like the Dart SDK's generated.dart.\n` +
    `//\n` +
    `// Sources (all under open-source/):\n` +
    `//   schema/protocol.json          → protocolVersion\n` +
    `//   sdk-kotlin/VERSION            → sdkSemver\n` +
    `//   sdk-kotlin/capabilities.json  → widgets, actionKinds\n` +
    `//   engine/src/types/value.ts     → valueKinds, transformKinds, boolExprOps\n\n` +
    `package com.orcagateway.core.capabilities\n\n` +
    `public object GeneratedCapabilities {\n` +
    `    public const val protocolVersion: String = ${kotlinString(protocolVersion)}\n` +
    `    public const val sdkSemver: String = ${kotlinString(sdkSemver)}\n\n` +
    kotlinList("widgets", vector.widgets) +
    `\n` +
    kotlinList("valueKinds", vector.valueKinds) +
    `\n` +
    kotlinList("actionKinds", vector.actionKinds) +
    `\n` +
    kotlinList("transformKinds", vector.transformKinds) +
    `\n` +
    kotlinList("boolExprOps", vector.boolExprOps) +
    `\n` +
    `    /** sha256 of the engine's canonicalizeVector() of the vector above. */\n` +
    `    public const val capsHash: String = ${kotlinString(capsHash)}\n` +
    `}\n`
  );
}

// ─── Targets ────────────────────────────────────────────────────────────────

const SWIFT: NativeSdk = {
  dir: "sdk-swift",
  platform: "ios",
  out: "Sources/OrcaGatewayCore/Capabilities/Generated.swift",
  render: renderSwift,
};

const KOTLIN: NativeSdk = {
  dir: "sdk-kotlin",
  platform: "android",
  out: "core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt",
  render: renderKotlin,
};

export function swiftCapabilityVector() {
  return nativeCapabilityVector(SWIFT);
}

export function kotlinCapabilityVector() {
  return nativeCapabilityVector(KOTLIN);
}

function main() {
  for (const sdk of [SWIFT, KOTLIN]) {
    const { vector, capsHash } = nativeCapabilityVector(sdk);
    const out = join(OSS_ROOT, sdk.dir, sdk.out);
    mkdirSync(dirname(out), { recursive: true });
    writeFileSync(out, sdk.render(vector, capsHash));

    console.log(`✔  native capabilities generated (${sdk.platform})`);
    console.log(`   protocol: ${vector.protocolVersion} / ${sdk.dir}: ${vector.sdkSemver}`);
    console.log(
      `   widgets=${vector.widgets.length} values=${vector.valueKinds.length} ` +
        `actions=${vector.actionKinds.length} transforms=${vector.transformKinds.length} ` +
        `boolExprOps=${vector.boolExprOps.length}`,
    );
    console.log(`   hash: ${capsHash}`);
    console.log(`   → ${relative(process.cwd(), out)}`);
  }
}

if (import.meta.main) main();
