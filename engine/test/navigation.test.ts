import { describe, expect, it, afterAll } from "bun:test";
import {
  App,
  Flow,
  PageDefinition,
  Engine,
} from "../src/core";
import type { AppNavConfig } from "../src/core/app";
import type { PageContext } from "../src/types/context";
import { PrimitiveWidget } from "../src/types/widget";
import { Text } from "../src/components";

// ── Helpers ────────────────────────────────────────────────

class SimpleText extends PrimitiveWidget {
  readonly type = "Text";
  constructor(private data: string) { super(); }
  getProps() { return { data: this.data }; }
}

function makePage(id: string) {
  return PageDefinition.create({
    id,
    title: id,
    render: () => new SimpleText(`page:${id}`),
  });
}

// ── 14.1: Navigation config from server ────────────────────

describe("14.1: Navigation config from server", () => {
  it("GET /config returns tabs and drawer items", async () => {
    const app = App.create({
      id: "navapp",
      name: "Nav App",
      navigation: {
        initialRoute: "/home",
        tabs: [
          { id: "home", label: "Home", icon: "home", initialRoute: "/home" },
          { id: "search", label: "Search", icon: "search", initialRoute: "/search" },
        ],
        drawerItems: [
          { id: "profile", label: "Profile", icon: "person", route: "/profile" },
        ],
      },
      flows: [
        Flow.create({ name: "home", routes: [{ path: "home", page: makePage("home") }] }),
        Flow.create({ name: "search", routes: [{ path: "search", page: makePage("search") }] }),
        Flow.create({ name: "profile", routes: [{ path: "profile", page: makePage("profile") }] }),
      ],
    });

    const engine = new Engine();
    engine.registerApp(app);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/navapp/config`);
      expect(res.status).toBe(200);
      const body = (await res.json()) as AppNavConfig;

      expect(body.appId).toBe("navapp");
      expect(body.initialRoute).toBe("/home");
      expect(body.tabs).toHaveLength(2);
      expect(body.tabs![0].id).toBe("home");
      expect(body.tabs![0].label).toBe("Home");
      expect(body.tabs![0].icon).toBe("home");
      expect(body.tabs![0].initialRoute).toBe("/home");
      expect(body.tabs![1].id).toBe("search");
      expect(body.drawerItems).toHaveLength(1);
      expect(body.drawerItems![0].id).toBe("profile");
      expect(body.drawerItems![0].route).toBe("/profile");
    } finally {
      engine.stop();
    }
  });

  it("GET /config returns initialRoute '/' when no navigation config", async () => {
    const app = App.create({
      id: "simple",
      name: "Simple",
      flows: [Flow.create({ name: "main", routes: [{ path: "home", page: makePage("home") }] })],
    });

    const engine = new Engine();
    engine.registerApp(app);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/simple/config`);
      const body = (await res.json()) as AppNavConfig;
      expect(body.initialRoute).toBe("/");
      expect(body.tabs).toBeUndefined();
      expect(body.drawerItems).toBeUndefined();
    } finally {
      engine.stop();
    }
  });

  it("config includes nested route children", async () => {
    const app = App.create({
      id: "nested",
      name: "Nested",
      navigation: { initialRoute: "/home" },
      flows: [
        Flow.create({
          name: "home",
          routes: [
            {
              path: "home",
              page: makePage("home"),
              children: [
                { path: "product/:id", page: makePage("product") },
              ],
            },
          ],
        }),
      ],
    });

    const engine = new Engine();
    engine.registerApp(app);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/nested/config`);
      const body = (await res.json()) as AppNavConfig;
      const homeRoute = body.flows[0].routes[0];
      expect(homeRoute.path).toBe("home");
      expect(homeRoute.children).toHaveLength(1);
      expect(homeRoute.children![0].path).toBe("home/product/:id");
    } finally {
      engine.stop();
    }
  });

  it("config includes redirect rules", async () => {
    const app = App.create({
      id: "redirect",
      name: "Redirect",
      navigation: { initialRoute: "/dashboard" },
      flows: [
        Flow.create({
          name: "main",
          routes: [
            {
              path: "dashboard",
              page: makePage("dashboard"),
              redirect: { when: "isLoggedIn", equals: false, to: "/login" },
            },
            { path: "login", page: makePage("login") },
          ],
        }),
      ],
    });

    const engine = new Engine();
    engine.registerApp(app);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/redirect/config`);
      const body = (await res.json()) as AppNavConfig;
      const dashRoute = body.flows[0].routes[0];
      expect(dashRoute.redirect).toBeDefined();
      expect(dashRoute.redirect!.when).toBe("isLoggedIn");
      expect(dashRoute.redirect!.equals).toBe(false);
      expect(dashRoute.redirect!.to).toBe("/login");
    } finally {
      engine.stop();
    }
  });
});

// ── 14.5: Route matching with deeplink params ──────────────

