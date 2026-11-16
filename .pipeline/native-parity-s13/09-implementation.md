# 09 · Implementation · native-parity-s13

## Front page

### In one breath
group 2 of 2 so far · tasks: 3 green, 0 blocked · cases: 4 of 4 green · all suites green
T1 engine: ReorderableListView declares onReorder and the scroll triggers; fixtures, demo app.
T2 Swift: a List whose drop fires onReorder with Flutter's raw indices; the page keeps the order.
T3 Kotlin: a lazy list dragged by long press, the same event, the same rule.
Sub-pages and the sliver widgets are not built yet: each waits on something outside this slice.

### New for you
nothing new

### Trade-offs
2 auto-decided: `onReorder` joins the engine's trigger names · a horizontal list on iOS
scrolls but does not drag. 1 needs you: the SubPage contract, asked through the parent session.

### Questions for you
1. SubPage: define the contract and fix Flutter too, or leave Flutter as it is? (default: wait)
2. Sliver widgets wait for Phase A step 5 on main. (default: wait)

## Appendix

### Group 1

#### T1 · Engine triggers, fixtures render 68 and actions 34, Flutter builder test, `reorder` demo
Files: engine reorderable-list-view.ts, types/action.ts, registry (generated) · engine tests ·
schema/fixtures/render/68, actions/34 · sdk/test/reorderable_list_view_test.dart · examples/server/reorder.ts
Cases: B13.3-F, C-demo → green. The Flutter builder is untouched; its test found no bug.
Review fit: pass · Review quality: pass

### Group 2

#### T2 · Swift: core ReorderDrop, List with onMove, capabilities (37 widgets), README
Cases: B13.3-S → green. Plain long-press drag, no edit mode. Vertical scroll triggers need iOS 18.
Review fit: a test never dropped on screen; the hand-check then showed the List keeping its own
move after a drop. Fixed: the rows are laid out again in the page's order; the test drives the
hosted list and failed before the fix. Second pass: pass · Review quality: pass

#### T3 · Kotlin: core ReorderDrop, LazyColumn/LazyRow with long-press drag, capabilities, README
Cases: B13.3-K → green. Real gesture driven under Robolectric; edge auto-scroll; right-to-left row.
Review fit: pass · Review quality: a drag stayed stuck when the page changed the rows mid-hold,
fixed; then unreachable index checks left by that fix, removed; fixed

### Test run
engine 763 · Flutter +360, analyze clean · Swift macOS: 0 failures, 0 warnings; simulator package tests
TEST SUCCEEDED · Kotlin core 432, sdk 400, lint clean · both example builds succeed · generators leave no diff.

### Blocked
B13.4, B13.5 (SubPage, updateSubPage): the contract is the user's call (asked 2026-11-16).
B13.1, B13.2 (sliver widgets): Phase A step 5 (ListView, GridView) is not on main.

### Not done
none of the planned tasks

### For ship (stage 10) to know
Hand-check on both devices with the `reorder` app: row 0 dragged between rows 2 and 3 shows 0 → 3 and
Bread, Coffee, Apples, Dates, Eggs; on Android the last row dragged to the top shows 4 → 0.
