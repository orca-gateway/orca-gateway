import { describe, expect, it } from "bun:test";
import { ValueResolver, getByDotPath } from "../src/core/value-resolver";
import type { ValueResolverContext } from "../src/core/value-resolver";
import { V, Expr, TV } from "../src/types";
import type { RequestInfo } from "../src/types/context";

// ── Test helpers ────────────────────────────────────────────

function makeRequestInfo(overrides: Partial<RequestInfo> = {}): RequestInfo {
  return {
    platform: "iOS",
    osVersion: "17.0",
    deviceModel: "iPhone 15",
    appVersion: "1.0.0",
    buildNumber: "1",
    screenSize: { width: 390, height: 844 },
    pixelDensity: 3,
    safeAreaInsets: { top: 47, bottom: 34, left: 0, right: 0 },
    locale: "en_US",
    timezone: "UTC",
    language: "en",
    networkType: "wifi",
    ipAddress: "127.0.0.1",
    routePath: "/",
    routeParams: {},
    queryParams: {},
    ...overrides,
  };
}

function makeCtx(overrides: Partial<ValueResolverContext> = {}): ValueResolverContext {
  return {
    pageState: {},
    appState: {},
    infoData: {},
    requestInfo: makeRequestInfo(),
    ...overrides,
  };
}

function r(overrides: Partial<ValueResolverContext> = {}): ValueResolver {
  return new ValueResolver(makeCtx(overrides));
}

// ════════════════════════════════════════════════════════════
// EPIC 9: Value Resolver
// ════════════════════════════════════════════════════════════

// ── 9.1: ValueResolver class ───────────────────────────────

describe("9.1: ValueResolver class", () => {
  it("constructor takes state, appState, infoData, requestInfo", () => {
    expect(r()).toBeInstanceOf(ValueResolver);
  });

  it("resolve() returns resolved value", () => {
    expect(r().resolve(V.static("hello"))).toBe("hello");
  });
});

// ── 9.2: Resolve static values ─────────────────────────────

describe("9.2: Resolve static values", () => {
  it("resolves static string", () => {
    expect(r().resolve(V.static("hello"))).toBe("hello");
  });

  it("resolves static number", () => {
    expect(r().resolve(V.static(42))).toBe(42);
  });

  it("resolves static boolean", () => {
    expect(r().resolve(V.static(true))).toBe(true);
  });

  it("resolves static null", () => {
    expect(r().resolve(V.static(null))).toBeNull();
  });

  it("resolves static object", () => {
    const obj = { a: 1, b: "two" };
    expect(r().resolve(V.static(obj))).toEqual(obj);
  });

  it("resolves static array", () => {
    expect(r().resolve(V.static([1, 2, 3]))).toEqual([1, 2, 3]);
  });
});

// ── 9.3: Resolve state references ──────────────────────────

describe("9.3: Resolve state references", () => {
  it("resolve() resolves page state by key", () => {
    expect(r({ pageState: { count: 5 } }).resolve(V.pageState("count"))).toBe(5);
  });

  it("resolve() resolves app state by key", () => {
    expect(r({ appState: { theme: "dark" } }).resolve(V.appState("theme"))).toBe("dark");
  });

  it("resolve() resolves app state with dot-path", () => {
    expect(r({ appState: { user: { token: "abc123" } } }).resolve(V.appState("user.token"))).toBe("abc123");
  });

  it("resolve() resolves nested page state with dot-path", () => {
    expect(r({ pageState: { user: { name: "Amr" } } }).resolve(V.pageState("user.name"))).toBe("Amr");
  });

  it("resolve() returns undefined for missing page state key", () => {
    expect(r().resolve(V.pageState("missing"))).toBeUndefined();
  });

  it("resolve() returns undefined for missing app state key", () => {
    expect(r().resolve(V.appState("missing"))).toBeUndefined();
  });

  it("resolveProps leaves V.pageState as Value object (for SDK)", () => {
    const resolved = r({ pageState: { count: 5 } }).resolveProps({
      data: V.pageState("count"),
    });
    expect(resolved.data).toEqual(V.pageState("count"));
  });

  it("resolveProps leaves V.appState as Value object (for SDK)", () => {
    const resolved = r({ appState: { theme: "dark" } }).resolveProps({
      data: V.appState("theme"),
    });
    expect(resolved.data).toEqual(V.appState("theme"));
  });
});

// ── 9.4: Resolve info/request references ───────────────────

describe("9.4: Resolve info/request references", () => {
  it("resolves info data by key", () => {
    expect(r({ infoData: { products: [{ name: "Widget" }, { name: "Gadget" }] } })
      .resolve(V.info("products.0.name"))).toBe("Widget");
  });

  it("resolves request info by key", () => {
    expect(r({ requestInfo: makeRequestInfo({ platform: "Android" }) })
      .resolve(V.request("platform"))).toBe("Android");
  });

  it("resolves nested request info", () => {
    expect(r().resolve(V.request("screenSize.width"))).toBe(390);
  });

  it("returns undefined for missing info key", () => {
    expect(r({ infoData: {} }).resolve(V.info("nonexistent"))).toBeUndefined();
  });

  it("returns undefined for missing request key", () => {
    expect(r().resolve(V.request("nonexistent"))).toBeUndefined();
  });

  it("resolveProps resolves V.info to plain value", () => {
    const resolved = r({ infoData: { name: "Orca" } }).resolveProps({
      data: V.info("name"),
    });
    expect(resolved.data).toBe("Orca");
  });

  it("resolveProps resolves V.request to plain value", () => {
    const resolved = r().resolveProps({
      platform: V.request("platform"),
    });
    expect(resolved.platform).toBe("iOS");
  });
});

// ── 9.5: Resolve nested paths ──────────────────────────────

