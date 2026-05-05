import { describe, expect, it, afterAll, beforeAll, afterEach } from "bun:test";
import { App, Engine, Flow, PageDefinition } from "../src/core";
import type { Middleware, MiddlewareContext } from "../src/core/middleware";
import { authMiddleware } from "../src/middlewares/auth";
import { rateLimitMiddleware } from "../src/middlewares/rate-limit";
import { corsMiddleware } from "../src/middlewares/cors";
import { loggingMiddleware } from "../src/middlewares/logging";
import { recoveryMiddleware } from "../src/middlewares/recovery";
import { PrimitiveWidget } from "../src/types/widget";

// ── Helpers ─────────────────────────────────────────────────

class SimpleText extends PrimitiveWidget {
  readonly type = "Text";
  constructor(private data: string) { super(); }
  getProps() { return { data: this.data }; }
}

function createTestApp(opts: {
  middlewares?: Middleware[];
  configuration?: Record<string, unknown>;
  globalErrorHandler?: (err: unknown, ctx: MiddlewareContext) => void;
} = {}) {
  const page = PageDefinition.create({
    id: "home",
    title: "Home",
    render: () => new SimpleText("hello"),
  });

  const flow = Flow.create({
    name: "main",
    routes: [{ path: "home", page }],
  });

  const app = App.create({
    id: "test-app",
    name: "Test App",
    flows: [flow],
    configuration: opts.configuration,
    globalErrorHandler: opts.globalErrorHandler,
  });

  for (const mw of opts.middlewares ?? []) {
    app.registerMiddleware(mw);
  }

  return app;
}

async function startEngine(app: App): Promise<{ engine: Engine; port: number }> {
  const engine = new Engine();
  engine.registerApp(app);
  const server = await engine.start({ port: 0, cache: false });
  return { engine, port: server.port };
}

// ── 16.1: Middleware interface ───────────────────────────────

describe("16.1: Middleware interface", () => {
  it("has { name, onRequest, onResponse } pattern", () => {
    const mw: Middleware = {
      name: "test",
      onRequest: () => undefined,
      onResponse: (_ctx, res) => res,
    };
    expect(mw.name).toBe("test");
    expect(typeof mw.onRequest).toBe("function");
    expect(typeof mw.onResponse).toBe("function");
  });

  it("allows optional onRequest and onResponse", () => {
    const mw: Middleware = { name: "noop" };
    expect(mw.onRequest).toBeUndefined();
    expect(mw.onResponse).toBeUndefined();
  });
});

// ── 16.2: App.registerMiddleware() ──────────────────────────

describe("16.2: App.registerMiddleware()", () => {
  it("registers middlewares in order", () => {
    const app = createTestApp();
    const mw1: Middleware = { name: "first" };
    const mw2: Middleware = { name: "second" };
    app.registerMiddleware(mw1).registerMiddleware(mw2);
    const mws = app.getMiddlewares();
    expect(mws).toHaveLength(2);
    expect(mws[0]!.name).toBe("first");
    expect(mws[1]!.name).toBe("second");
  });

  it("executes onRequest in registration order", async () => {
    const order: string[] = [];
    const mw1: Middleware = { name: "a", onRequest: () => { order.push("a"); } };
    const mw2: Middleware = { name: "b", onRequest: () => { order.push("b"); } };

    const app = createTestApp({ middlewares: [mw1, mw2] });
    const { engine, port } = await startEngine(app);

    await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    engine.stop();

    expect(order).toEqual(["a", "b"]);
  });

  it("short-circuits on first middleware returning a response", async () => {
    const order: string[] = [];
    const blocker: Middleware = {
      name: "blocker",
      onRequest: () => {
        order.push("blocker");
        return { status: 403, body: { error: "Blocked" } };
      },
    };
    const after: Middleware = {
      name: "after",
      onRequest: () => { order.push("after"); },
    };

    const app = createTestApp({ middlewares: [blocker, after] });
    const { engine, port } = await startEngine(app);

    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    engine.stop();

    expect(res.status).toBe(403);
    expect(order).toEqual(["blocker"]);
  });
});

// ── 16.3: Auth middleware ───────────────────────────────────

describe("16.3: Auth middleware", () => {
  let engine: Engine;
  let port: number;

  beforeAll(async () => {
    const app = createTestApp({
      middlewares: [
        authMiddleware({ apiKeys: ["valid-key-123"], exclude: ["/config"] }),
      ],
    });
    const result = await startEngine(app);
    engine = result.engine;
    port = result.port;
  });

  afterAll(() => engine.stop());

  it("returns 401 on missing API key", async () => {
    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    expect(res.status).toBe(401);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("Missing API key");
  });

  it("returns 401 on invalid API key", async () => {
    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`, {
      headers: { "x-api-key": "wrong-key" },
    });
    expect(res.status).toBe(401);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("Invalid API key");
  });

  it("passes with valid API key", async () => {
    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`, {
      headers: { "x-api-key": "valid-key-123" },
    });
    expect(res.status).toBe(200);
  });

  it("excludes configured paths from auth", async () => {
    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/config`);
    expect(res.status).toBe(200);
  });
});

// ── 16.4: Rate limit middleware ─────────────────────────────

describe("16.4: Rate limit middleware", () => {
  it("returns 429 when rate exceeded", async () => {
    const app = createTestApp({
      middlewares: [rateLimitMiddleware({ maxPerSecond: 2, burst: 2 })],
    });
    const { engine, port } = await startEngine(app);

    // First 2 requests should succeed
    const r1 = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    const r2 = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    expect(r1.status).toBe(200);
    expect(r2.status).toBe(200);

    // 3rd request should be rate limited
    const r3 = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    expect(r3.status).toBe(429);
    const body = await r3.json() as { error: string };
    expect(body.error).toBe("Too many requests");
    expect(r3.headers.get("Retry-After")).toBe("1");

    engine.stop();
  });
});

// ── 16.5: CORS middleware ───────────────────────────────────

describe("16.5: CORS middleware", () => {
  let engine: Engine;
  let port: number;

  beforeAll(async () => {
    const app = createTestApp({
      middlewares: [
        corsMiddleware({
          origins: ["https://example.com"],
          credentials: true,
        }),
      ],
    });
    const result = await startEngine(app);
    engine = result.engine;
    port = result.port;
  });

  afterAll(() => engine.stop());

  it("handles preflight OPTIONS with 204", async () => {
    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`, {
      method: "OPTIONS",
      headers: { Origin: "https://example.com" },
    });
    expect(res.status).toBe(204);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("https://example.com");
    expect(res.headers.get("Access-Control-Allow-Methods")).toContain("GET");
    expect(res.headers.get("Access-Control-Allow-Credentials")).toBe("true");
  });

  it("adds CORS headers to regular responses for allowed origin", async () => {
    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`, {
      headers: { Origin: "https://example.com" },
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("https://example.com");
  });

  it("does not add CORS headers for disallowed origin", async () => {
    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`, {
      headers: { Origin: "https://evil.com" },
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });
});

