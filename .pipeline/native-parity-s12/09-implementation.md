# 09 · Implementation · native-parity-s12

## Front page

### In one breath
group 4 of 4 · tasks: 15 green, 0 blocked · cases: 22 of 22 green · all suites green
G1 cores: 42 curves, a controller run by a clock passed in, implicit mixes; the `motion` demo app.
G2: fixtures, animateForward and animateReverse in three executors, the controlled AnimatedBuilder.
G3: AnimatedContainer, Opacity, Align, Switcher, Hero's child; route transitions from the config.
G4: Hero flies on Android's single stack and zooms on iOS 18; a plain push elsewhere.

### New for you
nothing new

### Trade-offs
3 auto-decided, yours to overturn: iOS fade and slide-up animate the pushed page's content
inside NavigationStack, not a custom presenter · implicit widgets sample the pure core each
frame · the default curve is easeInOut, as Flutter's builders use.

### Questions for you
1. Approve the stage? Device hand-checks are recorded in stage 10. (default: go)
2. Keep the in-stack iOS transitions, or build the custom presenter? (default: keep; said in the PR)

## Appendix

### Group 1

#### T1 · Swift core: Curves, AnimationController, AnimationRegistry, ImplicitAnimation
Files: Sources/OrcaGatewayCore/Animation/*.swift · Tests/OrcaGatewayCoreTests/AnimationCoreTests.swift
Cases: B12.7-S → green. Time is a parameter; reduce motion or a duration of 0 jumps to the end.
Review fit: twins differed on a missing alignment side, a fractional duration, a read before start,
completion counting and a live run's duration; fixed in two passes · Review quality: pass

#### T2 · Kotlin core: the same under core/animation
Files: core/.../animation/{Curves,AnimationController,ImplicitAnimation}.kt · AnimationCoreTest.kt
Cases: B12.7-K → green. Review fit: as T1, fixed · Review quality: pass

#### T3 · Motion demo app
Files: examples/server/motion.ts · index.ts · both native READMEs ("Animation")
Cases: C-demo → green. Review fit: pass · Review quality: pass

### Group 2

#### T4 · Action fixtures 32, 33, render 67, Effect enum, Dart emit
Files: schema/fixtures/actions/32, 33 · render/67 · action-fixture.schema.json · sdk action_executor.dart
Cases: B12.1-F → green on Flutter. Review fit: pass · Review quality: pass

#### T5 · Render fixtures 62 to 66
Cases: B12.2-F to B12.5-F → green on Flutter. Review fit: pass · Review quality: pass

#### T6 · Swift executor emits animateForward and animateReverse
Cases: B12.1-S → green. An empty animationId emits nothing. Review fit: pass · Review quality: pass

#### T7 · Kotlin executor emits; kinds in capabilities
Cases: B12.1-K → green. Review fit: pass · Review quality: pass

#### T8 · Swift controlled builder, registry in the page model, reduce-motion key
Files: OrcaPageModel.swift · Widgets/Motion.swift · MotionTests.swift
Cases: C-curves-S → green. Review fit: a displaced builder lost its state and fired onComplete
twice; a stale onComplete; fixed · Review quality: a test-only clock helper removed, fixed

#### T9 · Kotlin controlled builder, registry, reduce-motion local
Files: OrcaPageModel.kt · widgets/Motion.kt · MotionTest.kt
Cases: C-curves-K → green. Review fit: controller rebuilt on a prop update, fixed ·
Review quality: public surface too wide, now internal; fixed

### Group 3

#### T10 · Swift Animated.swift: container, opacity, align, switcher, Hero's child
Cases: B12.2-S to B12.4-S → green. Review fit: the switcher did not fade the outgoing child after
replaceComponent; now a snapshot of what was drawn, inert, one outgoing layer; fixed · quality: pass

#### T11 · Kotlin Animated.kt
Cases: B12.2-K to B12.4-K → green. Review fit: as T10; the outgoing layer takes no focus, its
recorder forgets removed nodes, drawn alphas pinned by pixels; fixed · Review quality: pass

#### T12 · Swift TransitionSpec (core), fade and slide-up in OrcaApp and OrcaRouter
Cases: B12.6-S → green. Other kinds keep the system push. Review fit: pass ·
Review quality: a test-only flag removed, fixed

#### T13 · Kotlin TransitionSpec (core), NavHost and tab shell
Cases: B12.6-K → green. Review fit: scale and unknown kinds untested, tests added; a pop during a
push inside a tab restarted from 0, now goes back from where it is; fixed · Review quality: pass

### Group 4

#### T14 · Swift Hero zoom on iOS 18
Cases: B12.5-S → green. Review fit: the tag leaked to later navigates; now only the run's first
push from the top page; fixed · Review quality: dead helpers removed, fixed

#### T15 · Kotlin Hero shared element on the single stack
Cases: B12.5-K → green. Not in tabs, not under reduce motion, first wins on a repeated tag.
Review fit: pass · Review quality: pass

### Test run
engine 754 · Flutter +356, analyze clean · Swift macOS: 0 failures, 0 warnings; simulator package tests TEST SUCCEEDED · Kotlin core 419, sdk 381, lint clean · both example builds succeed · generators leave no diff.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Follow-ups, not in this slice: colour tweens in AnimatedBuilder write `#AARRGGBB` while widgets read
`#RRGGBBAA` (shared with Flutter, so a blue tween draws pink; fixing it changes all three SDKs) ·
a `go` that leaves a transition route alone at the bottom animates in Flutter, on neither native SDK ·
Kotlin Hero flight uses Compose's spring, not the route duration · Kotlin Input.kt SetText can still
write from an outgoing switcher layer; Structure.kt reads the live node in a frozen layer ·
Swift delete-then-add mid-fade keeps the deleted child beside the new one, Kotlin drops it ·
an empty animationId emits nothing on the native SDKs, Flutter would emit.