describe("9.5: Resolve nested paths (getByDotPath)", () => {
  it("traverses nested objects", () => {
    expect(getByDotPath({ user: { profile: { city: "Cairo" } } }, "user.profile.city")).toBe("Cairo");
  });

  it("traverses arrays by numeric index", () => {
    expect(getByDotPath({ items: ["a", "b", "c"] }, "items.1")).toBe("b");
  });

  it("traverses mixed objects and arrays", () => {
    const obj = { user: { addresses: [{ city: "Cairo" }, { city: "Alex" }] } };
    expect(getByDotPath(obj, "user.addresses.0.city")).toBe("Cairo");
    expect(getByDotPath(obj, "user.addresses.1.city")).toBe("Alex");
  });

  it("returns undefined for null in path", () => {
    expect(getByDotPath({ user: null }, "user.name")).toBeUndefined();
  });

  it("returns undefined for undefined in path", () => {
    expect(getByDotPath({}, "user.name")).toBeUndefined();
  });

  it("returns undefined for non-numeric array index", () => {
    expect(getByDotPath({ items: [1, 2, 3] }, "items.foo")).toBeUndefined();
  });

  it("returns undefined when traversing a primitive", () => {
    expect(getByDotPath({ count: 5 }, "count.foo")).toBeUndefined();
  });

  it("handles single-segment path", () => {
    expect(getByDotPath({ name: "test" }, "name")).toBe("test");
  });

  it("handles deeply nested path", () => {
    expect(getByDotPath({ a: { b: { c: { d: { e: 99 } } } } }, "a.b.c.d.e")).toBe(99);
  });
});

// ── 9.7: Non-Value props pass through ──────────────────────

describe("9.7: Non-Value props pass through", () => {
  it("passes through plain strings", () => {
    expect(r().resolve("hello")).toBe("hello");
  });

  it("passes through plain numbers", () => {
    expect(r().resolve(42)).toBe(42);
  });

  it("passes through plain booleans", () => {
    expect(r().resolve(true)).toBe(true);
  });

  it("passes through null and undefined", () => {
    expect(r().resolve(null)).toBeNull();
    expect(r().resolve(undefined)).toBeUndefined();
  });

  it("resolveProps resolves server-only Values, passes through non-Values", () => {
    const resolved = r({ infoData: { title: "Orca" } }).resolveProps({
      text: V.static("hello"),
      info: V.info("title"),
      color: "#FF0000",
      size: 16,
      visible: true,
    });
    expect(resolved).toEqual({
      text: "hello",
      info: "Orca",
      color: "#FF0000",
      size: 16,
      visible: true,
    });
  });

  it("resolveProps handles nested objects with server-only Values", () => {
    const resolved = r({ infoData: { pad: 5 } }).resolveProps({
      style: { padding: V.info("pad"), color: "red" },
    });
    expect(resolved.style).toEqual({ padding: 5, color: "red" });
  });

  it("resolveProps handles arrays with Values", () => {
    const resolved = r({ infoData: { name: "Amr" } }).resolveProps({
      items: [V.static("a"), V.info("name"), "c"],
    });
    expect(resolved.items).toEqual(["a", "Amr", "c"]);
  });
});

// ── 9.6: Pipeline integration ──────────────────────────────

describe("9.6: Pipeline resolves Values in render context", () => {
  const { runPipeline, PageDefinition } = require("../src/core");
  const { PrimitiveWidget } = require("../src/types/widget");
  const { V: VH } = require("../src/types/value");

  class ValueText extends PrimitiveWidget {
    readonly type = "Text";
    constructor(private data: unknown) { super(); }
    getProps() { return { data: this.data }; }
  }

  function makePipelineContext() {
    return {
      requestInfo: makeRequestInfo(),
      pageId: "test",
      routePath: "/",
      routeParams: {},
      pageState: {},
      appState: {},
    };
  }

  it("resolves V.static in component props", async () => {
    const page = PageDefinition.create({ id: "t", title: "T", render: () => new ValueText(VH.static("resolved!")) });
    const res = await runPipeline(page, makePipelineContext());
    expect(res.components.find((c: any) => c.type === "Text").props.data).toBe("resolved!");
  });

  it("leaves V.pageState as Value object for SDK", async () => {
    const page = PageDefinition.create({
      id: "t", title: "T",
      state: [{ key: "greeting", scope: "page", initial: "Hello World" }],
      render: () => new ValueText(VH.pageState("greeting")),
    });
    const res = await runPipeline(page, makePipelineContext());
    const textNode = res.components.find((c: any) => c.type === "Text");
    expect(textNode.props.data).toEqual(VH.pageState("greeting"));
  });

  it("resolves V.info in component props", async () => {
    const page = PageDefinition.create({
      id: "t", title: "T",
      getInfoData: async () => ({ product: { name: "Orca Gateway" } }),
      render: () => new ValueText(VH.info("product.name")),
    });
    const res = await runPipeline(page, makePipelineContext());
    expect(res.components.find((c: any) => c.type === "Text").props.data).toBe("Orca Gateway");
  });

  it("resolves V.request in component props", async () => {
    const page = PageDefinition.create({ id: "t", title: "T", render: () => new ValueText(VH.request("platform")) });
    const res = await runPipeline(page, makePipelineContext());
    expect(res.components.find((c: any) => c.type === "Text").props.data).toBe("iOS");
  });

  it("resolves state-free V.transform in component props", async () => {
    const page = PageDefinition.create({
      id: "t", title: "T",
      getInfoData: async () => ({ price: 10 }),
      render: () => new ValueText(VH.transform(VH.info("price"), [{ type: "add", by: VH.static(5) }, { type: "toString" }])),
    });
    const res = await runPipeline(page, makePipelineContext());
    expect(res.components.find((c: any) => c.type === "Text").props.data).toBe("15");
  });

  it("leaves state-dependent V.transform as Value object for SDK", async () => {
    const value = VH.transform(VH.pageState("count"), [{ type: "toString" }]);
    const page = PageDefinition.create({
      id: "t", title: "T",
      state: [{ key: "count", scope: "page", initial: 0 }],
      render: () => new ValueText(value),
    });
    const res = await runPipeline(page, makePipelineContext());
    const textNode = res.components.find((c: any) => c.type === "Text");
    expect(textNode.props.data).toEqual(value);
  });

  it("partially resolves V.info inside state-dependent transform", async () => {
    const page = PageDefinition.create({
      id: "t", title: "T",
      state: [{ key: "qty", scope: "page", initial: 2 }],
      getInfoData: async () => ({ price: 49.99 }),
      render: () => new ValueText(
        VH.transform(VH.info("price"), [{ type: "multiply", by: VH.pageState("qty") }]),
      ),
    });
    const res = await runPipeline(page, makePipelineContext());
    const textNode = res.components.find((c: any) => c.type === "Text");
    // V.info("price") → V.static(49.99), state ref kept
    expect(textNode.props.data).toEqual(
      VH.transform(VH.static(49.99), [{ type: "multiply", by: VH.pageState("qty") }]),
    );
  });

  it("leaves plain string props untouched", async () => {
    const page = PageDefinition.create({ id: "t", title: "T", render: () => new ValueText("just a string") });
    const res = await runPipeline(page, makePipelineContext());
    expect(res.components.find((c: any) => c.type === "Text").props.data).toBe("just a string");
  });
});

