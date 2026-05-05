import { App, Flow, PageDefinition, ServerActionDefinition } from "../../engine/src/core";
import { V, Expr, ServerAction, SetState, ShowSnackbar, Lifecycle } from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Row,
  Text,
  ElevatedButton,
  TextButton,
  SizedBox,
  Padding,
  SingleChildScrollView,
  Divider,
  Card,
} from "../../engine/src/components";
import { EdgeInsets } from "../../engine/src/components";
import { sleep } from "bun";

// ── Server Actions ──────────────────────────────────────

const products: Record<string, { name: string; price: number; stock: number }> = {
  "prod-1": { name: "Orca Gateway Pro License", price: 49.99, stock: 100 },
  "prod-2": { name: "Wireless Headphones", price: 79.99, stock: 5 },
  "prod-3": { name: "USB-C Hub", price: 29.99, stock: 0 },
};

let cartItems: { productId: string; quantity: number }[] = [];

const addToCartAction = ServerActionDefinition.create({
  id: "addToCart",
  schema: {
    productId: { type: "string", required: true },
    quantity: { type: "number", required: true },
  },
  execute: async (ctx) => {
    const productId = ctx.actionParams.productId as string;
    const quantity = ctx.actionParams.quantity as number;

    const product = products[productId];
    if (!product) throw new Error(`Product "${productId}" not found`);
    if (product.stock < quantity) throw new Error(`Not enough stock. Only ${product.stock} available.`);

    product.stock -= quantity;

    const existing = cartItems.find((i) => i.productId === productId);
    if (existing) {
      existing.quantity += quantity;
    } else {
      cartItems.push({ productId, quantity });
    }

    const cartCount = cartItems.reduce((sum, i) => sum + i.quantity, 0);
    const lineTotal = (product.price * quantity).toFixed(2);
    await sleep(3000);
    return [
      { type: "setState", scope: "page" as const, key: "cartCount", value: cartCount },
      { type: "setState", scope: "page" as const, key: "stock", value: product.stock },
      {
        type: "addComponent" as const,
        parentId: "cart-list",
        keyPrefix: `cart-${productId}-${Date.now()}`,
        widget: Row.new({
          mainAxisAlignment: "spaceBetween",
          children: [
            Text.new({ data: `${quantity}x ${product.name}`, style: { fontSize: 14 } }),
            Text.new({ data: `$${lineTotal}`, style: { fontSize: 14, fontWeight: "bold" } }),
          ],
        }),
      },
      { type: "showSnackbar", message: `Added ${quantity}x ${product.name} to cart!` },
    ];
  },
});

const clearCartAction = ServerActionDefinition.create({
  id: "clearCart",
  execute: () => {
    for (const item of cartItems) {
      const product = products[item.productId];
      if (product) product.stock += item.quantity;
    }
    cartItems = [];
    return [
      { type: "setState", scope: "page" as const, key: "cartCount", value: 0 },
      { type: "showToast", message: "Cart cleared!" },
      {
        type: "replaceComponent", targetId: "cart-list", keyPrefix: "cart",
        widget: Column.new({ crossAxisAlignment: "start", children: [] }).withKey("cart-list")
      },
    ];
  },
});

const getCartAction = ServerActionDefinition.create({
  id: "getCart",
  execute: () => {
    const cartCount = cartItems.reduce((sum, i) => sum + i.quantity, 0);
    const cartTotal = cartItems.reduce((sum, i) => {
      const product = products[i.productId];
      return sum + (product ? product.price * i.quantity : 0);
    }, 0);
    return [
      { type: "setState", scope: "page" as const, key: "cartCount", value: cartCount },
      { type: "setState", scope: "page" as const, key: "cartTotal", value: cartTotal.toFixed(2) },
    ];
  },
});

// ── Page ────────────────────────────────────────────────

