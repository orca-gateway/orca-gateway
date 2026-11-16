# Step 8 inventory (Dialog + openDialog/closeDialog, BottomSheet + Scaffold slot, Tooltip, SnackBar + showSnackbar)
# Checked 2026-11-16 on feat/native-parity-s7 df113db6 (no SDK file changed to the s8 base 0ebffbeb). Both SDKs: 89
# widgets (Swift lacks Dialog, BottomSheet; Kotlin those and Tooltip, SnackBar), 26 action kinds (no open/closeDialog);
# 93 and 28 after (whole manifest; Flutter's 28).
# Render fixtures 56 (01-46, 60-69), next 47_; action fixtures 32 (01-19, 30-35, 45-51), next 52_ (gaps 20-29, 36-44).
PB, LB, SB, BH, FW, MUI, SW, KT as in step 7; BB = sdk/lib/src/builders/button_builders.dart; AE = sdk/lib/src/state/
action_executor.dart; OP = sdk/lib/src/widgets/orca_page.dart; g/ = MUI generated/; SWC = sdk-swift/Sources/
OrcaGatewayCore; KTC = sdk-kotlin/core/src/main/kotlin/com/orcagateway/core. Engine paths are under engine/src.

## 1. Engine classes (private ctor + static new, getProps() = {...rest}, all Valueable, no defaults)
| Dialog structure/dialog.ts:5-33, single | title Widget (in props, no slot), dismissible, backgroundColor, borderRadius |
| BottomSheet structure/bottom-sheet.ts:5-32, single | dismissible, backgroundColor, borderRadius |
| Tooltip layout/tooltip.ts:5-32, single | message (required); targets :13-14 flutter/web/android |
| SnackBar structure/snack-bar.ts:5-34, primitive | content (req.), duration, actionLabel, backgroundColor; onAction :17 |
SnackBar targets :15-16 as Tooltip's. No AlertDialog, SimpleDialog, hideSnackbar or closeBottomSheet anywhere. Scaffold
structure/scaffold.ts:5-75: slot bottomSheet :12, :41, :60; no snackbar slot. widget-registry-gen.ts BottomSheet :41,
Dialog :56, Scaffold :95, SnackBar :105, Tooltip :115; widget-registry.json types :644, :1274, :2994, :3453, :4025, targets
:673, :1310, :3031, :3489, :4040. Barrels structure/index.ts:6,7,16, layout/index.ts:38; actions types/index.ts:42-52.
- Dialog.title: registry kind "widget", but flatten puts the Widget object raw in props (types/widget.ts:121-146, checked
  with bun): `"title":{"kind":…,"type":"Text","props":{…}}`; its state keys join the Dialog's watches. No SDK reads it.
- The iOS degrade (Epic 23b): tooltip.ts:13-14, snack-bar.ts:15-16, both manifest targets, engine/test/widget-targets.test
  .ts:1-11, IOS_ORPHANS :19, :35-43, engine/test/target-check.test.ts:8-21, :45-49 (its ios off-target examples), Swift
  CapabilitiesTests.swift:29-35. Change: drop both `targets`, regen, IOS_ORPHANS → [], off-target examples from Video,
  flip the Swift check; gen-native-capabilities.ts:103-111 then takes them for ios. Cloud Go registry: a follow-up.

## 2. Actions, wire, fixtures
- types/action.ts union :5-34. OpenDialogAction :57-61 {dialogId = a `.withKey()` node id (types/widget.ts:228-235),
  heightFactor?}; CloseDialogAction :63-65 {}; ShowSnackbarAction :96-101 {message, duration?, action?}; ShowToast :103-106.
  Factories OpenDialog :351-355, CloseDialog :357-359, ShowSnackbar :403-405 (never sets `action`), ShowToast :407-409.
- schema/action.schema.json OpenDialogAction :170-184 (dialogId only: heightFactor missing, TS drift), ShowSnackbar :283-303,
  ShowToast :304-318 (no duration; all SDKs read one), CloseDialog :592-604 ("Never pops a page route"). action-fixture.
  schema.json Effect enum :190-215: showSnackbar, showToast; not open/closeDialog.
