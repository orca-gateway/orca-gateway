# 12 · Deploy watch · native-sdk-s11

## Front page

### In one breath
PR #18 is merged into main as c394c5b (08:12Z); its 8 checks all passed, Swift on Linux included.
S11 deploys nothing and publishes nothing: the SDK fixes ship with the next sdk-swift or
sdk-kotlin release through release.sh. Row 23b.33's done-when holds: six fixtures, four runners.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), S11 closed, row 23b.33 ✅ in the epic plan.
   (default: yes)
2. The next slice, row 23b.34 (`\b`, the `i` flag, Kotlin's "!" label, Swift's live 4.0), starts
   on your "Start S12". (default: wait for you)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #18
https://github.com/orca-gateway/orca-gateway/pull/18
- Merged 2026-11-08T08:12:40Z as c394c5b (head 93afb2f, the stage 10 notes included).
- Read once at this card (`get_status`): merged; checks 8 passing, 0 failing, 0 pending.
- Expected by path filters: Engine, Schema, SDK (Flutter), SDK Swift (ubuntu, the first Linux run of
  T5's JSON parser), SDK Swift UI, SDK Kotlin (JDK 17 and 21). All green.

### Row 23b.33's done-when
"One render fixture per corner in `schema/fixtures/render/`, green on the engine, Flutter, Swift and
Kotlin; a Swift layout test per flex case":
- fixtures 25-30, one per corner (P1-P6), green on all four runners locally and in CI;
- FlexLayoutTests: L1 spaceAround, L2 gap with spaceEvenly and spaceAround (and gap 0), L3 Column
  baseline;
- Kotlin's failed Image draws "!" (I1), ImageTest and the re-recorded golden.

### What ships when
Nothing is released by S11 (stage 11 skipped by default). The Swift fixes reach apps with the next
`sdk-swift-v*` tag (the SwiftPM mirror), the Kotlin ones with the next `sdk-kotlin-v*` (Maven
Central, after your Sonatype steps; 23b.27e). Both go through `bash scripts/release.sh`.

### Cleanup
Nothing running. Scratch logs, diffs and backups stay in the session scratchpad (`s11/`). Not
touched: Docker on 8080, the bun on 8091, your DevTools app on 6363. The worktree's branch
feat/native-sdk-s11 is merged; the session can be archived when you like.

### What S11 leaves for later
- Row 23b.34 (new, gate 09 question 2): `\b`/`\B` as ASCII word edges in both SDKs; the `i` flag's
  ſ/K/ı/İ; Kotlin's "!" in the Image's accessibility label; Swift `OrcaClient`'s live 4.0 inside
  Codable models.
- 23b.27e: the Maven Central release is yours (User_Actions "Maven Central publishing", Step 6).
- Earlier carry-overs: a public builder hook for hosts (S9 08 F4); the DevTools compression reply
  (S8 F1); keeping the page stack across rotation (S7 F1); the example server's banner port (S9 F4);
  engine-dart's broken conformance test (S11 F13).

### Next
- On your A: stages 13-16 skipped ("S11 has no deployed service; skipped by the default accepted at
  gate 12 (A)"), S11 closed, row 23b.33 ✅ Done (PR #18).
- Then row 23b.34 on your go.

### Closed (gate 12, "A", 2026-11-08)
PR #18 merged as c394c5b with its 8 checks green (read at this card). Gate 12 approved on your "A";
stages 13-16 skipped ("S11 has no deployed service; skipped by the default accepted at gate 12
(A)"); S11 closed. Epic row 23b.33 reads ✅ Done; row 23b.34 holds what S11 left, "After S11".
The next slice starts on your "Start S12".
