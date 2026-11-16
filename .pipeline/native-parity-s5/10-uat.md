# 10 · UAT · native-parity-s5

## Front page

### In one breath
Step 5 is ready: A5.1-A5.7 ticked on both SDKs, PR #45 open (orca-gateway/orca-gateway).
Hand checks passed on the `lists` page on both devices, before and after the rebase on 644d5d8.
38 of the 54 Phase A rows are now done on both SDKs.

### New for you
nothing new

### Trade-offs
1 auto-decided (minor): on Android the fast fling rests on its Compose test; adb flings never
reached the pager on the starved emulator (a slow swipe turns one page, offset = viewport).

### Questions for you
1. Merge PR #45 once its checks are green. (default: wait for your merge)
2. After the merge: close the slice, 11 and 13-16 skipped as in s4. (default: yes)

## Appendix

### Where it stands
PR https://github.com/orca-gateway/orca-gateway/pull/45, branch feat/native-parity-s5, on main 644d5d8 (rebased
twice: 3518792, then 644d5d8). Rows A5.1-A5.7 ticked ✅ / ✅ in
/Users/amrebada/.claude/plans/native-parity/phase-a-tests.md with test names, hand checks, Flutter line references
and the PR link. A5.4 corrected (Flutter has no onPageChanged; onScroll* fire with offset and viewport); A5.5, A5.6
and A5.7 gain Flutter notes (no row weakened). A5.6 gains the SubPage tests and the Android refetch oddity.

### Suites on this head
engine `bun test` 798 pass · Flutter 487 pass, analyze clean · `swift test` UI 456, core 548; iOS scheme UI 560,
core 548 · Kotlin `./gradlew cleanTest build --no-build-cache` core 570, sdk 642, lint clean · app-ios and
app-android build · the generator leaves no diff.

### Hand checks (parity-a page `lists`)
iPhone 16 Pro simulator and Android API 34 emulator, built from this branch, before and after the rebase; details in
09-implementation.md and the scratchpad notes s5/hand-checks.md. On the rebased Android build 2 of 7 refetches
during the emulator's worst stall reached the server but never landed; 5 landed (recorded in A5.6 and the PR).

### Known differences and follow-ups
In the PR body: Swift builds only the rows in sight; iOS flashes the indicator under thumbVisibility and thickness is
not settable; UIRefreshControl refreshes a drag begun below the top; refresh colours not settable on iOS; iOS 16-17.3
nested edge hand-off; Android nested vertical list also refreshes, 160 dp threshold, no top stretch and a 50 px
outer move; Kotlin keeps Android's fling tracker; no edge bounce. Follow-ups: ListView separator wire bug; Flutter's
Scrollbar without a controller; same-axis nested drag in the Swift pager; KeepDrag for every nested scroll kind;
duplicate Layout.swift helpers; RTL padding on eager grids; Gradle core:test inputs; ReorderableListView not wired to
Scrollbar/PullToRefresh; from s4: LocalPointerBlocked, InertButton, Modulate.

### Next
Step 6 (inputs and buttons; rows A6) opens as native-parity-s6, stacked on this branch until #45 merges. Its
inventory is drafted; the user's call to draw Checkbox, Radio, FloatingActionButton and InkWell on iOS is logged
there as theirs.
