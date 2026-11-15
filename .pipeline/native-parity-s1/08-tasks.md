# 08 · Tasks · native-parity-s1

## Front page

### In one breath
tasks: 14 in 7 groups · widest group: 3 · cases: 13 of 13 placed
Plan step 1: the 27 widgets both native SDKs draw honour the props Flutter does (rows A1.1-A1.13).
G1: render fixtures 40 and 41 pin the new props on the wire; it runs alone (both SDKs' pins).
G2-G7 pair one Swift and one Kotlin task: each SDK has one build tree, so its tasks run in turn.
Themes: text (G2), flex, Center and scroll (G3), Container and the Kotlin router (G4), AppBar and
Card (G5), buttons, Stack and Kotlin Image (G6), Swift Image and both TextFields (G7).
G2 also writes the demo app `parity-a` (page `polish`), used for the A1.9 and A1.13 hand checks.

### New for you
nothing new

### Trade-offs
2 needs you: serial groups vs a worktree per task (q4); re-record 5 goldens vs keep (q5)

### Questions for you
1. Commands: every suite as at baseline; Swift on macOS and iOS 18.5. (default: as found)
2. Commits: one per task on feat/native-parity-s1; nothing pushed before 10. (default: yes)
3. One gate per group, 7 groups. (default: yes)
4. One Swift and one Kotlin task per group (shared build trees) instead of a worktree each.
   (default: serial groups)
5. Rows A1.4, A1.5, A1.9 change pixels: re-record 3 Kotlin and 2 Swift goldens. (default: yes)
6. A1.11 corrected: the three text buttons carry no `tooltip` on the wire. (default: yes)
7. Kotlin router (A1.13) may declare lifecycle-viewmodel-compose, already shipped. (default: yes)

## Appendix

### Where step 1 comes from
Plan `/Users/amrebada/.claude/plans/native-parity/plan.md`, Phase A step 1 ("Polish the widgets we already
have", S). The user approved the plan and asked for one session per phase; stages 01-07 skipped as covered by it.
Cases: `/Users/amrebada/.claude/plans/native-parity/phase-a-tests.md` rows A1.1-A1.13. Branch
`feat/native-parity-s1` from `5c6b57e` (the user's local main; that commit is not yet on origin/main).
Design in force, written here: `design.md` in this folder (gap inventory per widget with file:line, decisions
D1-D13, constraints). Plan decision 1 (draw the seven degrade widgets on iOS) answered by the user, relayed by the
parent session: "Yes, draw them" (steps 6 and 8; nothing in step 1).

### Groups
Paths from the repo root. `sw` = Swift cell, `kt` = Kotlin cell, `fx` = the fixture half of a row.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | C1 | Fixtures 40, 41 and count pins | schema/fixtures/render/40_text_style_polish.json (new) · schema/fixtures/render/41_flex_direction_center_factors.json (new) · sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt | A1.1 fx, A1.10 fx | M | — |
| 2 | S-text | Swift text style, overflow, align | sdk-swift/Sources/OrcaGateway/Style/Props.swift · sdk-swift/Sources/OrcaGateway/Widgets/Content.swift · sdk-swift/Sources/OrcaGateway/Widgets/TextKit.swift (new) · sdk-swift/Tests/OrcaGatewayTests/TextStyleTests.swift (new) | A1.1 sw, A1.2 sw, A1.3 sw, A1.11 sw (decorationColor) | M | — |
| 2 | K-text | Kotlin text style, decorations, fade | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/style/Props.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Content.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/TextDecorations.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/style/PropsTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/TextTest.kt (new) | A1.1 kt, A1.2 kt, A1.3 kt, A1.11 kt (decorationColor) | M | — |
| 2 | D1 | Demo app parity-a, page polish | examples/server/parity-a.ts (new) · examples/server/index.ts · examples/server/record-page.ts | A1.13 sw (hand) | M | — |
| 3 | S-flex | Swift flex directions, Center, scroll | sdk-swift/Sources/OrcaGateway/Widgets/Layout.swift · sdk-swift/Sources/OrcaGateway/Widgets/Flex.swift · sdk-swift/Tests/OrcaGatewayTests/FlexLayoutTests.swift · sdk-swift/Tests/OrcaGatewayTests/LayoutTests.swift (new) | A1.10 sw, A1.12 sw | M | S-text |
| 3 | K-flex | Kotlin flex directions, Center, scroll | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Flex.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Layout.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/FlexLayoutTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/LayoutTest.kt (new) | A1.10 kt, A1.12 kt | M | — |
| 4 | S-box | Swift Container border inset, clip | sdk-swift/Sources/OrcaGateway/Widgets/Box.swift · sdk-swift/Tests/OrcaGatewayTests/BoxTests.swift (new) · sdk-swift/Tests/Goldens/native-widgets-home.sdk-27.2.ios-18.5.png | A1.4 sw | M | S-text |
| 4 | K-router | Kotlin router retained, can-pop local | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/navigation/OrcaRouter.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppTest.kt · sdk-kotlin/gradle/libs.versions.toml · sdk-kotlin/sdk/build.gradle.kts | A1.13 kt | M | — |
| 5 | S-bar | Swift AppBar and Card | sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · sdk-swift/Tests/OrcaGatewayTests/AppBarCardTests.swift (new) | A1.9 sw, A1.11 sw (Card) | S | S-text |
| 5 | K-bar | Kotlin AppBar, back arrow, Card | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Structure.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/AppBarCardTest.kt (new) · sdk-kotlin/sdk/src/test/resources/goldens/counter-home.png · sdk-kotlin/sdk/src/test/resources/goldens/degrade-warn.png · sdk-kotlin/sdk/src/test/resources/goldens/native-widgets-home.png | A1.9 kt, A1.11 kt (Card) | M | K-router |
| 6 | S-button | Swift buttons and Stack passthrough | sdk-swift/Sources/OrcaGateway/Widgets/Buttons.swift · sdk-swift/Sources/OrcaGateway/Widgets/Stack.swift · sdk-swift/Tests/OrcaGatewayTests/ButtonTests.swift (new) · sdk-swift/Tests/OrcaGatewayTests/StackTests.swift · sdk-swift/Tests/Goldens/counter-home.sdk-27.2.ios-18.5.png | A1.5 sw, A1.6 sw, A1.11 sw (autofocus) | M | S-text |
| 6 | K-button | Kotlin button ripple, autofocus, Image repeat | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Buttons.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Image.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ButtonTest.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/ImageTest.kt | A1.5 kt, A1.7 kt, A1.11 kt (autofocus) | M | — |
| 7 | S-media | Swift Image fits, TextField styles | sdk-swift/Sources/OrcaGateway/Widgets/Media.swift · sdk-swift/Sources/OrcaGateway/Widgets/Input.swift · sdk-swift/Tests/OrcaGatewayTests/ImageTests.swift (new) · sdk-swift/Tests/OrcaGatewayTests/TextFieldTests.swift (new) | A1.7 sw, A1.8 sw | M | S-text |
| 7 | K-field | Kotlin TextField styles, Box/Stack pins | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Input.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/TextFieldTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/BoxTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/StackTest.kt | A1.4 kt, A1.6 kt, A1.8 kt | M | — |
Placed: A1.1 C1/S-text/K-text · A1.2, A1.3 S-text/K-text · A1.4 S-box/K-field · A1.5 S-button/K-button ·
A1.6 S-button/K-field · A1.7 S-media/K-button · A1.8 S-media/K-field · A1.9 S-bar/K-bar (+ hand) · A1.10
C1/S-flex/K-flex · A1.11 S-text/K-text (decorationColor), S-bar/K-bar (Card), S-button/K-button (autofocus) ·
A1.12 S-flex/K-flex · A1.13 K-router (kt), D1 + hand (sw).

### Order, and why each boundary
- Each SDK has one build tree: two Swift tasks at once would compile each other's half-written files (same for
  Kotlin). So a group holds one Swift task and one Kotlin task, plus at most a task touching neither SDK.
- 1 → 2: C1 touches both SDKs' tests, so it runs alone, first: fixtures pin the wire props before the drawing.
  D1 cannot sit in G1: engine/test/demo-server.test.ts starts examples/server/index.ts.
- 2 → 3..7 (Swift): S-text adds the absolute-insets modifier to Props.swift (D4); every later Swift task moves
  its own call sites to it (Layout.swift:138,171 · Box.swift:198,210 · Structure.swift:160,167 ·
  Buttons.swift:53 · Input.swift:179).
- 4 → 5 (Kotlin): K-bar reads the can-pop / go-back CompositionLocal that K-router provides in OrcaApp.kt (D6).
- The other boundaries hold only the one-Swift-one-Kotlin rule.

### Seams
- `Style/Props.swift` → S-text only (TextStyleProps keeps `font` and `color`: Input.swift:99,114-115,169-172).
- `OrcaApp.kt` → K-router only (D5 retention and the D6 provider sit in the same NavHost block, :164-187).
- Goldens, one owner each: 3 Kotlin (AppBar height 56, D7) → K-bar; Swift counter-home (64x40 minimum and
  shadow, D11) → S-button; Swift native-widgets-home (border inset) → S-box. Any other golden moving stops the task.

### Findings (planner, checked against the code)
- D4 cannot live in Props.swift alone: `Props.insets` has no layout direction, so S-text adds a modifier that
  reads it and keeps `Props.insets`; each later task switches its call sites (listed above).
- Item 11's "the overload stays": read as "the SDK still never retains or closes a host's router"; D5 replaces
  `popBackStack(ROOT_ROUTE…)` at OrcaApp.kt:181 inside it, and D6's provider sits in its NavHost (166-175).
- Count pins also in message text: ModelRoundTripTests.swift:151, ModelRoundTripTest.kt:176 (C1's files).
- Kotlin PropsTest.kt:132 pins `fade → Clip`, :179 the underline decoration: D3 draws fade in the Text, so
  `Props.overflow` may keep returning Clip.
- A1.5 kt, A1.4 kt and A1.6 kt are already drawn right (Buttons.kt:62-66, Box.kt, Stack.kt): tests only.
- D6's ArrowBack needs no dependency (material-icons-extended, sdk/build.gradle.kts:94).
- No golden moves for Swift images (GoldenTests.swift:60-62 blanks every Image src).

### Done when
test: `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift test` (macOS) ·
`xcodebuild test -scheme OrcaGateway-Package -destination 'platform=iOS Simulator,id=F8CA6558-39C5-42D2-838F-5D04ED93750D'`
in sdk-swift (iPhone 16, iOS 18.5, derived data in the session scratchpad) ·
`cd sdk-kotlin && ./gradlew :core:test :sdk:testDebugUnitTest --console=plain`
lint: `cd sdk && flutter analyze` · `cd sdk-kotlin && ./gradlew build --console=plain` (lint, warnings as errors)
typecheck: none beyond the compilers.
baseline: engine 737 pass 0 fail · Flutter +246 all passed · Swift macOS 234 tests 0 failures · Kotlin core 228,
sdk 132, 0 failures (JDK 25), 2026-11-15, on 5c6b57e.
commits: per task · gate: per group (answered at gate 08, 2026-11-15, under the standing rule: all defaults)

### Not planned
none: all 13 cases placed. The hand halves of A1.9 and A1.13 are run by the main session on D1's page (iOS
simulator and Android emulator) after G5.