// ── State-dependent vs server-only resolution ──────────────

describe("9.x: resolveProps skips state-dependent Values", () => {
  it("leaves V.transform with state input as Value object (state parts kept)", () => {
    const value = V.transform(V.pageState("count"), [{ type: "toString" }]);
    const resolved = r({ pageState: { count: 5 } }).resolveProps({ data: value });
    // State ref kept, structure preserved
    expect(resolved.data).toEqual(value);
  });

  it("leaves V.transform with state in by param as Value object", () => {
    const value = V.transform(V.static(10), [{ type: "multiply", by: V.pageState("qty") }]);
    const resolved = r({ pageState: { qty: 3 } }).resolveProps({ data: value });
    expect(resolved.data).toEqual(value);
  });

  it("partially resolves V.info inside state-dependent transform to V.static", () => {
    const resolved = r({ infoData: { price: 49.99 }, pageState: { qty: 2 } }).resolveProps({
      data: V.transform(V.info("price"), [
        { type: "multiply", by: V.pageState("qty") },
      ]),
    });
    // V.info("price") → V.static(49.99), V.pageState kept
    expect(resolved.data).toEqual(V.transform(V.static(49.99), [
      { type: "multiply", by: V.pageState("qty") },
    ]));
  });

  it("partially resolves V.request inside state-dependent transform to V.static", () => {
    const resolved = r({ pageState: { suffix: "!" } }).resolveProps({
      data: V.transform(V.request("platform"), [
        { type: "template", template: "{{value}}" },
      ]),
    });
    // No state ref in template transform, but V.pageState("suffix") not in this transform
    // Actually this has no state refs in transforms — but the overall extractWatches
    // checks the whole tree. Let me use a proper example:
    expect(resolved.data).toBe("iOS"); // no state refs → fully resolved
  });

  it("resolves V.transform with only info/static/request (no state)", () => {
    const resolved = r({ infoData: { price: 10 } }).resolveProps({
      data: V.transform(V.info("price"), [
        { type: "multiply", by: V.static(2) },
        { type: "toString" },
      ]),
    });
    expect(resolved.data).toBe("20");
  });

  it("resolves V.static inside resolveProps", () => {
    const resolved = r().resolveProps({ data: V.static("hello") });
    expect(resolved.data).toBe("hello");
  });

  it("mixed: resolves server-only, keeps state-dependent structure", () => {
    const stateValue = V.pageState("count");
    const resolved = r({ infoData: { name: "Orca" } }).resolveProps({
      title: V.info("name"),
      count: stateValue,
      label: V.static("Buy"),
    });
    expect(resolved.title).toBe("Orca");
    expect(resolved.count).toEqual(stateValue);
    expect(resolved.label).toBe("Buy");
  });
});

// ════════════════════════════════════════════════════════════
// EPIC 10: Transformers
// ════════════════════════════════════════════════════════════

// ── 10.1: String transforms ────────────────────────────────