- Fixtures: actions 07_showSnackbar.json ({message, duration 4000}), 08, 12, 13, 15, 31 (toast 2000) carry snackbar/toast;
  none has open/closeDialog. subpage 05_merge_node_ids.json (:53-57, Dialog :146) and 07_actions_rewrite.json prefix
  dialogId (sub_page_core.dart:231, SWC State/SubPage.swift:216, KTC subpage/SubPage.kt:113); no render fixture holds the
  four. Pins: Swift ModelRoundTripTests.swift:10, :39, ActionFixtureTests.swift:30; Kotlin ModelRoundTripTest.kt:32,
  FixturePathsTest.kt:13-14, ActionFixtureTest.kt:149.
- Filter: an unadvertised widget or kind on a node is a missing feature (core/capability-filter.ts:203-222, :340-351), so
  natives must advertise Dialog (drawn as nothing) and both dialog kinds or the nodes are degraded.

## 3. Flutter (the reference)
openDialog / Dialog: claim 1 HOLDS
- SB:229-233 Dialog draws SizedBox.shrink in place. AE:862-871 only calls onOpenDialog (never set); OP registers its own
  after the host's custom actions (OP:318-320, :323-374), so it beats a custom `openDialog`.
- OP:323-374: nodeMap[dialogId] (absent: nothing :329); the Dialog's children depth-first (none: nothing :344), from
  the first (component_renderer.dart:44-54) with the page's live stores and executor. showModalBottomSheet(page context,
  isScrollControlled, transparent) (:346-349) on defaults: nearest Navigator (with tabs the branch's: tab bar uncovered),
  isDismissible true, enableDrag true, no handle, useSafeArea false (MUI bottom_sheet.dart:1332-1338, :367-368); barrier
  black54 0x8A000000 (:1123, :1364, colors.dart:335), tap closes (:1117); in 250 / out 200 ms (:29-30); full width (M3 max
  640, g/bottom_sheet_defaults_m3.g.dart:18), whole height available (:618-625). Content FractionallySizedBox(heightFactor
  ?? 0.5) > Container(white, top corners 24, antiAlias) (OP:326, :358-369). title, dismissible, backgroundColor and
  borderRadius are never read. The handler awaits the sheet (OP:346): a sequential group's next action waits for it.
- Closed by barrier tap, drag down, back, closeDialog: AE:894-919, next frame, pops one PopupRoute of the page's Navigator,
  never a page; none open: no-op; stacked: one per call (progress_and_dialog_fixes_test.dart:76-140). No effect emitted.
BottomSheet (A8.2)
- SB:235-249 Container(padding 16, backgroundColor ?? white, top corners borderRadius ?? 16, child or empty); no Material,
  elevation or drag; dismissible ignored; inline wherever it stands.
- Scaffold slot SB:45, :76 → MUI Scaffold.bottomSheet, persistent: built at animation value 1 (no entrance, MUI scaffold.
  dart:2511-2563), no drag (:2690), on BottomSheet's Material: #F7F2FA (g/color_scheme_defaults.g.dart:45), elevation 1, no
  shadow or tint, top radius 28, ≤ 640 wide, bottom-centred (bottom_sheet.dart:350-420, g/bottom_sheet_defaults_m3.g.dart:
  12-40); the node's 16-radius Container covers it. At contentBottom over the body's bottom (body not shrunk), above the
  bottom bar and footers (scaffold.dart:1173-1176, :1240-1258); FAB lifted above it; a snackbar paints over it.
Tooltip (A8.3)
- LB:583-586 MUI Tooltip(message, child), nothing else; empty message → the child alone (MUI tooltip.dart:499-501).
- Long press 500 ms (FW gestures/constants.dart:29) on touch (tooltip.dart:420; FW widgets/raw_tooltip.dart:672-700), with
  feedback (iOS click + heavy haptic, Android vibrate: FW widgets/feedback.dart:136-146); stays while held, hides 1.5 s after
  release (raw_tooltip.dart:762-767; tooltip.dart:416); any other pointer down hides it (:706-733). Mouse: at once on hover,
  hides 100 ms after exit (tooltip.dart:417-418). Fade in 150 / out 75 ms fastOutSlowIn (raw_tooltip.dart:27-31).
- Look (light, the Scaffold's ThemeData()): grey[700]@0.9 = 0xE6616161, radius 4, bodyMedium white 14 (14/20, ls 0.25:
  g/typography_defaults_m3.g.dart:142-151) (tooltip.dart:503-534); padding h16 v4, min height 32 on phones (:450-465),
  margin 0, start aligned (:415, :422); dark: white@0.9, black. x centred on the child, 10 px off the overlay's edges; y =
  child centre + 24, above when it does not fit (FW painting/geometry.dart:42-68; tooltip.dart:413-414; raw_tooltip.dart:
  881). The bubble ignores touches; the message is the semantics tooltip. IconButton `tooltip` wraps the button in one
  (BB:158-159); MUI FAB wraps itself (floating_action_button.dart:623).
showSnackbar (A8.4)
- AE:393-406: message resolved, duration int ?? 4000; emits {message, duration}; ScaffoldMessenger.of(ctx).showSnackBar(
  SnackBar(Text(message), duration)): no action button (wire `action` ignored), the showing bar is not hidden. showToast
  AE:408-423: floating, margin 16, 2000 ms, same queue. A refused server action shows its message (AE:721-724; SWC
  ActionExecutor.swift:395; KTC state/ActionExecutor.kt:509).
- One messenger per app, MaterialApp's (MUI app.dart:990; orca_app.dart:611-615 mounts MaterialApp.router). FIFO: the next
  goes in when the previous is dismissed (MUI scaffold.dart:371-392, :438-449); its timer starts once fully in (:661-674; no
  route above the messenger, so it always runs); 250 ms each way (snack_bar.dart:30); no action → times out (:323).
- Drawn in every root Scaffold (scaffold.dart:229-262): the page's, with tabs OrcaShell's above the tab bar (orca_shell.dart:
  114-117). A pushed page's Scaffold registers and shows the current bar (Hero, snack_bar.dart:898): it survives navigate
  and tab switch, time running. No Scaffold: debug assert (scaffold.dart:360-365); release: never seen.
- Look, M3 fixed: full width, square (snack_bar.dart:817-818), #322F35 with bodyMedium #F5EFF7 (g/color_scheme_defaults.g.
  dart:57-58, g/snackbar_defaults_m3.g.dart:18, :41-42), padding 24 each side (snack_bar.dart:707-713), 14 vertical on one
  line (:29, :793), elevation 6, bottom safe area (:812), revealed by height, no fade (:830, :881-889), swipe down dismisses
  (:819, :859-871); at contentBottom above the bottom bars (scaffold.dart:1236-1237, :1340-1352), FAB lifted.
