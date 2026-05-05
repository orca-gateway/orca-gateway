// Frozen-widget contract test (Epic 25b, task 25b.5).
//
// Some widgets carry a *frozen* prop-shape contract: their `getProps()` key
// set, introducedIn version, and logical types CANNOT change across protocol
// versions. The canonical example is FallbackPrompt, which must render
// identically on every SDK version that ever shipped so the server always
// has a universal "something needs your attention" channel.
//
// This test enforces the contract by diffing two things:
//
//   1. The generated widget-registry.json — does every frozen-golden entry
//      show up in the manifest with `frozen: true` and the expected
//      introducedIn?
//
//   2. The runtime widget class — does instantiating the widget with ALL
//      props (required + optional) produce a `getProps()` key set that
//      exactly matches the golden?
//
// A PR that drops a prop, renames a prop, adds a prop, or changes the
// introducedIn on a frozen widget fails here. To intentionally evolve the
// golden, a developer must edit schema/golden/frozen-widgets.json and
// explain the change in the PR description — which is exactly the red flag
// the frozen contract is supposed to surface in code review.

import { test, expect } from "bun:test";
import { readFileSync } from "fs";
import { join } from "path";
import { FallbackPrompt } from "../src/components/primitive/fallback-prompt";

// Golden file — the pinned contract.
interface GoldenPropSpec {
  required: boolean;
  type: string;
}

interface GoldenEntry {
  introducedIn: string;
  props: Record<string, GoldenPropSpec>;
}

interface Golden {
  widgets: Record<string, GoldenEntry>;
}

interface ManifestEntry {
  type: string;
  introducedIn?: string;
  frozen?: boolean;
}

interface Manifest {
  widgets: ManifestEntry[];
}

const GOLDEN_PATH = join(import.meta.dir, "..", "..", "schema", "golden", "frozen-widgets.json");
const MANIFEST_PATH = join(import.meta.dir, "..", "..", "schema", "widget-registry.json");

const golden: Golden = JSON.parse(readFileSync(GOLDEN_PATH, "utf8"));
const manifest: Manifest = JSON.parse(readFileSync(MANIFEST_PATH, "utf8"));
const manifestByType = new Map(manifest.widgets.map((w) => [w.type, w] as const));

// Per-widget instantiation. Each frozen widget declares how to produce an
// instance with ALL props populated — this is the runtime counterpart of the
// golden and is the only per-widget code the test needs. Adding a new frozen
// widget means adding one entry here plus one entry in the golden. If the
// two disagree, the test fails.
const FROZEN_INSTANCES: Record<string, () => Record<string, unknown>> = {
  FallbackPrompt: () =>
    FallbackPrompt.new({
      title: "Heads up",
      body: "Please take a look.",
      ctaLabel: "Open",
      ctaUrl: "https://example.com",
      severity: "info",
    }).getProps(),
};

for (const [widgetName, entry] of Object.entries(golden.widgets)) {
  test(`frozen-contract: ${widgetName} manifest entry`, () => {
    const manifestEntry = manifestByType.get(widgetName);
    expect(manifestEntry).toBeDefined();
    expect(manifestEntry?.frozen).toBe(true);
    expect(manifestEntry?.introducedIn).toBe(entry.introducedIn);
  });

  test(`frozen-contract: ${widgetName} getProps() key set`, () => {
    const makeInstance = FROZEN_INSTANCES[widgetName];
    if (!makeInstance) {
      throw new Error(
        `frozen-contract: golden declares "${widgetName}" as frozen but no ` +
          `FROZEN_INSTANCES entry exists in frozen-contract.test.ts. ` +
          `Add an instantiation with every prop populated so the test can ` +
          `diff against the golden.`,
      );
    }
    const actualProps = makeInstance();
    const actualKeys = Object.keys(actualProps).sort();
    const expectedKeys = Object.keys(entry.props).sort();
    expect(actualKeys).toEqual(expectedKeys);
  });
}

test("frozen-contract: every manifest-frozen widget is in the golden", () => {
  // The inverse check — if someone marks a widget as `frozen = true` in the
  // source but forgets to add it to the golden, the test must catch that
  // too. Otherwise a new frozen widget could sneak in without explicit
  // sign-off on its pinned shape.
  const goldenTypes = new Set(Object.keys(golden.widgets));
  const manifestFrozen = manifest.widgets.filter((w) => w.frozen === true).map((w) => w.type);
  for (const type of manifestFrozen) {
    if (!goldenTypes.has(type)) {
      throw new Error(
        `frozen-contract: widget "${type}" has frozen=true in the manifest ` +
          `but no entry in schema/golden/frozen-widgets.json. Add a golden ` +
          `entry that pins its prop shape before merging.`,
      );
    }
  }
  expect(manifestFrozen.length).toBe(goldenTypes.size);
});
