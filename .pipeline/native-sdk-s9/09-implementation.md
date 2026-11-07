# 09 · Implementation · native-sdk-s9

## Front page

### In one breath
group 2 of 4 · tasks: 6 green, 0 blocked · cases: 32 of 39 green · build: core 112, sdk 117
S9.8 Goldens: the warn page (banner over the page) and the require page are pinned.
S9.9 Container and ClipRRect: Flutter's sizing, decoration, padding, clipped corners.
S9.10 Stack and Positioned: Flutter's RenderStack sizing, edges and expand.
S9.11 Image: network image, cover by default, alt for TalkBack, empty box on failure.
S9.12 Icon: Flutter's 156 names as Material icons, unknown ones a filled circle (rework: names).
S9.6b GestureDetector: TalkBack can tap and long-press it (your yes at gate 09).

### New for you
nothing new

### Trade-offs
3 needs you: Image sizing, Stack defaults, right-to-left icons (questions 2-4).
21 auto-decided: implementation choices with the same output (decisions log, stage 09).

### Questions for you
1. Next: group 3, S9.13, registers and advertises the ten widgets? (default: go)
2. An Image with no width or height: size it as Flutter (aspect ratio kept) in S9.11b,
   beside S9.13? Compose's sizing shows the demo's food images wrong. (default: yes)
3. Stack keeps Flutter's builder defaults (centred, no clip; top -8 hangs over)? (default: yes)
4. 9 icons mirror unlike Flutter in right-to-left apps; leave as Swift does? (default: yes)

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

### Group 2
Commits, one per task: S9.8 b8f704c, S9.9 4b52cf2, S9.10 8c12df9, S9.11 58c6caf, S9.12 54aebbf,
S9.6b 088baaf. Nothing pushed. S9.6b was added at gate 09 (question 2, "A").

#### Task S9.8 · Goldens of the warn and require pages
Files: `sdk/…/GoldenTest.kt`, `sdk/src/test/resources/goldens/degrade-{warn,require}.{png,runtime}`
Cases: G1, G2 → green · red first: both skipped by "no golden; record one", the recording run
failed on purpose, the compare run passed · baseline unchanged (counter-home.png byte-identical).
Changed: `g1_theWarnPolicyPageDrawsItsBannerOverThePage`, `g2_theRequirePolicyPageIsOneBlocking
Prompt`; draw and compare moved to internal top-level functions, `assertPageGolden` for S9.14.
Warn: orange banner on top, then the page with its Checkbox as an "Unsupported content" prompt;
require: one red "Update required" prompt. The Scaffold inside the warn Column drew fine.
Decisions: counterPage's body unchanged; default registry; recorded with a --tests filter.
Review fit: pass
Review quality: pass

#### Task S9.9 · Container and ClipRRect on Flutter's decoration
Files: `sdk/…/widgets/Box.kt` (new), `sdk/…/widgets/BoxTest.kt` (new)
Cases: W4 (two tests) → green · red first: "expected 51.0.dp but was 35.0.dp" (no padding yet),
"(30, 30) is #ffffffff, expected red" (nothing clipped) · baseline unchanged.
Changed: `ContainerWidget`: margin, size, decoration or `color`, clip to the decoration's shape,
padding plus the border width; no child or an alignment fills the space, else it wraps the child.
`ClipRRectWidget` clips to one radius or four corners.
Decisions: ClipRRect always clips (the builder never reads clipBehavior); a clipping Container
with no decoration clips to a rectangle, as Swift; the clip sits inside the decoration.
Review fit: pass
Review quality: pass

#### Task S9.10 · Stack and Positioned following RenderStack
Files: `sdk/…/widgets/Stack.kt` (new), `sdk/…/widgets/StackTest.kt` (new)
Cases: K1, K2, K3, K5 → green · red first: all four against compiling stubs · baseline unchanged.
Changed: `StackWidget` (custom layout, size from the largest ordinary child, clip only when
asked), `PositionedWidget`, `StackFit`, `PositionedSpec` (Flutter's edge rules), `Modifier.positioned`.
Decisions: needs you (question 3): no alignment or clip sent → centred, no clip, as Flutter's
builder and Swift (my brief said topLeft and hardEdge, the widget defaults the builder
overrides); edges keep their sign, so top -8 hangs over; an unbounded axis as Swift.
Review fit: pass
Review quality: pass

#### Task S9.11 · Image widget: fit, alignment, alt
Files: `sdk/…/widgets/Image.kt` (new), `sdk/…/widgets/ImageTest.kt` (new)
Cases: I2 (3 tests) → green · red first: "Failed to retrieve bounds of the node" (no alt node),
every fit name FixedScale(1.0) · baseline unchanged.
Changed: `ImageWidget` loads `src` through `ImageLoader.shared`, a new src empties the box until
it loads; seven fit names, cover by default; alignment; `color` tints; `alt` on the box.
Decisions: alt with Role.Image on the box (described while loading too, as Flutter); a failed
load is an empty box; needs you (question 2): with no width or height Compose sizes the bitmap
in device pixels and keeps no aspect ratio from one side, unlike Flutter.
Review fit: pass
Review quality: pass

#### Task S9.12 · Icon on Flutter's names
Files: `sdk/…/widgets/Icon.kt`, `sdk/…/style/IconNames.kt`, `sdk/…/style/IconNamesTest.kt` (new),
`sdk/build.gradle.kts`, `gradle/libs.versions.toml`
Cases: W10, W11 → green · red first: W10 listed every Dart name as missing, W11
NotImplementedError, the widget 0 dp for 24 · baseline unchanged.
Changed: material-icons-extended (BOM 1.7.8, no download; build time unchanged within noise);
a table of Dart's 156 names, unknown → filled circle; `IconWidget` (size 24, colour, `src` wins).
Decisions: needs you (question 4): 17 deprecated icons use their AutoMirrored copies, so 9
names mirror unlike Flutter in right-to-left; `src` fits the box; `copy` is ContentCopy.
Review fit: pass
Review quality: test names lacked the `w10_` underscore, fixed (renamed by a fresh implementer)

#### Task S9.6b · GestureDetector actions for TalkBack
Files: `sdk/…/widgets/Gesture.kt`, `sdk/…/widgets/GestureDetectorTest.kt`
Cases: K7 (5 tests) → green · red first: the 3 positive tests "could not find any node that
satisfies (OnClick is defined)"; the 2 absence tests passed before · K6 unchanged and green.
Changed: semantics with a click action only for onTap and a long-click only for onLongPress.
Decisions: no merged descendants (keeps K6's bounds); no button role (Flutter adds actions only).
Review fit: pass
Review quality: pass

### Test run
Group 1: `cd sdk-kotlin && ./gradlew build --console=plain --rerun-tasks`: BUILD SUCCESSFUL; core
112 (106 + 6), sdk 98 (71 + 27), 0 failures; lint "No issues found".
Group 2, the same command after all six returned: BUILD SUCCESSFUL; core 112, sdk 117 (98 + 19),
0 failures; lint "No issues found". Every changed file sits in its task's `Files`; no stray file.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
nothing yet. material-icons-extended is a new runtime dependency of the sdk (BOM-pinned, R8
drops unused icons in an app). Nothing is registered or advertised until S9.13, so no page can
use the new widgets before group 3; the record lines join Taskfile.yml in S9.14.
