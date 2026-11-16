# 10 · UAT · native-parity-s6

## Front page

### In one breath
Step 6 is ready: A6.1-A6.7 ticked on both SDKs, PR #50 open (orca-gateway/orca-gateway).
Hand checks pass on the `forms` page on both devices, and a smoke check after the d82ed11 rebase.
45 of the 54 Phase A rows are now done on both SDKs.

### New for you
nothing new

### Trade-offs
2 auto-decided (minor): the iOS InkWell highlight stays until the lift (as Kotlin's);
Compose's 48 dp touch target on small Kotlin widgets is a follow-up in the PR body.

### Questions for you
1. Merge PR #50 once its checks are green. (default: wait for your merge)
2. After the merge: close the slice, 11 and 13-16 skipped as in s5. (default: yes)
3. Regenerate the cloud Go registry after the merge (4 widgets gained `ios`). (default: yours)

## Appendix

### Where it stands
PR https://github.com/orca-gateway/orca-gateway/pull/50, branch feat/native-parity-s6, on main d82ed11 (rebased three
times: 941e789, 677d114, then d82ed11 after PR #48's slivers). Rows A6.1-A6.7 ticked ✅ / ✅ in
/Users/amrebada/.claude/plans/native-parity/phase-a-tests.md with test names, hand checks, Flutter line references and
the PR link. A6.4 corrected ("its children" → "its child"); A6.7 rewritten to Flutter's real disabled and no-handler
behaviour; A6.1-A6.6 gain Flutter notes (no row weakened).

### Suites on this head
engine `bun test` 822 pass · Flutter 544 pass, analyze clean · `swift test` UI 531, core 619; iOS scheme UI 682, core
619 · Kotlin `./gradlew cleanTest :sdk:cleanTestDebugUnitTest build --no-build-cache` core 637, sdk 759, lint clean ·
app-ios and app-android build · the three generators leave no diff. Caps hash 00a7fbbd… on both SDKs (82 widgets).

### Hand checks (parity-a page `forms`)
iPhone 16 Pro simulator and Android API 34 emulator, details in 09-implementation.md and the scratchpad notes
s6/hand-checks.md. The iOS InkWell needed three reworks found only by hand (a hold fired a tap; then taps were lost
twice); the fourth check passed. After the rebase: Checkbox, Radio, Switch and the FAB again on both devices.

### Known differences and follow-ups
In the PR body. For you: the Flutter bare-field white text (a likely Flutter builder bug the natives now follow) and
the cloud Go registry. Others: Kotlin 48 dp touch targets, the iOS keyboard on a disabled bare field, the Swift
GestureDetector hold that also taps, Kotlin long-press timing outside step 6's builders, LocalPointerBlocked, the
engine's missing `stateKey` / Switch `label` / unread `validator`, the step 1 decorated TextField look.

### Next
Step 7 opens as native-parity-s7, stacked on this branch until #50 merges.
