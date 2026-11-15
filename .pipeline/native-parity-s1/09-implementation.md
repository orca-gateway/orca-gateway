# 09 · Implementation · native-parity-s1

## Front page

### In one breath
group 1 of 7 · tasks: 1 green, 0 blocked · cases: 2 of 26 green · every suite green
C1 Fixtures 40, 41 and count pins: fixture 40 pins the new Text style props, 41 the flex direction
props and Center factors; engine, Flutter, Swift and Kotlin pass both; render pins 39 → 41.
Every prop was already on the wire: no engine change. Next, G2: Swift and Kotlin text, demo page.

### New for you
nothing new

### Trade-offs
1 auto-decided: fixture 40's text comes from page state, so the resolved map checks a resolution.

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 2 (S-text, K-text, D1 demo page)? (default: go)

## Appendix

Cases count: 26 = the 13 rows split per SDK, plus the fixture halves of A1.1 and A1.10 (counted with
the row's first SDK cell they unblock); a row is ticked in phase-a-tests.md only when both its halves pass.

### Group 1
Commit: C1 (below). Nothing pushed. Gate 08 approved under the standing rule (all defaults).

#### Task C1 · Fixtures 40, 41 and count pins
Files: `schema/fixtures/render/40_text_style_polish.json` (new) · `schema/fixtures/render/41_flex_direction_center_factors.json` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt` · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt`
Cases: A1.1 fx, A1.10 fx → green (engine `bun test` 739 pass 0 fail; Flutter conformance +49, full +248; Swift
`swift test` 234 tests 0 failures; Kotlin `:core:test` 228 tests 0 failures; `:core:build` successful) · baseline
unchanged (737/+246/234/228 plus 2 new engine and 2 new Flutter tests). Red first: with the pins at 39, Swift
ModelRoundTripTests:10 and Kotlin ModelRoundTripTest, FixturePathsTest failed (41 vs 39).
Changed: 40 = Text "t" with style {fontSize 16, height 1.5, wordSpacing 4, decoration overline, decorationStyle
dashed, decorationColor #E53935, overflow fade}, overflow fade, textAlign justify, maxLines 1; `resolved` pins the
five props. 41 = Column "col" (verticalDirection up, textDirection rtl) > Row "row" (rtl; Texts first, second) +
Center "center" (widthFactor 0.5, heightFactor 2). `expected` from `encodeJsonTree` (scratchpad script), not by
hand. Render pins 39 → 41 (Swift :10, :151; Kotlin ModelRoundTripTest :30, :176; FixturePathsTest :10).
Decisions: 1. Fixture 40's `data` comes from page state `caption`, so its resolved map checks a real resolution
· 2. The engine accepted every prop as spelled; nothing renamed.
Review fit: pass
Review quality: pass
Not done: nothing

### Test run
engine 739 pass 0 fail · Flutter +248 all passed · Swift macOS 234 tests 0 failures · Kotlin core 228, sdk 132,
0 failures. Lint: not run (no lint-relevant source changed; G2 onward runs `./gradlew build` and `flutter analyze`).

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing
