# 12 · Deploy watch · native-parity-s18

## Front page

### In one breath
PR #38 is merged into main as 3518792 (2026-11-16 08:56Z); all 15 check runs passed.
Before the merge it was rebased onto main 8a7276f: the widget pins now say 56.
Step 18 deploys and publishes nothing: the SDKs ship it with their next release tags.
Rows C18.1-C18.5 are ticked on Swift and Kotlin in phase-c-tests.md, with test names and PR #38.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), step 18 closed. (default: yes)
2. Step 14 goes on, rebased onto main 3518792 now that #38 is in. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #38
https://github.com/orca-gateway/orca-gateway/pull/38
- Merged 2026-11-16T08:56:01Z as 3518792 (a merge commit; head 862d39d, after the third rebase onto 8a7276f).
  Gate 10 approved under your standing rule: question 1 answered by your merge, questions 2-4 minor, defaults;
  11 skipped by default.
- Read once at this card (`gh pr checks 38`): 15 passing, 0 failing, 0 pending, among them both Linux Swift jobs,
  the iOS simulator UI tests, both JDK jobs, both Flutter jobs and the codegen drift check.
- The third rebase met main's step 3, 4 and 19 work: the debug overlay and the DevTools request bodies kept beside
  the error views and the 30 s timeout (OrcaApp and OrcaClient in both SDKs); the capability vectors regenerated
  (56 widgets, one hash on both sides); the A3.1, B10 and C1 pins and the README counts moved to 56.

### What ships when
Nothing is released by step 18. The Swift changes reach apps with the next `sdk-swift-v*` tag and the Kotlin ones
with the next `sdk-kotlin-v*` tag, through `bash scripts/release.sh` (yours).

### Next
- On A: stages 13-16 skipped ("step 18 has no deployed service; skipped by the default accepted at gate 12"),
  step 18 closed. Step 14 continues at stage 09 group 6, rebased onto origin/main 3518792.

### Closed (gate 12, your standing rule, 2026-11-16)
PR #38 merged as 3518792 with its 15 check runs green (read at this card). Gate 12 approved under your standing rule
(both questions minor, defaults); stages 13-16 skipped ("step 18 has no deployed service; skipped by the default
accepted at gate 12 (standing rule, minor)"); step 18 closed. This note rides on feat/native-parity-s14.
