// The parity-a `lists` demo page (examples/server/parity-a.ts), native-parity
// step 5: ListView, GridView, PageView, PullToRefresh and Scrollbar are on the
// page with a RefetchPage action, and the Swift and Kotlin vectors get the page
// whole, so iOS and Android draw the real widgets rather than a fallback.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";
import { swiftCapabilityVector, kotlinCapabilityVector } from "../../schema/gen-native-capabilities";

const WIDGETS = ["GridView", "ListView", "PageView", "PullToRefresh", "Scrollbar"];
const PAGE = "lists";

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

describe("parity-a lists page (native-parity step 5)", () => {
  test("A5 the lists page holds all five", async () => {
    const nodes = await plainPage(PAGE);
    const types = new Set(nodes.map((n) => n.type));
    expect(WIDGETS.filter((type) => !types.has(type))).toEqual([]);
    const refetchOnRefresh = nodes.some(
      (n) => n.type === "PullToRefresh" && (n.actions?.onRefresh as { type?: string } | undefined)?.type === "refetchPage",
    );
    expect({ refetchOnRefresh }).toEqual({ refetchOnRefresh: true });
  });

  test("A5 each native vector gets the lists page whole, no FallbackPrompt", async () => {
    const plain = await plainPage(PAGE);
    for (const [name, make] of [
      ["swift", swiftCapabilityVector],
      ["kotlin", kotlinCapabilityVector],
    ] as const) {
      const served = await nativePage(PAGE, make);
      const kept = new Set(served.map((n) => n.type));
      const dropped = [...new Set(plain.map((n) => n.type))].filter((type) => !kept.has(type)).sort();
      expect({ page: PAGE, name, dropped }).toEqual({ page: PAGE, name, dropped: [] });
      // The server fetch count differs per fetch; everything else must match.
      expect({ page: PAGE, name, components: withoutFetchCount(served) }).toEqual({
        page: PAGE,
        name,
        components: withoutFetchCount(plain),
      });
      expect({ page: PAGE, name, fallback: served.some((n) => n.type === "FallbackPrompt") }).toEqual({
        page: PAGE,
        name,
        fallback: false,
      });
    }
  });
});

/** The nodes with the "server fetches: N" text blanked, since N grows with every fetch. */
function withoutFetchCount(nodes: ComponentNode[]): ComponentNode[] {
  return nodes.map((n) =>
    typeof n.props?.data === "string" && n.props.data.startsWith("server fetches: ")
      ? { ...n, props: { ...n.props, data: "server fetches: N" } }
      : n,
  );
}
