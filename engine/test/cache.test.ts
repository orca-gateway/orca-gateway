import { describe, expect, it, afterAll, beforeAll, beforeEach } from "bun:test";
import { SQLiteCache } from "../src/core/sqlite-cache";
import {
  NoOpCache,
  buildCacheKey,
  generateETag,
  resolveCacheConfig,
} from "../src/core/cache";
import type { CacheProvider, CachePolicy, CachePolicyConfig } from "../src/core/cache";
import {
  PageDefinition,
  runPipeline,
  Flow,
  App,
  Engine,
} from "../src/core";
import type { PageContext } from "../src/types/context";
import { PrimitiveWidget } from "../src/types/widget";
import type { PageResponse } from "../src/core/page";

// ── Test Helpers ───────────────────────────────────────────

class SimpleText extends PrimitiveWidget {
  readonly type = "Text";
  constructor(private data: string) { super(); }
  getProps() { return { data: this.data }; }
}

function makeContext(
  routePath = "/",
  routeParams: Record<string, string> = {},
  overrides: Partial<PageContext> = {},
): PageContext {
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
      routeParams,
      queryParams: {},
    },
    pageId: "test",
    routePath,
    routeParams,
    pageState: {},
    appState: {},
    ...overrides,
  };
}

// ── 15.1: CacheProvider interface ─────────────────────────

describe("15.1: CacheProvider interface", () => {
  it("NoOpCache implements the interface", async () => {
    const cache: CacheProvider = new NoOpCache();
    expect(await cache.get("key")).toBeNull();
    await cache.set("key", "value");
    expect(await cache.get("key")).toBeNull();
    await cache.del("key");
    await cache.flush();
  });
});

// ── 15.2: SQLiteCache implementation ──────────────────────

describe("15.2: SQLiteCache implementation", () => {
  let cache: SQLiteCache;

  beforeEach(() => {
    cache = new SQLiteCache(":memory:");
  });

  it("set and get a value", async () => {
    await cache.set("key1", "hello");
    expect(await cache.get("key1")).toBe("hello");
  });

  it("returns null for missing key", async () => {
    expect(await cache.get("nonexistent")).toBeNull();
  });

  it("overwrites existing key", async () => {
    await cache.set("key1", "v1");
    await cache.set("key1", "v2");
    expect(await cache.get("key1")).toBe("v2");
  });

  it("deletes a key", async () => {
    await cache.set("key1", "v1");
    await cache.del("key1");
    expect(await cache.get("key1")).toBeNull();
  });

  it("flushes all keys", async () => {
    await cache.set("a", "1");
    await cache.set("b", "2");
    await cache.flush();
    expect(await cache.get("a")).toBeNull();
    expect(await cache.get("b")).toBeNull();
  });

  it("respects TTL expiry", async () => {
    await cache.set("ttl-key", "temp", 1);
    expect(await cache.get("ttl-key")).toBe("temp");
    await Bun.sleep(1100);
    expect(await cache.get("ttl-key")).toBeNull();
  });

  it("no TTL means no expiry", async () => {
    await cache.set("persist", "forever");
    expect(await cache.get("persist")).toBe("forever");
  });

  it("cleanup removes expired entries", async () => {
    await cache.set("exp", "value", 1);
    await Bun.sleep(1100);
    cache.cleanup();
    expect(await cache.get("exp")).toBeNull();
  });

  it("stores and retrieves JSON", async () => {
    const data = { items: [1, 2, 3], name: "test" };
    await cache.set("json", JSON.stringify(data));
    const result = JSON.parse((await cache.get("json"))!);
    expect(result).toEqual(data);
  });
});

// ── 15.4: Auto-selection from env ─────────────────────────

describe("15.4: Auto-selection from env", () => {
  it("creates SQLiteCache when REDIS_URL is not set", async () => {
    const original = process.env.REDIS_URL;
    delete process.env.REDIS_URL;

    const { createCacheProvider } = await import("../src/core/cache");
    const cache = await createCacheProvider(":memory:");
    await cache.set("test", "value");
    expect(await cache.get("test")).toBe("value");
    await cache.flush();

    if (original) process.env.REDIS_URL = original;
  });
});

// ── Cache key builder ─────────────────────────────────────

