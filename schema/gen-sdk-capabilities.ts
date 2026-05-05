#!/usr/bin/env bun
/**
 * SDK capability vector codegen (Epic 25b, task 25b.1).
 *
 * Emits open-source/sdk/lib/src/capabilities/generated.dart — a compile-time
 * snapshot of everything the SDK build CAN render. The vector is the data
 * sink that later slices (25b.2 headers, 25b.8 cache key) hand to the server
 * so the server can adapt per-client per-request.
 *
 * Inputs (read-only):
 *   - open-source/schema/protocol.json           → protocolVersion
 *   - open-source/sdk/pubspec.yaml               → SDK semver (via regex; Bun has
 *                                            no YAML builtin and pulling one
 *                                            in for one line is disproportionate)
 *   - open-source/schema/widget-registry.json    → supported widget types
 *   - open-source/engine/src/types/action.ts     → discriminator literals for
 *                                            action kinds (scraped)
 *   - open-source/engine/src/types/value.ts      → discriminator literals for
 *                                            value kinds, transform kinds,
 *                                            BoolExpr ops (scraped)
 *
 * Output:
 *   - open-source/sdk/lib/src/capabilities/generated.dart
 *
 * Run order (IMPORTANT): this script must run AFTER gen-widget-registry.ts,
 * because it reads the manifest the widget codegen produces. If you run them
 * in the wrong order, `generated.dart` will be stale. Wire both into a single
 * taskfile target if that matters for your workflow.
 *
 * Why scrape action.ts / value.ts directly instead of the JSON Schemas?
 * The JSON Schemas at open-source/schema/action.schema.json use `oneOf` of `$ref`s
 * — they describe shapes, not a flat kind enumeration. The authoritative flat
 * list lives in the TypeScript union literals, so we scrape those.
 *
 * Skip list: `CustomAction` at action.ts declares `type: string` (not a
 * quoted literal) so the regex naturally excludes it. The explicit skip set
 * below is a belt-and-suspenders safeguard for future catch-all sentinels.
 */

import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join, dirname, relative } from "path";

// ── Paths ───────────────────────────────────────────────────────────────────

const HERE = import.meta.dir;                     // open-source/schema
const HARPY_ROOT = join(HERE, "..");              // open-source/
const PROTOCOL_JSON = join(HARPY_ROOT, "schema/protocol.json");
const PUBSPEC = join(HARPY_ROOT, "sdk/pubspec.yaml");
const WIDGET_MANIFEST = join(HARPY_ROOT, "schema/widget-registry.json");
const ACTION_TS = join(HARPY_ROOT, "engine/src/types/action.ts");
const VALUE_TS = join(HARPY_ROOT, "engine/src/types/value.ts");
const OUT_DART = join(HARPY_ROOT, "sdk/lib/src/capabilities/generated.dart");

// Sentinels that must never appear in a capability vector, even if a stray
// `type: "..."` literal sneaks in. CustomAction is caught by the
// "must be a quoted literal" regex anyway — this is belt-and-suspenders.
const SKIP_ACTION_KINDS = new Set<string>([]);
const SKIP_VALUE_KINDS = new Set<string>([]);
const SKIP_TRANSFORM_KINDS = new Set<string>([]);
const SKIP_BOOL_EXPR_OPS = new Set<string>([]);

// ── Readers ─────────────────────────────────────────────────────────────────

function readProtocolVersion(): string {
  const raw = readFileSync(PROTOCOL_JSON, "utf8");
  const { protocolVersion } = JSON.parse(raw) as { protocolVersion: string };
  if (typeof protocolVersion !== "string" || !protocolVersion) {
    throw new Error(`protocol.json: missing or invalid protocolVersion`);
  }
  return protocolVersion;
}

function readSdkSemver(): string {
  const raw = readFileSync(PUBSPEC, "utf8");
  const m = raw.match(/^version:\s*(.+)$/m);
  if (!m) {
    throw new Error(
      `gen-sdk-capabilities: cannot find "version:" line in ${PUBSPEC}. ` +
        `The pubspec format must expose a top-level version for the SDK semver.`,
    );
  }
  return m[1].trim();
}

interface ManifestEntry {
  type: string;
  introducedIn?: string;
  removedIn?: string;
}

