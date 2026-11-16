# 09 · Implementation · native-parity-s13

## Front page

### In one breath
group 5 of 5 · tasks: 9 green, 0 blocked · cases: all placed green · all suites green
T1 to T3: the reorderable list on the engine and both native SDKs.
T4: the SubPage contract as 72 shared cases, with a pure Dart core. T5, T6: the same core in
Swift and Kotlin. T7: the Flutter SDK follows the contract. T8, T9: SubPage and updateSubPage
drawn on iOS and Android. The sliver widgets are not built: they wait for Phase A step 5.

### New for you
nothing new

### Trade-offs
1 your call, taken: "Yes, fix Flutter too" (the SubPage contract; design brief Part 2).
3 auto-decided: SubPage keys may not hold `:` or `#` · a sub-page follows its node, not its
view · joined pages take the full width.

### Questions for you
1. Approve the stage? Device hand-checks are recorded in stage 10. (default: go)
2. Sliver widgets (B13.1, B13.2) wait for Phase A step 5 on main. (default: a later PR)

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

### Group 3

#### T4 · SubPage fixture family, schema, README; pure Dart core and runner
Files: schema/subpage-fixture.schema.json · schema/fixtures/subpage/01..12 + README · sdk sub_page_core.dart ·
sdk/test/conformance/subpage_fixtures_test.dart · actions/35_update_sub_page_unknown_id.json
Cases: B13.4-F, B13.5-F → green, 72 cases in four kinds (merge, actions, request, sequence).
Review fit: two rules had no case and several edges were unpinned; fixed (52 → 72 cases; the engine
refuses a SubPage key with `:` or `#`; SubPage exported from the barrel) · Review quality: pass

### Group 4

#### T5 · Swift core · T6 · Kotlin core
Files: sdk-swift Sources/OrcaGatewayCore/State/SubPage.swift + SubPageFixtureTests · sdk-kotlin
core/.../subpage/SubPage.kt + SubPageFixtureTest
Cases: B13.4, B13.5 (core) → green on both: 12 files, 72 cases, counts pinned, none skipped.
Review fit: pass (the fixtures are the review) · Review quality: pass

#### T7 · Flutter follows the contract; widget tests; `subpage` demo app
Files: sdk sub_page_widget.dart, component_store.dart, elm_store.dart, action_executor.dart, orca_page.dart,
animation_registry.dart · sdk/test/sub_page_widget_test.dart · examples/server/subpage.ts · engine barrel
Cases: C-flutter, C-demo2 → green. 10 of the first 15 widget tests failed on the old code.
Review fit: a replaced page reused the old page's widget state; nodes added inside leaked; a host
refetch lost sub-page state; fixed. Then: unmount followed the widget, not the node; fixed · quality: pass

### Group 5

#### T8 · Swift UI: SubPage, updateSubPage, scoped server actions, capabilities (51 widgets, 23 kinds)
Cases: B13.4-S, B13.5-S → green. Review fit: missing race tests, added · Review quality: nodes left only
by listed id, no fresh views after replace, joined pages not full width; fixed. Then: unmount followed
the view, not the node (a list drop reset the sub-page); the slot now lives in the model; fixed

#### T9 · Kotlin UI: the same
Cases: B13.4-K, B13.5-K → green. Review fit: nodes left only by listed id, no fresh UI state after
replace, joined pages not full width; fixed · Review quality: a test exemption for updateSubPage,
removed with action fixture 35; an unused public function, removed; second pass: pass

### Test run
engine 773 · Flutter +476, analyze clean · Swift macOS: 0 failures, 0 warnings; simulator package tests TEST SUCCEEDED · Kotlin core 469, sdk 485, lint clean · both example builds succeed · generators leave no diff.

### Blocked
B13.1, B13.2 (sliver widgets): Phase A step 5 (ListView, GridView) is not on main.

### Not done
none of the planned tasks

### For ship (stage 10) to know
Follow-ups, not in this slice: the executor's action source is one shared variable on all three SDKs, so
a second serverAction in a chain inside a sub-page can post the wrong state view · Flutter: updateSubPage
aimed at a SubPage scrolled out of a lazy list does nothing · two updateSubPage in flight resolve by
arrival · engine: `collectWatches` skips the transform inside `map`; `ListView.separator` is not encoded
as a slot; action.schema.json names addComponent's field `node` while the server sends `components` ·
plugin actions' literal state keys are not rewritten inside a sub-page (documented).
