import { describe, expect, it } from "bun:test";
import {
  V,
  Expr,
  Encoder,
  Widget,
  PrimitiveWidget,
  SingleChildLayout,
  MultiChildLayout,
  Navigate,
  GoBack,
  SetState,
  ClearState,
  ServerAction,
  CopyToClipboard,
  Share,
  OpenUrl,
  ShowSnackbar,
  ShowToast,
  Sequential,
  Parallel,
  When,
  type ComponentNode,
  type Value,
  type ActionMap,
  type RequestInfo,
  type PageContext,
  type RenderContext,
  type ActionContext,
  type StateDefinition,
  type PageState,
  type AppState,
} from "../src/types";

// ── Test widgets ────────────────────────────────────────────

class TestText extends PrimitiveWidget {
  readonly type = "Text";
  constructor(private data: string | Value) { super(); }
  getProps() { return { data: this.data }; }
}

class TestContainer extends SingleChildLayout {
  readonly type = "Container";
  constructor(child?: Widget) { super(); this.child = child; }
  getProps() { return {}; }
}

class TestColumn extends MultiChildLayout {
  readonly type = "Column";
  private gap: number;
  constructor(children: Widget[], gap = 0) {
    super();
    this.children = children;
    this.gap = gap;
  }
  getProps() { return { gap: this.gap }; }
}

// ── 2.1: Widget base classes ────────────────────────────────

describe("Widget base classes", () => {
  it("PrimitiveWidget has correct kind/childMode", () => {
    const t = new TestText("hello");
    expect(t.kind).toBe("primitive");
    expect(t.childMode).toBe("none");
    expect(t.type).toBe("Text");
  });

  it("SingleChildLayout has correct kind/childMode", () => {
    const c = new TestContainer();
    expect(c.kind).toBe("layout");
    expect(c.childMode).toBe("single");
  });

  it("MultiChildLayout has correct kind/childMode", () => {
    const col = new TestColumn([]);
    expect(col.kind).toBe("layout");
    expect(col.childMode).toBe("multi");
  });
});

// ── 2.2: ComponentNode wire format ──────────────────────────

describe("ComponentNode wire format", () => {
  it("encodes primitive widget to valid node shape", () => {
    const encoder = new Encoder();
    encoder.addNode(new TestText("hello"));
    const nodes = encoder.getNodes();

    expect(nodes).toHaveLength(1);
    const node = nodes[0];
    expect(node).toHaveProperty("id");
    expect(node).toHaveProperty("type", "Text");
    expect(node).toHaveProperty("kind", "primitive");
    expect(node).toHaveProperty("childMode", "none");
    expect(node).toHaveProperty("props");
    expect(node).toHaveProperty("children");
    expect(node).toHaveProperty("watches");
    expect(node.children).toEqual([]);
  });
});

// ── 2.3: Encoder class ─────────────────────────────────────

describe("Encoder", () => {
  it("generates incremental IDs", () => {
    const encoder = new Encoder();
    const id1 = encoder.addNode(new TestText("a"));
    const id2 = encoder.addNode(new TestText("b"));
    expect(id1).toBe("0");
    expect(id2).toBe("1");
  });

  it("encodes single-child layout", () => {
    const encoder = new Encoder();
    const container = new TestContainer(new TestText("inner"));
    encoder.addNode(container);
    const nodes = encoder.getNodes();

    expect(nodes).toHaveLength(2);
    // child encoded first, then parent
    const textNode = nodes.find(n => n.type === "Text")!;
    const containerNode = nodes.find(n => n.type === "Container")!;
    expect(containerNode.children).toEqual([textNode.id]);
  });

  it("encodes multi-child layout", () => {
    const encoder = new Encoder();
    const col = new TestColumn([
      new TestText("a"),
      new TestText("b"),
      new TestText("c"),
    ]);
    encoder.addNode(col);
    const nodes = encoder.getNodes();

    expect(nodes).toHaveLength(4);
    const colNode = nodes.find(n => n.type === "Column")!;
    expect(colNode.children).toHaveLength(3);
  });

  it("encodes deeply nested tree", () => {
    let widget: Widget = new TestText("leaf");
    for (let i = 0; i < 10; i++) {
      widget = new TestContainer(widget);
    }
    const encoder = new Encoder();
    encoder.addNode(widget);
    const nodes = encoder.getNodes();

    // 10 containers + 1 text = 11 nodes
    expect(nodes).toHaveLength(11);
  });

  it("preserves props", () => {
    const encoder = new Encoder();
    encoder.addNode(new TestColumn([], 16));
    const node = encoder.getNodes().find(n => n.type === "Column")!;
    expect(node.props).toEqual({ gap: 16 });
  });

  it("auto-extracts watches from Value props", () => {
    const text = new TestText(V.pageState("username"));
    const encoder = new Encoder();
    encoder.addNode(text);
    const node = encoder.getNodes()[0];
    expect(node.watches).toEqual(["username"]);
  });

  it("preserves actions", () => {
    const text = new TestText("click");
    text.actions = { onTap: Navigate("/home") };
    const encoder = new Encoder();
    encoder.addNode(text);
    const node = encoder.getNodes()[0];
    expect(node.actions?.onTap).toEqual({ type: "navigate", route: "/home", params: undefined });
  });
});

