# 08 · Tasks · native-parity-s15

## Front page

### In one breath
tasks: 12 in 4 groups · widest group: 6 · cases: 6 of 6 placed (12 cells, Swift and Kotlin)
Plan step 15 on both native SDKs: version check, sessions, analytics, device id, telemetry sink.
G1 (6 at once): key-value store and device id, telemetry sink, batched analytics, per SDK.
G2: sessions with the offline queue and the foreground/background hook. G3: version check, boot
model, OrcaApp's enableOffline and enableSessionTracking. G4: demo switches and docs.
Two rows corrected against Flutter: C15.1 needs enableOffline; C15.2 has no duration.

### New for you
nothing new

### Trade-offs
3 auto-decided: endpoints as OrcaClient extensions; one task per SDK; lifecycle-process declared

### Questions for you
1. Commands: swift build --build-tests + swift test; ./gradlew build (Kotlin tests + lint);
   engine and Flutter in G4 (it touches examples/server). (default: as found)
2. Commits: one per task on feat/native-parity-s15; PR after G4. (default: yes)
3. One gate per group, 4 groups. (default: yes)
4. needs: androidx.lifecycle:lifecycle-process 2.9.4, declared in sdk-kotlin (T8). It is already
   on the classpath through emoji2, so apps get nothing new. (default: yes)
5. Rows C15.1 and C15.2 are rewritten to Flutter's behaviour, with a note. (default: yes)

## Appendix

