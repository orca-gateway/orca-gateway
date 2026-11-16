# Step 5 inventory (lists, grids, pages, pull to refresh, refetchPage), checked 2026-11-16 on feat/native-parity-s4 d2b2262 (branch feat/native-parity-s5 starts at d16d855; no source change between)
Note: K-caps (a2b0bd5) landed while this was read; line numbers in WidgetBuilders.kt and capabilities Generated.kt may be off by up to 11. Re-read before editing.
SB = sdk/lib/src/builders/structure_builders.dart, LB = …/layout_builders.dart, BH = …/builder_helpers.dart, FW =
~/flutter/packages/flutter/lib/src, MUI = ~/.pub-cache/hosted/pub.dev/material_ui-1.11.0/lib/src (RefreshIndicator and
Scrollbar come from this package, LB:2-13).

## 1. Engine classes
All five: private ctor + static new, getProps() = {...this.props}; no engine defaults; no `targets` → all four
(widget-registry-gen.ts:68,81,86,88,96). Exports layout/index.ts:40,49,51; structure/index.ts:4-5.
| ListView (structure/list-view.ts:6-38) Multi | scrollDirection?: horizontal|vertical; padding?: EdgeInsetsData; shrinkWrap?, reverse?, primary?: boolean; itemExtent?: number; separator?: Widget; triggers onScrollBegin/onScrolling/onScrollEnd (:20) |
| GridView (structure/grid-view.ts:6-39) Multi | crossAxisCount: number (required); mainAxisSpacing?, crossAxisSpacing?, childAspectRatio?: number; scrollDirection?; padding?; shrinkWrap?, primary?; no reverse; same 3 triggers (:21) |
| PageView (layout/page-view.ts:5-32) Multi | scrollDirection?; pageSnapping?, reverse?: boolean; no triggers (registry :86 `[]`); no initialPage/viewportFraction |
| Scrollbar (layout/scrollbar.ts:5-31) Single | thumbVisibility?: boolean; thickness?: number |
| PullToRefresh (layout/pull-to-refresh.ts:5-33) Single | color?, backgroundColor?: string; displacement?: number; triggers ["onRefresh"] (:15) |
Children: a plain list, no builder/template/count; the encoder emits every child (types/widget.ts:111-116); 1,000 rows =
1,000+ nodes (cap 50,000, widget.ts:42). ListView.separator is broken on the wire: only StructureWidget slots become node ids
(widget.ts:124-131), so the Widget goes out raw in props while Flutter reads a node id (SB:171, BH:25-29, cast
component_context.dart:77). refetchPage: RefetchPageAction {type} (types/action.ts:156-158, union :28), RefetchPage()
(:426-428), schema action.schema.json:604-615, no fields; used as an action value, e.g. {onRefresh: RefetchPage()}.
ActionTrigger has no onPageChanged (action.ts:303-326). Only use: engine/test/components.test.ts:659-693 (List/GridView).

## 2. Flutter builders (registered SB:23-24; LB:28,48,72,77)
- ListView SB:161-202: vertical unless 'horizontal'; padding (BH:74-85); shrinkWrap false; reverse false; primary null;
  itemExtent. renderChildren (BH:14-16) calls every child's builder up front (component_renderer.dart:219): widget configs
  eager, elements lazy. SliverChildListDelegate (FW widgets/scroll_view.dart:1363); itemExtent → SliverFixedExtentList
  (:1730-1740); cacheExtent 250 px (FW rendering/viewport.dart:289,605); physics unset → iOS Bouncing, Android Clamping (FW
  widgets/scroll_configuration.dart:243-256); padding null → MediaQuery padding added on the scroll axis (scroll_view.dart
  :913-944; SingleChildScrollView does not); primary null → PrimaryScrollController if vertical (:517-523); shrinkWrap →
  ShrinkWrappingViewport (:490-491). onScroll* via wrapScrollNotifier (BH:46-71).
