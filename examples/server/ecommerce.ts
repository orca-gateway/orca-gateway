import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  V,
  Navigate,
  GoBack,
  SwitchTab,
  OpenDrawer,
  SetState,
  ShowSnackbar,
  Sequential,
  type PageContext,
  Expr,
} from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Row,
  Text,
  Icon,
  ElevatedButton,
  IconButton,
  TextButton,
  TextDecoration,
  Center,
  SizedBox,
  Container,
  ListView,
  GridView,
  Card,
  Padding,
  Image,
  TextField,
  Spacer,
  SingleChildScrollView,
  SafeArea,
  BottomNavigationBar,
  BottomNavItem,
  Drawer,
  Color,
  EdgeInsets,
  Expanded,
  AnimatedContainer,
  Positioned,
} from "../../engine/src/components";
import { Curves } from "../../engine/src/components/helpers/curves";

// ── Product Data ────────────────────────────────────────────

const products = [
  { id: "1", name: "Wireless Headphones", price: 79.99, image: "headphones" },
  { id: "2", name: "Smart Watch", price: 199.99, image: "watch" },
  { id: "3", name: "Laptop Stand", price: 49.99, image: "stand" },
  { id: "4", name: "USB-C Hub", price: 39.99, image: "hub" },
  { id: "5", name: "Mechanical Keyboard", price: 129.99, image: "keyboard" },
  { id: "6", name: "Webcam HD", price: 59.99, image: "webcam" },
];

// ── Home Page ──────────────────────────────────────────────

const homePage = PageDefinition.create({
  id: "home",
  title: "Home",
  render: (_ctx, _info) =>
    SafeArea.new({
      top: true,
      child: Column.new({
        children: [
          Padding.new({
            padding: { top: 16, left: 16, right: 16, bottom: 8 },
            child: Text.new({
              data: "Featured Products",
              style: { fontSize: 24, fontWeight: "bold" },
            }),
          }),
          ...products.map((p) =>
            Padding.new({
              padding: { top: 4, left: 16, right: 16, bottom: 4 },
              child: Card.new({
                child: Padding.new({
                  padding: { top: 16, left: 16, right: 16, bottom: 16 },
                  child: Row.new({
                    children: [
                      Column.new({
                        crossAxisAlignment: "start",
                        children: [
                          Text.new({
                            data: p.name,
                            style: { fontSize: 16, fontWeight: "w600" },
                          }),
                          SizedBox.new({ height: 4 }),
                          Text.new({
                            data: `$${p.price.toFixed(2)}`,
                            style: { fontSize: 14, color: "#4CAF50" },
                          }),
                        ],
                      }),
                      Spacer.new({}),
                      ElevatedButton.new({
                        child: Text.new({ data: "View" }),
                        actions: {
                          onTap: Navigate(`/home/product/${p.id}`),
                        },
                      }),
                    ],
                  }),
                }),
              }),
            }),
          ),
        ],
      }),
    }),
});

// ── Product Detail Page ────────────────────────────────────