// ── 2.4: Value types ────────────────────────────────────────

describe("V.* constructors", () => {
  it("V.static", () => {
    expect(V.static("hello")).toEqual({ type: "static", value: "hello" });
    expect(V.static(42)).toEqual({ type: "static", value: 42 });
    expect(V.static(true)).toEqual({ type: "static", value: true });
    expect(V.static(null)).toEqual({ type: "static", value: null });
  });

  it("V.pageState", () => {
    expect(V.pageState("count")).toEqual({ type: "state", key: "count", scope: "page" });
  });

  it("V.appState", () => {
    expect(V.appState("user.token")).toEqual({ type: "state", key: "user.token", scope: "app" });
  });

  it("V.info", () => {
    expect(V.info("platform")).toEqual({ type: "info", key: "platform" });
  });

  it("V.request", () => {
    expect(V.request("id")).toEqual({ type: "request", key: "id" });
  });

  it("V.transform", () => {
    const v = V.transform(V.pageState("price"), [
      { type: "multiply", by: V.pageState("qty") },
      { type: "formatCurrency", currency: "USD" },
    ]);
    expect(v.type).toBe("transform");
    expect(v.input).toEqual(V.pageState("price"));
    expect(v.by).toHaveLength(2);
  });

  it("V.when", () => {
    const v = V.when(
      [{ when: Expr.gt(V.pageState("stock"), V.static(0)), then: V.static("In Stock") }],
      V.static("Out of Stock"),
    );
    expect(v.type).toBe("conditional");
    expect(v.branches).toHaveLength(1);
    expect(v.else).toEqual(V.static("Out of Stock"));
  });
});

// ── 2.5: Transform types ───────────────────────────────────

describe("Transform types", () => {
  it("string transforms have correct shape", () => {
    const t = V.transform(V.pageState("name"), [
      { type: "toUpperCase" },
      { type: "template", template: "Hello, {{value}}!" },
      { type: "substring", start: 0, length: 10 },
    ]);
    expect(t.by).toHaveLength(3);
    expect(t.by[0].type).toBe("toUpperCase");
    expect(t.by[1].type).toBe("template");
    expect(t.by[2].type).toBe("substring");
  });

  it("number transforms have correct shape", () => {
    const t = V.transform(V.pageState("price"), [
      { type: "multiply", by: V.static(1.1) },
      { type: "round" },
      { type: "toFixed", decimals: 2 },
    ]);
    expect(t.by).toHaveLength(3);
  });

  it("collection transforms have correct shape", () => {
    const t = V.transform(V.pageState("items"), [
      { type: "length" },
    ]);
    expect(t.by[0].type).toBe("length");
  });

  it("format transforms have correct shape", () => {
    const t = V.transform(V.pageState("amount"), [
      { type: "formatCurrency", currency: "EUR", decimals: 2 },
    ]);
    expect(t.by[0]).toEqual({ type: "formatCurrency", currency: "EUR", decimals: 2 });
  });
});

// ── 2.6: BoolExpr types ────────────────────────────────────

