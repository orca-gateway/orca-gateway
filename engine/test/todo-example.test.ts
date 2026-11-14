// The Todo example app (examples/server/todo.ts), cases U1-U10 of the
// launch-builds pipeline. The list is module state in todo.ts, so every test
// starts from resetTodos() and builds the list it needs through the actions.

import { describe, expect, test, beforeAll, afterAll, beforeEach } from "bun:test";
import { readFileSync } from "fs";
import { join } from "path";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";
import { swiftCapabilityVector, kotlinCapabilityVector } from "../../schema/gen-native-capabilities";

type TodoModule = typeof import("../../examples/server/todo");

const LIST = "todo-list";
const EMPTY = "Nothing to do yet. Add one above.";
const FOOTER = "Kept on the server until it stops.";
const OSS_ROOT = join(import.meta.dir, "..", "..");

interface WireAction {
  type: string;
  targetId?: string;
  components?: ComponentNode[];
  [k: string]: unknown;
}

interface Tree {
  type: string;
  props: Record<string, unknown>;
  actions?: unknown;
  children: Tree[];
}

let todo: TodoModule;
let engine: Engine;
let base: string;

beforeAll(async () => {
  todo = await import("../../examples/server/todo");
  engine = new Engine();
  engine.registerApp(todo.todoApp);
  const server = await engine.start({ port: 0, cache: false });
  base = `http://localhost:${server.port}`;
});

afterAll(() => {
  engine?.stop();
});

beforeEach(() => {
  todo.resetTodos();
});

// ── Helpers ────────────────────────────────────────────────

async function getPage(at = base, headers?: Record<string, string>): Promise<ComponentNode[]> {
  const res = await fetch(`${at}/api/v1/app/todo/page/home`, { headers });
  expect(res.status).toBe(200);
  return ((await res.json()) as { components: ComponentNode[] }).components;
}

async function act(action: string, params: Record<string, unknown>, at = base): Promise<WireAction[]> {
  const res = await fetch(`${at}/api/v1/app/todo/action`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ action, params }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { actions: WireAction[] }).actions;
}

/**
 * A page GET resolves V.static on the server (a param arrives as its literal);
 * a server action reply ships the Value. Both draw the same, so compare literals.
 */
function literal(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(literal);
  if (v === null || typeof v !== "object") return v;
  const o = v as Record<string, unknown>;
  if (o.type === "static" && Object.keys(o).length === 2 && "value" in o) return o.value;
  return Object.fromEntries(Object.entries(o).map(([k, x]) => [k, literal(x)]));
}

/** The subtree under `id`, ids dropped and V.static read as its literal, so a GET and a reply compare. */
function tree(nodes: ComponentNode[], id: string): Tree {
  const byId = new Map(nodes.map((n) => [n.id, n]));
  const build = (nid: string): Tree => {
    const n = byId.get(nid);
    if (!n) throw new Error(`no node "${nid}"`);
    return {
      type: n.type,
      props: literal(n.props) as Record<string, unknown>,
      actions: literal(n.actions),
      children: n.children.map(build),
    };
  };
  return build(id);
}

function parents(nodes: ComponentNode[]): Map<string, string> {
  const map = new Map<string, string>();
  for (const n of nodes) for (const c of n.children) map.set(c, n.id);
  return map;
}

function textNode(nodes: ComponentNode[], data: string): ComponentNode | undefined {
  return nodes.find((n) => n.type === "Text" && n.props.data === data);
}

interface Item {
  row: Tree;
  id: string;
  text: string;
  icon: Tree;
  label: Tree;
}

function items(list: Tree): Item[] {
  return list.children
    .filter((c) => c.type === "Row")
    .map((row) => {
      const [dot, expanded] = row.children;
      const tap = (dot!.actions as { onTap: { params: { id: string } } }).onTap;
      return {
        row,
        id: tap.params.id,
        text: expanded!.children[0]!.props.data as string,
        icon: dot!.children[0]!,
        label: expanded!.children[0]!,
      };
    });
}

