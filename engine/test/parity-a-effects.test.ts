// The parity-a `effects` demo page (examples/server/parity-a.ts), native-parity
// step 4: the 11 visual effect and touch wrappers are on the page, and the
// Swift and Kotlin vectors get the page whole, so iOS and Android draw the real
// widgets rather than hoisted children or a fallback.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";
import { swiftCapabilityVector, kotlinCapabilityVector } from "../../schema/gen-native-capabilities";

const WRAPPERS = [
  "AbsorbPointer",
  "BackdropFilter",
  "BlurView",
  "ClipOval",
  "ClipRect",
  "ColorFiltered",
  "DecoratedBox",
  "IgnorePointer",
  "InteractiveViewer",
  "Opacity",
  "RotatedBox",
];
const PAGE = "effects";

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

describe("parity-a effects page (native-parity step 4)", () => {
  test("A4 the effects page holds all 11", async () => {
    const effects = new Set((await plainPage(PAGE)).map((n) => n.type));
    expect(WRAPPERS.filter((type) => !effects.has(type))).toEqual([]);
  });

  test("A4 each native vector gets the effects page whole, no FallbackPrompt", async () => {
    const plain = await plainPage(PAGE);
    for (const [name, make] of [
      ["swift", swiftCapabilityVector],
      ["kotlin", kotlinCapabilityVector],
    ] as const) {
      const served = await nativePage(PAGE, make);
      const kept = new Set(served.map((n) => n.type));
      const dropped = [...new Set(plain.map((n) => n.type))].filter((type) => !kept.has(type)).sort();
      expect({ page: PAGE, name, dropped }).toEqual({ page: PAGE, name, dropped: [] });
      expect({ page: PAGE, name, components: served }).toEqual({ page: PAGE, name, components: plain });
      expect({ page: PAGE, name, fallback: served.some((n) => n.type === "FallbackPrompt") }).toEqual({
        page: PAGE,
        name,
        fallback: false,
      });
    }
  });
});
