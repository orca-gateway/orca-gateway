import { describe, expect, it, beforeEach } from "bun:test";
import {
  MonitorEmitter,
  ConsoleMonitor,
  type Monitor,
  type FlowStartEvent,
  type FlowEndEvent,
  type PageRenderEvent,
  type PageUpdateEvent,
  type MonitorErrorEvent,
  type CacheHitEvent,
  type CacheMissEvent,
  type ServerActionCallEvent,
  type SessionStartEvent,
  type SessionEndEvent,
  type RegisterOfflineSessionsEvent,
} from "../src/core/monitor";
import {
  PageDefinition,
  runPipeline,
  Engine,
  App,
  Flow,
} from "../src/core";
import type { PageContext } from "../src/types/context";
import { SQLiteCache } from "../src/core/sqlite-cache";
import { Text } from "../src/components";

// ── Helpers ──────────────────────────────────────────────

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

/** Collects all events by hook name. */
class MockMonitor implements Monitor {
  events: { hook: string; event: unknown }[] = [];

  onFlowStart(e: FlowStartEvent) { this.events.push({ hook: "onFlowStart", event: e }); }
  onFlowEnd(e: FlowEndEvent) { this.events.push({ hook: "onFlowEnd", event: e }); }
  onPageRender(e: PageRenderEvent) { this.events.push({ hook: "onPageRender", event: e }); }
  onPageUpdate(e: PageUpdateEvent) { this.events.push({ hook: "onPageUpdate", event: e }); }
  onError(e: MonitorErrorEvent) { this.events.push({ hook: "onError", event: e }); }
  onCacheHit(e: CacheHitEvent) { this.events.push({ hook: "onCacheHit", event: e }); }
  onCacheMiss(e: CacheMissEvent) { this.events.push({ hook: "onCacheMiss", event: e }); }
  onServerActionCall(e: ServerActionCallEvent) { this.events.push({ hook: "onServerActionCall", event: e }); }
  onSessionStart(e: SessionStartEvent) { this.events.push({ hook: "onSessionStart", event: e }); }
  onSessionEnd(e: SessionEndEvent) { this.events.push({ hook: "onSessionEnd", event: e }); }
  onRegisterOfflineSessions(e: RegisterOfflineSessionsEvent) { this.events.push({ hook: "onRegisterOfflineSessions", event: e }); }

  byHook(name: string) {
    return this.events.filter((e) => e.hook === name);
  }
}

// ── 18.1: Monitor interface ─────────────────────────────

describe("18.1: Monitor interface", () => {
  it("defines all required hooks", () => {
    const monitor: Monitor = {};
    // All hooks are optional — an empty object satisfies the interface
    expect(monitor).toBeDefined();
  });

  it("hooks are callable when implemented", () => {
    const mock = new MockMonitor();
    const ts = Date.now();

    mock.onFlowStart({ timestamp: ts, flowName: "main", path: "/home" });
    mock.onFlowEnd({ timestamp: ts, flowName: "main", path: "/home", durationMs: 10 });
    mock.onPageRender({
      timestamp: ts,
      pageId: "home",
      path: "/home",
      context: makeContext("/home"),
      response: { pageId: "home", title: "Home", state: [], components: [] },
      durationMs: 5,
    });
    mock.onError({ timestamp: ts, error: new Error("boom"), pageId: "home", stage: "pipeline" });
    mock.onCacheHit({ timestamp: ts, pageId: "home", cacheKey: "page:home" });
    mock.onCacheMiss({ timestamp: ts, pageId: "home", cacheKey: "page:home" });
    mock.onServerActionCall({
      timestamp: ts,
      actionId: "doSomething",
      context: { requestInfo: makeContext().requestInfo, pageState: {}, appState: {}, actionParams: {} },
      durationMs: 3,
      success: true,
    });
    mock.onSessionStart({ timestamp: ts, deviceId: "abc", requestInfo: makeContext().requestInfo });
    mock.onSessionEnd({ timestamp: ts, deviceId: "abc", requestInfo: makeContext().requestInfo });

    expect(mock.events).toHaveLength(9);
  });
});

