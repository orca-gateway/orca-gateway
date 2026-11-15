# 10 · UAT · native-parity-s16

## Front page

### In one breath
PR #34 is open: step 16, the plugin system on both native SDKs and Swift/Kotlin stubs in the CLI.
Rebased on origin/main after PRs #30 and #31; every suite green locally, both example apps build.
C16.1 seen by hand on the iOS simulator and the Android emulator: the plugin badge draws and runs.
The merge is yours; nothing is published (the SDKs and the CLI ship with their next release tags).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #34 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT: seen by hand at 09 (badges drawn by the plugin, a tap runs it). (default: nothing more)
3. After A: 11 skipped by default; 12 reads PR #34's checks and your merge. (default: yes)
4. Meanwhile step 18 starts, stacked on this branch; #30 unblocked step 14. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #34
https://github.com/orca-gateway/orca-gateway/pull/34, opened after gate 09 was approved under your standing rule
(its one question, "approve the stage; stage 10 pushes the branch and opens the PR", was minor). Bound to this session;
Auto-fix off, auto-merge off. Branch feat/native-parity-s16 on origin/main 81b4bc1 (PRs #30 and #31 merged): the 14
task commits (T1-T14), the step 15 close note, the rebase follow-up `refactor(sdk-swift): one error view…` (R1) and
the pipeline notes. At open (`get_status`): mergeable, 0 passing, 8 pending, 0 failing.
The body is in the session scratchpad (`s16/pr-s16.md`).

### What reviewers will find in the body
- Why: the natives degraded unknown widgets and dropped `custom:` actions; Flutter had plugins.
- What changes, by part: merger and caps, handlers, fixtures 45-47, UI contract, OrcaApp, CLI, demo and docs.
- Where the natives differ on purpose: the conflict shows the SDK's error view with the message; the Swift/Kotlin
  registry difference when an app has no plugins.
- Tests: every suite's line after the rebase; the hand checks; left for later (GestureDetector's held tap on iOS,
  custom.ts's `Custom` type, action.schema.json's catch-all, keyword prop names).

### Test file
`/Users/amrebada/.claude/plans/native-parity/phase-c-tests.md`: C16.1-C16.6 ticked on Swift and Kotlin with the test
names, the fixtures and "PR #34" (C16.1 with the hand check). Rows ticked: Swift 12 of 35, Kotlin 12 of 35.

### Not run locally
- The Linux Swift jobs (CI runs them). The new core files are Foundation-only; the generated stub and the SwiftUI
  tests sit inside `#if canImport(SwiftUI)`.
