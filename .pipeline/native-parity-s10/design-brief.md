# Design brief · native-parity-s10 · tabs and drawer

Stand-in for stages 05–07 (skipped: the approved plan file covers them). Source of truth for behaviour is the
Flutter SDK; where Flutter is only inferred from go_router, a fixture run on the real Flutter `OrcaApp` decides.

## 1. What Flutter does (the oracle)

Files: `sdk/lib/src/navigation/navigation_handler.dart` (NH), `sdk/lib/src/widgets/orca_shell.dart` (SH),
`sdk/lib/src/state/action_executor.dart` (AE), `sdk/lib/src/builders/structure_builders.dart` (SB).

1. Tabs exist only when `config.tabs` is non-empty: `StatefulShellRoute.indexedStack`, one branch per tab in order.
   Membership `path == initialRoute || startsWith(initialRoute + "/")`; a tab with no route gets a synthetic root.
   (Already in `RouteTable.resolve`: `tabIndex`, `stack`.)
2. Each tab keeps its page stack and page state; a tab's page is fetched on first visit; switching never re-fetches.
3. Default bar: Material `BottomNavigationBar`, icon (Material icon name) + label per tab. Tapping another tab
   restores its last location; tapping the selected tab pops that tab to its root (`goBranch(i, initialLocation: i == current)`).
4. `_tabIndex` app state: the shell writes the current index on mount and on every tab change (SH:81-88), before the
   first tab page request. A write of an int different from the current index switches to that tab and restores its
   stack (SH:96-101). Non-int: ignored. Out of range: unguarded in Flutter.
5. `switchTab {tabId}`: `GoRouter.go(tab.initialRoute)` (AE:347-357): lands on the tab's root, drops anything pushed
   over the shell. Unknown id / no tabs: no-op.
6. `tabBarComponents` (flat `ComponentNode[]`, first node is the root) replaces the default bar. Resolved against
   app state only, executor page id `__shell__`. Current index comes from `V.appState("_tabIndex")`.
7. Shell drawer, only with tabs: `drawerComponents` (server tree, root normally a `Drawer`), else a default built from
   `drawerItems` (blue "Menu" header, icon + label rows; a tap closes the drawer, then pushes `item.route`), else none.
   With a drawer the shell shows a top bar on every tab page: title = current tab label, leading menu button.
8. `openDrawer {}` (no fields; there is no `closeDrawer`, no `end`): opens the shell drawer from a tab page; no-op
   when the shell has no drawer. Elsewhere Flutter throws (`Scaffold.of`).
9. Routes outside the tabs cover the tab bar and get the step 9 title bar; no drawer there.
10. Page `Scaffold` slots `drawer`, `endDrawer`, `bottomNavigationBar` pass straight to Material `Scaffold`.
    `Drawer` props: `backgroundColor`, `elevation`, `width`; one child.
    `BottomNavigationBar`: slots `item_0..item_9`, props `currentIndex` (Valueable, default 0, clamped),
    `backgroundColor`, `selectedItemColor`, `unselectedItemColor`; zero items draws nothing. A tap first writes the
    index into the state key `currentIndex` is bound to (`{type: state, scope, key}`; scope default page), then fires
    `onChange` with `event.value = index` (SB:290-307). `BottomNavItem`: `icon`, `activeIcon`, `label` read raw
    (not resolved); standalone it is an icon + label row.
11. Back: pops inside the current tab; at a tab root it leaves the app; no hop to the first tab.

## 2. Decisions taken here (minor; logged)

- D1 `openDrawer` where Flutter throws: native opens the nearest drawer: the shell drawer on a tab page; else the
  page's own `Scaffold.drawer` when it has one; else nothing. Listed as a known difference (a superset).
- D2 Server tab bar and server drawer repaint on any app-state change (Flutter repaints only when the shell
  rebuilds). Known difference, a superset.
