# native-parity-s6 · design in force (plan step 6, written at stage 08; 05-07 skipped)

Repo: /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/native-parity-phase-a-35cc97 (paths below from
there), branch feat/native-parity-s6 stacked on feat/native-parity-s5 at a289936 (step 5 is PR #45, not merged yet;
rebase when it is). Flutter (`sdk/`) is the reference. Inventory with every file:line: .pipeline/native-parity-s6/
inventory.md. Swift deploys to iOS 16 / macOS 13; Kotlin minSdk 24, Compose BOM 2026.05.01 (material3 1.4.0).

## Cases (phase-a-tests.md rows, after corrections)
- A6.1 Checkbox bound to a stateKey toggles that state and fires onChange with the new value. It is drawn on iOS too.
  fixture + ui  [note: the write is page scope and comes before onChange (IB:208-218); the tick redraws when the node
  watches the key, as Flutter's WatchBuilder (component_renderer.dart:63-79); tristate cycles false → true → null
  (toggleable.dart:247-252)]
- A6.2 Radio buttons sharing a group value select exactly one. fixture + ui  [note: selected iff value and group are
  equal as strings (IB:142-148); tapping the selected one does nothing (:153)]
- A6.3 Switch and Slider (min, max, divisions) write state, and a Text watching the key redraws. fixture + ui
  [note: Slider defaults min 0, max 1, draws value clamped, snaps to divisions, fires on every drag update (IB:296-348)]
