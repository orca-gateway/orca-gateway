// End-to-end test for Epic 25b task 25b.11: forward + backward compat.
//
// The epic spec:
//   "Spin up SDK v1 + server that supports v2-only features. Verify all
//    three policies: graceful renders the page without the v2 node; warn
//    renders the page plus a banner FallbackPrompt; require returns a
//    full-page FallbackPrompt. Flip min_sdk_version above v1 → verify 426
//    response with blocking FallbackPrompt."
//
// Implementation notes:
//   - "SDK v1" is simulated by sending requests whose caps vector omits a
//     specific widget (Divider). The server can't tell the difference
//     between a truly-old SDK and a test pretending to be old — both
//     produce the same `x-orca-caps-hash` header.
//   - The authored page uses Column([Text, Divider, Text]) so filtering
//     has something meaningful to strip (graceful) or wrap (warn).
//   - One engine instance serves all four scenarios via runtime reconfig
//     through setFallbackPolicy / setMinSdkVersion setters. This validates
//     the runtime-swap path alongside the policy behavior itself.
//   - The caps vector is pre-registered via a POST retry once per test so
//     each policy scenario can hit the fast path with hash-only requests,
//     mirroring what a real SDK after startup would do.

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import {
  App,
  Engine,
  Flow,
  PageDefinition,
  canonicalizeVector,
} from "../src/core";
import type { CapabilityVector } from "../src/types/context";
import { Column, Text, Divider } from "../src/components";
import { createHash } from "crypto";

type BunServer = import("bun").Server<undefined>;

function sha256Hex(input: string): string {
  return createHash("sha256").update(input).digest("hex");
}

// Simulated "SDK v1" that knows Column, Text, FallbackPrompt, but NOT
// Divider. The server supports Divider; the client doesn't. That's the
// exact forward-compat gap the epic wants tested.
const SDK_V1_VECTOR: CapabilityVector = {
  protocolVersion: "1.0.0",
  sdkSemver: "1.0.0",
  widgets: ["Column", "Text", "FallbackPrompt"],
  valueKinds: ["static"],
  actionKinds: [],
  transformKinds: [],
  boolExprOps: [],
};

const SDK_V1_HASH = sha256Hex(canonicalizeVector(SDK_V1_VECTOR));

let server: BunServer;
let engine: Engine;
let port: number;

beforeAll(async () => {
  // Authored page: Column wrapping [Text, Divider, Text]. Divider is the
  // widget our simulated v1 client doesn't support, so it's the filter's
  // target in every scenario below.
  const page = PageDefinition.create({
    id: "home",
    title: "Home",
    render: () =>
      Column.new({
        children: [
          Text.new({ data: "above" }),
          Divider.new({ thickness: 1 }),
          Text.new({ data: "below" }),
        ],
      }),
  });
  const flow = Flow.create({
    name: "main",
    routes: [{ path: "home", page }],
  });
  const app = App.create({ id: "capse2e", name: "Caps E2E", flows: [flow] });

  engine = new Engine();
  engine.registerApp(app);
  server = await engine.start({ port: 0, cache: false });
  port = server.port;

  // Pre-register the v1 vector with the engine's in-memory cache by sending
  // one warm-up POST retry. This mimics what the SDK does on its very first
  // request: send the hash, get 412, retry with the full vector. After
  // this, every test can hit the hash-only fast path.
  const warmup = await fetch(
    `http://localhost:${port}/api/v1/app/capse2e/page/home`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-orca-sdk-version": SDK_V1_VECTOR.sdkSemver,
        "x-orca-caps-hash": SDK_V1_HASH,
      },
      body: JSON.stringify({ _orcaCapsVector: SDK_V1_VECTOR }),
    },
  );
  if (warmup.status !== 200) {
    throw new Error(
      `warmup failed: status=${warmup.status}, body=${await warmup.text()}`,
    );
  }
});

afterAll(() => {
  engine.stop();
});

function capsHeaders(): Record<string, string> {
  return {
    "x-orca-sdk-version": SDK_V1_VECTOR.sdkSemver,
    "x-orca-caps-hash": SDK_V1_HASH,
  };
}

function url(): string {
  return `http://localhost:${port}/api/v1/app/capse2e/page/home`;
}

interface ComponentNode {
  id: string;
  type: string;
  kind: string;
  childMode: string;
  props: Record<string, unknown>;
  children: string[];
  watches: string[];
}

