# native-parity-s8 · design in force (plan step 8, written at stage 08; 05-07 skipped)

Repo: /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/native-parity-phase-a-35cc97 (paths below from
there), branch feat/native-parity-s8 on main 4a7f389b (step 7 merged as PR #52). Flutter (`sdk/`) is the reference. Facts with every file:line: .pipeline/native-parity-s8/inventory.md
(abbreviations PB, LB, SB, BH, BB, AE, OP, FW, MUI, SW, SWC, KT, KTC as there). Swift deploys to iOS 16 / macOS 13;
Kotlin minSdk 24, Compose BOM 2026.05.01 (material3 1.4.0).

## Cases (phase-a-tests.md rows, after corrections)
- A8.1 [corrected] openDialog shows the keyed Dialog node's children as a modal bottom sheet: a white panel, top
  corners 24, full width (at most 640, centred), heightFactor ?? 0.5 of the available height, over a 0x8A000000
  barrier, in 250 / out 200 ms; a barrier tap, a drag down or Back close it whatever `dismissible` says; closeDialog
  closes the top sheet only, never a page (none open: nothing); the Dialog draws nothing in place; an action after
  openDialog in a Sequential waits until the sheet closes. fixture + ui  [the row said "as a modal; outside tap
  follows barrierDismissible": OP:323-374 shows a bottom sheet and never reads dismissible, title, backgroundColor or
  borderRadius; AE:894-919]
- A8.2 BottomSheet draws, and the Scaffold bottomSheet slot shows it. ui  [note: the widget is a Container, padding
  16, backgroundColor ?? white, top corners borderRadius ?? 16, inline (SB:235-249); the slot is MUI's persistent
  sheet: over the body's bottom without shrinking it, above the bottom bar, on #F7F2FA with top radius 28, at most
  640 wide, no entrance or drag, the FAB lifted above it (inventory §3)]
- A8.3 Tooltip shows its message on long press. hand + ui  [note: 500 ms, a haptic, stays while held, gone 1.5 s
  after release, any other touch hides it; grey[700] at 0.9, radius 4, white 14, padding 16 x 4, min height 32;
  centred on the child, 24 below its centre, above when it does not fit, 10 from the edges (LB:583-586, MUI
  tooltip.dart, FW raw_tooltip.dart); IconButton and FAB `tooltip` wrap the button in one (BB:158-159)]
- A8.4 Two showSnackbar actions in a row show one after the other, and a snackbar survives a navigate. unit + hand
  [note: one queue for the app (the root ScaffoldMessenger), shared with showToast; each bar's duration (?? 4000) runs
  once it is fully in; drawn in the top page's root Scaffold (with tabs, the shell's, above the tab bar); a pushed
  page shows the same bar, its time still running (AE:393-423, MUI scaffold.dart, snack_bar.dart)]
