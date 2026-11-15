import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  V,
  Expr,
  Navigate,
  GoBack,
  SetState,
  SwitchTab,
  OpenDrawer,
  type Action,
  type Value,
} from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  BottomNavigationBar,
  BottomNavItem,
  Column,
  Container,
  Divider,
  Drawer,
  ElevatedButton,
  Expanded,
  Icon,
  OutlinedButton,
  Padding,
  Row,
  SingleChildScrollView,
  SizedBox,
  Text,
  TextButton,
  TextField,
  EdgeInsets,
} from "../../engine/src/components";
import type { MaterialIcons } from "../../engine/src/types/icons";
import type { Widget } from "../../engine/src/types/widget";

// Tabs demo (native parity, S10). Two apps over the same flows and pages:
//   tabs         the default shell: the SDK draws the tab bar from `tabs` and
//                the drawer from `drawerItems`.
//   tabs-server  the server-driven shell: the tab bar and the drawer are
//                widget trees sent in /config (`tabBar`, `drawer`).
// Each tab has something to lose (a counter, a scroll position, typed text) so
// a person can see that a tab keeps its page while another one is shown. The
// pages and the shell trees use only widgets and actions the iOS and Android
// SDKs draw today (sdk-swift/capabilities.json), so both apps run on Flutter,
// iOS and Android.

const grey = "#757575";
const blue = "#1976D2";
const paleBlue = "#E3F2FD";
const white = "#FFFFFF";

const FEED_ROWS = 40;

interface Tab {
  id: string;
  label: string;
  icon: MaterialIcons;
  initialRoute: string;
}

const TABS: Tab[] = [
  { id: "feed", label: "Feed", icon: "home", initialRoute: "/feed" },
  { id: "search", label: "Search", icon: "search", initialRoute: "/search" },
  { id: "profile", label: "Profile", icon: "person", initialRoute: "/profile" },
];

// ── Shared pieces ──────────────────────────────────────────

function gap() {
  return SizedBox.new({ height: 12 });
}

function note(text: string) {
  return Text.new({ data: text, style: { color: grey, fontSize: 14 } });
}

function button(label: string, onTap: Action) {
  return ElevatedButton.new({ child: Text.new({ data: label }), actions: { onTap } });
}

function backButton() {
  return TextButton.new({ child: Text.new({ data: "Back" }), actions: { onTap: GoBack() } });
}

/** A live value behind a label, as in "count: 3". */
function labelled(label: string, value: Value) {
  return Text.new({
    data: V.transform(value, [{ type: "template", template: `${label}: {{value}}` }]),
    style: { fontSize: 16, fontWeight: "bold" },
  });
}

function plusOne(value: Value): Value {
  return V.transform(value, [{ type: "add", by: V.static(1) }]);
}

function scrolling(children: Widget[]) {
  return SingleChildScrollView.new({
    child: Padding.new({
      padding: EdgeInsets.all(16),
      child: Column.new({ crossAxisAlignment: "stretch", children }),
    }),
  });
}

function screen(title: string, children: Widget[]) {
  return Scaffold.new({
    appBar: AppBar.new({ title: Text.new({ data: title }) }),
    body: scrolling(children),
  });
}

function feedRow(index: number) {
  return Column.new({
    crossAxisAlignment: "stretch",
    children: [
      Padding.new({
        padding: EdgeInsets.symmetric({ vertical: 12 }),
        child: Text.new({ data: `Row ${index} of ${FEED_ROWS}` }),
      }),
      Divider.new({}),
    ],
  });
}

// ── Pages ──────────────────────────────────────────────────

const feedPage = PageDefinition.create({
  id: "feed",
  title: "Feed",
  state: [{ key: "count", scope: "page", initial: 0 }],
  appState: ["visits"],
  render: () =>
    screen("Feed", [
      note("Tab 0. Count up and scroll down, switch tab and come back: the count and the scroll position are kept."),
      gap(),
      labelled("count (page state)", V.pageState("count")),
      button("+1", SetState("count", plusOne(V.pageState("count")))),
      gap(),
      labelled("visits (app state)", V.appState("visits")),
      button("visits +1", SetState("visits", plusOne(V.appState("visits")), "app")),
      gap(),
      button("Open post 7", Navigate("/feed/post/7")),
      gap(),
      button("Go to Search (SwitchTab)", SwitchTab("search")),
      gap(),
      button("Go to Profile (_tabIndex = 2)", SetState("_tabIndex", V.static(2), "app")),
      gap(),
      button("Open drawer", OpenDrawer()),
      gap(),
      button("Open Settings", Navigate("/settings")),
      gap(),
      ...Array.from({ length: FEED_ROWS }, (_, i) => feedRow(i + 1)),
    ]),
});

