import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  V,
  Expr,
  Navigate,
  GoBack,
  SetState,
  Sequential,
  ShowSnackbar,
  type Action,
  type NavigateAction,
} from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Card,
  Column,
  Divider,
  ElevatedButton,
  OutlinedButton,
  TextButton,
  Icon,
  Row,
  Text,
  SizedBox,
  Padding,
  SingleChildScrollView,
  EdgeInsets,
} from "../../engine/src/components";
import type { Widget } from "../../engine/src/types/widget";

// Navigation demo (native parity, S9). An app whose /config drives the boot of
// the native SDKs: the first route is /welcome (not home), the app state is
// seeded with `loggedIn: false`, /account redirects to /login while logged
// out, /home has a nested child with a route param, and /settings is a route
// outside the tabs. The pages use only widgets and actions the iOS and Android
// SDKs draw today, so the same app runs on Flutter, iOS and Android.

const grey = "#757575";
const USER = "Ada";

/** Replaces the current location instead of pushing a new one. */
function Replace(route: string): NavigateAction {
  return { ...Navigate(route), replace: true };
}

const logIn = Sequential(
  SetState("loggedIn", V.static(true), "app"),
  SetState("userName", V.static(USER), "app"),
  Replace("/account"),
);

function logOut(then?: Action): Action {
  const actions: Action[] = [
    SetState("loggedIn", V.static(false), "app"),
    SetState("userName", V.static(""), "app"),
    ShowSnackbar("Logged out"),
  ];
  if (then) actions.push(then);
  return Sequential(...actions);
}

// ── Shared pieces ──────────────────────────────────────────

function gap() {
  return SizedBox.new({ height: 12 });
}

function note(text: string) {
  return Text.new({ data: text, style: { color: grey, fontSize: 14 } });
}

function pushButton(label: string, route: string) {
  return ElevatedButton.new({
    child: Text.new({ data: label }),
    actions: { onTap: Navigate(route) },
  });
}

function backButton() {
  return TextButton.new({
    child: Text.new({ data: "Back" }),
    actions: { onTap: GoBack() },
  });
}

/** The shared session, read live from app state. */
function sessionCard() {
  return Card.new({
    padding: EdgeInsets.all(16),
    child: Column.new({
      crossAxisAlignment: "start",
      children: [
        Row.new({
          children: [
            Icon.new({
              name: V.when([{ when: Expr.eq(V.appState("loggedIn"), true), then: V.static("lock_open") }], V.static("lock")),
              size: 20,
              color: grey,
            }),
            SizedBox.new({ width: 8 }),
            Text.new({
              data: V.when(
                [{ when: Expr.eq(V.appState("loggedIn"), true), then: V.static("loggedIn: true") }],
                V.static("loggedIn: false"),
              ),
              style: { fontSize: 16, fontWeight: "bold" },
            }),
          ],
        }),
        SizedBox.new({ height: 8 }),
        Text.new({
          data: V.transform(V.appState("userName"), [{ type: "template", template: "userName: {{value}}" }]),
        }),
      ],
    }),
  });
}

function screen(title: string, children: Widget[]) {
  return Scaffold.new({
    appBar: AppBar.new({ title: Text.new({ data: title }) }),
    body: SingleChildScrollView.new({
      child: Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({ crossAxisAlignment: "stretch", children }),
      }),
    }),
  });
}

// ── Pages ──────────────────────────────────────────────────

const welcomePage = PageDefinition.create({
  id: "welcome",
  title: "Welcome",
  appState: ["loggedIn", "userName"],
  render: () =>
    screen("Welcome", [
      note("The app starts here: the config's initialRoute is /welcome, not a tab."),
      gap(),
      sessionCard(),
      gap(),
      pushButton("Go to Home", "/home"),
      gap(),
      pushButton("Go to Account (protected)", "/account"),
      gap(),
      pushButton("Open product 42", "/home/product/42"),
      gap(),
      pushButton("Open Settings", "/settings"),
      gap(),
      OutlinedButton.new({
        child: Text.new({ data: "Log out" }),
        actions: { onTap: logOut() },
      }),
    ]),
});

