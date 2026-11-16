# 12 · Deploy watch · native-parity-s17-video

## Front page

### In one breath
PR #49 is in main as merge commit 3880607 (2026-11-16 16:32Z); all 9 checks passed.
The video player ships as its own Swift and Gradle packages, released on their own.
Nothing is published by the merge: release rows 13-14 do it, after the SDK releases.
C17.2 is ticked on Swift and Kotlin in phase-c-tests.md, with test names and PR #49.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), the video slice closed. (default: yes)
2. The map's branch is rebased onto main 3880607 and goes on. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #49
https://github.com/orca-gateway/orca-gateway/pull/49
- In main as 3880607, a merge commit whose second parent is the PR's head 8eb855c (on main d82ed11).
- Read once at this card (`gh pr checks 49`): 9 passing, 0 failing, 0 pending. Two Swift package jobs (the video's
  and the voice's, macOS and the iOS simulator) were cancelled unstarted on the first run because no hosted macOS
  runner was acquired; re-running the failed jobs passed them on the PR head before the merge.
- Gate 10 approved: question 1 answered by the user's merge (relayed by the parent session), questions 2-4 minor,
  defaults under the standing rule; 11 skipped by default.

### What ships when (yours)
1. Create the empty public repository orca-gateway/orca-video-player-swift, give it its own write deploy key, and add
   the private half as the Actions secret ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY (docs/User_Actions.md, "Native parity
   step 17: the orca_video_player Swift mirror").
2. Release, each run green before the next: sdk-swift 0.1.0-alpha.2 (row 9), sdk-kotlin (row 10), then rows 13 and 14.

### Next
- On A: stages 13-16 skipped ("the video player has no deployed service; skipped by the default accepted at gate 12
  (standing rule, minor)").
- The map plugin (native-parity-s17-map) is rebased onto main 3880607 before its PR; push is plugin 4 of 4.
