// The reorder example app (examples/server/reorder.ts), case C-demo of
// native-parity-s13. The order lives in page state as a list; each row reads
// its label by position, and the `moveRow` server action answers a drop with
// the new list. Nothing is kept on the server.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";
import { readFileSync } from "fs";
import { join } from "path";

type ReorderModule = typeof import("../../examples/server/reorder");

let reorder: ReorderModule;
let engine: Engine;
let base: string;

beforeAll(async () => {
  reorder = await import("../../examples/server/reorder");
  engine = new Engine();
  engine.registerApp(reorder.reorderApp);
  const server = await engine.start({ port: 0, cache: false });
  base = `http://localhost:${server.port}`;
});

afterAll(() => {
  engine?.stop();
});

async function move(order: unknown, oldIndex: number, newIndex: number) {
  const res = await fetch(`${base}/api/v1/app/reorder/action`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action: "moveRow", params: { oldIndex, newIndex }, pageState: { order } }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { actions: unknown[] }).actions;
}

const set = (key: string, value: unknown) => ({ type: "setState", scope: "page", key, value });

describe("reorder example", () => {
  test("C-demo the page is one ReorderableListView of five rows, each reading its label by position, with onReorder sending the event indices", async () => {
    const res = await fetch(`${base}/api/v1/app/reorder/page/home`);
    expect(res.status).toBe(200);
    const page = (await res.json()) as { components: ComponentNode[]; state: { key: string; initial: unknown }[] };
    const byId = new Map(page.components.map((n) => [n.id, n]));

    const order = page.state.find((s) => s.key === "order")!.initial as string[];
    expect(order).toEqual([...reorder.INITIAL_ORDER]);
    expect(order).toHaveLength(5);

    const list = page.components.find((n) => n.type === "ReorderableListView")!;
    expect(list.id).toBe("reorder-list");
    expect(list.children).toEqual([0, 1, 2, 3, 4].map((i) => `reorder-row-${i}`));
    expect(list.actions).toEqual({
      onReorder: {
        type: "serverAction",
        id: "moveRow",
        params: {
          oldIndex: { type: "event", key: "oldIndex" },
          newIndex: { type: "event", key: "newIndex" },
        },
      },
    });

    list.children.forEach((rowId, i) => {
      const label = byId.get(`reorder-label-${i}`)!;
      expect(byId.has(rowId)).toBe(true);
      expect(label.props.data).toEqual({
        type: "transform",
        input: { type: "state", key: "order", scope: "page" },
        by: [{ type: "at", index: i }],
      });
      expect(label.watches).toEqual(["order"]);
    });

    const last = byId.get("reorder-last")!;
    expect(last.props.data).toEqual({ type: "state", key: "lastMove", scope: "page" });
  });

  test("C-demo every widget of the page but the list itself is one the native SDKs already draw", async () => {
    const res = await fetch(`${base}/api/v1/app/reorder/page/home`);
    const page = (await res.json()) as { components: ComponentNode[] };
    const used = [...new Set(page.components.map((n) => n.type))].filter((t) => t !== "ReorderableListView");
    for (const sdk of ["sdk-swift", "sdk-kotlin"]) {
      const file = join(import.meta.dir, "..", "..", sdk, "capabilities.json");
      const drawn = new Set((JSON.parse(readFileSync(file, "utf8")) as { widgets: string[] }).widgets);
      expect({ sdk, missing: used.filter((t) => !drawn.has(t)) }).toEqual({ sdk, missing: [] });
    }
  });

  test("C-demo moveRow moves down with the raw newIndex: the insertion index before removal", async () => {
    expect(await move(["a", "b", "c", "d", "e"], 0, 3)).toEqual([
      set("order", ["b", "c", "a", "d", "e"]),
      set("lastMove", "0 → 3"),
    ]);
    expect(await move(["a", "b", "c", "d", "e"], 0, 5)).toEqual([
      set("order", ["b", "c", "d", "e", "a"]),
      set("lastMove", "0 → 5"),
    ]);
  });

  test("C-demo moveRow moves up: newIndex is where the row lands", async () => {
    expect(await move(["a", "b", "c", "d", "e"], 3, 1)).toEqual([
      set("order", ["a", "d", "b", "c", "e"]),
      set("lastMove", "3 → 1"),
    ]);
  });

  test("C-demo moveRow answers nothing for indices outside the list or a list it was not sent", async () => {
    expect(await move(["a", "b", "c"], 7, 0)).toEqual([]);
    expect(await move(["a", "b", "c"], 0, 9)).toEqual([]);
    expect(await move(undefined, 0, 2)).toEqual([]);
  });
});
