# 09 · Implementation · native-sdk-s7

## Front page

### In one breath
S7 is built on feat/native-sdk-s7: 9 code commits; nothing pushed. Android now draws the counter.
Core gains OrcaClient (412 handshake); `sdk` adds OkHttp, Compose, the 15 widgets and OrcaApp.
141 tests pass (93 core, 48 sdk on Robolectric), lint clean; the example app builds.
Live: the Kotlin client got 412, retried, and loaded the 16-node counter from the real engine.
Not done: the emulator run. This Mac's two emulator images cannot boot (question 1).

### New for you
Nothing new.

### Trade-offs
1 auto-decided: Column and Row follow Flutter's layout rules exactly, where Swift drifts in three
  spots (spaceAround, gap with spaceEvenly, Column baseline). Question 2.
2 auto-decided: the golden passes on Linux x86_64 as on macOS, so CI compares it, not skips it.
  It is drawn on a software canvas (no shadows): Compose's capture hangs under Robolectric.
3 auto-decided: a Material 3 look (tonal ElevatedButton, M3 card colour, TopAppBar), as Flutter's.

### Questions for you
1. The emulator needs Google's API 34 arm64 image, 1.6 GB (arm64-v8a-34_r14.zip, dl.google.com).
   May I reinstall it with sdkmanager for UAT? (default: yes; else you run the app on a device)
