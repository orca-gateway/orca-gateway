// The parity-a `layout` and `layout-safe` demo pages (examples/server/parity-a.ts),
// case A3.1 of native-parity step 3: the 13 layout and sizing wrappers are on
// the page, and the Swift and Kotlin vectors get the page whole, so iOS and
// Android draw the real widgets rather than hoisted children or a fallback.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";
import { swiftCapabilityVector, kotlinCapabilityVector } from "../../schema/gen-native-capabilities";

const WRAPPERS = [
  "Align",
  "AspectRatio",
  "Baseline",
  "ConstrainedBox",
  "FittedBox",
  "Flexible",
  "FractionallySizedBox",
  "IntrinsicHeight",
  "IntrinsicWidth",
  "LimitedBox",
  "Offstage",
  "SafeArea",
  "Wrap",
];
const PAGES = ["layout", "layout-safe"];

let engine: Engine;
let base: string;

beforeAll(async () => {
  const { parityAApp } = await import("../../examples/server/parity-a");
  engine = new Engine();
  engine.registerApp(parityAApp);
  const server = await engine.start({ port: 0, cache: false });
  base = `http://localhost:${server.port}`;
});

afterAll(() => {
  engine?.stop();
});

function pageUrl(page: string): string {
  return `${base}/api/v1/app/parity-a/page/${page}`;
}

/** The page as a client with no capability vector gets it (unfiltered). */
async function plainPage(page: string): Promise<ComponentNode[]> {
  const res = await fetch(pageUrl(page));
  expect({ page, status: res.status }).toEqual({ page, status: 200 });
  return ((await res.json()) as { components: ComponentNode[] }).components;
}

/** The page as a native SDK gets it: its caps hash plus the full vector in the body. */
async function nativePage(page: string, make: typeof swiftCapabilityVector): Promise<ComponentNode[]> {
  const { vector, capsHash } = make();
  const res = await fetch(pageUrl(page), {
    method: "POST",
    headers: {
      "x-orca-sdk-version": vector.sdkSemver,
      "x-orca-caps-hash": capsHash,
      "content-type": "application/json",
    },
    body: JSON.stringify({ _orcaCapsVector: vector }),
  });
  expect({ page, status: res.status }).toEqual({ page, status: 200 });
  return ((await res.json()) as { components: ComponentNode[] }).components;
}

describe("parity-a layout pages (native-parity step 3)", () => {
  test("A3.1 the layout page holds all 13 wrappers", async () => {
    const layout = new Set((await plainPage("layout")).map((n) => n.type));
    expect(WRAPPERS.filter((type) => !layout.has(type))).toEqual([]);

    const safe = new Set((await plainPage("layout-safe")).map((n) => n.type));
    expect(safe.has("SafeArea")).toBe(true);
  });

  test("A3.1 each native vector gets the layout page whole, no FallbackPrompt", async () => {
    for (const page of PAGES) {
      const plain = await plainPage(page);
      for (const [name, make] of [
        ["swift", swiftCapabilityVector],
        ["kotlin", kotlinCapabilityVector],
      ] as const) {
        const served = await nativePage(page, make);
        const kept = new Set(served.map((n) => n.type));
        const dropped = [...new Set(plain.map((n) => n.type))].filter((type) => !kept.has(type)).sort();
        expect({ page, name, dropped }).toEqual({ page, name, dropped: [] });
        expect({ page, name, components: served }).toEqual({ page, name, components: plain });
        expect({ page, name, fallback: served.some((n) => n.type === "FallbackPrompt") }).toEqual({
          page,
          name,
          fallback: false,
        });
      }
    }
  });
});