const shopPage = PageDefinition.create({
  id: "shop",
  title: "Shop",
  state: [
    { key: "cartCount", scope: "page", initial: 0 },
    { key: "stock", scope: "page", initial: 100 },
    { key: "adding", scope: "page", initial: false },
  ],
  getInfoData: async () => ({ product: products["prod-1"] }),
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Server Actions Shop" }),
        centerTitle: true,
      }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "start",
            children: [
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Row.new({
                    mainAxisAlignment: "spaceBetween",
                    children: [
                      Text.new({ data: "🛒 Cart", style: { fontSize: 20, fontWeight: "bold" } }),
                      Text.new({
                        data: V.transform(V.pageState("cartCount"), [{ type: "toString" }, { type: "template", template: "{{value}} items" }]),
                        style: { fontSize: 16, color: "#2E7D32" },
                      }),
                    ],
                  }),
                }),
              }),
              SizedBox.new({ height: 8 }),
              Column.new({ crossAxisAlignment: "start", children: [] }).withKey("cart-list"),
              SizedBox.new({ height: 24 }),
              Text.new({ data: "Featured Product", style: { fontSize: 18, fontWeight: "w600", color: "#333333" } }),
              SizedBox.new({ height: 8 }),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    crossAxisAlignment: "start",
                    children: [
                      Text.new({ data: V.info("product.name"), style: { fontSize: 22, fontWeight: "bold" } }),
                      SizedBox.new({ height: 8 }),
                      Text.new({
                        data: V.transform(V.info("product.price"), [{ type: "formatCurrency", currency: "USD" }]),
                        style: { fontSize: 18, color: "#2E7D32", fontWeight: "w600" },
                      }),
                      SizedBox.new({ height: 8 }),
                      Text.new({
                        data: V.transform(V.pageState("stock"), [{ type: "toString" }, { type: "template", template: "Stock: {{value}}" }]),
                        style: { fontSize: 14, color: "#666666" },
                      }),
                      SizedBox.new({ height: 16 }),
                      Divider.new({}),
                      SizedBox.new({ height: 16 }),
                      ElevatedButton.new({
                        enabled: V.transform(V.pageState("adding"), [{ type: "not" }]),
                        child: Text.new({
                          data: V.when([
                            { when: Expr.eq(V.pageState("adding"), V.static(true)), then: V.static("Adding...") },
                          ], V.static("Add to Cart")),
                        }),
                        actions: {
                          onTap: Lifecycle(
                            ServerAction("addToCart", { productId: V.static("prod-1"), quantity: V.static(1) }),
                            {
                              onLoading: SetState("adding", V.static(true)),
                              onError: ShowSnackbar("Failed to add to cart. Try again."),
                              onComplete: SetState("adding", V.static(false)),
                            },
                          ),
                        },
                      }),
                      SizedBox.new({ height: 8 }),
                      TextButton.new({
                        child: Text.new({ data: "Add 3 to Cart" }),
                        actions: { onTap: ServerAction("addToCart", { productId: V.static("prod-1"), quantity: V.static(3) }) },
                      }),
                    ],
                  }),
                }),
              }),
              SizedBox.new({ height: 24 }),
              Text.new({ data: "Cart Actions", style: { fontSize: 18, fontWeight: "w600", color: "#333333" } }),
              SizedBox.new({ height: 8 }),
              Row.new({
                children: [
                  ElevatedButton.new({ child: Text.new({ data: "Refresh Cart" }), actions: { onTap: ServerAction("getCart") } }),
                  SizedBox.new({ width: 12 }),
                  TextButton.new({ child: Text.new({ data: "Clear Cart" }), actions: { onTap: ServerAction("clearCart") } }),
                ],
              }),
              SizedBox.new({ height: 32 }),
            ],
          }),
        }),
      }),
    }),
});

// ── App ──────────────────────────────────────────────────

const mainFlow = Flow.create({
  name: "main",
  routes: [{ path: "shop", page: shopPage }],
});

export const serverActionsApp = App.create({
  id: "server-actions",
  name: "Server Actions Demo",
  flows: [mainFlow],
  actions: [addToCartAction, clearCartAction, getCartAction],
});