// ── 16.6: Logging middleware ────────────────────────────────

describe("16.6: Logging middleware", () => {
  it("adds X-Request-Id header to response", async () => {
    const app = createTestApp({ middlewares: [loggingMiddleware()] });
    const { engine, port } = await startEngine(app);

    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    expect(res.headers.get("X-Request-Id")).toBeTruthy();

    engine.stop();
  });
});

// ── 16.7: Recovery middleware ───────────────────────────────

describe("16.7: Recovery middleware", () => {
  it("engine returns 500 when middleware throws", async () => {
    const throwingMw: Middleware = {
      name: "thrower",
      onRequest: () => { throw new Error("boom"); },
    };

    const app = createTestApp({
      middlewares: [recoveryMiddleware(), throwingMw],
    });
    const { engine, port } = await startEngine(app);

    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    expect(res.status).toBe(500);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("Internal Server Error");

    engine.stop();
  });
});

// ── 16.8: App configuration ────────────────────────────────

describe("16.8: App configuration", () => {
  it("makes configuration accessible via App.configuration", () => {
    const app = createTestApp({
      configuration: { apiBaseUrl: "https://api.example.com", featureFlags: { dark: true } },
    });
    expect(app.configuration).toEqual({
      apiBaseUrl: "https://api.example.com",
      featureFlags: { dark: true },
    });
  });

  it("defaults to empty object", () => {
    const app = createTestApp();
    expect(app.configuration).toEqual({});
  });

  it("passes configuration to middleware context", async () => {
    let receivedConfig: Record<string, unknown> = {};
    const spy: Middleware = {
      name: "spy",
      onRequest: (ctx) => { receivedConfig = ctx.configuration; },
    };

    const app = createTestApp({
      middlewares: [spy],
      configuration: { apiBaseUrl: "https://api.test.com" },
    });
    const { engine, port } = await startEngine(app);

    await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    engine.stop();

    expect(receivedConfig).toEqual({ apiBaseUrl: "https://api.test.com" });
  });
});

// ── 16.9: Global error handler ──────────────────────────────

describe("16.9: Global error handler", () => {
  it("fires on unhandled middleware error", async () => {
    let caughtError: unknown = null;
    let caughtCtx: MiddlewareContext | null = null;

    const throwingMw: Middleware = {
      name: "thrower",
      onRequest: () => { throw new Error("middleware boom"); },
    };

    const app = createTestApp({
      middlewares: [throwingMw],
      globalErrorHandler: (err, ctx) => {
        caughtError = err;
        caughtCtx = ctx;
      },
    });
    const { engine, port } = await startEngine(app);

    const res = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`);
    engine.stop();

    expect(res.status).toBe(500);
    expect(caughtError).toBeInstanceOf(Error);
    expect((caughtError as Error).message).toBe("middleware boom");
    expect(caughtCtx).not.toBeNull();
    expect(caughtCtx!.appId).toBe("test-app");
  });
});

// ── 16.10: Full integration ─────────────────────────────────

describe("16.10: Middleware integration", () => {
  it("full pipeline: auth → rate-limit → cors → logging", async () => {
    const app = createTestApp({
      middlewares: [
        recoveryMiddleware(),
        loggingMiddleware(),
        corsMiddleware({ origins: ["https://app.test"] }),
        authMiddleware({ apiKeys: ["key-1"] }),
        rateLimitMiddleware({ maxPerSecond: 100 }),
      ],
    });
    const { engine, port } = await startEngine(app);

    // Unauthorized → 401
    const r1 = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`, {
      headers: { Origin: "https://app.test" },
    });
    expect(r1.status).toBe(401);
    // CORS still applied to error responses via onResponse
    expect(r1.headers.get("Access-Control-Allow-Origin")).toBe("https://app.test");
    // Logging still adds request ID
    expect(r1.headers.get("X-Request-Id")).toBeTruthy();

    // Authorized → 200
    const r2 = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`, {
      headers: { Origin: "https://app.test", "x-api-key": "key-1" },
    });
    expect(r2.status).toBe(200);
    expect(r2.headers.get("Access-Control-Allow-Origin")).toBe("https://app.test");
    expect(r2.headers.get("X-Request-Id")).toBeTruthy();

    // Preflight → 204
    const r3 = await fetch(`http://localhost:${port}/api/v1/app/test-app/page/home`, {
      method: "OPTIONS",
      headers: { Origin: "https://app.test" },
    });
    expect(r3.status).toBe(204);

    engine.stop();
  });
});
