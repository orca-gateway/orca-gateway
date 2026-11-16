// The subpage example app (examples/server/subpage.ts), case C-demo2 of
// native-parity-s13. A host page embeds `detail/a` in a SubPage keyed
// `detail`; both have a page state `count`. The param `from` reaches the
// detail page as a query parameter. Contract: schema/fixtures/subpage.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";
import { readFileSync } from "fs";
import { join } from "path";

type SubPageModule = typeof import("../../examples/server/subpage");
type Page = { components: ComponentNode[]; state: { key: string; scope: string; initial: unknown }[] };

let demo: SubPageModule;
let engine: Engine;
let base: string;

beforeAll(async () => {
  demo = await import("../../examples/server/subpage");
  engine = new Engine();
  engine.registerApp(demo.subPageApp);
  // The cache is on: the detail page must render once per id and per param.
  const server = await engine.start({ port: 0 });
  base = `http://localhost:${server.port}`;
});

afterAll(() => {
  engine?.stop();
});

async function page(location: string): Promise<Page> {
  const res = await fetch(`${base}/api/v1/app/subpage/page/${location}`);
  expect(res.status).toBe(200);
  return (await res.json()) as Page;
}

const byId = (p: Page) => new Map(p.components.map((n) => [n.id, n]));
const tap = (p: Page, id: string) => byId(p).get(id)!.actions!.onTap as Record<string, unknown>;

/** Every action kind under a value, nested actions included. */
function actionKinds(value: unknown, into = new Set<string>()): Set<string> {
  if (Array.isArray(value)) value.forEach((v) => actionKinds(v, into));
  else if (value && typeof value === "object") {
    const map = value as Record<string, unknown>;
    if (typeof map.type === "string" && !["state", "static", "transform", "add", "template"].includes(map.type)) into.add(map.type);
    Object.values(map).forEach((v) => actionKinds(v, into));
  }
  return into;
}

describe("subpage example", () => {
  test("C-demo2 the host has its own count, a SubPage `detail` on detail/a with a param, and the replace and join buttons", async () => {
    const host = await page("home");
    expect(host.state).toEqual([{ key: "count", scope: "page", initial: 0 }]);

    const subPage = host.components.find((n) => n.type === "SubPage")!;
    expect(subPage.id).toBe("detail");
    // The encoder writes a static prop value as the bare value.
    expect(subPage.props).toEqual({ pageId: "detail/a", params: { from: "the host page" } });

    expect(byId(host).get("host-count")!.watches).toEqual(["count"]);
    expect(tap(host, "host-plus")).toMatchObject({ type: "setState", scope: "page", key: "count" });
    expect(tap(host, "replace-b")).toEqual({
      type: "updateSubPage",
      subPageId: "detail",
      pageId: "detail/b",
      mode: "replace",
      params: { from: "Replace with B" },
    });
    expect(tap(host, "join-c")).toEqual({
      type: "updateSubPage",
      subPageId: "detail",
      pageId: "detail/c",
      mode: "join",
      params: { from: "Join C" },
    });
  });

  test("C-demo2 each detail page renders with its own count, a +1 and a server action", async () => {
    for (const id of ["a", "b", "c"]) {
      const detail = await page(`detail/${id}`);
      const nodes = byId(detail);
      expect(detail.state).toEqual([{ key: "count", scope: "page", initial: demo.DETAIL_COUNTS[id] }]);
      expect(demo.DETAIL_COUNTS[id]).not.toBe(0);
      expect(nodes.get("title")!.props.data).toBe(`Detail ${id.toUpperCase()}`);
      expect(nodes.get("count")!.props.data).toMatchObject({ type: "transform", input: { type: "state", key: "count", scope: "page" } });
      expect(nodes.get("count")!.watches).toEqual(["count"]);
      expect(tap(detail, "plus")).toMatchObject({ type: "setState", scope: "page", key: "count" });
      expect(tap(detail, "add-ten")).toEqual({ type: "serverAction", id: "addTen" });
    }
  });

  test("C-demo2 the param arrives as a query parameter, and each value gets its own render", async () => {
    const from = async (location: string) => byId(await page(location)).get("from")!.props.data;
    expect(await from("detail/a?from=the%20host%20page")).toBe("Opened from: the host page");
    expect(await from("detail/a?from=Join%20C")).toBe("Opened from: Join C");
    expect(await from("detail/a?from=the%20host%20page")).toBe("Opened from: the host page");
    expect(await from("detail/b?from=Join%20C")).toBe("Opened from: Join C");
    expect(await from("detail/a")).toBe("Opened from: nobody");
    expect(byId(await page("detail/b?from=Join%20C")).get("title")!.props.data).toBe("Detail B");
  });

  test("C-demo2 addTen answers with a setState on the count it was posted", async () => {
    const post = async (pageState: unknown) => {
      const res = await fetch(`${base}/api/v1/app/subpage/action`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ action: "addTen", pageState }),
      });
      expect(res.status).toBe(200);
      return ((await res.json()) as { actions: unknown[] }).actions;
    };
    // What a client posts from inside the sub-page: its keys, no prefix.
    expect(await post({ count: 11 })).toEqual([{ type: "setState", scope: "page", key: "count", value: 21 }]);
    expect(await post({})).toEqual([]);
  });

  test("C-demo2 apart from SubPage and updateSubPage, every widget and action is one the native SDKs already have", async () => {
    const pages = [await page("home"), await page("detail/a")];
    const widgets = [...new Set(pages.flatMap((p) => p.components.map((n) => n.type)))].filter((t) => t !== "SubPage");
    const actions = [...actionKinds(pages.flatMap((p) => p.components.map((n) => n.actions ?? {})))].filter((t) => t !== "updateSubPage");
    expect(actions.sort()).toEqual(["serverAction", "setState"]);
    for (const sdk of ["sdk-swift", "sdk-kotlin"]) {
      const file = join(import.meta.dir, "..", "..", sdk, "capabilities.json");
      const caps = JSON.parse(readFileSync(file, "utf8")) as { widgets: string[]; actionKinds: string[] };
      expect({ sdk, missing: widgets.filter((t) => !caps.widgets.includes(t)) }).toEqual({ sdk, missing: [] });
      expect({ sdk, missing: actions.filter((t) => !caps.actionKinds.includes(t)) }).toEqual({ sdk, missing: [] });
    }
  });
});