SnackBar widget (A8.5): claim 2 HOLDS
- SB:429-465 a static Container: backgroundColor ?? #323232, radius 4, padding h16 v12; Row[Expanded(Text content white 14),
  if actionLabel non-empty: 8 gap + GestureDetector(label #BB86FC 14 w600) → onAction]. `duration` is never read: no timer,
  no animation, no Material; needs a bounded width (Expanded).

## 4. Native today
Swift
- None of the four in WidgetView (SW NodeView.swift:91-191): plugin builder or EmptyView (:189-191). capabilities.json and
  Generated.swift: the manifest's 91 ios widgets minus Dialog, BottomSheet. ScaffoldView ignores bottomSheet (SW Widgets/
  Structure.swift:22 "not drawn yet", body :36-89).
- SWC Models/Action.swift decodes openDialog {dialogId, heightFactor} :109-115, closeDialog, showSnackbar {message, duration,
  action} :157-164, showToast :166-172. Executor kinds :43-48 (26 + replaceComponent): open/closeDialog return at :162, no
  effect. Snackbar/toast reduce to {message, duration ?? 4000/2000} (ActionReducer.swift:40-50; executor :207-210).
- Per page OrcaPageModel.toast (SW OrcaPageModel.swift:6-14, :97-98, perform :385-392): the next replaces it, gone with
  the page. ToastView (SW OrcaApp.swift:40, :45-72): subheadline, white on white 0.18, 16/12, radius 6 full width (22 toast).
