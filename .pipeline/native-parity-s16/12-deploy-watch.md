# 12 · Deploy watch · native-parity-s16

## Front page

### In one breath
PR #34 is merged into main as 5e3099f (2026-11-15 22:28Z); all 17 check runs passed.
The Linux Swift 5.10 job that failed before the second rebase is green.
Step 16 deploys and publishes nothing: the SDKs and the CLI ship it with their next release tags.
Rows C16.1-C16.6 are ticked on Swift and Kotlin in phase-c-tests.md, with test names and PR #34.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), step 16 closed. (default: yes)
2. Step 18 goes on, rebased onto main now that #34 is in. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #34
https://github.com/orca-gateway/orca-gateway/pull/34
- Merged 2026-11-15T22:28:56Z as 5e3099f (a merge commit; head 797ae75, after the second rebase onto 82e9027).
  Gate 10 approved under your standing rule: question 1 answered by your merge, questions 2-4 minor, defaults;
  11 skipped by default.
- Read once at this card (`gh pr checks 34`): 17 passing, 0 failing, 0 pending, among them both Linux Swift jobs
  (5.10-jammy, 6.2-noble), the iOS simulator UI tests, both JDK jobs, both Flutter jobs and the codegen drift check.

### What ships when
Nothing is released by step 16. The Swift changes reach apps with the next `sdk-swift-v*` tag, the Kotlin ones with
the next `sdk-kotlin-v*` tag, the CLI's `--lang swift|kotlin` with the next `cli-v*` tag, all through
`bash scripts/release.sh` (yours).

### What step 16 leaves for later
- The SDK's GestureDetector on iOS uses `onTapGesture`, so a held tap is dropped (Widgets/Stack.swift).
- examples/server/custom.ts calls `Custom("hapticFeedback", …)` against `Custom`'s `custom:${string}` type.
- schema/action.schema.json's `oneOf` ends in a catch-all CustomAction (strict draft-07 rejects valid built-ins).
- The generators do not escape prop names that are Swift or Kotlin keywords.

### Next
- On A: stages 13-16 skipped ("step 16 has no deployed service; skipped by the default accepted at gate 12"),
  step 16 closed. Step 18 continues at stage 09 group 2, rebased onto origin/main.

### Closed (gate 12, your standing rule, 2026-11-16)
PR #34 merged as 5e3099f with its 17 check runs green (read at this card). Gate 12 approved under your standing rule
(both questions minor, defaults); stages 13-16 skipped ("step 16 has no deployed service; skipped by the default
accepted at gate 12 (standing rule, minor)"); step 16 closed. This note rides on feat/native-parity-s18.
