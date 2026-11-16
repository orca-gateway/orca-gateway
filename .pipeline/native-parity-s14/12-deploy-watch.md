# 12 · Deploy watch · native-parity-s14

## Front page

### In one breath
PR #46 is in main as merge commit 941e789 (2026-11-16 12:26Z); all 17 check runs passed.
Before the merge it was rebased onto main 20611b2: saved-state fixtures 49-51, 26 action kinds.
Step 14 deploys and publishes nothing: the SDKs ship it with their next release tags.
Rows C14.1-C14.6 are ticked on Swift and Kotlin in phase-c-tests.md, with test names and PR #46.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), step 14 closed. (default: yes)
2. Step 17's voice recorder goes on, rebased onto main 941e789 now that #46 is in. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #46
https://github.com/orca-gateway/orca-gateway/pull/46
- In main as 941e789, a merge commit whose second parent is the PR's head 5c44c58 (after the rebase onto 20611b2).
  GitHub still showed the PR as open when this card was written; the commit is on main either way.
  Gate 10 approved under your standing rule: question 1 answered by your merge, questions 2-4 minor, defaults;
  11 skipped by default.
- Read once at this card (`gh pr checks 46`): 17 passing, 0 failing, 0 pending.
- The rebase onto 20611b2 met main's step 5 (lists, pages, refetchPage): the saved-state action fixtures moved to
  49-51 after main's 48_refetchPage, the action kinds count 26 on both sides, and a refetched page lays its saved
  entry over the fresh seed under the SubPages' carried keys, as Flutter's initPage (T21).

### What ships when
Nothing is released by step 14. The Swift changes reach apps with the next `sdk-swift-v*` tag and the Kotlin ones
with the next `sdk-kotlin-v*` tag, through `bash scripts/release.sh` (yours).

### Next
- On A: stages 13-16 skipped ("step 14 has no deployed service; skipped by the default accepted at gate 12"),
  step 14 closed. Step 17's voice recorder continues at stage 09 group 4, rebased onto origin/main 941e789.

### Closed (gate 12, your standing rule, 2026-11-16)
PR #46 in main as 941e789 with its 17 check runs green (read at this card). Gate 12 approved under your standing rule
(both questions minor, defaults); stages 13-16 skipped ("step 14 has no deployed service; skipped by the default
accepted at gate 12 (standing rule, minor)"); step 14 closed. This note rides on feat/native-parity-s17-voice.