describe("buildCacheKey", () => {
  it("returns empty string for 'none' policy", () => {
    expect(buildCacheKey("p1", "none", {})).toBe("");
  });

  it("returns pageId-only key for 'static' policy", () => {
    expect(buildCacheKey("p1", "static", {})).toBe("page:p1");
  });

  it("includes selected requestInfo fields", () => {
    const policy: CachePolicyConfig = { requestInfo: ["locale", "timezone"] };
    const k1 = buildCacheKey("p1", policy, {
      requestInfo: { locale: "en_US", timezone: "UTC", platform: "iOS" },
    });
    const k2 = buildCacheKey("p1", policy, {
      requestInfo: { locale: "en_US", timezone: "UTC", platform: "Android" },
    });
    // platform not in policy — should produce same key
    expect(k1).toBe(k2);
  });

  it("different selected values produce different keys", () => {
    const policy: CachePolicyConfig = { requestInfo: ["locale"] };
    const k1 = buildCacheKey("p1", policy, {
      requestInfo: { locale: "en_US" },
    });
    const k2 = buildCacheKey("p1", policy, {
      requestInfo: { locale: "ar_EG" },
    });
    expect(k1).not.toBe(k2);
  });

  it("includes selected pageState keys", () => {
    const policy: CachePolicyConfig = { pageState: ["theme"] };
    const k1 = buildCacheKey("p1", policy, {
      pageState: { theme: "dark", count: 0 },
    });
    const k2 = buildCacheKey("p1", policy, {
      pageState: { theme: "dark", count: 99 },
    });
    // count not in policy — same key
    expect(k1).toBe(k2);
  });

  it("includes selected appState keys", () => {
    const policy: CachePolicyConfig = { appState: ["userPref"] };
    const k1 = buildCacheKey("p1", policy, {
      appState: { userPref: "compact" },
    });
    const k2 = buildCacheKey("p1", policy, {
      appState: { userPref: "expanded" },
    });
    expect(k1).not.toBe(k2);
  });

  it("combines requestInfo + pageState + appState", () => {
    const policy: CachePolicyConfig = {
      requestInfo: ["locale"],
      pageState: ["theme"],
      appState: ["mode"],
    };
    const k = buildCacheKey("p1", policy, {
      requestInfo: { locale: "en" },
      pageState: { theme: "dark" },
      appState: { mode: "pro" },
    });
    expect(k).toContain("page:p1");
    expect(k).toContain("ri:");
    expect(k).toContain("ps:");
    expect(k).toContain("as:");
  });

  it("supports dot-path for nested requestInfo", () => {
    const policy: CachePolicyConfig = { requestInfo: ["screenSize.width"] };
    const k1 = buildCacheKey("p1", policy, {
      requestInfo: { screenSize: { width: 390, height: 844 } },
    });
    const k2 = buildCacheKey("p1", policy, {
      requestInfo: { screenSize: { width: 768, height: 1024 } },
    });
    expect(k1).not.toBe(k2);
  });

  it("empty config object acts like static", () => {
    const k1 = buildCacheKey("p1", {}, {});
    const k2 = buildCacheKey("p1", "static", {});
    expect(k1).toBe(k2);
  });
});

// ── resolveCacheConfig (flow + page merge) ────────────────

describe("resolveCacheConfig", () => {
  it("page policy wins over flow policy", () => {
    const result = resolveCacheConfig(
      "static", 120,
      { requestInfo: ["locale"] }, 60,
    );
    expect(result.policy).toEqual({ requestInfo: ["locale"] });
    expect(result.ttl).toBe(60);
  });

  it("falls back to flow when page is 'none'", () => {
    const result = resolveCacheConfig(
      "static", 120,
      "none", 60,
    );
    expect(result.policy).toBe("static");
    expect(result.ttl).toBe(120);
  });

  it("returns 'none' when both are 'none'", () => {
    const result = resolveCacheConfig("none", 60, "none", 60);
    expect(result.policy).toBe("none");
  });

  it("returns 'none' when flow is undefined and page is 'none'", () => {
    const result = resolveCacheConfig(undefined, undefined, "none", 60);
    expect(result.policy).toBe("none");
  });

  it("uses ttl from CachePolicyConfig when present", () => {
    const result = resolveCacheConfig(
      undefined, undefined,
      { requestInfo: ["locale"], ttl: 300 }, 60,
    );
    expect(result.ttl).toBe(300);
  });

  it("uses flow ttl from CachePolicyConfig", () => {
    const result = resolveCacheConfig(
      { requestInfo: ["locale"], ttl: 200 }, 120,
      "none", 60,
    );
    expect(result.ttl).toBe(200);
  });
});