2. Add Swift's three flex drifts from Flutter to row 23b.33, after S10? (default: yes)
3. Push and open the S7 PR at stage 10? (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Tasks, status and evidence
| # | Status | Evidence |
|---|---|---|
| S7.1 | done | Core `client/`: `HttpTransport` (interface only), `DeviceInfo` (headers, platform `Android`), `OrcaClient`: GET page with the Flutter headers; on 412 `caps_vector_unknown` one POST retry with `_orcaCapsVector`, never a second; the 426 page as Swift returns it; `executeAction` implements S6's `ActionClient`. T6.3.1 and T6.3.2: Swift's 11 `OrcaClientTests` as `OrcaClientTest` (11). The S6 executor test's left-out HTTP assertions (method, URL, content type, caps hash, platform) are restored through the real client. Commit 71442c0 (ported by a subagent in its own worktree, cherry-picked) |
| S7.2 | done | `:sdk`: Android library on AGP 9.0.1 (built-in Kotlin), compileSdk 36, minSdk 24, Compose BOM 2026.05.01, Material 3, navigation-compose 2.9.2, OkHttp 4.12.0, coroutines 1.9.0; Robolectric 4.17 at SDK 34. `OkHttpTransport` (cancellable; tested against the JDK's HttpServer, 4 tests); `DeviceInfo.current(context)` (dp sizes, density, insets from an attached activity, Android version, locale, time zone; 1 test). `capabilities.json` lists the 15 widgets; Kotlin caps hash `6a68c380…`. Commits 66bead9, 6c1f0be, bf76df5 |
| S7.3 | done | `WidgetBuilders` registry, `NodeView` (each node observes only its watches), `Props`, the 15 widgets in `widgets/` (Flex, Layout, Content, Buttons, Structure). T6.3.5 `UnknownTypeTest` 3; `PropsTest` 14; `FlexLayoutTest` 10; `FallbackPromptTest` 2. Commit 05efc76 (ported by a subagent, reviewed here) |
| S7.4 | done | `OrcaPageModel` (executor on a main-dispatcher scope it owns), `OrcaPageView` (M3 `SnackbarHost`, Android `Toast`), `OrcaApp` (NavHost, loading, error with retry) and `OrcaPageLoader`. T6.3.3 `CounterPageTest` 4 (title, + twice shows 2, Reset shows 0 and "Counter reset to 0" for 4000 ms, toast, long press); `PageModelTest` 6 (Swift's 6); `OrcaAppTest` 2 (handshake and counting through a stub engine; error and retry); T6.3.4 `GoldenTest` 1. Commits 05efc76, f3fbf37 |
| S7.5 | partly | `examples/app-android`: own Gradle build including `../../sdk-kotlin`, one activity, intent extras for URL, app id and path, cleartext in debug only, README. `assembleDebug` builds. The emulator run waits for question 1. Commit 81cd0d5 |
| S7.6 | done | Taskfile `sdk-kotlin:test` (both modules), `sdk-kotlin:build`, `sdk-kotlin:record`, `example:android:build`, `example:android:run`; `sdk-kotlin.yml` runs `./gradlew build` and the example's `assembleDebug` on JDK 17 and 21; README status. Commit ef57d0c |

### Test results
| Where | Result |
|---|---|
| `./gradlew build --rerun-tasks --no-build-cache` (JDK 21) | green in 54 s: core 93 tests in 13 classes, sdk 48 in 11, 0 failures, lint 0 warnings |
| Per class (sdk) | OrcaClientTest 11 (core), PageModelTest 6, CounterPageTest 4, UnknownTypeTest 3, PropsTest 14, FlexLayoutTest 10, FallbackPromptTest 2, GoldenTest 1, OrcaAppTest 2, OkHttpTransportTest 4, AndroidDeviceTest 1, ToolchainSmokeTest 1 |
| `examples/app-android` `:app:assembleDebug` | builds `app-debug.apk` |
| `bun run schema/codegen.ts` | no drift |
| Live, the Kotlin `OrcaClient` with `OkHttpTransport` against `examples/server` on :8097 (a scratch test, deleted) | GET 412, POST 200, page `home` with 16 nodes; second GET 200 (hash known); an unknown server action raises `OrcaActionException` "Server action \"nope\" not found" |
| Recorded counter page with Kotlin's caps (`record-page.ts --sdk kotlin`) | byte-identical to Swift's recording |

### Deliberate differences from Swift
- Flex: a custom layout that follows Flutter's `RenderFlex`, not Compose's Column and Row:
  unbounded main axis for children, `gap` as the Flutter SDK inserts it, exact `spaceAround`,
  Column `baseline` as start, right to left mirrored. Swift differs in the last three (question 2).
- Look: Material 3, as Flutter's. ElevatedButton is the tonal button and reads `elevation`; AppBar
  centres only when `centerTitle` is true; Card uses the M3 elevated-card colour; untyped text is
  `bodyMedium`.
- Text: all six `textAlign` values; `overflow` honoured with clip as the default (Swift always
  ellipsises).
- Unknown types: core already turns them into the warn FallbackPrompt, as Swift does; a type with no
  Compose builder (a plugin's, or core's `_Empty`) draws nothing and logs once.
- Snackbar in the root Scaffold's `SnackbarHost`, shown for its duration (default 4000 ms); toast
  as an Android `Toast` (short up to 2 s, long above). Long press suppresses the tap, as Flutter.
- Client: immutable with `copy(...)`; `transport` is required (core has none); URLs are
  `java.net.URI`; page errors throw `OrcaClientException`, refused actions `OrcaActionException`.
- Navigation, URL, clipboard, share and DevTools wait for S8: `OrcaApp(effectHandler = …)` gets
  those effects; without one they do nothing, and a FallbackPrompt link opens through `UriHandler`.

### The golden (T6.3.4)
`sdk/src/test/resources/goldens/counter-home.png`: 786x1704 px (393x852 dp at 2x), drawn with
Robolectric's native graphics on a software canvas, compared within Swift's tolerance (0.01% of
pixels). Re-record with `./gradlew :sdk:testDebugUnitTest --tests '*GoldenTest*'
-Porca.recordGoldens=true`.

Trade-off 5 at 08 said to compare only where recorded, unless Linux and macOS agree. They do: the
PNG recorded on macOS passed unchanged in an x86_64 Linux container (`eclipse-temurin:21-jdk`, the
SDK mounted read-only, 8 min under emulation), 1 test, 0 skipped. The runtime marker now names only
the Robolectric SDK (`robolectricSdk=34`), so ubuntu CI compares the golden. Commit 9dd23f0.

### Swift UI notes (question 2, not fixed)
- `FlexView` with `gap` and `spaceEvenly` or `spaceAround` places children differently from the
  Flutter SDK; it draws `spaceAround` as `spaceEvenly` and centres a Column's `baseline`.
- A long press on a button probably fires `onTap` too (not checked on a device).
- `Props.color` accepts a leading `+` in the hex; `centerTitle` and ElevatedButton `elevation` are
  ignored; insets map to leading and trailing, so they mirror right to left.
- The client never logs a refused caps vector (the second 412) to DevTools; Dart does. Carry into
  S8.

### Findings worth remembering
- F1 Both emulator images here (API 34 `google_apis` and API 36 `google_apis_playstore`, arm64)
  lack `system.img`, so neither AVD boots ("No initial system image for this configuration").
- F2 AAPT2's Linux build exists only for x86_64; a Linux container on Apple Silicon must run as
  `linux/amd64`.
- F3 AGP 9 runs only the debug unit tests in `build`; the release variant has none.
- F4 The capability vector still advertises navigate, openUrl, copyToClipboard, share and
  serverAction. The core runs them and server actions work; the Android adapters for the other four
  arrive in S8, so on Android they do nothing until then unless the host passes `effectHandler`.
- F5 Two subagents did the ports (the client in its own worktree, the Compose layer here); I
  reviewed the model, view, node observer and client API, wrote the transport, device info,
  OrcaApp, the example and CI, and reran every test.

### For ship (stage 10) to know
Nothing deploys. Push the branch and open the PR. CI: SDK Kotlin (`./gradlew build` and the
example on JDK 17 and 21), Schema (Generated.kt drift), and the workflows whose paths `schema/` or
`examples/` touch. The UAT is the counter on an emulator (question 1).
