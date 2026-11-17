// The parity-a `overlays` demo page (examples/server/parity-a.ts), native-parity
// step 8: Dialog, BottomSheet, Tooltip and SnackBar are on the page with the
// openDialog, closeDialog, showSnackbar and showToast actions that drive them,
// and the Swift and Kotlin vectors get the page whole, so iOS and Android draw
// the real widgets rather than a fallback and keep both dialog kinds.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";
import { swiftCapabilityVector, kotlinCapabilityVector } from "../../schema/gen-native-capabilities";

const WIDGETS = ["BottomSheet", "Dialog", "SnackBar", "Tooltip"];
const KINDS = ["closeDialog", "openDialog", "showSnackbar", "showToast"];
const PAGE = "overlays";

let engine: Engine;
let base: string;

beforeAll(async () => {
  const { parityAApp } = await import("../../examples/server/parity-a");
  engine = new Engine();
  engine.registerApp(parityAApp);
  const server = await engine.start({ port: 0, cache: false });
  base = `http://localhost:${server.port}`;
});

afterAll(() => {
  engine?.stop();
});

function pageUrl(page: string): string {
  return `${base}/api/v1/app/parity-a/page/${page}`;
}

/** The page as a client with no capability vector gets it (unfiltered). */
async function plainPage(page: string): Promise<ComponentNode[]> {
  const res = await fetch(pageUrl(page));
  expect({ page, status: res.status }).toEqual({ page, status: 200 });
  return ((await res.json()) as { components: ComponentNode[] }).components;
}

/** The page as a native SDK gets it: its caps hash plus the full vector in the body. */
async function nativePage(page: string, make: typeof swiftCapabilityVector): Promise<ComponentNode[]> {
  const { vector, capsHash } = make();
  const res = await fetch(pageUrl(page), {
    method: "POST",
    headers: {
      "x-orca-sdk-version": vector.sdkSemver,
      "x-orca-caps-hash": capsHash,
      "content-type": "application/json",
    },
    body: JSON.stringify({ _orcaCapsVector: vector }),
  });
  expect({ page, status: res.status }).toEqual({ page, status: 200 });
  return ((await res.json()) as { components: ComponentNode[] }).components;
}

/** Every action on the page, nested ones (a Sequential's steps) included. */
function pageActions(components: ComponentNode[]): Record<string, unknown>[] {
  const out: Record<string, unknown>[] = [];
  const walk = (action: unknown): void => {
    if (!action || typeof action !== "object") return;
    const a = action as Record<string, unknown>;
    out.push(a);
    if (Array.isArray(a.actions)) for (const nested of a.actions) walk(nested);
    if (a.action) walk(a.action);
  };
  for (const node of components) for (const action of Object.values(node.actions ?? {})) walk(action);
  return out;
}

describe("parity-a overlays page (native-parity step 8)", () => {
  test("A8.x eng the overlays page holds the four widgets and the dialog, snackbar and toast kinds", async () => {
    const plain = await plainPage(PAGE);
    const types = new Set(plain.map((n) => n.type));
    expect(WIDGETS.filter((type) => !types.has(type))).toEqual([]);
    const actions = pageActions(plain);
    const kinds = new Set(actions.map((a) => a.type));
    expect(KINDS.filter((kind) => !kinds.has(kind))).toEqual([]);
    // Every openDialog names a Dialog node of the page (its key), at 0.5 (absent) and at 0.3.
    const dialogs = new Set(plain.filter((n) => n.type === "Dialog").map((n) => n.id));
    const opens = actions.filter((a) => a.type === "openDialog");
    expect(opens.filter((a) => !dialogs.has(a.dialogId as string))).toEqual([]);
    expect([...new Set(opens.map((a) => a.heightFactor ?? 0.5))].sort()).toEqual([0.3, 0.5]);
  });

  test("A8.x eng each native vector gets the overlays page whole, openDialog and closeDialog kept, no FallbackPrompt or caps banner", async () => {
    const plain = await plainPage(PAGE);
    for (const [name, make] of [
      ["swift", swiftCapabilityVector],
      ["kotlin", kotlinCapabilityVector],
    ] as const) {
      const served = await nativePage(PAGE, make);
      const kept = new Set(served.map((n) => n.type));
      const dropped = [...new Set(plain.map((n) => n.type))].filter((type) => !kept.has(type)).sort();
      expect({ page: PAGE, name, dropped }).toEqual({ page: PAGE, name, dropped: [] });
      const keptKinds = new Set(pageActions(served).map((a) => a.type));
      const lostKinds = KINDS.filter((kind) => !keptKinds.has(kind));
      expect({ page: PAGE, name, lostKinds }).toEqual({ page: PAGE, name, lostKinds: [] });
      expect({ page: PAGE, name, components: served }).toEqual({ page: PAGE, name, components: plain });
      // The warn banner is a FallbackPrompt too (capability-filter.ts), so this covers both.
      expect({ page: PAGE, name, fallback: served.some((n) => n.type === "FallbackPrompt") }).toEqual({
        page: PAGE,
        name,
        fallback: false,
      });
    }
  });
});
