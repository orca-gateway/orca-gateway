# Orca Gateway Engine

Server-driven UI framework: write pages in **TypeScript** (Bun), render in **Flutter**.
Package: `orcagateway-engine`. Docs: https://orcagateway.com

## Project Structure

```
src/
  pages/          # PageDefinition files (one per page)
  flows/          # Flow definitions (group related routes)
  actions/        # ServerActionDefinition files
  app.ts          # App.create — register flows, navigation, server actions
  server.ts       # Engine bootstrap — new Engine(), registerApp, start
package.json
```

## Commands

```bash
bun run dev          # Start dev server with watch mode
bun run build        # Bundle for production
bun test             # Run tests
```

## Imports

```typescript
// Core — app scaffolding
import { App, Flow, PageDefinition, Engine, ServerActionDefinition } from "orcagateway-engine/core";

// Types — values, actions, expressions
import { V, TV, Expr, SetState, Navigate, GoBack, Sequential, Parallel, When,
         ShowSnackbar, ShowToast, ServerAction, CopyToClipboard, Share, OpenUrl,
         Lifecycle, RefetchPage, OpenDialog, CloseDialog, SwitchTab, OpenDrawer,
         AnimateForward, AnimateReverse, ClearState, Custom } from "orcagateway-engine/types";

// Components — widgets + helpers
import { Scaffold, AppBar, Column, Row, Text, Container, Center, SizedBox, Padding,
         Expanded, Flexible, Stack, Wrap, SingleChildScrollView, SafeArea,
         ElevatedButton, TextButton, IconButton, OutlinedButton, FloatingActionButton,
         TextField, TextFormField, Checkbox, Switch, Slider, Radio,
         Card, ListView, GridView, Image, Icon, Divider, Spacer, Opacity,
         Dialog, BottomSheet, Form, Drawer, BottomNavigationBar, BottomNavItem,
         AnimatedContainer, AnimatedOpacity, Hero, Table, PageView,
         EdgeInsets, TextStyle, BoxDecoration, BorderRadius, Color, Colors } from "orcagateway-engine/components";
```

## Page (the core building block)

Every screen is a `PageDefinition` with an optional state, optional data loader, and a `render` function:

```typescript
const counterPage = PageDefinition.create({
  id: "counter",
  title: "Counter",

  // 1. Declare reactive state (page-scoped or app-scoped)
  state: [
    { key: "count", scope: "page", initial: 0 },
  ],

  // 2. Optional async data fetch (result passed to render as `infoData`)
  getInfoData: async (ctx) => {
    // ctx.routeParams, ctx.requestInfo, ctx.pageState, ctx.appState
    return { greeting: "Hello" };
  },

  // 3. Build the widget tree
  render: (ctx, infoData) =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Counter" }) }),
      body: Center.new({
        child: Column.new({
          mainAxisAlignment: "center",
          children: [
            Text.new({
              data: V.transform(V.pageState("count"), [TV.toString()]),
              style: { fontSize: 48, fontWeight: "bold" },
            }),
            SizedBox.new({ height: 24 }),
            Row.new({
              mainAxisAlignment: "center",
              children: [
                ElevatedButton.new({
                  child: Text.new({ data: "-" }),
                  actions: {
                    onTap: SetState("count", V.transform(V.pageState("count"), [TV.subtract(V.static(1))])),
                  },
                }),
                SizedBox.new({ width: 16 }),
                ElevatedButton.new({
                  child: Text.new({ data: "+" }),
                  actions: {
                    onTap: SetState("count", V.transform(V.pageState("count"), [TV.add(V.static(1))])),
                  },
                }),
              ],
            }),
            SizedBox.new({ height: 16 }),
            ElevatedButton.new({
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
      }),
    }),
});
```

## Flow (group routes)

```typescript
const mainFlow = Flow.create({
  name: "main",
  routes: [
    { path: "home", page: homePage },
    { path: "products", page: productsPage, children: [
      { path: ":id", page: productDetailPage, transition: { type: "slide", duration: 300 } },
    ]},
    { path: "settings", page: settingsPage },
  ],
});
```

**RouteDefinition options:** `path`, `page`, `children`, `transition` (`{ type: "slide"|"fade"|"scale"|"slideUp"|"slideRight"|"none", duration?, curve? }`), `hooks` (`{ onEnter?, onExit? }`), `redirect` (`{ when, equals, to }`), `isDynamic`.

## App (top-level container)