const productDetailPage = PageDefinition.create({
  id: "product-detail",
  title: "Product Detail",
  appState: ["cartCount"],
  getInfoData: (ctx: PageContext) => {
    const id = ctx.routeParams.id;
    return products.find((p) => p.id === id) ?? null;
  },
  render: (ctx, infoData) => {
    const product = infoData as (typeof products)[0] | null;
    if (!product) {
      return Center.new({
        child: Text.new({ data: "Product not found" }),
      });
    }

    return SafeArea.new({

      child: Container.new({
        color: '#FFFFFF',
        child: SingleChildScrollView.new({
          child: Padding.new({
            padding: { top: 24, left: 24, right: 24, bottom: 24 },
            child: Column.new({
              crossAxisAlignment: "start",
              children: [
                Container.new({
                  height: 200,
                  decoration: {
                    color: "#E3EFFD",
                    borderRadius: 12,
                  },
                  child: Center.new({
                    child: Icon.new({ name: "shopping_bag", size: 64, color: "#1976D2" }),
                  }),
                }),
                SizedBox.new({ height: 16 }),
                Text.new({
                  data: product.name,
                  style: { fontSize: 24, fontWeight: "bold" },
                }),
                SizedBox.new({ height: 8 }),
                Text.new({
                  data: `$${product.price.toFixed(2)}`,
                  style: { fontSize: 20, color: "#4CAF50", fontWeight: "w600" },
                }),
                SizedBox.new({ height: 24 }),
                Text.new({
                  data: "Premium quality product with excellent build and design. Perfect for everyday use.",
                  style: { fontSize: 14, color: "#666666" },
                }),
                SizedBox.new({ height: 24 }),
                Row.new({
                  children: [
                    ElevatedButton.new({
                      child: Text.new({ data: "Add to Cart" }),
                      actions: {
                        onTap: Sequential(
                          SetState(
                            "cartCount",
                            V.transform(V.appState("cartCount"), [
                              { type: "add", by: V.static(1) },
                            ]),
                            "app",
                          ),
                          ShowSnackbar(`${product.name} added to cart!`),
                        ),
                      },
                    }),
                    SizedBox.new({ width: 12 }),
                    TextButton.new({
                      child: Text.new({ data: "Back" }),
                      actions: {
                        onTap: GoBack(),
                      },
                    }),
                  ],
                }),
              ],
            }),
          }),
        }),
      })
    });
  },
});

// ── Search Page ────────────────────────────────────────────

const searchPage = PageDefinition.create({
  id: "search",
  title: "Search",
  state: [{ key: "query", scope: "page", initial: "" }],
  render: (_ctx, _info) =>
    SafeArea.new({
      child: Padding.new({
        padding: { top: 16, left: 16, right: 16, bottom: 16 },

        child: Column.new({
          crossAxisAlignment: "start",
          children: [
            Container.new({
              decoration: {
                color: "#F5F5F5",
                borderRadius: 8,

              },
              padding: EdgeInsets.all(12),
              width: _ctx.requestInfo.screenSize.width - 32,
              child: Row.new({
                mainAxisAlignment: "center",
                crossAxisAlignment: "center",
                mainAxisSize: "max",
                children: [
                  Icon.new({ name: "search", size: 20, color: "#757575" }),
                  SizedBox.new({ width: 8 }),
                  Expanded.new({
                    child: TextField.new({

                      placeholder: "Search products...",
                      inputType: 'text',
                      value: V.pageState("query"),
                      actions: {
                        onChange: SetState("query", V.event("query")),
                      },
                    }),
                  }),

                ],
              }),
            }),

            SizedBox.new({ height: 16 }),
            Text.new({
              data: "Search results will appear here",
              style: { fontSize: 14, color: "#999999" },
            }),
          ],
        }),
      }),
    })
});

// ── Cart Page ──────────────────────────────────────────────

const cartPage = PageDefinition.create({
  id: "cart",
  title: "Cart",
  appState: ["cartCount"],
  render: (_ctx, _info) =>
    Center.new({
      child: Column.new({
        mainAxisAlignment: "center",
        children: [
          Icon.new({ name: "shopping_cart", size: 64, color: "#1976D2" }),
          SizedBox.new({ height: 16 }),
          Text.new({
            data: V.transform(
              V.appState("cartCount"),
              [{ type: "toString" }],
            ),
            style: { fontSize: 36, fontWeight: "bold" },
          }),
          SizedBox.new({ height: 8 }),
          Text.new({
            data: "items in cart",
            style: { fontSize: 16, color: "#666666" },
          }),
          SizedBox.new({ height: 24 }),
          ElevatedButton.new({
            child: Text.new({ data: "Clear Cart" }),
            actions: {
              onTap: Sequential(
                SetState("cartCount", V.static(0), "app"),
                ShowSnackbar("Cart cleared"),
              ),
            },
          }),
        ],
      }),
    }),
});

