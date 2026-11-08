# 10 · UAT · native-sdk-s11

## Front page

### In one breath
PR #18 is open (feat/native-sdk-s11 → main), bound here, Auto-fix off; main had not moved.
At this card its CI read 2 passing, 5 pending, 0 failing; mergeable. Swift on Linux runs there.
S11 has no new screen: the six fixtures and the layout and Image tests are its proof.
Epic row 23b.33 reads "S11 PR #18"; the corners left for later are row 23b.34 (your yes).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. UAT, optional: run the Swift example app and open a page with a Row using `spaceAround`, or
   the Android example with a broken image URL, to see the change by eye. (default: skip it)
2. Merge PR #18 once its checks are green (you merge; I read its state on your reply).
   (default: ok)
3. After A: 11 skipped by default; 12 reads PR #18's checks and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #18
https://github.com/orca-gateway/orca-gateway/pull/18, opened at this stage on gate 09's "A",
bound to this session, Auto-fix off, auto-merge off. Title "fix(sdk-swift,sdk-kotlin): match Dart in
the native SDKs' string, regex, number, flex and Image corners (S11)". Before the push `origin/main`
was still 07d5279 (PR #17's merge), already in the branch, so nothing was merged. (The app's
sync-with-base tool was turned off; the check was a plain fetch.)
The PR: 36 files, +2695 −123 over main, 12 commits:
- code, one per task: T1 c9cab82, T4 4b2dfdb, T2 882fce6, T3 8b219b5, T6 847e7ec, T5 f30a150;
- the S10 closing notes and the S11 pipeline notes.
Read once at this card (`get_status`): mergeable; 2 passing, 5 pending, 0 failing.
Expected checks, by their path filters: Engine (`schema/**`), Schema, SDK (Flutter), SDK Swift
(ubuntu; the first Linux run of T5's JSON parser), SDK Swift UI (iOS simulator), SDK Kotlin
(JDK 17 and 21). The body is in the session scratchpad (`pr-s11.md`).

### What UAT covers here
No screen was added; the cases ran at 09:
- P1-P6: render fixtures 25-30, green on the engine, Flutter, Swift and Kotlin.
- L1-L3: FlexLayoutTests on the iOS simulator (positions measured from pixels).
- I1: ImageTest under Robolectric, and the re-recorded `native-widgets-home.png`.
Question 1 is the only look by eye. The Swift example is `examples/app-ios`, the Android one
`examples/app-android`; neither has a recorded page with `spaceAround`, a gap or a broken image, so
seeing it means editing a page in the example server, which S11 did not do.

### Epic plan (outside the repo)
- Row 23b.33: "S11 PR #18".
- New row 23b.34 (gate 09 question 2, default yes): `\b`/`\B` as ASCII word edges, the `i` flag's
  ſ/K/ı/İ, Kotlin's "!" in the Image's label, Swift `OrcaClient`'s live 4.0 in Codable models;
  done when a fixture per regex corner is green on all four, plus an ImageTest and an OrcaClient
  test. Backup of the plan before both edits in the session scratchpad.

### Cleanup
- No server or emulator ran in S11 beyond the test runners; the iOS simulator stays booted as
  before.
- Logs and diffs are in the session scratchpad (`s11/`).
- Not touched: Docker on 8080, the bun on 8091, your DevTools app on 6363.

### Next
- 11 Release: skipped by default (config.json). No package is released by S11; the next sdk-swift
  or sdk-kotlin release carries it, through `release.sh`.
- 12 Deploy watch: PR #18's checks, your merge.