```typescript
const myApp = App.create({
  id: "my-app",
  name: "My App",
  flows: [mainFlow, settingsFlow],
  actions: [submitFormAction, addToCartAction],   // server actions
  navigation: {
    initialRoute: "/home",
    initialAppState: { theme: "light", cartCount: 0 },
    tabs: [
      { id: "home", label: "Home", icon: "home", initialRoute: "/home" },
      { id: "search", label: "Search", icon: "search", initialRoute: "/search" },
      { id: "profile", label: "Profile", icon: "person", initialRoute: "/profile" },
    ],
    drawerItems: [
      { id: "settings", label: "Settings", icon: "settings", route: "/settings" },
    ],
  },
});
```

## Engine (start the server)

```typescript
const engine = new Engine();
engine.registerApp(myApp);
await engine.start({ port: 3000, devMonitor: true });
```

**EngineConfig:** `port?` (default 8080), `cache?` (true/false/CacheProvider), `cacheSqlitePath?`, `devMonitor?`, `enableDebugEndpoint?`, `maxRequestBodySize?`.

## Value System (V.*)

All widget props accept `Valueable<T>` — either a static value or a reactive `Value`:

| Helper | Purpose | Example |
|---|---|---|
| `V.static(x)` | Literal value | `V.static("hello")` |
| `V.pageState("key")` | Read page state | `V.pageState("count")` |
| `V.appState("key")` | Read app state | `V.appState("cartCount")` |
| `V.info("key")` | Read getInfoData result (dot-notation) | `V.info("user.name")` |
| `V.request("key")` | Read request metadata | `V.request("locale")` |
| `V.event("key")` | Input event value (SDK sends `"value"` for inputs) | `V.event("value")` |
| `V.transform(val, transforms)` | Apply transforms | `V.transform(V.pageState("count"), [TV.add(V.static(1))])` |
| `V.when(branches, else)` | Conditional | `V.when([{ when: Expr.eq(V.pageState("x"), 1), then: V.static("yes") }], V.static("no"))` |
| `V.Tween(begin, end, animId?)` | Animation tween | `V.Tween(0, 1, "fade")` |

## Transform Helpers (TV.*)

Chain transforms via `V.transform(value, [TV.xxx(), ...])`:

**String:** `TV.toString()`, `TV.toUpperCase()`, `TV.toLowerCase()`, `TV.trim()`, `TV.template("Count: {{value}}")`, `TV.substring(start, length?)`, `TV.split(sep)`, `TV.join(sep)`, `TV.regex(pattern, flags?)`

**Number:** `TV.add(V.static(1))`, `TV.subtract(by)`, `TV.multiply(by)`, `TV.divide(by)`, `TV.modulo(by)`, `TV.round()`, `TV.floor()`, `TV.ceil()`, `TV.abs()`, `TV.toFixed(decimals)`

**Boolean:** `TV.not()`, `TV.toBool()`

**Collection:** `TV.length()`, `TV.at(index)`, `TV.first()`, `TV.last()`, `TV.map(transform)`, `TV.filter(boolExpr)`, `TV.contains(value)`

**Format:** `TV.formatCurrency("USD", decimals?)`, `TV.formatDate("yyyy-MM-dd")`, `TV.formatNumber(decimals?, useGrouping?)`

## Boolean Expressions (Expr.*)

Used in `V.when()` and `When()` action conditions:

`Expr.eq(left, right)`, `Expr.neq`, `Expr.gt`, `Expr.gte`, `Expr.lt`, `Expr.lte`, `Expr.and(...exprs)`, `Expr.or(...exprs)`, `Expr.not(expr)`, `Expr.isNull(val)`, `Expr.contains(haystack, needle)`, `Expr.startsWith(str, prefix)`, `Expr.matches(str, regex)`

The right-hand side auto-wraps with `V.static()` if a plain value is passed.

## Actions

Actions are event handlers on widget `actions` prop:

