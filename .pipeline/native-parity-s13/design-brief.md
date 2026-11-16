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

## Part 2 · SubPage and updateSubPage

User's call, 2026-11-16: "Yes, fix Flutter too". The contract below is what rows B13.4 and B13.5 say;
it is pinned by a new fixture family that Flutter, Swift and Kotlin all pass, and the Flutter SDK is
changed to follow it. Facts about today's Flutter code: scratchpad `s13/inventory.md`, sections 3, 4, 7.

### Contract

S1. Prefix. A SubPage node with id K holds a list of mounted pages. Page 0 has prefix `K:`; the j-th
    page added by `join` (j from 1) has prefix `K#j:`. A nested SubPage composes by itself, since its
    own id is already prefixed (`outer:inner:`).
S2. Merge is one pure function: (prefix P, page response) gives (nodes, state seeds). It rewrites:
    a. each node `id` and each entry of `children`: P + id;
    b. slot props: a top-level string prop whose value is one of that node's original `children` ids;
    c. page-state references, anywhere inside `props` and `actions` (deep walk): a state Value with
       page scope gets key P + key; app-scoped references are left alone;
    d. `watches`: each entry that names a page-state key gets the prefix;
    e. page-state writes in actions (setState and every other action or prop that names a page-state
       key, nested sequences and conditions included): key P + key. The oracle task lists every such
       field from `schema/action.schema.json` and the widget registry in the fixture README;
    f. ids that address the sub-page's own nodes: `animationId` (prop and the two animate actions),
       `dialogId`, component mutation targets and parents, `updateSubPage.subPageId`, when they are
       literal strings: P + id. Hero tags, `type`, `kind` and everything else are left alone.
    Seeds: each page-scoped state definition gives `P + key = initial`. App-scoped definitions are
    ignored, as today.
S3. The merged nodes live in the host page's node store (so component mutations, openDialog and
    animations can reach them) and the seeds in the host page's state. Nothing in the host page can
    clash with them, since `:` and `#` prefixes are only made here.
S4. Fetch. The normal page route with the resolved `pageId` as the path; resolved `params` are sent as
    a query string (keys sorted, values as strings, percent-encoded). When: on mount, and again (as a
    replace) when the resolved `pageId` or `params` change. App state is posted as on any page fetch.
S5. Drawing. While the first fetch runs: the child if there is one, else a centred spinner. On error:
    the text `SubPage error: <message>`. Loaded: the root of each mounted page, in order, oldest
    first, one below the other; one mounted page draws exactly as its root.
S6. Actions fired from a node inside a sub-page (source id starts with a mounted prefix; the longest
    match wins): a serverAction posts, as `pageState`, only the keys under that prefix with the prefix
    removed; the actions the server returns are rewritten with the same prefix (S2 c to f, as actions)
    before they run. Client-side actions already carry prefixed keys from the merge.
S7. updateSubPage(subPageId, pageId, params, mode). Unknown id: nothing happens, no effect. The old
    content stays while the fetch runs; a fetch error leaves it and surfaces as any failed action does
    (lifecycle `onError`). `replace` (and any mode that is not `join`): the mounted pages' nodes and
    their state keys are removed, the new page becomes page 0. `join`: the new page is mounted after
    the current ones with the next `K#j:` prefix. The change sticks: no later rebuild puts the first
    page back.
S8. Unmount: when the SubPage node goes away its nodes are removed; its state keys are left.

### Fixture family `schema/fixtures/subpage/` (schema `schema/subpage-fixture.schema.json`)

One file per case, kinds: `merge` (prefix + response in, nodes + seeds out), `actions` (prefix +
actions in, rewritten actions out), `request` (pageId + resolved params in, path and query out; prefix +
page state in, posted view out), `sequence` (mount, then updateSubPage steps with stubbed responses;
after each step: drawn roots in order, node ids, page state). Each SDK has a pure core that the runner
drives; the UI layers only fetch and draw.

### Flutter changes (the oracle is fixed, not copied)

`sub_page_widget.dart` uses the pure functions, puts nodes in the parent ComponentStore, sends params,
drops the first-load guard that reverted updateSubPage, draws joined pages one below the other. The
executor applies S6. Widget tests cover what the fixtures cannot (fetch, loading, error, redraw).

## Part 3 · CustomScrollView and the four sliver widgets

Wait for Phase A step 5 (ListView, GridView) on main, per the plan.