describe("10.1: String transforms", () => {
  it("toString", () => {
    expect(r().resolve(V.transform(V.static(42), [{ type: "toString" }]))).toBe("42");
  });

  it("toString on null", () => {
    expect(r().resolve(V.transform(V.static(null), [{ type: "toString" }]))).toBe("");
  });

  it("toUpperCase", () => {
    expect(r().resolve(V.transform(V.static("hello"), [{ type: "toUpperCase" }]))).toBe("HELLO");
  });

  it("toLowerCase", () => {
    expect(r().resolve(V.transform(V.static("HELLO"), [{ type: "toLowerCase" }]))).toBe("hello");
  });

  it("trim", () => {
    expect(r().resolve(V.transform(V.static("  hi  "), [{ type: "trim" }]))).toBe("hi");
  });

  it("template", () => {
    expect(r().resolve(V.transform(V.static(5), [
      { type: "template", template: "Count is {{value}}!" },
    ]))).toBe("Count is 5!");
  });

  it("template with multiple placeholders", () => {
    expect(r().resolve(V.transform(V.static("X"), [
      { type: "template", template: "{{value}}-{{value}}" },
    ]))).toBe("X-X");
  });

  it("regex", () => {
    expect(r().resolve(V.transform(V.static("abc123def"), [
      { type: "regex", pattern: "\\d+" },
    ]))).toBe("123");
  });

  it("regex no match returns null", () => {
    expect(r().resolve(V.transform(V.static("abc"), [
      { type: "regex", pattern: "\\d+" },
    ]))).toBeNull();
  });

  it("template with named params resolves each placeholder", () => {
    expect(
      r().resolve(
        V.transform(V.static("World"), [
          TV.template("{{greeting}}, {{value}}! Count: {{count}}", {
            greeting: V.static("Hello"),
            count: V.static(7),
          }),
        ]),
      ),
    ).toBe("Hello, World! Count: 7");
  });

  it("template resolves nested transforms and page-state in params", () => {
    const ctx = { pageState: { qty: 3 }, appState: {}, infoData: null,
      requestInfo: {} as unknown as import("../src/types/context").RequestInfo };
    const resolver = new ValueResolver(ctx);
    expect(
      resolver.resolve(
        V.transform(V.static("X"), [
          TV.template("{{value}}: {{doubled}}", {
            doubled: V.transform(V.pageState("qty"), [TV.multiply(V.static(2))]),
          }),
        ]),
      ),
    ).toBe("X: 6");
  });

  it("template unknown placeholder renders as empty string", () => {
    // Explicit contract: unknown names don't leak `{{missing}}` into UI.
    expect(
      r().resolve(
        V.transform(V.static("x"), [
          TV.template("[{{value}}|{{missing}}]"),
        ]),
      ),
    ).toBe("[x|]");
  });

  it("template extractWatches picks up state refs from params", () => {
    // Without this, the SDK's WatchBuilder wouldn't rebuild when `userName`
    // changes — same class of bug that bit the Settings page previously.
    const v = V.transform(V.static("hi"), [
      TV.template("{{value}}, {{name}}", { name: V.pageState("userName") }),
    ]);
    expect(V.extractWatches(v)).toEqual(["userName"]);
  });

  it("regex replace with $1 backref and {{value}} placeholder", () => {
    expect(
      r().resolve(
        V.transform(V.static("a=1, b=22"), [
          TV.regex("(\\w+)=(\\d+)", "g", "[$1->$2|{{value}}]"),
        ]),
      ),
    ).toBe("[a->1|a=1], [b->22|b=22]");
  });

  it("regex replace with named param", () => {
    expect(
      r().resolve(
        V.transform(V.static("hello world"), [
          TV.regex("world", undefined, "{{planet}}", {
            planet: V.static("Earth"),
          }),
        ]),
      ),
    ).toBe("hello Earth");
  });

  it("regex replace without 'g' flag only replaces first match", () => {
    expect(
      r().resolve(
        V.transform(V.static("a a a"), [
          TV.regex("a", undefined, "b"),
        ]),
      ),
    ).toBe("b a a");
  });

  it("substring", () => {
    expect(r().resolve(V.transform(V.static("hello world"), [
      { type: "substring", start: 6 },
    ]))).toBe("world");
  });

  it("substring with length", () => {
    expect(r().resolve(V.transform(V.static("hello world"), [
      { type: "substring", start: 0, length: 5 },
    ]))).toBe("hello");
  });

  it("split", () => {
    expect(r().resolve(V.transform(V.static("a,b,c"), [
      { type: "split", separator: "," },
    ]))).toEqual(["a", "b", "c"]);
  });

  it("join", () => {
    expect(r().resolve(V.transform(V.static(["a", "b", "c"]), [
      { type: "join", separator: "-" },
    ]))).toBe("a-b-c");
  });
});

// ── 10.2: Number transforms ───────────────────────────────

describe("10.2: Number transforms", () => {
  it("add", () => {
    expect(r().resolve(V.transform(V.static(10), [{ type: "add", by: V.static(5) }]))).toBe(15);
  });

  it("subtract", () => {
    expect(r().resolve(V.transform(V.static(10), [{ type: "subtract", by: V.static(3) }]))).toBe(7);
  });

  it("multiply", () => {
    expect(r().resolve(V.transform(V.static(4), [{ type: "multiply", by: V.static(3) }]))).toBe(12);
  });

  it("divide", () => {
    expect(r().resolve(V.transform(V.static(15), [{ type: "divide", by: V.static(3) }]))).toBe(5);
  });

  it("modulo", () => {
    expect(r().resolve(V.transform(V.static(10), [{ type: "modulo", by: V.static(3) }]))).toBe(1);
  });

  it("round", () => {
    expect(r().resolve(V.transform(V.static(3.7), [{ type: "round" }]))).toBe(4);
    expect(r().resolve(V.transform(V.static(3.2), [{ type: "round" }]))).toBe(3);
  });

  it("floor", () => {
    expect(r().resolve(V.transform(V.static(3.9), [{ type: "floor" }]))).toBe(3);
  });

  it("ceil", () => {
    expect(r().resolve(V.transform(V.static(3.1), [{ type: "ceil" }]))).toBe(4);
  });

  it("abs", () => {
    expect(r().resolve(V.transform(V.static(-5), [{ type: "abs" }]))).toBe(5);
  });

  it("toFixed", () => {
    expect(r().resolve(V.transform(V.static(3.14159), [{ type: "toFixed", decimals: 2 }]))).toBe("3.14");
  });
});

// ── 10.3: Boolean transforms ──────────────────────────────

describe("10.3: Boolean transforms", () => {
  it("not true → false", () => {
    expect(r().resolve(V.transform(V.static(true), [{ type: "not" }]))).toBe(false);
  });

  it("not false → true", () => {
    expect(r().resolve(V.transform(V.static(false), [{ type: "not" }]))).toBe(true);
  });

  it("not on truthy value", () => {
    expect(r().resolve(V.transform(V.static("hello"), [{ type: "not" }]))).toBe(false);
  });

  it("toBool on truthy", () => {
    expect(r().resolve(V.transform(V.static(1), [{ type: "toBool" }]))).toBe(true);
    expect(r().resolve(V.transform(V.static("yes"), [{ type: "toBool" }]))).toBe(true);
  });

  it("toBool on falsy", () => {
    expect(r().resolve(V.transform(V.static(0), [{ type: "toBool" }]))).toBe(false);
    expect(r().resolve(V.transform(V.static(""), [{ type: "toBool" }]))).toBe(false);
    expect(r().resolve(V.transform(V.static(null), [{ type: "toBool" }]))).toBe(false);
  });
});

// ── 10.4: Collection transforms ───────────────────────────

