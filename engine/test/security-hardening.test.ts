import { describe, expect, it, test, afterAll, beforeAll } from "bun:test";
import { Engine, App, Flow, PageDefinition, ServerActionDefinition } from "../src/core";
import { extractRequestInfo } from "../src/core/request-info";
import { getByDotPath } from "../src/core/value-resolver";
import { encodeJsonTree, type JsonTreeNode } from "../src/core/json-tree-encoder";
import { flatten, MAX_TREE_DEPTH, MAX_TREE_NODES } from "../src/types/widget";
import { Column, Text } from "../src/components";

// ── X-Forwarded-For / trustProxy ──────────────────────────

describe("client IP resolution", () => {
  const reqWithXff = (xff: string) =>
    new Request("http://localhost/api/v1/app/x/page/home", {
      headers: { "x-forwarded-for": xff },
    });

  it("ignores X-Forwarded-For by default (spoofable header)", () => {
    const info = extractRequestInfo(reqWithXff("6.6.6.6"), {}, { socketAddress: "10.0.0.5" });
    expect(info.ipAddress).toBe("10.0.0.5");
  });

  it("falls back to 127.0.0.1 without a socket address", () => {
    const info = extractRequestInfo(reqWithXff("6.6.6.6"), {});
    expect(info.ipAddress).toBe("127.0.0.1");
  });

  it("with trustProxy, takes the RIGHTMOST hop (appended by the trusted proxy)", () => {
    const info = extractRequestInfo(
      reqWithXff("6.6.6.6, 203.0.113.7"),
      {},
      { socketAddress: "10.0.0.5", trustProxy: true },
    );
    expect(info.ipAddress).toBe("203.0.113.7");
  });

  it("with trustProxy, rejects a non-IP value and falls back to the socket", () => {
    const info = extractRequestInfo(
      reqWithXff("not-an-ip"),
      {},
      { socketAddress: "10.0.0.5", trustProxy: true },
    );
    expect(info.ipAddress).toBe("10.0.0.5");
  });

  it("with trustProxy, accepts IPv6", () => {
    const info = extractRequestInfo(
      reqWithXff("2001:db8::1"),
      {},
      { socketAddress: "10.0.0.5", trustProxy: true },
    );
    expect(info.ipAddress).toBe("2001:db8::1");
  });
});

// ── getByDotPath prototype-chain hardening ─────────────────

describe("getByDotPath refuses prototype-chain segments", () => {
  const obj = { a: { b: 1 } };

  it("resolves normal paths", () => {
    expect(getByDotPath(obj, "a.b")).toBe(1);
  });

  it.each(["__proto__", "constructor", "a.constructor", "__proto__.polluted", "constructor.prototype"])(
    "returns undefined for %p",
    (path) => {
      expect(getByDotPath(obj, path)).toBeUndefined();
    },
  );
});

// ── Encoder ceilings ───────────────────────────────────────

describe("encoder tree ceilings", () => {
  it("flatten() rejects trees deeper than MAX_TREE_DEPTH", () => {
    let widget = Text.new({ data: "leaf" }) as any;
    for (let i = 0; i < MAX_TREE_DEPTH + 1; i++) {
      widget = Column.new({ children: [widget] });
    }
    expect(() => flatten(widget)).toThrow(/nesting levels/);
  });

  it("json-tree-encoder rejects trees deeper than MAX_TREE_DEPTH", () => {
    let tree: JsonTreeNode = { type: "Text", props: { data: "leaf" } };
    for (let i = 0; i < MAX_TREE_DEPTH + 1; i++) {
      tree = { type: "Column", children: [tree] };
    }
    const ctx = { pageState: {}, appState: {} };
    expect(() => encodeJsonTree(tree, ctx as any)).toThrow(/nesting levels/);
  });

  it("flatten() rejects trees with more than MAX_TREE_NODES nodes", () => {
    const children = Array.from({ length: MAX_TREE_NODES + 1 }, () =>
      Text.new({ data: "x" }),
    );
    expect(() => flatten(Column.new({ children }))).toThrow(/nodes/);
  });
});

// ── ServerAction authorize hook ────────────────────────────

describe("server action authorize hook", () => {
  const gatedAction = ServerActionDefinition.create({
    id: "gated",
    authorize: (ctx) => ctx.requestInfo.authToken === "let-me-in",
    execute: () => [{ type: "showToast", message: "ran" }],
  });

  const throwingAuthAction = ServerActionDefinition.create({
    id: "authThrows",
    authorize: () => {
      throw new Error("auth backend down");
    },
    execute: () => [{ type: "showToast", message: "ran" }],
  });

  const page = PageDefinition.create({
    id: "home",
    render: () => Text.new({ data: "hi" }),
  });
  const app = App.create({
    id: "authz-app",
    name: "Authz App",
    flows: [Flow.create({ name: "main", routes: [{ path: "home", page }] })],
    actions: [gatedAction, throwingAuthAction],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<Engine["start"]>>;

  beforeAll(async () => {
    server = await engine.start({ port: 0, cache: false });
  });
  afterAll(() => engine.stop());

  const callAction = (actionId: string, headers: Record<string, string> = {}) =>
    fetch(`http://localhost:${server.port}/api/v1/app/authz-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body: JSON.stringify({ action: actionId }),
    });

  test("rejects with 403 when authorize returns false", async () => {
    const res = await callAction("gated");
    expect(res.status).toBe(403);
  });

  test("executes when authorize returns true", async () => {
    const res = await callAction("gated", { authorization: "Bearer let-me-in" });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { actions: { type: string }[] };
    expect(body.actions[0]!.type).toBe("showToast");
  });

  test("rejects with 403 when authorize throws", async () => {
    const res = await callAction("authThrows");
    expect(res.status).toBe(403);
  });
});
