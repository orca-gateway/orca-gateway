# Design brief · native-parity-s13 (sliver scrolling, reorderable lists, sub-pages)

Inventory of the engine and Flutter behaviour: session scratchpad `s13/inventory.md` (2026-11-16).

## Part 1 · ReorderableListView (built first; depends on nothing)

R1. Engine: `ReorderableListView` declares `static triggers = ["onReorder", "onScrollBegin", "onScrolling",
    "onScrollEnd"]`. Only Flutter's builder knew these names. Additive; registry and manifest regenerated.
R2. Event: `onReorder` fires with event data `{oldIndex, newIndex}`. `newIndex` is Flutter's raw value: the
    insertion index before the dragged item is removed (item 0 dropped at the end of 3 gives 3; below item 1
    gives 2). A drop that leaves the item where it was fires nothing, as Flutter.
R3. Core, both twins: `ReorderDrop.newIndex(from:, slot:)` style pure helper that turns a drop slot into the
    raw value and says when nothing moved. Unit tested with the same table on both.
R4. Order is never changed locally. After the drop the list draws the children the page has; the action
    (state or a component mutation) changes the order. Same as Flutter.
R5. Swift: `List` + `ForEach.onMove` when vertical. Horizontal draws a scrolling row with no drag (limit,
    documented). `padding` applies as content insets.
R6. Kotlin: `LazyColumn` / `LazyRow` with long-press drag and item placement animation.
R7. Scroll triggers fire as on SingleChildScrollView (Phase A step 2) where the platform view allows it.
R8. Fixtures: render `68_reorderable_list_view.json` (wire shape with the triggers), action
    `34_reorder_event.json` (event `{oldIndex, newIndex}` read by `V.event` into state). Flutter gets a widget
    test for the builder, since it had none.
R9. Demo: `reorder` app in examples/server: a list whose order lives in page state, `onReorder` moves it.

## Part 2 · SubPage and updateSubPage (waiting on the user's call, asked 2026-11-16)

Flutter's SubPage is half working (params never sent, slot ids not prefixed, state seeded under a prefix
that nothing reads, updateSubPage to another page snaps back, join draws one tree). Recommended: define the
contract as rows B13.4 and B13.5 say, pin it with a fixture family, fix Flutter in the same PR.

## Part 3 · CustomScrollView and the four sliver widgets

Wait for Phase A step 5 (ListView, GridView) on main, per the plan.
