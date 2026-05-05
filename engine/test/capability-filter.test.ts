// Unit tests for filterByCapabilities (Epic 25b slice 2, task 25b.3).
//
// Covers the eight enumerated cases from the slice 2 plan:
//   1. Unversioned client → no-op (pre-25b behavior)
//   2. `graceful` strip of an unsupported primitive widget
//   3. `graceful` strip of an unsupported Value kind inside a prop
//   4. `graceful` strip of an unsupported Action kind inside actions
//   5. `warn` wraps the tree with a FallbackPrompt banner
//   6. `require` replaces the entire tree with a single blocking FallbackPrompt
//   7. Structure-widget `graceful` → promoted to `warn` (dangling-slot guard)
//   8. Dropped nodes with children → children re-parented correctly

import { describe, test, expect } from "bun:test";
import { filterByCapabilities } from "../src/core/capability-filter";
import { createStaticPolicyResolver } from "../src/core/fallback-policy";
import type { CapabilityVector } from "../src/types/context";
import type { ComponentNode } from "../src/types/node";

// Minimal vector covering the widgets/values these tests use. When a test
// wants a feature to appear unsupported, it rebuilds this vector with that
// feature omitted.
const FULL_VECTOR: CapabilityVector = {
  protocolVersion: "1.0.0",
  sdkSemver: "0.1.0",
  widgets: ["Column", "Text", "Divider", "Scaffold", "FallbackPrompt"],
  valueKinds: ["static", "state", "info", "request", "event", "transform", "conditional", "tween", "tweenSequence"],
  actionKinds: ["navigate", "setState"],
  transformKinds: ["toString", "toUpperCase"],
  boolExprOps: ["eq", "neq"],
};

const graceful = createStaticPolicyResolver({ default: "graceful" });
const warn = createStaticPolicyResolver({ default: "warn" });
const require_ = createStaticPolicyResolver({ default: "require" });

// Small node factory to keep tests readable.
function n(
  id: string,
  type: string,
  opts: Partial<ComponentNode> = {},
): ComponentNode {
  return {
    id,
    type,
    kind: opts.kind ?? "primitive",
    childMode: opts.childMode ?? "none",
    props: opts.props ?? {},
    children: opts.children ?? [],
    watches: opts.watches ?? [],
    ...(opts.actions ? { actions: opts.actions } : {}),
  };
}

