# 10 · UAT · native-parity-s17-push

## Front page

### In one breath
PR #54 is open on main 4a7f389: push notifications as their own Swift and Gradle packages.
Every suite green; both demo apps build; C17.5 ticked on both; Swift 34 of 35, Kotlin 34 of 35.
By hand, both demos: permission, a shown notification, its tap routed to /map.
C17.4 waits for your Firebase project (the token by hand). At open: 4 checks pending.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #54 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT done without Firebase; the token waits for your Firebase project (C17.4 ☐). (default: ok)
3. Merge PR #53 (map fix, green) first if you can: the keyed Android /map needs it. (default: ok)
4. After A: 11 skipped by default; 12 reads PR #54's checks and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #54
https://github.com/orca-gateway/orca-gateway/pull/54, opened after gate 09 was approved under your standing rule
(group 5: no blocked task, nine minor decisions). Bound to this session; Auto-fix off, auto-merge off. Branch
feat/native-parity-s17-push on origin/main 4a7f389 (PR #52 merged; no conflict): groups 1-5 of 08 plus T19 and T20,
one commit per task (reworks as their own commits), the stage records, and the walks marked as seen (9171d1e0). At open
(`get_status`): 0 passing, 4 pending, 0 failing, mergeable. The body is in the session scratchpad
(`s17p/pr-s17-push.md`).

### After PR #53 merged: rebased onto main 96f6986 (2026-11-17)
- CI on 9a8bcec: 12 green, 1 red, "orca_google_map Swift package (macOS, iOS simulator)" (run 43961936036, job
  133631314894). The macOS `swift test` passed 28 of 28. On the iOS simulator one map test failed,
  `testC17_1_S_TheTriggersRunTheNodesActionsAsTheyAreNow` (MapKitViewTests.swift:377): it got "marker1", the old
  action, not "the new action". The test waits a fixed 0.3 s after replaceComponent for SwiftUI's updateUIView to hand
  the coordinator the node's new `fire`, then taps. On that runner the test took 19.1 s (0.4 s here), so the update
  came after the tap.
- A flake, not this PR: #54 changes no map file. Its only shared change is the push entry in native-plugins.yml's two
  matrices, a job on its own runner. The map PR's own run 43919111892 failed the same way in another map test (the
  pin not shown within the 3 s pump). Here `xcodebuild test -only-testing:OrcaGoogleMapTests/MapKitViewTests
  -test-iterations 5` on the iOS 18.5 simulator: 55 tests, 0 failures; the trigger test 0.40 s each time.
- Rebased onto 96f6986 (43 commits, no conflict); the push re-runs every check. Again here: map, push Android green;
  the Android demo assembleDebug and lintDebug; engine 843 pass, 0 fail; the generators leave no diff.
- The Android walk's step 3 again, with the Maps key: the tap logged the deep-link line, the notification left the
  shade, and Map Integration drew Google's map with its pin (no MapsDynamite crash: #53's entry is now on the branch).
- Follow-up: harden the map's iOS simulator tests (wait on a signal, not a fixed pump), its own PR.

### What reviewers will find in the body
- Why: push existed only for Flutter.
- What changes: the two packages in the map's shape (firebase-ios-sdk from 12.17.0 on iOS, firebase-messaging 25.0.2
  on Android), the five actions one to one with Flutter (raw keys and scope, resolved title, body, payload and topic),
  initialize and the tap hand-off, the generated types and drift tests, release.sh rows 17-18, the mirror line, the
  CI matrices, the /push page, both demo apps (Firebase optional, taps routed through their own deep-link paths, the
  Android demo's icon), the native READMEs and the pub README's native section; no wire-format change.
- The Firebase 12.18+ deprecation warning on token(completion:), why it is accepted, and the follow-up.
- The differences from Flutter: initialize on the host's plugin, the iOS delegate replaced, the Android service in the
  manifest, the iOS launch tap (unseen).
- Tests and the hand checks, said as seen; after the merge (yours): the mirror repo and secret, a Firebase project
  (closes C17.4), the release order; follow-ups.

### Test file
`/Users/amrebada/.claude/plans/native-parity/phase-c-tests.md`:
- C17.4 corrected against Flutter, as 05 found ("writes the permission and the token into state, shows a local
  notification, and hands a tapped notification's payload to the host, which the demo routes through the SDK's deep
  link path"), the old wording kept in the evidence. Both columns stay ☐: what was seen by hand and the tests are
  written in; the token by hand needs the user's Firebase project.
- C17.5 ticked on both, the push part written in (all four plugins done).
- Rows ticked: Swift 34 of 35, Kotlin 34 of 35; C17.4 the one open row.

### UAT, by hand (SC/s17p/hand/hand-push.md)
- iOS 18.5 simulator FDE5D612, the demo's /push on the example server (:8094): the permission asked at launch (Allow),
  the APNs token line, "Permission: granted" with the token part failing as "Firebase is not configured", the banner
  in front, its tap logging the deep-link line and drawing Map Integration, Get token's error in DevTools.
- emulator-5584 (API 34, Google Play): the permission dialog, "Permission: granted", Show notification posting nothing
  (no small icon: T20 added), then after T20 the heads-up and the shade entry with the demo's "+", the tap logging
  the deep-link line and cancelling the notification. With the user's Maps key /map then crashed in MapsDynamite
  (org.apache.http.ProtocolVersion), which PR #53 fixes and this branch lacks.
- The emulator was loaded (ANR dialogs, a 30 s permission dialog): taps waited for the page to draw.

### Not run locally
- Xcode 16.4 (CI's pin) and actionlint: CI proves both.
- Anything needing Firebase (the token, topics, a real push), a tap that launches a terminated iOS app, a real
  mirror publish and a Maven Central upload.
