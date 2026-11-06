// Epic 23b, task 23b.7 — page targets vs widget targets.
import { beforeEach, describe, expect, test } from "bun:test";
import { findOffTargetWidgets, resetOffTargetWarnings, warnOffTargetOnce } from "../src/core/target-check";
import { PageDefinition } from "../src/core/page-definition";
import { Text } from "../src/components";

describe("findOffTargetWidgets", () => {
  test("names each widget type a declared target cannot render, once", () => {
    const hits = findOffTargetWidgets(
      [{ type: "Column" }, { type: "Drawer" }, { type: "Text" }, { type: "Drawer" }, { type: "SnackBar" }],
      ["ios"],
    );
    expect(hits).toEqual([
      { type: "Drawer", missing: ["ios"] },
      { type: "SnackBar", missing: ["ios"] },
    ]);
  });

  test("all-platform widgets and unknown (plugin) types never hit", () => {
    expect(findOffTargetWidgets([{ type: "Column" }, { type: "GoogleMap" }], ["ios", "android", "web"])).toEqual([]);
  });

  test("a widget missing several targets lists all of them", () => {
    const hits = findOffTargetWidgets([{ type: "Checkbox" }], ["android", "ios"]);
    expect(hits).toEqual([{ type: "Checkbox", missing: ["ios"] }]);
  });
});

describe("warnOffTargetOnce", () => {
  beforeEach(() => resetOffTargetWarnings());

  test("logs once per page for the same hits, again for new ones", () => {
    const logs: string[] = [];
    const log = (m: string) => logs.push(m);
    const hits = [{ type: "Drawer", missing: ["ios"] as const }];
    expect(warnOffTargetOnce("home", hits, log)).toBe(true);
    expect(warnOffTargetOnce("home", hits, log)).toBe(false);
    expect(warnOffTargetOnce("settings", hits, log)).toBe(true);
    expect(warnOffTargetOnce("home", [...hits, { type: "Tooltip", missing: ["ios"] as const }], log)).toBe(true);
    expect(logs).toHaveLength(3);
    expect(logs[0]).toContain('page "home"');
    expect(logs[0]).toContain("Drawer (not on ios)");
    expect(logs[2]).toContain("Tooltip");
    expect(logs[2]).not.toContain("Drawer");
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
