# 09 · Implementation · native-parity-s4

## Front page

### In one breath
group 1 of 6 · tasks: 1 green, 0 blocked · A4.1-A4.5 fixture half green on all four runners
F1: render fixture 43 holds the 11 effect and touch wrappers with every wire prop; pins 44 → 45.

### New for you
nothing new

### Trade-offs
1 auto-decided (minor): BlurView's overlay in the fixture is "#FFFFFF80" (the brief's "#80FFFFFF"
would be read as an opaque colour: the clients read the alpha last).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 2, BackdropFilter and BlurView on both SDKs (already running). (default: go)

## Appendix

Cases count: 5 rows split per SDK = 10 cells, plus the fixture half (F1) and the engine half (D1); a row is ticked in
phase-a-tests.md only when every half passes on both SDKs and the hand checks agree.

### Group 1
Commits: F1 2aac5b4 (staged by path). Nothing pushed. Gate 08 approved under the standing rule (all defaults, q3
adjusted). Baseline: feat/native-parity-s3 2179ff2 (engine 751, Flutter 331, Swift 240 + 368, Kotlin core 369, sdk 348).

#### Task F1 · Fixture 43 and native count pins
Files: `schema/fixtures/render/43_effects_and_touch.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift`
· `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `.../core/FixturePathsTest.kt`
Cases: A4.1-A4.5 fx → green. Red first: the three pins at 44 failed with 45. Engine conformance 45 pass, whole `bun
test` 752; Flutter `test/conformance/` all pass including "43_effects_and_touch.json · resolved props"; Swift
`ModelRoundTripTests|ResolverFixtureTests` 11/0, `swift test` 368 + 240; Kotlin `:core:check` 369/0.
Changed: a Column holding all 11, each around a Text, every wire prop (Opacity 0.5, RotatedBox 1, ClipOval, ClipRect,
DecoratedBox color/radius 8/border/shadow + position foreground, ColorFiltered #FF0000 multiply, BackdropFilter 4/6,
BlurView 8/8 #FFFFFF80 radius 12, AbsorbPointer false, IgnorePointer bound to pageState `ignore`, InteractiveViewer
0.5/4 pan false); `expected` is the engine's output unedited; `resolved` covers the 11 ids.
Decisions: overlay "#FFFFFF80" (RRGGBBAA, alpha last); no gradient on DecoratedBox (optional); `resolved` from a
scratchpad generator (wire props with the page-state Value replaced), checked by all three resolvers.
Review: main session (one reviewer, both lenses; a small, mechanical task): every wire prop in inventory §1 present
(checked with jq), `expected` engine-generated, runners green · pass
Not done: nothing.
