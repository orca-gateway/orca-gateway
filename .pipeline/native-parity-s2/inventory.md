# Step 2 inventory (lifecycle and triggers), checked 2026-11-15 against base 5c6b57e + step 1

## Wire
- Triggers on the node: `ComponentNode.actions` = map trigger → Action (schema/component-node.schema.json:39-43;
  engine/src/types/node.ts:18, widget.ts:227; ActionMap action.ts:330). Flutter also accepts an array per trigger
  (component_context.dart:113-114); native maps hold one Action per trigger.
- Trigger names (action.ts:304-328): onTap onLongPress onDoubleTap onChange onScrollBegin onScrolling onScrollEnd
  onRefresh onAction onVisible onInit onAppBackground onAppForeground onBackground onForeground onSuccess onError
  onComplete.
- onInit, onVisible, app triggers: ANY widget (action.ts:272-302), not in widgets' `triggers` lists.
  onBackground/onForeground alias onAppBackground/onAppForeground.
- Scroll triggers declared on SingleChildScrollView (single-child-scroll-view.ts:18), ListView (list-view.ts:20),
  GridView (grid-view.ts:21), CustomScrollView (custom-scroll-view.ts:15). Flutter also wraps PageView and
  ReorderableListView (layout_builders.dart:675,699). Native: only SingleChildScrollView exists today.
- DebugLog (action.ts:203-221): {type:"debugLog", level? debug|info|warn|error (default debug), message?
  string|Value, tag?, data? Value|Record, includeState?, includeEvent?, includeRequest?, includeStackTrace?}.
  Schema action.schema.json:616-654.
- Once/Always (action.ts:241-249): {type:"once"|"always", action}. Schema :655-686: once = at most once per
  (widget, trigger); without a widget source it fires every time.

## Flutter
- component_renderer.dart:230-255 wraps a node with onInit, onVisible, onAppBackground|onBackground,
  onAppForeground|onForeground in OrcaLifecycleWrapper (onApp* wins when both; the set name is the trigger passed).
- lifecycle_wrapper.dart: onInit in initState via addPostFrameCallback, guarded (:34-39) = once per mount.
  onVisible: SAME as onInit (:40-45) — NOT viewport based; action.ts:285-293 says "CURRENT BEHAVIOR: fires once on
  mount". App: WidgetsBindingObserver (:46-58): paused → onBackground, resumed → onForeground (:61-67);
  inactive, hidden, detached ignored. No initial onForeground (observer added after resumed).
- Scroll: wrapScrollNotifier BH:46-71 (no-op unless a scroll trigger is set). ScrollStart → onScrollBegin,
  ScrollUpdate → onScrolling (+ delta = scrollDelta ?? 0), ScrollEnd → onScrollEnd; returns false (bubbles).
  Payload _scrollEventData (:32-41): {offset: pixels, maxExtent: maxScrollExtent, minExtent: minScrollExtent,
  viewportDimension, atStart: atEdge && pixels<=min, atEnd: atEdge && pixels>=max} (+ delta). No throttling.
- ctx.fireAction(trigger, eventData:) (component_context.dart:108-119) → ActionSource(widgetId: node.id,
  trigger) → executor.execute(action, eventData:, source:). event Value {type:"event", key}: flat eventData[key],
  null when absent (value_resolver.dart:55,88-100).
- Executor (action_executor.dart): ActionSource {widgetId, trigger}, dedupeKey '$widgetId::$trigger' (:32-38);
  _currentSource (:128) and _firedOnceKeys (:133); nested executions inherit the source. once (:409-418): with a
  source, skip if fired, else record and run inner with current event; without a source run every time. Known:
  Sequential(Once(A), Once(B)) under one widget+trigger → B never runs (key has no wrapper id). always (:423-427)
  runs inner. debugLog (:442-537): never throws; level default debug, tag default "orca"; message via
  resolveString; data resolved per entry ('<unresolvable>' on failure); entry {level, tag, timestamp, message?,
  data?} (+ pageState/appState with includeState, event with includeEvent, stackTrace); writes developer.log +
  debugPrint; does NOT _emit an effect (_emit at :113-116).
- OrcaPage builds a new ActionExecutor in build()'s FutureBuilder (orca_page.dart:234,267): once-keys reset on
  rebuild. Flutter tests orca_gateway_test.dart:1799-1880 (onInit/onVisible after first frame).

## Native cores
- Models decode all 28 kinds: Swift Models/Action.swift:13-54 (.debugLog(DebugLog) :268-284, .once/.always
  (Wrapped {action}) :286-289); Kotlin models/Action.kt:120-187, 280-286.
- Executors ignore them: Swift State/ActionExecutor.swift `kinds` :23-27, early return :77; Kotlin
  state/ActionExecutor.kt :282-286, :86. `implements` does not recurse into once/always (Swift :62-70, Kotlin
  :289-295). ActionReducer: setState/actionGroup/showSnackbar/showToast only.