| Action | Signature | Example |
|---|---|---|
| `Navigate` | `(route, params?)` | `Navigate("/product/42")` |
| `GoBack` | `()` | `GoBack()` |
| `SwitchTab` | `(tabId)` | `SwitchTab("home")` |
| `OpenDrawer` | `()` | `OpenDrawer()` |
| `SetState` | `(key, value, scope?)` | `SetState("name", V.event("value"))` |
| `ClearState` | `(key, scope?)` | `ClearState("count")` |
| `ServerAction` | `(id, params?)` | `ServerAction("submit", { name: V.pageState("name") })` |
| `ShowSnackbar` | `(message, duration?)` | `ShowSnackbar("Saved!")` |
| `ShowToast` | `(message)` | `ShowToast("Done")` |
| `CopyToClipboard` | `(text)` | `CopyToClipboard(V.pageState("code"))` |
| `Share` | `(title, message, url?)` | `Share("Check this", "Cool app")` |
| `OpenUrl` | `(url)` | `OpenUrl("https://example.com")` |
| `OpenDialog` | `(dialogId, heightFactor?)` | `OpenDialog("confirm")` |
| `CloseDialog` | `()` | `CloseDialog()` |
| `Sequential` | `(...actions)` | `Sequential(SetState("x", V.static(1)), ShowSnackbar("Done"))` |
| `Parallel` | `(...actions)` | `Parallel(action1, action2)` |
| `When` | `(branches, else?)` | `When([{ when: Expr.gt(V.pageState("count"), 0), then: action }])` |
| `Lifecycle` | `(action, opts)` | `Lifecycle(ServerAction("load"), { onLoading: ..., onError: ... })` |
| `RefetchPage` | `()` | `RefetchPage()` |
| `AnimateForward` | `(animationId)` | `AnimateForward("slide")` |
| `AnimateReverse` | `(animationId)` | `AnimateReverse("slide")` |
| `Custom` | `(type, params?)` | `Custom("custom:myAction", { data: 1 })` |

**Action triggers:** `onTap`, `onLongPress`, `onDoubleTap`, `onChange`, `onScrollBegin`, `onScrolling`, `onScrollEnd`, `onVisible`, `onInit`, `onBackground`, `onForeground`, `onSuccess`, `onError`, `onComplete`.

## Server Actions

Server actions handle round-trip mutations. Define them and register in `App.create({ actions: [...] })`:

```typescript
const submitFormAction = ServerActionDefinition.create({
  id: "submitForm",
  schema: {
    name: { type: "string", required: true },
    email: { type: "string", required: true },
  },
  execute: async (ctx) => {
    const { name, email } = ctx.actionParams as { name: string; email: string };
    // ... save to database, call API, etc.
    return [
      { type: "setState", scope: "page" as const, key: "submitted", value: true },
      { type: "showSnackbar", message: `Welcome, ${name}!` },
    ];
  },
});
```

**Trigger from UI:** `ServerAction("submitForm", { name: V.pageState("name"), email: V.pageState("email") })`

**With loading/error UX:** `Lifecycle(ServerAction("submitForm", params), { onLoading: SetState("loading", V.static(true)), onError: ShowSnackbar("Failed"), onComplete: SetState("loading", V.static(false)) })`

**Response action types:** `setState`, `navigate`, `goBack`, `showSnackbar`, `showToast`, `copyToClipboard`, `addComponent` (dynamic insert), `replaceComponent`, `updateComponent`, `deleteComponent`, `closeDialog`.

## Widget Reference

All widgets use `.new({...})` factories — **never use the `new` keyword**.

**Layout:** `Column` (children, gap?, mainAxisAlignment?, crossAxisAlignment?), `Row` (same), `Container` (child, padding?, decoration?, width?, height?), `Stack` (children, fit?), `Wrap` (children, spacing?, runSpacing?), `Padding` (child, padding), `SizedBox` (width?, height?, child?), `Center` (child), `Expanded` (child, flex?), `Flexible` (child, flex?, fit?), `SingleChildScrollView` (child), `SafeArea` (child, top?, bottom?)

**Primitive:** `Text` (data, style?, textAlign?, maxLines?, overflow?), `Image` (src, fit?, width?, height?), `Icon` (icon, size?, color?), `Divider` (height?, color?), `Spacer` (flex?)

**Input:** `TextField` (value?, placeholder?, inputType?, obscureText?, maxLines?, actions: { onChange }), `TextFormField` (same + validation), `Checkbox` (value, actions: { onChange }), `Switch` (value, actions: { onChange }), `Slider` (value, min?, max?, actions: { onChange }), `Radio` (value, groupValue, actions: { onChange })

**Button:** `ElevatedButton` (child, actions: { onTap }), `TextButton`, `IconButton` (icon, actions), `OutlinedButton`, `FloatingActionButton`

**Structure:** `Scaffold` (body, appBar?, floatingActionButton?, bottomNavigationBar?, drawer?, backgroundColor?), `AppBar` (title, leading?, actions?, centerTitle?), `Card` (child, elevation?), `ListView` (children, scrollDirection?, padding?, shrinkWrap?, separator?), `GridView` (children, crossAxisCount), `Dialog` (child, title?), `BottomSheet` (child)

**Helpers:** `EdgeInsets.all(16)`, `EdgeInsets.symmetric({ horizontal: 16, vertical: 8 })`, `EdgeInsets.only({ top: 16 })`, `{ top, right, bottom, left }` object form. `Color("#hex")`, `Colors.blue`. `TextStyle`: `{ fontSize, fontWeight, color, decoration }`. `BoxDecoration`: `{ color, borderRadius, border, boxShadow, gradient }`.

