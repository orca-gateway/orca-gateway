# 09 · Implementation · native-parity-s15

## Front page

### In one breath
group 4 of 4 · tasks: 2 green, 0 blocked · cases: 6 of 6 green on both SDKs, C15.1 also by hand
engine 737 · Flutter 246 · Swift 284 + SwiftUI 62 · Kotlin core 286, sdk 143: all green.
T11: ORCA_FORCE_UPDATE on the demo server, iOS demo switches, Swift README section.
T12: Android demo switches, Kotlin README section.
By hand, both platforms: force update blocks the app (only /version called); option off loads
the page; sessions log start, end on Home, start on return, one device id.

### New for you
nothing new

### Trade-offs
3 auto-decided: the server flag only for "1"; one boolean-extra convention on Android; the
server README now lists all three ORCA_* flags

### Questions for you
1. `A` approves the stage; then ship: rebase on origin/main, push feat/native-parity-s15, open
   the step 15 PR (default: go)

## Appendix

### Group 1
Commits (staged by path): T2 2d8f831 · T1 313a3f9 · T4 1774445 · T3 e145e15 · T6 7112b41 · T5 2c0861c (after the gate's retry).
Gate 08 approved under your standing rule. Swift tasks ran one at a time, as did Kotlin tasks (one Swift and
one Kotlin at once): a red test file of one task breaks the shared test target's compile for another.

#### Task T1 · Swift key-value store, device identity
Files: `sdk-swift/Sources/OrcaGatewayCore/Client/KeyValueStore.swift` · `Client/DeviceIdentity.swift` ·
`Tests/OrcaGatewayCoreTests/DeviceIdentityTests.swift`
Cases: C15.5/S → green (7 tests) · baseline unchanged (`swift test` 241 = 234 + 7). Red first: compile.
Changed: `KeyValueStore` protocol (nil removes) and an NSLock `MemoryKeyValueStore` with a `values` snapshot;
`DeviceIdentity.resolve`: the saved id, or a new lowercase UUID saved under `orca_device_id`. Tests: one id over
two calls, the same id after a restart, a new id for missing or empty, the format, the header for nil and "".
Decisions: 1. Dart's two header cases ported; they pass on today's client (red only through the compile).
Review fit: pass
Review quality: pass
Not done: UserDefaults adapter and OrcaApp wiring (T9).

#### Task T2 · Kotlin key-value store, device identity
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/KeyValueStore.kt` · `client/DeviceIdentity.kt` ·
`core/src/test/kotlin/com/orcagateway/core/client/DeviceIdentityTest.kt`
Cases: C15.5/K → green (7 tests) · baseline unchanged (`:core:test` 235 = 228 + 7; `:core:build` clean).
Changed: `KeyValueStore` interface, a synchronized `MemoryKeyValueStore` with `snapshot()`; `object DeviceIdentity`
with `STORAGE_KEY` and `resolve`. Tests as T1's, plus the header on the request sent through StubEngine.
Decisions: 1. A saved non-empty id is returned as is (design) · 2. Lock as WidgetRegistry's.
Review fit: pass
Review quality: pass
Not done: SharedPreferences adapter and OrcaApp wiring (T10).

#### Task T3 · Swift OrcaTelemetry, unknown-widget report
Files: `sdk-swift/Sources/OrcaGatewayCore/Telemetry/OrcaTelemetry.swift` · `Render/PageRenderer.swift` (+2 lines) ·
`Tests/OrcaGatewayCoreTests/OrcaTelemetryTests.swift`
Cases: C15.6/S → green (4 tests) · baseline unchanged (`swift test` 245 = 241 + 4). Red first: compile, then 3 of
4 failing until the renderer hook.
Changed: `enum OrcaTelemetry` (`onEvent`, `reportUnknownWidgetOnce`, `resetForTesting`), state in three private
statics behind an NSLock, sink called outside the lock; `WidgetRegistry.reportUnknown` calls it.
Decisions: 1. Called on every unknown render, telemetry dedups (Flutter component_renderer.dart:168) · 2. Reset
clears only the seen set, as Dart.
Review fit: pass
Review quality: a private `@unchecked Sendable` storage box, a second pattern beside OrcaDebug's statics, fixed
Not done: nothing.

#### Task T4 · Kotlin OrcaTelemetry, unknown-widget report
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/telemetry/OrcaTelemetry.kt` · `core/render/PageRenderer.kt`
(one call + comment) · `core/src/test/kotlin/com/orcagateway/core/telemetry/OrcaTelemetryTest.kt`
Cases: C15.6/K → green (5 tests) · baseline unchanged (`:core:test` 240 = 235 + 5; `:core:build` clean).
Changed: `object OrcaTelemetry` (`@Volatile onEvent`, lock-guarded seen set, `resetForTesting`);
`WidgetRegistry.reportUnknown` calls it. Tests incl. 16 threads reporting one type once.
Decisions: 1. Called every time, telemetry dedups (as T3) · 2. Fully qualified call, no import line.
Review fit: pass
Review quality: pass
Not done: nothing.

#### Task T5 · Swift OrcaAnalytics with sendEvents
Files: `sdk-swift/Sources/OrcaGatewayCore/Telemetry/OrcaAnalytics.swift` · `Tests/OrcaGatewayCoreTests/OrcaAnalyticsTests.swift`
Cases: C15.4/S → green (15 tests, stable over 8 runs) · baseline unchanged (`swift test` 260 = 245 + 15).
Changed: `OrcaAnalytics` (track, flush, dispose, bufferedCount, forClient; one armed timer; a full buffer flushes
in a Task; a failed batch back in front, then trim), `OrcaScheduler` (cancel closure), `OrcaClient.sendEvents`
through the internal `send`. Tests: Dart's 5 + timer, in-flight flush, order, ts, sendEvents statuses and throw.
Decisions: 1. ts from whole ms via `DateParts(epochMillis:)` · 2. Tests await a fire-and-forget flush through an
internal `backgroundFlush` · 3. The scheduler is called under the lock; documented: the action runs later.
Review fit: pass
Review quality: ts rebuilt a UTC calendar by hand beside `DateParts`, fixed; then a test-only `ThrowingTransport`
repeating `DownTransport` (DevToolsEventTests.swift:27), fixed on the gate's retry (fit pass, quality pass)
Not done: nothing.

#### Task T6 · Kotlin OrcaAnalytics with sendEvents
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/telemetry/OrcaAnalytics.kt` ·
`core/src/test/kotlin/com/orcagateway/core/telemetry/OrcaAnalyticsTest.kt`
Cases: C15.4/K → green (18 tests) · baseline unchanged (`:core:test` 258 = 240 + 18; `:core:build` clean).
Changed: `OrcaScheduler` (cancel function; default one daemon thread), `OrcaAnalytics` (as T5; fire-and-forget via
stdlib `startCoroutine`), `suspend fun OrcaClient.sendEvents` through the internal `send`.
Decisions: 1. A fire-and-forget flush whose sender throws drops the batch (Dart's unawaited future) · 2. sendEvents
is false on any error; only cancellation goes up · 3. ts via GregorianCalendar(UTC) + String.format.
Review fit: pass
Review quality: ts used java.time, missing below API 26 while minSdk is 24 (track() would crash on Android 7), fixed
Not done: nothing. Found: a `= runSuspend { … }` JUnit 5 test ending in a value is skipped silently; checked:
every existing core class runs all its declared tests.

### Group 2
Commits (staged by path): T7 9606fe9 · T8 78b0f78. Group 1's card approved under your standing rule (T5 retried
once and passed both reviews: 2c0861c).

#### Task T7 · Swift sessions, offline queue, scenePhase hook
Files: `sdk-swift/Sources/OrcaGatewayCore/Client/Sessions.swift` · `Tests/OrcaGatewayCoreTests/SessionTrackerTests.swift` ·
`Sources/OrcaGateway/SessionLifecycle.swift`
Cases: C15.2/S, C15.3/S → green (14 tests) · baseline unchanged (`swift test` 274 = 260 + 14). Red first: compile.
Changed: `OfflineSessionRecord`, `OfflineSessionStore` (key `orca_offline_sessions`, NSLock, clock; corrupt → []),
`actor SessionTracker` (foreground: start once per foreground period, a throw queues it, then flush; background: end
once; flush with an in-flight guard), `OrcaClient.sendSession` / `sendOfflineSessions` through `send`; an internal
scenePhase modifier (.active → foreground, .background → background, foreground on appear).
Decisions: 1. Flush on every foreground (Dart flushes on every resumed) · 2. "Network back" tested with a second
tracker on a working client over the same store.
Review fit: a public `View.orcaSessionTracking` the design lacks, fixed (internal; OrcaApp is the only switch)
Review quality: pass
Not done: no unit test of the modifier (scenePhase cannot be driven host-less on macOS); T9 and the hand check.

#### Task T8 · Kotlin sessions, offline queue, lifecycle-process hook
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/Sessions.kt` · `core/src/test/.../client/SessionTrackerTest.kt` ·
`sdk/src/main/kotlin/com/orcagateway/sdk/SessionLifecycle.kt` · `gradle/libs.versions.toml` · `sdk/build.gradle.kts`
Cases: C15.2/K, C15.3/K → green (17 tests) · baseline unchanged (core 275 = 258 + 17; sdk 132; lint clean).
Changed: the same core types as T7; `ProcessSessions`, one tracker and one `ProcessLifecycleOwner` observer per
process (baseUrl + appId + deviceId) in a process-lifetime scope; internal `@Composable SessionTracking(client,
deviceId, offline)` for T10; `androidx.lifecycle:lifecycle-process` 2.9.4 declared (still 2.9.4 on the classpath).
Decisions: 1. Registry key baseUrl + appId + deviceId · 2. Flush guard lifted in `finally` · 3. Whole queue cleared
after a 200, as Swift and Dart (question 2).
Review fit: the hook died with the composition, so a late ON_STOP never ended the session, fixed (process-wide);
flushed only on the opening foreground, unlike Swift and Flutter, fixed
Review quality: a `detach()` nothing called and an attach guard that never fired, fixed
Not done: no sdk test of the hook (question 3); OrcaApp wiring is T10's.

### Group 3
Commits (staged by path): T13 7d0ce03 · T9 b9b7fa1 · T10 460ddd9. Group 2's card approved under your standing rule
(question 2 at its default: keep Flutter's whole-queue clear; question 3: T13 added).

#### Task T9 · Swift version check, boot model, OrcaApp options
Files: `sdk-swift/Sources/OrcaGatewayCore/Client/VersionChecker.swift` · `Tests/OrcaGatewayCoreTests/VersionCheckerTests.swift` ·
`Sources/OrcaGateway/OrcaBoot.swift` · `Sources/OrcaGateway/OrcaApp.swift` · `Tests/OrcaGatewayTests/OrcaBootTests.swift`
Cases: C15.1/S → green (VersionCheckerTests 10, OrcaBootTests 8) · baseline unchanged (core 284 = 274 + 10). Red first: compile.
Changed: `VersionResponse`, `OrcaClient.fetchVersion()` through `send`, `VersionChecker.check` (forceUpdate first, stale
sorted, any throw offline); public `UserDefaultsKeyValueStore`; internal `@MainActor OrcaBootModel` (checking | ready |
forceUpdate, one memoized SessionTracker), `OrcaBootView`, the force-update text with id `orca.forceUpdate`; both OrcaApp
inits gain `enableOffline` and `enableSessionTracking`; init(client:) sets a device id from the store when the client has none.
Decisions: 1. Boot model internal · 2. The model takes the client at start (init(router:) builds its router lazily) ·
3. A cancelled check counts as offline, so the app boots · 4. /version decoded through `JSONValue`, as every response.
Review fit: pass
Review quality: decoded with Foundation's JSONDecoder, the only one in Sources, beside JSONValue everywhere else, fixed
Not done: the hand check (group 4).

#### Task T10 · Kotlin version check, boot model, OrcaApp options
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/VersionChecker.kt` · `core/src/test/.../client/VersionCheckerTest.kt` ·
`sdk/src/main/kotlin/com/orcagateway/sdk/OrcaBoot.kt` · `sdk/.../OrcaApp.kt` · `sdk/src/test/.../OrcaBootTest.kt`
Cases: C15.1/K → green (VersionCheckerTest 11, OrcaBootTest 7) · baseline unchanged (core 286 = 275 + 11, sdk 143 =
136 + 7; lint clean). Red first: compile.
Changed: the same core types (`@Serializable VersionResponse`; cancellation rethrown); public `SharedPreferencesKeyValueStore`
("orca_gateway"); internal `OrcaBoot` model with Compose state and `OrcaBootView` (spinner, force-update text with testTag
`orca.forceUpdate`, or the NavHost; SessionTracking when enabled); both OrcaApp overloads gain the two options; the NavHost
body moved unchanged into a private `OrcaNavHost`.
Decisions: 1. Unknown keys ignored, as Dart and Swift (a new server key must not read as offline) · 2. /version through the
router's client as built (the engine reads no device header there) · 3. `remember(client)`: enableOffline read once, as initState.
Review fit: the boot model's stale and offline answers had no test, fixed
Review quality: pass
Not done: the hand check (group 4).

#### Task T13 · Kotlin process-wide session hook test
Files: `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/SessionLifecycleTest.kt`
Cases: C15.2/K (hook) → green (4 tests) · baseline unchanged (sdk 136 = 132 + 4). Red first: none (a test of T8's code).
Changed: Robolectric tests over ProcessLifecycleOwner: start on ON_START, end on ON_STOP, one tracker per key, and a late
ON_STOP still ends the session after the composition is gone.
Decisions: none.
Review fit: pass
Review quality: pass
Not done: nothing.

### Group 4
Commits (staged by path): T12 96bafe0 · T11 fbf5422. Group 3's card approved under your standing rule (go).

#### Task T11 · iOS demo, ORCA_FORCE_UPDATE, Swift docs
Files: `examples/app-ios/OrcaCounter/OrcaCounterApp.swift` · `examples/app-ios/README.md` · `examples/server/static-flows.ts` ·
`examples/server/README.md` · `sdk-swift/README.md`
Cases: C15.1 hand/iOS → enabled, then run (below) · baseline unchanged (swift test 284; iOS example builds; engine 737).
Changed: static-flows answers forceUpdate when `ORCA_FORCE_UPDATE=1`; the iOS example reads ORCA_OFFLINE and ORCA_SESSIONS
("1" or "true") through one `isOn` helper; app-ios README "Version check and sessions"; the server README gains a table of
its three ORCA_* flags; sdk-swift README "Sessions, analytics and version check".
Decisions: 1. The flag is on only for exactly "1" · 2. The server table lists all three flags · 3. One `isOn` helper.
Review fit: pass
Review quality: pass
Not done: the scheme does not list the two settings (README: Edit Scheme or SIMCTL_CHILD_*); the demo-server test
does not clear ORCA_FORCE_UPDATE (no test reads static-flows /version).

#### Task T12 · Android demo, Kotlin docs
Files: `examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt` ·
`examples/app-android/README.md` · `sdk-kotlin/README.md`
Cases: C15.1 hand/Android → enabled, then run (below) · baseline unchanged (`:app:assembleDebug` OK, warnings as errors).
Changed: boolean extras ORCA_OFFLINE and ORCA_SESSIONS (as ORCA_DEVTOOLS) into OrcaApp; app-android README "Force update
and sessions" (extras, adb lines, the console lines to look for); sdk-kotlin README, the twin section.
Decisions: 1. READMEs also explain the offline queue and the SDK screen vs the server's 426 page · 2. ORCA_PATH home
explicit · 3. Wording checked against the Swift twin at review (both quality reviews: no mismatch).
Review fit: pass
Review quality: pass
Not done: nothing.

### Hand checks (main session, 2026-11-15)
Server: `PORT=8094 ORCA_FORCE_UPDATE=1`. Devices: iOS simulator "Orca PhaseC iPhone 16 Pro" (iOS 26.5), Android AVD
"Orca_PhaseC_API_34" (both Phase C's own, beside the siblings'). Screenshots: scratchpad `s15/hand/`.
C15.1 iOS and Android: static-flows with the offline option shows "Update required. Please update the app."; the server
logs only GET /version, no page. Control, option off: the static-flows home page loads; no /version request.
Sessions (C15.2, beyond its unit check): iOS and Android each log start, end after Home, start on return, one device id.
Android ends a session only after ProcessLifecycleOwner's 700 ms (a quick return keeps it open, as designed).

### Test run
Group 4: engine `bun test` 737 pass, 0 fail · Flutter `flutter test` +246: All tests passed · Swift `swift build
--build-tests` 0 warnings, `swift test` 284, 0 failures · `xcodebuild test -only-testing:OrcaGatewayTests` (Phase C
simulator, iOS 26.5) 66 executed, 4 skipped (golden snapshots with no image for this runtime, as before), 0 failures ·
Kotlin `./gradlew build` BUILD SUCCESSFUL, core 286, sdk 143, 0 failures, 0 skipped · both example apps build.
Earlier groups: G3 Swift 284 / Kotlin 286, 143 · G2 274 / 275, 132 · G1 260 / 258, 132. All green.
Failures: none. Files changed: the tasks' files only.

### Blocked
none (every finding in groups 3 and 4 was fixed on its one rework pass)

### Not done
none

### For ship (stage 10) to know
Android apps get androidx.lifecycle:lifecycle-process 2.9.4 declared by the SDK (it was already resolved through
emoji2). OrcaApp gains `enableOffline` and `enableSessionTracking` (both off by default) on both SDKs, and two public
stores, `UserDefaultsKeyValueStore` and `SharedPreferencesKeyValueStore`. No config, env or migration; `/events` is the
cloud's route and answers 404 on the OSS engine, which sendEvents reports as false.
