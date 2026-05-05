import { describe, expect, it, afterAll } from "bun:test";
import {
  App,
  Flow,
  PageDefinition,
  Engine,
} from "../src/core";
import { PrimitiveWidget } from "../src/types/widget";

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

// ── 17.1: Version endpoint ─────────────────────────────────

describe("17.1: Version endpoint", () => {
  const app = App.create({
    id: "versionapp",
    name: "Version App",
    flows: [
      Flow.create({ name: "homeFlow", version: 3, routes: [{ path: "home", page: makePage("home") }] }),
      Flow.create({ name: "profileFlow", version: 1, routes: [{ path: "profile", page: makePage("profile") }] }),
    ],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<typeof engine.start>>;

  it("setup", async () => {
    server = await engine.start({ port: 0, cache: false });
  });

  afterAll(() => engine.stop());

  it("GET /version returns flow versions", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/versionapp/version`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { flows: Record<string, number> };
    expect(body.flows).toEqual({
      homeFlow: 3,
      profileFlow: 1,
    });
  });

  it("does not include forceUpdate when false", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/versionapp/version`);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.forceUpdate).toBeUndefined();
  });
});

describe("17.1: Version endpoint with forceUpdate", () => {
  const app = App.create({
    id: "forceapp",
    name: "Force App",
    forceUpdate: true,
    flows: [
      Flow.create({ name: "main", version: 2, routes: [{ path: "home", page: makePage("home") }] }),
    ],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<typeof engine.start>>;

  it("setup", async () => {
    server = await engine.start({ port: 0, cache: false });
  });

  afterAll(() => engine.stop());

  it("includes forceUpdate: true when set", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/forceapp/version`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { flows: Record<string, number>; forceUpdate: boolean };
    expect(body.forceUpdate).toBe(true);
    expect(body.flows.main).toBe(2);
  });
});

// ── 17.2: Static flow packaging ────────────────────────────

describe("17.2: Static flow packaging in config", () => {
  const app = App.create({
    id: "staticapp",
    name: "Static App",
    flows: [
      Flow.create({
        name: "staticFlow",
        version: 1,
        isStatic: true,
        routes: [
          { path: "home", page: makePage("home") },
          { path: "about", page: makePage("about") },
        ],
      }),
      Flow.create({
        name: "dynamicFlow",
        version: 1,
        routes: [{ path: "dashboard", page: makePage("dashboard") }],
      }),
    ],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<typeof engine.start>>;

  it("setup", async () => {
    server = await engine.start({ port: 0, cache: false });
  });

  afterAll(() => engine.stop());

  it("static flow includes pre-rendered pages", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/staticapp/config`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    const flows = body.flows as Array<{
      name: string;
      isStatic?: boolean;
      version?: number;
      pages?: Record<string, { pageId: string; title: string; components: unknown[] }>;
      routes: unknown[];
    }>;

    // Static flow
    const staticFlow = flows.find((f) => f.name === "staticFlow")!;
    expect(staticFlow.isStatic).toBe(true);
    expect(staticFlow.version).toBe(1);
    expect(staticFlow.pages).toBeDefined();
    expect(staticFlow.pages!["home"]).toBeDefined();
    expect(staticFlow.pages!["home"].pageId).toBe("home");
    expect(staticFlow.pages!["about"]).toBeDefined();
    expect(staticFlow.pages!["about"].pageId).toBe("about");

    // Dynamic flow should NOT have pages
    const dynamicFlow = flows.find((f) => f.name === "dynamicFlow")!;
    expect(dynamicFlow.isStatic).toBeUndefined();
    expect(dynamicFlow.pages).toBeUndefined();
  });

  it("isDynamic routes are excluded from static flow pages", async () => {
    const mixedApp = App.create({
      id: "mixedapp",
      name: "Mixed App",
      flows: [
        Flow.create({
          name: "mainFlow",
          version: 1,
          isStatic: true,
          routes: [
            { path: "home", page: makePage("home") },
            { path: "profile", page: makePage("profile"), isDynamic: true },
            { path: "settings", page: makePage("settings") },
          ],
        }),
      ],
    });

    const mixedEngine = new Engine();
    mixedEngine.registerApp(mixedApp);
    const mixedServer = await mixedEngine.start({ port: 0, cache: false });

    try {
      const res = await fetch(`http://localhost:${mixedServer.port}/api/v1/app/mixedapp/config`);
      const body = (await res.json()) as Record<string, unknown>;
      const flows = body.flows as Array<{
        name: string;
        pages?: Record<string, unknown>;
        routes: Array<{ path: string; isDynamic?: boolean }>;
      }>;

      const mainFlow = flows[0]!;
      // home and settings are pre-rendered, profile is NOT (isDynamic)
      expect(mainFlow.pages!["home"]).toBeDefined();
      expect(mainFlow.pages!["settings"]).toBeDefined();
      expect(mainFlow.pages!["profile"]).toBeUndefined();

      // isDynamic flag is present on the route info
      const profileRoute = mainFlow.routes.find((r) => r.path === "profile")!;
      expect(profileRoute.isDynamic).toBe(true);

      const homeRoute = mainFlow.routes.find((r) => r.path === "home")!;
      expect(homeRoute.isDynamic).toBeUndefined();
    } finally {
      mixedEngine.stop();
    }
  });

  it("static flow pages contain components", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/staticapp/config`);
    const body = (await res.json()) as Record<string, unknown>;
    const flows = body.flows as Array<{
      name: string;
      pages?: Record<string, { components: Array<{ type: string; props: Record<string, unknown> }> }>;
    }>;

    const staticFlow = flows.find((f) => f.name === "staticFlow")!;
    const homePage = staticFlow.pages!["home"];
    expect(homePage.components).toBeInstanceOf(Array);
    expect(homePage.components.length).toBeGreaterThan(0);
    expect(homePage.components[0].type).toBe("Text");
    expect(homePage.components[0].props.data).toBe("page:home");
  });
});
