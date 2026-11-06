# 08 · Tasks · native-sdk-s7

## Front page

### In one breath
S7 is 23b.27b, Swift's S2 in Kotlin: the HTTP client with the 412 handshake, an Android library
`sdk` with Compose, the 15 core widgets, OrcaApp, snackbar and toast, and an example app.
Done: the counter counts on the Pixel 3a emulator, and T6.3 (Swift's T2) is green on ubuntu.
The executor and render tree came with S6, so S7 is the client, the views and the app.

### New for you
Nothing new.

### Trade-offs
1 needs you: the client's logic goes in core behind a transport interface, as in Swift; OkHttp
  only in `sdk`. Default: yes. Alternative: all of OrcaClient in `sdk`.
2 needs you: UI tests run on the JVM with Robolectric (taps on the counter, one golden); no
  emulator in CI, the emulator run is your UAT. Default: yes. Alternative: an emulator CI job.
3 needs you: `examples/app-android` is its own Gradle build that includes `sdk-kotlin`, as app-ios
  points at sdk-swift by path. Default: yes. Alternative: a module inside `sdk-kotlin`.
4 auto-decided: AGP 9.0.1, Compose BOM 2026.05.01, OkHttp 4.12.0 (cached); Robolectric downloads.
5 auto-decided (memory, Swift S2 golden): the golden compares only where it was recorded.

### Questions for you
1. Android floor: minSdk 24 (Android 7.0), compile and target SDK 36? (default: yes)
2. UAT on the Pixel 3a API 34 emulator, the server on :8097 (Docker holds 8080). (default: yes)
3. Branch feat/native-sdk-s7 from main, S6's close commits first. (default: yes, done)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Where S7 comes from
`.pipeline/native-sdk-s6/08-tasks.md`, slice plan: S7 Compose UI is "`sdk` Android library: OkHttp
`OrcaClient` with the 412 handshake, Compose renderer, the 15 core widgets, `OrcaApp` with NavHost,
toast; `examples/app-android` counter on an emulator (S2)", done when "T6.3 green; counter runs on
the Pixel 3a API 34 emulator". Stage 07 of native-sdk: T6 repeats T1 to T4 in Kotlin, Compose UI
tests with Robolectric. Epic row 23b.27b.

### What Swift's S2 had, and what S7 takes
| Swift S2 (23b.15-19) | Kotlin S7 |
|---|---|
| `OrcaClient`, `HTTPTransport`, `DeviceInfo` in core (245 + 86 + 68 lines) | Same split: core `client/`; `OkHttpTransport` and `DeviceInfo.current(context)` in `sdk` |
| Render tree and reducers for the counter (23b.16) | Already in core from S6 (`PageRenderer`, the executor's 15 kinds) |
| SwiftUI: `NodeView`, `OrcaPageModel`, `OrcaApp`, `Props`, Widgets (Layout, Content, Buttons, Structure), about 850 lines | Compose: `NodeView`, `OrcaPageModel`, `OrcaApp`, `Props`, the same four widget files |
| One NavigationStack, toast overlay | `NavHost` with the one page route (navigation actions are S8), Material 3 `SnackbarHost`, `Toast` |
| `examples/app-ios` (xcodeproj, path dependency) | `examples/app-android` (Gradle build including `../../sdk-kotlin`) |
| macOS UI job | Robolectric on ubuntu, plus the example's `assembleDebug` |

The 15 widgets (Swift's S2 list): AppBar, Card, Center, Column, Divider, ElevatedButton,
FallbackPrompt (basic card; S9 adds the looks and policies), OutlinedButton, Padding, Row, Scaffold,
SingleChildScrollView, SizedBox, Text, TextButton. They go into `sdk-kotlin/capabilities.json`, so
`Generated.kt` and the Kotlin caps hash change in this slice.

### Tasks for S7
| # | Task | Acceptance criteria |
|---|------|---------------------|
| S7.1 | Core `client/`: `HttpTransport` interface, `DeviceInfo`, `OrcaClient`: GET `/api/v1/app/{appId}/page/{path}` with the Flutter headers; on 412 `caps_vector_unknown`, one POST retry with `_orcaCapsVector`, never a second; the 426 page returned as Swift does; `executeAction` implements S6's `ActionClient`. | T6.3.1 and T6.3.2: Swift's 11 `OrcaClientTests` on the JVM against a stub transport (handshake A to E, other 412s, app state in both bodies, errors, URL join, headers with platform `Android`, fractional sizes, empty device id). |
| S7.2 | `sdk` module: Android library (namespace `com.orcagateway.sdk`), Compose BOM, Material 3, navigation-compose, OkHttp, coroutines; `OkHttpTransport`; `DeviceInfo.current(context)` (dp sizes, density, insets, locale, timezone, Android version). `capabilities.json` gains the 15 widgets; `Generated.kt` regenerated. | `./gradlew :sdk:assembleRelease` with no warnings; `CapabilitiesTest` still green with the new hash. |
| S7.3 | Compose renderer: registry from type to builder, `NodeView` subscribing to its own watches, `Props` (#RRGGBB and #RRGGBBAA colours, four-side insets, flex alignment, gap), the 15 widgets with a Material 3 look, unknown types drawn as nothing with one warning per type. | T6.3.5: an unknown type does not throw, takes no space, warns once. Props unit tests. |
| S7.4 | `OrcaPageModel` and `OrcaApp`: loading and error states, the executor on the main dispatcher, `showSnackbar` in a `SnackbarHost`, `showToast` as a `Toast`, other effects to a host callback (S8 wires them). | T6.3.3 (Robolectric): the counter page, recorded with Kotlin's caps, has the title "Counter Example"; + twice shows 2; Reset shows 0 and the snackbar "Counter reset to 0". Swift's page-model cases. T6.3.4: one golden of the counter page (trade-off 5). |
| S7.5 | `examples/app-android`: one Activity hosting `OrcaApp`; server URL, app id and path from intent extras, defaulting to `http://10.0.2.2:8080`, `counter`, `home`; cleartext only in debug; README. | Runs on the Pixel 3a API 34 emulator against `examples/server`: + counts, Reset shows the snackbar. |
| S7.6 | Taskfile: `sdk-kotlin:test` runs both modules; `sdk-kotlin:record` records the Kotlin test pages (`record-page.ts --sdk kotlin`). `sdk-kotlin.yml` adds the Robolectric tests and the example build, paths gain `examples/app-android/**`. `sdk-kotlin/README.md` status. | Green on the S7 PR, JDK 17 and 21. |

### Trade-off 1: where the client lives
Swift keeps `OrcaClient` in the pure core behind `HTTPTransport`, so its handshake tests run on Linux.
The same here keeps `sdk-core` free of OkHttp and runs T6.3.1 and T6.3.2 as plain JUnit, the way S6's
tests run. `OkHttpTransport` is about 40 lines in `sdk`. Alternative: OkHttp in the client itself,
whose tests then need Robolectric or a mock server.

### Trade-off 2: UI tests
Robolectric runs Android code on the JVM, so Compose UI tests can tap the counter's buttons on
ubuntu in about a minute, without an emulator. Swift could not tap in its tests and relied on the
golden plus a manual run. An emulator job (`reactivecircus/android-emulator-runner`) costs about 10
minutes per PR and is often flaky. The emulator run stays a manual UAT step, as the iOS simulator
was for S2.

### Trade-off 5: the golden
The memory "swift-golden-runtime" says to compare a golden only on the runtime that recorded it,
because rendering belongs to that runtime. Robolectric's native graphics mode renders with its own
Skia, so Linux and macOS may agree; 09 checks this. If they differ, the golden is recorded on ubuntu
and skipped elsewhere, so CI keeps comparing it.

### Tests (T6.3, Swift's T2 in Kotlin)
T6.3.1 handshake and errors, T6.3.2 headers (JUnit, core). T6.3.3 counter taps and snackbar,
T6.3.4 one golden, T6.3.5 unknown type (Robolectric, `sdk`). The counter page is recorded from the
Bun server with Kotlin's caps vector into `sdk-kotlin/sdk/src/test/resources/pages/`. The core's 82
tests keep running.

### Findings while planning
F1 The Gradle cache holds AGP 8.12 to 9.0.1, Compose BOM 2026.05.01 (UI 1.11.2, Material 3 1.4.0),
   navigation-compose 2.9.2, activity-compose 1.10.1, OkHttp 4.12.0 and coroutines-android 1.9.0.
   Robolectric, the Compose UI test artifacts and the Compose compiler for Kotlin 2.4.0 are not
   cached; they download from Maven Central and Google.
F2 AGP 9 compiles Kotlin itself (built-in Kotlin) and needs Gradle 9.1 or later and JDK 17; the
   wrapper is 9.7.1. The Compose compiler plugin version follows Kotlin (2.4.0).
F3 The Android SDK here has platforms 28 to 36 and build-tools to 36.0.0; ubuntu runners ship an
   Android SDK, so CI needs no emulator and no SDK install step.
F4 The engine reads `x-orca-platform` as `iOS` or `Android` (`request-info.ts:32`).
F5 The emulator reaches the host at `10.0.2.2`. Docker holds 8080 here, so UAT uses :8097.

### CI
`sdk-kotlin.yml`: one job per JDK runs `./gradlew build` (core, sdk unit tests with Robolectric,
lint off for now), then `assembleDebug` in `examples/app-android`. Paths: `sdk-kotlin/**`,
`schema/**`, `examples/app-android/**`, the workflow.

### Wire format
Unchanged. Kotlin's capability vector gains 15 widgets (a codegen output `schema.yml` checks).
`record-page.ts` gains `--sdk kotlin`.

### Commits on feat/native-sdk-s7 (conventional)
1. chore(pipeline): native-sdk-s6 gates 10 and 12, S6 closed (done: c4216b0, 91c6b79)
2. chore(pipeline): native-sdk-s7 stage 08
3. feat(sdk-kotlin): OrcaClient and the 412 handshake in core (S7.1)
4. build(sdk-kotlin): the Android library module sdk (S7.2)
5. feat(sdk-kotlin): Compose renderer and the 15 widgets (S7.3)
6. feat(sdk-kotlin): OrcaApp, page model, snackbar and toast (S7.4)
7. feat(examples): app-android counter (S7.5)
8. ci(sdk-kotlin): Robolectric and the example on ubuntu (S7.6)
9. chore(pipeline): stage 09 onward

### Not in S7
Navigation, system and server-action adapters, DevTools (S8). FallbackPrompt looks, the three
policies, the 426 page drawn, the ten extra widgets, theme hooks (S9). Maven Central (S10).
