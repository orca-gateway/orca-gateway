# Step 3 inventory (layout and sizing wrappers), checked 2026-11-16 against origin/main 3cdeef7

Read-only facts with file:line. Paths from the repo root.

## 1. Engine classes (`engine/src/components/layout/*.ts`)
Every class: private ctor, `static new(opts)`, `getProps()` = `{...this.props}` (opts minus child/children/actions).
Bases: `SingleChildLayout` (`types/widget.ts:245-248`, child?), `MultiChildLayout` (`:250-253`, children). No per-widget
encoder logic (`types/widget.ts:45-51`, `Encoder.addNode :108-148`; `core/json-tree-encoder.ts:101-172` generic). No
`static readonly targets` on any of the 13 → all four targets (`schema/gen-widget-registry.ts:210-212`).

| Widget (file) | base | props (no engine defaults) |
|---|---|---|
| Align (`align.ts:6-33`) | Single | alignment?: AlignmentValue; widthFactor?, heightFactor?: number |
| AspectRatio (`aspect-ratio.ts:5-30`) | Single | aspectRatio: number (required) |
| Baseline (`baseline.ts:5-31`) | Single | baseline: number; baselineType: "alphabetic"\|"ideographic" (both required) |
| ConstrainedBox (`constrained-box.ts:6-31`) | Single | constraints: {minWidth?, maxWidth?, minHeight?, maxHeight?} (`helpers/constraints.ts:1-6`) |
| FittedBox (`fitted-box.ts:6-32`) | Single | fit?: fill\|contain\|cover\|fitWidth\|fitHeight\|none\|scaleDown; alignment? |
| Flexible (`flexible.ts:5-31`) | Single | flex?: number; fit?: "tight"\|"loose" |
| FractionallySizedBox (`fractionally-sized-box.ts:6-33`) | Single | widthFactor?, heightFactor?; alignment? |
| IntrinsicHeight (`intrinsic-height.ts:4-28`) | Single | none |
| IntrinsicWidth (`intrinsic-width.ts:5-31`) | Single | stepWidth?, stepHeight? |
| LimitedBox (`limited-box.ts:5-31`) | Single | maxWidth?, maxHeight? |
| Offstage (`offstage.ts:5-30`) | Single | offstage?: boolean |
| SafeArea (`safe-area.ts:5-33`) | Single | top?, bottom?, left?, right?: boolean (no minimum / maintainBottomViewPadding) |
| Wrap (`wrap.ts:6-34`) | Multi | spacing?, runSpacing?; alignment?: MainAxisAlignment; crossAxisAlignment?: start\|end\|center\|stretch\|baseline |
Not on the wire for Wrap: direction, runAlignment, textDirection, verticalDirection, clipBehavior. AlignmentValue = 9
names topLeft…bottomRight (`helpers/alignment.ts:1-10`). Engine tests: Wrap getProps `engine/test/components.test.ts:277-287`,
Flexible `:325-331`.

## 2. Flutter builders (`sdk/lib/src/builders/layout_builders.dart`, registrations :27,30,34-38,55-57,60,63-65)
- Wrap :188-201: `direction` 'vertical' → vertical else horizontal (engine cannot author it); spacing, runSpacing default
  0; alignment `_parseWrapAlignment` :737-747 start/end/center/spaceBetween/spaceAround/spaceEvenly, default start;
  crossAxisAlignment `_parseWrapCrossAlignment` :749-756 start/end/center only, stretch/baseline/unknown → start;
  runAlignment, textDirection, verticalDirection, clipBehavior framework defaults.
- Flexible :234-240: flex default 1; fit tight only for 'tight', else loose. Expanded :230-232 flex default 1.
- Align :265-272: alignment `parseAlignment` (builder_helpers.dart:225-238) 9 names, default center; factors as given.
- FittedBox :274-279: fit `_parseBoxFit` :807-818, default contain. QUIRK: `alignment` not read → always centred.
- AspectRatio :281-286: aspectRatio default 1; missing child → null.
- SafeArea :295-303: top/bottom/left/right default true; minimum, maintainBottomViewPadding not read.
- IntrinsicHeight :434-436 plain. IntrinsicWidth :438-446 stepWidth, stepHeight as given.
- Offstage :448-453: `offstage` default TRUE.
- Baseline :469-479: baseline default 0; baselineType ideographic only for 'ideographic', else alphabetic.
- ConstrainedBox :487-503: missing min → 0, missing max → infinity; absent map → BoxConstraints().
- LimitedBox :506-512: missing max → infinity.
- FractionallySizedBox :514-521: factors as given; alignment parseAlignment default center; missing child → null.
- `renderChild` → SizedBox.shrink() without a child (builder_helpers.dart:19-22). Row/Column cross default center
  (:204-213). OrcaLifecycleWrapper/WatchBuilder add no RenderObject (`lifecycle_wrapper.dart:70`): parent data survives.

