# 09 · Implementation · native-parity-s8

## Front page

### In one breath
group 1 of 7 · tasks: 4 green, 0 blocked · fixtures 47 and 52, both dialog kinds on both SDKs
F1: fixture 47 (four overlays, both actions), 52 (no state, no effect), heightFactor in the schema.
F-pins: both natives run 47 and 52; render pins 57, action pins 33.
S-act / K-act: openDialog and closeDialog known (26 → 28 kinds); no page handler: nothing happens.

### New for you
nothing new

### Trade-offs
none (one review finding, fixed: fixture 52's name hyphenated like its neighbours)

### Questions for you
1. Blocked tasks: none. (default: nothing to retry)
2. Next: group 2, the cores and the static widgets. (default: go)

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

### Test run (group 1, all four tasks' final files)
engine `bun test` 840 pass · Flutter 547 pass, analyze clean · `swift test` UI 578, core 647 · Kotlin
`./gradlew cleanTest :sdk:cleanTestDebugUnitTest build --no-build-cache` core 664, sdk 814, lint clean · the generators
leave no diff (caps hash 1aaf60d6… on both SDKs).

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing yet
