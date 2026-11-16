# 09 · Implementation · native-parity-s17-push

## Front page

### In one breath
group 4 of 5 · tasks: 4 green, 0 blocked · cases: 16 of 20 green · engine bun test: 843 pass
T13 Android demo: the push build, taps through its own deep-link path, Firebase file optional.
T14 Android README: install, register, the five actions, Firebase as the app's; the server row.
T16 Swift token and topics on Firebase Messaging from 12.17.0; the APNs token handed on arrival.
T19 the yaml now says a tap without a payload hands "", as Flutter does.
Rebased onto main 4a7f389 (PR #52), no conflict. Two review findings (T16), both fixed.

### New for you
nothing new

### Trade-offs
10 auto-decided (minor, your standing rule); one is the parent session's: Firebase iOS 12.17.0+,
its deprecation warning accepted.

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 5 of 5, T12 iOS demo, T15 walkthroughs, T17 iOS plist, T18 iOS README? (default: go)

## Appendix

### Group 1
#### T1 · Push schema block, actions only (cdb8d703)
Files: PN/orca_plugin.yaml (its `schema:` block and a notes header, appended) · cli/test/push_notification_schema_test.dart (new)
Cases: C17.5/yaml → green (`cd cli && dart test` 54 = 51 + 3, `dart analyze` no issues; red first: all 3 on "has a
schema: section"; 15 hand mutations each caught: order, required, default, enum, a type, a param added or dropped, raw
vs resolved, what an action writes, a `widgets:` key; the yaml restored, cmp)
Changed: `schema.actions` only, Flutter's five in its order: requestNotificationPermission {statusKey, tokenKey,
scope=app} and getNotificationToken {tokenKey=fcmToken, scope=app} read raw (a non-string fails the action);
showLocalNotification {title="", body="", payload}, subscribeToTopic and unsubscribeFromTopic {topic} resolved as
values; each says what it writes; the test pins it against push_notification_plugin.dart by structure
Decisions: `required` only on topic (an empty topic does nothing) · scope `enum: [page, app]` as the voice's raw scope
(both minor, auto-decided); no generator test or stub reads this yaml; the TS types raw keys `Value | string` (CLI's)
Review fit: pass · Review quality: pass
#### T2 · Pub and git ignore native dirs (0e775cbf)
Files: PN/.pubignore (new) · PN/.gitignore (new)
Cases: P-pub → green (red first: dummies ios/T2_DUMMY.txt and android/T2_DUMMY.txt in the `flutter pub publish
--dry-run` archive, and `git check-ignore` ignored none of the six build outputs; green: the dummies out, all six
ignored, android/build/ by the root .gitignore, ios/Package.swift, android/settings.gradle.kts and lib/ not ignored;
the dry run from "Publishing" on as at baseline: 1 warning, no 0.2.1 CHANGELOG entry, 1 hint, exit 65 both)
Changed: both copied from the map's, byte-identical (cmp); the push package had neither, nothing to merge
Decisions: copied exactly · dummies deleted by their exact paths · pubspec.lock, rewritten by each dry run, restored
(all minor, auto-decided)
Review fit: pass · Review quality: pass
#### T3 · Android Gradle package, needs: firebase-messaging (45b32680; 31050c84 gate change)
Files: PN/android/{settings.gradle.kts, gradle.properties, VERSION, gradlew (a symlink to ../../../sdk-kotlin/gradlew),
push-notification/build.gradle.kts} (all new)
Cases: P-pkg/K → green (`./gradlew build --continue` BUILD SUCCESSFUL on the empty module; red first: "should contain one
of the possible settings files"; throwaway files compiled every API T8 needs and a Robolectric runTest, then were
deleted; explicitApi, -Werror and lint NewApi breakages each failed the build; map, video, voice still green). Gate
change: a throwaway getToken call failed the build on 26.0.2 (deprecated, -Werror) and compiled on 25.0.2
Changed: the map's build with push's names; no Compose; the sdk and activity-compose 1.10.1 as api; firebase-messaging
25.0.2 (a constant, "not newer: from 25.1.0 getToken is deprecated"); coroutines stay 1.9.0; the voice's test set
Decisions: firebase-messaging 25.0.2, the gate's default (was needs you vs 26.0.2) · `kotlin.jvm apply false` so AGP
compiles with the SDK's Kotlin 2.4 · activity as api (minor)
Review fit: pass · Review quality: pass (the gate change: pass · pass)

### Group 2
#### T4 · SwiftPM package, generated params types (b106a5a8, ba44435d rework)
Files: PN/ios/{Package.swift, VERSION, SW/Generated/OrcaPushNotificationTypes.swift, SWT/PushNotificationParamsTests.swift}
(new) · cli/test/push_notification_swift_props_test.dart (new)
Cases: C17.5/S, P-pkg/S → green (`swift test` 6, 0 warnings from a clean build; `xcodebuild test` on the iOS 18.5
simulator 5, the manifest test macOS only; cli 56; red first: "No types at …", no Package.swift, "target … is empty")
Changed: the map's manifest with push's names (tools 5.9, iOS 16 / macOS 13, the SDK by path in the monorepo, else
orca-gateway-swift from 0.1.0-alpha.2); VERSION 0.1.0-alpha.1; the CLI's types unedited (five params types); the test
pins raw keys and scope, resolved params as strings (a Value nil, left in the raw action), the five names in Flutter's
order, both manifest branches with the SDK by identity and the other source absent (no dependency count, for T16)
Decisions: action order pinned through the params type names · no count in the manifest check (both minor)
Review fit: pass · Review quality: per-target product checks the siblings lack, fixed (two real drifts still red)
#### T5 · Kotlin generated params, drift test (4c84d828)
Files: KT/OrcaPushNotificationTypes.kt (new) · KTT/PushNotificationParamsTest.kt (new) ·
cli/test/push_notification_kotlin_props_test.dart (new)
Cases: C17.5/K → green (the push Gradle build with PushNotificationParamsTest 6/6, lint, explicitApi, warnings as errors;
the drift test 1/1; cli 56; sdk-kotlin green; red first: "Unresolved reference 'RequestNotificationPermissionParams'"
and "No types at …")
Changed: the CLI's --types-only output unedited (five `*Params(action: JsonObject)`, every param `String?`); the test pins
Flutter's five names each to its params class, each param set, raw keys and scope (a non-string key null), resolved
params as strings, a Value object or a number null and left in the raw action for T8, absent and null null
Decisions: no action-name list in the Kotlin types: "exactly five, in order" rests on T1's pin and the drift test ·
plain JUnit and reflection as the voice's and map's (both minor, auto-decided)
Review fit: pass · Review quality: pass
#### T6 · Demo /push page, home button (edd49a80)
Files: examples/server/orca_push_notification.ts (new) · examples/server/custom.ts · engine/test/push-demo.test.ts (new) ·
engine/test/voice-demo.test.ts · engine/test/video-demo.test.ts
Cases: C17.4/page → green (engine 832 pass, 0 fail = 828 + 4; red first: 6 fails, the 4 push tests (/push 404, no home
button) and the 2 exact home pins; examples/server tsc 36 → 47 errors, all of kinds already present: the generated
interfaces against `custom:${string}`, the builders in onTap, `Custom("navigate")`)
Changed: the CLI's TS output but its import; home's "Go to Push Page" after "Go to Video Page"; /push ("Push
Notifications"): five buttons through the generated builders (statusKey pushStatus, tokenKey pushToken, scope app;
"Orca push", "Tap to open the map", payload orcacounter://open/map; topic news), "Permission:" and "Token:" Texts on
app state; the test pins each action exactly, the Texts' watches and the home button
Decisions: voice-demo's and video-demo's exact home pins gain /push, still exact (a baseline edit) · pushStatus and
pushToken declared in app scope, initial "" · no scroll, as the voice and video pages (all minor, auto-decided)
Review fit: pass · Review quality: pass

### Group 3
#### T7 · Swift plugin: permission, notification, tap (1c72e189; eb89fbd8, f8fd71ef, 8bdae715, 6ab9db64 reworks)
Files: SW/PushNotificationPlugin.swift · SW/Notifications.swift · SW/PushMessaging.swift · SWT/PushNotificationPluginTests.swift (new)
Cases: C17.4/S → green (`swift test` 22 = 6 + 16, 0 warnings from a clean build; `xcodebuild test` on the iOS 18.5 simulator
21; red first "cannot find type 'PushNotificationPlugin'"; 15 one-line mutations each red; each rework red first)
Changed: Flutter's name and five actions; statusKey, tokenKey, scope raw (a non-string fails), title, body, payload,
topic resolved; id = current seconds; no payload taps as "" (Flutter's `payload ?? ''`); initialize(onNotificationTap:)
takes the notification center's delegate, asks alert, badge, sound, registers for remote notifications; a foreground
remote notification with an alert or a sound is shown as a local one, its data as JSON; the APNs hand-off; seams internal
Decisions: initialize on the instance · RemoteNotificationRegistration internal, for T16 · the foreground rule as
firebase_messaging builds it · seams internal over the brief's "public init" (all minor, auto-decided)
Review fit: nil tap payload, fixed; a sound-only push dropped: blocked, retried, fixed; digest wording, fixed · Review
quality: a bare try?, fixed; public seams: blocked, retried, fixed
#### T8 · Kotlin plugin, FCM service, Robolectric (a9c94038; 0e1bd458 rework)
Files: PN/android/push-notification/src/main/AndroidManifest.xml · KT/PushNotificationPlugin.kt · KT/Notifications.kt ·
KT/PushMessaging.kt · KTT/PushNotificationPluginTest.kt (all new)
Cases: C17.4/K → green (push Gradle build: PushNotificationPluginTest 23/23, PushNotificationParamsTest 6/6, explicitApi,
warnings as errors, lint 0 errors; red first "Unresolved reference 'Notifications'"; 23 mutations each red)
Changed: POST_NOTIFICATIONS and PushMessagingService (FCM picks it over Firebase's); the five actions as T7's; API 33+
asks POST_NOTIFICATIONS unless held, below 33 the switch decides; fails before initialize or twice at once; initialize
(activity, onNotificationTap): the channel, the launcher, a new-intent listener; orca_default_channel / high, the app
icon, a tap intent with `payload ?: ""`; the service shows foreground notification messages, their data as JSON
Decisions: the foreground check as firebase_messaging's · no coroutines-play-services · a stateless service, showing
foreground messages even before initialize (T14's README says so) · a pending answer kept for the recreated activity (all minor)
Review fit: pass · Review quality: initialize kept a destroyed activity's launcher (a leak; a request in the gap wedged later ones), fixed (26 tests)
#### T9 · release.sh rows 17-18, scratch-repo test (9d99991e)
Files: scripts/release.sh · engine/test/launch-release.test.ts
Cases: P-release → green (launch-release 7 pass, also under /bin/bash 3.2.57; red first "index out of range: 17"; engine
833 = 832 + 1, 0 fail; `bash -n` clean; shellcheck the same 3 SC2005 notes as baseline, none on touched lines)
Changed: two rows appended, nothing else: 17 `orca_push_notification-ios` (mirror), 18 `orca_push_notification-android`
(maven); the script derives the mirror orca-gateway/orca-push-notification-swift, ORCA_PUSH_NOTIFICATION_SWIFT_MIRROR_URL,
com.orcagateway:orca-push-notification and "the orca_push_notification Swift mirror"; the test: both VERSION files, a
missing-mirror stop, then a full stubbed release of 17 and 18 against a local bare mirror
Decisions: the voice, video and map list-end checks move from row 17 to 19, still as strict (three baseline tests: all
three had `not 17)`) · T15's walkthrough title fixed by the missing-mirror run (both minor, auto-decided)
Review fit: pass · Review quality: pass
#### T10 · Mirror PACKAGES line, LICENSE, rehearsal (f9317bf3, e84304f4 rework)
Files: scripts/swift-mirror.sh · .github/workflows/sdk-swift-mirror.yml (header, comments) · PN/ios/LICENSE (new)
Cases: P-mirror → green (SC/s17p/t10/rehearse.sh 13 of 13, the map's 12 plus L, LICENSE byte for byte the map's; red first
"tag must start with one of …", then "the split has no LICENSE"; rerun with T7's sources at e84304f4: 13 of 13, the split
builds alone on a stand-in sdk-swift 0.1.0-alpha.2, macOS and iOS simulator builds import it; sdk-swift's split and the
other plugins' `info` as baseline; real SwiftPM fingerprints untouched; `bash -n`, shellcheck as baseline, YAML parses)
Changed: PACKAGES gains `orca_push_notification-ios-v` (plugins/orca_push_notification/ios, orca-gateway/
orca-push-notification-swift, ORCA_PUSH_NOTIFICATION_SWIFT_DEPLOY_KEY, OrcaPushNotification); the workflow header names
push's secret and mirror; three comments name SwiftUI through OrcaPlugin, AVFoundation, MapKit, UserNotifications
Decisions: no new job wiring · comments widened to the verify-linux one, as the map's · rehearsal check L (all minor)
Review fit: the Apple-only frameworks comments were false for push, fixed · Review quality: pass
#### T11 · CI matrices gain the push plugin (9bd3c1ad)
Files: .github/workflows/native-plugins.yml
Cases: P-ci → green (red first: no push entry in either matrix; the YAML parses; actionlint not installed; push's steps
run locally: swift test 22, xcodebuild on the iOS 18.5 simulator 21, Gradle build green with 29 unit tests)
Changed: the ios matrix gains orca_push_notification / OrcaPushNotification after the map's; the android list gains
orca_push_notification at its end; nothing else (path filters, names, report globs come from the matrix; no
google-services.json is needed to build or test a library)
Decisions: entries last, in release-row order · header unchanged · checked with this Mac's Xcode, CI's 16.4 confirms it
on the PR (all minor, auto-decided)
Review fit: pass · Review quality: pass

### Group 4
The branch was rebased twice in this group, onto main 2ca21c9 (PR #51), then 4a7f389 (PR #52), with no conflict;
the ids below are current, groups 1-3's are mapped under ### Rebases.
#### T13 · Android demo routes taps, needs: google-services (a89d1fe7)
Files: AND/settings.gradle.kts · AND/app/build.gradle.kts · AND/app/…/MainActivity.kt · AND/.gitignore · AND/README.md
Cases: C17.4/hand-K, P-firebase/K → green (`:app:assembleDebug`, warnings as errors, without the file, with a dummy
google-services.json, and after deleting it; red first "Unresolved reference 'PushNotificationPlugin'"; on the emulator
no crash without Firebase; an adb tap intent with orcacounter://open/map opened /map, a blank payload nothing)
Changed: the push build as orca-push-notification-android; the library at its VERSION; google-services Gradle plugin
4.6.0 (Apache 2.0) applied only when the git-ignored app/google-services.json exists; one
PushNotificationPlugin(applicationContext), initialize(this) in every onCreate; README "### Push notifications", untried
Decisions: the tap re-enters the singleTop activity as an ACTION_VIEW intent, OrcaApp's own deep-link path · a blank
payload opens nothing · the README links Firebase's setup page (all minor, auto-decided)
Review fit: pass · Review quality: pass
#### T14 · Android README, server README row (0579a9f7; 7ceee33f rework)
Files: PN/android/README.md (new) · examples/server/README.md (one row)
Cases: P-readme/K → green (facts check 177 of 177 against the yaml, the sources, the SDK, release.sh, the workflow,
custom.ts, firebase-messaging's POM; red first 99 of 152; six mutations each red; the snippet compiles)
Changed: Maven Central with the SDK and firebase-messaging 25.0.2; one PushNotificationPlugin(applicationContext),
initialize(this) in every onCreate of a singleTop ComponentActivity; the five actions, the permission, both failure
messages; Firebase files as the app's; foreground messages; the channel; differences; tests, releases, LICENSE · the
server README's orca_push_notification.ts row
Decisions: the snippet routes links with router.handleDeeplink · system-shown and cold-start taps never reach
onNotificationTap, said as Flutter's behaviour (both minor, auto-decided)
Review fit: pass · Review quality: a cold-start tap listed under Differences though it matches Flutter, fixed
Not done: needs: the yaml's payload description said null; T19 fixed it (90f3dd5f)
#### T16 · Swift token and topics through Firebase Messaging (be119c47; b419d4e6, 0837fbc4 reworks)
Files: SW/FirebaseMessagingAdapter.swift (new) · SWT/PushMessagingTests.swift (new) · PN/ios/Package.swift · the hook
only: SW/PushMessaging.swift, SW/PushNotificationPlugin.swift
Cases: C17.4/S-token → green (`swift test` 32 = 22 + 10, clean build; `xcodebuild test` on the simulator 30; red first
the missing adapter, the on-arrival test, the 12.18.0 bound; rehearsal 13 of 13; own files: one warning, the accepted
deprecation of token(completion:) with 12.19.3)
Changed: firebase-ios-sdk `from: "12.17.0"` (Apache 2.0), FirebaseMessaging, both branches, the header says why · the
internal adapter: FirebaseApp.app() first, else "Firebase is not configured: the app calls FirebaseApp.configure() at
launch, …"; the APNs token to Messaging in didRegister and before each call; topics on Firebase's async API · public init()
Decisions: from 12.17.0, the warning accepted (the parent's call) · the hook a PushMessaging method, no-op default · the
token keeps a continuation (Firebase's async token() is non-optional) (all minor, auto-decided)
Review fit: the token reached Messaging only at the next action, fixed · Review quality: continuations for topics, fixed
#### T19 · The yaml says a tap without a payload hands "" (90f3dd5f)
Files: PN/orca_plugin.yaml · SWT/PushNotificationParamsTests.swift · cli/test/push_notification_schema_test.dart
Cases: C17.5 (yaml) → green (cli `dart test` 56 → 57, red first on "Absent, the tap hands null."; push `swift test` 31;
the drift tests and the pub dry run as before)
Changed: showLocalNotification's payload description ends `Absent, the tap hands "" (an empty string).`
(flutter_local_notifications 18.0.1's `payload ?? ''`, both native plugins) · the Swift test's message at :90 · a new
schema test pins the wording; no generated file carries descriptions
Decisions: a new test, not an edit of a baseline one · the test pins the wording, not the package's source, which is
not in the repo (both minor, auto-decided)
Review fit: pass · Review quality: pass
Added at group 4 from T14's needs: line.

### Test run
Group 1, after T1-T3 (SC/s17p/g1run), on 45b32680: cli `dart test` 54 pass (51 + T1's 3), `dart analyze` no issues ·
engine `bun test` 828 pass, 0 fail · push android `./gradlew build --continue` BUILD SUCCESSFUL · map, video, voice
android BUILD SUCCESSFUL · sdk-kotlin BUILD SUCCESSFUL · push `flutter pub publish --dry-run` exit 65 with 1 warning
(no 0.2.1 CHANGELOG entry) and 1 hint, as at baseline · no stray file outside .pipeline/. Failures: none.

Group 2, after T4-T6 (SC/s17p/g2run), on edd49a80: cli 56 pass (54 + T4's and T5's drift tests), `dart analyze` no
issues · engine 832 pass, 0 fail (828 + T6's 4) · push android BUILD SUCCESSFUL (PushNotificationParamsTest 6) ·
sdk-kotlin BUILD SUCCESSFUL · sdk-swift 604 pass · push ios `swift test` 6, 0 warnings, `xcodebuild test` on the iOS
18.5 simulator 5, TEST SUCCEEDED · the generators leave no diff · examples/server tsc 36 → 47 errors, no new kind.
After T4's rework ba44435d (its test only): swift test 6, xcodebuild test 5, 0 warnings. Failures: none.

Group 3, after T7-T11 (SC/s17p/g3run), on 9bd3c1ad plus T7's quality reworks: cli 56 pass, `dart analyze` no issues ·
engine 833 pass, 0 fail (832 + T9's 1) · push, map, video, voice android BUILD SUCCESSFUL · sdk-kotlin BUILD SUCCESSFUL ·
sdk-swift 604 pass · push ios `swift test` 22, `xcodebuild test` on the iOS 18.5 simulator 21, TEST SUCCEEDED · map ios
28, video ios 26, voice ios 24 · release.sh and swift-mirror.sh `bash -n`, both workflows parse · the generators leave
no diff · T10's rehearsal with T7's sources 13 of 13. After T7's last rework 6ab9db64: push ios from a clean build 22,
0 warnings, xcodebuild 21. After T8's rework 0e1bd458: push android BUILD SUCCESSFUL, PushNotificationPluginTest 26, PushNotificationParamsTest 6. Failures: none.

Group 4, after T13, T14, T16, T19 (SC/s17p/g4run), on b419d4e6, the branch rebased onto main 4a7f389 (PR #52): cli
`dart test` 57 pass (56 + T19's 1), `dart analyze` no issues · engine `bun test` 843 pass, 0 fail ·
push, map, video, voice android BUILD SUCCESSFUL (push: PushNotificationPluginTest 26, PushNotificationParamsTest 6) ·
the Android demo `:app:assembleDebug` BUILD SUCCESSFUL, warnings as errors · sdk-kotlin BUILD SUCCESSFUL · sdk-swift
640 pass (with main's PR #52 tests) · push ios from a clean build `swift test` 32 with firebase-ios-sdk 12.19.3 resolved, its one
warning the accepted deprecation of token(completion:) (FirebaseMessagingAdapter.swift:123), `xcodebuild test` on the
iOS 18.5 simulator 30, TEST SUCCEEDED · map ios 28, video ios 26, voice ios 24 · release.sh and swift-mirror.sh
`bash -n`, both workflows parse · the generators leave no diff · T16's rehearsal g4-firebase-from 13 of 13. Failures: none.
After T16's quality rework 0837fbc4 (the adapter only): push ios `swift test` 32, the one accepted warning, `xcodebuild test`
30, TEST SUCCEEDED.

### Blocked
none (group 3: T7 was blocked twice, once per lens; each one retry passed: its review lines. Group 4: none)

### Not done
none

### Rebases
Groups 1-3's commits, original → current (main 4a7f389):
T1 cdb8d703→0b4f96dd · T2 0e775cbf→c1b76588 · T3 45b32680→2b7f1da1 · T3 gate change 31050c84→e84a71aa
T4 b106a5a8→e1ace137 · T4 rework ba44435d→b923c3ab · T5 4c84d828→fb176b6c · T6 edd49a80→a646b8f5
T7 1c72e189→dad13465 · T7 rework eb89fbd8→dbb9ca62 · T7 retry f8fd71ef→0cd1bc12
T7 quality rework 8bdae715→0a9cb581 · T7 quality retry 6ab9db64→18573da0 · T8 a9c94038→9ef2b628
T8 quality rework 0e1bd458→146f53c5 · T9 9d99991e→c266449e · T10 f9317bf3→8e676798 · T10 rework e84304f4→eded4945
T11 9bd3c1ad→8f303983

### For ship (stage 10) to know
- firebase-messaging is the first Firebase library; it brings play-services and androidx.fragment 1.1.0, so T8 registers
  its permission launcher through activityResultRegistry.register (ComponentActivity.registerForActivityResult fails
  lint's InvalidFragmentVersionForActivityResult); 25.0.2 keeps coroutines at the SDK's 1.9.0.
- The library never applies the google-services Gradle plugin: that is the app's (T13).
- The push Swift plugin has no public initializer until T16 adds `public init()` (its seams are internal, as the
  siblings'); the iOS demo (T12) needs T16. The real UNUserNotificationCenter is seen only at the iOS hand check.
- READMEs: T14 (Android) says initialize in onCreate on a singleTop activity, the Firebase files are the app's, and the
  service shows foreground messages even before initialize; T18 (iOS) says the host's own notification delegate is
  replaced and the app delegate forwards the APNs token.
- CI: native-plugins.yml now queues 4 macOS and 4 Linux plugin jobs; the first PR run confirms CI's Xcode 16.4.
- Firebase iOS: the push package takes firebase-ios-sdk `from: "12.17.0"`, so a fresh resolve gets the newest 12.x
  (12.19.3 today) and the build shows one deprecation warning, token(completion:) in FirebaseMessagingAdapter.swift,
  accepted (the token call works while the installation-ID registration stays opt-in); CI's Swift steps do not treat
  warnings as errors. 13.x needs Xcode 26.2. The PR body and T18's README say so. Follow-up: register(completion:) once
  it is no longer opt-in.
- The iOS demo (T12) configures Firebase only when its git-ignored GoogleService-Info.plist exists, as the Android demo
  applies google-services only with its file; without them the token and topic actions fail, local notifications work.
- The :8094 example server predates /push (T13 saw a 404): restart it before the hand checks.
- The Android walk in examples/app-android/README.md is marked untried until the stage 10 hand check runs it.
