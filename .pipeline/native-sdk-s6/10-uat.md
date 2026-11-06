# 10 · UAT · native-sdk-s6

## Front page

### In one breath
PR #12 is open: feat/native-sdk-s6 → main, 5 code commits plus pipeline ones. CI is running.
Passed so far: Engine, Schema (Generated.kt drift), Swift core (push). Kotlin and Flutter running.
Nothing to see on a device: S6 is a JVM library. UAT is one test run and three pages; steps below.

### New for you
Nothing new.

### Trade-offs
1 done: gate 09 defaults kept. Epic plan: 23b.27a says PR #12; new row 23b.33 holds the six Dart
  corners, after S10 (question 1 at 09). Both outside the repo.
2 noted: Auto-fix stays off for #12, as for #8 and #10, so CI results reach me when you ask.

### Questions for you
1. UAT: does `t sdk-kotlin:test` pass for you; do the README and PR text read right? (default: ok)
2. After A: 11 is skipped by default, 12 records PR #12's CI, 13-16 skipped. (default: yes)
3. After merge nothing is released: sdk-kotlin joins release.sh at S10. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### UAT steps
1. Run the tests (any JDK 17 or later; the wrapper fetches Gradle 9.7.1 the first time):
   ```
   cd /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/keen-leakey-4c4de7
   task sdk-kotlin:test
   ```
   Expect `BUILD SUCCESSFUL`. The report is at `sdk-kotlin/core/build/reports/tests/test/index.html`:
   82 tests in 12 classes, none failed or skipped.
2. Read, on the PR branch:
   - [sdk-kotlin/README.md](https://github.com/orca-gateway/orca-gateway/blob/feat/native-sdk-s6/sdk-kotlin/README.md):
     the experimental banner, the two modules, the slice table S6 to S10.
   - [sdk/CHANGELOG.md](https://github.com/orca-gateway/orca-gateway/blob/feat/native-sdk-s6/sdk/CHANGELOG.md):
     the 0.3.3 entry (DevTools warning, the 426 page, the Scaffold under the warn banner).
   - The PR description: what's in it, the Swift comparison, the known Dart differences.
3. Optional, one fixture end to end: `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/ActionFixtureTest.kt`
   reads `schema/fixtures/actions/*.json` and checks state and effects, as Swift and Flutter do.

### PR #12
https://github.com/orca-gateway/orca-gateway/pull/12, opened at this stage, bound to this session,
Auto-fix off. Code commits: b290ff3 (Gradle skeleton), 37a7de8 (Kotlin caps vector), 2d5f7de (the
core port), f42782b (Taskfile and CI), 827cb6a (sdk 0.3.3 changelog). Pipeline commits: 7402b4c
and 90aee26 (S5 close), 65fea0c (S6 stage 08), 2b050c1 (stage 09). origin/main had not moved
since 602d8bc, so nothing needed merging.

At writing, each workflow runs twice (push and PR):
| Workflow | Jobs | State |
|---|---|---|
| Engine CI | test | success (both) |
| Schema CI | Codegen drift detection | success (both) |
| SDK Kotlin CI (new) | Core tests, JDK 17 and 21 | running |
| SDK Swift CI | Core tests, swift 5.10 and 6.2 | push run success; PR run running |
| SDK CI (Flutter) | test | running |
SDK Swift UI does not run: the PR touches no `sdk-swift/` file.

### Gate 09 answers carried out
- Question 1: row 23b.33 in the epic plan, "Native SDKs match Dart in six corners", one render
  fixture per corner, green on the engine, Flutter, Swift and Kotlin; status "After S10".
- Question 2: the branch is pushed and PR #12 is open.
- Question 3: S7 starts when you say go after the merge.

### Next
- 11 Release: skipped by default (config.json); nothing to release before S10.
- 12 Deploy watch: PR #12's CI and the merge.
- 13-16: nothing is deployed; skipped at gate 12 as for S1 to S5.
- S7 (23b.27b): the `sdk` Android library, OkHttp `OrcaClient`, Compose renderer, 15 core widgets,
  `examples/app-android` on the Pixel 3a API 34 emulator.