// ── Pipeline: unified stages 1-3 caching ──────────────────

describe("15.5: Unified pipeline caching", () => {
  it("caches stages 1-3 with static policy", async () => {
    let infoCount = 0;
    let renderCount = 0;
    const cache = new SQLiteCache(":memory:");

    const page = PageDefinition.create({
      id: "cached-static",
      title: "Cached Static",
      cachePolicy: "static",
      cacheTtl: 60,
      getInfoData: async () => { infoCount++; return { data: "x" }; },
      state: [{ key: "count", scope: "page", initial: 0 }],
      render: () => { renderCount++; return new SimpleText("hello"); },
    });

    const config = { policy: "static" as const, ttl: 60 };

    await runPipeline(page, makeContext(), undefined, cache, config);
    expect(infoCount).toBe(1);
    expect(renderCount).toBe(1);

    await runPipeline(page, makeContext(), undefined, cache, config);
    expect(infoCount).toBe(1); // cached
    expect(renderCount).toBe(1); // cached
  });

  it("caches by specific requestInfo fields", async () => {
    let infoCount = 0;
    const cache = new SQLiteCache(":memory:");

    const page = PageDefinition.create({
      id: "ri-cache",
      title: "RI Cache",
      cachePolicy: { requestInfo: ["locale"] },
      getInfoData: async () => { infoCount++; return {}; },
      render: () => new SimpleText("hi"),
    });

    const policy: CachePolicyConfig = { requestInfo: ["locale"] };
    const config = { policy, ttl: 60 };

    // Same locale → cache hit
    await runPipeline(page, makeContext(), undefined, cache, config);
    expect(infoCount).toBe(1);
    await runPipeline(page, makeContext(), undefined, cache, config);
    expect(infoCount).toBe(1);

    // Different locale → cache miss
    const ctx = makeContext();
    ctx.requestInfo.locale = "ar_EG";
    await runPipeline(page, ctx, undefined, cache, config);
    expect(infoCount).toBe(2);
  });

  it("caches by specific pageState keys", async () => {
    let renderCount = 0;
    const cache = new SQLiteCache(":memory:");

    const page = PageDefinition.create({
      id: "ps-cache",
      title: "PS Cache",
      cachePolicy: { pageState: ["theme"] },
      state: [
        { key: "theme", scope: "page", initial: "dark" },
        { key: "count", scope: "page", initial: 0 },
      ],
      render: () => { renderCount++; return new SimpleText("hi"); },
    });

    const policy: CachePolicyConfig = { pageState: ["theme"] };
    const config = { policy, ttl: 60 };

    // Same theme → cache hit (even though count differs conceptually)
    await runPipeline(page, makeContext(), undefined, cache, config);
    expect(renderCount).toBe(1);
    await runPipeline(page, makeContext(), undefined, cache, config);
    expect(renderCount).toBe(1);
  });

  it("caches by specific appState keys", async () => {
    let infoCount = 0;
    const cache = new SQLiteCache(":memory:");

    const page = PageDefinition.create({
      id: "as-cache",
      title: "AS Cache",
      cachePolicy: { appState: ["userPref"] },
      getInfoData: async () => { infoCount++; return {}; },
      render: () => new SimpleText("hi"),
    });

    const policy: CachePolicyConfig = { appState: ["userPref"] };
    const config = { policy, ttl: 60 };

    const ctx1 = makeContext();
    ctx1.appState = { userPref: "compact" };
    await runPipeline(page, ctx1, undefined, cache, config);
    expect(infoCount).toBe(1);

    // Same appState → hit
    const ctx2 = makeContext();
    ctx2.appState = { userPref: "compact" };
    await runPipeline(page, ctx2, undefined, cache, config);
    expect(infoCount).toBe(1);

    // Different appState → miss
    const ctx3 = makeContext();
    ctx3.appState = { userPref: "expanded" };
    await runPipeline(page, ctx3, undefined, cache, config);
    expect(infoCount).toBe(2);
  });

  it("caches by combined requestInfo + appState", async () => {
    let infoCount = 0;
    const cache = new SQLiteCache(":memory:");

    const page = PageDefinition.create({
      id: "combo-cache",
      title: "Combo",
      cachePolicy: { requestInfo: ["locale"], appState: ["theme"] },
      getInfoData: async () => { infoCount++; return {}; },
      render: () => new SimpleText("hi"),
    });

    const policy: CachePolicyConfig = { requestInfo: ["locale"], appState: ["theme"] };
    const config = { policy, ttl: 60 };

    const ctx1 = makeContext();
    ctx1.appState = { theme: "dark" };
    await runPipeline(page, ctx1, undefined, cache, config);
    expect(infoCount).toBe(1);

    // Same locale + theme → hit
    const ctx2 = makeContext();
    ctx2.appState = { theme: "dark" };
    await runPipeline(page, ctx2, undefined, cache, config);
    expect(infoCount).toBe(1);

    // Different theme → miss
    const ctx3 = makeContext();
    ctx3.appState = { theme: "light" };
    await runPipeline(page, ctx3, undefined, cache, config);
    expect(infoCount).toBe(2);

    // Different locale → miss
    const ctx4 = makeContext();
    ctx4.requestInfo.locale = "ar_EG";
    ctx4.appState = { theme: "dark" };
    await runPipeline(page, ctx4, undefined, cache, config);
    expect(infoCount).toBe(3);
  });

  // Epic 25b slice 2: cache key must include the client capability hash so
  // two SDK versions with different vectors never share a cache entry. This
  // is the correctness invariant behind task 25b.8 — without it, an old
  // client could see a tree rendered for a newer client and crash on an
  // unsupported feature the old client's vector wouldn't have allowed.
  it("caches separately by client capability hash", async () => {
    let infoCount = 0;
    const cache = new SQLiteCache(":memory:");

    const page = PageDefinition.create({
      id: "caps-cache",
      title: "Caps",
      cachePolicy: "static", // static is enough — caps hash always appended
      getInfoData: async () => { infoCount++; return {}; },
      render: () => new SimpleText("hi"),
    });
    const config = { policy: "static" as const, ttl: 60 };

    // First client with hash "aaa" → cold miss.
    const ctxA1 = makeContext();
    ctxA1.requestInfo.clientCapabilities = { sdkVersion: "1.0.0", hash: "aaa" };
    await runPipeline(page, ctxA1, undefined, cache, config);
    expect(infoCount).toBe(1);

    // Same client hash → warm hit, count stays at 1.
    const ctxA2 = makeContext();
    ctxA2.requestInfo.clientCapabilities = { sdkVersion: "1.0.0", hash: "aaa" };
    await runPipeline(page, ctxA2, undefined, cache, config);
    expect(infoCount).toBe(1);

    // Different client hash → different cache entry → cold miss.
    const ctxB = makeContext();
    ctxB.requestInfo.clientCapabilities = { sdkVersion: "1.1.0", hash: "bbb" };
    await runPipeline(page, ctxB, undefined, cache, config);
    expect(infoCount).toBe(2);

    // Omitting caps entirely → yet another cache entry (suffix absent →
    // different key from both hashed entries).
    const ctxUnversioned = makeContext();
    await runPipeline(page, ctxUnversioned, undefined, cache, config);
    expect(infoCount).toBe(3);

    // Unversioned repeat hits the unversioned entry, not a new one.
    const ctxUnversioned2 = makeContext();
    await runPipeline(page, ctxUnversioned2, undefined, cache, config);
    expect(infoCount).toBe(3);
  });
});