describe("Expr.* constructors", () => {
  it("comparison operators", () => {
    expect(Expr.eq(V.pageState("a"), V.static(1))).toEqual({
      op: "eq", left: V.pageState("a"), right: V.static(1),
    });
    expect(Expr.neq(V.pageState("a"), V.static(1)).op).toBe("neq");
    expect(Expr.gt(V.pageState("a"), V.static(1)).op).toBe("gt");
    expect(Expr.gte(V.pageState("a"), V.static(1)).op).toBe("gte");
    expect(Expr.lt(V.pageState("a"), V.static(1)).op).toBe("lt");
    expect(Expr.lte(V.pageState("a"), V.static(1)).op).toBe("lte");
  });

  it("auto-wraps non-Value right-hand side in V.static", () => {
    const expr = Expr.eq(V.pageState("count"), 42);
    expect(expr.right).toEqual({ type: "static", value: 42 });
  });

  it("logical operators", () => {
    const a = Expr.and(
      Expr.gt(V.pageState("age"), 18),
      Expr.eq(V.pageState("active"), true),
    );
    expect(a.op).toBe("and");
    expect(a.exprs).toHaveLength(2);

    const o = Expr.or(Expr.eq(V.pageState("x"), 1), Expr.eq(V.pageState("x"), 2));
    expect(o.op).toBe("or");

    const n = Expr.not(Expr.isNull(V.appState("token")));
    expect(n.op).toBe("not");
  });

  it("string operators", () => {
    expect(Expr.contains(V.pageState("tags"), "vip").op).toBe("contains");
    expect(Expr.startsWith(V.pageState("name"), "A").op).toBe("startsWith");
    expect(Expr.matches(V.pageState("email"), "^.+@.+$").op).toBe("matches");
  });

  it("isNull", () => {
    const expr = Expr.isNull(V.appState("token"));
    expect(expr).toEqual({ op: "isNull", value: V.appState("token") });
  });
});

// ── 2.7: V.extractWatches ──────────────────────────────────

describe("V.extractWatches", () => {
  it("static returns empty", () => {
    expect(V.extractWatches(V.static("hello"))).toEqual([]);
  });

  it("state returns key", () => {
    expect(V.extractWatches(V.pageState("count"))).toEqual(["count"]);
  });

  it("info/request return empty", () => {
    expect(V.extractWatches(V.info("platform"))).toEqual([]);
    expect(V.extractWatches(V.request("id"))).toEqual([]);
  });

  it("transform extracts from input and transform operands", () => {
    const v = V.transform(V.pageState("price"), [
      { type: "multiply", by: V.pageState("qty") },
    ]);
    const watches = V.extractWatches(v);
    expect(watches).toContain("price");
    expect(watches).toContain("qty");
  });

  it("conditional extracts from all branches", () => {
    const v = V.when(
      [
        {
          when: Expr.gt(V.pageState("stock"), V.static(0)),
          then: V.transform(V.pageState("price"), [
            { type: "multiply", by: V.pageState("qty") },
          ]),
        },
      ],
      V.pageState("fallback"),
    );
    const watches = V.extractWatches(v).sort();
    expect(watches).toEqual(["fallback", "price", "qty", "stock"]);
  });

  it("deduplicates keys", () => {
    const v = V.transform(V.pageState("x"), [
      { type: "add", by: V.pageState("x") },
    ]);
    expect(V.extractWatches(v)).toEqual(["x"]);
  });
});

// ── 2.9-2.10: Action types & helpers ────────────────────────

