# 10 · UAT · native-parity-s17-map

## Front page

### In one breath
PR #51 is open on main 3880607: the Google map as its own Swift and Gradle packages.
Every suite green; both demo apps build; C17.1 Swift ticked, Swift 33 of 35, Kotlin 32 of 35.
iOS seen by hand end to end. Android seen without a key: no pins, the camera never moves.
C17.1 Kotlin waits for your Maps key. At open: 4 checks pending. The merge is yours.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #51 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT: iOS done; Android's keyed walk waits for your Maps key (row stays ☐). (default: ok)
3. After A: 11 skipped by default; 12 reads PR #51's checks and your merge. (default: yes)
4. Meanwhile step 17's push plugin (plugin 4 of 4) starts on this branch's head. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #51
https://github.com/orca-gateway/orca-gateway/pull/51, opened after gate 09 was approved under your standing rule (its
three questions minor). Bound to this session; Auto-fix off, auto-merge off. Branch feat/native-parity-s17-map on
origin/main 3880607 (PR #49 merged; rebased with no conflict, the tree unchanged): groups 1-4 of 08, one commit per
task (reworks and the retry as their own commits), the video slice's close note. At open (`get_status`): 0 passing,
4 pending, 0 failing. The body is in the session scratchpad (`s17m/pr-s17-map.md`).

### What reviewers will find in the body
- Why: the map existed only for Flutter.
- What changes: the two packages in the video player's shape (MapKit on iOS with no key; Maps Compose 8.3.0 on
  Android, the one new library), the plugin one to one with Flutter (props and defaults, the camera read once, four
  triggers, moveCamera with its Values), the generated types and drift tests, release.sh rows 15-16, the mirror line,
  the CI matrices, the /map page's long press and marker-tap lines and counter, both demo apps (the SwiftPM link; the
  named Gradle build and the key from local.properties), the native READMEs; no wire-format change.
- The differences from Flutter: iOS draws Apple's map (terrain, zoom buttons, marker-tap camera, bearing); a
  wrong-typed prop takes its default; the iOS map takes a Column's leftover height.
- Tests and the hand checks: iOS seen whole (the black pin found and fixed); Android without a key, said as seen.
- After the merge (yours): the mirror repo orca-gateway/orca-google-map-swift, its deploy key and the secret
  ORCA_GOOGLE_MAP_SWIFT_DEPLOY_KEY; a Maps API key for the Android hand check (docs/User_Actions.md has both); the
  release order sdk-swift 0.1.0-alpha.2, sdk-kotlin, then rows 15 and 16.
- Follow-ups: sdk-swift's Center and Align in a Column drawn as a VStack and a real-bound signal for plugins, the
  plugins' package folder names, the pub CHANGELOG entry, three macOS CI jobs per run, the push plugin.

### Test file
`/Users/amrebada/.claude/plans/native-parity/phase-c-tests.md`: C17.1 confirmed against Flutter and ticked on Swift
with the test classes and "PR #51"; Kotlin stays ☐, blocked on a Google Maps Android API key, with what was seen and
what closes it. C17.5 keeps ☐ with the map's part written in (push to come). C17.2 and C17.5 name main 3880607.
Rows ticked: Swift 33 of 35, Kotlin 32 of 35.

### UAT, by hand
- iOS 18.5 simulator FDE5D612, the demo's /map on the example server (:8094), location granted and set: the whole
  walk (09's Hand checks); the pin's colour gap found and fixed (4bacde41 before the rebase), seen red after.
- emulator-5584 (API 34, Google Play), no key: /map opens, no crash, "Authorization failure"; grey box, no pins; a tap
  and a long press show coordinates; nothing moves the camera (SC/s17m/hand/android-nokey.md). The emulator was loaded
  (an app ANR at launch, as on the video's hand checks; dismissed with Wait, no reboot).
- After the rebase: the tree is byte-identical to the one the full run passed (09's group 4 test run).

### Not run locally
- Xcode 16.4 (CI's pin) and actionlint (not installed): CI proves both.
- The keyed Android walk (no key here), a real mirror publish and a Maven Central upload.
