// The slivers example app (examples/server/slivers.ts), case C-demo of
// native-parity-s13-slivers. Three tabs, each one CustomScrollView over the
// same content: a SliverAppBar (pinned, floating, neither), a heading, a
// SliverGrid of 6 cells, a SliverList of 40 rows and a closing line.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";

type SliversModule = typeof import("../../examples/server/slivers");

let slivers: SliversModule;
let engine: Engine;
let base: string;

beforeAll(async () => {
  slivers = await import("../../examples/server/slivers");
  engine = new Engine();
  engine.registerApp(slivers.sliversApp);
  const server = await engine.start({ port: 0, cache: false });
  base = `http://localhost:${server.port}`;
});

afterAll(() => {
  engine?.stop();
});

async function page(id: string): Promise<{ nodes: ComponentNode[]; byId: Map<string, ComponentNode> }> {
  const res = await fetch(`${base}/api/v1/app/slivers/page/${id}`);
  expect({ id, status: res.status }).toEqual({ id, status: 200 });
  const nodes = ((await res.json()) as { components: ComponentNode[] }).components;
  return { nodes, byId: new Map(nodes.map((n) => [n.id, n])) };
}

/** The bar props each tab must send, and nothing else of the three. */
const BARS = {
  pinned: { pinned: true, expandedHeight: 200 },
  floating: { floating: true },
  plain: { expandedHeight: 120 },
} as const;

const TITLES = { pinned: "Pinned", floating: "Floating", plain: "Plain" } as const;

describe("slivers example", () => {
  test("C-demo the app serves its config with three tabs, one per page, opening on the pinned one", async () => {
    const res = await fetch(`${base}/api/v1/app/slivers/config`);
    expect(res.status).toBe(200);
    const config = (await res.json()) as {
      initialRoute: string;
      tabs: { id: string; label: string; icon: string; initialRoute: string }[];
    };
    expect(config.initialRoute).toBe("/pinned");
    expect(config.tabs.map((t) => ({ id: t.id, label: t.label, initialRoute: t.initialRoute }))).toEqual([
      { id: "pinned", label: "Pinned", initialRoute: "/pinned" },
      { id: "floating", label: "Floating", initialRoute: "/floating" },
      { id: "plain", label: "Plain", initialRoute: "/plain" },
    ]);
    expect(slivers.GRID_CELLS).toBe(6);
    expect(slivers.LIST_ROWS).toBe(40);
  });

  for (const id of ["pinned", "floating", "plain"] as const) {
    test(`C-demo the ${id} page is one CustomScrollView: bar, heading, grid of 6, list of 40, closing line`, async () => {
      const { nodes, byId } = await page(id);

      const scrolls = nodes.filter((n) => n.type === "CustomScrollView");
      expect(scrolls).toHaveLength(1);
      const scroll = scrolls[0]!;
      expect(scroll.id).toBe(`${id}-scroll`);
      expect(scroll.children.map((c) => byId.get(c)!.type)).toEqual([
        "SliverAppBar",
        "SliverToBoxAdapter",
        "SliverGrid",
        "SliverList",
        "SliverToBoxAdapter",
      ]);
      const [barId, headingId, gridId, listId, endId] = scroll.children as [string, string, string, string, string];

      // The bar: only this tab's variant props, and its four slots as node ids.
      const bar = byId.get(barId)!;
      const { title, flexibleSpace, action_0, ...barProps } = bar.props as Record<string, unknown>;
      expect(barProps).toEqual({ ...BARS[id] });
      expect(byId.get(title as string)!.type).toBe("Text");
      expect(byId.get(title as string)!.props.data).toBe(TITLES[id]);
      expect(byId.get(flexibleSpace as string)!.type).toBe("Container");
      expect(typeof byId.get(flexibleSpace as string)!.props.color).toBe("string");
      expect(byId.get(action_0 as string)!.type).toBe("Icon");
      expect(bar.props.action_1).toBeUndefined();

      // The grid: 6 coloured cells, 3 across, spacing 8, ratio 1.5, numbered 1 to 6.
      const grid = byId.get(gridId)!;
      expect(grid.props).toEqual({ crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.5 });
      expect(grid.children).toEqual([1, 2, 3, 4, 5, 6].map((n) => `${id}-cell-${n}`));
      grid.children.forEach((cellId, i) => {
        expect(byId.get(cellId)!.type).toBe("Container");
        expect(byId.get(`${id}-cell-label-${i + 1}`)!.props.data).toBe(`${i + 1}`);
      });

      // The list: 40 rows, "Row 1" to "Row 40", each of one fixed height.
      const list = byId.get(listId)!;
      expect(list.props).toEqual({});
      expect(list.children).toEqual(Array.from({ length: 40 }, (_, i) => `${id}-row-${i + 1}`));
      const heights = new Set(list.children.map((rowId) => byId.get(rowId)!.props.height));
      expect([...heights]).toEqual([slivers.ROW_HEIGHT]);
      expect(byId.get(`${id}-row-label-1`)!.props.data).toBe("Row 1");
      expect(byId.get(`${id}-row-label-40`)!.props.data).toBe("Row 40");

      // The two adapters hold one child each: the heading and the closing line.
      expect(byId.get(headingId)!.children).toHaveLength(1);
      expect(byId.get(endId)!.children).toHaveLength(1);
      expect(byId.get(`${id}-end`)!.props.data).toBe("End of list");
    });
  }

  test("C-demo the three pages hold the same content: only the bar and the ids differ", async () => {
    const shape = async (id: string) =>
      (await page(id)).nodes.filter((n) => n.type !== "SliverAppBar").map((n) => n.type);
    const pinned = await shape("pinned");
    expect(await shape("floating")).toEqual(pinned);
    expect(await shape("plain")).toEqual(pinned);
  });
});
