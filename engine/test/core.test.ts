import { describe, expect, it, afterAll, beforeAll } from "bun:test";
import {
  Page,
  PageDefinition,
  runPipeline,
  Flow,
  App,
  Engine,
  extractRequestInfo,
} from "../src/core";
import { V } from "../src/types";
import type { PageContext } from "../src/types/context";
import { PrimitiveWidget } from "../src/types/widget";
import {
  Scaffold,
  AppBar,
  Text,
  Center,
} from "../src/components";
import type { PageResponse } from "../src/core/page";

// ── Test Helpers ───────────────────────────────────────────

class SimpleText extends PrimitiveWidget {
  readonly type = "Text";
  constructor(private data: string) { super(); }
  getProps() { return { data: this.data }; }
}

// ── 5.2: Page abstract class ──────────────────────────────

describe("5.2: Page abstract class", () => {
  it("has 4 lifecycle methods", () => {
    class TestPage extends Page {
      readonly id = "test";
      readonly title = "Test";
      render() { return new SimpleText("hi"); }
    }
    const page = new TestPage();
    expect(typeof page.getInfoData).toBe("function");
    expect(typeof page.getState).toBe("function");
    expect(typeof page.render).toBe("function");
    expect(typeof page.postRender).toBe("function");
  });

  it("defaults return sensible values", async () => {
    class TestPage extends Page {
      readonly id = "test";
      readonly title = "Test";
      render() { return new SimpleText("hi"); }
    }
    const page = new TestPage();
    const ctx = makeContext();
    expect(await page.getInfoData(ctx)).toBeUndefined();
    expect(page.getState(ctx)).toEqual([]);
    const dummyResponse = { pageId: "test", title: "Test", state: [], components: [] };
    page.postRender(ctx, dummyResponse);
    // default postRender is a no-op — response unchanged
    expect(dummyResponse.pageId).toBe("test");
  });
});

// ── 5.3: PageDefinition builder ───────────────────────────

describe("5.3: PageDefinition builder", () => {
  it("creates a Page from config", () => {
    const page = PageDefinition.create({
      id: "home",
      title: "Home",
      render: () => new SimpleText("hello"),
    });
    expect(page.id).toBe("home");
    expect(page.title).toBe("Home");
  });

  it("supports static state array", () => {
    const page = PageDefinition.create({
      id: "home",
      title: "Home",
      state: [{ key: "count", scope: "page", initial: 0 }],
      render: () => new SimpleText("hello"),
    });
    expect(page.getState(makeContext())).toEqual([
      { key: "count", scope: "page", initial: 0 },
    ]);
  });

  it("supports state as a function", () => {
    const page = PageDefinition.create({
      id: "home",
      title: "Home",
      state: (ctx) => [{ key: "path", scope: "page", initial: ctx.routePath }],
      render: () => new SimpleText("hello"),
    });
    const state = page.getState(makeContext("/foo"));
    expect(state[0].initial).toBe("/foo");
  });

  it("supports getInfoData", async () => {
    const page = PageDefinition.create({
      id: "home",
      title: "Home",
      getInfoData: async () => ({ items: [1, 2, 3] }),
      render: () => new SimpleText("hello"),
    });
    const info = await page.getInfoData(makeContext());
    expect(info).toEqual({ items: [1, 2, 3] });
  });

  it("supports postRender that mutates response", () => {
    const page = PageDefinition.create({
      id: "home",
      title: "Home",
      render: () => new SimpleText("hello"),
      postRender: (_ctx, response) => {
        response.refreshInterval = 5000;
        response.title = "Modified";
      },
    });
    const response = { pageId: "home", title: "Home", state: [] as any[], components: [] as any[] };
    page.postRender(makeContext(), response);
    expect((response as any).refreshInterval).toBe(5000);
    expect(response.title).toBe("Modified");
  });
});

// ── 5.4: Pipeline executor ────────────────────────────────

