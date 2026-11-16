# 10 · UAT · native-parity-s14

## Front page

### In one breath
PR #46 is open on main 644d5d8 (steps 12-13 merged): offline boot, static-flow cache, saved state.
Every suite green; iOS 18.5 simulator 560 + 532; both demo apps build. C14.1-C14.6 ticked, 30 of 35.
Seen by hand on both devices: offline boot, the boot error, save, session, forget and visits.
At open: mergeable, 8 checks pending. The merge is yours.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #46 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT: seen by hand after group 7 (C14.6 and C14.2 again); nothing left to see. (default: done)
3. After A: 11 skipped by default; 12 reads PR #46's checks and your merge. (default: yes)
4. Meanwhile step 17 (voice recorder, its own package) starts on main 644d5d8. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #46
https://github.com/orca-gateway/orca-gateway/pull/46, opened after gate 09 was approved under your standing rule (its
one question, "A approves the stage; the step 14 PR follows", was minor). Bound to this session; Auto-fix off,
auto-merge off. Branch feat/native-parity-s14 on origin/main 644d5d8 (PRs #41, #42): groups 1-7 of 08, the merge
fixes T17 and T18, the step 18 and 19 pipeline closes, one commit per task (group 7's reworks folded). At open
(`get_status`): mergeable, 0 passing, 8 pending, 0 failing. The body is in the session scratchpad (`s14/pr-s14.md`).

### What reviewers will find in the body
- Why: the natives could not boot offline or keep state across a restart; no SDK had persistState/clearState
  (decision 3 = A adds them to all three).
- What changes: FileKeyValueStore, StaticFlowManager and preload in both cores; OrcaApp's preloadedConfig,
  staticFlowManager, enableOffline boot and cache-first pages; SavedState in all three SDKs and its OrcaApp wiring;
  the wire format's five sync points (PersistState, the fixture format's saved/expected.saved/load, the offline
  fixture, action fixtures 48-50, 25 advertised kinds); ORCA_PRELOAD and the saved-state demo; the READMEs.
- Where the natives differ on purpose: the native "Try again"; a hand-built router saves only when given a SavedState.
- Tests: every suite's line, the new test classes, the pins moved; the hand checks; left for later.

### Test file
`/Users/amrebada/.claude/plans/native-parity/phase-c-tests.md`: C14.1-C14.6 ticked on Swift and Kotlin with test
names, the fixtures and "PR #46"; C14.2 corrected to Flutter's screen and checked again by hand; C14.6 with decision
3 and both devices' hand check. Rows ticked: Swift 30 of 35, Kotlin 30 of 35.

### Not run locally
- The Linux Swift jobs and Swift 5.10 (CI runs them). The new core files are Foundation-only.