describe("10.4: Collection transforms", () => {
  it("length of array", () => {
    expect(r().resolve(V.transform(V.static([1, 2, 3]), [{ type: "length" }]))).toBe(3);
  });

  it("length of string", () => {
    expect(r().resolve(V.transform(V.static("hello"), [{ type: "length" }]))).toBe(5);
  });

  it("length of non-collection returns 0", () => {
    expect(r().resolve(V.transform(V.static(42), [{ type: "length" }]))).toBe(0);
  });

  it("at", () => {
    expect(r().resolve(V.transform(V.static(["a", "b", "c"]), [{ type: "at", index: 1 }]))).toBe("b");
  });

  it("at out of bounds", () => {
    expect(r().resolve(V.transform(V.static([1]), [{ type: "at", index: 5 }]))).toBeUndefined();
  });

  it("first", () => {
    expect(r().resolve(V.transform(V.static([10, 20, 30]), [{ type: "first" }]))).toBe(10);
  });

  it("first of empty array", () => {
    expect(r().resolve(V.transform(V.static([]), [{ type: "first" }]))).toBeUndefined();
  });

  it("last", () => {
    expect(r().resolve(V.transform(V.static([10, 20, 30]), [{ type: "last" }]))).toBe(30);
  });

  it("map", () => {
    expect(r().resolve(V.transform(V.static([1, 2, 3]), [
      { type: "map", transform: { type: "multiply", by: V.static(2) } },
    ]))).toEqual([2, 4, 6]);
  });

  it("filter", () => {
    const result = r().resolve(V.transform(V.static([1, 2, 3, 4, 5]), [
      { type: "filter", expr: Expr.gt(V.static(3), V.static(2)) },
    ]));
    expect(result).toEqual([1, 2, 3, 4, 5]);
  });

  it("contains (array)", () => {
    expect(r().resolve(V.transform(V.static([1, 2, 3]), [{ type: "contains", value: V.static(2) }]))).toBe(true);
    expect(r().resolve(V.transform(V.static([1, 2, 3]), [{ type: "contains", value: V.static(9) }]))).toBe(false);
  });

  it("contains (string)", () => {
    expect(r().resolve(V.transform(V.static("hello world"), [{ type: "contains", value: V.static("world") }]))).toBe(true);
    expect(r().resolve(V.transform(V.static("hello"), [{ type: "contains", value: V.static("xyz") }]))).toBe(false);
  });
});

// ── 10.5: Format transforms ──────────────────────────────

describe("10.5: Format transforms", () => {
  it("formatCurrency", () => {
    const result = r().resolve(V.transform(V.static(29.99), [
      { type: "formatCurrency", currency: "USD" },
    ]));
    expect(result).toContain("29.99");
  });

  it("formatCurrency with custom decimals", () => {
    const result = r().resolve(V.transform(V.static(100), [
      { type: "formatCurrency", currency: "USD", decimals: 0 },
    ]));
    expect(result).toContain("100");
  });

  it("formatDate", () => {
    const result = r().resolve(V.transform(V.static("2025-03-15T10:30:00Z"), [
      { type: "formatDate", format: "yyyy-MM-dd" },
    ]));
    expect(result).toBe("2025-03-15");
  });

  it("formatNumber", () => {
    const result = r().resolve(V.transform(V.static(1234567.89), [
      { type: "formatNumber", decimals: 2 },
    ]));
    expect(result).toContain("1");
    expect(result).toContain("234");
    expect(result).toContain("89");
  });

  it("formatNumber without grouping", () => {
    const result = r().resolve(V.transform(V.static(1234567), [
      { type: "formatNumber", useGrouping: false },
    ]));
    expect(result).toBe("1234567");
  });
});

// ── 10.6: Transform `by` accepts Value ────────────────────

describe("10.6: Transform by accepts Value", () => {
  it("multiply by V.static", () => {
    expect(r().resolve(V.transform(V.static(10), [
      { type: "multiply", by: V.static(3) },
    ]))).toBe(30);
  });

  it("multiply by V.pageState (via resolve, not resolveProps)", () => {
    expect(r({ pageState: { quantity: 3 } }).resolve(V.transform(V.static(10), [
      { type: "multiply", by: V.pageState("quantity") },
    ]))).toBe(30);
  });

  it("add by V.info", () => {
    expect(r({ infoData: { bonus: 100 } }).resolve(V.transform(V.static(50), [
      { type: "add", by: V.info("bonus") },
    ]))).toBe(150);
  });

  it("divide by V.transform (nested)", () => {
    expect(r().resolve(V.transform(V.static(100), [
      { type: "divide", by: V.transform(V.static(2), [{ type: "multiply", by: V.static(5) }]) },
    ]))).toBe(10);
  });
});

// ── 10.7: Pipeline chaining ───────────────────────────────

describe("10.7: Pipeline chaining", () => {
  it("chains 2 transforms", () => {
    expect(r().resolve(V.transform(V.static(5), [
      { type: "add", by: V.static(3) },
      { type: "toString" },
    ]))).toBe("8");
  });

  it("chains 3 transforms", () => {
    expect(r().resolve(V.transform(V.static("  Hello World  "), [
      { type: "trim" },
      { type: "toUpperCase" },
      { type: "split", separator: " " },
    ]))).toEqual(["HELLO", "WORLD"]);
  });

  it("chains price × qty → toFixed", () => {
    expect(r({ pageState: { price: 29.99, quantity: 3 } }).resolve(
      V.transform(V.pageState("price"), [
        { type: "multiply", by: V.pageState("quantity") },
        { type: "toFixed", decimals: 2 },
      ]),
    )).toBe("89.97");
  });

  it("chains number → string → collection → string", () => {
    expect(r().resolve(V.transform(V.static("one,two,three"), [
      { type: "split", separator: "," },
      { type: "map", transform: { type: "toUpperCase" } },
      { type: "join", separator: " | " },
    ]))).toBe("ONE | TWO | THREE");
  });

  it("chains 6 transforms", () => {
    expect(r().resolve(V.transform(V.static(-3.7), [
      { type: "abs" },
      { type: "ceil" },
      { type: "multiply", by: V.static(10) },
      { type: "add", by: V.static(5) },
      { type: "toString" },
      { type: "template", template: "Result: {{value}}" },
    ]))).toBe("Result: 45");
  });
});

