// The /push page of the custom example app (examples/server/custom.ts), case
// C17.4/page of native-parity-s17-push. Five buttons built from the builders
// `orca plugin generate` writes for plugins/orca_push_notification/
// orca_plugin.yaml (examples/server/orca_push_notification.ts): Request
// permission and Get token write the status and the token into app state,
// Show notification carries a payload that is a deep link to /map (both native
// routers drop the scheme and the host), Subscribe and Unsubscribe use the topic
// "news"; two Texts show the two app-state keys. Home's "Go to Push Page" opens it.

import { describe, expect, test, beforeAll, afterAll } from "bun:test";
import { Engine } from "../src/core";
import type { ComponentNode } from "../src/types/node";

type Page = {
  title: string;
  components: ComponentNode[];
  state: { key: string; scope: string; initial: unknown }[];
};

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

const byId = (p: Page) => new Map(p.components.map((n) => [n.id, n]));
const tap = (p: Page, id: string) => byId(p).get(id)!.actions!.onTap as Record<string, unknown>;

// The text of a button whose child is a Text, or a Row holding one.
const label = (p: Page, button: ComponentNode): string => {
  const nodes = byId(p);
  const child = nodes.get(button.children[0]!)!;
  const text = child.type === "Text" ? child : child.children.map((id) => nodes.get(id)!).find((n) => n.type === "Text")!;
  return text.props.data as string;
};

// Each button's node id, its label, and the action its tap sends.
const BUTTONS: [string, string, Record<string, unknown>][] = [
  [
    "request-permission",
    "Request permission",
    { type: "requestNotificationPermission", statusKey: "pushStatus", tokenKey: "pushToken", scope: "app" },
  ],
  ["get-token", "Get token", { type: "getNotificationToken", tokenKey: "pushToken", scope: "app" }],
  [
    "show-notification",
    "Show notification",
    { type: "showLocalNotification", title: "Orca push", body: "Tap to open the map", payload: "orcacounter://open/map" },
  ],
  ["subscribe", "Subscribe to news", { type: "subscribeToTopic", topic: "news" }],
  ["unsubscribe", "Unsubscribe from news", { type: "unsubscribeFromTopic", topic: "news" }],
];

describe("push demo", () => {
  test("C17.4/page /push is titled Push Notifications and declares the status and the token in app state", async () => {
    const push = await page("push");
    expect(push.title).toBe("Push Notifications");
    expect(push.state).toEqual([
      { key: "pushStatus", scope: "app", initial: "" },
      { key: "pushToken", scope: "app", initial: "" },
    ]);
  });

  test("C17.4/page the five buttons send the plugin's actions with their params, exactly", async () => {
    const push = await page("push");
    const buttons = push.components.filter((n) => n.actions?.onTap !== undefined);
    expect(buttons.map((n) => n.id).sort()).toEqual(BUTTONS.map(([id]) => id).sort());
    for (const [id, text, action] of BUTTONS) {
      const button = byId(push).get(id)!;
      expect(button.type).toBe("ElevatedButton");
      expect(label(push, button)).toBe(text);
      expect(tap(push, id)).toEqual(action);
    }
  });

  test("C17.4/page the Texts show the permission and the token from app state", async () => {
    const push = await page("push");
    const nodes = byId(push);
    const texts: [string, string, string][] = [
      ["push-status", "pushStatus", "Permission: {{value}}"],
      ["push-token", "pushToken", "Token: {{value}}"],
    ];
    expect(push.components.filter((n) => n.watches.length > 0).map((n) => n.id).sort()).toEqual(
      texts.map(([id]) => id).sort(),
    );
    for (const [id, key, template] of texts) {
      expect(nodes.get(id)!.type).toBe("Text");
      expect(nodes.get(id)!.watches).toEqual([key]);
      expect(nodes.get(id)!.props.data).toEqual({
        type: "transform",
        input: { type: "state", key, scope: "app" },
        by: [{ type: "template", template }],
      });
    }
  });

  test("C17.4/page /home's Go to Push Page, right after Go to Video Page, navigates to /push", async () => {
    const home = await page("home");
    const navigate = (n: ComponentNode) => n.actions?.onTap as Record<string, unknown> | undefined;
    const toPush = home.components.filter((n) => navigate(n)?.type === "navigate" && navigate(n)!.path === "/push");
    expect(toPush.length).toBe(1);
    expect(toPush[0]!.type).toBe("TextButton");
    expect(navigate(toPush[0]!)).toEqual({ type: "navigate", path: "/push" });
    expect(label(home, toPush[0]!)).toBe("Go to Push Page");
    const toVideo = home.components.find((n) => navigate(n)?.type === "navigate" && navigate(n)!.path === "/video")!;
    const column = home.components.find((n) => n.children.includes(toVideo.id))!;
    expect(column.children.indexOf(toPush[0]!.id)).toBe(column.children.indexOf(toVideo.id) + 1);
  });
});
