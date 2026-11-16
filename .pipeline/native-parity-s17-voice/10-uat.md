# 10 · UAT · native-parity-s17-voice

## Front page

### In one breath
PR #47 is open on main 941e789 (your merge of #46): the voice recorder as its own Swift and Gradle packages.
Every suite green; both demo apps build and open the voice page; C17.3 ticked, 31 of 35 each.
Seen by hand on both devices: the mic prompt, recording, Stop into page state, playback.
At open: 4 checks pending. The merge is yours; then the mirror repo, its key and secret are yours.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #47 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT: seen by hand on the emulator and the simulator; nothing left to see. (default: done)
3. After A: 11 skipped by default; 12 reads PR #47's checks and your merge. (default: yes)
4. Meanwhile step 17's video player (plugin 2 of 4) starts on main 941e789. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #47
https://github.com/orca-gateway/orca-gateway/pull/47, opened after gate 09 was approved under your standing rule (its
two questions minor). Bound to this session; Auto-fix off, auto-merge off. Branch feat/native-parity-s17-voice on
origin/main 941e789: groups 1-4 of 08, one commit per task (reworks as their own commits), the step 14 close. At open
(`get_status`): 0 passing, 4 pending, 0 failing. The body is in the session scratchpad (`s17/pr-s17-voice.md`).

### What reviewers will find in the body
- Why: the voice recorder existed only for Flutter.
- What changes: the two packages (SwiftPM with its two-way SDK dependency, Gradle on the SDK's toolchain), the plugin
  one to one with Flutter, the CLI's types-only mode and drift tests, release.sh rows 11-12, the mirror split per plugin
  tag, the Maven plugin tags, native-plugins.yml, the /voice demo page and both demo apps; no wire-format change.
- Tests and the hand checks, with the iOS simulator's silent input said plainly.
- After the merge (yours): the mirror repo orca-gateway/orca-voice-recorder-swift, its deploy key and the secret
  ORCA_VOICE_RECORDER_SWIFT_DEPLOY_KEY (docs/User_Actions.md); the release order sdk-swift 0.1.0-alpha.2, sdk-kotlin,
  then rows 11 and 12.
- Follow-ups: sdk-swift/README.md's exact 0.1.0-alpha.1, the plugin pubspec's homepage and repository, the
  examples/server typing, the next three plugins.

### Test file
`/Users/amrebada/.claude/plans/native-parity/phase-c-tests.md`: C17.3 ticked on Swift and Kotlin with the test classes
and "PR #47" (the iOS bar's silent input said); C17.5 keeps ☐ with the voice recorder's part written in (video, map
and push to come). Rows ticked: Swift 31 of 35, Kotlin 31 of 35.

### UAT, by hand
- Before the rebase onto 941e789 (bdfe0d0): the full C17.3 walk on emulator-5584 and the iOS 18.5 simulator (09's
  test run, SC/s17/hand/C17.3-hand.md).
- After it: the iOS build opens the voice page with the plugin's view; the Android build, on the emulator rebooted
  after it hung (processes failed to attach after 7 h), opens it too (the UI tree: Ready, Start, Stop, Play, "Saved
  to:", "Duration: 0 ms", "Voice Recorder").

### Not run locally
- Xcode 16.4 (CI's pin; this machine has 27.2 only) and actionlint (not installed): CI proves both.
- A real mirror publish and a Maven Central upload: they need the repo, the secret and the SDK releases first.