describe("Action helpers", () => {
  it("Navigate", () => {
    expect(Navigate("/home")).toEqual({ type: "navigate", route: "/home", params: undefined });
    expect(Navigate("/product", { id: V.static("42") })).toEqual({
      type: "navigate", route: "/product", params: { id: V.static("42") },
    });
  });

  it("GoBack", () => {
    expect(GoBack()).toEqual({ type: "goBack" });
  });

  it("SetState", () => {
    expect(SetState("count", V.static(0))).toEqual({
      type: "setState", scope: "page", key: "count", value: V.static(0),
    });
    expect(SetState("token", V.static("abc"), "app").scope).toBe("app");
  });

  it("ClearState", () => {
    expect(ClearState("cart")).toEqual({ type: "clearState", scope: "page", key: "cart" });
  });

  it("ServerAction", () => {
    expect(ServerAction("addToCart", { id: V.request("id") })).toEqual({
      type: "serverAction", id: "addToCart", params: { id: V.request("id") },
    });
  });

  it("CopyToClipboard", () => {
    expect(CopyToClipboard("hello")).toEqual({ type: "copyToClipboard", text: "hello" });
  });

  it("Share", () => {
    expect(Share("Title", "msg", "https://example.com")).toEqual({
      type: "share", title: "Title", message: "msg", url: "https://example.com",
    });
  });

  it("OpenUrl", () => {
    expect(OpenUrl("https://example.com")).toEqual({ type: "openUrl", url: "https://example.com" });
  });

  it("ShowSnackbar / ShowToast", () => {
    expect(ShowSnackbar("done", 3000)).toEqual({ type: "showSnackbar", message: "done", duration: 3000 });
    expect(ShowToast("hi")).toEqual({ type: "showToast", message: "hi" });
  });

  it("Sequential", () => {
    const a = Sequential(SetState("loading", V.static(true)), Navigate("/next"));
    expect(a.type).toBe("actionGroup");
    expect(a.mode).toBe("sequential");
    expect(a.actions).toHaveLength(2);
  });

  it("Parallel", () => {
    const a = Parallel(ServerAction("a"), ServerAction("b"));
    expect(a.mode).toBe("parallel");
    expect(a.actions).toHaveLength(2);
  });

  it("When (conditional action)", () => {
    const a = When(
      [{ when: Expr.eq(V.pageState("loggedIn"), true), then: Navigate("/dashboard") }],
      Navigate("/login"),
    );
    expect(a.type).toBe("conditionalAction");
    expect(a.branches).toHaveLength(1);
    expect(a.else).toEqual(Navigate("/login"));
  });
});

// ── 2.11: Context types (compile-time check) ───────────────

describe("Context types", () => {
  it("RequestInfo shape compiles", () => {
    const info: RequestInfo = {
      platform: "iOS",
      osVersion: "17.0",
      deviceModel: "iPhone 15",
      appVersion: "1.0.0",
      buildNumber: "1",
      screenSize: { width: 390, height: 844 },
      pixelDensity: 3,
      safeAreaInsets: { top: 47, bottom: 34, left: 0, right: 0 },
      locale: "en-US",
      timezone: "America/New_York",
      language: "en",
      networkType: "wifi",
      ipAddress: "10.0.0.1",
      routePath: "/home",
      routeParams: {},
      queryParams: {},
      authToken: "abc",
    };
    expect(info.platform).toBe("iOS");
  });

  it("PageContext shape compiles", () => {
    const ctx: PageContext = {
      requestInfo: {} as any,
      pageId: "home",
      routePath: "/home",
      routeParams: {},
      pageState: { count: 0 },
      appState: {},
    };
    expect(ctx.pageId).toBe("home");
  });

  it("RenderContext shape compiles", () => {
    const ctx: RenderContext = {
      requestInfo: {} as any,
      pageId: "home",
      infoData: { products: [] },
      pageState: {},
      appState: {},
    };
    expect(ctx.infoData).toEqual({ products: [] });
  });

  it("ActionContext shape compiles", () => {
    const ctx: ActionContext = {
      requestInfo: {} as any,
      pageState: {},
      appState: {},
      actionParams: { productId: 42 },
    };
    expect(ctx.actionParams.productId).toBe(42);
  });
});

// ── 2.12: State types (compile-time check) ──────────────────

describe("State types", () => {
  it("StateDefinition shape compiles", () => {
    const def: StateDefinition = { key: "count", scope: "page", initial: 0 };
    expect(def.scope).toBe("page");
  });

  it("PageState / AppState shapes compile", () => {
    const ps: PageState = { scope: "page", data: { count: 0 } };
    const as_: AppState = { scope: "app", data: { token: "abc" } };
    expect(ps.scope).toBe("page");
    expect(as_.scope).toBe("app");
  });
});
