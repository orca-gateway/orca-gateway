import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  V,
  SetState,
  PersistState,
  ClearState,
  Sequential,
  Navigate,
  type Action,
  type Value,
} from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Divider,
  ElevatedButton,
  OutlinedButton,
  Text,
  SizedBox,
  Padding,
  SingleChildScrollView,
  EdgeInsets,
} from "../../engine/src/components";
import type { Widget } from "../../engine/src/types/widget";

// Saved state demo (native parity, S14). persistState saves a snapshot of one
// key on the device (local: kept after a relaunch) or for the session (kept
// until the app process ends); clearState forgets the key and both saved
// copies. A saved key replaces the declared initial when its page (or, for app
// state, the app) is set up again. Run it with ORCA_APP_ID=saved-state and
// ORCA_PATH=home.

const grey = "#757575";

function gap() {
  return SizedBox.new({ height: 12 });
}

function note(text: string) {
  return Text.new({ data: text, style: { color: grey, fontSize: 14 } });
}

function big(data: Value) {
  return Text.new({ data, style: { fontSize: 28, fontWeight: "bold" } });
}

function button(label: string, onTap: Action, what: string) {
  return Column.new({
    crossAxisAlignment: "stretch",
    children: [
      ElevatedButton.new({ child: Text.new({ data: label }), actions: { onTap } }),
      SizedBox.new({ height: 4 }),
      note(what),
      gap(),
    ],
  });
}

function addOne(key: string, scope: "page" | "app"): Action {
  const current = scope === "app" ? V.appState(key) : V.pageState(key);
  return SetState(key, V.transform(current, [{ type: "add", by: V.static(1) }]), scope);
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

const homePage = PageDefinition.create({
  id: "home",
  title: "Saved state",
  state: [
    { key: "count", scope: "page", initial: 0 },
    { key: "visits", scope: "app", initial: 0 },
  ],
  render: () =>
    screen("Saved state", [
      note("Page state count, 0 when nothing is saved."),
      big(V.transform(V.pageState("count"), [{ type: "template", template: "Count: {{value}}" }])),
      gap(),
      button("+1", addOne("count", "page"), "Adds 1. Not saved until you save it."),
      button("Save on device", PersistState("count"), "Saves count now: kept after the app is killed and relaunched."),
      button(
        "Save for this session",
        PersistState("count", "page", "session"),
        "Saves count now: kept when you leave and reopen this page, gone after a relaunch.",
      ),
      button("Forget", ClearState("count"), "Empties count and deletes both saved copies."),
      Divider.new({}),
      gap(),
      note("App state visits, 0 when nothing is saved."),
      big(V.transform(V.appState("visits"), [{ type: "template", template: "Visits: {{value}}" }])),
      gap(),
      button(
        "+1 and save",
        Sequential(addOne("visits", "app"), PersistState("visits", "app")),
        "Adds 1 to visits and saves it on the device: kept after a relaunch.",
      ),
      Divider.new({}),
      gap(),
      OutlinedButton.new({
        child: Text.new({ data: "Leave this page" }),
        actions: { onTap: Navigate("/other") },
      }),
      SizedBox.new({ height: 4 }),
      note("Opens the other page; its button opens this page again."),
    ]),
});

const otherPage = PageDefinition.create({
  id: "other",
  title: "Other page",
  render: () =>
    screen("Other page", [
      note("You left the home page. Opening it again shows its saved count, or 0 when nothing is saved."),
      gap(),
      ElevatedButton.new({
        child: Text.new({ data: "Back home" }),
        actions: { onTap: Navigate("/home") },
      }),
    ]),
});

// ── App ────────────────────────────────────────────────────

const savedStateFlow = Flow.create({
  name: "saved-state",
  routes: [
    { path: "home", page: homePage },
    { path: "other", page: otherPage },
  ],
});

export const savedStateApp = App.create({
  id: "saved-state",
  name: "Saved state",
  flows: [savedStateFlow],
  navigation: { initialRoute: "/home" },
});
