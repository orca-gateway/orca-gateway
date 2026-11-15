# 10 · UAT · native-parity-s15

## Front page

### In one breath
PR #31 is open: step 15 on both SDKs (version check, sessions, analytics, device id, telemetry).
13 task commits on top of 5c6b57e, which PR #30 also carries; every suite green locally.
Hand checks done at 09 on the iOS simulator and the Android emulator; its 15 checks were pending.
The merge is yours; nothing is published (the SDKs ship with their next release tags).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #31 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT: already seen by hand at 09 (force update, the control, sessions). (default: nothing more)
3. After A: 11 skipped by default; 12 reads PR #31's checks and your merge. (default: yes)
4. Meanwhile step 16 starts on a branch stacked on this one. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #31
https://github.com/orca-gateway/orca-gateway/pull/31, opened at this stage after gate 09 was approved under your
standing rule (its last question, "approve the stage; ship pushes the branch and opens the PR", was minor). Bound to
this session; Auto-fix off, auto-merge off. Title "feat(sdk-swift, sdk-kotlin): version check, sessions, analytics,
device id and telemetry (native parity step 15)". Before the push `origin/main` was 9706551 (PR #29's merge), already
in the branch, so no rebase was needed. Over main: `5c6b57e` (local main's unpushed AnimatedBuilder, Transform and core
Video commit; PR #30 carries it too, and the body says so), the task commits T2 2d8f831, T1 313a3f9, T4 1774445,
T3 e145e15, T6 7112b41, T5 2c0861c, T7 9606fe9, T8 78b0f78, T13 7d0ce03, T9 b9b7fa1, T10 460ddd9, T12 96bafe0,
T11 fbf5422, and the pipeline notes 7b32a23.
Read once at this card (`get_status`): open, mergeable; 0 passing, 15 pending, 0 failing.
The body is in the session scratchpad (`s15/pr-s15.md`).

### What reviewers will find in the body
- Why: the natives had none of Flutter's production plumbing; rows C15.1-C15.6 pin each part to Flutter.
- What changes, by part: device id, telemetry, analytics, sessions, version check and boot, OrcaApp options, demo.
- Where the natives differ on purpose: one session per foreground period, stale flows sorted, a saved random id.
- Tests: every suite's line and the new test classes; the hand checks on both platforms.
- Left for later: step 14 (cache, local versions, preload), step 18 (host force-update view), one test-env gap.

### Test file
`/Users/amrebada/.claude/plans/native-parity/phase-c-tests.md`: C15.1-C15.6 ticked on Swift and Kotlin with the
test names and "hand-check PR #31" (C15.1).

### Not run locally
- The Linux Swift jobs (CI runs them; the core has no Apple-only import in this step's files).
