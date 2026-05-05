import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  V,
  Expr,
  SetState,
  Navigate,
  GoBack,
  ShowSnackbar,
  ShowToast,
  CopyToClipboard,
  OpenUrl,
  Share,
  Sequential,
  Parallel,
  When,
} from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Row,
  Text,
  ElevatedButton,
  TextButton,
  OutlinedButton,
  Center,
  SizedBox,
  Padding,
  SingleChildScrollView,
  Divider,
  Card,
} from "../../engine/src/components";
import { EdgeInsets } from "../../engine/src/components";

// ── Helpers ───────────────────────────────────────────────

function _sectionTitle(title: string) {
  return Padding.new({
    padding: EdgeInsets.only({ bottom: 8 }),
    child: Text.new({
      data: title,
      style: { fontSize: 18, fontWeight: "w600", color: "#333333" },
    }),
  });
}

// ── Home Page ─────────────────────────────────────────────

const homePage = PageDefinition.create({
  id: "home",
  title: "Basic Actions",
  state: [
    { key: "count", scope: "page", initial: 0 },
    { key: "message", scope: "page", initial: "Hello, Orca Gateway!" },
  ],
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Basic Actions Demo" }),
        centerTitle: true,
      }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "start",
            children: [
              // ── Counter Section ──
              _sectionTitle("setState"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    children: [
                      Text.new({
                        data: V.transform(V.pageState("count"), [
                          { type: "toString" },
                        ]),
                        style: { fontSize: 48, fontWeight: "bold" },
                      }),
                      SizedBox.new({ height: 12 }),
                      Row.new({
                        mainAxisAlignment: "center",
                        children: [
                          ElevatedButton.new({
                            child: Text.new({ data: "-" }),
                            actions: {
                              onTap: SetState(
                                "count",
                                V.transform(V.pageState("count"), [
                                  { type: "subtract", by: V.static(1) },
                                ]),
                              ),
                            },
                          }),
                          SizedBox.new({ width: 12 }),
                          ElevatedButton.new({
                            child: Text.new({ data: "+" }),
                            actions: {
                              onTap: SetState(
                                "count",
                                V.transform(V.pageState("count"), [
                                  { type: "add", by: V.static(1) },
                                ]),
                              ),
                            },
                          }),
                          SizedBox.new({ width: 12 }),
                          OutlinedButton.new({
                            child: Text.new({ data: "Reset" }),
                            actions: {
                              onTap: Sequential(
                                SetState("count", V.static(0)),
                                ShowSnackbar("Counter reset to 0"),
                              ),
                            },
                          }),
                        ],
                      }),
                    ],
                  }),
                }),
              }),

              SizedBox.new({ height: 24 }),

              // ── Navigate Section ──
              _sectionTitle("navigate / goBack"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    crossAxisAlignment: "start",
                    children: [
                      Text.new({
                        data: "Push a new page onto the navigation stack.",
                        style: { fontSize: 14, color: "#666666" },
                      }),
                      SizedBox.new({ height: 12 }),
                      Column.new({
                        mainAxisSize: 'min',
                        crossAxisAlignment: "start",
                        children: [
                          ElevatedButton.new({
                            child: Text.new({ data: "Go to About Page" }),
                            actions: { onTap: Navigate("about") },
                          }),
                          SizedBox.new({ width: 12 }),
                          ElevatedButton.new({
                            child: Text.new({ data: "Go to Product Page" }),
                            actions: { onTap: Navigate("product") },
                          }),
                          SizedBox.new({ width: 12 }),
                          ElevatedButton.new({
                            child: Text.new({ data: "Go to E-commerce Page" }),
                            actions: { onTap: Navigate("ecommerce") },
                          }),
                          SizedBox.new({ width: 12 }),
                          ElevatedButton.new({
                            child: Text.new({ data: "Go to Checkout" }),
                            actions: { onTap: Navigate("checkout") },
                          }),
                        ],
                      }),
                    ],
                  }),
                }),
              }),

              SizedBox.new({ height: 24 }),

              // ── Snackbar & Toast Section ──
              _sectionTitle("showSnackbar / showToast"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    crossAxisAlignment: "start",
                    children: [
                      ElevatedButton.new({
                        child: Text.new({ data: "Show Snackbar" }),
                        actions: {
                          onTap: ShowSnackbar("This is a snackbar message!", 3000),
                        },
                      }),
                      SizedBox.new({ height: 8 }),
                      ElevatedButton.new({
                        child: Text.new({ data: "Show Toast" }),
                        actions: { onTap: ShowToast("This is a toast!") },
                      }),
                    ],
                  }),
                }),
              }),

              SizedBox.new({ height: 24 }),

              // ── Clipboard Section ──
              _sectionTitle("copyToClipboard"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    crossAxisAlignment: "start",
                    children: [
                      Text.new({
                        data: V.pageState("message"),
                        style: { fontSize: 16 },
                      }),
                      SizedBox.new({ height: 12 }),
                      ElevatedButton.new({
                        child: Text.new({ data: "Copy Message" }),
                        actions: {
                          onTap: Sequential(
                            CopyToClipboard(V.pageState("message")),
                            ShowToast("Copied to clipboard!"),
                          ),
                        },
                      }),
                    ],
                  }),
                }),
              }),

              SizedBox.new({ height: 24 }),

              // ── OpenUrl Section ──
              _sectionTitle("openUrl"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: ElevatedButton.new({
                    child: Text.new({ data: "Open Flutter Docs" }),
                    actions: {
                      onTap: OpenUrl("https://flutter.dev"),
                    },
                  }),
                }),
              }),

              SizedBox.new({ height: 24 }),

              // ── Share Section ──
              _sectionTitle("share"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: ElevatedButton.new({
                    child: Text.new({ data: "Share Count" }),
                    actions: {
                      onTap: Share(
                        "Orca Gateway Counter",
                        V.transform(V.pageState("count"), [
                          { type: "template", template: "My counter is at {{value}}!" },
                        ]),
                      ),
                    },
                  }),
                }),
              }),

              SizedBox.new({ height: 24 }),

              // ── Combined Actions Section ──
              _sectionTitle("Sequential Actions"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    crossAxisAlignment: "start",
                    children: [
                      Text.new({
                        data: "Multiple actions fired from one tap.",
                        style: { fontSize: 14, color: "#666666" },
                      }),
                      SizedBox.new({ height: 12 }),
                      ElevatedButton.new({
                        child: Text.new({ data: "Increment + Snackbar" }),
                        actions: {
                          onTap: Sequential(
                            SetState(
                              "count",
                              V.transform(V.pageState("count"), [
                                { type: "add", by: V.static(1) },
                              ]),
                            ),
                            ShowSnackbar("Count incremented!"),
                          ),
                        },
                      }),
                    ],
                  }),
                }),
              }),

              SizedBox.new({ height: 32 }),
            ],
          }),
        }),
      }),
    }),
});

