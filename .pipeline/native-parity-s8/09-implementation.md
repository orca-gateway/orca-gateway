# 09 · Implementation · native-parity-s8

## Front page

### In one breath
group 5 of 7 · tasks: 2 green, 0 blocked · openDialog shows Flutter's modal bottom sheet
Barrier tap, drag and Android Back close it; closeDialog never pops a page; openDialog waits for it.
VoiceOver and TalkBack land in the panel; the page is out of reach; the keyboard lifts the panel.

### New for you
nothing new

### Trade-offs
The sheet's name follows Flutter per platform: "Dialog" on Android, none on iOS (the design said
"Bottom Sheet": a misread). An open sheet shows live nodes; Flutter keeps the first ones.

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: bring the branch up to main 1b5bbf4, then group 6, the tooltip bubbles. (default: go)

## Appendix

Cases: 5 rows split per SDK, plus the fixture half (F1, F-pins), the kinds caps (S-act, K-act), the cores' shared
cases and the engine half (D2, D-overlays); a row is ticked in phase-a-tests.md only when every half passes on both
SDKs and the hand checks agree.

### Group 1
Commits: F1 2cd6e781, F-pins a9ce895b, S-act 1deaa3d0, K-act 5e2f75bd (staged by path). Nothing pushed. Each reviewed,
fit and quality in one pass; F1 went back once (quality: fixture 52's name had spaces, now "openDialog-closeDialog";
rechecked: pass).

#### Task F1 · Fixtures 47, 52; heightFactor in schema
Files: `schema/action.schema.json` · `schema/fixtures/render/47_overlay_widgets.json` (new) ·
`schema/fixtures/actions/52_open_close_dialog.json` (new) · `engine/test/action-schema-sync.test.ts`. Commit 2cd6e781.
Cases: A8.1 fx (the schema pin) red first, green; 47 and 52 passed as written (they pin behaviour Flutter has);
corrupted copies failed the engine and Flutter runners, restored byte-identical. Engine 840/0, Flutter conformance 282,
whole 547, analyze clean.
Changed: OpenDialogAction gains the optional heightFactor number (default 0.5, AE:867); the sync test checks the TS
interface's fields against the schema. 47: a keyed Dialog (dismissible false, colour, radius, no title) around a Column
with a page-state Text (watches ["note"]), a Tooltip over a Text, a SnackBar (duration 3000, "Undo", onAction), the
two dialog buttons, a BottomSheet in the Scaffold slot. 52: [openDialog("d", 0.4), closeDialog], state unchanged,
effects [].
Decided: the closeDialog button sits in the body (the Dialog has one child); 52 runs in Flutter (no engine runner).

#### Task F-pins · Native fixture pins and runs
Files: Swift `ModelRoundTripTests.swift`, `ActionFixtureTests.swift`; Kotlin `ModelRoundTripTest.kt`,
`FixturePathsTest.kt`, `ActionFixtureTest.kt`. Commit a9ce895b.
Cases: A8.1-A8.5 fx sw/kt (`testA8_1to5_OverlayWidgetsAndDialogKindsRoundTrip_fixture47` /
`a8_1to5_overlayWidgetsAndDialogKindsRoundTrip`), A8.1 fx sw/kt (`testA8_1_OpenAndCloseDialogLeaveTheStateAndEmit
Nothing_fixture52` / `a8_1_openAndCloseDialogLeaveTheStateAndEmitNothing`); red 56≠57, 32≠33, 52 absent; green.
Changed: pins 57 ("01-47, 60-69") and 33 ("45-52"); the all-fixtures runner renamed ThirtyThree; the unimplemented-kind
examples use `custom:noSuchKind` (no handler, not in kinds: the same path closeDialog took).

