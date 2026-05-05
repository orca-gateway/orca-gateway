// Conformance suite for the JSON tree encoder.
//
// Loads every JSON fixture in schema/fixtures/render/ and runs it
// through encodeJsonTree(). Each fixture carries its own expected output,
// so this file locks down the engine's render spec for the JSON-tree input
// path: Value resolution, Transform evaluation, BoolExpr evaluation, watch
// extraction, child ordering, slot injection, and template variable
// interpolation.
//
// Fixtures double as the engine's behavioral documentation — every new
// feature (a new Value kind, a new Transform, a new Action, a new widget
// category, a new interpolation rule) should land with a fixture here that
// pins its resolved-output shape. That way any future implementation that
// consumes the same manifest (alternative language ports, plugin pipelines,
// authoring tools) can run the same suite and prove it agrees on semantics.

import { test, expect } from "bun:test";
import { readdirSync, readFileSync } from "fs";
import { join } from "path";
import { encodeJsonTree, type JsonTreeNode, type JsonTreeEncoderOptions } from "../src/core/json-tree-encoder";
import type { WidgetRegistryEntry } from "../src/core/widget-registry-gen";
import type { ValueResolverContext } from "../src/core/value-resolver";
import type { CapabilityVector } from "../src/types/context";
import { filterByCapabilities } from "../src/core/capability-filter";
import {
  createStaticPolicyResolver,
  type FallbackPolicyConfig,
} from "../src/core/fallback-policy";

interface Fixture {
  name: string;
  description: string;
  input: JsonTreeNode;
  context: ValueResolverContext;
  expected: unknown[];
  /**
   * Engines to skip this fixture on (Epic 25b slice 2). Used when a fixture
   * exercises a feature a given engine doesn't yet understand — the Go port
   * skips caps-aware fixtures until slice 3 lands its mirror. Each test
   * runner respects its own engine name; unknown names in the list are
   * silently ignored.
   */
  skipEngines?: string[];
  /**
   * Capability vector to apply via `filterByCapabilities` between the
   * encoder and the expected assertion (Epic 25b slice 2). When absent,
   * the fixture runs through the encoder alone (pre-25b behavior).
   */
  clientCapabilities?: CapabilityVector;
  /** Policy config for fixtures that exercise the capability filter. */
  fallbackPolicy?: FallbackPolicyConfig;
  /** Plugin widget definitions to merge into the registry (Epic 26b). */
  pluginWidgets?: WidgetRegistryEntry[];
}

const ENGINE_NAME = "bun";

const FIXTURES_DIR = join(import.meta.dir, "..", "..", "schema", "fixtures", "render");

const files = readdirSync(FIXTURES_DIR)
  .filter((f) => f.endsWith(".json"))
  .sort();

if (files.length === 0) {
  throw new Error(`no fixtures in ${FIXTURES_DIR}`);
}

for (const file of files) {
  const raw = readFileSync(join(FIXTURES_DIR, file), "utf8");
  const fx: Fixture = JSON.parse(raw);

  if (fx.skipEngines?.includes(ENGINE_NAME)) {
    test.skip(`conformance: ${file.replace(/\.json$/, "")} (skipped on ${ENGINE_NAME})`, () => {});
    continue;
  }

  test(`conformance: ${file.replace(/\.json$/, "")}`, () => {
    // Epic 26b: if the fixture carries plugin widget definitions, build an
    // extraWidgets map so the encoder recognises those types. Widgets with
    // removedIn set are excluded (same as plugin_loader.go in the Go side).
    let options: JsonTreeEncoderOptions | undefined;
    if (fx.pluginWidgets && fx.pluginWidgets.length > 0) {
      const extraWidgets: Record<string, WidgetRegistryEntry> = {};
      for (const pw of fx.pluginWidgets) {
        if (!pw.removedIn) {
          extraWidgets[pw.type] = pw;
        }
      }
      options = { extraWidgets };
    }

    let got = encodeJsonTree(fx.input, fx.context, options);

    // Epic 25b slice 2: if the fixture carries a capability vector, run the
    // filter stage between the encoder and the assertion. Fixtures that
    // exercise the pre-25b encoder path never set these fields and run
    // unchanged — the new fields are purely opt-in.
    if (fx.clientCapabilities) {
      const resolver = createStaticPolicyResolver(fx.fallbackPolicy ?? {});
      const filtered = filterByCapabilities(got, fx.clientCapabilities, resolver);
      got = filtered.components;
    }

    // Round-trip through JSON so the deep-equal ignores object-key ordering
    // (which isn't contractual — fixtures encode logical structure, not
    // byte layout).
    const normalize = (v: unknown) => JSON.parse(JSON.stringify(v));
    expect(normalize(got)).toEqual(normalize(fx.expected));
  });
}
