# 09 · Implementation · native-sdk-s9

## Front page

### In one breath
group 1 of 4 · tasks: 7 green, 0 blocked · cases: 21 of 38 green · build: core 112, sdk 98
S9.1 FallbackPrompt links: P3, P4 tests (no router; under the router); no production change.
S9.2 Degrade: 4 Kotlin recordings (same bytes as Swift's); graceful, warn, require, 426 tested.
S9.3 Style readers: Flutter alignment, radii, clip; BoxDecoration with shadows and gradient.
S9.4 Expanded and Spacer: flex children share the space left (rework: its red run recorded).
S9.5 TextField: local text, stateKey, then onChange per keystroke; Material 3 decoration.
S9.6 GestureDetector: tap, double tap, long press; only the gestures that have actions.
S9.7 Image loader: OkHttp, memory cache, one request per URL; failures give no image.

### New for you
nothing new

### Trade-offs
1 needs you: GestureDetector has no TalkBack actions; Flutter and Swift expose tap and long press.
1 auto-decided: oversized uneven corners shrink together, as Flutter paints (Swift caps each).
16 auto-decided: implementation choices with the same output (decisions log, stage 09).

### Questions for you
1. Next: group 2 (warn/require goldens, Container and ClipRRect, Stack, Image, Icon)? (default: go)
2. TalkBack: add tap and long-press actions as task S9.6b in group 2 (Gesture.kt and its test,
   case K7)? (default: yes)

## Appendix

### Group 1
Commits on feat/native-sdk-s9, one per task: S9.1 8191054, S9.2 1a9e02d, S9.3 8cd55e5, S9.4
25627e6, S9.5 fb99596, S9.6 eaafeab, S9.7 6b36213. Nothing pushed.

#### Task S9.1 · FallbackPrompt link without and under a router
Files: `sdk/src/test/kotlin/com/orcagateway/sdk/FallbackPromptTest.kt`
Cases: P3, P4 → green; they passed at first run (the behaviour exists since S7), so the
expected URLs were broken for one run to see both fail, then restored · baseline unchanged.
Changed: `withoutARouterTheLinkOpensDirectly` (a recording UriHandler through LocalUriHandler)
and `underTheRouterTheSystemOpensIt` (OrcaRouter with a recording SystemActions; the URI handler
is not called); a class KDoc. No production file changed.
Decisions: router.attach(model) with OrcaPageView, as Swift (not a full OrcaApp); a recording
UriHandler, not Robolectric's started activity.
Review fit: pass
Review quality: pass

#### Task S9.2 · Degrade policies and 426 on recordings
Files: `core/src/test/kotlin/com/orcagateway/core/render/DegradeTest.kt` (new),
`sdk/src/test/resources/pages/degrade-{graceful,warn,require,426}.json` (new)
Cases: D1-D6 → green · red first: D1-D4, D6 FileNotFoundException before the recordings; D5
passed at once (no recording; OrcaClient already handles it) · baseline unchanged.
Changed: six JUnit tests on `record-page.ts capability-demo degrade … --sdk kotlin` recordings
(byte-identical to Swift's), read through `Fixtures.text`, drawn with PageRenderer; D4-D6
through `StubEngine.forced` and `OrcaClient.fetchPage`.
Decisions: case-id prefixes in test names, as OrcaClientTest; the default WidgetRegistry (no
Checkbox), as Swift.
Review fit: pass
Review quality: pass

#### Task S9.3 · Flutter alignment, radii, clip and BoxDecoration
Files: `sdk/…/style/Props.kt`, `style/Decoration.kt` (new), `PropsTest.kt`, `DecorationTest.kt` (new)
Cases: W5-W9 → green · red first: 6 tests against stubs · baseline unchanged (14 PropsTest kept).
Changed: Props gains `alignment` (Flutter's nine names, absolute), `unitPoint`, `radii`, `clips`,
`CornerRadii`; Decoration.kt has `CornersShape`, `BoxDecorationProps.of(json)` (border,
shadows, gradient brush) and `Modifier.boxDecoration` (shadows, fill, inner border).
Decisions: oversized radii shrink by one factor, as Flutter paints (Swift caps each corner);
shadows through Compose `dropShadow`, extreme negative spread clamped; bad input drawn clear.
Review fit: pass
Review quality: pass

#### Task S9.4 · Expanded and Spacer join FlexMeasurePolicy
Files: `sdk/…/widgets/Flex.kt`, `sdk/…/widgets/FlexLayoutTest.kt`
Cases: W1-W3 → green (FlexLayoutTest 13/13) · red first (share turned off): W1 [50, 0, 0] for
[50, 50, 100] dp, W2 60 for 260 dp, W3 35 for 300 dp · baseline unchanged, counter golden green.
Changed: `ExpandedWidget`, `SpacerWidget`, `flexOf`, `Modifier.flex` (parent data); the policy
gives each flex child its share of what is left after the others and the gaps.
Decisions: shares rounded by running total; an unbounded main axis measures flex children as
ordinary ones, as Swift; Expanded always boxes its child.
Review fit: the first digest had no red-first record, fixed (a fresh implementer ran the cases
against the share turned off; the code is byte-identical to the reviewed diff)
Review quality: pass

#### Task S9.5 · TextField: local text, setState, onChange
Files: `sdk/…/widgets/Input.kt` (new), `sdk/…/widgets/TextFieldTest.kt` (new)
Cases: W12-W14 → green · red first: the empty stub drew no text field · baseline unchanged.
Changed: `TextFieldWidget` keeps its text, takes a new page value when it changes elsewhere,
writes `stateKey` with `store.dispatch`, then fires onChange {value}; keyboard, IME action,
obscure, maxLength, maxLines, enabled, readOnly, style and the InputDecoration fields.
Decisions: the page value is the store at stateKey first; no decoration draws a plain field as
Flutter's EditableText, a decoration the Material 3 box; DevTools sees a state change, no action.
Review fit: pass
Review quality: pass

#### Task S9.6 · GestureDetector, only the gestures with actions
Files: `sdk/…/widgets/Gesture.kt` (new), `sdk/…/widgets/GestureDetectorTest.kt` (new)
Cases: K6 (5 tests) → green · red first: 5 of 5 against a child-only stub · baseline unchanged.
Changed: `GestureDetectorWidget`: `detectTapGestures` with only the callbacks that have actions;
none means no pointer input. Tested: a lone tap fires at once, a double tap is not two taps, a
long press, a parent still gets taps, the box's empty corner takes touches.
Decisions: no wrapper without actions (Flutter renderChild); the detector restarts only when the
gesture set changes; needs you: no TalkBack actions (question 2).
Review fit: pass
Review quality: pass

#### Task S9.7 · Image loader on the SDK's OkHttp
Files: `sdk/…/client/ImageLoader.kt` (new), `sdk/…/client/ImageLoaderTest.kt` (new)
Cases: I1 (8 tests) → green · red first: 8 of 8 against a null stub · baseline unchanged.
Changed: `ImageLoader(client, maxBytes = heap/8)`, `load(url): ImageBitmap?` (http and https
only), a byte-sized LruCache, one shared request per URL, `ImageLoader.shared`; a non-2xx, an IO
error or an undecodable body gives null and is not cached; a cancelled caller rethrows.
Decisions: one ImageBitmap instance per URL; the shared request finishes even if all callers
cancel; cache 1/8 of the heap. Not done: no downsampling (not asked).
Review fit: pass
Review quality: pass

### Test run
`cd sdk-kotlin && ./gradlew build --console=plain --rerun-tasks` (after all seven returned):
BUILD SUCCESSFUL; core 112 tests (106 + 6), sdk 98 tests (71 + 27), 0 failures; lint "No issues
found". Every changed file sits in its task's `Files`; no stray file.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing yet. The degrade recordings are committed; their `sdk-kotlin:record` lines join
Taskfile.yml in S9.14. Nothing is registered or advertised until S9.13, so a page cannot use the
new widgets before group 3.
