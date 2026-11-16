# 08 · Tasks · native-parity-s8

## Front page

### In one breath
tasks: 22 in 7 groups · widest group: 4 · cases: 5 of 5 placed
Step 8 on both SDKs: the dialog sheet, BottomSheet and its slot, Tooltip, SnackBar and one queue.
G1 fixtures 47, 52, both dialog kinds. G2 the cores, static widgets. G3 the queue, iOS targets.
G4 the M3 bar. G5 the sheet layer, tooltip cores. G6 the bubbles. G7 caps 89 → 93, page overlays.

### New for you
nothing new

### Trade-offs
2 decided by you (11-16): sheet and tooltip drawn by us; Back, focus, backdrop, keyboard covered.
1 auto-decided (minor): the dialog kinds go out in G1 with fixture 52 (as refetchPage did), not G7.
Rows A8.1 and A8.5 corrected to Flutter: a bottom sheet that ignores dismissible; a static SnackBar.

### Questions for you
1. Commands as at baseline; Swift on macOS and the iOS scheme on DA7254F5. (default: as found)
2. One commit per task, one gate per group; nothing pushed before stage 10. (default: yes)
3. Hand checks on both devices after G7, VoiceOver and TalkBack on the sheet. (default: yes)
4. A text field in a sheet stays above the keyboard, beyond Flutter (your ask). (default: yes)

## Appendix

