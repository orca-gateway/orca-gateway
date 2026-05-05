import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { TimingCollector } from "../src/core/timing";
import { DebugStore } from "../src/core/debug-store";
import type { TimingData } from "../src/core/timing";
import {
  Engine,
  App,
  Flow,
  PageDefinition,
} from "../src/core";
import { Text } from "../src/components";

// ── 19.1: TimingCollector ────────────────────────────────

describe("19.1: TimingCollector", () => {
  test("mark pairs produce stage durations", () => {
    const tc = new TimingCollector();
    tc.mark("getInfoStart");
    tc.mark("getInfoEnd");
    tc.mark("renderStart");
    tc.mark("renderEnd");
    tc.mark("requestReceived");
    tc.mark("responseSent");

    const data = tc.toTimingData("/home", "GET");

    expect(data.path).toBe("/home");
    expect(data.method).toBe("GET");
    expect(typeof data.stages.getInfo).toBe("number");
    expect(data.stages.getInfo).toBeGreaterThanOrEqual(0);
    expect(typeof data.stages.render).toBe("number");
    expect(data.stages.render).toBeGreaterThanOrEqual(0);
    expect(data.totalMs).toBeGreaterThanOrEqual(0);
    expect(typeof data.timestamp).toBe("number");
  });

  test("missing mark pairs are excluded from stages", () => {
    const tc = new TimingCollector();
    tc.mark("requestReceived");
    tc.mark("responseSent");
    // No getInfoStart/End etc.

    const data = tc.toTimingData("/test", "POST");

    expect(data.stages.getInfo).toBeUndefined();
    expect(data.stages.getState).toBeUndefined();
    expect(data.stages.render).toBeUndefined();
    expect(data.stages.flatten).toBeUndefined();
    expect(data.stages.postRender).toBeUndefined();
    expect(data.stages.middleware).toBeUndefined();
  });

  test("defaults: cacheStatus=none, componentCount=0, responseSizeBytes=0", () => {
    const tc = new TimingCollector();
    tc.mark("requestReceived");
    tc.mark("responseSent");

    const data = tc.toTimingData("/x", "GET");

    expect(data.cacheStatus).toBe("none");
    expect(data.componentCount).toBe(0);
    expect(data.responseSizeBytes).toBe(0);
  });

  test("setting componentCount, responseSizeBytes, cacheStatus is reflected", () => {
    const tc = new TimingCollector();
    tc.componentCount = 5;
    tc.responseSizeBytes = 1234;
    tc.cacheStatus = "hit";
    tc.mark("requestReceived");
    tc.mark("responseSent");

    const data = tc.toTimingData("/cached", "GET");

    expect(data.componentCount).toBe(5);
    expect(data.responseSizeBytes).toBe(1234);
    expect(data.cacheStatus).toBe("hit");
  });

  test("totalMs is computed from requestReceived to responseSent", () => {
    const tc = new TimingCollector();
    tc.mark("requestReceived");
    // Simulate some work
    let sum = 0;
    for (let i = 0; i < 10000; i++) sum += i;
    tc.mark("responseSent");

    const data = tc.toTimingData("/slow", "GET");

    expect(data.totalMs).toBeGreaterThanOrEqual(0);
    // Prevent unused variable warning
    expect(sum).toBeGreaterThan(0);
  });

  test("stage durations are rounded to 2 decimal places", () => {
    const tc = new TimingCollector();
    tc.mark("getInfoStart");
    tc.mark("getInfoEnd");
    tc.mark("requestReceived");
    tc.mark("responseSent");

    const data = tc.toTimingData("/round", "GET");

    if (data.stages.getInfo !== undefined) {
      const str = data.stages.getInfo.toString();
      const parts = str.split(".");
      if (parts.length === 2) {
        expect(parts[1]!.length).toBeLessThanOrEqual(2);
      }
    }
    // totalMs should also be rounded
    const totalStr = data.totalMs.toString();
    const totalParts = totalStr.split(".");
    if (totalParts.length === 2) {
      expect(totalParts[1]!.length).toBeLessThanOrEqual(2);
    }
  });
});