describe("5.4: Pipeline executor", () => {
  it("runs all 4 stages in order", async () => {
    const order: string[] = [];
    const page = PageDefinition.create({
      id: "test",
      title: "Test",
      getInfoData: async () => { order.push("getInfoData"); return { v: 1 }; },
      state: () => { order.push("getState"); return []; },
      render: () => { order.push("render"); return new SimpleText("done"); },
      postRender: () => { order.push("postRender"); },
    });

    await runPipeline(page, makeContext());
    expect(order).toEqual(["getInfoData", "getState", "render", "postRender"]);
  });

  it("returns correct PageResponse shape", async () => {
    const page = PageDefinition.create({
      id: "home",
      title: "Home Page",
      state: [{ key: "count", scope: "page", initial: 0 }],
      render: () => new SimpleText("hello"),
    });

    const response = await runPipeline(page, makeContext());
    expect(response.pageId).toBe("home");
    expect(response.title).toBe("Home Page");
    expect(response.state).toHaveLength(1);
    expect(response.components).toHaveLength(1);
    expect(response.components[0].type).toBe("Text");
  });

  it("passes infoData to render", async () => {
    const page = PageDefinition.create({
      id: "test",
      title: "Test",
      getInfoData: async () => "fetched-data",
      render: (_ctx, info) => new SimpleText(info as string),
    });

    const response = await runPipeline(page, makeContext());
    expect(response.components[0].props.data).toBe("fetched-data");
  });

  it("initializes page state from definitions", async () => {
    let capturedCtx: PageContext | undefined;
    const page = PageDefinition.create({
      id: "test",
      title: "Test",
      state: [{ key: "count", scope: "page", initial: 42 }],
      render: (ctx) => { capturedCtx = ctx; return new SimpleText("hi"); },
    });

    await runPipeline(page, makeContext());
    expect(capturedCtx!.pageState.count).toBe(42);
  });
});

// ── 5.6: Flow class ──────────────────────────────────────

describe("5.6: Flow class", () => {
  it("creates a Flow with name and routes", () => {
    const flow = Flow.create({
      name: "main",
      routes: [{ path: "home", page: makePage("home") }],
    });
    expect(flow.name).toBe("main");
  });

  it("resolves simple route", () => {
    const page = makePage("home");
    const flow = Flow.create({
      name: "main",
      routes: [{ path: "home", page }],
    });
    const match = flow.resolve("home");
    expect(match).toBeDefined();
    expect(match!.page).toBe(page);
    expect(match!.params).toEqual({});
  });

  it("returns undefined for no match", () => {
    const flow = Flow.create({
      name: "main",
      routes: [{ path: "home", page: makePage("home") }],
    });
    expect(flow.resolve("settings")).toBeUndefined();
  });
});

// ── 5.7: Flow route matching with params ──────────────────

describe("5.7: route matching with params", () => {
  it("extracts params from dynamic segments", () => {
    const page = makePage("product");
    const flow = Flow.create({
      name: "shop",
      routes: [{ path: "product/:id", page }],
    });
    const match = flow.resolve("product/42");
    expect(match).toBeDefined();
    expect(match!.params).toEqual({ id: "42" });
  });

  it("extracts multiple params", () => {
    const page = makePage("order");
    const flow = Flow.create({
      name: "shop",
      routes: [{ path: "user/:userId/order/:orderId", page }],
    });
    const match = flow.resolve("user/abc/order/123");
    expect(match).toBeDefined();
    expect(match!.params).toEqual({ userId: "abc", orderId: "123" });
  });

  it("does not match wrong segment count", () => {
    const flow = Flow.create({
      name: "shop",
      routes: [{ path: "product/:id", page: makePage("product") }],
    });
    expect(flow.resolve("product")).toBeUndefined();
    expect(flow.resolve("product/42/extra")).toBeUndefined();
  });
});

// ── 5.8: Nested route resolution ──────────────────────────

describe("5.8: nested route resolution", () => {
  it("resolves nested child route", () => {
    const detailPage = makePage("detail");
    const flow = Flow.create({
      name: "home",
      routes: [
        {
          path: "home",
          page: makePage("home"),
          children: [
            { path: "details", page: detailPage },
          ],
        },
      ],
    });
    const match = flow.resolve("home/details");
    expect(match).toBeDefined();
    expect(match!.page).toBe(detailPage);
  });

  it("resolves deeply nested routes", () => {
    const leaf = makePage("leaf");
    const flow = Flow.create({
      name: "deep",
      routes: [
        {
          path: "a",
          page: makePage("a"),
          children: [
            {
              path: "b",
              page: makePage("b"),
              children: [{ path: "c", page: leaf }],
            },
          ],
        },
      ],
    });
    const match = flow.resolve("a/b/c");
    expect(match).toBeDefined();
    expect(match!.page).toBe(leaf);
  });

  it("nested route with params", () => {
    const detailPage = makePage("detail");
    const flow = Flow.create({
      name: "shop",
      routes: [
        {
          path: "category/:catId",
          page: makePage("category"),
          children: [
            { path: "product/:prodId", page: detailPage },
          ],
        },
      ],
    });
    const match = flow.resolve("category/electronics/product/42");
    expect(match).toBeDefined();
    expect(match!.params).toEqual({ catId: "electronics", prodId: "42" });
  });

  it("collects all route info (hierarchical)", () => {
    const flow = Flow.create({
      name: "app",
      routes: [
        {
          path: "home",
          page: makePage("home"),
          children: [{ path: "details", page: makePage("details") }],
        },
        { path: "settings", page: makePage("settings") },
      ],
    });
    const info = flow.getRouteInfo();
    const topPaths = info.map((r) => r.path);
    expect(topPaths).toContain("home");
    expect(topPaths).toContain("settings");
    // Children are nested, not flattened
    expect(info[0].children).toHaveLength(1);
    expect(info[0].children![0].path).toBe("home/details");
    // default requiredAppState is empty
    expect(info[0].requiredAppState).toEqual([]);
  });

  it("route info includes requiredAppState from page", () => {
    const page = PageDefinition.create({
      id: "profile",
      title: "Profile",
      appState: ["user.name", "theme"],
      render: () => new SimpleText("profile"),
    });
    const flow = Flow.create({
      name: "main",
      routes: [{ path: "profile", page }],
    });
    const info = flow.getRouteInfo();
    expect(info[0].requiredAppState).toEqual(["user.name", "theme"]);
  });
});