### Where step 8 comes from
Plan /Users/amrebada/.claude/plans/native-parity/plan.md:110-115 (step 8, M, 4 widgets + 2 actions). Stages 05-07
skipped. Design in force: .pipeline/native-parity-s8/design.md (D1-D12, rows A8.1-A8.5 after corrections); facts:
.pipeline/native-parity-s8/inventory.md. The design departs from the plan's hints where Flutter differs: `.sheet` with
detents and ModalBottomSheet → a sheet layer the SDKs draw (q1, the user's call); a popover and TooltipBox → a bubble
the SDKs draw (q2, the user's call); the plan's "SnackBar ... duration" → Flutter's static widget (A8.5 corrected).
Branch feat/native-parity-s8 on main 4a7f389b. Planned by pipeline:build-task-planner on c2a9ebcb; D2 and D2-chk merged
by the main session (D2-chk depended on D2 inside one group, and apart they leave G3 red), the dialog tasks given the
user's platform behaviour (D5).

### Groups (paths from the repo root)
| # | G | Task | Title | Files | Cases | Size | Depends |
|---|---|---|---|---|---|---|---|
| 1 | 1 | F1 | Fixtures 47, 52; heightFactor in schema | schema/action.schema.json · schema/fixtures/render/47_overlay_widgets.json (new) · schema/fixtures/actions/52_open_close_dialog.json (new) · engine/test/action-schema-sync.test.ts | A8.1-A8.5 fx (47: engine, Flutter); A8.1 fx (52: Flutter runner; heightFactor pinned) | M | — |
| 2 | 1 | F-pins | Native fixture pins and runs | sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift · sdk-swift/Tests/OrcaGatewayCoreTests/ActionFixtureTests.swift · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/models/ModelRoundTripTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/FixturePathsTest.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/ActionFixtureTest.kt | A8.1-A8.5 fx sw/kt (47 round-trips, render 56 → 57); A8.1 fx sw/kt (52 runs, actions 32 → 33) | M | — |
| 3 | 1 | S-act | Swift executor knows both dialog kinds | sdk-swift/Sources/OrcaGatewayCore/State/ActionExecutor.swift · sdk-swift/Tests/OrcaGatewayCoreTests/ActionHandlerTests.swift · sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift | A8.1 core sw (no-op, no effect without a page handler); kinds caps sw (26 → 28) | M | — |
| 4 | 1 | K-act | Kotlin executor knows both dialog kinds | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/ActionExecutor.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/ActionHandlerTest.kt · sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt | A8.1 core kt; kinds caps kt (28) | M | — |
| 5 | 2 | S-core | Swift DialogStack and SnackbarQueue cores | sdk-swift/Sources/OrcaGatewayCore/State/DialogStack.swift (new) · …/State/SnackbarQueue.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/DialogStackTests.swift (new) · …/SnackbarQueueTests.swift (new) | A8.1 core sw (open, close, dismiss, stack); A8.4 core sw (FIFO, phases, swipe) | M | — |
| 6 | 2 | K-core | Kotlin DialogStack and SnackbarQueue cores | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/state/DialogStack.kt (new) · …/state/SnackbarQueue.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/state/DialogStackTest.kt (new) · …/SnackbarQueueTest.kt (new) | A8.1, A8.4 core kt (same cases) | M | — |
| 7 | 2 | S-static | Swift BottomSheet, slot, SnackBar, inert Dialog | sdk-swift/Sources/OrcaGateway/Widgets/Overlays.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayTests/BottomSheetTests.swift (new) · …/SnackBarWidgetTests.swift (new) | A8.2 sw ui; A8.5 sw ui; A8.1 sw ui (Dialog draws nothing in place) | M | — |
| 8 | 2 | K-static | Kotlin BottomSheet, slot, SnackBar, inert Dialog | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Overlays.kt (new) · …/widgets/Structure.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/BottomSheetTest.kt (new) · …/SnackBarWidgetTest.kt (new) | A8.2, A8.5, A8.1 (inert Dialog) kt ui | M | — |
| 9 | 3 | S-queue | Swift one snackbar queue at router | sdk-swift/Sources/OrcaGateway/Navigation/OrcaRouter.swift · sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift · sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Tests/OrcaGatewayTests/PageModelTests.swift · …/SnackbarQueueHostTests.swift (new) | A8.4 sw unit (two in a row, survives a navigate, toast in turn) | M | S-core |
| 10 | 3 | K-queue | Kotlin one snackbar queue at router | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/navigation/OrcaRouter.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPageModel.kt · …/sdk/OrcaPageView.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/PageModelTest.kt · …/sdk/CounterPageTest.kt | A8.4 kt unit (same; no Scaffold: queued, not drawn) | M | K-core |
| 11 | 3 | D2 | Tooltip and SnackBar target iOS, checks follow (5 files + 2 regenerated) | engine/src/components/layout/tooltip.ts · engine/src/components/structure/snack-bar.ts · engine/test/widget-targets.test.ts · engine/test/target-check.test.ts · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · regenerated: engine/src/core/widget-registry-gen.ts, schema/widget-registry.json | A8.3, A8.5 eng (all four targets, IOS_ORPHANS [], off-target examples from Video); sw (orphan check flipped) | M | — |
| 12 | 4 | S-bar | Swift M3 fixed bar in Scaffold | sdk-swift/Sources/OrcaGateway/Widgets/SnackbarBar.swift (new) · sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · sdk-swift/Sources/OrcaGateway/Navigation/TabShellView.swift · sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Tests/OrcaGatewayTests/SnackbarBarTests.swift (new) | A8.4 sw ui (look, above the bars, over the slot, pushed page, swipe, tabs) | M | S-queue |
| 13 | 4 | K-bar | Kotlin M3 fixed bar in Scaffold | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/SnackbarBar.kt (new) · …/widgets/Structure.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/navigation/TabShellScreen.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPageView.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/SnackbarBarTest.kt (new) | A8.4 kt ui (same) | M | K-queue |
| 14 | 5 | S-dialog | Swift sheet layer over stacks (q1), Back/VoiceOver/keyboard | sdk-swift/Sources/OrcaGateway/Widgets/DialogLayer.swift (new) · sdk-swift/Sources/OrcaGateway/OrcaPageModel.swift · sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Sources/OrcaGateway/Navigation/TabShellView.swift · sdk-swift/Tests/OrcaGatewayTests/DialogTests.swift (new) | A8.1 sw ui (sheet, closes, waits, never a page; focus, modal, escape, keyboard) | M | S-core |
| 15 | 5 | K-dialog | Kotlin sheet layer in page (q1), Back/TalkBack/keyboard | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/DialogLayer.kt (new) · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaPageModel.kt · …/sdk/OrcaPageView.kt · …/sdk/OrcaApp.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/DialogTest.kt (new) | A8.1 kt ui (same, Back, TalkBack, keyboard) | M | K-core |
| 16 | 5 | S-tipcore | Swift TooltipPlacement core (q2) | sdk-swift/Sources/OrcaGatewayCore/Render/TooltipPlacement.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/TooltipPlacementTests.swift (new) | A8.3 core sw (placement, timings) | S | — |
| 17 | 5 | K-tipcore | Kotlin TooltipPlacement core (q2) | sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/render/TooltipPlacement.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/render/TooltipPlacementTest.kt (new) | A8.3 core kt (same) | S | — |
| 18 | 6 | S-tip | Swift Tooltip bubble, buttons too (q2) | sdk-swift/Sources/OrcaGateway/Widgets/Tooltip.swift (new) · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Sources/OrcaGateway/Widgets/Buttons.swift · sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Tests/OrcaGatewayTests/TooltipTests.swift (new) | A8.3 sw ui | M | S-tipcore |
| 19 | 6 | K-tip | Kotlin Tooltip bubble, buttons too (q2) | sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Tooltip.kt (new) · …/widgets/Buttons.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/TooltipTest.kt (new) · …/widgets/IconButtonFabTest.kt | A8.3 kt ui | M | K-tipcore |
| 20 | 7 | S-caps | Swift advertises the four | sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · sdk-swift/Tests/OrcaGatewayTests/StructureWidgetTests.swift · sdk-swift/README.md | A8.x caps sw (93; the switch draws each) | M | all S tasks, D2 |
| 21 | 7 | K-caps | Kotlin registers and advertises the four | sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt · sdk-kotlin/README.md | A8.x caps kt (93; standard() == vector) | M | all K tasks |
| 22 | 7 | D-overlays | Demo page overlays on parity-a | examples/server/parity-a.ts · examples/server/index.ts · engine/test/parity-a-overlays.test.ts (new) | A8.x eng (page whole on both vectors, both dialog kinds kept); A8.1-A8.5 hand | M | — (its test commits after S-caps and K-caps) |

### Where each case is placed
- A8.1: F1 (fixtures 47, 52; heightFactor in the schema); F-pins (52 runs on both natives); S-act, K-act (both kinds
  known; a no-op with no effect when no page handler is registered); S-core, K-core (DialogStack); S-static, K-static
  (the Dialog draws nothing in place); S-dialog, K-dialog (the sheet, q1, and the platform behaviour of D5); hand.
- A8.2: F1 (a BottomSheet in a Scaffold slot); S-static, K-static (the widget and the slot, the FAB lifted); S-bar,
  K-bar (a snackbar paints over the slot); hand.
- A8.3: F1; D2 (targets); S-tipcore, K-tipcore; S-tip, K-tip (the bubble, IconButton and FAB `tooltip`, q2); hand.
- A8.4: S-core, K-core (SnackbarQueue); S-queue, K-queue (one queue at the router, a toast waits its turn, survives
  a navigate, no Scaffold: queued, not drawn); S-bar, K-bar (the M3 fixed bar and where it is drawn); hand.
- A8.5: F1; D2; S-static, K-static (content, label, onAction; duration unread); hand.
- Beside the rows: kinds caps in S-act, K-act; widget caps in S-caps, K-caps; A8.x eng in D2 and D-overlays. Test
  names `testA8_N…` (Swift) and `a8_N_…` (Kotlin); the cores' shared cases carry the same names on both SDKs.

### Order, and why each boundary; expected reds
G1
- F1: OpenDialogAction (action.schema.json:170-184) gains the optional `heightFactor` number; action-schema-sync.test
  .ts (:50-57) pins it, red first. 47 in the shape of 46_rich_text_spans.json per D1: a `.withKey()` Dialog, no title
  (flatten embeds it raw), one prop bound to page state; `expected` from encodeJsonTree, cross-checked with flatten.
  52 in the shape of 48_refetchPage.json: [OpenDialog("d", 0.4), CloseDialog], state unchanged, effects []; Flutter
  passes as is (AE:864-871 no onOpenDialog, :896-918 no context). A corrupted copy fails both runners.
- F-pins: Swift ModelRoundTripTests.swift:10 → 57 and :39 → 33, ActionFixtureTests.swift:28-30 → 33; the closeDialog
  "unimplemented" examples (:134, :137, :153-156) switch to a `custom:` kind (holds before and after S-act); adds
  testA8_1_…_fixture52. Kotlin the same: ModelRoundTripTest.kt:32, :79, FixturePathsTest.kt:13-14,
  ActionFixtureTest.kt:149, :245-264; adds a8_1_…_fixture52.
- S-act: openDialog and closeDialog join ActionExecutor.kinds (:43-49); with no handler nothing runs and no effect is
  emitted (as refetchPage); capabilities.json sorted, one generator run; CapabilitiesTests.swift:169 → 28 (:178 holds),
  ActionHandlerTests.swift:122-131. K-act the same at ActionExecutor.kt:529, ActionHandlerTest.kt:173-182,
  CapabilitiesTest.kt:241, :251-252.
- The kinds go out in G1, not G7 (s5's refetchPage way): CapabilitiesTests.swift:178 and CapabilitiesTest.kt:255 tie
  each executor's kinds to its capabilities.json, and the native runners require every kind of a fixture to be
  implemented (ActionFixtureTests.swift:278, ActionFixtureTest.kt:70). The kinds are the same under q1 a or b.
- One gen-native-capabilities run writes both Generated files: each act task stages only its own; the main session
  reruns the generator at the group's end and expects no diff.
- Reds between commits: 52's native runs until the act tasks land; CapabilitiesTest.kt:252 between S-act and K-act.
  At the gate: none.
G1 → G2 (G2 needs nothing from G1; a group holds at most four tasks)
- S-core, K-core, red first on stubs. DialogStack (D4): open resolves the Dialog's children depth-first in order
  (component_renderer.dart:44-54), unknown id or no children opens nothing; h ?? 0.5, NaN or negative → 0.5; close pops
  the top, none open does nothing; a dismiss pops the top; stacked sheets close one per call. SnackbarQueue: FIFO,
  durations ?? 4000 / 2000; phases entering 250 → showing (counted once fully in) → leaving 250; a swipe removes
  the bar at once (D4 as corrected at S-core / K-core); nothing dropped or replaced; time passed in.
- S-static: Overlays.swift: BottomSheet = SB:235-249; SnackBar = SB:429-465 (Expanded content, D9); Dialog = a
  zero-size view of its own (not EmptyView: StructureWidgetTests.swift:273-285). ScaffoldView (Structure.swift:22,
  :36-89) draws the slot per D6 (over the body, which keeps its frame, above the bottom bar and footer; #F7F2FA, top
  radius 28, ≤ 640, the FAB lifted). NodeView gets the three. ImageRenderer frames and pixels; a hosted label tap fires
  onAction; the Dialog's frame is zero.
- K-static: the same in Overlays.kt; ScaffoldFrame (Structure.kt:230-270) lays the slot over the body. Robolectric
  bounds, pixels, the click. Reds: none.
G2 → G3 (the queue tasks drive SnackbarQueue; D2 here because the engine lane is free and only S-caps needs it)
- S-queue: one queue in OrcaRouter.swift, kept across navigate, back and tab switch, an injectable clock; perform
  (OrcaPageModel.swift:385-392) hands showSnackbar and showToast to it; a page with no router keeps its own; `toast`
  stays the read-only head; ToastView (OrcaApp.swift:45-72) draws the head; the snackbar at the bottom until S-bar.
  Tests: two in a row; a toast between two snackbars waits; a bar across a push keeps its time; a refused server
  action's message (ActionExecutor.swift:423). PageModelTests.swift:33-40, :71 updated.
- K-queue: the same in OrcaRouter.kt, OrcaPageModel.kt (:42-56, :306-312); OrcaPageView.kt (:44-83) feeds the head to
  the root Scaffold's host and drops the page-bottom host (:79); CounterPageTest.kt:72-85 flips to "not drawn"; a
  toast becomes an Android Toast on its turn; a8_4 cases in PageModelTest.kt on the main clock.
- D2: drop `targets` (tooltip.ts:13-14, snack-bar.ts:15-16), `bun run schema/gen-widget-registry.ts`; IOS_ORPHANS
  [] (widget-targets.test.ts:19) with an A8 test as at :46-50; target-check.test.ts:8-21 takes its iOS off-target
  examples from Video (off "flutter" and "web"); CapabilitiesTests.swift:29-36 flips (both carry ios, neither
  advertised until S-caps). Engine `bun test` and the Swift core suite on the final files. Reds: none at the gate.
G3 → G4 (the bars draw the queue's head)
- S-bar: SnackbarBar.swift per D8 (full width, square, #322F35, #F5EFF7 14 one line, padding 24 / 14, elevation 6,
  the bottom safe area inside, revealed by height, swipe down dismisses); the top page's root ScaffoldView draws it
  above its bottom bar and over the slot, the FAB lifted; with tabs TabShellView draws it above the tab bar; ToastView
  keeps toasts only.
- K-bar: SnackbarBar.kt replaces ScaffoldFrame's SnackbarHost (:263); TabShellScreen.kt draws it above the tab bar;
  LocalOrcaSnackbars (OrcaPageView.kt:29) carries the queue.
- Tests: frames over a BottomNavigationBar and the slot, pixels, a pushed page shows the same bar, the swipe; no
  Scaffold, no bar. Reds: none.
G4 → G5 (q1, plus q2's cores; the dialog layers use DialogStack)
- S-dialog: DialogLayer.swift (D5) over each NavigationStack (RouteStack OrcaApp.swift:664, each tab's stack
  TabShellView.swift:281), under the tab bar, so the navigation bar is covered too: barrier 0x8A000000; the panel at h
  of the available height, no safe area; white, top 24, ≤ 640 centred; in 250 / out 200 ms. Barrier tap and drag down
  pop the top sheet. The model registers openDialog (returns when its sheet closes) and closeDialog (top sheet only),
  after the plugin host. Platform behaviour (D5, the user's call): VoiceOver focus moves into the panel on open
  (UIAccessibility screenChanged to the panel) and back to the element that opened it on close; the panel is modal
  (accessibilityViewIsModal / .isModal), named "Bottom Sheet"; the backdrop one element "Scrim" with an action that
  closes; the VoiceOver escape gesture closes the top sheet; the navigation edge swipe is off while a sheet is open
  (Flutter: a popup route blocks the page's back gesture; check, risk 8); a text field in the panel stays above the
  keyboard (the panel lifts by the keyboard's height). Hosted UIWindow tests: frames at 0.5 and 0.4, the barrier
  pixel, a tap closes; a Sequential's SetState runs only after the close; closeDialog with none open keeps the page;
  stacked sheets close one per call; a state change redraws inside; the panel modal and named, the page hidden; the
  escape closes; the panel above a raised keyboard frame (simulated keyboard notification).
- K-dialog: DialogLayer.kt in OrcaPageView (the page's AppBar inside, the tab bar outside); BackHandler closes the
  top sheet; TalkBack: the page content below is cleared from semantics while open (or marked hidden), the panel a
  pane named "Bottom Sheet" (paneTitle) that takes accessibility focus on open, focus restored on close; the scrim one
  node "Scrim" with an onClick action labelled close; the panel lifts with the IME (imePadding / WindowInsets.ime);
  registration after plugins.install (OrcaApp.kt:199-201). Robolectric: the same cases, Back via the dispatcher,
  semantics tree checks, an IME inset.
- S-tipcore, K-tipcore: x centred, clamped 10 from the edges; y = centre + 24, else above; 500 ms, 1.5 s, fade 150 /
  75. Reds: none.
G5 → G6 (q2; the bubbles are placed by TooltipPlacement)
- S-tip: Tooltip.swift per D7: a 500 ms long press (Buttons.swift:296-308), a heavy haptic, held while pressed, gone
  1.5 s after release or at any other touch; the bubble in a host layer mounted in OrcaApp.swift (no ancestor clips
  it), taking no touches; an empty message draws the child alone; the message is the accessibility label (VoiceOver
  reads the child, then the message as its hint, as Flutter's semantics tooltip; check); TooltipLabel (:359-375)
  becomes the bubble for IconButton (:424) and the FAB (:528); NodeView gets "Tooltip".
- K-tip: a Popup at TooltipPlacement with the same timing (Buttons.kt:458); Buttons.kt (:319-320, :382-383,
  :512-515) wraps IconButton and FAB; IconButtonFabTest.kt:310-320 keeps the label and adds the bubble. Reds: none.
G6 → G7 (the vectors list what both SDKs draw)
- S-caps: the four widgets, one generator run (it takes Tooltip and SnackBar for ios only after D2,
  gen-native-capabilities.ts:109-111); CapabilitiesTests.swift:51-56 and StructureWidgetTests.swift:265-271 → 93; a
  testA8_x check; README.md:4-5 → 93 widgets, 28 kinds.
- K-caps: standard() registers the four (Dialog draws nothing); CapabilitiesTest.kt:90-93, :140 → 93; README.md:5, :91.
- D-overlays: page `overlays` (D10) after richPage (parity-a.ts:1617-1824), route after :1838, the header (:89-96)
  names it, the URL after index.ts:119; a text field inside the dialog for the keyboard check; the test a copy of
  parity-a-rich.test.ts, committed last. Reds: c1 (CapabilitiesTest.kt:94) between the two caps commits; green at
  the gate.

### Seams
- Swift: NodeView.swift S-static (G2) then S-tip (G6); Structure.swift S-static (G2) then S-bar (G4); OrcaApp.swift
  S-queue (G3), S-bar (G4), S-dialog (G5), S-tip (G6); OrcaPageModel.swift S-queue then S-dialog; TabShellView.swift
  S-bar then S-dialog.
- Kotlin: Structure.kt K-static (G2) then K-bar (G4); OrcaPageView.kt K-queue (G3), K-bar (G4), K-dialog (G5);
  OrcaPageModel.kt K-queue then K-dialog.
- One task each: OrcaRouter.swift / .kt, TabShellScreen.kt, OrcaApp.kt, Buttons.swift / .kt.
- Caps files: CapabilitiesTests.swift S-act (G1), D2 (G3), S-caps (G7); capabilities.json and Generated the act tasks
  (G1), then the caps tasks (G7); the main session reruns the generator after each group that touched them.
- Pins: fixture counts F-pins alone; widget counts and READMEs the caps tasks alone. Engine lane: F1 (G1), D2 (G3),
  D-overlays (G7); parity-a.ts and index.ts D-overlays alone. Goldens: none move; a moved golden stops the task.

### Risks (checked against the code on c2a9ebcb; the branch is now on main 4a7f389b, no SDK file changed)
1. Pins: render 57, actions 33, widgets 93, kinds 28; 47 and 52 are free on main (checked).
2. D3 split: the kinds go out in G1 (above); fixture 52 needs them there.
3. Dialog view: the switch-draws check (StructureWidgetTests.swift:273-285) fails on EmptyView: Swift's Dialog needs a
   view of its own.
4. Unregistered until G7: Swift tests widen the registry (CheckboxRadioTests.swift:332); Kotlin builders stay
   test-local (WidgetBuildersTest.kt:15-22).
5. Handler order: Flutter's page handler beats a host's custom openDialog (OP:318-320); the natives register
   refetchPage before the plugin host (OrcaPageModel.swift:168-173, OrcaApp.kt:199-201), so the dialog pair goes after.
6. iOS AppBar: the navigation bar is outside OrcaPageView, so the layer goes over each NavigationStack, under the tab
   bar.
7. A waiting openDialog: a page torn down with sheets open must resume every waiter, or a Sequential hangs.
8. Back on iOS: no system key; the VoiceOver escape closes; check Flutter for the edge swipe under a popup route before
   building.
9. Public API: `toast` and OrcaToast are public (OrcaPageModel.kt:47, :89): they stay a read-only head of the queue;
   a router-less OrcaPageView keeps a queue of its own.
10. Timing tests run on time passed in: the Compose main clock and an injected Swift clock, never sleeps.
11. Long press: a tooltipped IconButton with only onTap shows the bubble on hold and fires nothing (Buttons.swift:361-
    364); check how Flutter resolves a Tooltip over a child with its own onLongPress.
12. Build contention: one SwiftPM or Gradle build per worktree at a time; at most 4 tasks per group.
13. Accessibility checks need the real readers for the last word: the unit tests pin the tree; the hand checks run
    VoiceOver (simulator Accessibility Inspector) and TalkBack on the emulator.

### Hand checks (after G7, page `overlays`, iPhone 16 Pro DA7254F5 and Android API 34, against Flutter)
A8.1 the sheet at 0.5 and 0.3; barrier, drag, Back (Android); closeDialog closes only the sheet; the Sequential wait;
the tab bar uncovered; VoiceOver and TalkBack land in the panel, cannot reach the page, return on close; a text field
in the sheet stays above the keyboard. A8.2 the inline sheet and the slot over the FAB. A8.3 long press, haptic, gone
after 1.5 s, near an edge, the IconButton `tooltip`, what the readers say. A8.4 two in a row, across a push, a toast
between two snackbars. A8.5 the label's taps count.

### Done when
Suites: engine `bun test`; `flutter test`, `flutter analyze`; `swift test` and the iOS scheme on DA7254F5; Kotlin
`./gradlew cleanTest :sdk:cleanTestDebugUnitTest build --no-build-cache`. gen-widget-registry, gen-native-capabilities
and gen-sdk-capabilities leave no diff; no golden moved; examples/app-ios and examples/app-android build. One commit
per task, staged by path; one gate per group; hand checks after G7; a row ticked only when both SDKs match Flutter.
baseline: engine 838 pass · Flutter 545, analyze clean · `swift test` UI 578, core 640 · iOS scheme UI 739, core 640 ·
Kotlin core 658, sdk 814, lint clean (2026-11-16, the s7 head; no SDK file changed since).
commits: per task · gate: per group (answered at gate 08, 2026-11-16, by the standing rule; Q4 the user's own call).

### Not planned (on purpose)
q1 (b) and q2 (b) (`.sheet` / ModalBottomSheet, a popover / TooltipBox): declined by the user. Props Flutter never
reads: Dialog title, dismissible, backgroundColor, borderRadius (OQ10); SnackBar `duration`; showSnackbar's wire
`action`. Known differences: tooltip hover with a mouse or on macOS (D7); showToast's floating bar (D8); a sheet that
lifts above the keyboard (beyond Flutter, the user's call). No Flutter or encoder change beyond D1's schema line and
D2's targets. The cloud's Go registry after D2 (tools/gen-go-registry.ts writes into cloud/) is the user's follow-up;
engine/CHANGELOG.md is written at release.