- D3 Out-of-range or non-int `_tabIndex`: ignored on native.
- D4 The Flutter executor gains debug effects `switchTab {tabId}` and `openDrawer {}` (as `navigate` already has),
  so action fixtures can pin the two kinds in all three SDKs. Additive; no wire change.
- D5 Engine `Drawer.targets` gains `"ios"` (the user's decision 1: draw the drawer on iOS). Registry regenerated.
- D6 Whatever a session fixture shows Flutter doing for the corners in §3 is the contract. If Flutter throws or
  asserts in a corner, the corner is left out of the fixture and listed as a known difference.

## 3. Fixtures (Flutter first)

### Navigation sessions (B10.2, B10.3, B10.8)
Extend the navigation family with **sessions**: `schema/navigation-fixture.schema.json` gains an optional
`sessions: [{ name, steps: [{ op, …, expected }] }]` beside `cases`. Ops:
`go {location}` · `push {location}` · `back` · `tapTab {index}` · `switchTab {tabId}` · `setAppState {key, value}`.
`expected` after each step: `location` (the visible location), `tabIndex` (null over a non-tab route with no shell),
`appState` (subset; carries `_tabIndex`), `pageRequests` (the page paths requested by that step, in order; `[]` when
nothing is fetched). The session starts at the config's `initialRoute`; the first step's `pageRequests` includes the
boot fetch.
New files (numbers continue the family): `12_tab_sessions.json` (switch away and back restores the stack and fetches
nothing; reselect pops to root; lazy first visit), `13_tab_index_state.json` (`_tabIndex` follows taps, `go`,
`switchTab`; setting it switches and restores; same value and non-int do nothing), `14_switch_tab.json`
(`switchTab` lands on the root, drops routes over the shell, unknown id no-op), plus corners Flutter can show:
`push` of a non-tab route over the shell then `tapTab`/`back`. Count pin 11 → 14.
`sdk/test/conformance/navigation_fixtures_test.dart` runs sessions on the real `OrcaApp` with a recording client:
`tapTab` taps the default bar, `switchTab` and `setAppState` run through the real action executor / state manager.

### Action fixtures (B10.3, B10.5)
`schema/fixtures/actions/30_switch_tab.json`, `31_open_drawer.json` (Phase B owns 30–44): effects
`switchTab {tabId}` and `openDrawer {}`. Count pin 15 → 17 (Swift `ActionFixtureTests`, `ModelRoundTripTests`;
Kotlin `ActionFixtureTest`, `ModelRoundTripTest`, `FixturePathsTest`). Both native tests that use `openDrawer` as
their "unimplemented kind" example move to a kind that stays unsupported.

### Render fixtures (wire pin for the three widgets)
`schema/fixtures/render/60_bottom_navigation_bar.json` (items, `currentIndex` bound to page state, `onChange`),
`61_scaffold_drawers.json` (Scaffold `drawer`, `endDrawer`, `bottomNavigationBar`; `Drawer` props). Phase B owns
60–79. Count pin 39 → 41. No new wire shape: the widgets and actions exist in the engine and schema already.

## 4. Native design

### Capabilities
`capabilities.json` (both): widgets + `BottomNavigationBar`, `BottomNavItem`, `Drawer` (28 → 31); actionKinds +
`switchTab`, `openDrawer` (15 → 17). `Generated.swift` / `Generated.kt` regenerated by
`schema/gen-native-capabilities.ts`. Tests that pin 28 / 15 and "Drawer is not an iOS widget" are updated to the new
truth (a changed pin, not a lowered bar).

### Cores (pure, fixture-driven): `Navigation/TabShell`
`TabShell(table)` holds: one stack per tab (nil until first visited), `currentTab`, the routes pushed over the
shell, and the last `_tabIndex` it wrote. Operations mirror the session ops: `go`, `push`, `pop`, `selectTab(index)`
(restore, or pop to root on reselect), `switchTab(tabId)`, `appStateChanged(_tabIndex)`. Each returns what changed:
the visible location, the tab index, the `_tabIndex` write to make, and which stack entries are new (so the UI layer
knows which pages to load). Session fixtures run against it in both cores with a fake "page requested" log, and a
mirrored `unpinnedCornersAgree…` test covers what the fixtures leave out, as in step 9.
Action executors: `switchTab` emits effect `switchTab {tabId}`; `openDrawer` emits `openDrawer {}`.

### UI layers
`OrcaRouter` (both) owns a `TabShell` when the config has tabs. `root` / `stack` keep meaning "the visible stack" so
step 9 behaviour and tests hold. New public surface (same names in both SDKs): `tabs`, `currentTab`,
`selectTab(_:)`, `switchTab(_:)`, `isDrawerOpen`, `openDrawer()`, `closeDrawer()`. `perform` handles effects
`switchTab` and `openDrawer`. `_tabIndex` is written into the shared app state on boot (before the first page
request) and on every tab change; an app-state commit of `_tabIndex` from any page switches the tab.
Pages are loaded once per stack entry and kept while the entry is in any tab's stack (loaders are not dropped on a
tab switch).