Framework facts (`/Users/amrebada/flutter/packages/flutter/lib/src`):
- Flexible outside a Flex: debug "Incorrect use of ParentDataWidget", parent data not applied (`widgets/framework.dart:6900-6910`);
  release: ignored, child lays out normally. In a Flex, loose → min 0, tight → min = max (`rendering/flex.dart:813,900-903`).
- LimitedBox caps only an axis whose incoming constraint is unbounded (`rendering/proxy_box.dart:398-414`).
- ConstrainedBox enforces its constraints within the parent's (`proxy_box.dart:310-313`): a tight parent wins.
- Baseline places the child's baseline `baseline` px from its own top; no baseline → the child's height; size = child
  width × (top + child height) (`rendering/shifted_box.dart:1556-1571`). It does not align siblings by itself.
- IntrinsicHeight gives its child a tight height = the max intrinsic height; a Row's children become equally tall only
  with crossAxisAlignment stretch (default center).
- Offstage sizes to `constraints.smallest` (`proxy_box.dart:3842-3861`), skips paint and hit testing (`:3865-3880`).

## 3. Registry and capabilities
`schema/widget-registry.json`: all 13 kind layout, targets flutter/web/android/ios, triggers [] (Align :31, AspectRatio
:400, Baseline :455, ConstrainedBox :1051, FittedBox :1568, Flexible :1599, FractionallySizedBox :1735, IntrinsicHeight
:2243, IntrinsicWidth :2259, LimitedBox :2290, Offstage :2436, SafeArea :2940, Wrap :4200). `gen-native-capabilities.ts`
reads both capabilities.json (:77-84), fails on a widget without the platform target (:103-118), writes Generated.swift
and Generated.kt (:234-246); CI fails on drift (`.github/workflows/schema.yml:50-56,71-80`).
Both lists today (identical, 31): AnimatedBuilder, AppBar, BottomNavItem, BottomNavigationBar, Card, Center, ClipRRect,
Column, Container, Divider, Drawer, ElevatedButton, Expanded, FallbackPrompt, GestureDetector, Icon, Image,
OutlinedButton, Padding, Positioned, Row, Scaffold, SingleChildScrollView, SizedBox, Spacer, Stack, Text, TextButton,
TextField, Transform, Video. None of the 13.
Pins: Swift `StructureWidgetTests.swift:256-262` (31, WidgetRegistry.shared.types == Set(widgets)), `:264-275` (every
advertised type hits a non-default switch branch); Swift `OrcaGatewayCoreTests/CapabilitiesTests.swift:19-35`; Kotlin
`core/.../capabilities/CapabilitiesTest.kt:41-48` and `:61-76` (31, Kotlin list == Swift list, sorted, == generated);
Kotlin `sdk/.../WidgetBuildersTest.kt:14-24` (standard() == advertised == WidgetRegistry.shared); `WidgetBuilders.kt:88-97`
"31 widgets" comment.

## 4. Real widget vs fallback
Caps from headers (`request-info.ts:60-69`, `engine.ts:605-643`); `pipeline.ts:175-187` runs `filterByCapabilities`;
default policy graceful (`engine.ts:53`, `fallback-policy.ts:50-61`); example server sets `widget.Divider: "warn"`
(`examples/server/index.ts:57-66`). Filter (`core/capability-filter.ts`): no vector → none (:72-79); missing type →
feature `widget.<Type>` (:209-211); graceful drops the node and splices children into the parent (:141-160,400-437);
a structure-slot parent promotes to warn (:144-152, wrap in Column + FallbackPrompt :468-507); require → blocking page.
Today, natively, all 13 are dropped and their children hoisted (Offstage child shown, SafeArea no padding, Wrap children
become parent siblings); in a structure slot the client turns them into FallbackPrompt "Unsupported content"
(Swift `PageRenderer.swift:55-68,142-146`, Kotlin `core/.../render/PageRenderer.kt:22-30,50-70,161-163`).
Tests: `engine/test/capability-filter.test.ts` :65,:124,:157,:176,:199-223; `todo-example.test.ts:330-376` (native
vectors serve the page unfiltered); `demo-server.test.ts:326-347` `expectNativeDrawable`. Nothing tests the 13.

## 5. Native today
Swift dispatch `NodeView.swift:56-96` (default → plugin builder or EmptyView :91-93; ChildView :98-109). Kotlin
`NodeView.kt:46-55` (`model.builders[node.type]`), `WidgetBuilders.standard()` :98-130, ChildView :58-62. None of the
13 exist. Related code:
- Flexible/Expanded: Swift `FlexView.flex(of:)` counts Expanded and Spacer only (`Widgets/Layout.swift:67-71`);
  `FlexLayout` gives each flex child exactly its share (tight) (`Widgets/Flex.swift:73-164`, :117-121), chosen when any
  flex > 0 (`Layout.swift:51-62`); `ExpandedView` (`Flex.swift:168-182`) adds the main axis to `orcaTight`. Kotlin
  `Modifier.flex`/`FlexFactorNode` (`widgets/Flex.kt:101-123`), `FlexMeasurePolicy` min = max share (:181-201),
  `ExpandedWidget` Box(propagateMinConstraints) (:76-81), `flexOf` :94-95.
