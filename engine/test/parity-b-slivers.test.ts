// The `slivers` demo app (examples/server/slivers.ts), native-parity step 13,
// case C-caps: CustomScrollView and the four sliver widgets are on the page,
// and the Swift and Kotlin vectors get the page whole, so iOS and Android draw
// the real widgets rather than a fallback.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";
import { swiftCapabilityVector, kotlinCapabilityVector } from "../../schema/gen-native-capabilities";

const WIDGETS = ["CustomScrollView", "SliverAppBar", "SliverGrid", "SliverList", "SliverToBoxAdapter"];
const PAGE = "plain";
const UNDRAWN = ["FallbackPrompt", "UnsupportedWidgetPlaceholder"];

let engine: Engine;
let base: string;

beforeAll(async () => {
  const { sliversApp } = await import("../../examples/server/slivers");
  engine = new Engine();
  engine.registerApp(sliversApp);
  const server = await engine.start({ port: 0, cache: false });
  base = `http://localhost:${server.port}`;
});

afterAll(() => {
  engine?.stop();
});

function pageUrl(page: string): string {
  return `${base}/api/v1/app/slivers/page/${page}`;
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

/** One native vector gets the page as the plain client does: nothing dropped, nothing swapped. */
async function expectWhole(name: string, make: typeof swiftCapabilityVector): Promise<void> {
  const plain = await plainPage(PAGE);
  const served = await nativePage(PAGE, make);
  const kept = new Set(served.map((n) => n.type));
  const dropped = [...new Set(plain.map((n) => n.type))].filter((type) => !kept.has(type)).sort();
  expect({ page: PAGE, name, dropped }).toEqual({ page: PAGE, name, dropped: [] });
  expect({ page: PAGE, name, undrawn: served.filter((n) => UNDRAWN.includes(n.type)).map((n) => n.type) }).toEqual({
    page: PAGE,
    name,
    undrawn: [],
  });
  expect({ page: PAGE, name, components: served }).toEqual({ page: PAGE, name, components: plain });
}

describe("slivers page (native-parity step 13)", () => {
  test("C-caps the plain page holds all five", async () => {
    const nodes = await plainPage(PAGE);
    const types = new Set(nodes.map((n) => n.type));
    expect(WIDGETS.filter((type) => !types.has(type))).toEqual([]);
  });

  test("C-caps the Swift vector gets the page whole, no fallback, no placeholder", async () => {
    await expectWhole("swift", swiftCapabilityVector);
  });

  test("C-caps the Kotlin vector gets the page whole, no fallback, no placeholder", async () => {
    await expectWhole("kotlin", kotlinCapabilityVector);
  });
});
