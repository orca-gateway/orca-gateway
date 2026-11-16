# 08 · Tasks · native-parity-s17-push

## Front page

### In one breath
tasks: 18 in 5 groups · widest group: 5 · cases: 20 of 20 placed (C17.4, C17.5; template P1-P6)
Step 17, plugin 4 of 4: push notifications as their own Swift and Gradle packages, as the map's.
G1 schema and package shells; G2 generated params, the /push page; G3 both plugins, release rows.
G4 the Android demo and README, the iOS token; G5 the iOS demo, docs and READMEs.
FCM on Android; iOS waits on your A/B answer, from T16 on: groups 1-3, T13 and T14 run first.

### New for you
nothing new

### Trade-offs
1 needs you: iOS A Firebase Messaging (as Flutter, my default) vs B APNs only (the plan's words)
1 needs you (plan-approved): Android adds firebase-messaging, the plan's FCM

### Questions for you
1. Commands: as the map slice, the push packages in its place. (default: as found)
2. Commits: one per task on feat/native-parity-s17-push, stacked on PR #51. (default: yes)
3. One gate per group. (default: yes)
4. needs: firebase-messaging in the plugin's Gradle build, the plan's FCM. (default: add)
5. iOS: A Firebase Messaging, FCM token and topics, adds firebase-ios-sdk; B APNs only, no topics.
   Asked 2026-11-16; T16, T12, T15, T17, T18 wait. (default: A)
6. After the merge, yours: mirror repo, key, secret; a Firebase project for the token. (default: ok)

## Appendix

### Where step 17 push comes from
Plan step 17 of /Users/amrebada/.claude/plans/native-parity/plan.md ("Push notifications: APNs on iOS, FCM on Android.
User actions: APNs key, Firebase project."), the user's packaging answer B (2026-11-16), and the design in the session
scratchpad (s17/design-push.md: rows C17.4 and C17.5 checked against Flutter, the package template P1-P6 with push's
names, the plugin N1-N7, the demo D1-D4, the open A/B question). Stages 01-07 were skipped as covered by the plan,
that answer and the voice recorder's template (PR #47). Flutter is the reference:
plugins/orca_push_notification/lib/src/push_notification_plugin.dart (firebase_messaging 15.2.10 on Firebase Android
BoM 33.16.0 and iOS SDK 11.15.0; flutter_local_notifications 18.0.1). The planner's plan below is the map's (PR #51),
task for task, with push's names, plus T16-T18 for the jobs the A/B question splits.

### Repo
Layout and conventions as the map slice (08 of native-parity-s17-map): the three plugin packages under plugins/*/ios
and plugins/*/android are the template; cli/test holds the schema and drift tests; engine/test the demo and release
tests; examples/server the demo pages; examples/app-ios and examples/app-android the demo apps. Commands from
CLAUDE.md and the slices before. No CONSTRAINTS.md.

### Groups
Paths are from the repo root unless they start with /Users/. `PN/` = plugins/orca_push_notification/, `SW/` = PN/ios/Sources/OrcaPushNotification/, `SWT/` = PN/ios/Tests/OrcaPushNotificationTests/, `KT/` = PN/android/push-notification/src/main/kotlin/com/orcagateway/plugins/pushnotification/, `KTT/` = the same path under src/test/, `IOS/` = examples/app-ios/, `AND/` = examples/app-android/.

| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Push schema block, actions only | PN/orca_plugin.yaml (only its `schema:` block and a notes header; the platform, plist and setup blocks stay as Flutter has them) · cli/test/push_notification_schema_test.dart (new) | C17.5/yaml | S | — |
| 1 | T2 | Pub and git ignore native dirs | PN/.pubignore (new) · PN/.gitignore (new) | P-pub | S | — |
| 1 | T3 | Android Gradle package, needs: firebase-messaging | PN/android/settings.gradle.kts (new) · PN/android/gradle.properties (new) · PN/android/VERSION (new) · PN/android/gradlew (new, a symlink to ../../../sdk-kotlin/gradlew) · PN/android/push-notification/build.gradle.kts (new) | P-pkg/K | M | — |
| 2 | T4 | SwiftPM package, generated params types | PN/ios/Package.swift (new) · PN/ios/VERSION (new) · SW/Generated/OrcaPushNotificationTypes.swift (new) · SWT/PushNotificationParamsTests.swift (new; its manifest check pins the SDK dependency by identity, not by count) · cli/test/push_notification_swift_props_test.dart (new) | C17.5/S, P-pkg/S | M | T1 |
| 2 | T5 | Kotlin generated params, drift test | KT/OrcaPushNotificationTypes.kt (new) · KTT/PushNotificationParamsTest.kt (new) · cli/test/push_notification_kotlin_props_test.dart (new) | C17.5/K | M | T1, T3 |
| 2 | T6 | Demo /push page, home button | examples/server/orca_push_notification.ts (new: the CLI's TS output, imports on ../../engine/src/types) · examples/server/custom.ts (/push and "Go to Push Page") · engine/test/push-demo.test.ts (new) · engine/test/voice-demo.test.ts · engine/test/video-demo.test.ts (home's pinned targets gain /push) | C17.4/page | M | T1 |
| 3 | T7 | Swift plugin: permission, notification, tap | SW/PushNotificationPlugin.swift (new: five actions, initialize, the APNs token hand-off) · SW/Notifications.swift (new: the protocol, the UNUserNotificationCenter adapter and delegate) · SW/PushMessaging.swift (new: the protocol only; not named `Messaging`, Firebase's class under A) · SWT/PushNotificationPluginTests.swift (new, fakes) | C17.4/S | M | T4 |
| 3 | T8 | Kotlin plugin, FCM service, Robolectric | PN/android/push-notification/src/main/AndroidManifest.xml (new: POST_NOTIFICATIONS, the messaging service) · KT/PushNotificationPlugin.kt (new: takes a Context; five actions; initialize(activity, onNotificationTap)) · KT/Notifications.kt (new: the interface, the NotificationManagerCompat adapter, the channel, the PendingIntent) · KT/PushMessaging.kt (new: the interface, the FirebaseMessaging adapter, the FirebaseMessagingService) · KTT/PushNotificationPluginTest.kt (new: fakes, Robolectric @Config(sdk = [34]), the merged manifest) | C17.4/K | M | T3, T5 |
| 3 | T9 | release.sh rows 17-18, scratch-repo test | scripts/release.sh · engine/test/launch-release.test.ts | P-release | S | T3, T4 |
| 3 | T10 | Mirror PACKAGES line, LICENSE, rehearsal | scripts/swift-mirror.sh · .github/workflows/sdk-swift-mirror.yml (only its header's list of mirrors and secrets) · PN/ios/LICENSE (new) | P-mirror | M | T4 |
| 3 | T11 | CI matrices gain the push plugin | .github/workflows/native-plugins.yml | P-ci | S | T3, T4 |
| 4 | T13 | Android demo routes taps, needs: google-services | AND/settings.gradle.kts · AND/app/build.gradle.kts (applies the Gradle plugin only when app/google-services.json exists) · AND/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · AND/.gitignore (app/google-services.json) · AND/README.md (the hand check) | C17.4/hand-K, P-firebase/K | M | T6, T8 |
| 4 | T14 | Android README, server README row | PN/android/README.md (new) · examples/server/README.md (its orca_push_notification.ts row) | P-readme/K | S | T6, T8 |
| 4 | T16 | Swift token, topics; A needs: FirebaseMessaging | SW/FirebaseMessagingAdapter.swift under A, or SW/APNsMessaging.swift under B (new: the adapter, and the plugin's default init as an extension) · SWT/PushMessagingTests.swift (new: the adapter, and the manifest's whole dependency list) · PN/ios/Package.swift (A only: firebase-ios-sdk) | C17.4/S-token | M | T7 |
| 5 | T12 | iOS demo links push, routes taps | IOS/OrcaCounter.xcodeproj/project.pbxproj · IOS/OrcaCounter/OrcaCounterApp.swift (register, initialize, hold the router, an app delegate that forwards the APNs token) · IOS/OrcaCounter.entitlements (new, aps-environment development) · IOS/OrcaPushNotification (new, a git symlink to ../../plugins/orca_push_notification/ios) · IOS/README.md (the hand check) | C17.4/hand-S | M | T6, T7, T16 |
| 5 | T15 | Outside repo: walkthroughs, release table | /Users/amrebada/workspace/orca-gateway/docs/User_Actions.md · /Users/amrebada/workspace/orca-gateway/CLAUDE.md (both outside the git repo and not in the PR, as the map's T15) | P-docs | S | T9, T10, T13 |
| 5 | T17 | A only: iOS demo's optional Firebase plist | IOS/.gitignore (OrcaCounter/GoogleService-Info.plist) · IOS/Info.plist (FirebaseAppDelegateProxyEnabled NO) · IOS/OrcaCounter.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved (new, or git-ignored: T17 decides) | P-firebase/S | M | T16 |
| 5 | T18 | iOS and pub READMEs | PN/ios/README.md (new) · PN/README.md (a native apps section) | P-readme/S | S | T7, T14, T16 |

### Order, and why each boundary
- Kind: feature. T1-T15 are the map's tasks with push's names. T16-T18 are new because the A/B question splits three
  jobs and their cases: the Swift plugin is T7 (C17.4/S) and T16 (C17.4/S-token), so most of it runs before the
  answer; the iOS demo is T12 and, under A only, T17; the READMEs are T14 (Android) and T18 (iOS and pub). Push has
  no widget, view or trigger. Nothing changes under schema/ and no generator changes: both generators already handle
  an actions-only schema (checked).
- The answer: groups 1-3, T13 and T14 run before it. T16 (group 4) waits for it, and so do T12, T15, T17 and T18
  (group 5). Under B, T17 drops out and T16 does not touch Package.swift.
- 1 → 2: T4 and T5 run the CLI's `--types-only` on T1's yaml (the five actions' params). Package.swift goes with the
  types, because a SwiftPM target with no sources fails. T5 compiles in T3's build. T6's TS is the CLI's output for
  T1's yaml.
- 2 → 3: T7 and T8 read params through T4's and T5's types, inside those packages. T9 reads T3's and T4's VERSION
  files. T10 splits T4's package. T11 builds and tests both packages.
- 3 → 4: T13 registers T8's plugin and opens T6's /push. T14 documents T8 and T6's TS file. T16 implements T7's
  PushMessaging protocol.
- 4 → 5: T12 needs T16's default init (and, under A, its Firebase package) and T6's /push. T17 pins or ignores the
  Firebase packages Xcode resolves through T16. T18 documents T7 and T16. T15 writes T9's and T10's names and the
  Firebase steps for whichever answer comes.
- Fixed here so tasks agree: the iOS plist goes at IOS/OrcaCounter/GoogleService-Info.plist (a synchronized group:
  Xcode bundles it when present, the pbxproj needs no edit); Android reads app/google-services.json; under A the
  plugin configures Firebase when the plist is in the bundle, so the host imports no Firebase (a difference from
  Flutter, where the host calls initializeApp; T18 says so).
- Baseline edits, each a decision: T6 widens home's targets in voice-demo.test.ts and video-demo.test.ts (map-demo
  pins no home targets, checked); T9 moves the list-end check from row 17 to row 19.
- T3 picks the newest stable firebase-messaging that builds at compileSdk 36 and minSdk 24 (candidate 26.0.2 in BoM
  35.2.0, to confirm). T8 awaits the token Task with suspendCancellableCoroutine (no
  kotlinx-coroutines-play-services in the design). T8: asked before initialize, the Kotlin permission action fails
  with a message naming initialize (T14 says so). T7: the real UNUserNotificationCenter needs an app bundle, so it is
  seen only at hand-S. T16 under A reruns T10's rehearsal on the manifest with Firebase.
- Hand checks: a local notification and its tap through the deep link path (payload `orcacounter://open/map`), on the
  iOS 18.5 simulator and the API 34 emulator, without Firebase; token and topics are said as not seen until the
  user's Firebase project exists.
- The map's 09 findings carry over: Swift 6.2-only APIs under `#if compiler(>=6.2)`, Value params resolved from the
  raw action, hand checks said only as seen. The branch is stacked on PR #51; T6 and T9-T13 edit files #51 touches:
  if #51 changes, rebase before the group that touches them.

### Seams
- PN/orca_plugin.yaml → T1: T4, T5 and T6 generate from it.
- PN/.gitignore and PN/.pubignore → T2: byte-identical to the map's.
- PN/android/push-notification/build.gradle.kts → T3: declares everything T5 and T8 need up front (the sdk as api,
  firebase-messaging, activity and core from the SDK's catalog, the voice recorder's test set with Robolectric).
- PN/ios/Package.swift → T4; under A, T16 is its only other writer (firebase-ios-sdk), two groups later. T4's test
  pins the SDK by identity, so T16 owns the pin on the whole dependency list.
- SW/PushNotificationPlugin.swift → T7: T16 adds the default init as an extension in its own file.
- examples/server/custom.ts → T6: both hand checks open its /push page.
- scripts/release.sh → T9.

### Not planned
none: all 20 cases are placed (the 17 given, with C17.4/S, P-readme and P-firebase each split in two by the answer;
under B, P-firebase/S is not planned: iOS has no Firebase). The user's, not cases: the A/B answer; after the merge
the repo orca-gateway/orca-push-notification-swift, its own deploy key and the secret
ORCA_PUSH_NOTIFICATION_SWIFT_DEPLOY_KEY; a Firebase project (Android's google-services.json; under A the iOS plist and
the APNs key in Firebase; under B the APNs key on the user's server), which the token and topic hand checks wait for;
releasing sdk-swift 0.1.0-alpha.2 and sdk-kotlin before rows 17-18. A follow-up: taps on notifications the system
showed in the background, and cold starts from any tap, reach nothing, as in Flutter's plugin (N5).

### Done when
test: `cd cli && dart test` · `cd engine && bun test` · `cd sdk && flutter test` · `cd sdk-swift && swift build
--build-tests && swift test` · `cd sdk-kotlin && ./gradlew build --continue --console=plain` · the voice, video and
map packages (`swift test`, `./gradlew build`) · from G2: `cd plugins/orca_push_notification/ios && swift build
--build-tests && swift test` (and `xcodebuild test` on the iOS 18.5 simulator before the PR) · `cd
plugins/orca_push_notification/android && ./gradlew build --continue --console=plain`
lint: `dart analyze` in cli/ · `flutter analyze` in sdk/ · 0 Swift warnings · Kotlin explicitApi and warnings as
errors (in the build) · typecheck: the builds
baseline: cli 51 · engine 828 pass · Flutter 543, analyze clean · sdk-swift 604 · Kotlin BUILD SUCCESSFUL · voice
Swift 24, video Swift 26, map Swift 28 (27 on the iOS 18.5 simulator), the three Gradle builds green · both demo
apps build · generators: no drift (feat/native-parity-s17-map on main 3880607, 2026-11-16)

commits: per task (feat/native-parity-s17-push, stacked on PR #51) · gate: per group (answered at gate 08, 2026-11-16, standing rule) · needs: firebase-messaging added (plan step 17) · question 5 answered A by the user, 2026-11-16 (relayed by the parent session: "PR 50 and 51 merged, go with your recommendation"): T16, T12, T15, T17, T18 go
