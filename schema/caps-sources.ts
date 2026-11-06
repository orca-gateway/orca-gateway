/**
 * Shared inputs of the capability-vector generators.
 *
 * Used by:
 *   - gen-sdk-capabilities.ts     → sdk/lib/src/capabilities/generated.dart (Flutter)
 *   - gen-native-capabilities.ts  → sdk-swift/.../Capabilities/Generated.swift (iOS)
 *
 * Both SDKs must agree on how kinds are scraped from the engine's TypeScript
 * unions, so the scraping lives here once.
 */

import { readFileSync } from "fs";
import { join } from "path";

const HERE = import.meta.dir; // open-source/schema
export const OSS_ROOT = join(HERE, "..");

export const PROTOCOL_JSON = join(OSS_ROOT, "schema/protocol.json");
export const WIDGET_MANIFEST = join(OSS_ROOT, "schema/widget-registry.json");
export const ACTION_TS = join(OSS_ROOT, "engine/src/types/action.ts");
export const VALUE_TS = join(OSS_ROOT, "engine/src/types/value.ts");

export function readProtocolVersion(): string {
  const raw = readFileSync(PROTOCOL_JSON, "utf8");
  const { protocolVersion } = JSON.parse(raw) as { protocolVersion: string };
  if (typeof protocolVersion !== "string" || !protocolVersion) {
    throw new Error(`protocol.json: missing or invalid protocolVersion`);
  }
  return protocolVersion;
}

export interface ManifestEntry {
  type: string;
  introducedIn?: string;
  removedIn?: string;
  targets?: string[];
}

export function readManifestWidgets(): ManifestEntry[] {
  const raw = readFileSync(WIDGET_MANIFEST, "utf8");
  const manifest = JSON.parse(raw) as { widgets: ManifestEntry[] };
  return manifest.widgets;
}

// Scrape a TS file for discriminator literals of the form `<field>: "<kind>";`.
// Matches `type: "navigate";`, `op: "eq";`, etc. The `<field>` argument locks
// down which field name we're extracting so value-kind scraping doesn't
// accidentally pick up BoolExpr `op:` literals from the same file.
export function scrapeDiscriminatorLiterals(path: string, field: string): Set<string> {
  const src = readFileSync(path, "utf8");
  const re = new RegExp(`\\b${field}:\\s*"([^"]+)"`, "g");
  const kinds = new Set<string>();
  let m: RegExpExecArray | null;
  while ((m = re.exec(src)) !== null) {
    kinds.add(m[1]);
  }
  return kinds;
}

// Value kinds and transform kinds both use `type: "..."` inside value.ts, so
// the scrape returns them together. The authoritative value-kind list is short
// and stable, so it is pinned here as the anchor for the partition:
// everything else in the `type:` set is a transform kind. A new Value kind
// must update this anchor (and every SDK's resolver), which is the right
// failure mode.
export const VALUE_KIND_ANCHOR = new Set([
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

export interface EngineKinds {
  valueKinds: Set<string>;
  transformKinds: Set<string>;
  actionKinds: Set<string>;
  boolExprOps: Set<string>;
}

export function scrapeEngineKinds(): EngineKinds {
  const valueKindsRaw = scrapeDiscriminatorLiterals(VALUE_TS, "type");
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
        `caps-sources: VALUE_KIND_ANCHOR includes "${anchor}" but it ` +
          `was not found in ${VALUE_TS}. Update the anchor set in this file.`,
      );
    }
  }

  return {
    valueKinds,
    transformKinds,
    actionKinds: scrapeDiscriminatorLiterals(ACTION_TS, "type"),
    boolExprOps: scrapeDiscriminatorLiterals(VALUE_TS, "op"),
  };
}

export function minus(set: Set<string>, skip: Set<string>): string[] {
  return [...set].filter((x) => !skip.has(x)).sort();
}