- GridView SB:204-227: GridView.count; crossAxisCount propOr 2; spacings 0; childAspectRatio 1.0; padding, shrinkWrap,
  primary, scrollDirection; SliverGridDelegateWithFixedCrossAxisCount (scroll_view.dart:2176-2182): cross = (extent -
  crossSpacing*(n-1))/n, main = cross/ratio (FW rendering/sliver_grid.dart:394-399) → horizontal reads the ratio as
  height/width; cells forced tight (:79-85). Lazy, 250 px.
- PageView LB:668-684: horizontal unless 'vertical'; pageSnapping true; reverse false. No controller → PageController()
  initialPage 0, viewportFraction 1.0 (FW widgets/page_view.dart:122-124,981); no onPageChanged passed. PageScrollPhysics:
  page ±0.5 by fling direction then round → one page per fling (:603-611,1010-1017). Cache 0 viewports (:723): only visible
  pages built. Wrapped in wrapScrollNotifier (LB:675): onScroll* with offset/viewportDimension.
- Scrollbar LB:603-611 (both props nullable). iOS → CupertinoScrollbar(thumbVisibility ?? false, thickness ?? 3, dragging
  ?? 8) (MUI scrollbar.dart:180-191; cupertino_ui-1.1.6 scrollbar.dart:16-17,114,118: fades after 1200 ms over 250). Android
  → thickness 4 (:334-336), not interactive (:244), fades after 600 ms over 300 (:17-18). Uses PrimaryScrollController when
  no controller (FW widgets/scrollbar.dart:1435); thumbVisibility true with none attached asserts (:1535-1561).
- PullToRefresh LB:372-393: RefreshIndicator(color or theme primary (MUI refresh_indicator.dart:394), backgroundColor or
  canvasColor (:329), displacement 40); onRefresh awaits execute/executeAll(actions['onRefresh']) (LB:380-390); spinner
  stays until it completes (MUI :634-639). Starts only on a user drag at the top edge of a depth-0 vertical scrollable
  (:212,461-475,489): the child must be the scroll view.
- refetchPage: action_executor.dart:812-818 awaits onRefetchPage, emits NO ActionEffect. OrcaPage (widgets/orca_page.dart
  :276-297): fetchPage(appId, path, appState) (POST when app state set, client/orca_client.dart:292-310), then post-frame
  initPage + componentStore.init: in place, no loading screen; the future resolves after the fetch, before the swap. App
  state kept (initPage seeds only unset app keys, state/state_manager.dart:19-23); page state RESET to fresh initials (:28).

## 3. Registry and capabilities
widget-registry.json: GridView :1793, ListView :2366, PageView :2570, PullToRefresh :2667, Scrollbar :3031 (SCSV :3107).
Flutter kSupportedWidgets has all five (capabilities/generated.dart:63,76,81,83,91), 'refetchPage' :149. Natives: 55 widgets
each, sorted, identical, none of the five; 20 actionKinds each, identical, no refetchPage (capabilities.json :3,:60 both).
gen-native-capabilities.ts: ios/android target check (:109-110), kind must be in action.ts (:113-114), sorted (:86-88,123-125).
Action kinds ARE advertised; an unadvertised kind marks its node missing (capability-filter.ts:216-219,349-351) → graceful
drop, children hoisted (:119-121,139-157,400-437): a PullToRefresh with RefetchPage is dropped until refetchPage is listed.
Pins 55 → 60, 20 → 21: Swift CapabilitiesTests.swift:42-47,79-84; StructureWidgetTests.swift:259-263 (+ :267-277); Kotlin
CapabilitiesTest.kt:67-70,96-99,125-129; WidgetBuildersTest.kt:15-22; WidgetBuilders.kt:114-122 doc.
Executors: Swift ActionExecutor.kinds (OrcaGatewayCore/State/ActionExecutor.swift:40-45); run returns silently for a kind
with no handler and not in kinds (:137-139); switch :157-244, default return :242. Kotlin core/state/ActionExecutor.kt kinds
:401-405, run :138-141 same, when :164-258. Both decode refetchPage (Swift Models/Action.swift:35,80,351; Kotlin
models/Action.kt:103,165,269).

