# 10 · UAT · native-parity-s2

## Front page

### In one breath
PR #36 is open against main: both native SDKs now run onInit, onVisible, app background and
foreground, the three scroll triggers, once, always and debugLog as Flutter does.
Rows A2.1 to A2.6 pass on both SDKs (12 of 12 cells); hand-checked on an iPhone and an Android.
Rebased on main after #32 and #34. The merge is yours; nothing is published.

### New for you
nothing new

### Trade-offs
none needs you: 6 auto-decided at gate 09 (Swift scroll edges 0.5 pt, Android edge flick, covered
Android pages, public debugLog line, reverse offset, the guard on the page model); the known
differences and 5 follow-ups are in the PR body.

### Questions for you
1. Merge PR #36 once its checks are green: yours. (default: ok; step 3 starts next and is
   based on main once #36 is in)
2. After A: 11 skipped by default, 12 reads the PR's checks, 13 to 16 skipped. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #36
https://github.com/orca-gateway/orca-gateway/pull/36, base `main`, head `feat/native-parity-s2` (04363bd). Bound to
this session, Auto-fix off, auto-merge off. Rebased on `origin/main` 96094da (#32 tabs and drawer, #34 plugin system)
by an implementer; 19 files overlapped; fit and quality reviews of the resolutions pass. 27fcf7b regenerates the
capability code, 04363bd fixes two tests (merge fallout). Backup ref `backup/native-parity-s2-pre-rebase` (44c2aef),
local only.

### Suites at the head (local)
engine 748 pass · Flutter 330 (24 action fixtures), analyze clean · Kotlin `./gradlew build --rerun-tasks` core 351
+ sdk 288, lint clean · Swift macOS 190 UI + 350 core, no warnings · iOS scheme (iPhone 16 Pro simulator, iOS 18.5)
220 UI + 350 core, no golden moved · the three generators: no drift. Not run locally: CI's Xcode 16.4.

### Hand checks (demo app `parity-a`, page `lifecycle`, example server on :8131)
| Row | iPhone 16 Pro simulator, iOS 18.5 (04363bd) | Android emulator, API 34 (74ae3f5, rechecked on 04363bd) |
|---|---|---|
| A2.2 | onVisible 1 on open; still 1 after redraws, page scrolls, two trips away | the same |
| A2.3 | four counters 0 on launch, 1, then 2 | the same (task brought back with am start) |
| A2.4 | not by finger: a drag in the nested box moves the page (step 1 page too; follow-up) | offset, maxExtent, atEnd, delta live; one begin/end per drag and fling |
| A2.5/6 | once 1, always counts, debugLog in the unified log | once 1, always 3, `I parity: visible 1` in logcat |
The first Android boot ran out of memory (system and GMS ANRs); the scroll checks ran after a cold restart.

### Rows
phase-a-tests.md rows A2.1 to A2.6 are ticked in both columns with their tests and PR #36 (19 of 54 rows so far).

### Follow-ups (in the PR body)
Android app events for covered pages · Android edge flick that moves nothing · viewport onVisible (all three SDKs) ·
iOS nested same-axis scroll by finger (check on a device) · stale action-kind counts in the SDK READMEs and one
test comment (already stale on main).
