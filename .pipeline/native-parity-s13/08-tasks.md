# 08 · Tasks · native-parity-s13

## Front page

### In one breath
tasks: 3 in 2 groups · widest group: 2 · cases: 4 of 4 placed
This plan covers the reorderable list only. Group 1: the engine triggers, fixtures, a Flutter
test and the demo app. Group 2: the Swift and Kotlin twins, side by side.
Sub-pages wait on your call; the sliver widgets wait for Phase A step 5 on main.
Their tasks are added to this plan when each is unblocked.

### New for you
nothing new

### Trade-offs
2 auto-decided: `onReorder` and the scroll triggers are added to the engine widget's trigger
list (only Flutter's builder knew them) · a horizontal list on iOS scrolls but does not drag.

### Questions for you
1. Commands as found (bun test, flutter test, swift test + simulator, gradlew build)? (default: yes)
2. Commits by the plugin: per task? (default: per task)
3. One gate per group? (default: all groups under one card)
4. SubPage contract: asked through the parent session. (default: wait)

## Appendix

### Groups
| G | Task | Title | Cases | Depends on |
|---|---|---|---|---|
| 1 | T1 | Engine triggers on ReorderableListView, registry regenerated, render fixture 68, action fixture 34, Flutter builder test, `reorder` demo app | B13.3-F, C-demo | — |
| 2 | T2 | Swift: core ReorderDrop, ReorderableListView in the UI layer, capabilities, tests, README | B13.3-S | T1 |
| 2 | T3 | Kotlin: core ReorderDrop, ReorderableListView in the UI layer, capabilities, tests, README | B13.3-K | T1 |

### Order, and why each boundary
1 → 2: the twins run the fixtures and read the triggers T1 adds.

### Seams
capabilities.json + Generated.*: T2 and T3 each touch only their own SDK's. Fixture count pins: T2, T3.

### Not planned
B13.4, B13.5 (SubPage, updateSubPage): waiting on the user's call on the contract.
B13.1, B13.2 (sliver widgets): waiting for Phase A step 5 (ListView, GridView) on main.

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` and the package tests
on the iOS simulator · `cd sdk-kotlin && ./gradlew build` · lint: inside gradlew build, `flutter analyze`
baseline: engine 754 · Flutter +356 · Swift 0 failures · Kotlin core 419, sdk 381, 2026-11-16
commits: per task · gate: all (standing rule, 2026-11-16)