- Router SW Navigation/OrcaRouter.swift:166 (attach :728-752, perform :806-825); no sheet, popover or presentation anywhere.
  App layer RouterRoot ZStack + DrawerHostLayer (SW OrcaApp.swift:633-658, Widgets/DrawerPanel.swift:80, :186). Page
  handlers like refetchPage (SW OrcaPageModel.swift:171). Long press 0.5 s (Widgets/Buttons.swift:296-308); button `tooltip`
  = accessibility label only (TooltipLabel :359-375, :424, :528). iOS 16 floor (Package.swift:20): presentationDetents
  16.0; presentationCornerRadius, presentationBackground, presentationCompactAdaptation 16.4.
Kotlin
- None in standard() (KT WidgetBuilders.kt:170-269, 89 builders); missing draws nothing, logged once (KT NodeView.kt:80-90).
  capabilities.json: the 93 android widgets minus the four. ScaffoldWidget (KT widgets/Structure.kt:108-174, "Bottom sheets
  are not drawn yet" :114); ScaffoldFrame M3 Scaffold, snackbarHost when it is the page root (:230-270, :263).
- KTC models/Action.kt OpenDialog :36, CloseDialog :38, ShowSnackbar :57-62, decode :238-247; executor kinds :529-535,
  open/closeDialog return at :185; snackbar/toast effects (state/ActionReducer.kt:45-63; executor :240-244).
- Per page model.toast (KT OrcaPageModel.kt:42-56, :88-89, perform :306-312); OrcaPageView (KT OrcaPageView.kt:29, :44-83):
  M3 SnackbarHost of the root Scaffold (Indefinite, cancelled after duration :51-67) or at the page bottom (:79); toast =
  Android Toast. A new one cancels the showing one (LaunchedEffect(toast)); dies with the page.
- Router KT navigation/OrcaRouter.kt (attach :516-533, perform :632-644); OrcaNavHost KT OrcaApp.kt:867-880 (TabShellScreen,
  StackScreen :902); page handlers OrcaApp.kt:199-200; PageDrawerHost :1030-1031. Button `tooltip` = semantics label (KT
  widgets/Buttons.kt:319-320, :382-383, :512-515); FlutterGestureTiming 500 ms (:458). compose-bom 2026.05.01 (gradle/
  libs.versions.toml:6): material3 ModalBottomSheet, TooltipBox; minSdk 24.
- Pins that move: widgets 89 → 93 Swift CapabilitiesTests.swift:55-56, StructureWidgetTests.swift:267-268, Kotlin
  CapabilitiesTest.kt:90-93, :140, WidgetBuildersTest.kt:16-19; kinds 26 → 28 Swift CapabilitiesTests.swift:169, Kotlin
  CapabilitiesTest.kt:241, :251-252. closeDialog is the "unimplemented kind" example (Swift ActionFixtureTests.swift:131-157,
  Kotlin ActionFixtureTest.kt:242-266): use a `custom:` kind. Kotlin IconButtonFabTest.kt:311-315 (tooltip = label).

## 5. Demo and model test
- examples/server/parity-a.ts (1846 lines): header :89-96 ("Later steps add overlays: one page constant each, one entry in
  `routes`" :93-94; "Only widgets all three SDKs draw" :96); imports types :1-17, components :18-85 (the four and the three
  actions are in the barrels); richPage :1617-1824 is the last page; routes :1828-1839 (add after `{ path: "rich" }`
  :1838); polish-pushed (:462) is a push target. index.ts: import :11, apps :30, URLs :112-119 (add after :119).
- engine/test/parity-a-rich.test.ts (90 lines): WIDGETS :12-20, PAGE :21, Engine on port 0 :26-37, plainPage :43-47,
  nativePage (POST caps hash + vector) :50-63; tests "holds all" :66-69, "each native vector gets the page whole, no
  FallbackPrompt" :71-89. Overlays: WIDGETS [BottomSheet, Dialog, SnackBar, Tooltip]; whole means open/closeDialog survive.

## A8 rows vs Flutter
- A8.1 corrected (s7 10-uat.md:49-51): "openDialog shows the Dialog's child as a modal bottom sheet (white, top 24, 0.5 of
  the height, black54); barrier tap, drag down or back close it whatever `dismissible` says; closeDialog closes the top
  sheet only, never a page" (OP:323-374, AE:894-919). A8.2-A8.4 hold as §3. A8.5 corrected: "content and actionLabel
  drawn, the label fires onAction; duration changes nothing" (SB:429-465).