## 4. Native today: none of the five (Swift NodeView.swift:61-118, default :115-117; Kotlin WidgetBuilders.kt:124-182,
missing builder logged NodeView.kt:49-51).
- Swift ScrollNodeView (Widgets/Layout.swift:263-333; dispatch NodeView.swift:81): ScrollView(axis); reverse =
  defaultScrollAnchor iOS 17 else ScrollViewReader scrollTo on appear (:310-319); shrinkWrap HugLayout (:283-284,537); padding
  inside (:322-325); primary ignored; ScrollTriggers (:352+, ScrollTracker :446) on core ScrollObserver (Render/
  ScrollEvent.swift:65,80).
- Kotlin ScrollWidget (widgets/Layout.kt:115-150; WidgetBuilders.kt:132): unbounded axis → no scroll (:137-141),
  reverseScrolling, short content at far end (:182-193), ScrollTriggers on ScrollState (:159-175; core render/ScrollEvent.kt
  :41,59). BOM 2026.05.01 (gradle/libs.versions.toml:6), material3 (sdk/build.gradle.kts:92): LazyColumn, LazyVerticalGrid,
  Pagers, PullToRefreshBox available; no Android scrollbar API.
- Reload. Swift OrcaPageLoader.reload (OrcaApp.swift:85-110): phase = .loading → ProgressView (:483-484), new OrcaPageModel +
  ElmStore(app: router.appState); only caller the error retry (:489); app scope in OrcaRouter.appState (Navigation/
  OrcaRouter.swift:114), merged by attach (:492-518). Kotlin OrcaPageLoader.reload(context) (OrcaApp.kt:112-140): closes the
  old model (scope cancelled, OrcaPageModel.kt:144-146), phase = Loading (LoadingView :659); only caller retry (:662). No
  pull-to-refresh, no in-place reload. Kotlin OrcaPageModel.renderer is a val (:65); Swift's private(set) var (:24).
- Wiring point: executor emit → onEffect + perform (Swift ActionExecutor.swift:273-276 async; Kotlin :263-266 suspend) →
  model.perform, sync (Swift OrcaPageModel.swift:150-163; Kotlin OrcaPageModel.kt:190-202) → effectHandler → router.perform
  (Swift OrcaRouter.swift:558-575). To await a reload: registerHandler (Swift :82, Kotlin :94) or an async effect path.
  model.fire returns Task (Swift OrcaPageModel.swift:78-83) / Job (Kotlin OrcaPageModel.kt:122-125), awaitable by a spinner.

## 5. Fixtures. render/: 45 (01-43, 60, 61), top 43_effects_and_touch.json, next 44_; none holds the five. actions/: 24
(01-19, 30-31, 45-47), none refetchPage; shape {pageId, state, actions, expected {state, effects}} (05_goBack.json),
serverResponses option (15_…:11). Flutter emits nothing for refetchPage → a fixture pins effects [] and state unchanged.
Pins: Swift ModelRoundTripTests.swift:10,39, ActionFixtureTests.swift:23-25; Kotlin ModelRoundTripTest.kt:32,79,
FixturePathsTest.kt:13-14, ActionFixtureTest.kt:90-92. Runners skip unimplemented kinds (Swift ActionFixtureTests.swift
:29-41; Kotlin ActionFixtureTest.kt:75-86). Render runners: Swift ResolverFixtureTests.swift, Kotlin resolver/
ResolverFixtureTest.kt; Flutter sdk/test/conformance/action_fixtures_test.dart (effects via onEffect :91-99).