// ── Profile Page ───────────────────────────────────────────

const profilePage = PageDefinition.create({
  id: "profile",
  title: "Profile",
  state: [{ key: "isEditing", scope: "page", initial: false }],
  render: (_ctx, _info) =>
    Center.new({
      child: Column.new({
        mainAxisAlignment: "center",
        children: [
          Icon.new({ name: "person", size: 80, color: "#1976D2" }),
          SizedBox.new({ height: 16 }),
          Text.new({
            data: "John Doe",
            style: { fontSize: 24, fontWeight: "bold" },
          }),
          SizedBox.new({ height: 8 }),
          Text.new({
            data: "john.doe@example.com",
            style: { fontSize: 14, color: "#666666" },
          }),
          SizedBox.new({ height: 24 }),

          AnimatedContainer.new({
            duration: 300,
            curve: Curves.BounceInOut,
            color: V.when([
              { when: Expr.eq(V.pageState("isEditing"), true), then: V.static("#FF011A") },
            ], V.static("#3C00FF")),
            padding: V.when([
              { when: Expr.eq(V.pageState("isEditing"), true), then: V.static(EdgeInsets.symmetric({ vertical: 24, horizontal: 48 })) },
            ], V.static(EdgeInsets.symmetric({ vertical: 12, horizontal: 24 }))),

            child: ElevatedButton.new({
              child: Text.new({ data: "Edit Profile" }),
              actions: {
                onTap: ShowSnackbar("Edit profile tapped!"),
              },
            }),
          }),
          SizedBox.new({ height: 16 }),
          ElevatedButton.new({
            child: Text.new({ data: "Toggle Edit State" }),
            actions: {
              onTap: SetState("isEditing", V.transform(V.pageState("isEditing"), [{ type: "not" }])),
            },
          }),
        ],
      }),
    }),
});

// ── Settings Page ──────────────────────────────────────────

const settingsPage = PageDefinition.create({
  id: "settings",
  title: "Settings",
  render: (_ctx, _info) =>
    Padding.new({
      padding: { top: 16, left: 16, right: 16, bottom: 16 },
      child: Column.new({
        crossAxisAlignment: "start",
        children: [
          Text.new({
            data: "Settings",
            style: { fontSize: 24, fontWeight: "bold" },
          }),
          SizedBox.new({ height: 16 }),
          Text.new({
            data: "App settings will go here.",
            style: { fontSize: 14, color: "#666666" },
          }),
        ],
      }),
    }),
});

// ── Flows ──────────────────────────────────────────────────

const homeFlow = Flow.create({
  name: "home",
  routes: [
    {
      path: "home",
      page: homePage,
      children: [
        {
          path: "product/:id",
          page: productDetailPage,
          transition: { type: "slideUp", duration: 300, curve: "easeInOut" },
        },
      ],
    },
  ],
});

const searchFlow = Flow.create({
  name: "search",
  routes: [{ path: "search", page: searchPage }],
});

const cartFlow = Flow.create({
  name: "cart",
  routes: [
    {
      path: "cart",
      page: cartPage,
      hooks: {
        onEnter: (ctx) => {
          console.log(`[Analytics] Cart page viewed. Items: ${ctx.appState.cartCount ?? 0}`);
        },

      },
    },
  ],
});

const profileFlow = Flow.create({
  name: "profile",
  routes: [{ path: "profile", page: profilePage }],
});

const settingsFlow = Flow.create({
  name: "settings",
  routes: [{ path: "settings", page: settingsPage }],
});

// ── App ────────────────────────────────────────────────────

