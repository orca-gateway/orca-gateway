# 12 · Deploy watch · native-sdk-s3

## Front page

### In one breath
You merged PR #7 at 17:36Z as 80f144a. All 6 checks passed on its head, f4e8477.
Main CI on 80f144a: Schema, Engine and SDK Swift passed; SDK CI was still running at writing.
Nothing deploys: S3 is SDK code and a simulator example. The example server on :8097 is stopped.

### New for you
Nothing new.

### Trade-offs
1 done: UAT passed on your word ("A" at gate 10).
2 noted: #7 went in as a merge commit, like #4; still your call each time.

### Questions for you
1. After A: 13-16 are skipped (nothing deployed) and S3 is closed. (default: yes)
2. Next: S4 (23b.23-24) as native-sdk-s4 from main? At its stage 08 you choose whether to add
   Stack, Positioned, ClipRRect, GestureDetector and a button-style hook. (default: go)
3. The Dart DevTools builders want an sdk patch; you run release.sh. (default: with S4's release)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #7
- Merged by you at 2026-11-06T17:36:25Z as merge commit 80f144a.
- The merge differs from the head f4e8477 by one file: `scripts/release.sh` from #6, already on main.
- Checks on f4e8477, all passed:
  - Codegen drift detection (8 s)
  - Core tests, swift 5.10-jammy and 6.2-noble, Linux (43 s, 54 s)
  - UI tests and example, iOS simulator (3 min 10 s), with the golden and the app-ios build
  - SDK tests (1 min 48 s) and Engine tests (10 s)

### Main on 80f144a
| Workflow | Result |
|---|---|
| Schema CI | success |
| Engine CI | success |
| SDK Swift CI | success |
| SDK CI | in progress when this was written; the same code passed as the PR's "test" check |

### Cleanup
- The example server (`PORT=8097 bun run index.ts`) is stopped and the port is free.
- The DevTools stand-in on 6363 was stopped at stage 09.
- The simulator still has app-ios installed. Docker on 8080 and the other bun on 8091 were not
  touched.

### What S3 leaves for later
- A cross-SDK fixture for addComponent, updateComponent, deleteComponent and replaceComponent.
  It needs a node tree in action fixtures and support in the Dart runner (gate 09, trade-off 2).
- Swift prop traces for widget_rebuild (gate 09, trade-off 3).
- A test for Flutter's once-per-type FallbackPrompt warning, which needs a hook to capture what
  OrcaDebug sends.
- The sdk patch for `sdk/lib/src/debug` and the renderer (question 3).
- Your two questions at gate 09, both input for S4's stage 08:
  - a host button style for iOS;
  - the food-delivery screen, which needs Stack, Positioned, ClipRRect and GestureDetector
    beyond the six S4 widgets.

### Next
On A, stages 13-16 are skipped with the reason "S3 has no deployed surface; skipped by the default
accepted at gate 10 (A)", and S3 is closed. S4 starts as native-sdk-s4 from main when you say go:
23b.23 (FallbackPrompt policies, 426, debug placeholder) and 23b.24 (six widgets).
