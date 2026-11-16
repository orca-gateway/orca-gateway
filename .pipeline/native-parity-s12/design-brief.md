# Design brief · native-parity-s12 · finish animation

Source: plan step 12 (plan.md:147) and decision 2 (plan.md:223), rows B12.1 to B12.7, and a read of the Flutter SDK,
the engine and both native SDKs on 2026-11-16. Nothing was built or run; items marked (unverified) need a spike.

## 1. What Flutter does (the oracle)
1. `AnimationRegistry` is a map id -> (controller, curved animation), one per page (`sdk/lib/src/state/animation_registry.dart:18-36`,
   made in `widgets/orca_page.dart:112`, handed to the executor at `:274`). `getProgress` returns the value AFTER the curve.
2. `animateForward` is `controller.forward(from: 0.0)`: it always restarts from 0 (`state/action_executor.dart:793-801`).
   `animateReverse` is `controller.reverse()`: from the current value down to 0 (`:803-810`). A missing `animationId`, an
   unknown id or no registry: nothing, no error. Neither emits an effect today (`openDrawer` does, `:362`).
3. `OrcaAnimatedBuilder` (`builders/animated_builder_widget.dart`): `duration` (300), `curve`, `repeat` (false), `reverse`
   (false), `autoStart` (true), `animationId` (`builders/layout_builders.dart:941-961`). It registers its id in `initState`
   (`:58-63`), starts only when `autoStart` (`:67-73`), and fires `onComplete` on status completed AND dismissed (`:76-81`):
   at the end of a forward run and of a reverse run. A repeat never completes; `reverse()` at 0 fires nothing;
   `animateForward` on a repeating builder stops the repeat and plays once. Several children: `Stack(fit: expand)` (`:113-117`).
4. A `tween` / `tweenSequence` value may carry `animationId` (`schema/value.schema.json:98,117`): it reads that controller's
   progress, 0 for an unknown id, else the enclosing builder's (`state/value_resolver.dart:227-233`).
5. In `builders/layout_builders.dart`: `_parseCurve` (`:822-875`) knows 41 names, the engine's `Curves` enum
   (`engine/src/components/helpers/curves.ts:65`); missing or unknown: `easeInOut`. `duration`: int ms, default 300. The
   widgets animate only when a prop resolves to a new value; the first frame shows the target as is.
6. AnimatedContainer (`:877-900`): `duration`, `curve`, `padding`, `margin`, `decoration`, `width`, `height`, `color`,
   `alignment`. `color` is used only when there is no `decoration` (`:894`); alignment `center` is passed as none (`:897`).
7. AnimatedOpacity (`:902-913`): `opacity` (1.0), `duration`, `curve`. AnimatedAlign (`:915-930`): `alignment` (center; nine
   names, `builders/builder_helpers.dart:225-238`), `duration`, `curve`, `widthFactor`, `heightFactor`.
8. AnimatedSwitcher (`:932-939`): `duration` only (no curve prop; Flutter's default is a linear fade in and out, children
   stacked centred). Flutter decides "the child changed" by widget class and key. Orca's child carries a key only when the
   node has watches (`ValueKey('watch_<id>')`, `rendering/component_renderer.dart:66-67`); otherwise only the class counts.
9. Hero (`:963-973`): `tag`; an empty tag draws the child alone. Flutter flies a hero only if both pages hold the tag in the
   frame the route starts; an Orca page is fetched after the push, so it flies on push only when the page is already at
   hand, and on pop (framework behaviour, not observed here).
10. Field: `transition` on a route, `{type, duration=300, curve="easeInOut"}` (`models/page_response.dart:265-282,289`;
    engine `engine/src/core/flow.ts:14-18,36,60,219`; schema `schema/flow-definition.schema.json:57,74-89`).
    Kinds: `slide | fade | scale | slideUp | slideRight | none`.
