# 12 · Deploy watch · native-parity-s17-voice

## Front page

### In one breath
PR #47 is in main as merge commit 677d114 (2026-11-16 13:24Z); all 7 checks passed.
The voice recorder ships as its own Swift and Gradle packages, released on their own.
Nothing is published by the merge: release rows 11-12 do it, after the SDK releases.
C17.3 is ticked on Swift and Kotlin in phase-c-tests.md, with test names and PR #47.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), the voice slice closed. (default: yes)
2. The video player's branch is rebased onto main 677d114 and goes on. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #47
https://github.com/orca-gateway/orca-gateway/pull/47
- In main as 677d114, a merge commit whose second parent is the PR's head 56316c9 (on main 941e789).
- Read once at this card (`gh pr checks 47`): 7 passing, 0 failing, 0 pending. Among them the voice recorder's Swift
  package job (macOS and the iOS simulator), the only proof of its build with CI's Xcode 16.4 pin.
- Gate 10 approved: question 1 answered by the user's merge (relayed by the parent session), questions 2-4 minor,
  defaults under the standing rule; 11 skipped by default.

### What ships when (yours)
1. Create the empty public repository orca-gateway/orca-voice-recorder-swift, give it a write deploy key, and add the
   private half as the Actions secret ORCA_VOICE_RECORDER_SWIFT_DEPLOY_KEY (docs/User_Actions.md, "Native parity
   step 17: the orca_voice_recorder Swift mirror").
2. Release, each run green before the next: sdk-swift 0.1.0-alpha.2 (row 9), sdk-kotlin (row 10), then rows 11 and 12.

### Next
- On A: stages 13-16 skipped ("the voice recorder has no deployed service; skipped by the default accepted at gate
  12"), the voice slice closed. Step 17's video player continues at stage 09 group 2, rebased onto main 677d114.

### Closed (gate 12, your standing rule, 2026-11-16)
PR #47 in main as 677d114 with its 7 checks green (read at this card). Gate 12 approved under your standing rule
(both questions minor, defaults); stages 13-16 skipped ("the voice recorder has no deployed service; skipped by the
default accepted at gate 12 (standing rule, minor)"); the voice slice closed. This note rides on
feat/native-parity-s17-video.
