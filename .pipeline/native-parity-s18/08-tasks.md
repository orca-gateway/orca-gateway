# 08 · Tasks · native-parity-s18

## Front page

### In one breath
tasks: 13 in 7 groups · widest group: 2 · cases: 5 of 5 placed (10 cells, Swift and Kotlin)
Plan step 18 on both native SDKs: Flutter's error screens per status, host boot views, colour
scheme and locale, UnsupportedWidgetPlaceholder, a request timeout. One Swift + one Kotlin
task per group. G1 error mapping in the cores; G2 the error screens; G3 host views + theme;
G4 timeout; G5-G6 the placeholder; G7 demos, READMEs, then the hand checks.

### New for you
nothing new

### Trade-offs
3 auto-decided: five rows corrected to what Flutter does (evidence notes); Scaffold pages stay
light as Flutter's do; the natives keep "Try again" on page errors (Flutter has none)

### Questions for you
1. Commands: as step 16 (Swift test + SwiftUI target, ./gradlew build; engine, Flutter, cli
   and both example builds at G7). (default: as found)
2. Commits: one per task on feat/native-parity-s18 (stacked on PR #34); PR after G7. (default: yes)
3. One gate per group, 7 groups. (default: yes)
4. C18.5: Flutter declares a 30 s timeout and never applies it. Fix Flutter too (a Flutter
   behaviour change, so yours to decide)? (default: not now; the natives honour theirs)
5. Send the app's locale (not the device's) in x-orca-locale on all three SDKs? (default: no)

## Appendix

