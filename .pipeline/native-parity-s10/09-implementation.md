# 09 · Implementation · native-parity-s10

## Front page

### In one breath
group 3 of 5 · tasks: 12 green, 0 blocked · cases: 19 of 36 green · all four suites green
T9 / T10 routers own the tab shell: per-tab stacks, `_tabIndex` both ways, drawer state.
T11 / T12 widgets: BottomNavigationBar, BottomNavItem, Drawer; 31 widgets advertised on both.
A side-by-side review of the two routers found five differences; all aligned and pinned.
engine 742 · Flutter +321 · Swift core 252, UI 97 · Kotlin core 249, sdk 162.

### New for you
nothing new

### Trade-offs
3 auto-decided: the bar stops at the first missing item slot, as Flutter (my brief said skip) ·
Android keeps the Material 3 selection pill · a host write to `stack` that adds routes is
pushed through the shell on both SDKs (step 9 allowed it).

### Questions for you
1. Next: group 4 (the tab shells in OrcaApp, server tab bar, demo apps)? (default: go)

## Appendix

### Group 1

#### T1 · Navigation sessions, Flutter as oracle
Files: schema/navigation-fixture.schema.json · schema/fixtures/navigation/12_tab_sessions.json · 13_tab_index_state.json ·
14_switch_tab.json · sdk/test/conformance/navigation_fixtures_test.dart
Cases: B10.2-F, B10.3-F → green (file: 1 shape test + 56 old cases + 14 sessions; red first on placeholders)
Changed: schema admits `sessions` (name, boot.expected, steps per op, closed key sets); the test runs each session on
the real `OrcaApp`: tapTab taps the real bar, switchTab through `ActionExecutor.execute`, setAppState through
`StateManager`. One old line changed: the case loop tolerates a file without `cases`.
Recorded behaviour: design-brief.md section 6 (a to f). Could not pin: out-of-range `_tabIndex` (go_router asserts),
`back` at a root (pop throws), a tab tap under a pushed route.
Decisions: tabIndex read from the mounted shell even when covered · session files carry no `cases` · (f) kept as contract
Review fit: pass
Review quality: pass

#### T2 · Action fixtures 30/31, Flutter debug effects
Files: schema/fixtures/actions/30_switch_tab.json · 31_open_drawer.json · sdk/lib/src/state/action_executor.dart ·
schema/action-fixture.schema.json (added by the rework)
Cases: B10.3-A/F, B10.5-A/F → green (action fixtures +17, was +15; the test file lists the directory, unchanged)
Changed: `switchTab` emits `switchTab {tabId}` after the missing-id return and before the context check; `openDrawer`
emits before the context check; behaviour with a context unchanged. Each fixture: the action alone, then inside a
sequential between a setState and a toast.
Decisions: no tabId, no effect · an unknown id still emits (as navigate)
Review fit: the effect enum of action-fixture.schema.json lacked the two types, fixed
Review quality: pass

#### T3 · Render fixtures 60/61, sessions README
Files: schema/fixtures/render/60_bottom_navigation_bar.json · 61_scaffold_drawers.json · schema/fixtures/navigation/README.md
Cases: B10.6-R/F → green (engine conformance 39 → 41; Flutter render_resolved 22 → 23)
Changed: 60 = Scaffold slot → BottomNavigationBar, item_0..2, currentIndex on page state `tab`, onChange with
event.value, resolved; 61 = Scaffold appBar, body, drawer, endDrawer with Drawer props. Built with the real encoder.
Decisions: 61 has no bottomNavigationBar slot (60 pins it), accepted
Review fit: pass
Review quality: pass

#### T4 · Engine: Drawer gains the ios target
Files: engine/src/components/structure/drawer.ts · engine/src/core/widget-registry-gen.ts · schema/widget-registry.json ·
engine/test/widget-targets.test.ts · engine/test/target-check.test.ts
Cases: B10.C-S (engine half) → green (two new B10.C-S tests; red first)
Changed: targets + "ios"; registries regenerated (only Drawer differs); tests that used Drawer as the ios-less example
use FloatingActionButton with the same assertions (diff checked). The capability generators change nothing.
Review fit: pass
Review quality: pass

