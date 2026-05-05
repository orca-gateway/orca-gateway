import { App, Flow, PageDefinition } from "../../engine/src/core";
import { V, SetState, Navigate, GoBack } from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Text,
  Center,
  SizedBox,
  ElevatedButton,
  Icon,
  TextButton,
} from "../../engine/src/components";

// ── Static Pages (cached on client, version-controlled) ────

const homePage = PageDefinition.create({
  id: "home",
  title: "Home",
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Home (Static)" }) }),
      body: Center.new({
        child: Column.new({
          mainAxisAlignment: "center",
          children: [
            Icon.new({ name: "home", size: 64, color: "#2196F3" }),
            SizedBox.new({ height: 16 }),
            Text.new({
              data: "This page is served from cache",
              style: { fontSize: 20, fontWeight: "bold" },
            }),
            SizedBox.new({ height: 8 }),
            Text.new({
              data: "It loads instantly — no network request needed",
              style: { fontSize: 14, color: "#666666" },
            }),
            TextButton.new({
              child: Text.new({ data: "Go to About (also static)" }),
              actions: {
                onTap: Navigate('/about'),
              },
            }),
            TextButton.new({
              child: Text.new({ data: "Go to Profile (dynamic, always fresh)" }),
              actions: {
                onTap: Navigate('/profile'),
              },
            }),
          ],
        }),
      }),
    }),
});

const aboutPage = PageDefinition.create({
  id: "about",
  title: "About",
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "About (Static)" }) }),
      body: Center.new({
        child: Column.new({
          mainAxisAlignment: "center",
          children: [
            Icon.new({ name: "info", size: 64, color: "#4CAF50" }),
            SizedBox.new({ height: 16 }),
            Text.new({
              data: "About Page — also cached",
              style: { fontSize: 20, fontWeight: "bold" },
            }),
            SizedBox.new({ height: 8 }),
            Text.new({
              data: "Pre-rendered at config time, stored in SharedPreferences",
              style: { fontSize: 14, color: "#666666" },
            }),
            TextButton.new({
              child: Text.new({ data: "Back to Home" }),
              actions: {
                onTap: GoBack(),
              },
            }),
          ],
        }),
      }),
    }),
});

// ── Dynamic Page (always fetches fresh, even within static flow) ─

const profilePage = PageDefinition.create({
  id: "profile",
  title: "Profile",
  state: [{ key: "visits", scope: "page", initial: 0 }],
  render: (ctx) =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Profile (Dynamic)" }) }),
      body: Center.new({
        child: Column.new({
          mainAxisAlignment: "center",
          children: [
            Icon.new({ name: "person", size: 64, color: "#FF9800" }),
            SizedBox.new({ height: 16 }),
            Text.new({
              data: "This page always fetches fresh",
              style: { fontSize: 20, fontWeight: "bold" },
            }),
            SizedBox.new({ height: 8 }),
            Text.new({
              data: "Marked isDynamic: true — skipped during pre-rendering",
              style: { fontSize: 14, color: "#666666" },
            }),
            SizedBox.new({ height: 24 }),
            ElevatedButton.new({
              child: Text.new({
                data: V.transform(V.pageState("visits"), [
                  { type: "toString" },
                  { type: "template", template: "Visits: {{value}}" },
                ]),
              }),
              actions: {
                onTap: SetState(
                  "visits",
                  V.transform(V.pageState("visits"), [
                    { type: "add", by: V.static(1) },
                  ]),
                ),
              },
            }),
            TextButton.new({
              child: Text.new({ data: "Back to Home" }),
              actions: {
                onTap: GoBack(),
              },
            }),
          ],
        }),
      }),
    }),
});

// ── Flows ───────────────────────────────────────────────────

const mainFlow = Flow.create({
  name: "main",
  version: 4,
  isStatic: true,
  routes: [
    { path: "home", page: homePage },
    { path: "about", page: aboutPage },
    { path: "profile", page: profilePage, isDynamic: true },
  ],
});

// ── App (change forceUpdate to true to test force-update screen) ─

export const staticFlowsApp = App.create({
  id: "static-flows",
  name: "Static Flows Demo",
  forceUpdate: false,
  navigation: {
    initialRoute: "/home",
  },
  flows: [mainFlow],
});
