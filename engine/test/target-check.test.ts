// Epic 23b, task 23b.7 — page targets vs widget targets.
import { beforeEach, describe, expect, test } from "bun:test";
import { findOffTargetWidgets, resetOffTargetWarnings, warnOffTargetOnce } from "../src/core/target-check";
import { PageDefinition } from "../src/core/page-definition";
import { Text } from "../src/components";
import { WIDGET_REGISTRY } from "../src/core/widget-registry-gen";

describe("findOffTargetWidgets", () => {
  // No built-in widget is off ios since native parity step 8 (A8.3, A8.5): the
  // off-target examples are Video, on android and ios only, and an
  // android-only entry added to the registry; Tooltip and SnackBar no longer
  // hit on ios.
  test("names each widget type a declared target cannot render, once", () => {
    const registry = {
      ...WIDGET_REGISTRY,
      AndroidOnly: { ...WIDGET_REGISTRY.Video, type: "AndroidOnly", targets: ["android"] },
    };
    const hits = findOffTargetWidgets(
      [
        { type: "Column" }, { type: "Video" }, { type: "Text" }, { type: "AndroidOnly" }, { type: "Video" },
        { type: "Tooltip" }, { type: "SnackBar" }, { type: "AndroidOnly" },
      ],
      ["web", "ios"],
      registry,
    );
    expect(hits).toEqual([
      { type: "Video", missing: ["web"] },
      { type: "AndroidOnly", missing: ["web", "ios"] },
    ]);
  });

  test("B10.C-S Drawer is on every target, ios included: it never hits", () => {
    expect(findOffTargetWidgets([{ type: "Drawer" }, { type: "Video" }], ["flutter", "ios"])).toEqual([{ type: "Video", missing: ["flutter"] }]);
    expect(findOffTargetWidgets([{ type: "Drawer" }], ["flutter", "web", "android", "ios"])).toEqual([]);
  });

  test("all-platform widgets and unknown (plugin) types never hit", () => {
    expect(findOffTargetWidgets([{ type: "Column" }, { type: "GoogleMap" }], ["ios", "android", "web"])).toEqual([]);
  });

  test("a widget missing several targets lists all of them", () => {
    // Video is on android and ios only.
    const hits = findOffTargetWidgets([{ type: "Video" }], ["flutter", "web"]);
    expect(hits).toEqual([{ type: "Video", missing: ["flutter", "web"] }]);
  });
});

describe("warnOffTargetOnce", () => {
  beforeEach(() => resetOffTargetWarnings());

  test("logs once per page for the same hits, again for new ones", () => {
    const logs: string[] = [];
    const log = (m: string) => logs.push(m);
    const hits = [{ type: "FloatingActionButton", missing: ["ios"] as const }];
    expect(warnOffTargetOnce("home", hits, log)).toBe(true);
    expect(warnOffTargetOnce("home", hits, log)).toBe(false);
    expect(warnOffTargetOnce("settings", hits, log)).toBe(true);
    expect(warnOffTargetOnce("home", [...hits, { type: "Tooltip", missing: ["ios"] as const }], log)).toBe(true);
    expect(logs).toHaveLength(3);
    expect(logs[0]).toContain('page "home"');
    expect(logs[0]).toContain("FloatingActionButton (not on ios)");
    expect(logs[2]).toContain("Tooltip");
    expect(logs[2]).not.toContain("FloatingActionButton");
  });

  test("no hits, no log", () => {
    const logs: string[] = [];
    expect(warnOffTargetOnce("home", [], (m) => logs.push(m))).toBe(false);
    expect(logs).toEqual([]);
  });
});

describe("PageDefinition.create targets", () => {
  test("carries targets onto the page; undefined when not declared", () => {
    const withTargets = PageDefinition.create({ id: "a", title: "A", targets: ["ios", "android"], render: () => Text.new({ data: "x" }) });
    const without = PageDefinition.create({ id: "b", title: "B", render: () => Text.new({ data: "x" }) });
    expect(withTargets.targets).toEqual(["ios", "android"]);
    expect(without.targets).toBeUndefined();
  });
});
