# 12 · Deploy watch · native-parity-s15

## Front page

### In one breath
PR #31 is merged into main as c0b8645 (2026-11-15 20:44Z); all 12 check runs passed.
Step 15 deploys and publishes nothing: both SDKs ship it with their next release tags.
Rows C15.1-C15.6 are ticked on Swift and Kotlin in phase-c-tests.md, with test names and PR #31.
Local main's unpushed 5c6b57e reached origin/main through this merge.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), step 15 closed. (default: yes)
2. Step 16 (plugins) goes on, stacked on main now that #31 is in. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #31
https://github.com/orca-gateway/orca-gateway/pull/31
- Merged 2026-11-15T20:44:31Z as c0b8645 (a merge commit; head 9236afc, the codegen fix after gate 10 opened).
  Gate 10 approved under your standing rule: question 1 answered by your merge, questions 2-4 minor, defaults;
  11 skipped by default.
- Read once at this card (`gh pr checks 31`): 12 passing, 0 failing, 0 pending. No CI round after 9236afc.
- 5c6b57e (local main's AnimatedBuilder, Transform and core Video commit) is now on origin/main; PR #30 (Phase B,
  step 9) still carries it and will see it as already merged.

### What ships when
Nothing is released by step 15. The Swift changes reach apps with the next `sdk-swift-v*` tag, the Kotlin ones with
the next `sdk-kotlin-v*` tag, both through `bash scripts/release.sh` (yours). The engine gained only the demo's
`ORCA_FORCE_UPDATE` switch in examples/server; nothing in the published engine changed.

### What step 15 leaves for later
- engine/test/demo-server.test.ts does not clear `ORCA_FORCE_UPDATE` in its server env (a shell with it set fails
  that test); noted in the PR's "Left for later".
- Step 14 (cache, local versions, preload) and step 18 (a host-drawn force-update view) as the plan orders them.

### Cleanup
- The temporary worktree for the codegen fix (scratchpad `wt-s15`) was removed after 9236afc was pushed.
- The Phase C simulator (04AFD6DE) and emulator (emulator-5584) stay up for step 16's hand checks.

### Next
- On A: stages 13-16 skipped ("step 15 has no deployed service; skipped by the default accepted at gate 12"),
  step 15 closed. Step 16 continues at stage 09 group 4.

### Closed (gate 12, your standing rule, 2026-11-15)
PR #31 merged as c0b8645 with its 12 check runs green (read at this card). Gate 12 approved under your standing rule
(both questions minor, defaults); stages 13-16 skipped ("step 15 has no deployed service; skipped by the default
accepted at gate 12 (standing rule, minor)"); step 15 closed. This note rides on feat/native-parity-s16.