// ── Product Page ─────────────────────────────────────────

const productPage = PageDefinition.create({
  id: "product",
  title: "Product",
  state: [{ key: "quantity", scope: "page", initial: 1 }],
  getInfoData: async () => ({
    product: {
      name: "Orca Gateway Pro License",
      price: 49.99,
      description: "Server-Driven UI engine — control your entire mobile app from the server.",
      features: ["No app store updates", "Instant UI changes", "Full state management"],
    },
  }),
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Product Details" }) }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "start",
            children: [
              Text.new({
                data: V.info("product.name"),
                style: { fontSize: 24, fontWeight: "bold" },
              }),
              SizedBox.new({ height: 8 }),
              Text.new({
                data: V.info("product.description"),
                style: { fontSize: 14, color: "#666666" },
              }),
              SizedBox.new({ height: 4 }),
              Text.new({
                data: V.transform(V.request("platform"), [
                  { type: "template", template: "Platform: {{value}}" },
                ]),
                style: { fontSize: 12, color: "#999999" },
              }),
              SizedBox.new({ height: 16 }),
              Divider.new({}),
              SizedBox.new({ height: 16 }),
              _sectionTitle("Pricing"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    children: [
                      Row.new({
                        mainAxisAlignment: "spaceBetween",
                        children: [
                          Text.new({ data: "Unit Price", style: { fontSize: 16 } }),
                          Text.new({
                            data: V.transform(V.info("product.price"), [
                              { type: "formatCurrency", currency: "USD" },
                            ]),
                            style: { fontSize: 16, fontWeight: "bold" },
                          }),
                        ],
                      }),
                      SizedBox.new({ height: 12 }),
                      Row.new({
                        mainAxisAlignment: "spaceBetween",
                        children: [
                          Text.new({ data: "Quantity", style: { fontSize: 16 } }),
                          Row.new({
                            children: [
                              OutlinedButton.new({
                                child: Text.new({ data: "-" }),
                                actions: {
                                  onTap: SetState("quantity", V.transform(V.pageState("quantity"), [{ type: "subtract", by: V.static(1) }])),
                                },
                              }),
                              SizedBox.new({ width: 16 }),
                              Text.new({
                                data: V.transform(V.pageState("quantity"), [{ type: "toString" }]),
                                style: { fontSize: 20, fontWeight: "bold" },
                              }),
                              SizedBox.new({ width: 16 }),
                              OutlinedButton.new({
                                child: Text.new({ data: "+" }),
                                actions: {
                                  onTap: SetState("quantity", V.transform(V.pageState("quantity"), [{ type: "add", by: V.static(1) }])),
                                },
                              }),
                            ],
                          }),
                        ],
                      }),
                      SizedBox.new({ height: 12 }),
                      Divider.new({}),
                      SizedBox.new({ height: 12 }),
                      Row.new({
                        mainAxisAlignment: "spaceBetween",
                        children: [
                          Text.new({ data: "Total", style: { fontSize: 20, fontWeight: "bold" } }),
                          Text.new({
                            data: V.transform(V.info("product.price"), [
                              { type: "multiply", by: V.pageState("quantity") },
                              { type: "formatCurrency", currency: "USD" },
                            ]),
                            style: { fontSize: 20, fontWeight: "bold", color: "#2E7D32" },
                          }),
                        ],
                      }),
                    ],
                  }),
                }),
              }),
              SizedBox.new({ height: 16 }),
              Text.new({
                data: V.transform(V.info("product.features"), [
                  { type: "length" },
                  { type: "template", template: "{{value}} key features:" },
                ]),
                style: { fontSize: 16, fontWeight: "w600" },
              }),
              SizedBox.new({ height: 8 }),
              Text.new({
                data: V.transform(V.info("product.features"), [
                  { type: "map", transform: { type: "template", template: "• {{value}}" } },
                  { type: "join", separator: "\n" },
                ]),
                style: { fontSize: 14 },
              }),
              SizedBox.new({ height: 24 }),
              ElevatedButton.new({
                child: Text.new({
                  data: V.transform(V.info("product.price"), [
                    { type: "multiply", by: V.pageState("quantity") },
                    { type: "toFixed", decimals: 2 },
                    { type: "template", template: "Buy Now — ${{value}}" },
                  ]),
                }),
                actions: {
                  onTap: Sequential(
                    ShowSnackbar(V.transform(V.info("product.price"), [
                      { type: "multiply", by: V.pageState("quantity") },
                      { type: "toFixed", decimals: 2 },
                      { type: "template", template: "Purchased: {{value}}" },
                    ])),
                    SetState("quantity", V.static(1)),
                  ),
                },
              }),
              SizedBox.new({ height: 16 }),
              TextButton.new({
                child: Text.new({ data: "← Back to Home" }),
                actions: { onTap: GoBack() },
              }),
              SizedBox.new({ height: 32 }),
            ],
          }),
        }),
      }),
    }),
});

