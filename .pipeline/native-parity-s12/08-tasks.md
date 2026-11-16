# 08 · Tasks · native-parity-s12

## Front page

### In one breath
tasks: 15 in 4 groups · widest group: 6 · cases: 22 of 22 placed
Group 1: both pure cores (curves, controller, implicit animation) and the motion demo app.
Group 2: fixtures, the two actions in all three executors, the controlled AnimatedBuilder.
Group 3: the four implicit widgets with Hero's child, and route transitions. Group 4: Hero flight.
Swift and Kotlin twins always run side by side in one group.

### New for you
nothing new

### Trade-offs
3 auto-decided (design brief, section 9): iOS fade and slide-up animate the pushed page's
content, NavigationStack kept · implicit widgets sample the pure core each frame ·
Kotlin transitions apply inside tabs, Hero flies on the single stack only.

### Questions for you
1. Commands as found (bun test, flutter test, swift test + simulator, gradlew build)? (default: yes)
2. Commits by the plugin: per task? (default: per task, as in steps 9 to 11)
3. One gate per group? (default: all groups under one card, as in steps 9 to 11)

## Appendix

### Groups
| G | Task | Title | Cases | Depends on |
|---|---|---|---|---|
| 1 | T1 | Swift core: Curves, AnimationController + AnimationRegistry, ImplicitAnimation, AnimationCoreTests | B12.7-S | — |
| 1 | T2 | Kotlin core: the same four files under core/animation | B12.7-K | — |
| 1 | T3 | Motion demo app (examples/server/motion.ts, index.ts) and both READMEs | C-demo | — |
| 2 | T4 | Action fixtures 32, 33, render 67, Effect enum in action-fixture.schema.json, Dart emit | B12.1-F | — |
| 2 | T5 | Render fixtures 62 to 66 | B12.2-F to B12.5-F | — |
| 2 | T6 | Swift executor emits; kinds in capabilities.json + Generated.swift; ActionFixtureTests, ActionHandlerTests | B12.1-S | — |
| 2 | T7 | Kotlin executor emits; kinds in capabilities.json + Generated.kt; ActionFixtureTest, ActionHandlerTest | B12.1-K | — |
| 2 | T8 | Swift controlled builder, registry in OrcaPageModel, reduce-motion key, Motion.swift, MotionTests, pin | C-curves-S | T1 |
| 2 | T9 | Kotlin controlled builder, registry in OrcaPageModel, reduce-motion local, Motion.kt, MotionTest, pins | C-curves-K | T2 |
| 3 | T10 | Swift Animated.swift (container, opacity, align, switcher, Hero child), NodeView, capabilities | B12.2-S to B12.4-S | T1, T8 |
| 3 | T11 | Kotlin Animated.kt, WidgetBuilders.kt, capabilities | B12.2-K to B12.4-K | T2, T9 |
| 3 | T12 | Swift TransitionSpec (core) + fade and slide-up in OrcaApp, OrcaRouter, TabShellView | B12.6-S | T1, T8 |
| 3 | T13 | Kotlin TransitionSpec (core) + NavHost lambdas and tab shell in OrcaApp.kt, TabShellScreen.kt | B12.6-K | T2, T9 |
| 4 | T14 | Swift Hero zoom on iOS 18 (Animated.swift, NodeView, OrcaRouter, OrcaApp, RouterTests) | B12.5-S | T10, T12 |
| 4 | T15 | Kotlin Hero shared element on the single stack (Animated.kt, OrcaApp.kt, OrcaAppTest) | B12.5-K | T11, T13 |

### Order, and why each boundary
1 → 2: the builders import the core types. 2 → 3: the widgets and transitions read the reduce-motion
key and the curves. 3 → 4: Hero edits the files group 3 leaves behind and falls back to its transition.

### Seams
capabilities.json + Generated.*: T6/T7 (kinds), then T10/T11 (widgets). NodeView.swift: T10 then T14.
OrcaApp + OrcaRouter: T12 then T14; OrcaApp.kt: T13 then T15. Fixture count pins: T8, T9 (render 43 → 49,
actions 24 → 26). index.ts and READMEs: T3.

### Not planned
none. The hand parts of B12.5 and B12.6 run at the hand-check on the `motion` demo app.

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` and the package tests
on the iOS simulator · `cd sdk-kotlin && ./gradlew build` · lint: inside gradlew build, `flutter analyze`
baseline: engine 748 · Flutter +348 · Swift core 358, UI 237 · Kotlin core 359, sdk 314, 2026-11-16
commits: per task · gate: all (standing rule, 2026-11-16)
