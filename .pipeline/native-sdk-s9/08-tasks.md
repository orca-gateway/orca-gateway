# 08 · Tasks · native-sdk-s9

## Front page

### In one breath
tasks: 15 in 4 groups · widest group: 7 · cases: 38 of 40 placed (P1, P2 green since S7)
S9 is 23b.27d, Swift's S4 in Kotlin. The FallbackPrompt look and the 426 page exist since S7;
S9 adds their tests, the ten widgets and the host button theme. Done: T6.5 green, then
capability-demo and native-widgets run on the Pixel 3a at stage 10.
Group 1 (7 in parallel): degrade tests, style readers, Expanded/Spacer, TextField, gestures,
image loader. Group 2 (5): warn/require goldens, Container, Stack, Image, Icon.
Group 3: one task registers and advertises the ten. Group 4: native-widgets golden; OrcaTheme.

### New for you
nothing new

### Trade-offs
1 needs you: images; a small loader on the SDK's OkHttp (default) or Coil, a new library.
2 auto-decided from memory: OrcaTheme as Swift's (host style only on unstyled buttons);
  an unknown widget stays a FallbackPrompt in every build.
4 auto-decided: Expanded/Spacer join the existing flex layout; Stack is a custom layout as
  Flutter's; TextField sets state, then onChange per keystroke; one task registers all ten.

### Questions for you
1. Commands: `cd sdk-kotlin && ./gradlew build --console=plain`, lint inside. (default: as found)
2. Commits: one per task on feat/native-sdk-s9, as in S8; nothing pushed. (default: per task)
3. One gate per group? (default: yes, 4 gates)
4. needs: material-icons-extended 1.7.8 for Icon; BOM-pinned, already cached. (default: yes)
5. Images: the built-in OkHttp loader, no host hook in S9 (trade-off 1). (default: yes)

## Appendix

