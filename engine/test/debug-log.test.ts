import { describe, expect, it } from "bun:test";
import {
  V,
  DebugLog,
  flatten,
  type Action,
  type DebugLogAction,
  type FlattenOptions,
} from "../src/types";
import type { PageContext } from "../src/types/context";
import { PrimitiveWidget } from "../src/types";
import { ValueResolver } from "../src/core/value-resolver";

// ── Test widget ──────────────────────────────────────────────

class TestText extends PrimitiveWidget {
  readonly type = "Text";
  constructor(private data: string) {
    super();
  }
  getProps() {
    return { data: this.data };
  }
}

function makeCtx(pageState: Record<string, unknown> = {}): PageContext {
  return {
    requestInfo: {} as PageContext["requestInfo"],
    pageId: "t",
    routePath: "/",
    routeParams: {},
    pageState,
    appState: {},
  };
}

function opts(): FlattenOptions {
  return { ctx: makeCtx(), info: undefined };
}

// ── Tests ────────────────────────────────────────────────────

describe("DebugLog — helper shape", () => {
  it("empty call produces a bare debugLog action", () => {
    const a = DebugLog();
    expect(a.type).toBe("debugLog");
    expect(Object.keys(a)).toEqual(["type"]);
  });

  it("all optional fields round-trip", () => {
    const a = DebugLog({
      level: "info",
      tag: "checkout",
      message: "Qty changed",
      data: { qty: V.event("value"), cartTotal: V.pageState("total") },
      includeState: true,
      includeEvent: true,
      includeRequest: true,
      includeStackTrace: false,
    });
    expect(a.level).toBe("info");
    expect(a.tag).toBe("checkout");
    expect(a.message).toBe("Qty changed");
    expect(a.data).toEqual({
      qty: { type: "event", key: "value" },
      cartTotal: { type: "state", key: "total", scope: "page" },
    });
    expect(a.includeState).toBe(true);
    expect(a.includeEvent).toBe(true);
    expect(a.includeRequest).toBe(true);
    expect(a.includeStackTrace).toBe(false);
  });

  it("type-narrows against the Action union", () => {
    const a: Action = DebugLog({ message: "hi" });
    // Discriminate on the type string — if DebugLogAction isn't in the
    // union, this narrowing would widen to `never` and fail compile.
    if (a.type === "debugLog") {
      const narrow: DebugLogAction = a;
      expect(narrow.message).toBe("hi");
    }
  });
});

describe("DebugLog — wire format survives flatten + resolver", () => {
  it("static fields land unchanged in the action map", () => {
    class Btn extends PrimitiveWidget {
      readonly type = "TextButton";
      getProps() {
        return {};
      }
    }
    const b = new Btn();
    b.actions = {
      onTap: DebugLog({
        level: "warn",
        tag: "auth",
        message: "Login failed",
        includeState: true,
      }),
    };
    const nodes = flatten(b, opts());
    expect(nodes[0].actions?.onTap).toEqual({
      type: "debugLog",
      level: "warn",
      tag: "auth",
      message: "Login failed",
      includeState: true,
    });
  });

  it("info refs collapse server-side, state/event refs pass through to client", () => {
    const action = DebugLog({
      message: V.info("greeting"),
      data: {
        user: V.pageState("username"), // client-resolved
        evt: V.event("value"), // client-resolved
        platform: V.request("platform"), // server-resolved
      },
    });
    const resolver = new ValueResolver({
      pageState: { username: "alice" },
      appState: {},
      infoData: { greeting: "hello" },
      requestInfo: { platform: "iOS" } as PageContext["requestInfo"],
    });
    const resolved = resolver.resolveProps(
      action as unknown as Record<string, unknown>,
    );
    expect(resolved.message).toBe("hello");
    const dataOut = resolved.data as Record<string, unknown>;
    expect(dataOut.platform).toBe("iOS");
    // state + event references are forwarded untouched — the SDK resolves
    // them against live pageState / eventData when the action fires.
    expect(dataOut.user).toEqual({ type: "state", key: "username", scope: "page" });
    expect(dataOut.evt).toEqual({ type: "event", key: "value" });
  });
});