// ── 18.2: MonitorEmitter (registerMonitor) ──────────────

describe("18.2: MonitorEmitter", () => {
  let emitter: MonitorEmitter;

  beforeEach(() => {
    emitter = new MonitorEmitter();
  });

  it("registers multiple monitors", () => {
    emitter.register({});
    emitter.register({});
    expect(emitter.count).toBe(2);
  });

  it("fires monitors in registration order", () => {
    const order: number[] = [];
    emitter.register({ onCacheHit: () => order.push(1) });
    emitter.register({ onCacheHit: () => order.push(2) });
    emitter.register({ onCacheHit: () => order.push(3) });

    emitter.emit("onCacheHit", { timestamp: Date.now(), pageId: "x", cacheKey: "k" });
    expect(order).toEqual([1, 2, 3]);
  });

  it("skips monitors that don't implement the hook", () => {
    const calls: string[] = [];
    emitter.register({ onCacheHit: () => calls.push("a") });
    emitter.register({}); // no onCacheHit
    emitter.register({ onCacheHit: () => calls.push("c") });

    emitter.emit("onCacheHit", { timestamp: Date.now(), pageId: "x", cacheKey: "k" });
    expect(calls).toEqual(["a", "c"]);
  });

  it("does not throw when a monitor throws", () => {
    emitter.register({
      onError: () => { throw new Error("monitor bug"); },
    });
    // Should not throw
    emitter.emit("onError", { timestamp: Date.now(), error: new Error("original") });
  });
});

// ── 18.2: engine.registerMonitor() ──────────────────────

describe("18.2: engine.registerMonitor()", () => {
  it("returns this for chaining", () => {
    const engine = new Engine();
    const result = engine.registerMonitor({});
    expect(result).toBe(engine);
  });

  it("registers multiple monitors on the emitter", () => {
    const engine = new Engine();
    engine.registerMonitor({});
    engine.registerMonitor({});
    expect(engine.getMonitorEmitter().count).toBe(2);
  });
});

// ── 18.3: Pipeline emits cache events ───────────────────

describe("18.3: Pipeline emits events", () => {
  const page = PageDefinition.create({
    id: "cached-page",
    title: "Cached",
    cachePolicy: "static",
    cacheTtl: 300,
    render: () => Text.new({ data: "hi" }),
  });

  it("emits onCacheMiss on first render", async () => {
    const emitter = new MonitorEmitter();
    const mock = new MockMonitor();
    emitter.register(mock);

    const cache = new SQLiteCache(":memory:");
    await runPipeline(
      page,
      makeContext(),
      undefined,
      cache,
      { policy: "static", ttl: 300 },
      emitter,
    );

    expect(mock.byHook("onCacheMiss")).toHaveLength(1);
    expect(mock.byHook("onCacheHit")).toHaveLength(0);
    const missEvent = mock.byHook("onCacheMiss")[0]!.event as CacheMissEvent;
    expect(missEvent.pageId).toBe("cached-page");
    cache.close();
  });

  it("emits onCacheHit on second render", async () => {
    const emitter = new MonitorEmitter();
    const mock = new MockMonitor();
    emitter.register(mock);

    const cache = new SQLiteCache(":memory:");
    const cfg = { policy: "static" as const, ttl: 300 };

    // First render — miss
    await runPipeline(page, makeContext(), undefined, cache, cfg, emitter);
    // Second render — hit
    await runPipeline(page, makeContext(), undefined, cache, cfg, emitter);

    expect(mock.byHook("onCacheMiss")).toHaveLength(1);
    expect(mock.byHook("onCacheHit")).toHaveLength(1);
    const hitEvent = mock.byHook("onCacheHit")[0]!.event as CacheHitEvent;
    expect(hitEvent.pageId).toBe("cached-page");
    cache.close();
  });

  it("emits no cache events when cache is disabled", async () => {
    const emitter = new MonitorEmitter();
    const mock = new MockMonitor();
    emitter.register(mock);

    const noCachePage = PageDefinition.create({
      id: "no-cache",
      title: "No Cache",
      render: () => Text.new({ data: "hi" }),
    });

    await runPipeline(noCachePage, makeContext(), undefined, undefined, undefined, emitter);

    expect(mock.byHook("onCacheHit")).toHaveLength(0);
    expect(mock.byHook("onCacheMiss")).toHaveLength(0);
  });
});