11. Applied in `navigation/navigation_handler.dart:280-291` as a go_router `CustomTransitionPage`, the same duration in and
    out. Only the entering page moves; the page under it stands still; pop plays it backwards (`:303-325`):
    fade = opacity 0 to 1; scale = 0 to 1 from the centre; slideUp = from the bottom; `slideRight` = in from the RIGHT;
    `slide` and any unknown kind = in from the LEFT. `none` or no transition: a plain `builder`, so the platform's default
    page animation, not "no animation" (`:280,293-297`). The curve parser here knows only 11 names (`:328-343`).
12. Reduced motion: the SDK has no code for it (no `disableAnimations`, no `MediaQuery` read anywhere under `sdk/lib`).
    Flutter's framework shortens controller runs to 5% when the OS flag is on; repeats are untouched.

## 2. Engine and contract today
- Widget classes in `engine/src/components/layout/`: `animated-container.ts:7-19`, `animated-opacity.ts:6-12`,
  `animated-align.ts:7-15`, `animated-switcher.ts:5-9`, `hero.ts:5-9`, `animated-builder.ts:6-19` (trigger `onComplete`).
  None declares `static targets`, so `schema/widget-registry.json` already lists all four targets for each
  (`schema/gen-widget-registry.ts:210-212,260`). No engine or manifest change is needed.
- Actions: `engine/src/types/action.ts:145-153,407-412`; `schema/action.schema.json:483-510`. Both native models already
  decode them (`sdk-swift/Sources/OrcaGatewayCore/Models/Action.swift:33-34,349-350`; Kotlin `core/…/models/Action.kt:99-101,267-268`).
- Demos: `examples/server/animations.ts:118-203` (two builders driven by AnimateForward / AnimateReverse buttons);
  `examples/server/ecommerce.ts:325` (AnimatedContainer by state) and `:391` (a `slideUp` route). The other four widgets: none.

## 3. Native today
- AnimatedBuilder: `sdk-swift/Sources/OrcaGateway/Widgets/Motion.swift:28-58` (TimelineView on `Date()`, onComplete by
  `Task.sleep`), `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Motion.kt:41-70` (`withFrameNanos`); both say
  "Not ported yet: animationId". Test seam: a pure function of elapsed time (`Motion.swift:74-82` with `MotionTests.swift:9-21`;
  `Motion.kt:76-89` with `MotionTest.kt`). Kotlin UI tests can also step frames (`CounterPageTest.kt:43`); Swift cannot.
- Curves live in the UI layers, 9 names only, and a missing or unknown name is LINEAR (`Motion.swift:39,86-100`;
  `Motion.kt:46,92-110`). Flutter says easeInOut (fact 5). This is a parity bug in the shipped AnimatedBuilder.
- Tween lerp (number, colour) is already pure core: `ValueResolver.swift:175,186`, `ValueResolver.kt:248,261`. Both
  resolvers take `animationProgressFor(id)` (`ValueResolver.swift:24,133-138`; `ValueResolver.kt:43,137-140`); no UI code sets it.
- Executors: one switch per kind; a UI-only action leaves the core as an `ActionEffect` (`ActionExecutor.swift:204-208`,
  `ActionExecutor.kt:216-218`), the page model keeps toasts and passes the rest on (`OrcaPageModel.swift:150-163`,
  `OrcaPageModel.kt:190-202`), the router performs `switchTab` / `openDrawer` (`OrcaRouter.swift:557-571`, `OrcaRouter.kt:581-588`).
  `ActionExecutor.kinds` (`ActionExecutor.swift:40-45`) is what gets advertised.
- Action fixtures: effects are data in `expected.effects`, in order (`schema/fixtures/actions/31_open_drawer.json`; Dart
  runner `sdk/test/conformance/action_fixtures_test.dart:98`). Step 10 added the Dart `_emit` for its actions (commit
  757d74d). Swift tests use `animateForward` as the example of an unimplemented kind
  (`Tests/OrcaGatewayCoreTests/ActionFixtureTests.swift:111,117-121`): those must move to another kind.
- Capabilities: `sdk-swift/capabilities.json`, `sdk-kotlin/capabilities.json` (AnimatedBuilder only; neither action), checked
  against the manifest's targets by `schema/gen-native-capabilities.ts:109`, which writes `Generated.swift` / `Generated.kt`.