export const ecommerceApp = App.create({
  id: "ecommerce",
  name: "E-Commerce Demo",

  navigation: {
    initialRoute: "/home",
    initialAppState: { cartCount: 0, _tabIndex: 0 },
    tabs: [
      { id: "home", label: "Home", icon: "home", initialRoute: "/home" },
      { id: "search", label: "Search", icon: "search", initialRoute: "/search" },
      { id: "cart", label: "Cart", icon: "shopping_cart", initialRoute: "/cart" },
    ],

    // Server-driven tab bar — full visual control
    tabBar: Container.new({
      height: 60,
      decoration: { color: "#FFFFFF", border: { color: "#E0E0E0", width: 1, style: "solid" } },
      padding: EdgeInsets.symmetric({ vertical: 8 }),
      child: Row.new({
        mainAxisAlignment: "spaceAround",
        children: [
          IconButton.new({
            child: Icon.new({ name: "home", size: 24 }),
            color: V.when([
              { when: Expr.eq(V.appState("_tabIndex"), 0), then: V.static("#1976D2") },
              { when: Expr.neq(V.appState("_tabIndex"), 0), then: V.static("#757575") },
            ]),
            actions: { onTap: SwitchTab("home") },
          }),
          IconButton.new({
            child: Icon.new({ name: "search", size: 24 }),
            color: V.when([
              { when: Expr.eq(V.appState("_tabIndex"), 1), then: V.static("#1976D2") },
              { when: Expr.neq(V.appState("_tabIndex"), 1), then: V.static("#757575") },
            ]),
            actions: { onTap: SwitchTab("search") },
          }),
          IconButton.new({
            child: Icon.new({ name: "shopping_cart", size: 24 }),
            color: V.when([
              { when: Expr.eq(V.appState("_tabIndex"), 2), then: V.static("#1976D2") },
              { when: Expr.neq(V.appState("_tabIndex"), 2), then: V.static("#757575") },
            ]),
            actions: { onTap: SwitchTab("cart") },
          }),
        ],
      }),
    }),
    // BottomNavigationBar.new({
    //   currentIndex: V.appState("_tabIndex"),
    //   selectedItemColor: "#1976D2",
    //   unselectedItemColor: "#757575",
    //   backgroundColor: "#FFFFFF",
    //   items: [
    //     BottomNavItem.new({ icon: "home", label: "Home" }),
    //     BottomNavItem.new({ icon: "search", label: "Search" }),
    //     BottomNavItem.new({ icon: "shopping_cart", label: "Cart" }),
    //   ],
    // }),
    // Server-driven drawer — full visual control
    drawer: Drawer.new({
      backgroundColor: "#FFFFFF",
      child: Column.new({
        children: [
          Container.new({
            height: 180,
            width: Infinity,
            decoration: { color: "#1976D2" },
            child: Center.new({
              child: Column.new({
                mainAxisAlignment: "center",
                children: [
                  Icon.new({ name: "shopping_bag", size: 48, color: "#FFFFFF" }),
                  SizedBox.new({ height: 12 }),
                  Text.new({
                    data: "E-Commerce Demo",
                    style: { color: "#FFFFFF", fontSize: 22, fontWeight: "bold" },
                  }),
                ],
              }),
            }),
          }),
          SizedBox.new({ height: 8 }),
          Padding.new({
            padding: { top: 8, left: 16, right: 16, bottom: 8 },
            child: Column.new({
              children: [
                ElevatedButton.new({
                  child: Row.new({
                    children: [
                      Icon.new({ name: "person", size: 20 }),
                      SizedBox.new({ width: 12 }),
                      Text.new({ data: "Profile" }),
                    ],
                  }),
                  actions: { onTap: Navigate("/profile") },
                }),
                SizedBox.new({ height: 8 }),
                ElevatedButton.new({
                  child: Row.new({
                    children: [
                      Icon.new({ name: "settings", size: 20 }),
                      SizedBox.new({ width: 12 }),
                      Text.new({ data: "Settings" }),
                    ],
                  }),
                  actions: { onTap: Navigate("/settings") },
                }),
              ],
            }),
          }),
        ],
      }),
    }),
  },
  flows: [homeFlow, searchFlow, cartFlow, profileFlow, settingsFlow],
});