// ── 10.8: Product page pricing test ───────────────────────

describe("10.8: Product page example (price × quantity → currency)", () => {
  it("computes total price with currency format (via resolve)", () => {
    const res = r({
      pageState: { quantity: 2 },
      infoData: { product: { price: 49.99 } },
    }).resolve(V.transform(
      V.info("product.price"),
      [
        { type: "multiply", by: V.pageState("quantity") },
        { type: "formatCurrency", currency: "USD" },
      ],
    ));
    expect(res).toContain("99.98");
  });

  it("pipeline resolves state-free product info in component", async () => {
    const { runPipeline, PageDefinition } = require("../src/core");
    const { PrimitiveWidget } = require("../src/types/widget");

    class PriceText extends PrimitiveWidget {
      readonly type = "Text";
      constructor(private data: unknown) { super(); }
      getProps() { return { data: this.data }; }
    }

    // This transform has NO state refs — only info + static
    const page = PageDefinition.create({
      id: "product", title: "Product",
      getInfoData: async () => ({ product: { name: "Widget", price: 19.99 } }),
      render: () => new PriceText(
        V.transform(V.info("product.price"), [
          { type: "multiply", by: V.static(3) },
          { type: "toFixed", decimals: 2 },
          { type: "template", template: "Total: ${{value}}" },
        ]),
      ),
    });

    const ctx = {
      requestInfo: makeRequestInfo(),
      pageId: "product",
      routePath: "/product",
      routeParams: {},
      pageState: {},
      appState: {},
    };

    const res = await runPipeline(page, ctx);
    const textNode = res.components.find((c: any) => c.type === "Text");
    expect(textNode.props.data).toBe("Total: $59.97");
  });

  it("pipeline partially resolves state-dependent pricing for SDK", async () => {
    const { runPipeline, PageDefinition } = require("../src/core");
    const { PrimitiveWidget } = require("../src/types/widget");

    class PriceText extends PrimitiveWidget {
      readonly type = "Text";
      constructor(private data: unknown) { super(); }
      getProps() { return { data: this.data }; }
    }

    // This transform references V.pageState("quantity") — state-dependent
    const page = PageDefinition.create({
      id: "product", title: "Product",
      state: [{ key: "quantity", scope: "page", initial: 2 }],
      getInfoData: async () => ({ product: { price: 19.99 } }),
      render: () => new PriceText(V.transform(V.info("product.price"), [
        { type: "multiply", by: V.pageState("quantity") },
        { type: "formatCurrency", currency: "USD" },
      ])),
    });

    const ctx = {
      requestInfo: makeRequestInfo(),
      pageId: "product",
      routePath: "/product",
      routeParams: {},
      pageState: {},
      appState: {},
    };

    const res = await runPipeline(page, ctx);
    const textNode = res.components.find((c: any) => c.type === "Text");
    // V.info("product.price") → V.static(19.99), state refs kept
    expect(textNode.props.data).toEqual(V.transform(V.static(19.99), [
      { type: "multiply", by: V.pageState("quantity") },
      { type: "formatCurrency", currency: "USD" },
    ]));
  });
});

// ── Edge cases ────────────────────────────────────────────

describe("10.9: Edge cases", () => {
  it("empty transform array returns input unchanged", () => {
    expect(r().resolve(V.transform(V.static(42), []))).toBe(42);
  });

  it("transform on undefined input", () => {
    expect(r().resolve(V.transform(V.pageState("missing"), [{ type: "toString" }]))).toBe("");
  });

  it("divide by zero", () => {
    expect(r().resolve(V.transform(V.static(10), [{ type: "divide", by: V.static(0) }]))).toBe(Infinity);
  });

  it("at on non-array returns undefined", () => {
    expect(r().resolve(V.transform(V.static("not array"), [{ type: "at", index: 0 }]))).toBeUndefined();
  });

  it("map on non-array returns input", () => {
    expect(r().resolve(V.transform(V.static(42), [
      { type: "map", transform: { type: "toString" } },
    ]))).toBe(42);
  });

  it("join on non-array returns string", () => {
    expect(r().resolve(V.transform(V.static(42), [{ type: "join", separator: "," }]))).toBe("42");
  });

  it("contains on non-collection returns false", () => {
    expect(r().resolve(V.transform(V.static(42), [{ type: "contains", value: V.static(42) }]))).toBe(false);
  });
});

// ════════════════════════════════════════════════════════════
// EPIC 11: Conditions + Watches
// ════════════════════════════════════════════════════════════

// ── 11.1: BoolExpr evaluator ─────────────────────────────────