Swift (`OrcaApp.swift`, new `Navigation/TabShellView.swift`, `Widgets/DrawerPanel.swift`):
- `TabView(selection:)` with one `NavigationStack` per tab; visited tabs stay mounted (state, text and scroll kept).
  A reselect (binding set with the current value) pops to the root.
- Routes outside the tabs are pushed on the current tab's `NavigationStack` with the tab bar hidden for that
  destination, so they cover the bar and keep the system back swipe. `NavigationStack` is not replaced.
- `tabBarComponents`: the system bar is hidden and the server tree is drawn in a bottom safe-area inset.
- Drawer: a custom side panel hosted at the app root (scrim, slide in from the leading edge, drag to close, tap on
  the scrim closes; trailing edge for `endDrawer`), `ios` target. Shell drawer: default list from `drawerItems` or
  the server tree. With a shell drawer, tab pages get a top bar: tab label and a menu button.
- Page `Scaffold` `drawer` / `endDrawer`: the same panel, opened by an edge drag (and by `openDrawer`, D1).

Kotlin (`OrcaApp.kt`, new `navigation/TabShellScreen.kt`, `widgets/Structure.kt`):
- Material 3 `NavigationBar`; per-tab stacks; visited tabs keep their composition state (text, scroll) across a
  switch. `BackHandler` pops inside the tab and is disabled at a tab root, so back leaves the app.
- Routes outside the tabs are drawn over the whole shell (bar covered) with the step 9 `TopAppBar`.
- `ModalNavigationDrawer` for the shell drawer (default list or server tree; top bar with tab label and menu button).
- Page `Scaffold` `drawer` / `endDrawer`: `ModalNavigationDrawer` around the page Scaffold; the end drawer on the
  trailing edge.

Both: `BottomNavigationBar` / `BottomNavItem` / `Drawer` widgets per §1.10 (tap writes the bound key, then
`onChange` with `event.value`); server shell trees render through the normal renderer against app state with page id
`__shell__`, unknown widgets degrade as on a page; their actions reach the router.

### Engine and demo
- `engine/src/components/structure/drawer.ts`: targets + `"ios"`; `bun run schema/gen-widget-registry.ts`,
  `gen-sdk-capabilities.ts`, `gen-native-capabilities.ts`. (`tools/gen-go-registry.ts` writes into `cloud/`, outside
  this repo: not run here; said in the PR.)
- `examples/server/tabs.ts`: app `tabs`: three tabs (Feed with a long list and a child page, Search with a
  TextField, Profile), `drawerItems`, buttons for `SwitchTab`, `OpenDrawer` and `SetState _tabIndex`, a page with its
  own `Scaffold` drawer, endDrawer and `BottomNavigationBar`. App `tabs-server`: the same with a server `tabBar` and
  `drawer`. Engine test in `engine/test/demo-server.test.ts`. Example READMEs lose "tabs are not drawn yet".

