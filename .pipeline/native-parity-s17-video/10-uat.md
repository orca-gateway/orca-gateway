# 10 · UAT · native-parity-s17-video

## Front page

### In one breath
PR #49 is open on main d82ed11: the video player as its own Swift and Gradle packages.
Every suite green; both demo apps build and play /video; C17.2 ticked, 32 of 35 each.
Seen by hand on both devices: first frame, tap play and pause, seek, speed, the end.
At open: 4 checks pending. The merge is yours; then the mirror repo, its key and secret are yours.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #49 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT: seen by hand on the emulator and the simulator; nothing left to see. (default: done)
3. After A: 11 skipped by default; 12 reads PR #49's checks and your merge. (default: yes)
4. Meanwhile step 17's map plugin (plugin 3 of 4) starts on main d82ed11. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #49
https://github.com/orca-gateway/orca-gateway/pull/49, opened after gate 09 was approved under your standing rule (its
two questions minor). Bound to this session; Auto-fix off, auto-merge off. Branch feat/native-parity-s17-video on
origin/main d82ed11 (PR #48 merged; rebased with no conflict): groups 1-4 of 08, one commit per task (reworks as
their own commits), the voice slice's close note. At open (`get_status`): 0 passing, 4 pending, 0 failing. The body
is in the session scratchpad (`s17v/pr-s17-video.md`).

### What reviewers will find in the body
- Why: the video player existed only for Flutter.
- What changes: the two packages in the voice recorder's shape, the plugin one to one with Flutter (props, five
  actions with their clamps, five triggers and when they fire, the UI, the iOS audio session, the Android first
  frame), the generated types and drift tests, release.sh rows 13-14, the mirror line, the CI matrices, the /video
  demo page and both demo apps (the SwiftPM link and the named Gradle build); no wire-format change.
- The three differences from Flutter kept on purpose: a covered page stops its video, the ▶ follows the player, the
  iOS loading and error views take their own height.
- Tests and the hand checks, with the two gaps they found and fixed.
- After the merge (yours): the mirror repo orca-gateway/orca-video-player-swift, its deploy key and the secret
  ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY (docs/User_Actions.md); the release order sdk-swift 0.1.0-alpha.2, sdk-kotlin,
  then rows 13 and 14.
- Follow-ups: sdk-swift's Center and Align in a Column drawn as a VStack, a real-bound signal for plugins, the
  plugins' package folder names, sdk-swift/README.md's exact 0.1.0-alpha.1, the map and push plugins.

### Test file
`/Users/amrebada/.claude/plans/native-parity/phase-c-tests.md`: C17.2 ticked on Swift and Kotlin with the test classes,
the differences kept and "PR #49"; C17.5 keeps ☐ with the video player's part written in (map and push to come).
Rows ticked: Swift 32 of 35, Kotlin 32 of 35.

### UAT, by hand
- iOS 18.5 simulator FDE5D612 and emulator-5584 (API 34), the demo's /video on the example server (:8094): the full
  C17.2 walk, before the rebase onto d82ed11 (SC/s17v/hand/C17.2-hand.md). The two gaps it found were fixed (T7
  loading, T8 first frame) and seen fixed on a rebuild of each app.
- After the rebase: both demo apps build and every suite is green in the full run (09's group 4 test run). Main
  brought 30 sdk-swift and sdk-kotlin files (sliver scrolling) and a new slivers app in examples/server; none of the
  plugin's files, its /video page or the two demo apps changed; the server README kept both rows.

### Not run locally
- Xcode 16.4 (CI's pin; this machine has 27.2 only) and actionlint (not installed): CI proves both.
- A real mirror publish and a Maven Central upload: they need the repo, the secret and the SDK releases first.
