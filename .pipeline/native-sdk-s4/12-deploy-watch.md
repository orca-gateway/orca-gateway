# 12 · Deploy watch · native-sdk-s4

## Front page

### In one breath
PR #8 is open and mergeable; nothing is merged. CI on its head 744ccd6: 4 of 5 checks passed.
The iOS UI job (counter golden, app-ios build) was still running at writing; S3's took 3 min.
Nothing deploys: S4 is SDK code and simulator examples. The UAT servers are stopped.

### New for you
Nothing new.

### Trade-offs
1 done: UAT passed on your word ("A" at gate 10).
2 done: epic row 23b.23 now says S2's prompt stays and DevTools is the debug cue.
3 noted: Auto-fix stays off for #8, so CI results reach me only when you ask.

### Questions for you
1. Merging #8 is yours, once its checks are green. (default: I do not merge)
2. After A: 13-16 are skipped (nothing deployed) and S4 is closed. (default: yes)
3. Next: S5 (23b.25-26, the mirror and docs) plus the pre-release min-SDK fix, from main
   after #8 merges? (default: go)
4. The sdk patch (S3's DevTools builders, S4's 426 page) is yours, via release.sh. (default: after)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #8
https://github.com/orca-gateway/orca-gateway/pull/8, open, mergeable, not merged. Head 744ccd6
(the stage 10 pipeline commit); the code head is e480acf. Engine CI does not run: S4 does not
touch the engine.

Checks on 744ccd6 at 19:19:32Z:

| Check | Result |
|---|---|
| Codegen drift detection | success (10 s) |
| Core tests, swift 5.10-jammy, Linux | success (45 s) |
| Core tests, swift 6.2-noble, Linux | success (53 s) |
| SDK tests (`test`) | success (1 min 30 s) |
| UI tests and example, iOS simulator | running since 19:17:15Z |

The same workflows ran on e480acf when the PR opened: Schema, SDK and SDK Swift passed; its iOS UI
run was also still going. Locally the iOS suite passed 111/111 core and 50/50 UI on the same code.

### Cleanup
- The three UAT servers (:8097 default, :8095 warn, :8096 require) are stopped; the ports are free.
- The simulator keeps app-ios installed. Docker on 8080, the other bun on 8091 and DevTools' 6363
  were not touched.

### What S4 leaves for later
- The Flutter warn-wrapper crash: its own session, started by you at gate 09
  ("Fix Flutter crash on the warn-policy page wrapper"), with its own PR.
- The engine's min-SDK gate for pre-release versions such as `0.1.0-alpha.1`: S5 (gate 09, q 4).
- S2's Card does not fill under stretch, unlike Flutter's; the forced-axis rule from S4 would cover
  it, at the cost of re-recording S2's goldens.
- Flutter's ClipRRect reads only a number radius; the corners form is Swift only for now.
- ecommerce's search reads `V.event("query")`, but both SDKs send `{value}`.
- CI's Xcode 16.4 has a golden for counter only; warn, require and native-widgets are skipped
  there until goldens are recorded with its iOS SDK 18.5.
- The sdk patch (question 4).

### Next
On A, stages 13-16 are skipped with the reason "S4 has no deployed surface; skipped by the default
accepted at gate 12 (A)", and S4 is closed. S5 starts as native-sdk-s5 from main when you say go:
23b.25 (the release.sh mirror and subtree-split CI job) and 23b.26 (docs), plus the pre-release
min-SDK fix.