## 5. Cases (stage 07 stand-in)

| Id | Level | Given / When / Then |
|---|---|---|
| B10.1-S / -K | ui | a config with three tabs → a tab bar with three items; selecting each shows that tab's initial route |
| B10.2-F | fixture (Flutter) | `12_tab_sessions.json` passes on the real `OrcaApp` |
| B10.2-CS / -CK | fixture (cores) | the same sessions pass on `TabShell` |
| B10.2-S / -K | unit (router) | push in tab 0, switch to 1 and back → tab 0 shows its pushed page; reselect pops to root |
| B10.3-F / -CS / -CK | fixture | `13_tab_index_state.json`, `14_switch_tab.json` pass in Flutter and both cores |
| B10.3-A | fixture (actions) | `30_switch_tab.json` passes in Flutter, Swift, Kotlin |
| B10.3-S / -K | unit (router) | `switchTab` changes the tab; `_tabIndex` follows; a page `SetState app _tabIndex` switches |
| B10.4-S / -K | ui | `tabBarComponents` draws in place of the default bar; its `SwitchTab` button switches; it repaints on `_tabIndex` |
| B10.5-A | fixture (actions) | `31_open_drawer.json` passes in Flutter, Swift, Kotlin |
| B10.5-S / -K | ui | the drawer from `drawerItems` / `drawerComponents`; the menu button and `openDrawer` open it; an item tap closes it and pushes; a swipe / scrim tap closes it; page `Scaffold` `drawer` and `endDrawer` open and close |
| B10.6-R | fixture (render) | `60_…`, `61_…` round-trip in Flutter and both cores |
| B10.6-S / -K | ui | `BottomNavigationBar` with `BottomNavItem` children in the Scaffold slot; a tap writes the bound key and fires `onChange` with the index |
| B10.7-K | unit + hand | Android back pops inside the tab; at the root back is not intercepted |
| B10.7-S | hand | the iOS back swipe pops inside a tab |
| B10.8-S / -K | unit | switching tabs and opening / closing the drawer adds no page request and keeps the page model, a typed text and the scroll offset |
| B10.8-H | hand | the same on the simulator and the emulator with the `tabs` demo |
| B10.C-S / -K | unit | capabilities: 31 widgets, 17 action kinds, Drawer on iOS; generated files in step |
| B10.D | unit (engine) | the `tabs` and `tabs-server` demos serve `/config` and their pages |

## 6. Recorded on Flutter by group 1 (the session fixtures are the contract)

Files `schema/fixtures/navigation/12_tab_sessions.json`, `13_tab_index_state.json`, `14_switch_tab.json`; format in
`schema/navigation-fixture.schema.json` and the README's "Sessions" section. Session files carry no `cases`.
- a. Reselect pops the tab to its root and fetches nothing. `switchTab` to a visited tab lands on its root, no fetch.
- b. `go` to a route outside the tabs destroys the shell: `tabIndex` null, `_tabIndex` keeps its last value; after
  it every tab starts at its root again and its page is fetched again.
- c. A route outside the tabs PUSHED over the shell keeps `tabIndex` and the tab stacks. `go`, `switchTab` (also to
  the current tab) and a `_tabIndex` write of another index drop it; a write of the current index leaves it.
- d. `initialAppState._tabIndex` is overwritten at boot with the index of the initial route's tab.
- e. A non-int `_tabIndex` write moves nothing and stays in app state until the next tab change overwrites it.
- f. `push` of another tab's location stays in the current tab (index unchanged, one more entry on its stack); a
  later visit of that tab fetches that path for itself.
- `tabIndex` is the shell's index even while a pushed route covers the bar; null only when no shell exists.
- Not pinned (Flutter throws or asserts): out-of-range `_tabIndex`; `back` at a tab root or the app root; a tab tap
  under a pushed route. Native: out-of-range ignored (D3); `back` at a root changes nothing in the core (the UI
  layer lets the system leave the app on Android).