- Routes: the transition already reaches both route models (`Models/NavConfig.swift:122,170-187`, `RouteTable.swift:35,177`,
  `OrcaRouter.swift:20,407`; `models/NavConfig.kt:116,151-162`, `RouteTable.kt:36,112`, `OrcaRouter.kt:71`). Nothing reads it.
- Pushing. Swift: `NavigationStack(path: $router.stack)` (`OrcaApp.swift:395-406`), one more per tab (`TabShellView.swift:270`);
  iOS 16 minimum (`Package.swift:20`). Kotlin: a `NavHost` with ONE destination for every pushed page (`OrcaApp.kt:556-590`,
  `:599-604`; navigation-compose 2.9.2). The Kotlin tab shell has no NavHost: visited pages stay composed and only the top
  one is placed (`navigation/TabShellScreen.kt:280-295`), so a push inside a tab swaps at once today.

## 4. Flutter quirks we do not copy
- q1 `unregister(id)` removes whatever sits under the id: a leaving builder deletes a newer one with the same id.
- q2 AnimatedSwitcher: a Text swapped for another unwatched Text does not fade (same class, no key).
- q3 Route transitions accept 11 curve names, widgets 41.
- q4 Reduced motion plays at 5% speed instead of jumping, and repeats keep running.
- q5 A tween that names an id but sits outside that builder is repainted only when something else redraws it.

## 5. Decisions
- D1 Pure cores own the maths. New in each core (`OrcaGatewayCore/Animation/`, `core/animation/`): `Curves.apply(name, t)`
  with all 41 names in Flutter's formulas (cubics, bounce, elastic, decelerate, the three-point cubic); a missing or unknown
  name is easeInOut. The UI copies (`OrcaCurve`, `OrcaCurves`) are deleted. Why: one table per SDK, testable without a
  screen, and it fixes the linear default (section 3). The same table serves route transitions (differs from q3).
- D2 `AnimationController` (pure, per builder): no timer inside; `forward(from: 0, at:)`, `reverse(at:)`, `value(at:)`,
  `status(at:)` take the time. The UI passes the frame time, tests pass numbers. `forward` restarts from 0 and plays once,
  also on a repeating builder; `reverse` runs from the current value to 0 in value x duration; at 0 it does nothing.
- D3 `onComplete` fires each time a run reaches 1 or reaches 0, never for a repeat; the UI sees the end from
  `status(at:)` on its frame tick, not from a sleep. Why (D2, D3): facts 2 and 3; B12.1 needs a midpoint and a reverse.
- D4 `AnimationRegistry` (pure, one per page model): id -> controller. The last builder to register an id owns it; a
  builder leaving removes the entry only if it is still its own (differs from q1). Unknown id: nothing.
- D5 The executors emit `ActionEffect("animateForward" | "animateReverse", {animationId})` and change no state; the page
  model performs it on its registry (it owns the registry, as it owns toasts). The two kinds join `ActionExecutor.kinds`.
  Flutter gains the two `_emit` lines only. Why: the pattern of `openDrawer`, and the fixture can pin it on all three.
- D6 A tween with `animationId` reads the registry's curved progress, 0 for an unknown id (`animationProgressFor` gets
  wired). It is repainted under its builder only, as today. Why: fact 4; q5 stays a known limit (minor question m2).