## 6. Test patterns. Swift: LayoutTests.hosted (:216), reverse scroll pixels (:112-139); ScrollTriggerTests.Hosted
(:308-360) finds the UIScrollView, setContentOffset (:356-357), cases :53-233; HostedNode (LifecycleTests.swift:291). No
lazy or paging test yet. Kotlin: LayoutTest layoutPage/bounds, reverse (:97-120); ScrollTriggerTest scrollBy (:89), swipeUp
on hasScrollAction (:148); ViewerTest swipe in a scroll view (:365-395). Built-row counting: onInit fires per mounted row in
Flutter (component_renderer.dart:231-247, lifecycle_wrapper.dart:32-38).

## 7. Demo: parity-a.ts imports :1-62; header :64-71 (lists named as a later step); colours :72-77; helpers box :104, block
:109, caption :119, numbered :162; effectsPage :1014-1164 (body SingleChildScrollView :1024); routes :1166-1177; app
:1179-1183. index.ts import :11, apps :25, URLs :102-106. Engine tests parity-a-layout/effects.test.ts. New page `lists` +
parity-a-lists.test.ts; the refetch demo needs data that changes per fetch.

## 8. Risks
- Page bodies are SingleChildScrollView: a list/grid/pager inside needs a bounded height or shrinkWrap (then not lazy);
  Compose Lazy* in an unbounded parent throws. PullToRefresh must wrap the scrollable itself.
- reverse flips order and anchors at the end: Compose reverseLayout matches; SwiftUI has none (reverse the order + anchor).
- GridView cells are tight in Flutter; LazyVGrid only proposes sizes. Horizontal childAspectRatio is height/width.
- PageView: TabView(.page) is horizontal only, no reverse, no free scroll; paging ScrollView needs iOS 17. Compose Pager
  snaps one page; pageSnapping false needs a custom fling. Pager onScroll* need a probe.
- Lazy onScroll*: LazyListState has no pixel offset/maxExtent; SwiftUI lazy content size is an estimate. ListView's
  safe-area auto padding has no native twin.
- PullToRefresh: .refreshable has no colour/background/displacement and reaches every nested scroll view; PullToRefreshBox
  threshold ≠ displacement 40. Tie the spinner to fire()'s Task/Job.
- refetchPage: "the existing loader's reload" (plan.md:88) is not in place on either native (loading swap, scroll lost);
  Kotlin's also cancels the Job awaiting it. Needs a quiet swap: keep the view, new tree, page state reset, app kept. Emitting
  an ActionEffect breaks a Flutter-authored fixture (effects []). Advertise it with PullToRefresh (else node dropped).
- Scrollbar: iOS indicators are system-drawn (.scrollIndicators, iOS 16), no thickness, persistent thumb unverified;
  Compose has none: draw from the child's state, shared up to the wrapper.

## A5 rows vs Flutter
- A5.1 holds for elements (250 px cache, viewport.dart:289) though every child's widget config is built (BH:14-16).
- A5.2 holds: SB:162-167. A5.3 holds: SB:216-226, sliver_grid.dart:394-399.
- A5.4 wrong in part. One page per fling holds (LB:672; page_view.dart:603-611). No onPageChanged: the builder passes none
  (LB:677-682), PageView declares no trigger (page-view.ts:13-15, registry :86), ActionTrigger lacks it (action.ts:303-326);
  it fires onScrollBegin/onScrolling/onScrollEnd (LB:675) with offset and viewportDimension. Proposed: "PageView moves one
  page per swipe when pageSnapping (default true), scrolls freely when false, honours vertical and reverse; onScrollEnd
  reports offset = page × viewport width."
- A5.5 holds: LB:380-390, MUI refresh_indicator.dart:634-639; only from a top-edge drag on a depth-0 scrollable (:461-475).
- A5.6 holds (orca_page.dart:276-297, state_manager.dart:19-23); add "and resets page state" (:28). No effect emitted.
- A5.7 holds while scrolling; idle thumb fades unless thumbVisibility (MUI scrollbar.dart:17-18,180-191).
