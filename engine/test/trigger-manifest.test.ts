import { describe, expect, it } from "bun:test";
import { WIDGET_REGISTRY } from "../src/core/widget-registry-gen";
import type { ActionTrigger } from "../src/types";

// Lock down the trigger manifest. Each widget's `static readonly triggers`
// flows through the codegen into WIDGET_REGISTRY.<type>.triggers. Authors +
// tooling read this to know which triggers attach to which widget.

describe("Trigger manifest — per-widget triggers in widget-registry", () => {
  it("ElevatedButton fires onTap and onLongPress", () => {
    expect(WIDGET_REGISTRY.ElevatedButton.triggers).toEqual([
      "onTap",
      "onLongPress",
    ]);
  });

  it("TextField fires onChange", () => {
    expect(WIDGET_REGISTRY.TextField.triggers).toEqual(["onChange"]);
  });

  it("GestureDetector fires the full gesture set", () => {
    expect(WIDGET_REGISTRY.GestureDetector.triggers).toEqual([
      "onTap",
      "onLongPress",
      "onDoubleTap",
    ]);
  });

  it("scrollable widgets share the scroll trigger set", () => {
    const scrollTriggers = ["onScrollBegin", "onScrolling", "onScrollEnd"];
    expect(WIDGET_REGISTRY.ListView.triggers).toEqual(scrollTriggers);
    expect(WIDGET_REGISTRY.GridView.triggers).toEqual(scrollTriggers);
    expect(WIDGET_REGISTRY.SingleChildScrollView.triggers).toEqual(scrollTriggers);
    expect(WIDGET_REGISTRY.CustomScrollView.triggers).toEqual(scrollTriggers);
  });

  it("pure display widgets have no widget-specific triggers", () => {
    // Text / Divider / Spacer don't fire any gesture or input events on
    // their own — authors wrap them in GestureDetector for taps.
    expect(WIDGET_REGISTRY.Text.triggers).toEqual([]);
    expect(WIDGET_REGISTRY.Divider.triggers).toEqual([]);
    expect(WIDGET_REGISTRY.Spacer.triggers).toEqual([]);
  });

  it("every trigger referenced in the manifest is a known ActionTrigger", () => {
    // The compile-time type union ActionTrigger must list every trigger a
    // widget can fire. If a widget class declares a trigger that isn't in
    // the union, authors writing `actions: { onFoo: ... }` would have to
    // reach for a `(string & {})` escape hatch — which should never be
    // necessary for a built-in widget.
    const knownTriggers: readonly ActionTrigger[] = [
      "onTap",
      "onLongPress",
      "onDoubleTap",
      "onChange",
      "onScrollBegin",
      "onScrolling",
      "onScrollEnd",
      "onRefresh",
      "onAction",
      "onVisible",
      "onInit",
      "onAppBackground",
      "onAppForeground",
      "onBackground",
      "onForeground",
      "onSuccess",
      "onError",
      "onComplete",
    ];
    const known = new Set<string>(knownTriggers);

    for (const [name, entry] of Object.entries(WIDGET_REGISTRY)) {
      for (const t of entry.triggers) {
        expect({ widget: name, trigger: t, inUnion: known.has(t) }).toEqual({
          widget: name,
          trigger: t,
          inUnion: true,
        });
      }
    }
  });
});

describe("Trigger manifest — app-lifecycle aliases", () => {
  it("onAppBackground and onBackground both exist in the ActionTrigger union", () => {
    // TypeScript-level assertion: these assignments must compile.
    const a: ActionTrigger = "onAppBackground";
    const b: ActionTrigger = "onBackground";
    const c: ActionTrigger = "onAppForeground";
    const d: ActionTrigger = "onForeground";
    expect([a, b, c, d]).toEqual([
      "onAppBackground",
      "onBackground",
      "onAppForeground",
      "onForeground",
    ]);
  });
});