// ── 5.9: App class ────────────────────────────────────────

describe("5.9: App class", () => {
  it("creates app with id, name, flows", () => {
    const app = App.create({
      id: "myapp",
      name: "My App",
      flows: [],
    });
    expect(app.id).toBe("myapp");
    expect(app.name).toBe("My App");
  });

  it("resolves page across flows", () => {
    const homePage = makePage("home");
    const settingsPage = makePage("settings");

    const app = App.create({
      id: "myapp",
      name: "My App",
      flows: [
        Flow.create({ name: "main", routes: [{ path: "home", page: homePage }] }),
        Flow.create({ name: "settings", routes: [{ path: "settings", page: settingsPage }] }),
      ],
    });

    expect(app.resolve("home")?.page).toBe(homePage);
    expect(app.resolve("settings")?.page).toBe(settingsPage);
    expect(app.resolve("unknown")).toBeUndefined();
  });

  it("returns nav config", async () => {
    const app = App.create({
      id: "myapp",
      name: "My App",
      flows: [
        Flow.create({ name: "main", routes: [{ path: "home", page: makePage("home") }] }),
      ],
    });

    const config = await app.getNavConfig();
    expect(config.appId).toBe("myapp");
    expect(config.appName).toBe("My App");
    expect(config.flows).toHaveLength(1);
    expect(config.flows[0].name).toBe("main");
    expect(config.flows[0].routes[0].path).toBe("home");
    expect(config.flows[0].routes[0].requiredAppState).toEqual([]);
  });
});

// ── 5.10: Engine class ────────────────────────────────────

describe("5.10: Engine class", () => {
  it("registers apps and starts server", async () => {
    const engine = new Engine();
    const app = App.create({ id: "test", name: "Test", flows: [] });
    engine.registerApp(app);
    const server = await engine.start({ port: 0, cache: false });
    expect(server.port).toBeGreaterThan(0);
    engine.stop();
  });
});

// ── 5.12: RequestInfo extraction ──────────────────────────

describe("5.12: RequestInfo extraction", () => {
  it("extracts query params", () => {
    const req = new Request("http://localhost/test?foo=bar&baz=42");
    const info = extractRequestInfo(req, {});
    expect(info.queryParams).toEqual({ foo: "bar", baz: "42" });
  });

  it("extracts route params", () => {
    const req = new Request("http://localhost/test");
    const info = extractRequestInfo(req, { id: "99" });
    expect(info.routeParams).toEqual({ id: "99" });
  });

  it("extracts auth token from Bearer header", () => {
    const req = new Request("http://localhost/test", {
      headers: { Authorization: "Bearer my-token-123" },
    });
    const info = extractRequestInfo(req, {});
    expect(info.authToken).toBe("my-token-123");
  });

  it("extracts platform from x-orca headers", () => {
    const req = new Request("http://localhost/test", {
      headers: { "x-orca-platform": "Android" },
    });
    const info = extractRequestInfo(req, {});
    expect(info.platform).toBe("Android");
  });

  it("uses defaults for missing headers", () => {
    const req = new Request("http://localhost/test");
    const info = extractRequestInfo(req, {});
    expect(info.platform).toBe("iOS");
    expect(info.locale).toBe("en_US");
    expect(info.timezone).toBe("UTC");
  });
});

// ── 5.13 + 5.14: Integration test (HTTP) ──────────────────

