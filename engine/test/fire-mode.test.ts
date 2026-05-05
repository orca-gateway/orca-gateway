import { describe, expect, it } from "bun:test";
import {
  Once,
  Always,
  DebugLog,
  Navigate,
  Sequential,
  type Action,
  type OnceAction,
  type AlwaysAction,
} from "../src/types";

// Engine-side wire-format tests for the Once / Always fire-mode wrappers.
// The actual dedupe happens client-side in the SDK's ActionExecutor — here
// we lock down the authored shape so the SDK can rely on it.

describe("Once() / Always() — authoring shape", () => {
  it("Once() wraps an action into type:'once'", () => {
    const nav = Navigate("/home");
    const wrapped = Once(nav);
    expect(wrapped).toEqual({ type: "once", action: nav });
  });

  it("Always() wraps an action into type:'always'", () => {
    const log = DebugLog({ message: "scroll end" });
    const wrapped = Always(log);
    expect(wrapped).toEqual({ type: "always", action: log });
  });

  it("nested Once(Always(...)) and Always(Once(...)) both round-trip", () => {
    const inner: Action = DebugLog({ message: "inner" });
    const o = Once(Always(inner));
    const a = Always(Once(inner));
    expect(o).toEqual({ type: "once", action: { type: "always", action: inner } });
    expect(a).toEqual({ type: "always", action: { type: "once", action: inner } });
  });

  it("Once / Always work inside Sequential as any other action", () => {
    const seq = Sequential(Once(DebugLog({ message: "first" })), DebugLog({ message: "every" }));
    expect(seq.type).toBe("actionGroup");
    expect(seq.mode).toBe("sequential");
    expect(seq.actions).toHaveLength(2);
    const [first] = seq.actions;
    expect((first as OnceAction).type).toBe("once");
  });
});

describe("Once() / Always() — type narrowing", () => {
  it("type-narrows against the Action union", () => {
    const a: Action = Once(DebugLog());
    if (a.type === "once") {
      const narrow: OnceAction = a;
      expect(narrow.action.type).toBe("debugLog");
    }
    const b: Action = Always(DebugLog());
    if (b.type === "always") {
      const narrow: AlwaysAction = b;
      expect(narrow.action.type).toBe("debugLog");
    }
  });
});