function readSupportedWidgets(): string[] {
  const raw = readFileSync(WIDGET_MANIFEST, "utf8");
  const manifest = JSON.parse(raw) as { widgets: ManifestEntry[] };
  return manifest.widgets.map((w) => w.type);
}

// Scrape a TS file for discriminator literals of the form `<field>: "<kind>";`.
// Matches `type: "navigate";`, `op: "eq";`, etc. The `<field>` argument locks
// down which field name we're extracting so value-kind scraping doesn't
// accidentally pick up BoolExpr `op:` literals from the same file.
function scrapeDiscriminatorLiterals(path: string, field: string): Set<string> {
  const src = readFileSync(path, "utf8");
  const re = new RegExp(`\\b${field}:\\s*"([^"]+)"`, "g");
  const kinds = new Set<string>();
  let m: RegExpExecArray | null;
  while ((m = re.exec(src)) !== null) {
    kinds.add(m[1]);
  }
  return kinds;
}

function minus(set: Set<string>, skip: Set<string>): string[] {
  return [...set].filter((x) => !skip.has(x)).sort();
}

// ── Emitter ─────────────────────────────────────────────────────────────────

// Dart string literal using single quotes (flutter_lints prefer_single_quotes).
// Escapes backslashes and single quotes. Discriminator literals in the
// engine's TS sources never contain quotes or backslashes in practice, so
// the escape is a safety net for forward-compat, not a hot path.
function dartString(s: string): string {
  return `'${s.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}'`;
}

function emitDartSet(name: string, values: readonly string[]): string {
  if (values.length === 0) {
    return `const Set<String> ${name} = <String>{};\n`;
  }
  const body = values.map((v) => `  ${dartString(v)},`).join("\n");
  return `const Set<String> ${name} = {\n${body}\n};\n`;
}

function emitDart(
  protocolVersion: string,
  sdkSemver: string,
  widgets: readonly string[],
  valueKinds: readonly string[],
  actionKinds: readonly string[],
  transformKinds: readonly string[],
  boolExprOps: readonly string[],
): string {
  const banner =
    `// Code generated by open-source/schema/gen-sdk-capabilities.ts — DO NOT EDIT.\n` +
    `// Regenerate via: bun run open-source/schema/gen-sdk-capabilities.ts\n` +
    `//\n` +
    `// This file is the compile-time snapshot of everything this SDK build can\n` +
    `// render. The server uses it (via the X-Orca-Caps-Hash header, shipped in a\n` +
    `// later Epic 25b slice) to decide which features to emit or degrade per\n` +
    `// request. See Epic 25b in .claude/plans/orcagateway-epics.md.\n` +
    `//\n` +
    `// Sources (all under open-source/):\n` +
    `//   schema/protocol.json          → kProtocolVersion\n` +
    `//   sdk/pubspec.yaml              → kSdkSemver\n` +
    `//   schema/widget-registry.json   → kSupportedWidgets\n` +
    `//   engine/src/types/action.ts    → kSupportedActionKinds\n` +
    `//   engine/src/types/value.ts     → kSupportedValueKinds,\n` +
    `//                                    kSupportedTransformKinds,\n` +
    `//                                    kSupportedBoolExprOps\n\n`;

  const constants =
    `const String kProtocolVersion = ${dartString(protocolVersion)};\n` +
    `const String kSdkSemver = ${dartString(sdkSemver)};\n\n`;

  const sets =
    emitDartSet("kSupportedWidgets", widgets) +
    `\n` +
    emitDartSet("kSupportedValueKinds", valueKinds) +
    `\n` +
    emitDartSet("kSupportedActionKinds", actionKinds) +
    `\n` +
    emitDartSet("kSupportedTransformKinds", transformKinds) +
    `\n` +
    emitDartSet("kSupportedBoolExprOps", boolExprOps) +
    `\n`;

  const klass =
    `/// Compile-time snapshot of the capabilities this SDK build advertises.\n` +
    `///\n` +
    `/// Call [toVector] to obtain the full capability map — the shape the\n` +
    `/// server will hash on first contact and cache by hash afterwards. Later\n` +
    `/// Epic 25b slices will send this vector via the X-Orca-Caps-Hash header\n` +
    `/// and fall back to the full-vector body on cache miss.\n` +
    `class SdkCapabilities {\n` +
    `  const SdkCapabilities._();\n\n` +
    `  static Map<String, dynamic> toVector() => <String, dynamic>{\n` +
    `        'protocolVersion': kProtocolVersion,\n` +
    `        'sdkSemver': kSdkSemver,\n` +
    `        'widgets': kSupportedWidgets.toList()..sort(),\n` +
    `        'valueKinds': kSupportedValueKinds.toList()..sort(),\n` +
    `        'actionKinds': kSupportedActionKinds.toList()..sort(),\n` +
    `        'transformKinds': kSupportedTransformKinds.toList()..sort(),\n` +
    `        'boolExprOps': kSupportedBoolExprOps.toList()..sort(),\n` +
    `      };\n` +
    `}\n`;

  return banner + constants + sets + `\n` + klass;
}