### Group 2

#### T5 · Swift executor: switchTab, openDrawer, 17 kinds
Files: sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift · sdk-swift/capabilities.json · Generated.swift ·
Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · ActionFixtureTests.swift
Cases: B10.3-A/S, B10.5-A/S → green (fixtures 30, 31 pass; red first, 9 failures)
Changed: `kinds` + 2; both emit through `emit` like navigate; actionKinds 15 → 17, Generated regenerated; pins moved
15 → 17 (two tests); "Drawer is not an iOS widget" replaced by "Drawer has the ios target", the six ios-less widgets
still never advertised; the unimplemented-kind example is now `animateForward`; new emit-then-perform test.
Decisions: switchTab always emits (a missing id fails at decode)
Review fit: pass
Review quality: a Drawer assertion duplicated the list equality, fixed

#### T6 · Kotlin executor: switchTab, openDrawer, 17 kinds
Files: sdk-kotlin/core/.../state/ActionExecutor.kt · sdk-kotlin/capabilities.json · Generated.kt ·
core/src/test/.../capabilities/CapabilitiesTest.kt · state/ActionFixtureTest.kt
Cases: B10.3-A/K, B10.5-A/K → green (red first, 4 of 14)
Changed: as T5; Swift and Kotlin kind lists equal; two new tests `b10_3_A_…`, `b10_5_A_…`.
Review fit: pass
Review quality: pass

#### T7 · Swift core: TabShell passes the sessions
Files: sdk-swift/Sources/OrcaGatewayCore/Navigation/TabShell.swift (new) · Tests/OrcaGatewayCoreTests/NavigationFixtureTests.swift ·
ModelRoundTripTests.swift
Cases: B10.2-CS, B10.3-CS, B10.6-R/S → green (15 sessions, 87 steps; core 252)
Changed: `TabShellEntry`, `TabShellChange`, `TabShell` (go, push, pop, selectTab, switchTab, tabIndexChanged), pure;
session runner; `test_B10_2_tabSessions`, `test_B10_3_tabIndexStateAndSwitchTab`, corners 1-14 in
`test_unpinnedTabCornersAgreeWithKotlin`; pins moved: navigation 11 → 14, render 39 → 41, actions 15 → 17.
Reworks: aligned with Kotlin on the unpinned corners; then followed the new Flutter session (kept pages).
Review fit: pass (no input found where Swift and Kotlin differ)
Review quality: pass

#### T8 · Kotlin core: TabShell passes the sessions
Files: sdk-kotlin/core/.../navigation/TabShell.kt (new) · core/src/test/.../navigation/NavigationFixtureTest.kt ·
models/ModelRoundTripTest.kt · FixturePathsTest.kt
Cases: B10.2-CK, B10.3-CK, B10.6-R/K → green (15 sessions, 87 steps; core 249)
Changed: the twin of T7; `b10_2_tabSessions`, `b10_3_tabIndexStateAndSwitchTab`, `unpinnedTabCornersAgreeWithSwift`,
`b10_6_r_…RoundTrip`; the same pins moved.
Review fit: pass
Review quality: two dead branches left by the reworks, fixed

#### T1 (rework in group 2) · one more Flutter session
File: schema/fixtures/navigation/12_tab_sessions.json: "go inside a tab keeps the pages it still needs", 7 steps,
recorded: `go` to the tab root keeps the root page; a query-only change keeps the page and requests nothing.

### Group 3

#### T9 · Swift router: tabs, _tabIndex, drawer state
Files: sdk-swift/Sources/OrcaGateway/Navigation/OrcaRouter.swift · Tests/OrcaGatewayTests/RouterTests.swift
Cases: B10.2-S, B10.3-S → green (RouterTests 34: 13 new; no step 9 test edited, diff checked)
Changed: with a config the router owns a `TabShell`; one route per entry, stable id and loader; loaders dropped only
when the entry leaves every stack; `_tabIndex` at boot before the first request and on every tab change; a page or
host write of `_tabIndex` switches; `perform` handles `switchTab`, `openDrawer`.
Public: `tabs`, `hasShell`, `currentTab`, `tabStacks`, `overRoutes`, `selectTab`, `switchTab`, `setTabPath`,
`hasDrawer`, `isDrawerOpen`, `openDrawer`, `closeDrawer`, `pageDrawerRequest`.
Decisions: tab switches, reselect and `go` report replace · `openDrawer` in path mode asks the page
Review fit: a `stack` write adding routes was restored, not pushed (plus 3 alignments with Kotlin), fixed
Review quality: two maps where one does, fixed