interface PageResponse {
  pageId: string;
  title: string;
  state: unknown[];
  components: ComponentNode[];
}

async function fetchPage(): Promise<Response> {
  return fetch(url(), { headers: capsHeaders() });
}

async function fetchPageJson(): Promise<PageResponse> {
  const res = await fetchPage();
  if (res.status !== 200) {
    throw new Error(`expected 200, got ${res.status}: ${await res.text()}`);
  }
  return (await res.json()) as PageResponse;
}

function findNode(nodes: ComponentNode[], id: string): ComponentNode | undefined {
  return nodes.find((n) => n.id === id);
}

// ── Scenario 1: graceful ──────────────────────────────────────────────────
// Epic 25b.11: "`graceful` renders the page without the v2 node"

describe("25b.11 graceful policy", () => {
  beforeAll(() => {
    engine.setFallbackPolicy({ default: "graceful" });
    engine.setMinSdkVersion({}); // ensure no 426 gate interferes
  });

  test("unsupported widget is stripped and siblings reparent", async () => {
    const body = await fetchPageJson();

    // The authored root (Column) should survive. Divider should be gone.
    // The Column's children array should be reduced from 3 → 2 (two Text
    // nodes) with the Divider removed and reparenting handled correctly.
    const column = body.components.find((n) => n.type === "Column");
    expect(column).toBeDefined();
    expect(column!.children.length).toBe(2);

    // No Divider anywhere.
    expect(body.components.find((n) => n.type === "Divider")).toBeUndefined();

    // Both text nodes still present.
    const texts = body.components.filter(
      (n) => n.type === "Text" && (n.props.data === "above" || n.props.data === "below"),
    );
    expect(texts.length).toBe(2);

    // No warn banner, no blocking root.
    expect(body.components.find((n) => n.id === "__caps_warn_banner__")).toBeUndefined();
    expect(body.components.find((n) => n.id === "__caps_block_root__")).toBeUndefined();
  });
});

// ── Scenario 2: warn ──────────────────────────────────────────────────────
// Epic 25b.11: "`warn` renders the page plus a banner FallbackPrompt"

describe("25b.11 warn policy", () => {
  beforeAll(() => {
    engine.setFallbackPolicy({ default: "warn" });
    engine.setMinSdkVersion({});
  });

  test("tree is wrapped with FallbackPrompt banner, original tree preserved", async () => {
    const body = await fetchPageJson();

    // Wrapper Column at the head of the components array.
    const wrapper = findNode(body.components, "__caps_warn_root__");
    expect(wrapper).toBeDefined();
    expect(wrapper!.type).toBe("Column");
    expect(wrapper!.children).toEqual(["__caps_warn_banner__", ...wrapper!.children.slice(1)]);
    expect(wrapper!.children.length).toBe(2);

    // The banner itself — frozen FallbackPrompt with severity=warn.
    const banner = findNode(body.components, "__caps_warn_banner__");
    expect(banner).toBeDefined();
    expect(banner!.type).toBe("FallbackPrompt");
    expect(banner!.props.severity).toBe("warn");
    expect(banner!.props.title).toBe("Some content needs an update");

    // The original tree is preserved intact — Divider SHOULD still be in
    // the components list because warn mode doesn't strip, only prepends.
    expect(body.components.find((n) => n.type === "Divider")).toBeDefined();
    const textNodes = body.components.filter((n) => n.type === "Text");
    expect(textNodes.length).toBeGreaterThanOrEqual(2);
  });
});

// ── Scenario 3: require ───────────────────────────────────────────────────
// Epic 25b.11: "`require` returns a full-page FallbackPrompt"

describe("25b.11 require policy", () => {
  beforeAll(() => {
    engine.setFallbackPolicy({ default: "require" });
    engine.setMinSdkVersion({});
  });

  test("entire tree is replaced with a blocking FallbackPrompt", async () => {
    const body = await fetchPageJson();

    // The whole tree becomes a single node.
    expect(body.components.length).toBe(1);

    const root = body.components[0];
    expect(root.id).toBe("__caps_block_root__");
    expect(root.type).toBe("FallbackPrompt");
    expect(root.props.severity).toBe("blocking");
    expect(root.props.title).toBe("Update required");

    // Nothing else from the authored tree leaks through.
    expect(body.components.find((n) => n.type === "Column")).toBeUndefined();
    expect(body.components.find((n) => n.type === "Text")).toBeUndefined();
    expect(body.components.find((n) => n.type === "Divider")).toBeUndefined();
  });
});

