# 12 · Deploy watch · native-sdk-s15

## Front page

### In one breath
PR #22 is merged into main as bbd488d (2026-11-13 13:08Z); its 9 checks all passed.
Swift on Linux (5.10, 6.2) is green after round 2's ICU gating; so are Kotlin 17/21 and iOS 18.5.
S15 deploys nothing and publishes nothing: the fixes ship with the next sdk-swift and sdk-kotlin.
Row 23b.37's done-when holds: a test row per corner with Dart's value, and fixtures 35-36.
Side work, merged as PR #23: the Flutter SDK moved to material_ui and round 3's Flutter pin is gone.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), S15 closed, row 23b.37 ✅ in the epic plan.
   (default: yes)
2. The next slice, row 23b.38 (the input side), starts on your "Start S16". (default: wait for you)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #22
https://github.com/orca-gateway/orca-gateway/pull/22
- Merged 2026-11-13T13:08:19Z as bbd488d (head ded318e, gate 10's round 3 notes included). Gate 10
  approved with your words "Merged, go on"; 11 skipped by default.
- Read once at this card (`gh pr checks 22`): 9 passing, 0 failing, 0 pending.
- The checks: Core tests (swift 5.10-jammy, linux), Core tests (swift 6.2-noble, linux), UI tests and
  example (iOS simulator), SDK tests and example (JDK 17, linux), SDK tests and example (JDK 21,
  linux), Codegen drift detection, and three `test` jobs (engine, schema, Flutter).
- Three CI rounds at gate 10: round 2 fixed the Linux Swift tests (a7f9eb8: Linux's Foundation ICU is
  older than Apple's, so the script-value rows ask it first); round 3 pinned the Flutter job to 3.47.9
  (da9213b: Flutter 3.50 deprecates material.dart) and re-ran the iOS job GitHub had no runner for.

### Row 23b.37's done-when
"A TransformTests / TransformTest row per corner with Dart's printed value, or a render fixture where
the engine can express it":
- quantifiers on quantifiers and on assertions refused (A3): T1 (Swift), T2 (Kotlin);
- Annex B and engine-only syntax without `u`, through the pre-pass (A1, A2): T3, T4;
- the strict grammar with `u` (G3): T5, T6;
- group names, and references to groups unset at that point matching empty: T7, T8;
- `\P{…}` and `[^\p{…}]` under `iu`, script values (loose and Script_Extensions) (G4): T9, T10;
- fixtures 35 and 36 pin a selection on the engine, Flutter, Swift and Kotlin (X1): T11.
Every expected value was printed by Dart 3.12.2. The differences left are in the row as known
differences (two added at gate 09, Linux's older ICU added at gate 10), or row 23b.38's.

### What ships when
Nothing is released by S15 (stage 11 skipped by default). The fixes reach apps with the next
`sdk-swift-v*` tag (the SwiftPM mirror) and `sdk-kotlin-v*` tag (Maven Central), through
`bash scripts/release.sh`. The engine is unchanged; the schema gained fixtures 35-36.

### Side work: PR #23, material_ui (your "Do this task here", outside S15)
https://github.com/orca-gateway/orca-gateway/pull/23, merged 2026-11-13T13:46:39Z as d3229af.
- The Flutter SDK, orca_google_map, orca_video_player, orca_voice_recorder and examples/app take
  Material from `material_ui` 1.11.0; the SDK needs Dart 3.13 and Flutter 3.47 (was 3.11 and 3.24).
  Breaking for host apps (your answer: "Migrate now, breaking"): ThemeData is material_ui's now.
- CI: the SDK job runs on Flutter 3.47.9 and stable (pin lifted); all 6 checks passed.
- Your global Flutter was upgraded to 3.50.0 at your word ("Upgrade ~/flutter anyway"), after Flutter's
  own pubspec.lock drift (objective_c 9.2.3 → 9.3.0) was restored.
- At the next release: sdk crosses 0.x (0.3.3 → 0.4.0) through release.sh; bump all four plugins'
  `orca_gateway: ^0.3.0` before releasing them; select sdk before the plugins.

### Cleanup
- Nothing of this session is running. Scratch logs and diffs stay in the session scratchpad (`s15/`,
  `mui/`).
- Not touched: Docker (daemon off), the bun on 8091, DevTools on 6363, the orca-extender session's
  `flutter run` on the simulator (it may need a restart to hot reload on Flutter 3.50).
- The untracked `sdk-kotlin/core/bin/` (an IDE's build output from 2026-11-08) is still here, not
  committed, left for you.
- feat/native-sdk-s15 and feat/flutter-material-ui are merged; the session can be archived when you like.

### What S15 leaves for later
- Row 23b.38 (S16): backreferences under `i` compared with the engine's folding; UTF-16 units without `u`.
- Small follow-ups found here: `DartFoldTable`'s `u` column duplicates `DartFoldClasses` (a test pins
  they agree); Swift's `tableKept` comment also covers `propertyKept`; the S14 test name
  `p1_guard_scriptKeysLeaveTheValueToTheEngine` (TransformTest.kt) no longer says what it checks;
  S14's TransformTest.kt still holds U+00A0 ×2, U+2003 ×2 and U+0301 ×3 written literally.
- `devtools/` still imports the old Material library (it builds on its pinned Flutter 3.41.5, which
  material_ui does not support).
- Not run anywhere: the Kotlin SDK's Android ICU path.
- Earlier carry-overs: 23b.27e (the Maven Central release is yours); a public builder hook for hosts
  (S9 08 F4); the DevTools compression reply (S8 F1); keeping the page stack across rotation (S7 F1);
  the example server's banner port (S9 F4); engine-dart's broken conformance test (S11 F13).

### Next
- On your A: stages 13-16 skipped ("S15 has no deployed service; skipped by the default accepted at
  gate 12"), S15 closed, row 23b.37 ✅ Done.
- Then row 23b.38 on your "Start S16".

### Closed (gate 12, your standing rule, 2026-11-13)
PR #22 merged as bbd488d with its 9 checks green (read at this card). Gate 12 approved under your
standing rule (both questions minor, both defaults); stages 13-16 skipped ("S15 has no deployed
service; skipped by the default accepted at gate 12 (standing rule, minor)"); S15 closed. Epic row
23b.37 reads ✅ Done; row 23b.38 holds the input side, "After S15". The next slice starts on your
"Start S16".
