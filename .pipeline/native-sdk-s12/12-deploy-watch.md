# 12 · Deploy watch · native-sdk-s12

## Front page

### In one breath
PR #19 is merged into main as 29d77e9 (2026-11-10 09:31Z); its 8 checks all passed.
Swift on Linux (5.10 and 6.2), iOS UI, Kotlin (JDK 17 and 21), Flutter and codegen: all green.
S12 deploys nothing and publishes nothing: the fixes ship with the next SDK releases (release.sh).
Row 23b.34's done-when holds: fixtures 31-32 on four runners, Image semantics and 4.0 tests.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), S12 closed, row 23b.34 ✅ in the epic plan.
   (default: yes)
2. The next slice, row 23b.35 (Swift writes a typed 4.0 back as 4.0), starts on your
   "Start S13"; row 23b.36 (the regex corners left) after it. (default: wait for you)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #19
https://github.com/orca-gateway/orca-gateway/pull/19
- Merged 2026-11-10T09:31:41Z as 29d77e9 (head 4ceec75, the stage 10 notes included).
- Read once at this card (`get_status`, then `gh pr view` for the merge commit): merged; checks 8
  passing, 0 failing, 0 pending.
- The checks: test ×2 (engine and schema), Codegen drift detection, SDK tests and example (JDK 17
  and 21, linux), Core tests (swift 5.10-jammy and 6.2-noble, linux), UI tests and example (iOS
  simulator). The Flutter SDK's job is one of the two `test` runs.

### Row 23b.34's done-when
"A render fixture per regex corner in `schema/fixtures/render/`, green on the engine, Flutter, Swift
and Kotlin; a Flutter semantics test and an ImageTest for the label; an OrcaClient test for the live
`4.0`":
- fixtures 31 (`\b`, `\B`, `[\b]`, the `matches` op) and 32 (the `i` flag's ſ, K, ı, İ, with and
  without `u`), green on all four runners locally and in CI;
- Flutter's `image_error_semantics_test.dart` and Kotlin's ImageTest (the alt with the image role,
  "!" drawn but hidden); Swift already did it;
- Swift's OrcaClientTests (a live 4.0 stays a double in pages, the 426 page and server actions) and
  Kotlin's OrcaClientTest pins.

### What ships when
Nothing is released by S12 (stage 11 skipped by default). The Flutter SDK's Image change reaches
apps with the next `sdk-v*` release, which needs a `sdk/CHANGELOG.md` entry for it; the Swift fixes
with the next `sdk-swift-v*` tag (the SwiftPM mirror); the Kotlin ones with the next
`sdk-kotlin-v*` (Maven Central, after your Sonatype steps; 23b.27e). All through
`bash scripts/release.sh`.

### Cleanup
- Nothing running. Scratch logs, diffs and backups stay in the session scratchpad (`s12/`).
- Not touched: Docker on 8080, the bun on 8091, your DevTools app on 6363.
- An untracked folder `sdk-kotlin/core/bin/` (47 copies of Kotlin sources, created 2026-11-08 15:40,
  after S12's last change) sits in this worktree. It looks like an IDE's build output, not S12's;
  it is not committed, ignored by no rule, and left as it is for you.
- The worktree's branch feat/native-sdk-s12 is merged; the session can be archived when you like.

### What S12 leaves for later
- Row 23b.35 (gate 08): Swift writes a typed `4.0` as 4 through `encoded()` and
  `JSONValue(encoding:)` (request bodies, `Value.json`, DevTools payloads).
- Row 23b.36 (gate 09): letters inside a modifier group follow the pattern's `i`; patterns holding ß
  or a ligature still fold the ICU way in Swift; escaped letters and backreferences; Kotlin's long
  `\p{…}` names; patterns Dart rejects still run in Kotlin.
- 23b.27e: the Maven Central release is yours (User_Actions "Maven Central publishing", Step 6).
- Earlier carry-overs: a public builder hook for hosts (S9 08 F4); the DevTools compression reply
  (S8 F1); keeping the page stack across rotation (S7 F1); the example server's banner port (S9 F4);
  engine-dart's broken conformance test (S11 F13).

### Next
- On your A: stages 13-16 skipped ("S12 has no deployed service; skipped by the default accepted at
  gate 12 (A)"), S12 closed, row 23b.34 ✅ Done (PR #19).
- Then row 23b.35 on your "Start S13".
