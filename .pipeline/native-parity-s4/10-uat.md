# 10 · UAT · native-parity-s4

## Front page

### In one breath
Step 4 is ready: A4.1-A4.5 ticked on both SDKs, PR #44 open (orca-gateway/orca-gateway).
Both hand checks passed on the `effects` page; the 11 wrappers draw and take taps as Flutter's.
31 of the 54 Phase A rows are now done on both SDKs.

### New for you
nothing new

### Trade-offs
1 auto-decided (minor): on Android, "an up/down drag at scale 1 scrolls the page" rests on its
Compose test and the iPhone check, as the emulator's System UI kept hanging on a starved host.

### Questions for you
1. Merge PR #44 once its checks are green. (default: wait for your merge)
2. After the merge: close the slice, 11 and 13-16 skipped as in s3. (default: yes)

## Appendix

### Where it stands
PR https://github.com/orca-gateway/orca-gateway/pull/44, branch feat/native-parity-s4, on main 6a7f0e0 (no rebase
needed). Rows A4.1-A4.5 ticked ✅ / ✅ in /Users/amrebada/.claude/plans/native-parity/phase-a-tests.md with test names,
hand checks, Flutter line references for the hit-test notes and the PR link. A4.3's note gains the unclipped
ColorFiltered difference; A4.2 and A4.4 gain notes on Flutter's hit testing (no row weakened).

### Suites on this head
engine `bun test` 754 pass · Flutter 350 pass, analyze clean · `swift test` 0 failures, iOS scheme green (S-caps run;
no Swift change after) · Kotlin `./gradlew build` core 397, sdk 436, lint clean · the three generators leave no diff.

### Hand checks (parity-a page `effects`)
iPhone 16 Pro simulator and Android API 34 emulator (density 440), both built from this head's code; details and
measurements in 09-implementation.md (Hand check, iPhone; Hand check, Android). Pinches on Android were raw two-finger
touch events (adb root on the session's own emulator, undone after).

### Known differences and follow-ups
In the PR body: iOS materials for the blur; natives clip BackdropFilter and ColorFiltered to the box; the Kotlin blur
copy's staleness cases; Kotlin multiply below API 29; iOS fixed pinch focal point; zoomed drag inside a scroll view;
zoomed iOS text field past the clip; no fling inertia; Compose's 48 dp touch target; Android 11 scrim forced in tests.
Follow-ups: Kotlin builders not reading LocalPointerBlocked; InertButton vs material3; Modulate below API 29.

### Next
Step 5 (lists, grids, pages, pull to refresh; rows A5) opens as native-parity-s5, stacked on this branch until #44
merges. Its inventory is drafted.

### Merged
PR #44 merged by amrebada at 2026-11-16T08:22:53Z (merge 992652c, head d16d855), every PR check green after one rerun
of the JDK 17 job (a Maven Central 429); main green at the merge (Engine, Schema, SDK, SDK Swift, SDK Kotlin CI). Gate
10 approved under the standing rule, Q1 answered by the merge itself; 11 skipped by default; 12 approved; 13-16 skipped
(no deploy target).
