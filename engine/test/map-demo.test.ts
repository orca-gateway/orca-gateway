// The /map page of the custom example app (examples/server/custom.ts), case
// C17.1/page of native-parity-s17-map. A GoogleMap keyed "main-map" with two
// markers, built from the classes `orca plugin generate` writes for
// plugins/orca_google_map/orca_plugin.yaml (examples/server/orca_google_map.ts),
// whose four triggers keep their event's fields in page state, a Text on each
// of those keys, and a button whose moveCamera addresses the map by its node id.
// A marker tap also adds 1 to markerTapCount, so a second tap on the same pin,
// which sets the same markerTapId, still shows on the page.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";

type Page = { components: ComponentNode[]; state: { key: string; scope: string; initial: unknown }[] };

let engine: Engine;
let base: string;

beforeAll(async () => {
  const { customApp } = await import("../../examples/server/custom");
  engine = new Engine();
  engine.registerApp(customApp);
  const server = await engine.start({ port: 0 });
  base = `http://localhost:${server.port}`;
});

afterAll(() => {
  engine?.stop();
});

async function page(location: string): Promise<Page> {
  const res = await fetch(`${base}/api/v1/app/custom/page/${location}`);
  expect(res.status).toBe(200);
  return (await res.json()) as Page;
}

const theMap = (p: Page) => {
  const maps = p.components.filter((n) => n.type === "GoogleMap");
  expect(maps.length).toBe(1);
  return maps[0]!;
};

const setState = (key: string, field: string) => ({
  type: "setState",
  scope: "page",
  key,
  value: { type: "event", key: field },
});

// Each page-state key, the template of the Text that shows it.
const TEXTS: [string, string][] = [
  ["latTap", "Map tapped on lat {{value}}"],
  ["lngTap", "Map tapped on lng {{value}}"],
  ["latLongPress", "Long press at lat {{value}}"],
  ["lngLongPress", "Long press at lng {{value}}"],
  ["latMoveCamera", "Camera moved to lat {{value}}"],
  ["lngMoveCamera", "Camera moved to lng {{value}}"],
  ["zoomMoveCamera", "Camera moved to zoom {{value}}"],
  ["markerTapId", "Marker tapped: {{value}}"],
  ["markerTapCount", "Marker taps: {{value}}"],
];

describe("map demo", () => {
  test("C17.1/page /map declares the page state of the tap, the long press, the camera and the marker tap", async () => {
    const map = await page("map");
    expect(map.state).toEqual([
      { key: "latTap", scope: "page", initial: 0 },
      { key: "lngTap", scope: "page", initial: 0 },
      { key: "latMoveCamera", scope: "page", initial: 0 },
      { key: "lngMoveCamera", scope: "page", initial: 0 },
      { key: "zoomMoveCamera", scope: "page", initial: 0 },
      { key: "latLongPress", scope: "page", initial: 0 },
      { key: "lngLongPress", scope: "page", initial: 0 },
      { key: "markerTapId", scope: "page", initial: "" },
      { key: "markerTapCount", scope: "page", initial: 0 },
    ]);
  });

  test("C17.1/page /map has one GoogleMap keyed main-map with its camera, its settings and two markers", async () => {
    const map = theMap(await page("map"));
    expect(map).toMatchObject({ id: "main-map", kind: "primitive", childMode: "none" });
    // The encoder writes a static prop value as the bare value.
    expect(map.props).toEqual({
      latitude: 37.7749,
      longitude: -122.4194,
      zoom: 12,
      mapType: "normal",
      myLocationEnabled: true,
      zoomControlsEnabled: true,
      markers: [
        { id: "marker1", latitude: 37.7749, longitude: -122.4194, title: "San Francisco", snippet: "This is SF!" },
        { id: "marker2", latitude: 37.8044, longitude: -122.2711, title: "Oakland", snippet: "This is Oakland!" },
      ],
    });
  });

  test("C17.1/page the map's four triggers keep their event's fields in page state, a marker tap also counts", async () => {
    const actions = theMap(await page("map")).actions!;
    expect(Object.keys(actions).sort()).toEqual(["onCameraMove", "onLongPress", "onMarkerTap", "onTap"]);
    expect(actions.onTap).toEqual({
      type: "actionGroup",
      mode: "parallel",
      actions: [setState("latTap", "latitude"), setState("lngTap", "longitude")],
    });
    expect(actions.onLongPress).toEqual({
      type: "actionGroup",
      mode: "parallel",
      actions: [setState("latLongPress", "latitude"), setState("lngLongPress", "longitude")],
    });
    expect(actions.onCameraMove).toEqual({
      type: "actionGroup",
      mode: "parallel",
      actions: [
        setState("latMoveCamera", "latitude"),
        setState("lngMoveCamera", "longitude"),
        setState("zoomMoveCamera", "zoom"),
      ],
    });
    expect(actions.onMarkerTap).toEqual({
      type: "actionGroup",
      mode: "parallel",
      actions: [
        setState("markerTapId", "markerId"),
        {
          type: "setState",
          scope: "page",
          key: "markerTapCount",
          value: {
            type: "transform",
            input: { type: "state", key: "markerTapCount", scope: "page" },
            by: [{ type: "add", by: { type: "static", value: 1 } }],
          },
        },
      ],
    });
  });

  test("C17.1/page the Move Camera to NYC button moves the map by its node id", async () => {
    const map = await page("map");
    const nodes = new Map(map.components.map((n) => [n.id, n]));
    const buttons = map.components.filter(
      (n) => (n.actions?.onTap as Record<string, unknown> | undefined)?.type === "moveCamera",
    );
    expect(buttons.length).toBe(1);
    expect(buttons[0]!.type).toBe("ElevatedButton");
    expect(nodes.get(buttons[0]!.children[0]!)!.props.data).toBe("Move Camera to NYC");
    expect(buttons[0]!.actions!.onTap).toEqual({
      type: "moveCamera",
      targetId: theMap(map).id,
      latitude: 40.7128,
      longitude: -74.006,
      zoom: 14,
    });
  });

  test("C17.1/page a Text shows each page-state key through its template", async () => {
    const map = await page("map");
    const texts = map.components.filter((n) => n.type === "Text" && n.watches.length > 0);
    // The flat node list is not in screen order.
    expect(texts.map((n) => n.watches).sort()).toEqual(TEXTS.map(([key]) => [key]).sort());
    for (const [key, template] of TEXTS) {
      const text = texts.find((n) => n.watches[0] === key)!;
      expect(text.props.data).toEqual({
        type: "transform",
        input: { type: "state", key, scope: "page" },
        by: [{ type: "template", template }],
      });
    }
  });
});