## Recipe: Form with Server Action

```typescript
const formPage = PageDefinition.create({
  id: "contact",
  title: "Contact",
  state: [
    { key: "name", scope: "page", initial: "" },
    { key: "email", scope: "page", initial: "" },
    { key: "loading", scope: "page", initial: false },
  ],
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Contact Us" }) }),
      body: Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({
          gap: 16,
          children: [
            TextField.new({
              placeholder: "Your name",
              actions: { onChange: SetState("name", V.event("value")) },
            }),
            TextField.new({
              placeholder: "Email",
              inputType: "email",
              actions: { onChange: SetState("email", V.event("value")) },
            }),
            ElevatedButton.new({
              child: Text.new({
                data: V.when(
                  [{ when: Expr.eq(V.pageState("loading"), true), then: V.static("Sending...") }],
                  V.static("Submit"),
                ),
              }),
              actions: {
                onTap: Lifecycle(
                  ServerAction("submitForm", {
                    name: V.pageState("name"),
                    email: V.pageState("email"),
                  }),
                  {
                    onLoading: SetState("loading", V.static(true)),
                    onComplete: SetState("loading", V.static(false)),
                    onError: ShowSnackbar("Something went wrong"),
                  },
                ),
              },
            }),
          ],
        }),
      }),
    }),
});
```

## Recipe: List with Detail Navigation

```typescript
const listPage = PageDefinition.create({
  id: "products",
  title: "Products",
  getInfoData: async () => {
    const res = await fetch("https://api.example.com/products");
    return { products: await res.json() };
  },
  render: (_ctx, infoData) => {
    const data = infoData as { products: { id: string; name: string; price: number }[] };
    return Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Products" }) }),
      body: ListView.new({
        children: data.products.map((p) =>
          Card.new({
            child: Padding.new({
              padding: EdgeInsets.all(16),
              child: Row.new({
                mainAxisAlignment: "spaceBetween",
                children: [
                  Text.new({ data: p.name, style: { fontSize: 16 } }),
                  Text.new({ data: `$${p.price}`, style: { fontWeight: "bold" } }),
                ],
              }),
            }),
            actions: { onTap: Navigate(`/products/${p.id}`) },
          }),
        ),
      }),
    });
  },
});

const detailPage = PageDefinition.create({
  id: "product-detail",
  title: "Detail",
  getInfoData: async (ctx) => {
    const res = await fetch(`https://api.example.com/products/${ctx.routeParams.id}`);
    return res.json();
  },
  render: (_ctx, infoData) => {
    const product = infoData as { name: string; description: string; price: number };
    return Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: product.name }),
        leading: IconButton.new({ icon: "arrow_back", actions: { onTap: GoBack() } }),
      }),
      body: Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({
          crossAxisAlignment: "start",
          children: [
            Text.new({ data: product.name, style: { fontSize: 24, fontWeight: "bold" } }),
            SizedBox.new({ height: 8 }),
            Text.new({ data: product.description }),
            SizedBox.new({ height: 16 }),
            Text.new({ data: `$${product.price}`, style: { fontSize: 20, color: "#4CAF50" } }),
          ],
        }),
      }),
    });
  },
});
```

## Anti-Patterns

1. **Never use `new` keyword** on widgets — always `Widget.new({...})`
2. **Never hand-build Value JSON** — use `V.*`, `TV.*`, `Expr.*` helpers
3. **Never mutate state directly** — use `SetState()` action or server action `setState` response
4. **Never put async/mutation logic in `render`** — use `getInfoData` for data fetching, server actions for mutations
5. **Never import from internal paths** like `orcagateway-engine/src/...` — use barrel exports (`/core`, `/types`, `/components`)
6. **Never forget `.withKey("id")`** on widgets targeted by server action `addComponent`/`replaceComponent` responses

## Tips

- `V.info("path.to.nested")` supports dot-notation for nested `getInfoData` results
- `ctx.routeParams.id` reads path params from routes like `products/:id`
- `ctx.requestInfo.screenSize.width` — use for responsive layouts
- `Lifecycle()` wraps any action with `onLoading`, `onError`, `onComplete` callbacks — essential for async UX
- `EdgeInsets.all(16)` is shorthand for uniform padding; also `EdgeInsets.symmetric()` and `EdgeInsets.only()`
- Server actions can dynamically insert widgets via `addComponent` / `replaceComponent` response types
- State scope `"page"` resets on navigation, `"app"` persists across the entire app lifecycle
