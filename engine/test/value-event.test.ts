import { describe, expect, it } from "bun:test";
import { V, SetState, flatten, type FlattenOptions } from "../src/types";
import type { PageContext } from "../src/types/context";
import { TextField } from "../src/components/input/text-field";
import { ValueResolver } from "../src/core/value-resolver";

// Phase 2c — V.event wire-format tests.
//
// EventValue is a CLIENT-resolved Value: the server passes it through
// unchanged in `watches` and `props`, and the SDK's action_executor binds
// `key` against `eventData` at fire time. These tests lock down the
// server-side contract (pass-through, no resolution) so we catch any
// accidental server-side resolution that would break input callbacks.

function makeCtx(): PageContext {
  return {
    requestInfo: {} as PageContext["requestInfo"],
    pageId: "test",
    routePath: "/",
    routeParams: {},
    pageState: { username: "" },
    appState: {},
  };
}

function opts(): FlattenOptions {
  return { ctx: makeCtx(), info: undefined };
}

describe("V.event — authoring helper", () => {
  it("produces an EventValue with the given key", () => {
    const v = V.event("value");
    expect(v).toEqual({ type: "event", key: "value" });
  });
});

describe("V.event — server-side pass-through (no resolution)", () => {
  it("resolver leaves event values untouched", () => {
    const resolver = new ValueResolver({
      pageState: {},
      appState: {},
      infoData: null,
      requestInfo: {} as PageContext["requestInfo"],
    });
    const ev = V.event("value");
    const result = resolver.resolve(ev);
    expect(result).toEqual(ev);
  });

  it("resolveProps preserves event values inside nested actions", () => {
    const action = SetState("username", V.event("value"));
    const resolver = new ValueResolver({
      pageState: {},
      appState: {},
      infoData: null,
      requestInfo: {} as PageContext["requestInfo"],
    });
    const resolved = resolver.resolveProps(action as unknown as Record<string, unknown>);
    // The action's `value` field still carries the EventValue.
    expect(resolved.value).toEqual({ type: "event", key: "value" });
  });
});

describe("V.event — wire format via TextField.onChange", () => {
  it("TextField onChange SetState(V.event('value')) survives flatten", () => {
    const field = TextField.new({
      value: V.pageState("username"),
      actions: {
        onChange: SetState("username", V.event("value")),
      },
    });

    const nodes = flatten(field, opts());
    const node = nodes[0];
    expect(node.type).toBe("TextField");
    expect(node.actions).toBeDefined();

    const onChange = node.actions!.onChange as { type: string; key: string; value: unknown };
    expect(onChange.type).toBe("setState");
    expect(onChange.key).toBe("username");
    expect(onChange.value).toEqual({ type: "event", key: "value" });
  });

  it("V.event is not included in the node's watches list (client-only)", () => {
    const field = TextField.new({
      value: V.pageState("username"),
      actions: {
        onChange: SetState("username", V.event("value")),
      },
    });

    const nodes = flatten(field, opts());
    const node = nodes[0];
    // `username` is watched (V.pageState), but event values don't produce
    // watches — they resolve from the event payload, not app/page state.
    expect(node.watches).toContain("username");
    // Make sure no watches entry starts with "event." (there isn't such a
    // convention; this guards against regressions where someone adds one).
    for (const w of node.watches) {
      expect(w.startsWith("event.")).toBe(false);
    }
  });
});
