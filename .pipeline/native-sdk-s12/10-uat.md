# 10 · UAT · native-sdk-s12

## Front page

### In one breath
PR #19 is open (feat/native-sdk-s12 → main), bound here, Auto-fix off; main had not moved.
At this card its CI read 6 passing, 1 pending, 0 failing. Swift on Linux runs there.
S12 adds no screen: fixtures 31-32, the regex rows and the Image semantics tests are its proof.
Epic row 23b.34 reads "S12 PR #19"; what is left sits in rows 23b.35 and 23b.36.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. UAT, optional: turn on VoiceOver or TalkBack in an example app and open a page with a broken
   image; it should read the alt, not "!". (default: skip it)
2. Merge PR #19 once its checks are green (you merge; I read its state on your reply).
   (default: ok)
3. After A: 11 skipped by default; 12 reads PR #19's checks and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #19
https://github.com/orca-gateway/orca-gateway/pull/19, opened at this stage on gate 09's "A",
bound to this session, Auto-fix off, auto-merge off. Title "fix(sdk,sdk-swift,sdk-kotlin): match
Dart in regex word edges and case folding, failed Image labels and Swift's live 4.0 (S12)". Before
the push `origin/main` was still c394c5b (PR #18's merge), already in the branch, so nothing was
merged. (The app's sync-with-base tool was off; the check was a plain fetch.)
Over main: the code commits, one per task in the order they passed review — T2 43eeb8c, T5 40beb48,
T1 7a29224, T3 ebd78eb, T4 8f69742, T7 42d9636, T7's rework 3c919bc, T6 88583cf — plus S11's two
closing notes and the S12 pipeline notes (this file's commit included).
Read once at this card (`get_status`): open; 6 passing, 1 pending, 0 failing.
Expected checks, by their path filters: Engine and Schema (`schema/**`: fixtures 31-32), SDK
(Flutter), SDK Swift (ubuntu), SDK Swift UI (iOS simulator), SDK Kotlin (JDK 17 and 21). The body is
in the session scratchpad (`pr-s12.md`).

### What UAT covers here
No screen was added; the cases ran at 09:
- R1, R2: render fixtures 31-32, green on the engine, Flutter, Swift and Kotlin; TransformTests (Swift)
  and TransformTest (Kotlin) rows with Dart-printed values, including 39 shared class rows.
- A1: Flutter's `image_error_semantics_test.dart` and Kotlin's ImageTest (an image node with the alt,
  no "!" node, "!" still drawn). Swift already did it.
- C1: Swift's OrcaClientTests and ActionExecutorTests (a live 4.0 stays `.double`); Kotlin's
  OrcaClientTest pins.
Question 1 is the only check by ear. The example apps are `examples/app-ios` and
`examples/app-android` (and the Flutter example); none has a recorded page with a broken image, so
hearing it means pointing an Image at a bad URL in the example server, which S12 did not do.

### Epic plan (outside the repo)
- Row 23b.34: "S12 PR #19".
- Row 23b.35 (gate 08): Swift's write path for 4.0. Row 23b.36 (gate 09): modifier scope, ß and
  ligature patterns, escaped letters and backreferences, Kotlin's long `\p{…}` names, patterns Dart
  rejects. Backups before each edit are in the session scratchpad.

### Cleanup
- No server or emulator ran in S12 beyond the test runners; the iOS simulator stays booted as before.
  The Linux runs used swift:5.10 and swift:6.2 images already on this Mac, on a scratch copy.
- Logs and diffs are in the session scratchpad (`s12/`).
- Not touched: Docker on 8080, the bun on 8091, your DevTools app on 6363.

### Next
- 11 Release: skipped by default (config.json). No package is released by S12. The next Flutter SDK
  release needs a `sdk/CHANGELOG.md` entry for the Image semantics; the Swift and Kotlin fixes ship
  with their next releases, all through `release.sh`.
- 12 Deploy watch: PR #19's checks, your merge.