const homePage = PageDefinition.create({
  id: "home",
  title: "Home",
  render: () =>
    screen("Home", [
      note("A tab. The product route below is its nested child."),
      gap(),
      pushButton("Open product 42", "/home/product/42"),
      gap(),
      pushButton("Open product 7", "/home/product/7"),
      gap(),
      pushButton("Open Settings", "/settings"),
      gap(),
      pushButton("Go to Account (protected)", "/account"),
      gap(),
      OutlinedButton.new({
        child: Text.new({ data: "Back to Welcome" }),
        actions: { onTap: Navigate("/welcome") },
      }),
    ]),
});

const productPage = PageDefinition.create({
  id: "product",
  title: "Product",
  render: (ctx) =>
    screen("Product", [
      Text.new({ data: `Product ${ctx.routeParams.id}`, style: { fontSize: 24, fontWeight: "bold" } }),
      SizedBox.new({ height: 8 }),
      note("Route home/product/:id, a child of home. The id comes from the route params."),
      gap(),
      pushButton("Open Settings", "/settings"),
      gap(),
      pushButton("Go to Account (protected)", "/account"),
      gap(),
      backButton(),
    ]),
});

const accountPage = PageDefinition.create({
  id: "account",
  title: "Account",
  appState: ["loggedIn", "userName"],
  render: () =>
    screen("Account", [
      note("A protected tab: while loggedIn is false, this route redirects to /login."),
      gap(),
      sessionCard(),
      gap(),
      pushButton("Open product 42", "/home/product/42"),
      gap(),
      pushButton("Open Settings", "/settings"),
      gap(),
      OutlinedButton.new({
        child: Text.new({ data: "Log out" }),
        actions: { onTap: logOut(Replace("/welcome")) },
      }),
    ]),
});

const loginPage = PageDefinition.create({
  id: "login",
  title: "Log in",
  appState: ["loggedIn", "userName"],
  render: () =>
    screen("Log in", [
      note("Logging in sets loggedIn and userName in app state, then replaces this page with /account."),
      gap(),
      sessionCard(),
      gap(),
      ElevatedButton.new({
        child: Text.new({ data: `Log in as ${USER}` }),
        actions: { onTap: logIn },
      }),
      gap(),
      backButton(),
    ]),
});

const settingsPage = PageDefinition.create({
  id: "settings",
  title: "Settings",
  render: () =>
    screen("Settings", [
      note("Not a tab: pushed over the tabs, with a back button in the title bar."),
      gap(),
      pushButton("About", "/settings/about"),
      gap(),
      pushButton("Go to Account (protected)", "/account"),
      gap(),
      Divider.new({}),
      backButton(),
    ]),
});

const aboutPage = PageDefinition.create({
  id: "about",
  title: "About",
  render: () =>
    screen("About", [
      Text.new({ data: "Orca Gateway navigation demo", style: { fontSize: 18, fontWeight: "bold" } }),
      SizedBox.new({ height: 8 }),
      note("Route settings/about, a child of settings."),
      gap(),
      pushButton("Go to Home", "/home"),
      gap(),
      backButton(),
    ]),
});

// ── Flows ──────────────────────────────────────────────────

const welcomeFlow = Flow.create({
  name: "welcome",
  routes: [{ path: "welcome", page: welcomePage }],
});

const homeFlow = Flow.create({
  name: "home",
  routes: [
    {
      path: "home",
      page: homePage,
      children: [{ path: "product/:id", page: productPage }],
    },
  ],
});

const accountFlow = Flow.create({
  name: "account",
  routes: [
    {
      path: "account",
      page: accountPage,
      redirect: { when: "loggedIn", equals: false, to: "/login" },
    },
    { path: "login", page: loginPage },
  ],
});

const settingsFlow = Flow.create({
  name: "settings",
  routes: [
    {
      path: "settings",
      page: settingsPage,
      children: [{ path: "about", page: aboutPage }],
    },
  ],
});

// ── App ────────────────────────────────────────────────────

export const navigationApp = App.create({
  id: "navigation",
  name: "Navigation Demo",
  flows: [welcomeFlow, homeFlow, accountFlow, settingsFlow],
  navigation: {
    initialRoute: "/welcome",
    initialAppState: { loggedIn: false, userName: "" },
    tabs: [
      { id: "home", label: "Home", icon: "home", initialRoute: "/home" },
      { id: "account", label: "Account", icon: "person", initialRoute: "/account" },
    ],
    drawerItems: [{ id: "settings", label: "Settings", icon: "settings", route: "/settings" }],
  },
});