- Effects: Swift struct ActionEffect {type, payload} (.json) ElmStore.swift:54-70; Kotlin data class ActionEffect
  ElmStore.kt:61-63. emit → onEffect then perform (Swift :159-162, Kotlin :187-190); host adapters
  OrcaPageModel.perform (Swift :139, Kotlin :172).
- No source in executor API: Swift execute(_:eventData:)/executeAll (:49-59), eventData field :40 restored with
  defer; Kotlin execute(action, eventData)/executeAll (:61-74), eventData :55.
- UI: Swift OrcaPageModel.fire(_ trigger:, on node:, eventData:) -> Task? (:71-75) → run(_:eventData:) (:78-85);
  textChanged (:107-124) runs directly; appeared()/onFirstAppear page level (OrcaApp.swift:22). Kotlin
  OrcaPageModel.fire(trigger, on, eventData): Job? (:118-121) → suspend run(action, eventData) (:127-137);
  appeared() :149-153 (OrcaPageView.kt:46). ResolvedNode has id + actions (Swift PageRenderer.swift:75-87,
  Kotlin PageRenderer.kt:83-95).
- event Value supported in both resolvers (flat key of current eventData; Swift ValueResolver.swift:59,101-104;
  Kotlin ValueResolver.kt:64,102-106).

## Action fixtures
- schema/action-fixture.schema.json: {name, description, pageId, state{page,app}, event? (one payload for all
  actions :29-35), serverResponses?, actions[] (:55-61), expected{state, effects}}; additionalProperties false
  (:15, :68); Effect.type enum without debugLog (:105-115). Nothing validates fixtures against it.
- Runners: Flutter sdk/test/conformance/action_fixtures_test.dart:95-101 execute(action, eventData: event), no
  source, effects via onEffect (:92). Swift ActionFixtureTests.swift:13-33 (count 15 at :14, allSatisfy
  implements :17, execute :29). Kotlin core/.../state/ActionFixtureTest.kt:29-44 (count 15 :30, implements :33).
- Needed: per-step source {widgetId, trigger} and per-step event (new `steps: [{action, source?, event?}]`
  alternative to `actions`, or parallel); "debugLog" effect type with a deterministic payload (no timestamp);
  three runners pass source; native counts 15 → N; native implements recurses into once/always.

## Native UI today
- No lifecycle or scroll trigger fires in either SDK.
- Reuse: Swift Widgets/Video.swift:55-85 VisibilityTracked (GeometryReader .global ∩ screen bounds, scenePhase;
  UIKit-only); Kotlin widgets/Video.kt:75-77 onGloballyPositioned + boundsInWindow().
- Swift ScrollNodeView (Layout.swift) plain ScrollView; iOS 16 target → no onScrollGeometryChange/
  onScrollPhaseChange (iOS 18) without #available; needs GeometryReader preference in a named space or
  UIScrollView introspection. Kotlin ScrollWidget (Layout.kt) rememberScrollState (value, maxValue,
  viewportSize, isScrollInProgress).
- Per-node wrapper: Swift WatchedNode.body (NodeView.swift:36-42) around WidgetView; Kotlin NodeView
  (NodeView.kt:26-36) around WidgetView.
- Kotlin deps: activity-compose, navigation-compose bring androidx.lifecycle transitively; check
  lifecycle-runtime-compose (LifecycleEventEffect) on the compile classpath.

## Capabilities
- actionKinds from sdk-swift/capabilities.json, sdk-kotlin/capabilities.json (15 each), via
  schema/gen-native-capabilities.ts (:74-83, :113-117) → Generated.swift:63 / Generated.kt. Triggers have no
  capability (CapabilityVector context.ts:13-21).
- engine capability-filter.ts: walkActionsForFeatures (:330-338) walks map values only (trigger names never
  checked); walkSingleAction (:340-382) recurses into actionGroup, conditionalAction, lifecycle, NOT into
  once/always's inner action (only Value kinds :376-380) → an unadvertised kind inside Once is missed once `once`
  is advertised. Default policy graceful drops the node (fallback-policy.ts:50; capability-filter.ts:141-160).
  Today a node carrying once/always/debugLog is dropped for native clients.

## Row corrections to make at step 2 (Flutter differs)
- A2.2: Flutter's onVisible fires once on mount (lifecycle_wrapper.dart:40-45; engine doc action.ts:285-293
  "CURRENT BEHAVIOR: fires once on mount"), not on scrolling into the viewport → correct the row to Flutter;
  viewport visibility is a follow-up for all three SDKs.
- A2.6: Flutter's debugLog emits no effect → either add `_emit('debugLog', {level, tag, message, data?})` to
  Flutter (additive) so the row holds on all three, or correct the row. Default: add the effect in all three
  (the native design hands side effects to the host as effects; plan step 19 wants a debugLog sink).
- Engine fix: capability-filter recurses into once/always.