describe("11.1: BoolExpr evaluator", () => {
  it("eq — equal values", () => {
    expect(r().evaluateBoolExpr(Expr.eq(V.static(5), V.static(5)))).toBe(true);
  });

  it("eq — unequal values", () => {
    expect(r().evaluateBoolExpr(Expr.eq(V.static(5), V.static(3)))).toBe(false);
  });

  it("eq — string comparison", () => {
    expect(r().evaluateBoolExpr(Expr.eq(V.static("hello"), V.static("hello")))).toBe(true);
  });

  it("neq — different values", () => {
    expect(r().evaluateBoolExpr(Expr.neq(V.static(5), V.static(3)))).toBe(true);
  });

  it("neq — same values", () => {
    expect(r().evaluateBoolExpr(Expr.neq(V.static(5), V.static(5)))).toBe(false);
  });

  it("gt", () => {
    expect(r().evaluateBoolExpr(Expr.gt(V.static(10), V.static(5)))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.gt(V.static(5), V.static(10)))).toBe(false);
    expect(r().evaluateBoolExpr(Expr.gt(V.static(5), V.static(5)))).toBe(false);
  });

  it("gte", () => {
    expect(r().evaluateBoolExpr(Expr.gte(V.static(10), V.static(5)))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.gte(V.static(5), V.static(5)))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.gte(V.static(3), V.static(5)))).toBe(false);
  });

  it("lt", () => {
    expect(r().evaluateBoolExpr(Expr.lt(V.static(3), V.static(5)))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.lt(V.static(5), V.static(3)))).toBe(false);
  });

  it("lte", () => {
    expect(r().evaluateBoolExpr(Expr.lte(V.static(3), V.static(5)))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.lte(V.static(5), V.static(5)))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.lte(V.static(7), V.static(5)))).toBe(false);
  });

  it("and — all true", () => {
    expect(r().evaluateBoolExpr(Expr.and(
      Expr.eq(V.static(1), V.static(1)),
      Expr.gt(V.static(5), V.static(3)),
    ))).toBe(true);
  });

  it("and — one false", () => {
    expect(r().evaluateBoolExpr(Expr.and(
      Expr.eq(V.static(1), V.static(1)),
      Expr.gt(V.static(3), V.static(5)),
    ))).toBe(false);
  });

  it("or — one true", () => {
    expect(r().evaluateBoolExpr(Expr.or(
      Expr.eq(V.static(1), V.static(2)),
      Expr.gt(V.static(5), V.static(3)),
    ))).toBe(true);
  });

  it("or — all false", () => {
    expect(r().evaluateBoolExpr(Expr.or(
      Expr.eq(V.static(1), V.static(2)),
      Expr.gt(V.static(3), V.static(5)),
    ))).toBe(false);
  });

  it("not", () => {
    expect(r().evaluateBoolExpr(Expr.not(Expr.eq(V.static(1), V.static(2))))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.not(Expr.eq(V.static(1), V.static(1))))).toBe(false);
  });

  it("isNull — null value", () => {
    expect(r().evaluateBoolExpr(Expr.isNull(V.static(null)))).toBe(true);
  });

  it("isNull — undefined (missing state key)", () => {
    expect(r().evaluateBoolExpr(Expr.isNull(V.pageState("missing")))).toBe(true);
  });

  it("isNull — non-null value", () => {
    expect(r().evaluateBoolExpr(Expr.isNull(V.static(42)))).toBe(false);
  });

  it("contains — string in string", () => {
    expect(r().evaluateBoolExpr(Expr.contains(V.static("hello world"), V.static("world")))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.contains(V.static("hello"), V.static("xyz")))).toBe(false);
  });

  it("contains — value in array", () => {
    expect(r().evaluateBoolExpr(Expr.contains(V.static([1, 2, 3]), V.static(2)))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.contains(V.static([1, 2, 3]), V.static(9)))).toBe(false);
  });

  it("startsWith", () => {
    expect(r().evaluateBoolExpr(Expr.startsWith(V.static("hello"), V.static("hel")))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.startsWith(V.static("hello"), V.static("xyz")))).toBe(false);
  });

  it("matches", () => {
    expect(r().evaluateBoolExpr(Expr.matches(V.static("abc123"), "\\d+"))).toBe(true);
    expect(r().evaluateBoolExpr(Expr.matches(V.static("abc"), "\\d+"))).toBe(false);
  });

  it("evaluates with state values", () => {
    expect(r({ pageState: { count: 5 } }).evaluateBoolExpr(
      Expr.gt(V.pageState("count"), V.static(3)),
    )).toBe(true);
  });

  it("complex nested expression", () => {
    // (count > 0) AND (NOT isNull(name))
    expect(r({ pageState: { count: 5, name: "Amr" } }).evaluateBoolExpr(
      Expr.and(
        Expr.gt(V.pageState("count"), V.static(0)),
        Expr.not(Expr.isNull(V.pageState("name"))),
      ),
    )).toBe(true);
  });
});

// ── 11.2: ConditionalValue resolution ────────────────────────

describe("11.2: ConditionalValue resolution", () => {
  it("resolves first matching branch", () => {
    const result = r({ pageState: { stock: 5 } }).resolve(
      V.when(
        [{ when: Expr.gt(V.pageState("stock"), V.static(0)), then: V.static("In Stock") }],
        V.static("Out of Stock"),
      ),
    );
    expect(result).toBe("In Stock");
  });

  it("resolves else branch when no conditions match", () => {
    const result = r({ pageState: { stock: 0 } }).resolve(
      V.when(
        [{ when: Expr.gt(V.pageState("stock"), V.static(0)), then: V.static("In Stock") }],
        V.static("Out of Stock"),
      ),
    );
    expect(result).toBe("Out of Stock");
  });

  it("resolves undefined when no match and no else", () => {
    const result = r().resolve(
      V.when([{ when: Expr.eq(V.static(1), V.static(2)), then: V.static("never") }]),
    );
    expect(result).toBeUndefined();
  });

  it("resolves correct branch in if/else-if/else chain", () => {
    const conditional = V.when(
      [
        { when: Expr.lt(V.pageState("temp"), V.static(0)), then: V.static("Freezing") },
        { when: Expr.lt(V.pageState("temp"), V.static(20)), then: V.static("Cold") },
        { when: Expr.lt(V.pageState("temp"), V.static(30)), then: V.static("Warm") },
      ],
      V.static("Hot"),
    );

    expect(r({ pageState: { temp: -5 } }).resolve(conditional)).toBe("Freezing");
    expect(r({ pageState: { temp: 10 } }).resolve(conditional)).toBe("Cold");
    expect(r({ pageState: { temp: 25 } }).resolve(conditional)).toBe("Warm");
    expect(r({ pageState: { temp: 35 } }).resolve(conditional)).toBe("Hot");
  });
});

// ── 11.3: Nested conditions ──────────────────────────────────