// ── E-commerce Page ──────────────────────────────────────

const ecommercePage = PageDefinition.create({
  id: "ecommerce",
  title: "E-commerce",
  state: [
    { key: "quantity", scope: "page", initial: 1 },
    { key: "stock", scope: "page", initial: 10 },
    { key: "selectedColor", scope: "page", initial: "Black" },
  ],
  getInfoData: async () => ({
    product: {
      name: "Orca Gateway Wireless Headphones",
      price: 79.99,
      description: "Premium wireless headphones with noise cancellation.",
      colors: ["Black", "White", "Navy"],
      freeShippingThreshold: 100,
    },
  }),
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "E-commerce Demo" }) }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "start",
            children: [
              Text.new({ data: V.info("product.name"), style: { fontSize: 24, fontWeight: "bold" } }),
              SizedBox.new({ height: 4 }),
              Text.new({ data: V.info("product.description"), style: { fontSize: 14, color: "#666666" } }),
              SizedBox.new({ height: 16 }),
              _sectionTitle("Stock Status"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    crossAxisAlignment: "start",
                    children: [
                      Text.new({
                        data: V.when([
                          { when: Expr.eq(V.pageState("stock"), V.static(0)), then: V.static("❌ Out of Stock") },
                          { when: Expr.lte(V.pageState("stock"), V.static(3)), then: V.transform(V.pageState("stock"), [{ type: "template", template: "⚠️ Low Stock — only {{value}} left!" }]) },
                        ], V.transform(V.pageState("stock"), [{ type: "template", template: "✅ In Stock ({{value}} available)" }])),
                        style: { fontSize: 16, fontWeight: "w600" },
                      }),
                      SizedBox.new({ height: 12 }),
                      Row.new({
                        children: [
                          OutlinedButton.new({
                            child: Text.new({ data: "Sell 1" }),
                            actions: { onTap: SetState("stock", V.transform(V.pageState("stock"), [{ type: "subtract", by: V.static(1) }])) },
                          }),
                          SizedBox.new({ width: 8 }),
                          OutlinedButton.new({
                            child: Text.new({ data: "Restock +5" }),
                            actions: { onTap: SetState("stock", V.transform(V.pageState("stock"), [{ type: "add", by: V.static(5) }])) },
                          }),
                        ],
                      }),
                    ],
                  }),
                }),
              }),
              SizedBox.new({ height: 16 }),
              _sectionTitle("Pricing"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    children: [
                      Row.new({
                        mainAxisAlignment: "spaceBetween",
                        children: [
                          Text.new({ data: "Unit Price", style: { fontSize: 16 } }),
                          Text.new({ data: V.transform(V.info("product.price"), [{ type: "formatCurrency", currency: "USD" }]), style: { fontSize: 16, fontWeight: "bold" } }),
                        ],
                      }),
                      SizedBox.new({ height: 12 }),
                      Row.new({
                        mainAxisAlignment: "spaceBetween",
                        children: [
                          Text.new({ data: "Quantity", style: { fontSize: 16 } }),
                          Row.new({
                            children: [
                              OutlinedButton.new({ child: Text.new({ data: "-" }), actions: { onTap: SetState("quantity", V.transform(V.pageState("quantity"), [{ type: "subtract", by: V.static(1) }])) } }),
                              SizedBox.new({ width: 16 }),
                              Text.new({ data: V.transform(V.pageState("quantity"), [{ type: "toString" }]), style: { fontSize: 20, fontWeight: "bold" } }),
                              SizedBox.new({ width: 16 }),
                              OutlinedButton.new({ child: Text.new({ data: "+" }), actions: { onTap: SetState("quantity", V.transform(V.pageState("quantity"), [{ type: "add", by: V.static(1) }])) } }),
                            ],
                          }),
                        ],
                      }),
                      SizedBox.new({ height: 12 }),
                      Divider.new({}),
                      SizedBox.new({ height: 12 }),
                      Row.new({
                        mainAxisAlignment: "spaceBetween",
                        children: [
                          Text.new({ data: "Total", style: { fontSize: 20, fontWeight: "bold" } }),
                          Text.new({ data: V.transform(V.info("product.price"), [{ type: "multiply", by: V.pageState("quantity") }, { type: "formatCurrency", currency: "USD" }]), style: { fontSize: 20, fontWeight: "bold", color: "#2E7D32" } }),
                        ],
                      }),
                      SizedBox.new({ height: 12 }),
                      Text.new({
                        data: V.when([{
                          when: Expr.gte(V.transform(V.info("product.price"), [{ type: "multiply", by: V.pageState("quantity") }]), V.info("product.freeShippingThreshold")),
                          then: V.static("✓ Free shipping!"),
                        }], V.transform(V.info("product.freeShippingThreshold"), [
                          { type: "subtract", by: V.transform(V.info("product.price"), [{ type: "multiply", by: V.pageState("quantity") }]) },
                          { type: "toFixed", decimals: 2 },
                          { type: "template", template: "Add ${{value}} more for free shipping" },
                        ])),
                        style: { fontSize: 13, color: "#666666" },
                      }),
                    ],
                  }),
                }),
              }),
              SizedBox.new({ height: 16 }),
              ElevatedButton.new({
                child: Text.new({
                  data: V.when([{ when: Expr.eq(V.pageState("stock"), V.static(0)), then: V.static("Sold Out") }],
                    V.transform(V.info("product.price"), [{ type: "multiply", by: V.pageState("quantity") }, { type: "toFixed", decimals: 2 }, { type: "template", template: "Buy Now — ${{value}}" }])),
                }),
                actions: {
                  onTap: Sequential(
                    SetState("stock", V.transform(V.pageState("stock"), [{ type: "subtract", by: V.pageState("quantity") }])),
                    ShowSnackbar("Purchase complete!"),
                    SetState("quantity", V.static(1)),
                  ),
                },
              }),
              SizedBox.new({ height: 16 }),
              TextButton.new({ child: Text.new({ data: "← Back to Home" }), actions: { onTap: GoBack() } }),
              SizedBox.new({ height: 32 }),
            ],
          }),
        }),
      }),
    }),
});

