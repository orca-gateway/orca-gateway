# 09 · Implementation · native-parity-s17-push

## Front page

### In one breath
group 1 of 5 · tasks: 3 green, 0 blocked · cases: 3 of 20 green · engine bun test: 828 pass
T1 yaml: the five actions' schema, in Flutter's order, pinned by a new CLI test (cli 54).
T2 ignores: the map's .pubignore and .gitignore; pub leaves ios/ and android/ out.
T3 Android: the Gradle package on the SDK's toolchain, firebase-messaging 25.0.2; it builds empty.

### New for you
nothing new

### Trade-offs
6 auto-decided (minor, your standing rule), firebase-messaging 25.0.2 among them.

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 2 of 5, generated params types and the /push page? (default: go)
3. Still open from gate 08: iOS A Firebase Messaging or B APNs only. (default: A; T16+ wait)

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

### Test run
Group 1, after T1-T3 (SC/s17p/g1run), on 45b32680: cli `dart test` 54 pass (51 + T1's 3), `dart analyze` no issues ·
engine `bun test` 828 pass, 0 fail · push android `./gradlew build --continue` BUILD SUCCESSFUL · map, video, voice
android BUILD SUCCESSFUL · sdk-kotlin BUILD SUCCESSFUL · push `flutter pub publish --dry-run` exit 65 with 1 warning
(no 0.2.1 CHANGELOG entry) and 1 hint, as at baseline · no stray file outside .pipeline/. Failures: none.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- firebase-messaging is the first Firebase library; it brings play-services and androidx.fragment 1.1.0, so T8 registers
  its permission launcher through activityResultRegistry.register (ComponentActivity.registerForActivityResult fails
  lint's InvalidFragmentVersionForActivityResult); 25.0.2 keeps coroutines at the SDK's 1.9.0.
- The library never applies the google-services Gradle plugin: that is the app's (T13).