- A8.5 [corrected] The SnackBar widget draws its content and its actionLabel; the label fires onAction; `duration`
  changes nothing. ui  [the row said "honours its action label and duration": SB:429-465 is a static Container
  (#323232 ?? backgroundColor, radius 4, padding 16 x 12, content white 14, label #BB86FC 14 w600), no timer]

## Decisions
- D1 Contract. No new kind and no new prop. schema/action.schema.json OpenDialogAction gains the optional
  `heightFactor` number the TS type (engine/src/types/action.ts:57-61), Flutter and both native models already carry
  (a drift fix). Render fixture `schema/fixtures/render/47_overlay_widgets.json`: a keyed Dialog with a child and its
  three props, a Scaffold with a BottomSheet in its slot, a Tooltip, a SnackBar with actionLabel, duration and
  onAction, buttons with OpenDialog(id, 0.4) and CloseDialog. Action fixture
  `schema/fixtures/actions/52_open_close_dialog.json`: both kinds change no state and emit no effect, as Flutter's
  executor. Count pins move on both SDKs (render 56 → 57, actions 32 → 33).
- D2 Targets (the user's call, 2026-11-15, logged): Tooltip and SnackBar drop their `targets` (all four platforms);
  the registry is regenerated; engine/test/widget-targets.test.ts IOS_ORPHANS becomes []; target-check.test.ts takes
  its iOS off-target examples from a widget that is still off iOS; Swift's orphan check is flipped. The cloud's Go
  registry is the user's follow-up.
- D3 Capabilities, in the last group: both capabilities.json gain Dialog, BottomSheet, Tooltip, SnackBar (89 → 93) and
  openDialog, closeDialog (26 → 28), one generator run; the tests that use closeDialog as the unimplemented kind
  switch to a `custom:` kind. Kotlin registers the four in standard(). Engine test `engine/test/parity-a-overlays
  .test.ts` (as parity-a-rich.test.ts): each native vector gets page `overlays` whole, both dialog kinds kept.
- D4 Pure cores (both SDKs, the same cases by name):
  `DialogStack`: open(dialogId, heightFactor, nodeMap) → the Dialog's children subtree depth-first in order (unknown
  id or no children: nothing opens), heightFactor ?? 0.5 (NaN or negative → 0.5), pushed on a stack; close() pops the
  top, none open is a no-op; a dismiss (barrier, drag, Back) pops the top.
  `SnackbarQueue`: a FIFO of {kind snackbar | toast, message, duration ?? 4000 | 2000} driven by the time passed in:
  idle → entering (250 ms) → showing (its duration, counted once fully in) → leaving (250 ms) → the next; a swipe
  removes the bar at once and the next enters (the UI slides it off with the drag first: Flutter's Dismissible, then
  removeCurrentSnackBar with no leave animation, snack_bar.dart:859-871, :865; corrected at S-core / K-core); nothing
  is dropped or replaced.
  `TooltipPlacement`: given the child's rect, the bubble's size and the overlay's size: x centred on the child,
  clamped 10 from the overlay's edges; y = child centre + 24 below, above (centre − 24 − height) when below does not
  fit; the timing constants (500 ms press, 1.5 s after release, fade 150 / 75 ms).
- D5 Dialog layer (A8.1; q1 a, the user's call). Both SDKs draw the sheet themselves in the page host, over the page and
  under a tab bar (Flutter's branch Navigator): the barrier, the panel of D4's height from the bottom edge (no safe
  area, as useSafeArea false), white, top corners 24, clipped, at most 640 wide and centred, the slide 250 / 200 ms;
  barrier tap, drag down and Back pop it. Its content is the Dialog's subtree drawn with the page's stores and
  executor. openDialog and closeDialog are page-registered handlers (as refetchPage); openDialog returns when its sheet
  closes. The Dialog node draws nothing in place. Platform behaviour, covered explicitly (the user's call,
  2026-11-16): Android Back closes the top sheet (as Flutter's route pop); VoiceOver and TalkBack focus moves into the
  panel when it opens and back to where it was when it closes; while open the page below is out of reach of
  accessibility and the backdrop is one element labelled "Scrim" whose action closes the sheet, the panel a modal
  container named as Flutter names the route: "Dialog" on Android, no name on iOS (MUI bottom_sheet.dart:726-732,
  :801-805; material_localizations.dart:1122; corrected at S-dialog / K-dialog: "Bottom Sheet" is only the scrim's
  Android tap hint, :1357); the sheet panel is as wide as its content up to 640 (:417-421); a text field
  in the panel stays above the keyboard (the panel lifts by the keyboard's height: beyond Flutter, whose modal sheet
  lets the keyboard cover it; a known difference in the PR).
- D6 BottomSheet and the Scaffold slot (A8.2). The widget is Flutter's Container. The slot draws the node at the
  bottom over the body (the body keeps its size), above the bottom bar and persistent footer, on M3's sheet surface
  (#F7F2FA, top radius 28, ≤ 640 wide, centred, elevation 1, no shadow); the FAB rises above it; a snackbar paints
  over it; no entrance and no drag.
- D7 Tooltip (A8.3; q2 a, the user's call). Both SDKs draw the bubble themselves in an overlay above the page: D4's
  placement, the look of A8.3's note (Flutter's light theme, the Scaffold's ThemeData()), a long press of 500 ms with
  a haptic, held while pressed, hidden 1.5 s after release or at any other touch; an empty message draws the child
  alone; the message is the accessibility label; the bubble takes no touches. IconButton's and the FAB's `tooltip`
  show the same bubble. Hover (mouse, macOS) is not built: a known difference. (b) would use a popover (iOS 16.4 for
  a compact one) and TooltipBox.
- D8 Snackbar queue (A8.4). One D4 queue at the router (app level) for showSnackbar and showToast, kept across
  navigate, back and tab switch. A snackbar is Flutter's M3 fixed bar: full width, square, #322F35, text #F5EFF7 14 on
  one line, padding 24 each side and 14 vertical, elevation 6, the bottom safe area inside it, revealed by height
  (no fade), a swipe down dismisses; drawn in the top page's root Scaffold above its bottom bar (with tabs, above the
  tab bar). A toast keeps today's look on each SDK (the Swift pill, the Android Toast) but waits its turn (a known
  difference: Flutter's is a floating bar). With no Scaffold on screen the bar is queued and timed but not drawn, as
  Flutter release. A refused server action's message goes through the same queue.
- D9 SnackBar widget (A8.5). Flutter's static Container; `duration` unread; it needs a bounded width (Expanded).
- D10 Demo. Page `overlays` on parity-a (after `rich`), one section per row: a keyed Dialog whose child holds a Text
  bound to page state, a button that changes it and a closeDialog button; buttons opening it at 0.5 and at 0.3, and a
  Sequential openDialog → SetState that shows the wait; a BottomSheet inline and one in the page Scaffold's slot over
  a FAB; a Tooltip on a Text and an IconButton with `tooltip`; a button firing two showSnackbar in a row, one firing
  showSnackbar then navigating to a pushed page, one firing showToast between two snackbars; a SnackBar widget whose
  action label counts taps. The header gains "overlays".
- D11 Tests per row: Swift ImageRenderer for static looks, hosted UIWindow where presentation, touch or time matters;
  Kotlin Robolectric compose tests (semantics, bounds, captured pixels, the main clock). Names `testA8_N…` / `a8_N_…`;
  the cores' shared cases `a8_N_…` on both. No golden moves unless a task row lists it.
- D12 Row corrections (written by the main session): A8.1 and A8.5 as above; notes on A8.2-A8.4.

## Open (from the inventory, decided by the standing rule unless marked)
q1 Dialog layer drawn by the SDKs, not `.sheet` / ModalBottomSheet [major] → a, the user's call 2026-11-16 ("go with
your recommendation"), with the platform behaviour of D5 covered. q2 Tooltip bubble drawn by the SDKs, not a popover /
TooltipBox [major] → a, the user's call 2026-11-16.
OQ1 rows A8.1, A8.5 → corrected to Flutter (the standing rule: rows follow Flutter, never weakened). OQ4 dialog kinds →
no effect, page handlers; heightFactor into the schema. OQ5 queue → one at the router with toast. OQ6 bar → M3 fixed;
no Scaffold → not drawn. OQ8 IconButton / FAB tooltip → the bubble. OQ9 slot → as Flutter. OQ10 Dialog.title → unread,
as Flutter. OQ11 fixtures → 47 and 52.