// ── 19.2: DebugStore ──────────────────────────────────────

describe("19.2: DebugStore", () => {
  function makeTiming(path: string): TimingData {
    return {
      path,
      method: "GET",
      stages: {},
      componentCount: 1,
      responseSizeBytes: 100,
      cacheStatus: "none",
      totalMs: 5,
      timestamp: Date.now(),
    };
  }

  test("stores and retrieves entries", () => {
    const store = new DebugStore();
    store.push(makeTiming("/a"));
    store.push(makeTiming("/b"));

    const all = store.getAll();
    expect(all).toHaveLength(2);
    expect(all[0]!.path).toBe("/a");
    expect(all[1]!.path).toBe("/b");
  });

  test("getAll returns a copy (no mutation)", () => {
    const store = new DebugStore();
    store.push(makeTiming("/a"));

    const all1 = store.getAll();
    all1.push(makeTiming("/hacked"));

    const all2 = store.getAll();
    expect(all2).toHaveLength(1);
  });

  test("ring buffer evicts oldest when at capacity", () => {
    const store = new DebugStore(3);
    store.push(makeTiming("/1"));
    store.push(makeTiming("/2"));
    store.push(makeTiming("/3"));
    store.push(makeTiming("/4")); // should evict /1

    const all = store.getAll();
    expect(all).toHaveLength(3);
    expect(all[0]!.path).toBe("/2");
    expect(all[1]!.path).toBe("/3");
    expect(all[2]!.path).toBe("/4");
  });

  test("default capacity is 100", () => {
    const store = new DebugStore();
    for (let i = 0; i < 110; i++) {
      store.push(makeTiming(`/${i}`));
    }

    const all = store.getAll();
    expect(all).toHaveLength(100);
    // The first 10 should have been evicted
    expect(all[0]!.path).toBe("/10");
    expect(all[99]!.path).toBe("/109");
  });
});

// ── 19.3: HTTP Integration ────────────────────────────────