async function listTree(at = base): Promise<Tree> {
  return tree(await getPage(at), LIST);
}

function rgb(hex: unknown): [number, number, number] {
  const h = String(hex).replace("#", "");
  return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)) as [number, number, number];
}
const isGreen = (hex: unknown) => {
  const [r, g, b] = rgb(hex);
  return g > r && g > b;
};
const isGrey = (hex: unknown) => {
  const [r, g, b] = rgb(hex);
  return r === g && g === b;
};

// ── Cases ──────────────────────────────────────────────────

describe("Todo example app", () => {
  test("U1 the page renders the field, Add, the empty todo-list and the footer", async () => {
    const nodes = await getPage();
    expect(nodes.some((n) => n.type === "TextField")).toBe(true);
    const add = nodes.find(
      (n) => n.type === "ElevatedButton" && tree(nodes, n.id).children[0]?.props.data === "Add",
    );
    expect(add).toBeDefined();
    const list = tree(nodes, LIST);
    expect(list.children).toHaveLength(1);
    expect(list.children[0]!.type).toBe("Text");
    expect(list.children[0]!.props.data).toBe(EMPTY);
    expect(textNode(nodes, FOOTER)).toBeDefined();
  });

  test("U2 the field sets page state draft and Add sends it to addTodo", async () => {
    const nodes = await getPage();
    const field = nodes.find((n) => n.type === "TextField")!;
    expect(field.props.value).toEqual({ type: "state", key: "draft", scope: "page" });
    expect((field.actions as Record<string, unknown>).onChange).toEqual({
      type: "setState",
      scope: "page",
      key: "draft",
      value: { type: "event", key: "value" },
    });
    const add = nodes.find((n) => n.type === "ElevatedButton")!;
    expect((add.actions as Record<string, unknown>).onTap).toEqual({
      type: "serverAction",
      id: "addTodo",
      params: { text: { type: "state", key: "draft", scope: "page" } },
    });
  });

  test("U3 addTodo trims, appends at the bottom and replaces todo-list as a fresh GET draws it", async () => {
    await act("addTodo", { text: "Call Sam" });
    const reply = await act("addTodo", { text: "  Buy milk  " });
    expect(reply.map((a) => a.type)).toEqual(["replaceComponent", "setState"]);
    expect(reply[0]!.targetId).toBe(LIST);
    expect(reply[0]!.components![0]!.id).toBe(LIST);
    expect(reply[1]).toEqual({ type: "setState", scope: "page", key: "draft", value: "" });
    const replaced = tree(reply[0]!.components!, LIST);
    expect(items(replaced).map((i) => i.text)).toEqual(["Call Sam", "Buy milk"]);
    expect(replaced).toEqual(await listTree());
  });

  test("U4 a blank addTodo returns no actions and changes nothing", async () => {
    await act("addTodo", { text: "Call Sam" });
    const before = await listTree();
    expect(await act("addTodo", { text: "   " })).toEqual([]);
    expect(await listTree()).toEqual(before);
  });

  test("U5 ids are distinct uuids and toggleTodo flips only its item", async () => {
    await act("addTodo", { text: "Call Sam" });
    await act("addTodo", { text: "Call Sam" });
    const start = await listTree();
    const [first, second] = items(start);
    expect(typeof first!.id).toBe("string");
    expect(first!.id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
    expect(first!.id).not.toBe(second!.id);
    expect(first!.icon.props.name).toBe("circle");
    expect(isGrey(first!.icon.props.color)).toBe(true);

    await act("toggleTodo", { id: first!.id });
    const [a, b] = items(await listTree());
    expect([a!.id, b!.id]).toEqual([first!.id, second!.id]);
    expect(a!.icon.props.name).toBe("check_circle");
    expect(isGreen(a!.icon.props.color)).toBe(true);
    const style = a!.label.props.style as Record<string, unknown>;
    expect(style.decoration).toBe("lineThrough");
    expect(isGrey(style.color)).toBe(true);
    expect(b!.icon.props.name).toBe("circle");
    expect(isGrey(b!.icon.props.color)).toBe(true);
    expect((b!.label.props.style as Record<string, unknown> | undefined)?.decoration).not.toBe("lineThrough");

    await act("toggleTodo", { id: first!.id });
    expect(await listTree()).toEqual(start);
  });

  test("U6 deleteTodo removes one item, ignores an unknown id, and shows the empty text after the last", async () => {
    for (const t of ["A", "B", "C"]) await act("addTodo", { text: t });
    const ids = items(await listTree()).map((i) => i.id);

    await act("deleteTodo", { id: ids[1] });
    const afterOne = await listTree();
    expect(items(afterOne).map((i) => i.text)).toEqual(["A", "C"]);

    await act("deleteTodo", { id: "no-such-id" });
    expect(await listTree()).toEqual(afterOne);

    await act("deleteTodo", { id: ids[0] });
    const last = await act("deleteTodo", { id: ids[2] });
    const replied = tree(last[0]!.components!, LIST);
    const list = await listTree();
    expect(list).toEqual(replied);
    expect(list.children).toHaveLength(1);
    expect(list.children[0]!.props.data).toBe(EMPTY);
  });

  test("U7 an item row lays out dot, expanded text and close; the field is in an Expanded beside Add", async () => {
    const long = "Pick up the parcel at the post office before noon. ".repeat(6).slice(0, 299) + ".";
    expect(long).toHaveLength(300);
    await act("addTodo", { text: long });
    const nodes = await getPage();
    const [item] = items(tree(nodes, LIST));
    const row = item!.row;
    expect(row.props.crossAxisAlignment).toBe("start");
    expect(row.children.map((c) => c.type)).toEqual(["GestureDetector", "Expanded", "GestureDetector"]);
    expect(row.children[0]!.children[0]!.type).toBe("Icon");
    expect(row.children[0]!.children[0]!.props.name).toBe("circle");
    expect(row.children[1]!.children[0]!.type).toBe("Text");
    expect(row.children[1]!.children[0]!.props.data).toBe(long);
    expect(row.children[2]!.children[0]!.type).toBe("Icon");
    expect(row.children[2]!.children[0]!.props.name).toBe("close");
    expect((row.children[2]!.actions as { onTap: unknown }).onTap).toEqual({
      type: "serverAction",
      id: "deleteTodo",
      params: { id: item!.id },
    });
    expect((row.children[0]!.actions as { onTap: unknown }).onTap).toEqual({
      type: "serverAction",
      id: "toggleTodo",
      params: { id: item!.id },
    });

    const up = parents(nodes);
    const byId = new Map(nodes.map((n) => [n.id, n]));
    const field = nodes.find((n) => n.type === "TextField")!;
    const expanded = byId.get(up.get(field.id)!)!;
    expect(expanded.type).toBe("Expanded");
    const fieldRow = byId.get(up.get(expanded.id)!)!;
    expect(fieldRow.type).toBe("Row");
    expect(fieldRow.children.map((c) => byId.get(c)!.type)).toContain("ElevatedButton");
  });

  test("U8 the page Column sits in a SingleChildScrollView and the footer follows todo-list", async () => {
    const nodes = await getPage();
    const up = parents(nodes);
    const byId = new Map(nodes.map((n) => [n.id, n]));
    const column = byId.get(up.get(LIST)!)!;
    expect(column.type).toBe("Column");
    const ancestors: string[] = [];
    for (let id = up.get(column.id); id; id = up.get(id)) ancestors.push(byId.get(id)!.type);
    expect(ancestors).toContain("SingleChildScrollView");
    const footer = textNode(nodes, FOOTER)!;
    expect(up.get(footer.id)).toBe(column.id);
    expect(column.children.indexOf(footer.id)).toBeGreaterThan(column.children.indexOf(LIST));
  });

  test("U9 with the default cache a second GET shows the added item", async () => {
    const cached = new Engine();
    cached.registerApp(todo.todoApp);
    const server = await cached.start({ port: 0 });
    const at = `http://localhost:${server.port}`;
    try {
      expect(items(await listTree(at))).toHaveLength(0);
      await act("addTodo", { text: "Buy milk" }, at);
      expect(items(await listTree(at)).map((i) => i.text)).toEqual(["Buy milk"]);
    } finally {
      cached.stop();
    }
  });

  test("U10 the Swift and Kotlin vectors draw the page and the replies unfiltered", async () => {
    await act("addTodo", { text: "Call Sam" });
    const plain = await getPage();

    const replies: WireAction[] = [];
    // replaceComponent is a server response kind outside action.ts: no vector
    // lists it, and both native executors handle it on top of what they list.
    const executors = [
      "sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift",
      "sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/ActionExecutor.kt",
    ];
    for (const file of executors) {
      expect(readFileSync(join(OSS_ROOT, file), "utf8")).toContain('"replaceComponent"');
    }

    const seen = new Set<string>();
    for (const [name, make] of [
      ["swift", swiftCapabilityVector],
      ["kotlin", kotlinCapabilityVector],
    ] as const) {
      const { vector, capsHash } = make();
      const headers = { "x-orca-sdk-version": vector.sdkSemver, "x-orca-caps-hash": capsHash };
      const url = `${base}/api/v1/app/todo/page/home`;
      // Both SDKs may send the same vector (same hash): a known hash skips the 412.
      expect((await fetch(url, { headers })).status).toBe(seen.has(capsHash) ? 200 : 412);
      seen.add(capsHash);
      const retry = await fetch(url, {
        method: "POST",
        headers: { ...headers, "content-type": "application/json" },
        body: JSON.stringify({ _orcaCapsVector: vector }),
      });
      expect(retry.status).toBe(200);
      const served = ((await retry.json()) as { components: ComponentNode[] }).components;
      expect({ name, components: served }).toEqual({ name, components: plain });
      expect(served.some((n) => n.type === "FallbackPrompt")).toBe(false);
    }

    const id = items(tree(plain, LIST))[0]!.id;
    replies.push(...(await act("addTodo", { text: "Buy milk" })));
    replies.push(...(await act("toggleTodo", { id })));
    replies.push(...(await act("deleteTodo", { id })));
    expect(replies.length).toBeGreaterThan(0);

    const widgets = new Set(plain.map((n) => n.type));
    const actionKinds = new Set<string>();
    for (const n of plain) for (const a of Object.values(n.actions ?? {})) actionKinds.add((a as { type: string }).type);
    const replyKinds = new Set<string>();
    for (const r of replies) {
      replyKinds.add(r.type);
      for (const n of r.components ?? []) {
        widgets.add(n.type);
        for (const a of Object.values(n.actions ?? {})) actionKinds.add((a as { type: string }).type);
      }
    }

    for (const make of [swiftCapabilityVector, kotlinCapabilityVector]) {
      const { vector } = make();
      for (const w of widgets) expect({ widget: w, listed: vector.widgets.includes(w) }).toEqual({ widget: w, listed: true });
      for (const k of actionKinds) expect({ action: k, listed: vector.actionKinds.includes(k) }).toEqual({ action: k, listed: true });
      for (const k of replyKinds) {
        const listed = k === "replaceComponent" || vector.actionKinds.includes(k);
        expect({ reply: k, listed }).toEqual({ reply: k, listed: true });
      }
    }
    for (const banned of ["Checkbox", "InkWell", "FloatingActionButton", "SnackBar"]) {
      expect(widgets.has(banned)).toBe(false);
    }
  });
});