### Where S9 comes from
`.pipeline/native-sdk-s6/08-tasks.md`, slice plan: S9 is "FallbackPrompt, the three policies,
the 426 page; Icon, Image, Container, Expanded, Spacer, TextField, Stack, Positioned, ClipRRect,
GestureDetector; theme hooks (S4)", done when "T6.5 green; capability-demo and native-widgets
run". Epic row 23b.27d. T6.5 is the umbrella's T4 (07) in Kotlin, plus Swift S4's T4.4-T4.6.
Swift's S4 as built (`.pipeline/native-sdk-s4/09-implementation.md`) is the reference; its tests
give the case ids below, as S8 used Swift's S3 tests. S9 started on the default "go" accepted
at native-sdk-s8 gate 12 (A); branch feat/native-sdk-s9 from main (with PR #15's commits).

### Cases (Swift S4 tests, ported; I and C are new for Kotlin)
- P FallbackPromptTests: P1 an allowed link is an openUrl effect, P2 a blocked scheme does
  nothing (both green since S7), P3 without a router the link opens directly, P4 under the
  router the system opens it.
- D DegradeTests on engine recordings: D1 graceful strips the node and keeps its siblings, D2
  warn prepends a banner and keeps the page, D3 require replaces the page with one blocking
  prompt, D4 a 426 draws the upgrade page it carries, D5 a 426 without a page stays an error,
  D6 another status with a page stays an error.
- G goldens: G1 the warn page, G2 the require page, G3 the native-widgets home page.
- W NativeWidgetTests and IconNamesTests: W1 flex shares the space left by flex, W2 gaps come
  before the share and a Spacer pushes to the end, W3 a Column shares height and stretches
  across, W4 a Container fills only the axis its parent forces, W5 alignment names follow
  Flutter, W6 radii from a number or four corners, W7 clip off unless asked, W8 BoxDecoration
  reads every Flutter field, W9 corner radii capped at half the shorter side, W10 every Flutter
  icon name (Dart's map, read at test time) has a Material icon, W11 an unknown name draws a
  filled circle, W12 an edit sets state on `stateKey` then fires onChange with {value}, W13
  edits run in typing order, W14 a field with no binding fires nothing.
- K StackTests: K1 the Stack is as big as its largest child and centres it, K2 Positioned
  children sit by their edges, K3 fit expand fills what it is offered, K4 the native-widgets
  heart toggles its icon, K5 the Positioned spec follows Flutter's edge rules, K6 each gesture
  fires its trigger, and only gestures that have actions are attached.
- H OrcaThemeTests: H1 the host styles a button the server left plain, H2 a server style prop
  wins, H3 the theme travels down the tree.
- I (new) I1 the loader fetches a URL once over OkHttp, decodes it and serves the next request
  from memory; a failed or undecodable load gives no bitmap. I2 a network Image draws the
  bitmap, fit cover by default, `alt` as the content description.
- C (new) C1 capabilities.json lists the same 25 widgets as Swift's, and Generated.kt matches;
  C2 `WidgetBuilders.standard()` has a builder for exactly the advertised widgets.

### Groups
Paths under `sdk-kotlin/` unless they start with `examples/` or `Taskfile.yml`; `main/` is
`sdk/src/main/kotlin/com/orcagateway/sdk/`, `test/` is `sdk/src/test/kotlin/com/orcagateway/sdk/`,
`res/` is `sdk/src/test/resources/`.
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | S9.1 | FallbackPrompt link without and under a router | `test/FallbackPromptTest.kt` | P3, P4 | S | none |
| 1 | S9.2 | Degrade policies and 426 on recordings | `core/src/test/kotlin/com/orcagateway/core/render/DegradeTest.kt` (new), `res/pages/degrade-{graceful,warn,require,426}.json` (new, 4) | D1-D6 | M | none |
| 1 | S9.3 | Flutter alignment, radii, clip and BoxDecoration | `main/style/Props.kt`, `main/style/Decoration.kt` (new), `test/style/PropsTest.kt`, `test/style/DecorationTest.kt` (new) | W5-W9 | M | none |
| 1 | S9.4 | Expanded and Spacer join FlexMeasurePolicy | `main/widgets/Flex.kt`, `test/widgets/FlexLayoutTest.kt` | W1-W3 | S | none |
| 1 | S9.5 | TextField: local text, setState, onChange | `main/widgets/Input.kt` (new), `test/widgets/TextFieldTest.kt` (new) | W12-W14 | S | none |
| 1 | S9.6 | GestureDetector, only the gestures with actions | `main/widgets/Gesture.kt` (new), `test/widgets/GestureDetectorTest.kt` (new) | K6 | S | none |
| 1 | S9.7 | Image loader on the SDK's OkHttp | `main/client/ImageLoader.kt` (new), `test/client/ImageLoaderTest.kt` (new) | I1 | S | none |
| 2 | S9.8 | Goldens of the warn and require pages | `test/GoldenTest.kt`, `res/goldens/degrade-warn.{png,runtime}` (new), `res/goldens/degrade-require.{png,runtime}` (new) | G1, G2 | M | S9.2 |
| 2 | S9.9 | Container and ClipRRect on Flutter's decoration | `main/widgets/Box.kt` (new), `test/widgets/BoxTest.kt` (new) | W4 | S | S9.3 |
| 2 | S9.10 | Stack and Positioned following RenderStack | `main/widgets/Stack.kt` (new), `test/widgets/StackTest.kt` (new) | K1, K2, K3, K5 | S | S9.3 |
| 2 | S9.11 | Image widget: fit, alignment, alt | `main/widgets/Image.kt` (new), `test/widgets/ImageTest.kt` (new) | I2 | S | S9.3, S9.7 |
| 2 | S9.12 | Icon on Flutter's names (needs: material-icons-extended) | `main/widgets/Icon.kt` (new), `main/style/IconNames.kt` (new), `test/style/IconNamesTest.kt` (new), `sdk/build.gradle.kts`, `gradle/libs.versions.toml` | W10, W11 | M | S9.7 |
| 3 | S9.13 | Register and advertise the ten widgets | `main/WidgetBuilders.kt`, `capabilities.json`, `core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt`, `core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt`, `test/WidgetBuildersTest.kt` (new) | C1, C2 | M | S9.4-S9.6, S9.9-S9.12 |
| 4 | S9.14 | native-widgets page: recording, heart, golden | `Taskfile.yml`, `res/pages/native-widgets-home.json` (new), `test/NativeWidgetsPageTest.kt` (new), `res/goldens/native-widgets-home.{png,runtime}` (new) | K4, G3 | M | S9.13, S9.8 |
| 4 | S9.15 | OrcaTheme button styles and the READMEs | `main/style/OrcaTheme.kt` (new), `main/widgets/Buttons.kt`, `test/style/OrcaThemeTest.kt` (new), `README.md`, `examples/app-android/README.md` | H1, H2, H3 | M | S9.13 |
Group 1 has seven tasks: they launch as four, then three, in the plan's order.

### Order, and why each boundary
- 1 → 2: S9.9, S9.10 and S9.11 use S9.3's alignment, radii, clip and BoxDecoration readers;
  S9.11, and S9.12 for Icon `src` (drawn before `name`, as Flutter does), load through S9.7's
  loader; S9.8 draws the warn and require pages S9.2 records.
- 2 → 3: S9.13 registers in `standard()` the composables S9.4-S9.6 and S9.9-S9.12 create, and
  advertises the ten only once they draw: the registry, the caps list and Generated.kt change in
  one step.
- 3 → 4: S9.14 records native-widgets through the 25-widget caps (with the old 15, graceful would
  strip the ten) and draws it with the full registry; its golden uses the compare S9.8 exposes.
  S9.15's READMEs list the 25 widgets and how to run native-widgets.

### Seams
- `main/WidgetBuilders.kt`, `capabilities.json`, `Generated.kt` (`bun run
  schema/gen-native-capabilities.ts`) → S9.13.
- `main/style/Props.kt` → S9.3: every reader two widgets share lands there in group 1; a reader
  one widget needs (BoxFit, Stack fit, InputDecoration) stays in that widget's file.
- `Taskfile.yml` → S9.14, which adds the five `sdk-kotlin:record` lines. S9.2 runs its four
  `record-page.ts capability-demo degrade … --sdk kotlin` commands by hand (`--policy
  graceful|warn|require`; `--min-sdk 99.0.0 --sdk-version 0.1.0` for the 426). The degrade page
  holds core widgets and a Checkbox only, and recordings carry no caps hash, so S9.14's
  re-record leaves those four files unchanged.
- `test/GoldenTest.kt` → S9.8. Both READMEs → S9.15.
- Until S9.13 lands, a widget test builds its model as UnknownTypeTest does (its own type in
  `WidgetRegistry(types = …)`, registered on `WidgetBuilders.standard()`); layout cases drive the
  measure policies directly, as FlexLayoutTest does. `test/support/Pages.kt` is not touched.
- The four degrade recordings live once, in `res/pages/`; the core DegradeTest reads them by
  repo path through `Fixtures.text`, as it reads the schema fixtures.

### Findings while planning
F1 Kotlin draws FallbackPrompt with Flutter's colours and sends its CTA through the URL policy
   since S7 (P1, P2), and core's `OrcaClient.upgradeRequiredPage` returns the 426 page, but no
   test covers it yet (D4-D6).
F2 The warn wrapper puts the root Scaffold inside a Column. Kotlin's Scaffold already bounds an
   unbounded axis to the window (`Structure.kt` `boundedBy`), so G1 needs no layout change;
   Flutter still throws there (Swift S4 question 3).
F3 `examples/server/record-page.ts` takes `--sdk kotlin`, `--policy` and `--min-sdk`; the
   capability-demo `degrade` page and `native-widgets.ts` exist since Swift's S4.
F4 `WidgetBuilders` is internal: a host cannot swap the Image builder today, so S9 ships only the
   built-in loader (question 5). A public builder hook would be its own row.
F5 The Compose BOM 2026.05.01 pins material-icons-extended at 1.7.8, the version in the local
   Gradle cache, so question 4 downloads nothing here; R8 drops the unused icons from an app.
F6 `schema/widget-registry.json` already lists android in all ten widgets' targets.

### Done when
test: `cd sdk-kotlin && ./gradlew build --console=plain` (compile with warnings as errors, core
and sdk tests, lint) · lint: inside that build (`:sdk:lintDebug`) · typecheck: none (the Kotlin
compile is in the build) · baseline: BUILD SUCCESSFUL, core 106 and sdk 71 tests green, lint 0
issues, 2026-11-07 (run with `--rerun-tasks`).

### Not planned
- P1, P2: green since S7 (`theCallToActionIsAnOpenUrlEffect`, `aUrlThePolicyRefusesDoesNothing`).
- T4.3: rewritten at Swift S4 gate 08 (FallbackPrompt in every build, DevTools as the cue);
  green since S8 (DevToolsReportingTest, a FallbackPrompt once per type).
- U1: stage 10, by hand on the Pixel 3a: capability-demo with its degrade page, native-widgets,
  and each policy live via `ORCA_FALLBACK_POLICY=warn|require` and `ORCA_MIN_SDK_VERSION=99.0.0`.

### Commits on feat/native-sdk-s9 (conventional, per task on your yes to question 2)
1. chore(pipeline): native-sdk-s9 stage 08
2. one `test(sdk-kotlin): …` or `feat(sdk-kotlin): … (S9.n)` commit per task, in group order
3. chore(pipeline): stage 09 onward

### Not in S9
Maven Central (S10). A public builder hook. The DevTools server's compression reply (S8 F1).
Keeping the page stack across rotation. 23b.33 (after S10).