#### T10 · Kotlin router: tabs, _tabIndex, drawer state
Files: sdk-kotlin/sdk/.../navigation/OrcaRouter.kt · sdk/src/test/.../navigation/RouterTest.kt
Cases: B10.2-K, B10.3-K → green (RouterTest 34: 10 new; 24 step 9 tests unedited)
Changed: the twin of T9; also `canGoBack` (false at a tab root) for the back handler; `OrcaRoute.location`,
`scaffoldTitle`, `isNotFound`, `transition` are Compose state with internal set (a binary change of `OrcaRoute`).
Review fit: pass; aligned with Swift: a kept route takes every field of its entry, fixed
Review quality: pass

#### T11 · Swift widgets: BottomNavigationBar, BottomNavItem, Drawer; 31
Files: sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · NodeView.swift · capabilities.json · Generated.swift ·
Tests/OrcaGatewayTests/StructureWidgetTests.swift (new)
Cases: B10.6-S, B10.C-S → green (10 tests)
Changed: `BottomNavBar` (items, currentIndex, select) and its views; a tap writes the bound key, then fires `onChange`
with the index (order asserted through store commits); `DrawerView` panel (304 wide by default); the switch draws
all 31 advertised widgets. `ScaffoldView` still ignores drawer slots (group 5).
Review fit: pass
Review quality: items skipped a missing slot where Flutter stops, fixed

#### T12 · Kotlin widgets: BottomNavigationBar, BottomNavItem, Drawer; 31
Files: sdk-kotlin/sdk/.../widgets/Structure.kt · WidgetBuilders.kt · capabilities.json · Generated.kt ·
core/src/test/.../capabilities/CapabilitiesTest.kt
Cases: B10.C-K → green (pin 28 → 31, renamed test, three names asserted)
Changed: M3 `NavigationBar` with tags `orca-bottom-nav-item-<i>`, helpers `bottomNavEntries`, `bottomNavIndex`,
`bottomNavTap`; `DrawerWidget` on `ModalDrawerSheet`; three registrations.
Review fit: pass; the same slot rule as Swift, fixed
Review quality: pass

### Test run
group 3: `swift test` core 252, UI 97, 0 failures, 0 warnings · `./gradlew build` successful, core 249, sdk 162,
0 failed · engine and Flutter unchanged since group 2 (742, +321). Generators leave no diff.
group 2: `bun test` 742 pass 0 fail · `flutter test` +321 all passed · `swift test` core 252, UI 74, 0 failures,
0 warnings · `./gradlew build` successful, core 249, sdk 152, 0 failed. Generators leave no diff.
group 1: `bun test` 742 · `flutter test` +320 · native red by design, green again in group 2.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- `tools/gen-go-registry.ts` (writes into `cloud/`) was not run; say so in the PR.
- `engine/CHANGELOG.md:16` (a past release entry) still lists Drawer among the widgets without ios.
- README "Running it" does not say that the native runners run the sessions on `TabShell`; the file-12 row and
  description do not mention the fifth session. Fix before the PR.
- The Swift and Kotlin corner tests pin the same corners with different scripts and ids (not literal mirrors).
- Known differences to list: the Android bar has the M3 selection pill; a host route pushed by a `stack` write keeps
  its own path if its location redirects; Kotlin closes loaders of dropped routes, Swift forgets them (as before).
- No Kotlin test yet for the bar's stop-at-gap rule or its tap (T17 writes `StructureTest.kt`).
- `hasShell` always equals `currentTab != nil` in both twins (could be computed).
