import { describe, expect, it, afterAll, beforeAll } from "bun:test";
import { Engine, App, Flow, PageDefinition, ServerActionDefinition } from "../src/core";
import { V } from "../src/types";
import { Text, Row, Column } from "../src/components";

// ── Test Setup ────────────────────────────────────────────

const addToCartAction = ServerActionDefinition.create({
  id: "addToCart",
  schema: {
    productId: { type: "string", required: true },
    quantity: { type: "number", required: true },
  },
  execute: (ctx) => {
    const productId = ctx.actionParams.productId as string;
    const quantity = ctx.actionParams.quantity as number;
    return [
      { type: "setState", scope: "page" as const, key: "cartCount", value: quantity },
      { type: "showSnackbar", message: `Added ${quantity}x ${productId}!` },
    ];
  },
});

const failingAction = ServerActionDefinition.create({
  id: "failAction",
  execute: () => {
    throw new Error("Something went wrong");
  },
});

const asyncAction = ServerActionDefinition.create({
  id: "asyncAction",
  execute: async (ctx) => {
    await new Promise((r) => setTimeout(r, 10));
    return [{ type: "showToast", message: "Async done!" }];
  },
});

const noSchemaAction = ServerActionDefinition.create({
  id: "noSchema",
  execute: (ctx) => {
    return [{ type: "goBack" as const }];
  },
});

const addComponentAction = ServerActionDefinition.create({
  id: "addWidget",
  execute: () => {
    return [
      {
        type: "addComponent" as const,
        parentId: "cart-list",
        keyPrefix: "item-1",
        widget: Row.new({
          children: [
            Text.new({ data: "Item name" }),
            Text.new({ data: "$10.00" }),
          ],
        }),
      },
    ];
  },
});

const replaceComponentAction = ServerActionDefinition.create({
  id: "replaceWidget",
  execute: () => {
    return [
      {
        type: "replaceComponent" as const,
        targetId: "header",
        keyPrefix: "new-header",
        widget: Column.new({
          children: [
            Text.new({ data: "New Title" }),
            Text.new({ data: "Subtitle" }),
          ],
        }),
      },
    ];
  },
});

const dummyPage = PageDefinition.create({
  id: "home",
  title: "Home",
  render: () => Text.new({ data: "Hello" }),
});

const flow = Flow.create({
  name: "main",
  routes: [{ path: "home", page: dummyPage }],
});

const app = App.create({
  id: "test-app",
  name: "Test App",
  flows: [flow],
  actions: [addToCartAction, failingAction, asyncAction, noSchemaAction, addComponentAction, replaceComponentAction],
});

const engine = new Engine();
engine.registerApp(app);

let server: Awaited<ReturnType<Engine["start"]>>;
let baseUrl: string;

beforeAll(async () => {
  server = await engine.start({ port: 0, cache: false });
  baseUrl = `http://localhost:${server!.port}`;
});

afterAll(() => {
  engine.stop();
});

// ── Tests ─────────────────────────────────────────────────