- A6.4 TextFormField binds like TextField. Form passes its child through. ui  [note: Form has one child (form.ts:5,
  LB:481-483); TextFormField is TextField's builder (IB:86-137); validator is never read]
- A6.5 IconButton fires onTap. FloatingActionButton in the Scaffold slot sits bottom-end and fires its action.
  ui + hand  [note: IconButton fires only when enabled and given onTap/onLongPress (BB:142-152); FAB endFloat 16
  (scaffold.dart:52-53), onLongPress through its wrapper (BB:219-220)]
- A6.6 InkWell fires onTap, onLongPress and onDoubleTap with press feedback. ui  [note: onDoubleTap is always set, so
  onTap waits out the 300 ms double-tap timeout (LB:628-630, ink_well.dart:1475, gestures/constants.dart:35); long
  press 500 ms]
- A6.7 [rewritten] enabled false makes a control inert and draws it as Flutter does: greyed for Checkbox, Switch,
  Slider and TextFormField, an unselected Radio greyed (a selected one unchanged), IconButton at opacity 0.38, FAB
  unchanged; InkWell has no `enabled`. Without a handler, Checkbox, Switch, Slider, FAB and InkWell still take touches
  and fire nothing; IconButton takes none. ui  [Flutter: IB:171-175,229,240,280,320; BB:123-152,206; LB:628-630;
  floating_action_button.dart:538-542. The old wording ("a control with no handler or disabled is not interactive and
  looks disabled") holds for no widget's no-handler case in Flutter.]

## Decisions
- D1 Contract. No wire change: the nine are in the schema, the engine, the registry and Flutter. Render fixture
  `schema/fixtures/render/45_form_controls.json` holding the nine with every wire prop the engine sends (Checkbox
  value, label, tristate, colours, enabled false; Radio value/groupValue/colours; Switch; Slider value/min/max/divisions/
  trackHeight/label/colours; a Form around a TextFormField; IconButton with padding, alignment, constraints, tooltip;
  FAB mini, colours, elevation, tooltip; InkWell borderRadius and colours, each with onChange/onTap/onLongPress/
  onDoubleTap actions as Values) and a `resolved` block. No action fixture: the stateKey write happens inside the
  widget, and onChange's SetState(V.event('value')) is covered by fixture 19's event values. Count pins move on both
  SDKs (render 53 → 54). `stateKey` is read as Flutter's builders read it (a prop no engine class sends; inventory §8).
- D2 iOS targets (the user's call, 2026-11-15: draw Checkbox, Radio, FloatingActionButton and InkWell on iOS,
  reversing Epic 23b's "degrade on iOS"). Their engine classes gain the `ios` target and lose the "No native iOS
  counterpart (Epic 23b)" doc line (checkbox.ts, radio.ts, floating-action-button.ts, ink-well.ts); Tooltip and SnackBar
  wait for step 8. Regenerate `engine/src/core/widget-registry-gen.ts` and `schema/widget-registry.json` with
  `bun run schema/gen-widget-registry.ts`; the engine pins that list iOS orphans move (widget-targets.test.ts,
  target-check.test.ts). The cloud's generated Go registry carries targets (tools/gen-go-registry.ts:133); it lives
  in the cloud repo, so regenerating it there is a follow-up for the user, not part of this PR.
- D3 Capabilities. Both capabilities.json gain the nine widgets (68 → 77), sorted, one generator run, in the last
  group; no new action kind. Kotlin registers the nine in standard(). The degrade tests that use Checkbox as the
  widget the natives lack (Swift DegradeTests, Kotlin DegradeTest and their degrade-*.json pages) switch to a widget no
  Phase A step adds. Engine test `engine/test/parity-a-forms.test.ts` (copy of parity-a-lists.test.ts): each native
  vector gets page `forms` whole (red until the caps group).
- D4 Binding (both SDKs, as Flutter's builders, inventory §2-3). Read: the merged state (page wins) at `stateKey` when
  set, else the `value` prop, with the builder's default. Write on a user change: SetState(stateKey, new) in page scope,
  then fire onChange with eventData {value: new} (bool for Checkbox/Switch, the radio's value string, a double for
  Slider, the text for TextFormField). No local control state: what is drawn comes from the store or the prop, and a
  node redraws only through its watches (NodeObserver), as Flutter's WatchBuilder. Generalise Swift's
  `model.textChanged` and Kotlin's `edit()` to a JSON value; Swift keeps writing through a SetState action and Kotlin
  through store.dispatch (s9 decision). A Checkbox state that is not a bool: Flutter throws; the natives draw the prop
  value and log once (documented).
- D5 Pure cores (both SDKs, same cases): `FormControls` with checkboxNext(value, tristate) (false → true → null or
  false; null → false), radioSelected(value, group) (string equality; both empty selects, as Flutter's BH:440),
  sliderValue(fraction, min, max, divisions) (clamp, then min + round(t·d)·(max − min)/d when discrete) and
  sliderFraction(value, min, max) (clamped, 0 when max == min). The UI layers only measure, draw and feed gestures.
- D6 Look and feel = Flutter's builders, with the plan's platform controls where Flutter uses Material ones.
  Swift (plan): Switch a SwiftUI `Toggle` (activeColor → the on tint; inactiveColor not settable on iOS, documented);
  Slider a SwiftUI `Slider` (step (max − min)/divisions; no value-indicator label and no trackHeight on iOS,
  documented); Checkbox an iOS-style tick control (SF Symbols square / checkmark.square.fill / minus.square.fill,
  activeColor fill), with a label the whole row taps; Radio an iOS-style dot control (circle / record.circle, activeColor
  ?? #2196F3, inactiveColor ?? #757575, #BDBDBD disabled unselected) at Flutter's 20 pt; FAB Flutter's M3 shape (56 pt,
  corner radius 16; mini 40, radius 12; #EADDFF fill, #4F378B content, shadow for elevation 6), not a circle; InkWell a
  tappable area with the highlight colour while pressed (no ripple on iOS, documented); IconButton Flutter's own box
  (size + 16 square, centred child, 0.38 when disabled, no press feedback, as Flutter).
  Kotlin (Material 3 where Flutter uses Material): Checkbox M3 `Checkbox` (activeColor → checked box colour), with a
  label a ListTile-like row (whole row toggles, leading box, title); Switch M3 `Switch` (activeColor → checked thumb,
  inactiveColor → unchecked track, Flutter's mapping IB:274-281); Slider M3 `Slider` (steps = divisions − 1, the
  value indicator with `label` only when divisions is set, trackHeight honoured); FAB M3 `FloatingActionButton` /
  `SmallFloatingActionButton` with long press; InkWell `combinedClickable` with a ripple in splashColor, clipped to
  borderRadius. Radio and IconButton draw Flutter's own look (Flutter uses no Material Radio or IconButton here,
  IB:139-194, BB:93-163): Radio a 20 dp circle, 2 dp border, 10 dp dot in Flutter's colours, no ripple; IconButton the
  size + 16 box, centred child, 0.38 disabled, no ripple.
- D7 Timing = Flutter's. InkWell: onDoubleTap is always set, so a single tap fires after the 300 ms double-tap timeout;
  long press 500 ms on Android (Compose's default timeout is the platform's, documented if it differs) and on iOS.
  Slider: onChange and the state write on every drag update.
- D8 Demo. Page `forms` on parity-a (after `lists`), one section per row, every control bound by the working engine
  pattern value: V.pageState(k) + onChange SetState(k, V.event('value')) with a Text watching each key: a Checkbox
  and a tristate one, a labelled Checkbox; a Radio group of three on one key; a Switch; a Slider 0-100, divisions 4,
  label; a Form around a TextFormField mirrored by a Text; an IconButton counting taps; the page Scaffold's FAB counting
  taps and long presses; an InkWell with tap, long-press and double-tap counters; for A6.7 a row of disabled controls
  and a row with no handlers. The header drops forms from "later steps".
- D9 Tests per row: Swift hosted UIWindow where touches matter (hit test and the control's own actions, as
  TouchTests and RefreshTests do), ImageRenderer for static looks; Kotlin Robolectric compose tests (performClick,
  performTouchInput, longClick, doubleClick, semantics for toggle state and progress). Each row's check named
  `testA6_N…` / `a6_N_…`. No golden moves unless a task row lists it.
- D10 Row corrections (written by the main session): A6.7 rewritten as above; notes on A6.1, A6.2, A6.3, A6.4, A6.5
  and A6.6 as in the cases above.