// ── 15.7: Stage 4 never cached ───────────────────────────

describe("15.7: Stage 4 never cached", () => {
  it("postRender always runs even with caching enabled", async () => {
    let postRenderCount = 0;
    const cache = new SQLiteCache(":memory:");

    const page = PageDefinition.create({
      id: "post-render-test",
      title: "PostRender",
      cachePolicy: "static",
      cacheTtl: 60,
      render: () => new SimpleText("hello"),
      postRender: () => { postRenderCount++; },
    });

    const config = { policy: "static" as const, ttl: 60 };

    await runPipeline(page, makeContext(), undefined, cache, config);
    await runPipeline(page, makeContext(), undefined, cache, config);
    await runPipeline(page, makeContext(), undefined, cache, config);

    expect(postRenderCount).toBe(3);
  });
});

// ── 15.8: CachePolicy per flow ───────────────────────────

describe("15.8: CachePolicy per flow (flow-level default)", () => {
  it("none policy skips cache entirely", async () => {
    let renderCount = 0;
    const cache = new SQLiteCache(":memory:");

    const page = PageDefinition.create({
      id: "no-cache",
      title: "No Cache",
      render: () => { renderCount++; return new SimpleText("hi"); },
    });

    // No cacheConfig → no caching
    await runPipeline(page, makeContext(), undefined, cache);
    await runPipeline(page, makeContext(), undefined, cache);
    expect(renderCount).toBe(2);
  });

  it("flow cachePolicy applies to pages that don't set their own", () => {
    const flow = Flow.create({
      name: "cached-flow",
      cachePolicy: { requestInfo: ["locale"] },
      cacheTtl: 120,
      routes: [{ path: "home", page: PageDefinition.create({
        id: "home",
        title: "Home",
        render: () => new SimpleText("hi"),
      }) }],
    });

    const match = flow.resolve("home");
    expect(match).toBeDefined();
    expect(match!.flowCachePolicy).toEqual({ requestInfo: ["locale"] });
    expect(match!.flowCacheTtl).toBe(120);

    // Page has "none" → resolveCacheConfig should use flow's
    const resolved = resolveCacheConfig(
      match!.flowCachePolicy,
      match!.flowCacheTtl,
      match!.page.cachePolicy,
      match!.page.cacheTtl,
    );
    expect(resolved.policy).toEqual({ requestInfo: ["locale"] });
    expect(resolved.ttl).toBe(120);
  });

  it("page cachePolicy overrides flow cachePolicy", () => {
    const page = PageDefinition.create({
      id: "custom",
      title: "Custom",
      cachePolicy: { requestInfo: ["timezone"], appState: ["mode"] },
      cacheTtl: 30,
      render: () => new SimpleText("hi"),
    });

    const flow = Flow.create({
      name: "cached-flow",
      cachePolicy: "static",
      cacheTtl: 120,
      routes: [{ path: "custom", page }],
    });

    const match = flow.resolve("custom");
    const resolved = resolveCacheConfig(
      match!.flowCachePolicy,
      match!.flowCacheTtl,
      match!.page.cachePolicy,
      match!.page.cacheTtl,
    );
    expect(resolved.policy).toEqual({ requestInfo: ["timezone"], appState: ["mode"] });
    expect(resolved.ttl).toBe(30);
  });

  it("PageDefinition defaults to 'none' cache policy", () => {
    const page = PageDefinition.create({
      id: "default",
      title: "Default",
      render: () => new SimpleText("hi"),
    });
    expect(page.cachePolicy).toBe("none");
    expect(page.cacheTtl).toBe(60);
  });
});