describe("14.5: route matching with deeplink params", () => {
  it("resolves /product/42 with id param", () => {
    const app = App.create({
      id: "shop",
      name: "Shop",
      flows: [
        Flow.create({
          name: "home",
          routes: [
            {
              path: "home",
              page: makePage("home"),
              children: [
                { path: "product/:id", page: makePage("product") },
              ],
            },
          ],
        }),
      ],
    });

    const match = app.resolve("home/product/42");
    expect(match).toBeDefined();
    expect(match!.page.id).toBe("product");
    expect(match!.params).toEqual({ id: "42" });
  });
});

// ── 14.7: onEnter / onExit hooks ────────────────────────────

describe("14.7: onEnter / onExit hooks", () => {
  it("onEnter fires during page pipeline", async () => {
    let hookCalled = false;
    let hookPageId = "";

    const app = App.create({
      id: "hookapp",
      name: "Hook App",
      flows: [
        Flow.create({
          name: "main",
          routes: [
            {
              path: "home",
              page: makePage("home"),
              hooks: {
                onEnter: (ctx) => {
                  hookCalled = true;
                  hookPageId = ctx.pageId;
                },
              },
            },
          ],
        }),
      ],
    });

    const engine = new Engine();
    engine.registerApp(app);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/hookapp/page/home`);
      expect(res.status).toBe(200);
      expect(hookCalled).toBe(true);
      expect(hookPageId).toBe("home");
    } finally {
      engine.stop();
    }
  });

  it("onExit fires via hook endpoint", async () => {
    let exitCalled = false;

    const app = App.create({
      id: "hookapp2",
      name: "Hook App 2",
      flows: [
        Flow.create({
          name: "main",
          routes: [
            {
              path: "home",
              page: makePage("home"),
              hooks: {
                onExit: () => { exitCalled = true; },
              },
            },
          ],
        }),
      ],
    });

    const engine = new Engine();
    engine.registerApp(app);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/hookapp2/hook`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type: "exit", path: "home" }),
      });
      expect(res.status).toBe(200);
      expect(exitCalled).toBe(true);
    } finally {
      engine.stop();
    }
  });

  it("hook endpoint returns ok for routes without hooks", async () => {
    const app = App.create({
      id: "hookapp3",
      name: "Hook App 3",
      flows: [
        Flow.create({
          name: "main",
          routes: [{ path: "home", page: makePage("home") }],
        }),
      ],
    });

    const engine = new Engine();
    engine.registerApp(app);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/hookapp3/hook`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type: "exit", path: "home" }),
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as { ok: boolean };
      expect(body.ok).toBe(true);
    } finally {
      engine.stop();
    }
  });
});

// ── 14.10: E-commerce config test ──────────────────────────

describe("14.10: E-commerce app config", () => {
  it("ecommerce app has correct navigation structure", async () => {
    // Import and register the ecommerce app
    const { ecommerceApp } = await import("../../examples/server/ecommerce");
    const engine = new Engine();
    engine.registerApp(ecommerceApp);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/ecommerce/config`);
      expect(res.status).toBe(200);
      const body = (await res.json()) as AppNavConfig;

      expect(body.appId).toBe("ecommerce");
      expect(body.initialRoute).toBe("/home");
      expect(body.tabs).toHaveLength(3);
      expect(body.tabs![0].id).toBe("home");
      expect(body.tabs![1].id).toBe("search");
      expect(body.tabs![2].id).toBe("cart");
      // Server-driven drawer and tab bar are component trees
      expect(body.tabBarComponents).toBeDefined();
      expect(body.tabBarComponents!.length).toBeGreaterThan(0);
      expect(body.tabBarComponents![0].type).toBe("Container");
      expect(body.drawerComponents).toBeDefined();
      expect(body.drawerComponents!.length).toBeGreaterThan(0);
      expect(body.drawerComponents![0].type).toBe("Drawer");
    } finally {
      engine.stop();
    }
  });

  it("ecommerce home page renders", async () => {
    const { ecommerceApp } = await import("../../examples/server/ecommerce");
    const engine = new Engine();
    engine.registerApp(ecommerceApp);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/ecommerce/page/home`);
      expect(res.status).toBe(200);
      const body = (await res.json()) as { pageId: string; components: any[] };
      expect(body.pageId).toBe("home");
      expect(body.components.length).toBeGreaterThan(0);
    } finally {
      engine.stop();
    }
  });

  it("ecommerce product detail resolves with params", async () => {
    const { ecommerceApp } = await import("../../examples/server/ecommerce");
    const engine = new Engine();
    engine.registerApp(ecommerceApp);
    const server = await engine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${server.port}/api/v1/app/ecommerce/page/home/product/1`);
      expect(res.status).toBe(200);
      const body = (await res.json()) as { pageId: string; components: any[] };
      expect(body.pageId).toBe("product-detail");
    } finally {
      engine.stop();
    }
  });
});