describe("5.14: HTTP integration test", () => {
  const homePage = PageDefinition.create({
    id: "home",
    title: "Counter",
    state: [{ key: "count", scope: "page", initial: 0 }],
    render: () =>
      Scaffold.new({
        appBar: AppBar.new({ title: Text.new({ data: "Counter" }) }),
        body: Center.new({
          child: Text.new({
            data: V.transform(V.pageState("count"), [{ type: "toString" }]),
          }),
        }),
      }),
  });

  const homeFlow = Flow.create({
    name: "home",
    routes: [{ path: "home", page: homePage }],
  });

  const counterApp = App.create({
    id: "myapp",
    name: "Counter App",
    flows: [homeFlow],
  });

  const engine = new Engine();
  engine.registerApp(counterApp);
  let server: Awaited<ReturnType<Engine["start"]>>;

  beforeAll(async () => {
    server = await engine.start({ port: 0, cache: false });
  });
  afterAll(() => engine.stop());

  it("GET /health returns 200", async () => {
    const res = await fetch(`http://localhost:${server.port}/health`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { status: string };
    expect(body.status).toBe("ok");
  });

  it("GET /api/v1/app/myapp/page/home returns page JSON", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/myapp/page/home`);
    expect(res.status).toBe(200);
    const body: PageResponse = (await res.json()) as PageResponse;

    expect(body.pageId).toBe("home");
    expect(body.title).toBe("Counter");
    expect(body.state).toHaveLength(1);
    expect(body.state[0].key).toBe("count");
    expect(Array.isArray(body.components)).toBe(true);
    expect(body.components.length).toBeGreaterThan(0);

    // Root should be Scaffold
    expect(body.components[0].type).toBe("Scaffold");
  });

  it("GET /api/v1/app/myapp/config returns nav config", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/myapp/config`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { appId: string; appName: string; flows: any[] };

    expect(body.appId).toBe("myapp");
    expect(body.appName).toBe("Counter App");
    expect(body.flows).toHaveLength(1);
    expect(body.flows[0].routes[0].path).toBe("home");
    expect(body.flows[0].routes[0].requiredAppState).toEqual([]);
  });

  it("GET unknown app returns 404", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/noapp/page/home`);
    expect(res.status).toBe(404);
  });

  it("GET unknown page returns 404", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/myapp/page/nonexistent`);
    expect(res.status).toBe(404);
  });

  it("GET unknown route returns 404", async () => {
    const res = await fetch(`http://localhost:${server.port}/totally/unknown`);
    expect(res.status).toBe(404);
  });

  it("page response components have correct wire format", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/myapp/page/home`);
    const body: PageResponse = (await res.json()) as PageResponse;

    for (const node of body.components) {
      expect(node).toHaveProperty("id");
      expect(node).toHaveProperty("type");
      expect(node).toHaveProperty("kind");
      expect(node).toHaveProperty("childMode");
      expect(node).toHaveProperty("props");
      expect(node).toHaveProperty("children");
      expect(node).toHaveProperty("watches");
    }
  });
});

// ── appState from request body ─────────────────────────────

describe("appState: client sends only required keys", () => {
  let capturedAppState: Record<string, unknown> = {};

  const profilePage = PageDefinition.create({
    id: "profile",
    title: "Profile",
    appState: ["user.name", "theme"],
    render: (ctx) => {
      capturedAppState = ctx.appState;
      return new SimpleText("profile");
    },
  });

  const profileFlow = Flow.create({
    name: "profile",
    routes: [{ path: "profile", page: profilePage }],
  });

  const app = App.create({
    id: "stateapp",
    name: "State App",
    flows: [profileFlow],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<Engine["start"]>>;

  beforeAll(async () => {
    server = await engine.start({ port: 0, cache: false });
  });
  afterAll(() => engine.stop());

  it("populates appState from POST body with declared keys", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/stateapp/page/profile`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        appState: { "user.name": "Amr", "theme": "dark", "secret": "ignored" },
      }),
    });
    expect(res.status).toBe(200);
    expect(capturedAppState["user.name"]).toBe("Amr");
    expect(capturedAppState["theme"]).toBe("dark");
    expect(capturedAppState["secret"]).toBeUndefined();
  });

  it("appState is empty on GET (no body)", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/stateapp/page/profile`);
    expect(res.status).toBe(200);
    expect(capturedAppState).toEqual({});
  });

  it("config endpoint exposes requiredAppState per route", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/stateapp/config`);
    const body = (await res.json()) as { appId: string; appName: string; flows: any[] };
    expect(body.flows[0].routes[0].requiredAppState).toEqual(["user.name", "theme"]);
  });
});

// ── Helpers ────────────────────────────────────────────────

function makeContext(routePath = "/"): PageContext {
  return {
    requestInfo: {
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
      routePath,
      routeParams: {},
      queryParams: {},
    },
    pageId: "test",
    routePath,
    routeParams: {},
    pageState: {},
    appState: {},
  };
}

function makePage(id: string): Page {
  return PageDefinition.create({
    id,
    title: id,
    render: () => new SimpleText(`page:${id}`),
  });
}
