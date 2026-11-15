# native-parity-s2 · design in force (plan step 2, written at stage 08; 05-07 skipped)

Repo: /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/native-parity-phase-a-35cc97 (paths below from there),
branch feat/native-parity-s2 stacked on feat/native-parity-s1 (PR #33). Flutter (`sdk/`) is the reference. Inventory with every
file:line: .pipeline/native-parity-s2/inventory.md. Swift deploys to iOS 16 / macOS 13; Kotlin minSdk 24.

## Cases (phase-a-tests.md rows, after corrections)
- A2.1 onInit runs once when a node is first built and not again when it redraws. fixture + unit
- A2.2 (corrected) onVisible runs once when the node is first built, as Flutter's (lifecycle_wrapper.dart:40-45;
  engine doc action.ts:285-293 "CURRENT BEHAVIOR: fires once on mount"); not again on a redraw. Viewport-based
  visibility is a follow-up for all three SDKs. unit + hand
- A2.3 onBackground and onForeground (and the onApp aliases) run when the app leaves and returns. unit + hand
- A2.4 onScrollBegin, onScrolling and onScrollEnd run with offset and extent readable through the event value.
  fixture + ui
- A2.5 An action wrapped in once runs one time per widget and trigger; a second tap does nothing. fixture
- A2.6 always runs every time. debugLog emits an effect carrying its message. fixture (Flutter gains the effect:
  additive `_emit('debugLog', …)`, so the row holds on all three SDKs.)

## Decisions
D1 ActionSource {widgetId, trigger} in both cores, as Flutter's (action_executor.dart:32-38): executor
   `execute(action, eventData:, source:)` / executeAll; the current source is inherited by nested runs (sequential,
   conditional, lifecycle, once/always), restored after (as eventData is today). OrcaPageModel.fire passes
   (node.id, trigger). Swift and Kotlin `textChanged`/edit paths pass (node.id, "onChange").
D2 once: per executor (= per page model) set of fired keys `widgetId::trigger`; with a source skip if fired, else
   record, run inner; without a source run every time. Flutter's known limit kept (two Once under one widget and
   trigger share a key) and documented. always runs inner. Keys live as long as the page model (Flutter resets them
   on rebuild of OrcaPage; native page models live per route: same observable behaviour for a tap).
D3 debugLog: never throws; level default "debug", tag default "orca"; message resolved as a string (Values and
   templates); data resolved per entry ("<unresolvable>" on failure); emits effect
   `{type:"debugLog", level, tag, message?, data?}` (no timestamp, no state/event/stack: deterministic; the include*
   flags only add to the host log line). Host adapters print it (os.Logger / android.util.Log) and pass it on to
   the effect handler. Flutter: `_emit('debugLog', {level, tag, message?, data?})` before its developer.log.
D4 `implements` recurses into once/always (both cores); the engine capability filter recurses into once/always's
   inner action (capability-filter.ts walkSingleAction), so an unadvertised kind inside Once is caught.
D5 Lifecycle on any node (Flutter component_renderer.dart:230-255): a node whose actions hold onInit, onVisible,
   onAppBackground|onBackground, onAppForeground|onForeground gets a wrapper (Swift: in WatchedNode around
   WidgetView, only when one of these triggers is present, so plain nodes keep their tree; Kotlin: in NodeView,
   same rule). onInit and onVisible fire once per mount after the first frame (Swift `.onAppear` guarded by
   @State, or `.task(id: node.id)`; Kotlin LaunchedEffect(node.id)). onApp* wins when both are set.
D6 App lifecycle: paused → onBackground, resumed → onForeground; inactive/hidden ignored; no initial
   onForeground (Flutter adds its observer after resume). Swift `scenePhase` (.background / .active, only after a
   .background); Kotlin LifecycleEventEffect(ON_STOP / ON_START) or a LifecycleEventObserver on
   LocalLifecycleOwner (check lifecycle-runtime-compose is on the compile classpath; any new artifact = ask).
   Flutter `paused` ≈ Android ON_STOP, iOS scenePhase .background.
D7 Scroll triggers on SingleChildScrollView (the only native scrollable today; step 5 reuses the observer for
   ListView/GridView/PageView): payload {offset, maxExtent, minExtent (0), viewportDimension, atStart, atEnd} and
   + delta on onScrolling (BH:32-73). Begin on drag start, scrolling per offset change, end when it settles.
   Swift (iOS 16): offset via a GeometryReader preference in a named coordinate space (iOS 18
   onScrollGeometryChange / onScrollPhaseChange behind #available where it is simpler); begin/end from a
   simultaneous DragGesture + settle detection, documented. Kotlin: ScrollState (value, maxValue, viewportSize,
   isScrollInProgress) via snapshotFlow. No throttling (Flutter has none).
D8 Action fixtures: new optional `steps: [{action, source?, event?}]` beside `actions` (oneOf), so once/always
   can be checked per widget and trigger; three runners pass source and per-step event; Effect enum gains
   `debugLog`. Fixtures 16_once_per_widget_trigger, 17_always_and_debugLog, 18_onInit_once (source onInit run
   twice → once), 19_scroll_event_values (event Value reads offset/maxExtent/atEnd). Native counts 15 → 19.
D9 Capabilities: actionKinds gain once, always, debugLog in both capabilities.json; gen-native-capabilities.
   Triggers have no capability (nothing to add).
D10 Demo: parity-a page `lifecycle`: onInit sets a counter, onVisible logs, onBackground/onForeground write
   state, a SingleChildScrollView shows offset/atEnd live, a once button and an always button.

## Gaps to close (from the inventory)
- Executors ignore once/always/debugLog (Swift kinds ActionExecutor.swift:23-27, :77; Kotlin :282-286, :86).
- No source in either executor API; no once-key set.
- No lifecycle or scroll trigger fires natively.
- Flutter: no debugLog effect; fixture format has no source/per-step event.
- Engine filter misses inner actions of once/always.
