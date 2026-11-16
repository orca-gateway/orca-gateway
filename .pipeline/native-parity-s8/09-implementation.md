# 09 · Implementation · native-parity-s8

## Front page

### In one breath
group 2 of 7 · tasks: 4 green, 0 blocked · the two pure cores and the static overlay widgets
S-core / K-core: DialogStack (the Dialog's subtree, heightFactor ?? 0.5) and one SnackbarQueue FIFO.
S-static / K-static: BottomSheet, the Scaffold slot (the FAB lifted), SnackBar, an inert Dialog.

### New for you
nothing new

### Trade-offs
A swipe removes a snackbar at once, as Flutter does (the design said "starts leaving"; corrected).
SnackBar texts take an enclosing DefaultTextStyle under their own, as Flutter (review finding).

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 3, one snackbar queue at the router, Tooltip and SnackBar on iOS. (default: go)

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