const postPage = PageDefinition.create({
  id: "post",
  title: "Post",
  render: (ctx) =>
    screen("Post", [
      Text.new({ data: `Post ${ctx.routeParams.id}`, style: { fontSize: 24, fontWeight: "bold" } }),
      SizedBox.new({ height: 8 }),
      note("Route feed/post/:id, a child of feed: pushed inside the Feed tab, so the tab bar stays."),
      gap(),
      button("Go to Search (SwitchTab)", SwitchTab("search")),
      gap(),
      backButton(),
    ]),
});

const searchPage = PageDefinition.create({
  id: "search",
  title: "Search",
  state: [{ key: "query", scope: "page", initial: "" }],
  render: () =>
    screen("Search", [
      note("Tab 1. Type something, switch tab and come back: the text is kept."),
      gap(),
      TextField.new({
        placeholder: "Type here",
        value: V.pageState("query"),
        actions: { onChange: SetState("query", V.event("value")) },
      }),
      gap(),
      labelled("You typed", V.pageState("query")),
    ]),
});

const profilePage = PageDefinition.create({
  id: "profile",
  title: "Profile",
  appState: ["_tabIndex"],
  render: () =>
    screen("Profile", [
      note("Tab 2. The shell writes the index of the tab on show into the app state key _tabIndex."),
      gap(),
      labelled("_tabIndex", V.appState("_tabIndex")),
      gap(),
      button("Open drawer", OpenDrawer()),
      gap(),
      button("Page with its own drawers", Navigate("/profile/local")),
    ]),
});

function localDrawer(title: string, hint: string) {
  return Drawer.new({
    child: Padding.new({
      padding: EdgeInsets.all(16),
      child: Column.new({
        crossAxisAlignment: "start",
        children: [
          Text.new({ data: title, style: { fontSize: 20, fontWeight: "bold" } }),
          SizedBox.new({ height: 8 }),
          note(hint),
        ],
      }),
    }),
  });
}

const localPage = PageDefinition.create({
  id: "local",
  title: "Own drawers",
  state: [{ key: "section", scope: "page", initial: 0 }],
  appState: ["lastSection"],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Own drawers" }) }),
      body: scrolling([
        note("Route profile/local. This page's Scaffold has its own drawer, endDrawer and bottomNavigationBar."),
        gap(),
        labelled("section (page state)", V.pageState("section")),
        labelled("lastSection (app state)", V.appState("lastSection")),
        gap(),
        button("Open drawer", OpenDrawer()),
        gap(),
        backButton(),
      ]),
      drawer: localDrawer("Page drawer", "The drawer slot of this page: it opens from the leading edge."),
      endDrawer: localDrawer("Page end drawer", "The endDrawer slot of this page: it opens from the trailing edge."),
      bottomNavigationBar: BottomNavigationBar.new({
        currentIndex: V.pageState("section"),
        selectedItemColor: blue,
        unselectedItemColor: grey,
        items: [
          BottomNavItem.new({ icon: "info", label: "Info" }),
          BottomNavItem.new({ icon: "photo", label: "Photos" }),
          BottomNavItem.new({ icon: "star", label: "Starred" }),
        ],
        actionTriggers: { onChange: SetState("lastSection", V.event("value"), "app") },
      }),
    }),
});

const settingsPage = PageDefinition.create({
  id: "settings",
  title: "Settings",
  render: () =>
    screen("Settings", [
      note("Not a tab: drawn over the tabs, the tab bar is covered, back is in the title bar."),
      gap(),
      button("Open Help", Navigate("/help")),
      gap(),
      backButton(),
    ]),
});