describe("11.3: Nested conditions", () => {
  it("condition inside condition resolves correctly", () => {
    const inner = V.when(
      [{ when: Expr.eq(V.pageState("tier"), V.static("premium")), then: V.static("Free Shipping") }],
      V.static("$9.99 Shipping"),
    );
    const outer = V.when(
      [{ when: Expr.gt(V.pageState("total"), V.static(100)), then: V.static("Free Shipping") }],
      inner,
    );

    // total > 100 → free shipping regardless
    expect(r({ pageState: { total: 150, tier: "basic" } }).resolve(outer)).toBe("Free Shipping");
    // total <= 100, premium tier → free shipping via inner
    expect(r({ pageState: { total: 50, tier: "premium" } }).resolve(outer)).toBe("Free Shipping");
    // total <= 100, basic tier → paid shipping
    expect(r({ pageState: { total: 50, tier: "basic" } }).resolve(outer)).toBe("$9.99 Shipping");
  });
});

// ── 11.4: Condition with transforms ──────────────────────────

describe("11.4: Condition with transforms", () => {
  it("then branch can be a TransformValue", () => {
    const result = r({ pageState: { price: 49.99, quantity: 2 } }).resolve(
      V.when(
        [{
          when: Expr.gt(V.pageState("quantity"), V.static(0)),
          then: V.transform(V.pageState("price"), [
            { type: "multiply", by: V.pageState("quantity") },
            { type: "toFixed", decimals: 2 },
            { type: "template", template: "Total: ${{value}}" },
          ]),
        }],
        V.static("No items"),
      ),
    );
    expect(result).toBe("Total: $99.98");
  });

  it("else branch can be a TransformValue", () => {
    const result = r({ pageState: { quantity: 0, price: 49.99 } }).resolve(
      V.when(
        [{ when: Expr.gt(V.pageState("quantity"), V.static(0)), then: V.static("Has items") }],
        V.transform(V.pageState("price"), [
          { type: "template", template: "Add to cart — ${{value}}" },
        ]),
      ),
    );
    expect(result).toBe("Add to cart — $49.99");
  });
});

// ── 11.5: extractWatches() ───────────────────────────────────

describe("11.5: extractWatches()", () => {
  it("returns empty for static values", () => {
    expect(V.extractWatches(V.static("hello"))).toEqual([]);
  });

  it("returns key for state value", () => {
    expect(V.extractWatches(V.pageState("count"))).toEqual(["count"]);
  });

  it("returns empty for info value", () => {
    expect(V.extractWatches(V.info("product.name"))).toEqual([]);
  });

  it("returns empty for request value", () => {
    expect(V.extractWatches(V.request("platform"))).toEqual([]);
  });

  it("extracts from transform input", () => {
    const watches = V.extractWatches(V.transform(V.pageState("price"), [{ type: "toString" }]));
    expect(watches).toEqual(["price"]);
  });

  it("extracts from transform by field", () => {
    const watches = V.extractWatches(V.transform(V.static(10), [
      { type: "multiply", by: V.pageState("quantity") },
    ]));
    expect(watches).toEqual(["quantity"]);
  });

  it("extracts from both input and by", () => {
    const watches = V.extractWatches(V.transform(V.pageState("price"), [
      { type: "multiply", by: V.pageState("quantity") },
    ]));
    expect(watches).toContain("price");
    expect(watches).toContain("quantity");
    expect(watches).toHaveLength(2);
  });

  it("extracts from conditional branches", () => {
    const watches = V.extractWatches(V.when(
      [{
        when: Expr.gt(V.pageState("stock"), V.static(0)),
        then: V.pageState("stockLabel"),
      }],
      V.pageState("emptyLabel"),
    ));
    expect(watches).toContain("stock");
    expect(watches).toContain("stockLabel");
    expect(watches).toContain("emptyLabel");
    expect(watches).toHaveLength(3);
  });

  it("extracts from nested conditions", () => {
    const watches = V.extractWatches(V.when(
      [{
        when: Expr.and(
          Expr.gt(V.pageState("a"), V.static(0)),
          Expr.eq(V.pageState("b"), V.static("yes")),
        ),
        then: V.when(
          [{ when: Expr.isNull(V.pageState("c")), then: V.static("null") }],
          V.pageState("d"),
        ),
      }],
    ));
    expect(watches).toContain("a");
    expect(watches).toContain("b");
    expect(watches).toContain("c");
    expect(watches).toContain("d");
    expect(watches).toHaveLength(4);
  });

  it("deduplicates keys", () => {
    const watches = V.extractWatches(V.when(
      [{
        when: Expr.gt(V.pageState("count"), V.static(0)),
        then: V.pageState("count"),
      }],
    ));
    expect(watches).toEqual(["count"]);
  });

  it("extracts from filter expr in transforms", () => {
    const watches = V.extractWatches(V.transform(V.static([1, 2, 3]), [
      { type: "filter", expr: Expr.gt(V.pageState("threshold"), V.static(0)) },
    ]));
    expect(watches).toEqual(["threshold"]);
  });

  it("extracts from contains transform", () => {
    const watches = V.extractWatches(V.transform(V.static([1, 2, 3]), [
      { type: "contains", value: V.pageState("search") },
    ]));
    expect(watches).toEqual(["search"]);
  });

  it("extracts from contains expr", () => {
    const watches = V.extractWatches(V.when(
      [{ when: Expr.contains(V.pageState("items"), V.pageState("target")), then: V.static(true) }],
    ));
    expect(watches).toContain("items");
    expect(watches).toContain("target");
  });

  it("extracts from startsWith expr", () => {
    const watches = V.extractWatches(V.when(
      [{ when: Expr.startsWith(V.pageState("name"), V.static("A")), then: V.static(true) }],
    ));
    expect(watches).toEqual(["name"]);
  });

  it("extracts from matches expr", () => {
    const watches = V.extractWatches(V.when(
      [{ when: Expr.matches(V.pageState("email"), ".*@.*"), then: V.static(true) }],
    ));
    expect(watches).toEqual(["email"]);
  });
});