- Align-like: Swift ContainerView alignment (`Widgets/Box.swift:225-231`), `CenterView`/`CenterFactorLayout`
  (`Layout.swift:160-207`); Kotlin ContainerWidget alignment (`widgets/Box.kt:45,62-66`), `CenterMeasurePolicy`
  (`widgets/Layout.kt:54-82`).
- Alignment parsing: Swift `Props.alignment` (`Style/Props.swift:124-137`), `unitPoint` (:139-152); Kotlin
  `Props.alignment` (`style/Props.kt:169-172`), :179-196. Axis enums Swift `Props.swift:80-101`, Kotlin `Props.kt:108-134`.
- Tight constraints: Swift `TightAxes`/`orcaTight`/`orcaFlexAxis` (`Flex.swift:14-49`), `AddTight` (`Layout.swift:531-539`);
  Kotlin `propagateMinConstraints` (`Layout.kt:41-46`).
- Intrinsic-like: Swift `HugLayout` (`Layout.swift:512-530`, used by shrinkWrap :259-262); Kotlin none.
- Baseline-like: Row baseline → Swift HStack(.firstTextBaseline) (`Layout.swift:121-125`), Kotlin FirstBaseline
  (`Flex.kt:207-221,242`).
- FittedBox-like: Swift `ImageFit.rect(for:in:alignment:)` 7 fits (`Widgets/Media.swift:129-150`); Kotlin `imageFit()`
  (`widgets/Image.kt:211-219`).
- Fixed size: Swift `SizedBoxView` (`Layout.swift:223-243`); Kotlin `SizedBoxWidget` (`Layout.kt:98-108`).
- SafeArea-like: Swift Scaffold uses SwiftUI's safe area (`Widgets/Structure.swift:31-46`, AppBar :258); Kotlin M3
  Scaffold padding + consumeWindowInsets (`widgets/Structure.kt:226-253`).
- Offstage, Wrap: nothing.

## 6. Render fixtures
43 files (01-41, 60, 61); none mention the 13. Format (`engine/test/conformance.test.ts:25-53`): name, description,
input (JsonTreeNode), context, expected (ComponentNode[] root-first); optional note, resolved, clientCapabilities +
fallbackPolicy, pluginWidgets, skipEngines. Example `41_flex_direction_center_factors.json`. Runners: engine
`conformance.test.ts:60-112`; Flutter `sdk/test/conformance/render_resolved_test.dart:13-45` (only fixtures with
`resolved`; list `fixture_paths.dart:20-29`); Swift `ResolverFixtureTests.swift:9-33`, `ModelRoundTripTests.swift:8-24`
(pins 43 at :10); Kotlin `FixturePathsTest.kt:13` (43), `ModelRoundTripTest.kt:30-43` (43 at :32, 60/61 names :46-61),
`ResolverFixtureTest.kt:21-44`.

## 7. Native UI size-test patterns
Swift `Tests/OrcaGatewayTests/LayoutTests.swift`: `draw(nodes,width,height,direction)` :198-213 (ImageRenderer scale 1 →
`Pixels`), `hosted(...)` :216-238 (iOS, UIWindow, `.ignoresSafeArea()`), helpers `node`/`box`/`model`/`rootId`
:170-196, `assertFrame` accuracy 0.5 :161-167; `Pixels` (`TextStyleTests.swift:243-300`). Example
`testA1_10CenterWidthFactorHalfHeightFactorTwoIsTwentyByForty` :46-57. Also FlexLayoutTests, BoxTests :103-118.
Kotlin `sdk/src/test/kotlin/com/orcagateway/sdk/widgets/LayoutTest.kt`: Robolectric mdpi :33-34, compose rule :36-37,
`bounds(tag)` :39, `layoutPage` :46-58 (testTag per node, host Box(size, propagateMinConstraints = tight)); example
`a1_10_centerFactorsSizeItByTheChild` :66-80; helpers `support/Pages.kt:22-45`.

## 8. parity-a demo (`examples/server/parity-a.ts`)
Header :38-45 (one page per step; only widgets all three draw; Wrap named as one to avoid). Imports :15-36. Helpers:
section :60-72, fullWidth :75-77, box(label,color) :79-87 (48×32), caption :89-91, oneLine :93-114, imageBox :116-130,
numbered :132-137, bump :440-442, shows :445-448, scrollEvent :451-459; colours :47-52. Pages: polish :142-403
(Scaffold → SingleChildScrollView → Padding(16) → Column(start) of sections), polish-pushed :406-414, polish-no-back
:417-434, lifecycle :461-581. Routes `parityFlow` :583-591; `parityAApp` id parity-a :593-597; `index.ts:11,25` and URL
lines :102-103; `record-page.ts:32,56`. Add a page: a PageDefinition constant + a `routes` entry (+ a URL line).
