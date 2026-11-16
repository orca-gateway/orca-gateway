# 10 · UAT · native-parity-s19

## Front page

### In one breath
PR #43 is open: step 19, DevTools and debug parity on both native SDKs.
On main 6a7f0e0; every suite green locally, the iOS 18.5 simulator run included.
C19.1-C19.7 ticked on Swift and Kotlin; chip and DevTools events checked on both devices.
The merge is yours; #38 and #43 both change OrcaApp, so the second to land needs a rebase.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #43 once its checks are green: yours, so this card waits for you. (default: ok)
2. UAT: seen by hand after group 6 (chip, tap, events validated on :6363). (default: done)
3. After A: 11 skipped by default; 12 reads PR #43's checks and your merge. (default: yes)
4. Next: step 14; its Flutter change (persistState/clearState) waits for your word. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #43
https://github.com/orca-gateway/orca-gateway/pull/43, opened after gate 09 was approved under your standing rule
(its question, "A approves the stage; then ship", was minor). Bound to this session; Auto-fix off, auto-merge off.
Branch feat/native-parity-s19 on origin/main 6a7f0e0 (no rebase needed: main has not moved): the task commits
T1-T15 with their reworks (T7, T8, T10, T15) and the pipeline notes. At open (`get_status`): 0 passing, 8 pending,
0 failing. The body is in the session scratchpad (`s19/pr-s19.md`).

### What reviewers will find in the body
- Why: the natives sent empty propTraces, no traced setState, no bodies, and had no debug options or overlay.
- What changes: resolveWithTrace in both cores; one widget_rebuild per build of a watched node; setState with
  transformTrace and affectedWidgets in Flutter's node order; Flutter's five debug options; the chip; the debugLog
  pin; no wire change, three new DevTools fixtures, the traces fixture folder, an engine schema validator test.
- Where the natives differ: a host-drawn page view's chip; a chip after a late DevTools start; follow-ups
  (X-Orca-Debug/server timing, firstFrameMs, network scope, animate affectedWidgets).
- Tests: every suite's line, the iOS 18.5 package run, the hand checks, the merge note with #38.

### Test file
`/Users/amrebada/.claude/plans/native-parity/phase-c-tests.md`: C19.1-C19.7 ticked on Swift and Kotlin with the
test names, the fixtures and "PR #43", each row corrected to Flutter's behaviour (said in its evidence). Rows
ticked: Swift 24 of 35, Kotlin 24 of 35.

### Not run locally
- The Linux Swift jobs (CI runs them). The new core code (TraceStep, resolveWithTrace, OrcaDebugOptions, the
  pageNodes hook) is Foundation-only; the core tests have no synchronous `@MainActor` methods.
- The DevTools window itself (screen control was declined); its parsing is pinned by `fixture_parse_test.dart`.