describe("19.3: HTTP integration - X-Orca-Timing header", () => {
  const homePage = PageDefinition.create({
    id: "timing-home",
    title: "Timing Home",
    state: [{ key: "count", scope: "page", initial: 0 }],
    render: () => Text.new({ data: "hello" }),
  });

  const homeFlow = Flow.create({
    name: "main",
    routes: [{ path: "home", page: homePage }],
  });

  const app = App.create({
    id: "timing-app",
    name: "Timing App",
    flows: [homeFlow],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<Engine["start"]>>;

  beforeAll(async () => {
    server = await engine.start({ port: 0, cache: false });
  });
  afterAll(() => engine.stop());

  test("X-Orca-Timing header is absent without x-orca-debug", async () => {
    const res = await fetch(
      `http://localhost:${server.port}/api/v1/app/timing-app/page/home`,
    );
    expect(res.status).toBe(200);
    expect(res.headers.get("X-Orca-Timing")).toBeNull();
  });

  test("X-Orca-Timing header is present with x-orca-debug=true", async () => {
    const res = await fetch(
      `http://localhost:${server.port}/api/v1/app/timing-app/page/home`,
      {
        headers: { "x-orca-debug": "true" },
      },
    );
    expect(res.status).toBe(200);

    const timingHeader = res.headers.get("X-Orca-Timing");
    expect(timingHeader).not.toBeNull();

    const timingData: TimingData = JSON.parse(timingHeader!);
    expect(timingData.path).toBe("/home");
    expect(timingData.method).toBe("GET");
    expect(typeof timingData.totalMs).toBe("number");
    expect(timingData.totalMs).toBeGreaterThanOrEqual(0);
    expect(typeof timingData.timestamp).toBe("number");
    expect(timingData.componentCount).toBeGreaterThan(0);
    expect(timingData.responseSizeBytes).toBeGreaterThan(0);
    expect(timingData.cacheStatus).toBe("none");
  });

  test("timing stages include getInfo, getState, render, flatten, postRender", async () => {
    const res = await fetch(
      `http://localhost:${server.port}/api/v1/app/timing-app/page/home`,
      {
        headers: { "x-orca-debug": "true" },
      },
    );
    const timingData: TimingData = JSON.parse(res.headers.get("X-Orca-Timing")!);

    // All stages should be present since no cache is used
    expect(typeof timingData.stages.getInfo).toBe("number");
    expect(typeof timingData.stages.getState).toBe("number");
    expect(typeof timingData.stages.render).toBe("number");
    expect(typeof timingData.stages.flatten).toBe("number");
    expect(typeof timingData.stages.postRender).toBe("number");
  });

  test("timing includes middleware stage", async () => {
    const res = await fetch(
      `http://localhost:${server.port}/api/v1/app/timing-app/page/home`,
      {
        headers: { "x-orca-debug": "true" },
      },
    );
    const timingData: TimingData = JSON.parse(res.headers.get("X-Orca-Timing")!);

    expect(typeof timingData.stages.middleware).toBe("number");
    expect(timingData.stages.middleware).toBeGreaterThanOrEqual(0);
  });

  test("x-orca-debug=false does not produce timing header", async () => {
    const res = await fetch(
      `http://localhost:${server.port}/api/v1/app/timing-app/page/home`,
      {
        headers: { "x-orca-debug": "false" },
      },
    );
    expect(res.headers.get("X-Orca-Timing")).toBeNull();
  });
});

describe("19.4: GET /api/v1/debug/last-requests", () => {
  const homePage = PageDefinition.create({
    id: "debug-home",
    title: "Debug Home",
    render: () => Text.new({ data: "hello" }),
  });

  const homeFlow = Flow.create({
    name: "main",
    routes: [{ path: "home", page: homePage }],
  });

  const app = App.create({
    id: "debug-app",
    name: "Debug App",
    flows: [homeFlow],
  });

  const engine = new Engine();
  engine.registerApp(app);
  let server: Awaited<ReturnType<Engine["start"]>>;

  beforeAll(async () => {
    server = await engine.start({ port: 0, cache: false, enableDebugEndpoint: true });
  });
  afterAll(() => engine.stop());

  test("returns empty array initially", async () => {
    const res = await fetch(
      `http://localhost:${server.port}/api/v1/debug/last-requests`,
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as TimingData[];
    expect(Array.isArray(body)).toBe(true);
  });

  test("accumulates debug requests in the store", async () => {
    // Make a debug request
    await fetch(
      `http://localhost:${server.port}/api/v1/app/debug-app/page/home`,
      { headers: { "x-orca-debug": "true" } },
    );

    // Make another debug request
    await fetch(
      `http://localhost:${server.port}/api/v1/app/debug-app/page/home`,
      { headers: { "x-orca-debug": "true" } },
    );

    const res = await fetch(
      `http://localhost:${server.port}/api/v1/debug/last-requests`,
    );
    const body = (await res.json()) as TimingData[];
    expect(body.length).toBeGreaterThanOrEqual(2);

    // All entries should have path /home
    for (const entry of body) {
      expect(entry.path).toBe("/home");
      expect(entry.method).toBe("GET");
      expect(typeof entry.totalMs).toBe("number");
    }
  });

  test("non-debug requests are not stored", async () => {
    // Get current count
    const res1 = await fetch(
      `http://localhost:${server.port}/api/v1/debug/last-requests`,
    );
    const before = ((await res1.json()) as TimingData[]).length;

    // Make a non-debug request
    await fetch(
      `http://localhost:${server.port}/api/v1/app/debug-app/page/home`,
    );

    // Count should not increase
    const res2 = await fetch(
      `http://localhost:${server.port}/api/v1/debug/last-requests`,
    );
    const after = ((await res2.json()) as TimingData[]).length;
    expect(after).toBe(before);
  });
});