## Open questions
1. A8.1 and A8.5 corrections [major: public behaviour; logged in s7]. (a) the rows as corrected above (default); (b) change
   Flutter: a centred dialog honouring `dismissible`, a timed SnackBar widget (the reference and the wire meaning move).
2. iOS dialog [major: approach; the plan names `.sheet` with detents]. (a) an SDK-drawn modal layer at app level (RouterRoot,
   beside DrawerHostLayer): black54, white 24-radius panel at h·height, slide 250/200 ms, drag down and barrier tap close
   (default); (b) `.sheet` + `.presentationDetents([.fraction(h)])`: white and radius 24 need 16.4, system dim and spring.
3. Kotlin dialog [minor]. (a) ModalBottomSheet dressed as Flutter: no handle, scrim 0x8A000000, transparent container,
   content fillMaxHeight(h) white, top 24 (default); (b) M3 defaults (handle, 28, #F7F2FA, 0.32 scrim). Natives cover the
   tab bar, Flutter's branch Navigator does not: a known difference.
4. open/closeDialog in the contract [major: public wire]. (a) no effect, as Flutter: natives run both in page-registered
   handlers like refetchPage, advertise them (26 → 28), await the sheet (OP:346); action fixture 52 pins "no state change,
   no effect" (default); (b) both become effects (Flutter `_emit`, Effect enum +2). Either way heightFactor joins
   OpenDialogAction in action.schema.json [patch].
5. Snackbar queue [minor; the plan's]. (a) one FIFO in the router for showSnackbar and showToast, each its duration after the
   previous leaves, drawn in the top page's root Scaffold above its bars (the shell's under tabs), kept across navigate and
   tab switch (default); (b) per page, replacing (today).
6. Snackbar look [minor]. (a) Flutter's M3 fixed bar of §3 (default); (b) the platform's (Swift pill; Compose's, 12 dp
   margin, 4 dp corners). showToast keeps its look (Android Toast, Swift pill) but joins the queue. No Scaffold on screen:
   (a) as Flutter release, queued and timed but not shown (default); (b) drawn at the page bottom as today.
7. iOS tooltip [major: approach; the plan names a long-press popover]. (a) an SDK-drawn bubble in an overlay with §3's look,
   place, timing and haptic (default); (b) `.popover` + presentationCompactAdaptation(.popover) (16.4): arrow, system look.
8. Kotlin tooltip [minor]. (a) TooltipBox with our own content (§3 colours, radius 4, h16 v4, min 32, 14 sp), 24 below the
   centre, 500 ms long press, gone 1.5 s after release (default); (b) PlainTooltip (12 sp, inverseSurface, 8x4, min 24).
   Both SDKs: IconButton and FAB `tooltip` show the same bubble (BB:158-159) (default) or stay a label only.
9. Scaffold bottomSheet slot [minor]. (a) as Flutter: over the body's bottom (body not shrunk), above the bars, ≤ 640 wide,
   FAB lifted, no animation or drag (default); (b) inset the body above the sheet.
10. Dialog.title [minor]. (a) leave it, an embedded object nobody draws, as Flutter (default); (b) a drawn slot (wire too).
11. Fixtures [patch]. render 47_overlay_widgets.json (keyed Dialog with child and three props, BottomSheet in a Scaffold
    slot, Tooltip, SnackBar with actionLabel, duration, onAction, OpenDialog(id, 0.4), CloseDialog) and action 52 per 4.