### Where step 18 comes from
Plan step 18 of /Users/amrebada/.claude/plans/native-parity/plan.md ("App shell, theming and error screens", M, 1
widget): custom loading, splash, error and force-update views; status-specific error screens (401, 403, 404, 429,
5xx, offline); dark mode and locale passed through the SDK; UnsupportedWidgetPlaceholder; request timeout option.
Swift: view-builder parameters on OrcaApp. Kotlin: composable slot parameters. Rows C18.1-C18.5 in phase-c-tests.md.
Stages 01-07 skipped as covered by the plan (the Phase C brief). Branch feat/native-parity-s18 from
feat/native-parity-s16 (PR #34, open; restacked on its head 797ae75 after its rebase onto main 82e9027).

### Checked before planning (2026-11-16)
A read-only pass over Flutter and both natives (session scratchpad `s18/design.md`, "Flutter facts", with file:line).
Flutter: OrcaApp `loadingWidget`, `splashWidget`, `errorBuilder(Object)`, `forceUpdateBuilder()` (orca_app.dart:71-124),
boot-only; buildOrcaError's mapping (orca_error.dart:6-87), used for boot and page errors, no retry;
OrcaMaterialAppConfig theme/darkTheme/themeMode/locale reach MaterialApp only, x-orca-locale is the device locale
(orca_client.dart:277), most builders wrap a light `ThemeData()`; UnsupportedWidgetPlaceholder substituted only on web,
a wire widget elsewhere (fixture render/17); OrcaClient.timeout (30 s) declared, never applied.

### Row corrections (to write into phase-c-tests.md with the evidence)
- C18.1: host loading, splash, error and force-update views at boot (Flutter's four); pages keep the SDK's defaults.
- C18.2: boot and page errors use Flutter's titles and messages per 401/403/404/429/5xx, other status, configuration
  error, connection failed (Flutter's "offline": a string match on the transport error; the natives use typed
  transport errors) and the default. The natives keep their "Try again" on page loads.
- C18.3: the colour scheme and locale passed to OrcaApp reach the SDK's screens and pages; Scaffold pages stay light
  as in Flutter; x-orca-locale stays the device locale as in Flutter.
- C18.4: the natives advertise UnsupportedWidgetPlaceholder and draw it as Flutter does when the server sends it
  (fixture 17); an unknown type stays FallbackPrompt.
- C18.5: Flutter declares 30 s and never applies it; the natives gain the option and honour it (default 30 s).

### Design (written here; 05-07 skipped)
Session scratchpad `s18/design.md`: D1 error mapping in the cores (`OrcaErrorInfo`: kind, title, message, Flutter's
words), D2 the error screen (icon, title, message; theme colours), D3 host boot views (Swift AnyView closures
`loadingView`, `splashView`, `errorView(Error)`, `forceUpdateView`; Kotlin composable slots `loading`, `splash`,
`error(Throwable)`, `forceUpdate`), D4 colour scheme and locale (Swift `colorScheme`, `locale`; Kotlin `colorScheme`,
`locale`; Scaffold pinned light), D5 the placeholder (capabilities, generator, Flutter's look), D6 the timeout (Swift
`timeout: TimeInterval = 30`, Kotlin `timeoutMillis: Long = 30_000`).

### Cases (07 rows of this slice; each has a Swift cell /S and a Kotlin cell /K)
C18.1 (ui) host boot views · C18.2 (ui) error screens per status · C18.3 (ui + hand) colour scheme and locale ·
C18.4 (ui) UnsupportedWidgetPlaceholder · C18.5 (unit) request timeout.

### Groups
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Swift core error mapping | sdk-swift/Sources/OrcaGatewayCore/Client/OrcaErrorInfo.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/OrcaErrorInfoTests.swift (new) | C18.2/S mapping | S | — |
| 1 | T2 | Kotlin core error mapping | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/OrcaErrorInfo.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/OrcaErrorInfoTest.kt (new) | C18.2/K mapping | S | — |
| 2 | T3 | Swift error screen per status | sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Sources/OrcaGateway/OrcaBoot.swift · sdk-swift/Tests/OrcaGatewayTests/ErrorScreenTests.swift (new) · sdk-swift/Tests/OrcaGatewayTests/AppBootTests.swift · sdk-swift/Tests/OrcaGatewayTests/OrcaAppPluginTests.swift | C18.2/S screen | M | T1 |
| 2 | T4 | Kotlin error screen per status | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaBoot.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/ErrorScreenTest.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppPluginTest.kt | C18.2/K screen | M | T2 |
| 3 | T5 | Swift host views, theme, locale | sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Sources/OrcaGateway/OrcaBoot.swift · sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · sdk-swift/Tests/OrcaGatewayTests/AppShellTests.swift (new) | C18.1/S, C18.3/S | M | T3 |
| 3 | T6 | Kotlin host views, theme, locale | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaBoot.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Structure.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/AppShellTest.kt (new) | C18.1/K, C18.3/K | M | T4 |
| 4 | T7 | Swift request timeout option | sdk-swift/Sources/OrcaGatewayCore/Client/OrcaClient.swift · sdk-swift/Sources/OrcaGatewayCore/Client/HTTPTransport.swift · sdk-swift/Tests/OrcaGatewayCoreTests/RequestTimeoutTests.swift (new) | C18.5/S | M | T1 |
| 4 | T8 | Kotlin request timeout option | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/OrcaClient.kt · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/HttpTransport.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/client/OkHttpTransport.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/OrcaClientTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/client/OkHttpTransportTest.kt | C18.5/K | M | T2 |
| 5 | T9 | Kotlin placeholder drawn as Flutter | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Content.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/UnsupportedWidgetPlaceholderTest.kt (new) | C18.4/K look | S | — |
| 5 | T10 | Swift placeholder drawn as Flutter (split by hand at 09: the Swift caps hash pin is a sixth file) | sdk-swift/Sources/OrcaGateway/Widgets/Content.swift · sdk-swift/Tests/OrcaGatewayTests/UnsupportedWidgetPlaceholderTests.swift (new) | C18.4/S look | S | — |
| 6 | T11 | Kotlin placeholder advertised and registered | sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/UnsupportedWidgetPlaceholderTest.kt | C18.4/K advertised, fixture 17 | M | T9 |
| 6 | T14 | Swift placeholder advertised and dispatched (split from T10 by hand at 09; StructureWidgetTests added by hand at 09: its 31-widget pin moves, six files) | sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · sdk-swift/Tests/OrcaGatewayTests/UnsupportedWidgetPlaceholderTests.swift · sdk-swift/Tests/OrcaGatewayTests/StructureWidgetTests.swift | C18.4/S advertised, fixture 17 | M | T10 |
| 6 | T15 | Placeholder demo page on the example server (added at 09 by hand: the demo page the plan asks for per step) | examples/server/capability-demo.ts · examples/server/index.ts | C18.4 hand (enables) | S | none |
| 7 | T12 | iOS demo, Swift README sections | examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/README.md · sdk-swift/README.md | C18.3 hand/S (enables, plus 404/401/offline/splash) | M | T5 |
| 7 | T16 | Swift Scaffold page draws its light background and bar under a dark scheme (added at 09 by hand: found by T12 on the simulator, a T5 regression) | sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · sdk-swift/Tests/OrcaGatewayTests/AppShellTests.swift | C18.3/S (fix) | S | T5 |
| 7 | T13 | Android demo, Kotlin README sections | examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · examples/app-android/README.md · sdk-kotlin/README.md | C18.3 hand/K (enables, plus the same) | M | T6 |

### Order, and why each boundary
- One Swift and one Kotlin task per group (shared test targets and build dirs; example apps build the SDK).
- C18.2 per SDK splits into the core mapping (T1/T2) and the screen (T3/T4); C18.4/K into the look (T9) and the
  registration (T11): one task each would pass five files.
- 1 → 2: the screens draw T1/T2's OrcaErrorInfo. Kotlin: SerializationException is an IllegalArgumentException, as is
  the plugin conflict: T2 maps only decode errors to "Configuration Error"; T4 shows the conflict under "Something Went
  Wrong" with its own message.
- 2 → 3: the host `errorView` / `error` receives the error the boot phases carry after T3/T4; both edit OrcaApp/OrcaBoot.
- 3 → 4: T7/T8 assert a timeout maps to "Connection Failed" (T1/T2); they wait only for the lane rule.
- 4 → 5 → 6: G5 draws the placeholder on each SDK (T9, T10); G6 advertises it on both (T11 registers T9's composable,
  T14 dispatches T10's view; the Swift caps hash pin and the drawn-if-advertised check move with them); they share G6 because the advertised
  widget lists of both SDKs are pinned equal (31 on main after PR #32, then 32) and builders must equal the advertised list.
- 6 → 7: the demos pass T5/T6's views and colour scheme; the READMEs document G2-G4. G7's run adds the engine,
  Flutter and cli suites and both example builds.

### Seams
none: no file is named by two tasks of one group. OrcaApp/OrcaBoot go to T3 then T5 (Swift), T4 then T6 (Kotlin);
OrcaClient and the transports only to T7/T8. One generator run writes both Generated files; T10 commits Generated.swift,
T11 Generated.kt (each depends only on its own capabilities.json).

### Done when
test: `cd sdk-swift && swift build --build-tests && swift test` (0 warnings) · `cd sdk-swift && xcodebuild test -scheme
OrcaGateway-Package -destination 'id=04AFD6DE-2948-48F6-B402-1C3B39FEB88A' -only-testing:OrcaGatewayTests` · `cd
sdk-kotlin && ./gradlew build --console=plain` · at G7 also `cd engine && bun test`, `cd sdk && flutter test`, `cd cli
&& dart test && dart analyze`, both example builds
lint: in the Gradle build; Swift warnings counted · typecheck: none
baseline: engine 740 · Flutter 308 · cli 27, analyze clean · Swift core 325, 0 warnings · SwiftUI on 04AFD6DE (iOS
26.5) 157 run, 4 golden skips, 4 of main's tests failing as on origin/main alone (AppBarCardTests A1_9 ×3, ButtonTests
D11; they pass on the iOS 18.5 simulator CI uses) · Kotlin core 327, sdk 234 · both example apps build (restacked on PR
#34's head 797ae75 after its second rebase, 2026-11-16)
Green at 09: the task's cases pass and nothing that passed here fails.

commits: per task (feat/native-parity-s18) · gate: per group (answered at gate 08, 2026-11-16, standing rule)

### Not planned
none: all 5 cases are placed (10 cells); the main session runs the hand checks after G7 and ticks the rows.
Left out by default: Flutter applying its declared timeout (question 4); x-orca-locale from the app locale (question 5).