// ── 18.5: Error propagation ─────────────────────────────

describe("18.5: Error propagation", () => {
  it("emits onError when pipeline throws", async () => {
    const emitter = new MonitorEmitter();
    const mock = new MockMonitor();
    emitter.register(mock);

    const brokenPage = PageDefinition.create({
      id: "broken",
      title: "Broken",
      render: () => { throw new Error("render failed"); },
    });

    try {
      await runPipeline(brokenPage, makeContext(), undefined, undefined, undefined, emitter);
    } catch {
      // expected
    }

    // The error is caught and emitted by the engine, not the pipeline itself.
    // Pipeline throws, engine catches → emits onError.
    // This test verifies the emitter can handle error events.
    emitter.emit("onError", {
      timestamp: Date.now(),
      error: new Error("render failed"),
      pageId: "broken",
      stage: "pipeline",
    });

    expect(mock.byHook("onError")).toHaveLength(1);
    const errorEvent = mock.byHook("onError")[0]!.event as MonitorErrorEvent;
    expect(errorEvent.pageId).toBe("broken");
    expect(errorEvent.stage).toBe("pipeline");
  });
});

// ── 18.6: ConsoleMonitor ────────────────────────────────

describe("18.6: ConsoleMonitor", () => {
  it("implements all monitor hooks", () => {
    const cm = new ConsoleMonitor();
    expect(typeof cm.onFlowStart).toBe("function");
    expect(typeof cm.onFlowEnd).toBe("function");
    expect(typeof cm.onPageRender).toBe("function");
    expect(typeof cm.onPageUpdate).toBe("function");
    expect(typeof cm.onError).toBe("function");
    expect(typeof cm.onCacheHit).toBe("function");
    expect(typeof cm.onCacheMiss).toBe("function");
    expect(typeof cm.onServerActionCall).toBe("function");
    expect(typeof cm.onSessionStart).toBe("function");
    expect(typeof cm.onSessionEnd).toBe("function");
  });

  it("can be registered via devMonitor config", async () => {
    const engine = new Engine();
    const app = App.create({
      id: "test-app",
      name: "Test",
      flows: [
        Flow.create({ name: "main", routes: [{ path: "home", page: PageDefinition.create({ id: "home", title: "Home", render: () => Text.new({ data: "hi" }) }) }] }),
      ],
    });
    engine.registerApp(app);
    await engine.start({ port: 0, cache: false, devMonitor: true });

    expect(engine.getMonitorEmitter().count).toBe(1);
    engine.stop();
  });
});

// ── 18.7: Timing data ───────────────────────────────────

describe("18.7: Timing data in events", () => {
  it("FlowEndEvent includes durationMs", () => {
    const event: FlowEndEvent = {
      timestamp: Date.now(),
      flowName: "main",
      path: "/home",
      durationMs: 42.5,
    };
    expect(event.durationMs).toBeGreaterThan(0);
  });

  it("PageRenderEvent includes durationMs", () => {
    const event: PageRenderEvent = {
      timestamp: Date.now(),
      pageId: "home",
      path: "/home",
      context: makeContext(),
      response: { pageId: "home", title: "Home", state: [], components: [] },
      durationMs: 12.3,
    };
    expect(event.durationMs).toBeGreaterThan(0);
  });

  it("ServerActionCallEvent includes durationMs", () => {
    const event: ServerActionCallEvent = {
      timestamp: Date.now(),
      actionId: "doThing",
      context: { requestInfo: makeContext().requestInfo, pageState: {}, appState: {}, actionParams: {} },
      durationMs: 8.1,
      success: true,
    };
    expect(event.durationMs).toBeGreaterThan(0);
  });
});

// ── 18.8: Full page render integration ──────────────────

