# 12 · Deploy watch · native-parity-s17-map

## Front page

### In one breath
PR #51 is in main as merge commit 2ca21c9 (2026-11-16 19:14Z); all 11 checks passed.
The Google map ships as its own Swift and Gradle packages, released on their own.
Nothing is published by the merge: release rows 15-16 do it, after the SDK releases.
C17.1 Swift ticked; C17.1 Kotlin stays ☐ until your Google Maps Android key is in.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. On A: 13-16 skipped (no deployed service), the map slice closed. (default: yes)
2. The push branch is rebased onto main 2ca21c9 and goes on, iOS on A. (default: go)
3. Your Google Maps Android key, to finish C17.1 Kotlin's hand check. (default: wait)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #51
https://github.com/orca-gateway/orca-gateway/pull/51
- In main as 2ca21c9, a merge commit whose second parent is the PR's head aaecd67 (first parent 06422c1, PR #50).
- Read once at this card (`gh pr checks 51`): 11 passing, 0 failing, 0 pending. The map's and the video's Swift
  package jobs (macOS and the iOS simulator) were cancelled unstarted on the first run because no hosted macOS arm64
  runner was acquired; re-running the failed jobs passed them on the PR head before the merge.
- Gate 10 approved: question 1 answered by the user's merge (relayed by the parent session: "PR 50 and 51 merged, go
  with your recommendation"), questions 2-4 minor, defaults under the standing rule; 11 skipped by default.

### What ships when (yours)
1. Create the empty public repository orca-gateway/orca-google-map-swift, give it its own write deploy key, and add
   the private half as the Actions secret ORCA_GOOGLE_MAP_SWIFT_DEPLOY_KEY (docs/User_Actions.md, "Native parity
   step 17: the orca_google_map Swift mirror").
2. Release, each run green before the next: sdk-swift 0.1.0-alpha.2 (row 9), sdk-kotlin (row 10), then rows 15 and 16.
3. A Google Maps Android API key (docs/User_Actions.md, the native apps' key section) in
   examples/app-android/local.properties as GOOGLE_MAPS_ANDROID_API_KEY, for the keyed Android walk; give it in this
   session and it is used locally only, never committed.

### Next
- On A: stages 13-16 skipped ("the Google map has no deployed service; skipped by the default accepted at gate 12
  (standing rule, minor)").
- The push plugin (native-parity-s17-push, plugin 4 of 4) is rebased onto main 2ca21c9 before its PR; iOS on answer A.