describe("filterByCapabilities", () => {
  test("unversioned client returns the tree unchanged", () => {
    const tree = [n("r", "Column", { kind: "layout", childMode: "multi" })];
    const result = filterByCapabilities(tree, undefined, graceful);
    expect(result.components).toBe(tree); // same reference, no copy
    expect(result.droppedFeatures).toEqual([]);
    expect(result.replacedWithBlocker).toBe(false);
    expect(result.addedWarnBanner).toBe(false);
  });

  test("graceful strips an unsupported primitive widget", () => {
    // Vector omits Divider.
    const vector = { ...FULL_VECTOR, widgets: ["Column", "Text", "FallbackPrompt"] };
    const tree: ComponentNode[] = [
      n("root", "Column", {
        kind: "layout",
        childMode: "multi",
        children: ["t1", "d1", "t2"],
      }),
      n("t1", "Text", { props: { data: "a" } }),
      n("d1", "Divider", { props: { thickness: 1 } }),
      n("t2", "Text", { props: { data: "b" } }),
    ];
    const result = filterByCapabilities(tree, vector, graceful);
    expect(result.replacedWithBlocker).toBe(false);
    expect(result.addedWarnBanner).toBe(false);
    expect(result.droppedFeatures).toContain("widget.Divider");

    // The Divider node is gone; root's children list lost its reference.
    const root = result.components.find((n) => n.id === "root")!;
    expect(root.children).toEqual(["t1", "t2"]);
    expect(result.components.some((n) => n.id === "d1")).toBe(false);
  });

  test("graceful strips an unsupported Value kind inside a prop", () => {
    // Vector omits the `state` Value kind.
    const vector = {
      ...FULL_VECTOR,
      valueKinds: FULL_VECTOR.valueKinds.filter((k) => k !== "state"),
    };
    const tree: ComponentNode[] = [
      n("root", "Text", {
        props: { data: { type: "state", key: "count", scope: "page" } },
      }),
    ];
    const result = filterByCapabilities(tree, vector, graceful);
    // The root's type (Text) is still supported, but it carries an
    // unsupported value kind. graceful drops the root entirely since it's
    // a leaf with no children to reparent.
    expect(result.droppedFeatures).toContain("value.state");
    expect(result.components.find((n) => n.id === "root")).toBeUndefined();
  });

  test("graceful strips an unsupported Action kind", () => {
    // Vector omits `navigate`.
    const vector = { ...FULL_VECTOR, actionKinds: ["setState"] };
    const tree: ComponentNode[] = [
      n("root", "Text", {
        actions: {
          onTap: { type: "navigate", route: "/somewhere" },
        },
      }),
    ];
    const result = filterByCapabilities(tree, vector, graceful);
    expect(result.droppedFeatures).toContain("action.navigate");
    // Leaf Text node with the unsupported action is dropped entirely.
    expect(result.components.find((n) => n.id === "root")).toBeUndefined();
  });

  test("warn wraps the tree with a FallbackPrompt banner", () => {
    const vector = { ...FULL_VECTOR, widgets: ["Column", "Text", "FallbackPrompt"] };
    const tree: ComponentNode[] = [
      n("root", "Column", {
        kind: "layout",
        childMode: "multi",
        children: ["t1", "d1"],
      }),
      n("t1", "Text", { props: { data: "hi" } }),
      n("d1", "Divider", {}),
    ];
    const result = filterByCapabilities(tree, vector, warn);
    expect(result.replacedWithBlocker).toBe(false);
    expect(result.addedWarnBanner).toBe(true);

    // New root is the synthetic wrapper Column.
    const newRoot = result.components[0];
    expect(newRoot.id).toBe("__caps_warn_root__");
    expect(newRoot.type).toBe("Column");
    expect(newRoot.children).toEqual(["__caps_warn_banner__", "root"]);

    // Second node is the banner FallbackPrompt.
    const banner = result.components[1];
    expect(banner.id).toBe("__caps_warn_banner__");
    expect(banner.type).toBe("FallbackPrompt");
    expect(banner.props.severity).toBe("warn");

    // Original tree survives intact after the banner.
    const originalRoot = result.components.find((n) => n.id === "root");
    expect(originalRoot?.children).toEqual(["t1", "d1"]);
    expect(result.components.some((n) => n.id === "d1")).toBe(true);
  });

  test("require replaces the entire tree with a blocking FallbackPrompt", () => {
    const vector = { ...FULL_VECTOR, widgets: ["Column", "Text", "FallbackPrompt"] };
    const tree: ComponentNode[] = [
      n("root", "Column", {
        kind: "layout",
        childMode: "multi",
        children: ["t1", "d1"],
      }),
      n("t1", "Text", {}),
      n("d1", "Divider", {}),
    ];
    const result = filterByCapabilities(tree, vector, require_);
    expect(result.replacedWithBlocker).toBe(true);
    expect(result.components).toHaveLength(1);
    expect(result.components[0].id).toBe("__caps_block_root__");
    expect(result.components[0].type).toBe("FallbackPrompt");
    expect(result.components[0].props.severity).toBe("blocking");
  });

  test("structure-widget graceful is promoted to warn (dangling-slot guard)", () => {
    // Scaffold body slot points at a widget whose type is unsupported.
    // graceful would normally drop the child, but that would leave the
    // slot pointer dangling — so the filter promotes this node's handling
    // to warn instead.
    const vector = { ...FULL_VECTOR, widgets: ["Scaffold", "Text", "FallbackPrompt"] };
    const tree: ComponentNode[] = [
      n("root", "Scaffold", {
        kind: "structure",
        childMode: "none",
        children: ["body"],
        props: { body: "body" },
      }),
      n("body", "Divider", {}),
    ];
    const result = filterByCapabilities(tree, vector, graceful);
    // Promoted to warn → tree wrapped with banner, original slot structure
    // preserved (no dangling pointer).
    expect(result.replacedWithBlocker).toBe(false);
    expect(result.addedWarnBanner).toBe(true);
    expect(result.components.some((n) => n.id === "body")).toBe(true);
  });

  test("dropped nodes with children re-parent their children to the parent", () => {
    // Vector omits "Divider". The Divider here has children that should
    // become grandchildren of the Column.
    const vector = { ...FULL_VECTOR, widgets: ["Column", "Text", "FallbackPrompt"] };
    const tree: ComponentNode[] = [
      n("root", "Column", {
        kind: "layout",
        childMode: "multi",
        children: ["d1"],
      }),
      n("d1", "Divider", {
        // Divider is a primitive so this is a contrived test shape, but the
        // reparenting logic is widget-agnostic and should still apply.
        children: ["t1", "t2"],
      }),
      n("t1", "Text", { props: { data: "a" } }),
      n("t2", "Text", { props: { data: "b" } }),
    ];
    const result = filterByCapabilities(tree, vector, graceful);
    const root = result.components.find((n) => n.id === "root")!;
    expect(root.children).toEqual(["t1", "t2"]);
    expect(result.components.some((n) => n.id === "d1")).toBe(false);
    expect(result.components.some((n) => n.id === "t1")).toBe(true);
    expect(result.components.some((n) => n.id === "t2")).toBe(true);
  });

  test("FallbackPrompt is always supported even if the vector omits it", () => {
    // Paranoid invariant: FallbackPrompt is the frozen emergency channel.
    // Even a pathologically-small vector must render it correctly — the
    // filter hardcodes it into the support set before lookup.
    const vector = {
      ...FULL_VECTOR,
      widgets: ["Column"], // explicitly no FallbackPrompt
    };
    const tree: ComponentNode[] = [
      n("root", "FallbackPrompt", {
        props: { title: "x", body: "y", severity: "info" },
      }),
    ];
    const result = filterByCapabilities(tree, vector, graceful);
    expect(result.droppedFeatures).not.toContain("widget.FallbackPrompt");
    expect(result.components.some((n) => n.id === "root")).toBe(true);
  });

  test("empty component list is a no-op", () => {
    const result = filterByCapabilities([], FULL_VECTOR, graceful);
    expect(result.components).toEqual([]);
    expect(result.replacedWithBlocker).toBe(false);
    expect(result.addedWarnBanner).toBe(false);
  });

  test("tree with all-supported features is returned unchanged", () => {
    const tree: ComponentNode[] = [
      n("root", "Column", {
        kind: "layout",
        childMode: "multi",
        children: ["t1"],
      }),
      n("t1", "Text", { props: { data: "hi" } }),
    ];
    const result = filterByCapabilities(tree, FULL_VECTOR, graceful);
    expect(result.components).toBe(tree);
    expect(result.droppedFeatures).toEqual([]);
  });
});