// ── 15.9: Cache invalidation ─────────────────────────────

describe("15.9: Cache invalidation", () => {
  it("manual del removes cached entry", async () => {
    const cache = new SQLiteCache(":memory:");
    await cache.set("page:my-page", JSON.stringify({ data: "old" }));
    expect(await cache.get("page:my-page")).toBe(JSON.stringify({ data: "old" }));
    await cache.del("page:my-page");
    expect(await cache.get("page:my-page")).toBeNull();
  });

  it("TTL expiry invalidates automatically", async () => {
    const cache = new SQLiteCache(":memory:");
    await cache.set("key", "value", 1);
    expect(await cache.get("key")).toBe("value");
    await Bun.sleep(1100);
    expect(await cache.get("key")).toBeNull();
  });
});

// ── 15.10: ETag / If-None-Match ──────────────────────────

describe("15.10: ETag / If-None-Match", () => {
  const homePage = PageDefinition.create({
    id: "etag-home",
    title: "ETag Home",
    render: () => new SimpleText("hello"),
  });

  const flow = Flow.create({
    name: "main",
    routes: [{ path: "home", page: homePage }],
  });

  const app = App.create({
    id: "etagapp",
    name: "ETag App",
    flows: [flow],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<Engine["start"]>>;

  beforeAll(async () => {
    server = await engine.start({ port: 0, cache: false });
  });
  afterAll(() => engine.stop());

  it("response includes ETag header", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/etagapp/page/home`);
    expect(res.status).toBe(200);
    const etag = res.headers.get("etag");
    expect(etag).toBeTruthy();
    expect(etag!.startsWith('"')).toBe(true);
    expect(etag!.endsWith('"')).toBe(true);
  });

  it("returns 304 when If-None-Match matches ETag", async () => {
    const res1 = await fetch(`http://localhost:${server.port}/api/v1/app/etagapp/page/home`);
    const etag = res1.headers.get("etag")!;

    const res2 = await fetch(`http://localhost:${server.port}/api/v1/app/etagapp/page/home`, {
      headers: { "If-None-Match": etag },
    });
    expect(res2.status).toBe(304);
  });

  it("returns 200 when If-None-Match does not match", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/etagapp/page/home`, {
      headers: { "If-None-Match": '"wrong-etag"' },
    });
    expect(res.status).toBe(200);
  });

  it("generateETag produces consistent hashes", () => {
    const body = '{"pageId":"home","components":[]}';
    const etag1 = generateETag(body);
    const etag2 = generateETag(body);
    expect(etag1).toBe(etag2);
    expect(etag1).not.toBe(generateETag(body + "x"));
  });
});

// ── HTTP Integration: flow-level caching ──────────────────

describe("15.11: HTTP integration with flow-level cache", () => {
  let infoCallCount = 0;

  const cachedPage = PageDefinition.create({
    id: "flow-cached",
    title: "Flow Cached",
    getInfoData: async () => {
      infoCallCount++;
      return { items: ["a", "b"] };
    },
    render: () => new SimpleText("cached"),
  });

  const flow = Flow.create({
    name: "main",
    cachePolicy: "static",
    cacheTtl: 300,
    routes: [{ path: "cached", page: cachedPage }],
  });

  const app = App.create({
    id: "flowcacheapp",
    name: "Flow Cache App",
    flows: [flow],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<Engine["start"]>>;

  beforeAll(async () => {
    infoCallCount = 0;
    server = await engine.start({ port: 0 });
  });
  afterAll(() => engine.stop());

  it("first request populates cache", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/flowcacheapp/page/cached`);
    expect(res.status).toBe(200);
    expect(infoCallCount).toBe(1);
  });

  it("second request uses cache (flow-level policy)", async () => {
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/flowcacheapp/page/cached`);
    expect(res.status).toBe(200);
    expect(infoCallCount).toBe(1); // cached
  });

  it("cache can be flushed via engine.getCache()", async () => {
    await engine.getCache()!.flush();
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/flowcacheapp/page/cached`);
    expect(res.status).toBe(200);
    expect(infoCallCount).toBe(2); // flushed → re-fetched
  });
});