- D7 `ImplicitAnimation` (pure): holds `from`, `to`, the start time, duration and curve; `value(at:)` returns the mix. A new
  target while running starts again from the value on screen, full duration (Flutter's rule). The first target is shown
  with no animation. Mixed: number (width, height, opacity, factors), colour (per ARGB channel, the core's `lerpColor`),
  alignment (x and y in -1…1), edge insets (four sides), and in a decoration the colour, corner radius and border width
  and colour. Anything else, or a side that is null, snaps at the start. Why: B12.2 and B12.3 sample 150 of 300 ms.
- D8 Drawing: the three implicit widgets tick like AnimatedBuilder does (TimelineView / `withFrameNanos`) while a run is
  live and feed the sampled props to the EXISTING Container, Opacity and Align drawing code, so `color` vs `decoration`,
  the `center` rule and the no-child cases follow what Container already does. Not SwiftUI `.animation(_:value:)` or
  `animate*AsState` as the plan sketched: SwiftUI cannot express bounce or elastic, and two engines would give two midpoints.
- D9 AnimatedSwitcher: the child changed when the child's NODE ID changed (a replace, an add/delete, a refetch). Old child
  fades out and new one in, both linear over `duration`, stacked centred; same id with new props: no fade (differs from q2).
- D10 Hero: empty tag draws the child. Android: `SharedTransitionLayout` around the single-stack NavHost and
  `Modifier.sharedElement(key = tag)`; it flies when both pages hold the tag as the transition starts (on pop, and on push
  when the page is already loaded), else the route's normal transition; not inside the tab shell. iOS 18+:
  `matchedTransitionSource(id: tag)` on the Hero and `.navigationTransition(.zoom(sourceID: tag))` on the pushed page. The
  tag must be known at push time, so the route records the tag of the Hero enclosing the widget whose action navigated;
  none, or iOS 16-17: plain push. iOS zooms the whole page, which is not Flutter's flight.
- D11 Transition table. Entering page only, the page under stays still and visible, pop plays it backwards, same duration
  and curve (D1) both ways:

  | kind | Android enter (pop exit is the reverse) | iOS |
  |---|---|---|
  | `fade` | `fadeIn` 0 to 1 | honoured (D13) |
  | `slideUp` | `slideInVertically` from full height | honoured (D13) |
  | `scale` | `scaleIn(initialScale = 0)`, centre | system push |
  | `slideRight` | `slideInHorizontally` from +width (the right) | system push |
  | `slide`, unknown | `slideInHorizontally` from -width (the left) | system push |
  | `none`, absent | NavHost default | system push |

- D12 Android realisation. Single stack: the one `composable(PAGE_ROUTE)` gets enter / popExit lambdas that look the route
  up by the entry's id; the page under uses `ExitTransition.KeepUntilTransitionsFinished` and `EnterTransition.None`. The
  popped route is already off the router's stack, so the screen keeps id -> transition for the entries it shows. Tab shell:
  the entering top page gets a `graphicsLayer` (alpha, translation, scale) driven by `ImplicitAnimation`, and the previous
  top stays placed until it ends. Compose specs take the curve as an `Easing` wrapping `Curves.apply`.
- D13 iOS, NavigationStack kept. Recommended: push with the system animation off (the path changes inside a `Transaction`
  with `disablesAnimations = true`) and the pushed page animates its own content in (opacity 0 to 1, or offset from the
  screen height to 0) with the route's duration and curve. Limits: the old page is gone at once, so the new one fades or
  rises over the page background, not over the old page; the bar and back button appear at once; back (button or swipe) is
  the system pop; iOS 16 may not obey the transaction (unverified; fallback `UIView.setAnimationsEnabled(false)`).
  Rejected: `fullScreenCover` or an overlay presenter (a true fade over the old page, but a second stack: no back swipe,
  its own bar, tabs and deep links must split the stack); a `UINavigationControllerDelegate` under SwiftUI (private wiring).
- D14 Reduced motion: one `reduceMotion` flag enters every controller, implicit animation, switcher and transition; when
  true the duration is 0: end state at once, `onComplete` once, a repeating builder rests at 1 (differs from q4). iOS:
  `accessibilityReduceMotion`, read through the SDK's own environment key `orcaReduceMotion` (nil = follow the system)
  because the system key cannot be set in a test. Android: `Settings.Global.ANIMATOR_DURATION_SCALE == 0f` behind
  `LocalOrcaReduceMotion` (tests provide it); Compose's own duration scale does not reach a `withFrameNanos` loop. iOS
  route transitions and the Hero zoom fall back to the system push, which already obeys the OS.
- D15 Contract work: the five widgets and two action kinds join both `capabilities.json` (regenerate with
  `schema/gen-native-capabilities.ts`); the fixtures below; the Dart `_emit`; the two effect types join the `Effect` enum
  of the fixture schema (`schema/action-fixture.schema.json:168-182`). No wire schema, engine type or manifest change.

## 6. Core and UI split, and where the rows are tested
Pure core, tested with a number for "now": curves, duration parsing (<= 0 jumps), controller, registry, ImplicitAnimation
and its mixes, the transition spec per platform: B12.1 (with fixtures 32, 33), B12.2, B12.3 (value at 150 of 300 ms, linear
and easeInOut, a retarget mid-run), B12.7. UI: frame tick, reduce-motion read, registering, `onComplete`, drawing, NavHost
lambdas, `graphicsLayer`, the iOS modifier, Hero: B12.4 (both children present mid-fade); B12.5 and B12.6 by hand.

## 7. Fixtures (render 62-67, actions 32-33; Flutter must pass all eight)
| File | Pins |
|---|---|
| `actions/32_animate_forward_reverse.json` | forward then reverse inside a sequential group between a setState and a toast: effects `{type, animationId}` in order, state untouched by them |
| `actions/33_animate_unknown_id.json` | an id no builder has: the effect still goes out, no error, the group runs its next action |
| `render/62_animated_container.json` | static duration and curve; width, height, color by page state (stay Values, watched); padding, alignment |
| `render/63_animated_opacity.json` | opacity by state, duration, a curve name outside the old nine (`bounceOut`) |
| `render/64_animated_align.json` | alignment by state, widthFactor, heightFactor |
| `render/65_animated_switcher.json` | duration and one keyed child |
| `render/66_hero.json` | tag from a template over state, one child |
| `render/67_animated_builder_controlled.json` | `animationId` (a plain string), `autoStart: false`, `onComplete`, a child tween naming the id (resolves to `begin`) |

## 8. Open questions
Major
- M1 iOS fade and slide-up (D13). The plan's decision 2 says "a custom presenter"; the brief recommends the smaller
  in-stack content animation, whose look is weaker (nothing of the old page shows through). Accept, or pay for the presenter?
- M2 Implicit widgets are drawn by sampling the core each frame (D8), not with the platform's implicit animation APIs the
  plan names. Same result on screen, different approach.
- M3 Android pushes inside the tab shell have no NavHost: D12 adds a second mechanism there, and Hero is left out of tabs.
  In this step, or single stack only?

Minor
- m1 `none` means the platform default, as in Flutter, not "no animation". Keep.
- m2 A targeted tween outside its builder is not repainted per frame (q5). Leave, or subscribe such nodes to the registry?
- m3 Transition defaults (300, easeInOut): unit tests, no navigation fixture. Decoration parts that snap (gradient,
  shadow, image): accepted for now? The curve default change (linear to easeInOut) is a fix to note in the changelogs.
- m4 Add the four undemoed widgets to `examples/server/animations.ts` for the hand checks? `SharedTransitionLayout` may
  still need an experimental opt-in at the pinned Compose BOM (unverified).

## 9. Open questions, settled for the build (2026-11-16)
- M1 (iOS fade and slide-up): build D13 as written: NavigationStack kept, the push made with
  the system animation off, the pushed page's content fades or rises in. No second stack, the
  back swipe stays. The plan's words were "custom presenter"; this is the smaller form of the
  same default. It is flagged to the user in the PR and can be swapped for a presenter later
  without touching the contract. Every other kind keeps the system push on iOS.
- M2 (implicit widgets): sampled from the pure core each frame (one clock seam, all 41 curves).
  The plan's API names were hints; rows B12.2 and B12.3 need the midpoint from a test clock.
- M3 (Kotlin tab shell): route transitions apply inside tabs too (the shell's stack switch is
  animated with the same enter and exit table). Hero is drawn on the single-stack NavHost only;
  inside tabs it falls back to a plain push, as row B12.5 allows. Said in the README.
- The AnimatedBuilder default curve becomes easeInOut with Flutter's 41 names (parity fix).
