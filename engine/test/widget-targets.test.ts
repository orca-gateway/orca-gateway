// Epic 23b, task 23b.2 — per-widget platform targets.
//
// `targets` generalises the Epic 38 `isSupportedOnWeb` bit: the list of
// platforms whose Orca SDK renders the widget natively. Every widget carries
// it, the default is all four platforms, and the six widgets with no iOS
// counterpart omit "ios" so a SwiftUI client degrades them via the caps
// vector instead of guessing. Drawer left that list in native-parity-s10
// (B10.C-S): the iOS SDK draws it as a side panel.
import { describe, expect, test } from "bun:test";
import { readFileSync } from "fs";
import { join } from "path";
import { WIDGET_REGISTRY } from "../src/core/widget-registry-gen";

const MANIFEST = join(import.meta.dir, "../../schema/widget-registry.json");
const ALL = ["flutter", "web", "android", "ios"];
const IOS_ORPHANS = ["Checkbox", "FloatingActionButton", "InkWell", "Radio", "SnackBar", "Tooltip"];
// Widgets only the native SDKs draw so far; Flutter and web degrade them.
const NATIVE_ONLY = ["Video"];

interface ManifestWidget { type: string; targets?: string[]; isSupportedOnWeb?: boolean }

describe("widget targets", () => {
  const manifest = JSON.parse(readFileSync(MANIFEST, "utf8")) as { widgets: ManifestWidget[] };

  test("every manifest widget carries a non-empty targets array of known platforms", () => {
    for (const w of manifest.widgets) {
      expect(w.targets, w.type).toBeDefined();
      expect(w.targets!.length, w.type).toBeGreaterThan(0);
      for (const t of w.targets!) expect(ALL, `${w.type}: ${t}`).toContain(t);
    }
  });

  test("default is all four platforms; only the iOS orphans omit ios", () => {
    for (const type of NATIVE_ONLY) expect(manifest.widgets.find((w) => w.type === type)?.targets, type).toEqual(["android", "ios"]);
    const noIos = manifest.widgets.filter((w) => !w.targets!.includes("ios")).map((w) => w.type).sort();
    expect(noIos).toEqual(IOS_ORPHANS);
    for (const w of manifest.widgets) {
      if (IOS_ORPHANS.includes(w.type)) expect(w.targets).toEqual(["flutter", "web", "android"]);
      else if (!NATIVE_ONLY.includes(w.type)) expect(w.targets).toEqual(ALL);
    }
  });

  test("B10.C-S Drawer targets all four platforms, ios included, in the manifest and the TS registry", () => {
    expect(manifest.widgets.find((w) => w.type === "Drawer")?.targets).toEqual(ALL);
    expect([...WIDGET_REGISTRY.Drawer.targets]).toEqual(ALL);
    expect(IOS_ORPHANS).not.toContain("Drawer");
  });

  test("isSupportedOnWeb is derived from targets", () => {
    for (const w of manifest.widgets) expect(w.isSupportedOnWeb, w.type).toBe(w.targets!.includes("web"));
  });

  test("the TS registry agrees with the manifest", () => {
    for (const w of manifest.widgets) expect([...WIDGET_REGISTRY[w.type].targets], w.type).toEqual(w.targets);
  });
});
