# 10 · UAT · native-parity-s8

## Front page

### In one breath
Step 8 is ready: A8.1-A8.5 ticked on both SDKs, PR #57 open (orca-gateway/orca-gateway).
Hand checks pass on the `overlays` page on both devices; the branch sits on main 1b5bbf4.
All 54 Phase A rows are now done on both SDKs: Phase A is complete once #57 merges.

### New for you
nothing new

### Trade-offs
VoiceOver and TalkBack were not checked by hand (VoiceOver does not run in the Simulator); the PR
lists those checks for a device. A8.1 and A8.5 are corrected to what Flutter's SDK does.

### Questions for you
1. Merge PR #57 once its checks are green. (default: wait for your merge)
2. After the merge: close the slice, 11 and 13-16 skipped as in s7. (default: yes)

## Appendix

### Where it stands
PR https://github.com/orca-gateway/orca-gateway/pull/57, branch feat/native-parity-s8, on main 1b5bbf4 (PRs #53-#56,
rebased between groups 5 and 6; the generators showed no drift). Rows A8.1-A8.5 ticked ✅ / ✅ in
/Users/amrebada/.claude/plans/native-parity/phase-a-tests.md with test names, hand checks, Flutter references and the
PR. A8.1 corrected (the sheet, its width and closes; `dismissible` unread), A8.5 corrected (`duration` unread);
A8.2-A8.4 gain Flutter notes (no row weakened).

### Suites (final head)
engine 849 pass · Flutter 554 pass, analyze clean · `swift test` UI 633, core 667 · iOS scheme UI 829, core 667 ·
Kotlin core 684, sdk 892, lint clean · app-ios and app-android build · the generators leave no diff · no golden moved ·
the four native plugins: iOS packages (map 28, push 32, video 26, voice 24) and the Android packages build and test.

### Hand checks (parity-a page `overlays`)
iPhone 16 Pro simulator and Android API 34 emulator; details in 09-implementation.md (group 7) and the scratchpad
notes s8/hand-checks.md. All five rows pass on both devices. One Android finding fixed in this step (1793d880): a field
focused in the sheet took one Back more than Flutter. Not checked here: VoiceOver / TalkBack, a real finger's hold.

### Known differences and follow-ups
In the PR body. For you: VoiceOver and TalkBack on a device; the cloud Go registry (Tooltip and SnackBar gained `ios`).
Others: live nodes in an open sheet, iOS focus not restored on close, the snackbar across a push, a linear fling,
Swift's bars on the keyboard, the Tooltip arena with a long-pressing child, Kotlin's unclipped bubble, TalkBack's
contentDescription; DialogLayer.swift's copied cubic solver.

### Next
The small PR queued by the parent (2026-11-17): a page under a pushed page does not hear app background / foreground
events on Android (check main first, and Swift). Not folded into step 8.