const helpPage = PageDefinition.create({
  id: "help",
  title: "Help",
  render: () =>
    screen("Help", [
      note("Not a tab either. Go back, or jump to a tab: SwitchTab drops what was pushed over the tabs."),
      gap(),
      button("Go to Search (SwitchTab)", SwitchTab("search")),
      gap(),
      backButton(),
    ]),
});

// ── Flows ──────────────────────────────────────────────────

const flows = [
  Flow.create({
    name: "feed",
    routes: [{ path: "feed", page: feedPage, children: [{ path: "post/:id", page: postPage }] }],
  }),
  Flow.create({
    name: "search",
    routes: [{ path: "search", page: searchPage }],
  }),
  Flow.create({
    name: "profile",
    routes: [{ path: "profile", page: profilePage, children: [{ path: "local", page: localPage }] }],
  }),
  Flow.create({
    name: "more",
    routes: [
      { path: "settings", page: settingsPage },
      { path: "help", page: helpPage },
    ],
  }),
];

// ── Server-driven shell (tabs-server) ──────────────────────

/** `selected` on the tab the shell shows (app state _tabIndex), `other` on the rest. */
function whenTab(index: number, selected: string, other: string): Value {
  return V.when([{ when: Expr.eq(V.appState("_tabIndex"), index), then: V.static(selected) }], V.static(other));
}

function tabButton(tab: Tab, index: number) {
  return Expanded.new({
    child: Container.new({
      color: whenTab(index, paleBlue, white),
      child: TextButton.new({
        child: Column.new({
          mainAxisSize: "min",
          children: [
            Icon.new({ name: tab.icon, size: 24, color: whenTab(index, blue, grey) }),
            Text.new({ data: tab.label, style: { fontSize: 12 } }),
          ],
        }),
        actions: { onTap: SwitchTab(tab.id) },
      }),
    }),
  });
}

const serverTabBar = Container.new({
  color: white,
  padding: EdgeInsets.symmetric({ horizontal: 8, vertical: 4 }),
  child: Row.new({
    children: [
      ...TABS.map(tabButton),
      SizedBox.new({ width: 8 }),
      Text.new({
        data: V.transform(V.appState("visits"), [{ type: "template", template: "visits: {{value}}" }]),
        style: { color: grey, fontSize: 12 },
      }),
    ],
  }),
});

function drawerRow(label: string, icon: MaterialIcons, onTap: Action) {
  return OutlinedButton.new({
    child: Row.new({
      children: [Icon.new({ name: icon, size: 20 }), SizedBox.new({ width: 12 }), Text.new({ data: label })],
    }),
    actions: { onTap },
  });
}

const serverDrawer = Drawer.new({
  backgroundColor: white,
  child: Column.new({
    crossAxisAlignment: "stretch",
    children: [
      Container.new({
        color: blue,
        padding: EdgeInsets.all(24),
        child: Text.new({ data: "Tabs demo (server drawer)", style: { color: white, fontSize: 20, fontWeight: "bold" } }),
      }),
      Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({
          crossAxisAlignment: "stretch",
          children: [
            drawerRow("Settings", "settings", Navigate("/settings")),
            gap(),
            drawerRow("Help", "help", Navigate("/help")),
            gap(),
            drawerRow("Profile tab (SwitchTab)", "person", SwitchTab("profile")),
          ],
        }),
      }),
    ],
  }),
});

// ── Apps ───────────────────────────────────────────────────

const initialRoute = "/feed";
const initialAppState = { _tabIndex: 0, visits: 0 };

export const tabsApp = App.create({
  id: "tabs",
  name: "Tabs Demo",
  flows,
  navigation: {
    initialRoute,
    initialAppState,
    tabs: TABS,
    drawerItems: [
      { id: "settings", label: "Settings", icon: "settings", route: "/settings" },
      { id: "help", label: "Help", icon: "help", route: "/help" },
    ],
  },
});

export const tabsServerApp = App.create({
  id: "tabs-server",
  name: "Tabs Demo (server shell)",
  flows,
  navigation: {
    initialRoute,
    initialAppState,
    tabs: TABS,
    tabBar: serverTabBar,
    drawer: serverDrawer,
  },
});
