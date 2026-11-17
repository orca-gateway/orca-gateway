# 12 · Deploy watch · native-parity-s17-push

## Front page

### In one breath
PR #54 is in main as merge commit d66e804 (2026-11-16 23:52Z); all 17 checks passed.
Push notifications ship as their own Swift and Gradle packages; all four plugins are in main.
Nothing is published by the merge: release rows 17-18 do it, after the SDK releases.
C17.4 Swift ticked with your Firebase project; Kotlin waits on your Android API key change.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), the push slice closed. (default: yes)
2. Allow Firebase Installations on the Android key, for C17.4 Kotlin. (default: wait)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #54
https://github.com/orca-gateway/orca-gateway/pull/54
- In main as d66e804, a merge commit whose second parent is the PR's head 9574333 (the branch rebased onto 96f6986,
  PR #53, before the merge).
- Read once at this card (`gh pr checks 54`): 17 passing, 0 failing, 0 pending. The map's Swift package job (macOS and
  the iOS simulator) failed twice on the PR in existing map tests, timing flakes this PR does not touch (9a8bcec:
  the trigger test's fixed 0.3 s wait; 9574333: the tap-off test's 3 s pin wait); re-running the failed job passed it.
  The map tests' waits are hardened in a session of their own (claude/clever-lewin-8a028e, PR to come).
- Gate 10 approved: question 1 answered by the user's merge (relayed by the parent session), question 3 by PR #53's
  merge, questions 2 and 4 minor, defaults under the standing rule; 11 skipped by default.
- The stage 10 record of the Firebase walk (8a4b21f3) was kept off PR #54 so its green checks were not re-run (the
  parent's call); it rides with this close-out on PR #55's branch.

### C17.4 with the user's Firebase project (2026-11-17)
- iOS ✅: permission and the FCM token in app state, Get token, the news topic subscribed and unsubscribed, the
  banner and its tap to /map. The demo must be signed (Xcode's run); a CODE_SIGNING_ALLOWED=NO build has no
  aps-environment entitlement and APNs refuses it.
- Android ☐: Firebase Installations answers 403 PERMISSION_DENIED to the Android key in google-services.json, the same
  key as the Maps key in local.properties. The user's to change in Google Cloud (allow Firebase Installations and
  Firebase Cloud Messaging on that key, or a separate Maps key); then the Android walk's token step again.
- Not seen on either: a message sent through FCM and delivered (a send from the Firebase console, the user's), a tap
  that launches a terminated iOS app, anything only a device shows (a 32-byte device token, production APNs).
- The user's Firebase files now sit where the READMEs say in the main checkout (app/google-services.json,
  OrcaCounter/GoogleService-Info.plist), git-ignored since #54.

### What ships when (yours)
1. Create the empty public repository orca-gateway/orca-push-notification-swift, give it its own write deploy key,
   and add the private half as the Actions secret ORCA_PUSH_NOTIFICATION_SWIFT_DEPLOY_KEY (docs/User_Actions.md,
   "Native parity step 17: the orca_push_notification Swift mirror"); the voice, video and map mirrors likewise.
2. Release, each run green before the next: sdk-swift 0.1.0-alpha.2 (row 9), sdk-kotlin (row 10), then rows 11-18.

### Next
- On A: stages 13-16 skipped ("push notifications have no deployed service; skipped by the default accepted at gate
  12 (standing rule, minor)").
- Step 17 is done on both SDKs (rows Swift 35 of 35, Kotlin 34 of 35: C17.4 Kotlin waits on the key).
- PR #55 (fix/flutter-request-timeout): Flutter applies its 30 s request timeout, C18.5's decided follow-up.