#### Task S-act / K-act · both dialog kinds known
Files: `ActionExecutor.swift` / `.kt` · `ActionHandlerTest(s)` · both `capabilities.json` · `Generated.swift` / `.kt`
(one generator run, caps hash 1aaf60d6… on both) · `CapabilitiesTest(s)`. Commits 1deaa3d0, 5e2f75bd.
Cases: A8.1 core, the same four on both (`…AreKnownKinds`, `…WithNoHandlerBothChangeNoStateAndEmitNoEffect`,
`…ARegisteredHandlerRunsWithTheAction`, `…TheNextActionWaitsForTheOpenDialogHandler`) + Swift's advertised check;
kinds 26 → 28. Red: known kinds, the DevTools list, the pins; the two handler cases passed before (a registered handler
already ran ahead of the kinds check).
Changed: both kinds join `kinds`; with no handler they fall to the existing default (no state, no effect, reported to
DevTools as Flutter's built-in handlers are, AE:180-204); a page handler runs and is awaited (OP:323-374, D5).
Decided: no explicit switch branch (the default covers it). Not done: README's kind count (S-caps, G7).

### Group 5
Commits: K-dialog 2db22409, S-dialog ad4eda34 (staged by path). Nothing pushed. Twin review: fit findings on both
(Swift: the keyboard case red, a covered page dropped from the stack never ended its waiters, the page kept input
focus, the panel's name; Kotlin: the panel full width, the shell-tree case missing); both reworked once and passed on
recheck; Swift then took one nit (the Scrim's area leaves out the keyboard lift) and ran the whole iOS scheme.
Rows widened (logged): S-dialog also owns OrcaRouter.swift (closing dropped pages' sheets).

#### Task S-dialog / K-dialog · the sheet layer
Files: Swift `Widgets/DialogLayer.swift` (new), `OrcaPageModel.swift`, `OrcaApp.swift`, `Navigation/TabShellView.swift`,
`Navigation/OrcaRouter.swift`, `DialogTests.swift` (new); Kotlin `widgets/DialogLayer.kt` (new), `OrcaPageModel.kt`,
`OrcaPageView.kt`, `OrcaApp.kt`, `DialogTest.kt` (new).
Cases: A8.1: frames at 0.5, 0.4 and 640 (as wide as the content up to 640, centred: bottom_sheet.dart:417-421,
:618-621; the design said full width), from the bottom edge with no safe area, white, top 24; the barrier black54
through ease (routes.dart:1869); in 250 / out 200 on legacyDecelerate (bottom_sheet.dart:29-31); a barrier tap and a
drag past half or a fling over 700 close it (:32-33, :305-319); Back (Kotlin); a Sequential's SetState only after the
close; closeDialog with none open keeps the page; stacked sheets close one per call; a state change redraws inside;
the shell tree opens none; a page torn down or dropped while covered resumes every waiter (risk 7); handler order.
Platform (D5, the user's requirement): VoiceOver focus into the panel on open and back to the opener on close
(screenChanged / layoutChanged); TalkBack: the page cleared from semantics, the pane titled "Dialog", input focus moved
in and back (Compose has no public API to move accessibility focus: hand check); the Scrim one element that closes
(iOS: label "Scrim" and its action, only above the panel; Android: "Scrim" with "Close Bottom Sheet"); the escape
gesture (iOS); the panel above the keyboard (beyond Flutter). Swift 22 (UI 617 → 625, iOS 22/22 plus the whole
scheme: UI 810, core 666); Kotlin 21 (sdk 851 → 872). Red first, bar a few pins named in the digests (none-open, shell tree).
Decided (Flutter over the brief): closeDialog registered before the plugin host so a host's replaces the built-in,
openDialog after it so the page's beats a host's (action_executor.dart:151-156, :896; orca_page.dart:318-323); the
pane name per platform (bottom_sheet.dart:726-732; "Bottom Sheet" is only the scrim's Android hint, :1357); under tabs
the shell's snackbar paints over the sheet, a page Scaffold's under it (scaffold.dart:3197 vs :3276; orca_shell.dart
:114-117), so Swift moved the shell bar into TabStackLayers.
Known differences (in the PR): the sheet shows the page's live nodes (Flutter keeps the subtree from open time); iOS
does not give input focus back on close; a tab's drawer menu bar is covered on iOS. Follow-up: Swift copies Curves'
private cubic solver for legacyDecelerate.
Hand checks: VoiceOver and TalkBack landing in the panel and returning, the escape gesture, a real tap, drag, fling and
Back, the edge swipe off on iOS, the lift over a real keyboard with a text field in the sheet.

### Group 4
Commits: S-tipcore 82ce5acf, K-tipcore 9469a5ed, S-bar 80b2d16e, K-bar 5fdc17b9 (staged by path). Nothing pushed.
The tooltip cores moved up from G5 (they need nothing from G4; logged). Rows widened during the group (logged): K-bar
also owns OrcaPageModel.kt (the queue's reveal and swipe) and OrcaApp.kt (the titled-route bar); S-bar also owns
SnackbarQueueHostTests.swift (its two interim-bar tests).
Tooltip cores, twin review: pass both lenses; went back twice for tests only (the same inputs per case on both
SDKs, the wide-bubble doc: Flutter lays the bubble out with constraints.loosen(), so x ≥ 0; two cites).
Bars, twin review: S fit rework (two interim-bar tests red; routes over the shell), K fit rework (titled routes,
any root Scaffold, five missing cases, the keyboard floor); both rechecked; K once more (a titled route outside the
mounted shell drew no bar; now in RouteFrame); final: both pass both lenses.

#### Task S-tipcore / K-tipcore · TooltipPlacement
Files: Swift `OrcaGatewayCore/Render/TooltipPlacement.swift` + tests; Kotlin `core/.../render/TooltipPlacement.kt` +
test. Commits 82ce5acf, 9469a5ed.
Cases (six shared names, the same inputs on both): centred on the child; 24 below its centre; above when below does
not fit (both or neither: below, its top held at H − 10); clamped 10 from the edges; with ≤ 20 spare, centred in the
overlay; Flutter's timings. Red first on stubs. Swift core 660 → 666; Kotlin core 677 → 683.
Changed: a port of positionDependentBox (geometry.dart:51-66) around the child's centre (raw_tooltip.dart:881-884),
offset 24 (tooltip.dart:413), margin 10; 500 ms press (gestures/constants.dart:29), 1500 ms after release
(tooltip.dart:416, :570; raw_tooltip.dart:762-767), fade 150 / 75 with fastOutSlowIn both ways (raw_tooltip.dart:27-31).
For the tooltip UI tasks: measure the bubble with the overlay as its maximum; pass the overlay less the keyboard.

#### Task S-bar / K-bar · the M3 fixed snackbar bar
Files: Swift `Widgets/SnackbarBar.swift` (new), `Widgets/Structure.swift`, `Navigation/TabShellView.swift`,
`OrcaApp.swift`, `SnackbarBarTests.swift` (new), `SnackbarQueueHostTests.swift`; Kotlin `widgets/SnackbarBar.kt`
(new), `widgets/Structure.kt`, `navigation/TabShellScreen.kt`, `OrcaPageView.kt`, `OrcaPageModel.kt`, `OrcaApp.kt`,
`SnackbarBarTest.kt` (new).
Cases: A8.4 ui: the look (#322F35, #F5EFF7 bodyMedium 14 / 20 / 0.25, padding 24 and 14, square, full width); a long
message wraps (Flutter's Text has no maxLines: the design's "one line" was the padding constant); the safe area inside
only with no bars or footer; above the bottom bars and footer, over the bottom-sheet slot, the FAB 16 over it (the
higher of the two lifts); revealed by height through fastOutSlowIn, no fade; a swipe past 0.4 of the whole height or a
fling of 700 removes it, a short release slides back; under tabs only the shell draws it, above the tab bar; a nested
Scaffold draws none, no Scaffold draws nothing, any Scaffold with none above draws it; a titled route (Flutter's root
wrapper Scaffold) draws it at its edge, its page nested; the keyboard floor (Kotlin tested; Swift cited, hand check);
VoiceOver announces each bar once (Swift), a live region (Kotlin). Swift 21 + the two host tests reworked (UI 603 →
617; iOS 21/21, 9/9 and neighbours green); Kotlin 21 (sdk 830 → 851).
Red first: Swift's first pass and its five rework cases (proven against mutated sources); one iOS-only tab case passed
first. Kotlin: the first pass red for the right reasons; in the rework column root, titled route and keyboard ran red;
wrap, fling, toast, footer and nested Scaffold are pins of behaviour that already worked.
Also fixed: Swift's FAB read a 0 bottom inset on a device (S-static's reader sat inside ignoresSafeArea); it now
keeps 16 above the safe area (pinned by testA8_4_TheBottomSafeAreaIsInsideTheBar).
Known differences (in the PR): across a push the bar moves with the page (Flutter's Hero keeps it still); a fling is a
linear slide, not a spring; Kotlin drops the 400 cross-axis check; Swift's bottom bars ride up on the keyboard (from
before this step), so there the bar sits on the bars.
Hand checks: a real swipe and fling, the reveal's smoothness, VoiceOver / TalkBack reading the bar, the bar on the
keyboard, landscape edge to edge, real insets.

### Group 3
Commits: D2 2acf9405, K-queue ed8ab357, S-queue fd77ece9 (staged by path). Nothing pushed. D2 went back once
(the off-target "once" test had lost its two-hit check; restored with a test-only registry entry; rechecked: pass).
The queues were reviewed as twins: K pass; S went back once (its `toast` was no longer observable; now it publishes
once per head-item change, as Kotlin's Compose state; rechecked: pass).

#### Task D2 · Tooltip and SnackBar target iOS
Files: `engine/src/components/layout/tooltip.ts`, `structure/snack-bar.ts`, `engine/test/widget-targets.test.ts`,
`target-check.test.ts`, `sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift`; regenerated
`engine/src/core/widget-registry-gen.ts`, `schema/widget-registry.json` (a rerun leaves them byte-identical).
Cases: A8.3 eng, A8.5 eng (both on all four targets), IOS_ORPHANS [], the off-target examples from Video plus a
test-only AndroidOnly entry (two different hits, each once), Swift's orphan check flipped (both carry ios, neither
advertised until S-caps). Red first; engine 840 → 842, Swift core 660.
Decided: no built-in widget is off iOS now (only Video is partial: android, ios). The native capability generators
were run once to check and changed nothing. The cloud's Go registry is the user's follow-up (D2).

#### Task S-queue / K-queue · one snackbar queue at the router
Files: Swift `Navigation/OrcaRouter.swift`, `OrcaPageModel.swift`, `OrcaApp.swift`, `PageModelTests.swift`,
`SnackbarQueueHostTests.swift` (new); Kotlin `navigation/OrcaRouter.kt`, `OrcaPageModel.kt`, `OrcaPageView.kt`,
`PageModelTest.kt`, `CounterPageTest.kt`.
Cases: A8.4: two in a row one after the other; a toast between two snackbars waits its turn; a bar across a navigate
keeps its time; a refused server action's message joins as a 4000 ms snackbar (action_executor.dart:721-724). Swift
adds back, tab switch, a router-less page and the head-change publish; Kotlin adds "no Scaffold: queued, not drawn"
(its tab and router-less cases hold by construction: every page attaches, each model owns a queue). Swift UI 595 →
603, iOS scheme 15/15; Kotlin sdk 826 → 830. Red first.
Changed: the router owns the app's one queue (Flutter's root ScaffoldMessenger) and `attach` hands it to each page;
perform queues showSnackbar (?? 4000) and showToast (?? 2000); `toast` is a read-only head. Swift: OrcaSnackbars with an
injectable clock and its own wake; ToastView draws the head in the old look until S-bar. Kotlin: the queue as Compose
state ticked by withFrameMillis from any page on screen; a toast becomes an Android Toast on its turn; a snackbar goes
to the root Scaffold's host until K-bar; the page-bottom host is gone.
Baseline tests edited (reviewed: none tests less): CounterPageTest's bar flips to "queued, not drawn" (planned, D8)
and one advance 4000 → 4500 (250 in, 4000, 250 out); Swift PageModelTests gain the queued-item checks.
Nits left as is: Kotlin copies the queue's items every busy frame; the twin types have different internal names.
Moved to S-bar (G4): the Swift shell tree never attaches to the router, so a shell's snackbar goes to its own queue.

### Group 2
Commits: S-core 6261ac68, K-core b82f6ca3, S-static 826baa06, K-static 99760366 (staged by path). Nothing pushed. The cores
were reviewed as twins and went back once (both: a swipe now removes the bar at once, Flutter's Dismissible then
removeCurrentSnackBar with no leave animation, snack_bar.dart:859-871, :865; Swift: the unknown-id case could not go
red, strengthened as Kotlin's; rechecked: pass). The statics were reviewed as twins: K pass, S rework; both took
the review's findings (below); rechecked: both pass on both lenses, three nits left (listed).

#### Task S-core / K-core · DialogStack and SnackbarQueue
Files: `sdk-swift/Sources/OrcaGatewayCore/State/DialogStack.swift`, `SnackbarQueue.swift` + tests; Kotlin
`core/.../state/DialogStack.kt`, `SnackbarQueue.kt` + tests. Commits 6261ac68, b82f6ca3.
Cases (the same 13 names on both): A8.1 ×6 (`OpenResolvesTheDialogsFirstChildAsTheSheetRoot…`,
`AnUnknownIdOrNoChildrenOpensNothing`, `HeightFactorDefaultsToHalfAndNaNOrNegativeIsHalf`,
`ClosePopsTheTopSheetAndNoneOpenIsANoOp`, `ADismissPopsTheTopSheet`, `StackedSheetsCloseOnePerCall`); A8.4 ×7
(`ItemsShowInArrivalOrder`, `DurationsDefaultTo4000…`, `ABarEnters250ThenShows…ThenLeaves250`,
`TheDurationCountsOnlyOnceTheBarIsFullyIn`, `ASwipeRemovesTheBarAtOnce`, `NothingIsDroppedOrReplaced`,
`TheNextEntersOnlyAfterThePreviousHasLeft`). Red first on stubs (12/13 Swift, 13/13 Kotlin after the rework).
Changed: open collects the Dialog's children depth-first (root = the first child, component_renderer.dart:44-54,
orca_page.dart:332-343), nothing collected opens nothing; close and dismiss pop the top. The queue: entering 250 →
showing (counted once fully in) → leaving 250 → next; swipe removes the head in any phase; time passed in.
Decided: a node met twice is listed once (Flutter would recurse forever); a sheet keeps its nodes from open time.

#### Task S-static / K-static · BottomSheet, slot, SnackBar, inert Dialog
Files: Swift `Widgets/Overlays.swift` (new), `Widgets/Structure.swift`, `NodeView.swift`, `BottomSheetTests.swift`,
`SnackBarWidgetTests.swift`; Kotlin `widgets/Overlays.kt` (new), `widgets/Structure.kt`, `BottomSheetTest.kt`,
`SnackBarWidgetTest.kt`.
Cases: A8.2, A8.5, A8.1 (in place). Swift 17 (UI 578 → 595; iOS scheme on both classes 19/19 with the two hosted
tests), Kotlin 12 (sdk 814 → 826). Every case red first; Swift's hosted slot test also failed on the old Scaffold;
Kotlin's Dialog put the next child at 107 against Flutter's 80 until it became a 0x0 Box.
Changed: BottomSheet = SB:235-249; SnackBar = SB:429-465 (duration unread); the Dialog is a real zero-size child
(Flutter's SizedBox.shrink keeps its place in gaps). The slot: #F7F2FA, top radius 28, ≤ 640 centred, over the body
(which keeps its size), above the bottom bars, at the content bottom (no safe area, scaffold.dart:3396-3398); the FAB
at min(16 above the bottom, its centre on the sheet's top edge) (floating_action_button_location.dart:565-586).
Review findings fixed: a long label stays on one line and the content shrinks (Swift); the label is a Button so a tap
and VoiceOver activation fire onAction, pinned by a hosted accessibilityActivate() (Swift); an enclosing
DefaultTextStyle layers under both texts (both); the Dialog's zero size pinned in a gap-10 Row (Swift); the decorated
boxes take touches as Flutter's DecoratedBox (Kotlin).
Decided: the Swift activation test enables accessibility automation through a private libAccessibility symbol in
test code only, and fails if it disappears (logged, minor). Kotlin layers the texts by hand: a parsed style always
sets fontStyle, Flutter's const style keeps a DTS italic.
Not done (hand checks): a real finger tap on the label (iPhone); the slot under the home indicator (iPhone) and under
the gesture bar with the FAB lift from 16 above the inset (Android: Robolectric has zero insets). Registration and
caps are S-caps / K-caps (G7); a snackbar over the slot is S-bar / K-bar (G4).
Nits left as is: Swift's line keeping a DTS italic has no case of its own (Kotlin pins italic); Kotlin's touch box
covers the cut corners (16 on the sheet, 4 on the bar) where Flutter's BoxDecoration.hitTest lets them through; a
label wider than the whole bar is ellipsised on Kotlin, overflows on Swift and Flutter.

### Test run (group 5, both tasks' final files)
engine `bun test` 842 pass · Flutter 547 pass, analyze clean · `swift test` UI 625, core 666 · the whole iOS scheme UI
810, core 666, no state-during-update warning · Kotlin `./gradlew cleanTest :sdk:cleanTestDebugUnitTest build
--no-build-cache` core 683, sdk 872, lint clean.

### Test run (group 4, all four tasks' final files)
engine `bun test` 842 pass · Flutter 547 pass, analyze clean · `swift test` UI 617, core 666 · iOS scheme on
SnackbarBarTests 21/21, SnackbarQueueHostTests 9/9, BottomSheetTests 10/10, IconButtonFabTests 14/14, SafeAreaShell,
TabShell, AppBoot and Golden 37/37 · Kotlin `./gradlew cleanTest :sdk:cleanTestDebugUnitTest build --no-build-cache`
core 683, sdk 851, lint clean.

### Test run (group 3, all three tasks' final files)
engine `bun test` 842 pass · Flutter 547 pass, analyze clean · `swift test` UI 603, core 660 · iOS scheme on
SnackbarQueueHostTests and PageModelTests 15/15 · Kotlin `./gradlew cleanTest :sdk:cleanTestDebugUnitTest build
--no-build-cache` core 677, sdk 830, lint clean · gen-widget-registry leaves no diff.

### Test run (group 2, all four tasks' final files)
engine `bun test` 840 pass · Flutter 547 pass, analyze clean · `swift test` UI 595, core 660 · iOS scheme on
BottomSheetTests and SnackBarWidgetTests 19/19 · Kotlin `./gradlew cleanTest :sdk:cleanTestDebugUnitTest build
--no-build-cache` core 677, sdk 826, lint clean.

### Test run (group 1, all four tasks' final files)
engine `bun test` 840 pass · Flutter 547 pass, analyze clean · `swift test` UI 578, core 647 · Kotlin
`./gradlew cleanTest :sdk:cleanTestDebugUnitTest build --no-build-cache` core 664, sdk 814, lint clean · the generators
leave no diff (caps hash 1aaf60d6… on both SDKs).

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Follow-up for the user: Kotlin's ContainerWidget decoration takes no touch, unlike Flutter's DecoratedBox (the
new overlay widgets do).