// ── Checkout Page ────────────────────────────────────────

const checkoutPage = PageDefinition.create({
  id: "checkout",
  title: "Checkout",
  state: [
    { key: "loading", scope: "page", initial: false },
    { key: "agreed", scope: "page", initial: false },
    { key: "status", scope: "page", initial: "pending" },
    { key: "quantity", scope: "page", initial: 2 },
  ],
  getInfoData: async () => ({
    product: { name: "Orca Gateway Pro", price: 79.99 },
  }),
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Checkout" }) }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "start",
            children: [
              _sectionTitle("Order Summary"),
              Card.new({
                child: Padding.new({
                  padding: EdgeInsets.all(16),
                  child: Column.new({
                    children: [
                      Row.new({
                        mainAxisAlignment: "spaceBetween",
                        children: [
                          Text.new({ data: V.info("product.name"), style: { fontSize: 16 } }),
                          Text.new({ data: V.transform(V.info("product.price"), [{ type: "multiply", by: V.pageState("quantity") }, { type: "formatCurrency", currency: "USD" }]), style: { fontSize: 16, fontWeight: "bold" } }),
                        ],
                      }),
                      SizedBox.new({ height: 8 }),
                      Text.new({ data: V.transform(V.pageState("quantity"), [{ type: "template", template: "{{value}} items" }]), style: { fontSize: 14, color: "#666666" } }),
                    ],
                  }),
                }),
              }),
              SizedBox.new({ height: 16 }),
              _sectionTitle("Status"),
              Text.new({
                data: V.when([
                  { when: Expr.eq(V.pageState("loading"), V.static(true)), then: V.static("⏳ Processing...") },
                  { when: Expr.eq(V.pageState("status"), V.static("success")), then: V.static("✅ Payment successful!") },
                  { when: Expr.eq(V.pageState("status"), V.static("failed")), then: V.static("❌ Payment failed — please agree to terms.") },
                ], V.static("Ready to checkout")),
                style: { fontSize: 16 },
              }),
              SizedBox.new({ height: 16 }),
              Row.new({
                children: [
                  OutlinedButton.new({
                    child: Text.new({
                      data: V.when([{ when: Expr.eq(V.pageState("agreed"), V.static(true)), then: V.static("☑ I agree to terms") }], V.static("☐ I agree to terms")),
                    }),
                    actions: { onTap: SetState("agreed", V.transform(V.pageState("agreed"), [{ type: "not" }])) },
                  }),
                ],
              }),
              SizedBox.new({ height: 24 }),
              ElevatedButton.new({
                child: Text.new({
                  data: V.when([{ when: Expr.eq(V.pageState("loading"), V.static(true)), then: V.static("Processing...") }], V.static("Place Order")),
                }),
                actions: {
                  onTap: Sequential(
                    SetState("loading", V.static(true)),
                    SetState("status", V.static("pending")),
                    When([{
                      when: Expr.eq(V.pageState("agreed"), V.static(true)),
                      then: Sequential(SetState("status", V.static("success")), ShowSnackbar("Order placed successfully!")),
                    }], Sequential(SetState("status", V.static("failed")), ShowSnackbar("Please agree to terms first."))),
                    SetState("loading", V.static(false)),
                  ),
                },
              }),
              SizedBox.new({ height: 16 }),
              _sectionTitle("Parallel Actions"),
              Text.new({ data: "Tap to reset all fields at once (parallel).", style: { fontSize: 14, color: "#666666" } }),
              SizedBox.new({ height: 8 }),
              OutlinedButton.new({
                child: Text.new({ data: "Reset All (Parallel)" }),
                actions: {
                  onTap: Sequential(
                    Parallel(SetState("agreed", V.static(false)), SetState("status", V.static("pending")), SetState("quantity", V.static(2))),
                    ShowToast("All fields reset!"),
                  ),
                },
              }),
              SizedBox.new({ height: 16 }),
              TextButton.new({ child: Text.new({ data: "← Back" }), actions: { onTap: GoBack() } }),
              SizedBox.new({ height: 32 }),
            ],
          }),
        }),
      }),
    }),
});

// ── About Page ───────────────────────────────────────────

const aboutPage = PageDefinition.create({
  id: "about",
  title: "About",
  state: [],
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "About" }) }),
      body: Center.new({
        child: Column.new({
          mainAxisAlignment: "center",
          children: [
            Text.new({ data: "Orca Gateway Basic Actions", style: { fontSize: 24, fontWeight: "bold" } }),
            SizedBox.new({ height: 8 }),
            Text.new({ data: "Demonstrating Epics 8, 9, 10, 11, and 12.", style: { fontSize: 16, color: "#666666" } }),
            SizedBox.new({ height: 24 }),
            ElevatedButton.new({ child: Text.new({ data: "Go Back" }), actions: { onTap: GoBack() } }),
          ],
        }),
      }),
    }),
});

// ── App ──────────────────────────────────────────────────

const mainFlow = Flow.create({
  name: "main",
  routes: [
    { path: "home", page: homePage },
    { path: "about", page: aboutPage },
    { path: "product", page: productPage },
    { path: "ecommerce", page: ecommercePage },
    { path: "checkout", page: checkoutPage },
  ],
});

export const basicActionsApp = App.create({
  id: "basic-actions",
  name: "Basic Actions Demo",
  flows: [mainFlow],
});