describe("15.12: HTTP integration with fine-grained cache", () => {
  let infoCallCount = 0;

  const localePage = PageDefinition.create({
    id: "locale-page",
    title: "Locale",
    cachePolicy: { requestInfo: ["locale", "timezone"] },
    cacheTtl: 60,
    getInfoData: async () => {
      infoCallCount++;
      return { translations: {} };
    },
    render: () => new SimpleText("localized"),
  });

  const flow = Flow.create({
    name: "main",
    routes: [{ path: "locale", page: localePage }],
  });

  const app = App.create({
    id: "localeapp",
    name: "Locale App",
    flows: [flow],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<Engine["start"]>>;

  beforeAll(async () => {
    infoCallCount = 0;
    server = await engine.start({ port: 0 });
  });
  afterAll(() => engine.stop());

  it("same locale+tz → cache hit", async () => {
    const headers = {
      "x-orca-locale": "en_US",
      "x-orca-timezone": "UTC",
    };
    await fetch(`http://localhost:${server.port}/api/v1/app/localeapp/page/locale`, { headers });
    expect(infoCallCount).toBe(1);

    await fetch(`http://localhost:${server.port}/api/v1/app/localeapp/page/locale`, { headers });
    expect(infoCallCount).toBe(1); // cache hit
  });

  it("different locale → cache miss", async () => {
    await fetch(`http://localhost:${server.port}/api/v1/app/localeapp/page/locale`, {
      headers: { "x-orca-locale": "ar_EG", "x-orca-timezone": "UTC" },
    });
    expect(infoCallCount).toBe(2); // different locale
  });

  it("different timezone → cache miss", async () => {
    await fetch(`http://localhost:${server.port}/api/v1/app/localeapp/page/locale`, {
      headers: { "x-orca-locale": "en_US", "x-orca-timezone": "America/New_York" },
    });
    expect(infoCallCount).toBe(3); // different timezone
  });
});