describe("POST /api/v1/app/:appId/action", () => {
  it("executes a server action and returns response actions", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "addToCart",
        params: { productId: "prod-1", quantity: 2 },
      }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { actions: unknown[] };
    expect(body.actions).toHaveLength(2);
    expect(body.actions[0]).toEqual({
      type: "setState",
      scope: "page",
      key: "cartCount",
      value: 2,
    });
    expect(body.actions[1]).toEqual({
      type: "showSnackbar",
      message: "Added 2x prod-1!",
    });
  });

  it("validates required params (missing productId)", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "addToCart",
        params: { quantity: 1 },
      }),
    });

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("productId");
  });

  it("validates param types (wrong type for quantity)", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "addToCart",
        params: { productId: "prod-1", quantity: "not-a-number" },
      }),
    });

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("quantity");
    expect(body.error).toContain("number");
  });

  it("returns 404 for unknown action", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "nonExistent" }),
    });

    expect(res.status).toBe(404);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("nonExistent");
  });

  it("returns 404 for unknown app", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/no-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "addToCart" }),
    });

    expect(res.status).toBe(404);
  });

  it("returns 400 for missing action field", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ params: {} }),
    });

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("action");
  });

  it("returns 400 for invalid JSON body", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "text/plain" },
      body: "not json",
    });

    expect(res.status).toBe(400);
  });

  it("handles server action errors with 500 and error snackbar", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "failAction" }),
    });

    expect(res.status).toBe(500);
    const body = (await res.json()) as { error: string; actions: unknown[] };
    expect(body.error).toBe("Server action failed");
    expect(body.actions).toHaveLength(1);
    expect(body.actions[0]).toEqual({
      type: "showSnackbar",
      message: "Something went wrong",
    });
  });

  it("handles async server actions", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "asyncAction" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { actions: unknown[] };
    expect(body.actions).toEqual([{ type: "showToast", message: "Async done!" }]);
  });

  it("works without schema (no validation)", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "noSchema", params: { anything: "goes" } }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { actions: unknown[] };
    expect(body.actions).toEqual([{ type: "goBack" }]);
  });

  it("passes pageState and appState to action context", async () => {
    const contextAction = ServerActionDefinition.create({
      id: "echoContext",
      execute: (ctx) => {
        return [
          {
            type: "setState" as const,
            scope: "page" as const,
            key: "echoed",
            value: {
              pageState: ctx.pageState,
              appState: ctx.appState,
            },
          },
        ];
      },
    });

    // Register a new app with this action
    const contextApp = App.create({
      id: "context-app",
      name: "Context Test",
      flows: [flow],
      actions: [contextAction],
    });
    engine.registerApp(contextApp);

    const res = await fetch(`${baseUrl}/api/v1/app/context-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action: "echoContext",
        pageState: { count: 5 },
        appState: { userId: "user-123" },
      }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { actions: { value: unknown }[] };
    expect(body.actions[0]!.value).toEqual({
      pageState: { count: 5 },
      appState: { userId: "user-123" },
    });
  });

  it("auto-flattens addComponent widget into ComponentNode[]", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "addWidget" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { actions: Record<string, unknown>[] };
    const action = body.actions[0]!;
    expect(action.type).toBe("addComponent");
    expect(action.parentId).toBe("cart-list");
    // widget was flattened into components[]
    expect(action).not.toHaveProperty("widget");
    const components = action.components as { type: string; children: string[] }[];
    expect(Array.isArray(components)).toBe(true);
    // Root is a Row with 2 Text children
    expect(components[0]!.type).toBe("Row");
    expect(components[0]!.children).toHaveLength(2);
    // Total nodes: 1 Row + 2 Text = 3
    expect(components).toHaveLength(3);
    // All IDs are prefixed with "item-1_"
    for (const c of components) {
      expect((c as { id: string }).id).toStartWith("item-1_");
    }
    // Children refs are also prefixed
    expect(components[0]!.children[0]).toStartWith("item-1_");
  });

  it("auto-flattens replaceComponent widget into ComponentNode[]", async () => {
    const res = await fetch(`${baseUrl}/api/v1/app/test-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "replaceWidget" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { actions: Record<string, unknown>[] };
    const action = body.actions[0]!;
    expect(action.type).toBe("replaceComponent");
    expect(action.targetId).toBe("header");
    expect(action).not.toHaveProperty("widget");
    const components = action.components as { type: string; children: string[] }[];
    // Root is a Column with 2 Text children
    expect(components[0]!.type).toBe("Column");
    expect(components[0]!.children).toHaveLength(2);
    expect(components).toHaveLength(3);
  });

  it("applies keyPrefix to all node IDs", async () => {
    const keyedAction = ServerActionDefinition.create({
      id: "keyedWidget",
      execute: () => [
        {
          type: "addComponent" as const,
          parentId: "parent",
          keyPrefix: "item-42",
          widget: Row.new({
            children: [Text.new({ data: "child" })],
          }).withKey("my-row"),
        },
      ],
    });

    const keyedApp = App.create({
      id: "keyed-app",
      name: "Keyed Test",
      flows: [flow],
      actions: [keyedAction],
    });
    engine.registerApp(keyedApp);

    const res = await fetch(`${baseUrl}/api/v1/app/keyed-app/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "keyedWidget" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { actions: Record<string, unknown>[] };
    const components = body.actions[0]!.components as { id: string; type: string }[];
    // The Row has a stable key via .withKey() — preserved as-is
    const row = components.find((c) => c.type === "Row");
    expect(row!.id).toBe("my-row");
    // The Text child has an auto-generated ID — gets prefixed
    const text = components.find((c) => c.type === "Text");
    expect(text!.id).toStartWith("item-42_");
  });
});
