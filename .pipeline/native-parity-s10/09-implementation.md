# 09 · Implementation · native-parity-s10

## Front page

### In one breath
group 1 of 5 · tasks: 4 green, 0 blocked · cases: 5 of 36 green · bun test: 742 pass · flutter: +320
T1 Navigation sessions: 14 sessions in 3 files, recorded on the real Flutter app.
T2 Action fixtures 30/31: Flutter now emits `switchTab` and `openDrawer` debug effects.
T3 Render fixtures 60/61 and the README's Sessions section.
T4 Engine: Drawer carries the `ios` target; both registries regenerated.
Native suites are red on the count pins by design until group 2.

### New for you
nothing new

### Trade-offs
2 auto-decided: `push` of another tab's route stays in the current tab, as Flutter does ·
fixture 61 carries no bottom bar slot (60 pins it).

### Questions for you
1. Next: group 2 (executors and pure tab cores, Swift and Kotlin)? (default: go)

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

### Test run
group 1: `bun test` 742 pass 0 fail · `flutter test` +320 all passed · `flutter analyze` no issues.
Swift and Kotlin not run: red by design on the count pins (render 39, actions 15, navigation 11), the two new action
kinds and "Drawer is not an iOS widget"; group 2 turns them green.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- `tools/gen-go-registry.ts` (writes into `cloud/`) was not run; say so in the PR.
- `engine/CHANGELOG.md:16` (a past release entry) still lists Drawer among the widgets without ios.
- README "Running it" does not yet say how the native runners treat the session files (group 2 adds them).