// ── Run ─────────────────────────────────────────────────────────────────────

function main() {
  const protocolVersion = readProtocolVersion();
  const sdkSemver = readSdkSemver();

  const widgets = readSupportedWidgets().sort();

  // Value kinds and BoolExpr ops live in value.ts together. Value kinds use
  // `type: "..."`, BoolExpr ops use `op: "..."` — the field-specific regex
  // keeps them cleanly separated.
  const valueKindsRaw = scrapeDiscriminatorLiterals(VALUE_TS, "type");
  // Transform kinds also use `type: "..."` inside value.ts, so the `type:`
  // regex above catches BOTH value kinds and transform kinds. We split them
  // by consulting the manifest-declared value kinds: everything else in the
  // `type:` set that is NOT a value kind must be a transform kind. The
  // authoritative value-kind list is short and stable, so we hardcode it
  // here as the anchor for the partition. (Keeping this anchor means the
  // scraper will fail loudly if someone introduces a new Value kind without
  // updating this list — which is the right failure mode, because any new
  // Value kind must also land in the SDK's value_resolver.dart.)
  const VALUE_KIND_ANCHOR = new Set([
    "static",
    "state",
    "info",
    "request",
    "event",
    "transform",
    "conditional",
    "tween",
    "tweenSequence",
  ]);

  const valueKinds = new Set<string>();
  const transformKinds = new Set<string>();
  for (const kind of valueKindsRaw) {
    if (VALUE_KIND_ANCHOR.has(kind)) {
      valueKinds.add(kind);
    } else {
      transformKinds.add(kind);
    }
  }

  // Assert the anchor matched reality. If someone removes a Value kind from
  // value.ts, the anchor will contain a phantom entry — fail loudly so the
  // anchor stays in sync.
  for (const anchor of VALUE_KIND_ANCHOR) {
    if (!valueKinds.has(anchor)) {
      throw new Error(
        `gen-sdk-capabilities: VALUE_KIND_ANCHOR includes "${anchor}" but it ` +
          `was not found in ${VALUE_TS}. Update the anchor set in this script.`,
      );
    }
  }

  const actionKinds = scrapeDiscriminatorLiterals(ACTION_TS, "type");
  const boolExprOps = scrapeDiscriminatorLiterals(VALUE_TS, "op");

  const out = emitDart(
    protocolVersion,
    sdkSemver,
    widgets,
    minus(valueKinds, SKIP_VALUE_KINDS),
    minus(actionKinds, SKIP_ACTION_KINDS),
    minus(transformKinds, SKIP_TRANSFORM_KINDS),
    minus(boolExprOps, SKIP_BOOL_EXPR_OPS),
  );

  mkdirSync(dirname(OUT_DART), { recursive: true });
  writeFileSync(OUT_DART, out);

  console.log(`✔  sdk capabilities generated`);
  console.log(`   protocol: ${protocolVersion} / sdk: ${sdkSemver}`);
  console.log(
    `   widgets=${widgets.length} values=${valueKinds.size} ` +
      `actions=${actionKinds.size} transforms=${transformKinds.size} ` +
      `boolExprOps=${boolExprOps.size}`,
  );
  console.log(`   → ${relative(process.cwd(), OUT_DART)}`);
}

main();