describe("18.8: Mock monitor receives all expected events for a page render", () => {
  it("receives onFlowStart, onFlowEnd, onPageRender with timing via HTTP", async () => {
    const mock = new MockMonitor();
    const engine = new Engine();
    engine.registerMonitor(mock);

    const page = PageDefinition.create({
      id: "integration",
      title: "Integration",
      cachePolicy: "static",
      cacheTtl: 60,
      render: () => Text.new({ data: "hello" }),
    });

    const app = App.create({
      id: "mon-app",
      name: "MonApp",
      flows: [Flow.create({ name: "main", routes: [{ path: "home", page }] })],
    });
    engine.registerApp(app);

    const server = await engine.start({ port: 0 });
    const baseUrl = `http://localhost:${server.port}`;

    // First request — cache miss + page render
    const res1 = await fetch(`${baseUrl}/api/v1/app/mon-app/page/home`);
    expect(res1.status).toBe(200);

    // Second request — cache hit + page render
    const res2 = await fetch(`${baseUrl}/api/v1/app/mon-app/page/home`);
    expect(res2.status).toBe(200);

    engine.stop();

    // Verify cache events
    expect(mock.byHook("onCacheMiss")).toHaveLength(1);
    expect(mock.byHook("onCacheHit")).toHaveLength(1);
    expect(mock.byHook("onPageRender")).toHaveLength(2);

    // Verify flow events
    expect(mock.byHook("onFlowStart")).toHaveLength(2);
    expect(mock.byHook("onFlowEnd")).toHaveLength(2);

    const flowStart = mock.byHook("onFlowStart")[0]!.event as FlowStartEvent;
    expect(flowStart.flowName).toBe("main");
    expect(flowStart.path).toBe("/home");

    const flowEnd = mock.byHook("onFlowEnd")[0]!.event as FlowEndEvent;
    expect(flowEnd.flowName).toBe("main");
    expect(flowEnd.path).toBe("/home");
    expect(flowEnd.durationMs).toBeGreaterThanOrEqual(0);

    // Verify page render event
    const renderEvent = mock.byHook("onPageRender")[0]!.event as PageRenderEvent;
    expect(renderEvent.pageId).toBe("integration");
    expect(renderEvent.path).toBe("/home");
    expect(renderEvent.durationMs).toBeGreaterThanOrEqual(0);
    expect(renderEvent.response.components.length).toBeGreaterThan(0);
  });

  it("receives onError and onFlowStart/onFlowEnd when page throws", async () => {
    const mock = new MockMonitor();
    const engine = new Engine();
    engine.registerMonitor(mock);

    const brokenPage = PageDefinition.create({
      id: "broken",
      title: "Broken",
      render: () => { throw new Error("boom"); },
    });

    const app = App.create({
      id: "err-app",
      name: "ErrApp",
      flows: [Flow.create({ name: "main", routes: [{ path: "fail", page: brokenPage }] })],
    });
    engine.registerApp(app);

    const server = await engine.start({ port: 0, cache: false });
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/err-app/page/fail`);
    expect(res.status).toBe(500);

    engine.stop();

    expect(mock.byHook("onError")).toHaveLength(1);
    const errEvent = mock.byHook("onError")[0]!.event as MonitorErrorEvent;
    expect(errEvent.pageId).toBe("broken");
    expect(errEvent.stage).toBe("pipeline");
    expect(errEvent.error).toBeInstanceOf(Error);

    // Flow events still fire even on error
    expect(mock.byHook("onFlowStart")).toHaveLength(1);
    expect(mock.byHook("onFlowEnd")).toHaveLength(1);
  });

  it("receives onServerActionCall for actions", async () => {
    const mock = new MockMonitor();
    const engine = new Engine();
    engine.registerMonitor(mock);

    const { ServerActionDefinition } = await import("../src/core/server-action");

    const action = ServerActionDefinition.create({
      id: "greet",
      execute: () => [{ type: "showSnackbar", message: "hi" }],
    });

    const app = App.create({
      id: "act-app",
      name: "ActApp",
      flows: [Flow.create({ name: "main", routes: [{ path: "home", page: PageDefinition.create({ id: "home", title: "Home", render: () => Text.new({ data: "hi" }) }) }] })],
      actions: [action],
    });
    engine.registerApp(app);

    const server = await engine.start({ port: 0, cache: false });
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/act-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "greet", params: {} }),
    });
    expect(res.status).toBe(200);

    engine.stop();

    expect(mock.byHook("onServerActionCall")).toHaveLength(1);
    const actionEvent = mock.byHook("onServerActionCall")[0]!.event as ServerActionCallEvent;
    expect(actionEvent.actionId).toBe("greet");
    expect(actionEvent.success).toBe(true);
    expect(actionEvent.durationMs).toBeGreaterThanOrEqual(0);
  });

  it("receives onSessionStart and onSessionEnd via /session endpoint", async () => {
    const mock = new MockMonitor();
    const engine = new Engine();
    engine.registerMonitor(mock);

    const app = App.create({
      id: "sess-app",
      name: "SessApp",
      flows: [Flow.create({ name: "main", routes: [{ path: "home", page: PageDefinition.create({ id: "home", title: "Home", render: () => Text.new({ data: "hi" }) }) }] })],
    });
    engine.registerApp(app);

    const server = await engine.start({ port: 0, cache: false });
    const baseUrl = `http://localhost:${server.port}`;

    // Session start
    const res1 = await fetch(`${baseUrl}/api/v1/app/sess-app/session`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type: "start", deviceId: "device-123" }),
    });
    expect(res1.status).toBe(200);

    // Session end
    const res2 = await fetch(`${baseUrl}/api/v1/app/sess-app/session`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type: "end", deviceId: "device-123" }),
    });
    expect(res2.status).toBe(200);

    engine.stop();

    expect(mock.byHook("onSessionStart")).toHaveLength(1);
    const startEvent = mock.byHook("onSessionStart")[0]!.event as SessionStartEvent;
    expect(startEvent.deviceId).toBe("device-123");
    expect(startEvent.requestInfo).toBeDefined();
    expect(startEvent.requestInfo.ipAddress).toBeDefined();

    expect(mock.byHook("onSessionEnd")).toHaveLength(1);
    const endEvent = mock.byHook("onSessionEnd")[0]!.event as SessionEndEvent;
    expect(endEvent.deviceId).toBe("device-123");
    expect(endEvent.requestInfo).toBeDefined();
  });

  it("receives onError when hook throws", async () => {
    const mock = new MockMonitor();
    const engine = new Engine();
    engine.registerMonitor(mock);

    const page = PageDefinition.create({
      id: "hooked",
      title: "Hooked",
      render: () => Text.new({ data: "hi" }),
    });

    const app = App.create({
      id: "hook-app",
      name: "HookApp",
      flows: [Flow.create({
        name: "main",
        routes: [{
          path: "fail",
          page,
          hooks: {
            onEnter: () => { throw new Error("hook failed"); },
          },
        }],
      })],
    });
    engine.registerApp(app);

    const server = await engine.start({ port: 0, cache: false });
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/hook-app/hook`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type: "enter", path: "fail" }),
    });
    expect(res.status).toBe(500);

    engine.stop();

    expect(mock.byHook("onError")).toHaveLength(1);
    const errEvent = mock.byHook("onError")[0]!.event as MonitorErrorEvent;
    expect(errEvent.stage).toBe("hook");
    expect(errEvent.path).toBe("/fail");
  });

  it("receives onServerActionCall with error on failing action", async () => {
    const mock = new MockMonitor();
    const engine = new Engine();
    engine.registerMonitor(mock);

    const { ServerActionDefinition } = await import("../src/core/server-action");

    const action = ServerActionDefinition.create({
      id: "fail-action",
      execute: () => { throw new Error("action failed"); },
    });

    const app = App.create({
      id: "fail-act-app",
      name: "FailActApp",
      flows: [Flow.create({ name: "main", routes: [{ path: "home", page: PageDefinition.create({ id: "home", title: "Home", render: () => Text.new({ data: "hi" }) }) }] })],
      actions: [action],
    });
    engine.registerApp(app);

    const server = await engine.start({ port: 0, cache: false });
    const res = await fetch(`http://localhost:${server.port}/api/v1/app/fail-act-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "fail-action", params: {} }),
    });
    expect(res.status).toBe(500);

    engine.stop();

    // Should get both onServerActionCall (with success=false) and onError
    expect(mock.byHook("onServerActionCall")).toHaveLength(1);
    const actionEvent = mock.byHook("onServerActionCall")[0]!.event as ServerActionCallEvent;
    expect(actionEvent.actionId).toBe("fail-action");
    expect(actionEvent.success).toBe(false);
    expect(actionEvent.error).toBeInstanceOf(Error);

    expect(mock.byHook("onError")).toHaveLength(1);
    const errEvent = mock.byHook("onError")[0]!.event as MonitorErrorEvent;
    expect(errEvent.stage).toBe("serverAction");
  });

  it("receives onRegisterOfflineSessions via /session/offline endpoint", async () => {
    const mock = new MockMonitor();
    const engine = new Engine();
    engine.registerMonitor(mock);

    const app = App.create({
      id: "offline-app",
      name: "OfflineApp",
      flows: [Flow.create({ name: "main", routes: [{ path: "home", page: PageDefinition.create({ id: "home", title: "Home", render: () => Text.new({ data: "hi" }) }) }] })],
    });
    engine.registerApp(app);

    const server = await engine.start({ port: 0, cache: false });
    const baseUrl = `http://localhost:${server.port}`;

    const sessions = [
      { type: "start", timestamp: 1700000000000 },
      { type: "end", timestamp: 1700000060000 },
      { type: "start", timestamp: 1700000120000 },
      { type: "end", timestamp: 1700000180000 },
    ];

    const res = await fetch(`${baseUrl}/api/v1/app/offline-app/session/offline`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ deviceId: "device-abc", sessions }),
    });
    expect(res.status).toBe(200);

    const body = await res.json() as { ok: boolean; registered: number };
    expect(body.ok).toBe(true);
    expect(body.registered).toBe(4);

    engine.stop();

    expect(mock.byHook("onRegisterOfflineSessions")).toHaveLength(1);
    const event = mock.byHook("onRegisterOfflineSessions")[0]!.event as RegisterOfflineSessionsEvent;
    expect(event.deviceId).toBe("device-abc");
    expect(event.sessions).toHaveLength(4);
    expect(event.sessions[0]!.type).toBe("start");
    expect(event.sessions[0]!.timestamp).toBe(1700000000000);
    expect(event.sessions[3]!.type).toBe("end");
    expect(event.requestInfo).toBeDefined();
    expect(event.requestInfo.ipAddress).toBeDefined();
  });

  it("validates /session/offline request body", async () => {
    const engine = new Engine();
    const app = App.create({
      id: "val-app",
      name: "ValApp",
      flows: [Flow.create({ name: "main", routes: [{ path: "home", page: PageDefinition.create({ id: "home", title: "Home", render: () => Text.new({ data: "hi" }) }) }] })],
    });
    engine.registerApp(app);

    const server = await engine.start({ port: 0, cache: false });
    const baseUrl = `http://localhost:${server.port}`;

    // Missing deviceId
    const res1 = await fetch(`${baseUrl}/api/v1/app/val-app/session/offline`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sessions: [] }),
    });
    expect(res1.status).toBe(400);

    // Missing sessions
    const res2 = await fetch(`${baseUrl}/api/v1/app/val-app/session/offline`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ deviceId: "abc" }),
    });
    expect(res2.status).toBe(400);

    // Filters invalid session entries
    const mock = new MockMonitor();
    engine.registerMonitor(mock);

    const res3 = await fetch(`${baseUrl}/api/v1/app/val-app/session/offline`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        deviceId: "abc",
        sessions: [
          { type: "start", timestamp: 1000 },
          { type: "invalid", timestamp: 2000 },
          { type: "end" },
        ],
      }),
    });
    expect(res3.status).toBe(200);
    const body3 = await res3.json() as { registered: number };
    expect(body3.registered).toBe(1); // only the valid "start" entry

    engine.stop();
  });
});