// ── Scenario 4: min SDK version → HTTP 426 ────────────────────────────────
// Epic 25b.11: "Flip min_sdk_version above v1 → verify 426 response with
// blocking FallbackPrompt."

describe("25b.6 + 25b.11 minimum SDK version gate", () => {
  beforeAll(() => {
    engine.setFallbackPolicy({ default: "graceful" }); // policy shouldn't matter — 426 is a hard gate
    engine.setMinSdkVersion({ appDefault: "2.0.0" }); // client is on 1.0.0 → below
  });

  test("client below min gets HTTP 426 with structured body + embedded blocking page", async () => {
    const res = await fetchPage();
    expect(res.status).toBe(426);

    const body = (await res.json()) as {
      error: string;
      minSdkVersion: string;
      clientSdkVersion: string;
      page: PageResponse;
    };

    // Structured diagnostic fields — future-smart SDKs can branch on these.
    expect(body.error).toBe("sdk_version_too_old");
    expect(body.minSdkVersion).toBe("2.0.0");
    expect(body.clientSdkVersion).toBe("1.0.0");

    // Embedded page IS a PageResponse — the frozen v1 shape every SDK can
    // render. A forward-compatible SDK that knows about 426 will use this
    // as its upgrade screen.
    expect(body.page.pageId).toBe("home");
    expect(body.page.components.length).toBe(1);
    const block = body.page.components[0];
    expect(block.type).toBe("FallbackPrompt");
    expect(block.props.severity).toBe("blocking");
    expect(block.props.title).toBe("Update required");
    expect(block.props.body).toContain("2.0.0");
  });

  test("pipeline was skipped — no authored content leaks into the 426 body", async () => {
    const res = await fetchPage();
    const body = (await res.json()) as {
      page: PageResponse;
    };
    // The authored page has Column/Text/Divider. None of those should
    // appear in the 426 response — the gate short-circuits the pipeline
    // entirely, so no filter, no cache, no render output.
    expect(body.page.components.find((n) => n.type === "Column")).toBeUndefined();
    expect(body.page.components.find((n) => n.type === "Text")).toBeUndefined();
    expect(body.page.components.find((n) => n.type === "Divider")).toBeUndefined();
  });
});

// ── Scenario 5: 426 gate releases when client is at or above minimum ──────

describe("25b.6 gate release paths", () => {
  test("client at exactly min version passes the gate", async () => {
    engine.setFallbackPolicy({ default: "graceful" });
    engine.setMinSdkVersion({ appDefault: SDK_V1_VECTOR.sdkSemver }); // same as client
    const res = await fetchPage();
    expect(res.status).toBe(200);
  });

  test("client above min version passes the gate", async () => {
    engine.setMinSdkVersion({ appDefault: "0.9.0" });
    const res = await fetchPage();
    expect(res.status).toBe(200);
  });

  test("unversioned client bypasses the gate entirely", async () => {
    engine.setMinSdkVersion({ appDefault: "99.0.0" }); // absurdly high
    // No caps headers → unversioned client → gate skipped.
    const res = await fetch(url());
    expect(res.status).toBe(200);
  });

  test("empty min disables the gate", async () => {
    engine.setMinSdkVersion({ appDefault: "" });
    const res = await fetchPage();
    expect(res.status).toBe(200);
  });

  test("per-env override tightens the gate", async () => {
    engine.setMinSdkVersion({
      appDefault: "0.5.0",
      envOverrides: { prod: "2.0.0" },
    });
    // With x-orca-env: prod, the override kicks in and blocks.
    const prodRes = await fetch(url(), {
      headers: { ...capsHeaders(), "x-orca-env": "prod" },
    });
    expect(prodRes.status).toBe(426);
    // Without the env header, the appDefault is used and the client passes.
    const stagingRes = await fetch(url(), { headers: capsHeaders() });
    expect(stagingRes.status).toBe(200);
  });

  test("per-env empty-string override disables the gate for that env", async () => {
    engine.setMinSdkVersion({
      appDefault: "99.0.0", // app-wide block
      envOverrides: { dev: "" }, // dev is unrestricted
    });
    const devRes = await fetch(url(), {
      headers: { ...capsHeaders(), "x-orca-env": "dev" },
    });
    expect(devRes.status).toBe(200);
  });
});