### Where step 15 comes from
Plan step 15 of /Users/amrebada/.claude/plans/native-parity/plan.md ("Version check, sessions and analytics",
M): `/version` with force update; `/session` start and end; offline session queue; `/events` with the batched
emitter; automatic device id (a random id stored on first run); general telemetry sink. Swift: `scenePhase`
drives sessions. Kotlin: process lifecycle drives sessions. Test rows C15.1-C15.6 in phase-c-tests.md. Stages
01-07 skipped as covered by the plan (the Phase C brief). Branch feat/native-parity-s15 from 5c6b57e (the
user's local main, one commit ahead of origin/main 9706551, still unpushed).

### Checked before planning (2026-11-15)
- Flutter: `OrcaClient.fetchVersion/sendSessionStart/sendSessionEnd/flushOfflineSessions/sendEvents`,
  `VersionChecker`, `OfflineSessionStore`, `OrcaAnalytics`, `OrcaTelemetry`, `_OrcaAppState` (sdk/lib/src).
- Flutter checks `/version` only inside `OrcaApp.preload`, which runs when `enableOffline` is on (or a host
  calls preload): without it no force-update screen ever shows. Row C15.1 becomes "With enableOffline, ...".
- Flutter's session body is `{type, deviceId}`; the engine (engine/src/core/engine.ts handleSession) emits
  onSessionStart / onSessionEnd with its own timestamp. No duration travels. Row C15.2 drops "with its duration".
- Flutter queues a session offline only when the POST throws (a non-2xx is not queued); the flush posts
  `/session/offline` `{deviceId, sessions:[{type,timestamp}]}` and clears on 200.
- Flutter sends a session start on every `resumed`, also after `inactive`; the natives keep one session per
  foreground period (design D4), on purpose.
- `/events` is the cloud's route (Epic 47.4); the OSS engine answers 404, which `sendEvents` reports as false.
- `androidx.lifecycle:lifecycle-process` resolves at 2.9.4 on sdk-kotlin's debugRuntimeClasspath today (emoji2).
- Flutter tests to port: sdk/test/orca_analytics_test.dart (5), version_checker_test.dart (4 version rows),
  device_id_header_test.dart (2).

### Design (written here; 05-07 skipped)
In full in the session scratchpad (`s15/design.md`), pasted to the planner and to every implementer.
- D1 `KeyValueStore` (string get/put, null removes) + `MemoryKeyValueStore`; UI adapters over UserDefaults
  and SharedPreferences "orca_gateway".
- D2 client endpoints `fetchVersion`, `sendSession`, `sendOfflineSessions`, `sendEvents`, through the
  client's `send` (DevTools network events) with its headers; as OrcaClient extensions (no OrcaClient edit).
- D3 `VersionChecker.check(localVersions)` → fresh | stale(names, sorted) | forceUpdate | offline, as Dart.
- D4 `OfflineSessionRecord`, `OfflineSessionStore` (key `orca_offline_sessions`), `SessionTracker`
  (foreground: start + flush, background: end; a throw queues; one session per foreground period).
- D5 `DeviceIdentity.resolve(store)`: key `orca_device_id`, a lowercase random UUID on first run.
- D6 `OrcaAnalytics`: Dart's batch size 20, interval 10 s, buffer 500, re-queue in front, drop oldest,
  injectable clock and scheduler; Kotlin core stays free of kotlinx-coroutines.
- D7 `OrcaTelemetry.onEvent` + `reportUnknownWidgetOnce`, called from `WidgetRegistry.reportUnknown`.
- U1 OrcaApp: `enableOffline` (version check at boot; force update blocks the app with Flutter's text
  "Update required. Please update the app."; the cache arrives with step 14), `enableSessionTracking`
  (scenePhase / ProcessLifecycleOwner), device id resolved when the client has none; a boot model.
- Demo: `ORCA_FORCE_UPDATE=1` on the example server; `ORCA_OFFLINE`, `ORCA_SESSIONS` in both example apps.

### Cases (07 rows of this slice; each has a Swift cell /S and a Kotlin cell /K)
- C15.1 (unit + hand) With enableOffline, a version response with forceUpdate true shows the force-update
  screen and blocks the app.
- C15.2 (unit) A session starts on foreground and ends on background (Flutter sends {type, deviceId}).
- C15.3 (unit) Sessions recorded offline are queued and sent on the next online foreground.
- C15.4 (unit) track() batches by size and interval, re-queues a failed send, drops the oldest past the limit.
- C15.5 (unit) A device id is created once, persists, and is sent as x-orca-device-id.
- C15.6 (unit) The telemetry sink receives unknown_widget_type.

### Groups
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Swift key-value store, device identity | sdk-swift/Sources/OrcaGatewayCore/Client/KeyValueStore.swift (new) · sdk-swift/Sources/OrcaGatewayCore/Client/DeviceIdentity.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/DeviceIdentityTests.swift (new) | C15.5/S | M | — |
| 1 | T2 | Kotlin key-value store, device identity | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/KeyValueStore.kt (new) · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/DeviceIdentity.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/DeviceIdentityTest.kt (new) | C15.5/K | M | — |
| 1 | T3 | Swift OrcaTelemetry, unknown-widget report | sdk-swift/Sources/OrcaGatewayCore/Telemetry/OrcaTelemetry.swift (new) · sdk-swift/Sources/OrcaGatewayCore/Render/PageRenderer.swift · sdk-swift/Tests/OrcaGatewayCoreTests/OrcaTelemetryTests.swift (new) | C15.6/S | M | — |
| 1 | T4 | Kotlin OrcaTelemetry, unknown-widget report | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/telemetry/OrcaTelemetry.kt (new) · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/PageRenderer.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/telemetry/OrcaTelemetryTest.kt (new) | C15.6/K | M | — |
| 1 | T5 | Swift OrcaAnalytics with sendEvents | sdk-swift/Sources/OrcaGatewayCore/Telemetry/OrcaAnalytics.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/OrcaAnalyticsTests.swift (new) | C15.4/S | S | — |
| 1 | T6 | Kotlin OrcaAnalytics with sendEvents | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/telemetry/OrcaAnalytics.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/telemetry/OrcaAnalyticsTest.kt (new) | C15.4/K | S | — |
| 2 | T7 | Swift sessions, offline queue, scenePhase hook | sdk-swift/Sources/OrcaGatewayCore/Client/Sessions.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/SessionTrackerTests.swift (new) · sdk-swift/Sources/OrcaGateway/SessionLifecycle.swift (new) | C15.2/S, C15.3/S | M | T1 |
| 2 | T8 | Kotlin sessions, offline queue, lifecycle-process hook | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/Sessions.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/SessionTrackerTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/SessionLifecycle.kt (new) · sdk-kotlin/gradle/libs.versions.toml · sdk-kotlin/sdk/build.gradle.kts | C15.2/K, C15.3/K | M | T2 |
| 3 | T9 | Swift VersionChecker, boot model, OrcaApp options | sdk-swift/Sources/OrcaGatewayCore/Client/VersionChecker.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/VersionCheckerTests.swift (new) · sdk-swift/Sources/OrcaGateway/OrcaBoot.swift (new) · sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Tests/OrcaGatewayTests/OrcaBootTests.swift (new) | C15.1/S | M | T1, T7 |
| 3 | T10 | Kotlin VersionChecker, boot model, OrcaApp options | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/VersionChecker.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/VersionCheckerTest.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaBoot.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaBootTest.kt (new) | C15.1/K | M | T2, T8 |
| 3 | T13 | Kotlin process-wide session hook test (added at gate 09, group 2, question 3) | sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/SessionLifecycleTest.kt (new) | C15.2/K (hook) | S | T8 |
| 4 | T11 | iOS demo, ORCA_FORCE_UPDATE, Swift docs | examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/README.md · examples/server/static-flows.ts · examples/server/README.md · sdk-swift/README.md | C15.1 hand/iOS (enables) | M | T9 |
| 4 | T12 | Android demo, Kotlin docs | examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · examples/app-android/README.md · sdk-kotlin/README.md | C15.1 hand/Android (enables) | M | T10 |

### Order, and why each boundary
- 1 → 2: T7 and T8 build OfflineSessionStore on the KeyValueStore that T1 and T2 create.
- 2 → 3: the boot model in T9 and T10 resolves the device id with DeviceIdentity from T1/T2 and, with
  enableSessionTracking, builds a SessionTracker and attaches the lifecycle hook from T7/T8.
- 3 → 4: the example apps pass enableOffline and enableSessionTracking, which T9 and T10 add to OrcaApp; the
  READMEs document both. T11 touches examples/server, so the group 4 run includes engine and Flutter.
- VersionChecker sits in T9/T10, not group 1: C15.1's unit check needs it, the boot model and OrcaApp together.
- The foreground/background hook goes in T7/T8 (C15.2 is "starts on foreground, ends on background"); T8 also
  declares androidx.lifecycle:lifecycle-process 2.9.4.

### Seams
none: no file is named by two tasks. OrcaClient.swift/.kt and OrcaRouter.* stay unchanged: fetchVersion,
sendSession, sendOfflineSessions and sendEvents are OrcaClient extensions in the VersionChecker, Sessions and
OrcaAnalytics files, in the same module, through the internal `send` and `endpointURL` / `endpointUrl`. Only
T9/T10 edit OrcaApp.swift/.kt, and only a little (sibling branches edit them too).

### Done when
test: `cd sdk-swift && swift build --build-tests && swift test` · `cd sdk-kotlin && ./gradlew :core:test
:sdk:testDebugUnitTest --console=plain` · lint: `cd sdk-kotlin && ./gradlew build --console=plain` (Swift: 0
warnings from `swift build --build-tests`) · typecheck: none (compilers) · group 4 also `cd engine && bun test`
and `cd sdk && flutter test`.
baseline: Swift macOS 234 tests, 0 failures, 0 warnings · Kotlin `./gradlew build` BUILD SUCCESSFUL, core 228,
sdk 132, 0 failures, lint clean, 2026-11-15 (5c6b57e).
commits: per task (feat/native-parity-s15) · gate: per group (answered at gate 08, 2026-11-15)

### Not planned
none: all 6 cases are placed. T1-T10 hold the 12 unit cells. T11/T12 make the two C15.1 hand cells checkable;
the main session ticks them on the iOS simulator and the Android emulator after group 4 (ORCA_FORCE_UPDATE=1
on the server, ORCA_OFFLINE=1 in the app).
