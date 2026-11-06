# 08 · Tasks · native-sdk-s4

## Front page

### In one breath
S4 is rows 23b.23-24. The engine already strips, banners and blocks; Swift already draws
FallbackPrompt like Flutter. Swift gains the 426 page and tests for all three policies.
Icon, Image, Container, Expanded, Spacer and TextField join the iOS caps (targets already say ios).
Done: capability-demo and a new widget demo run on a simulator; S2-S3 demos stay green.

### New for you
Expanded and Spacer need flex, which SwiftUI lacks → learning/swiftui-proposal-layout.md

### Trade-offs
1 needs you: T4.3 wants a grey debug card and nothing in release for an unknown widget; S2 gate 09
  chose Flutter's FallbackPrompt in every build. Default: keep S2; DevTools is the debug cue.
2 needs you: icons. SF Symbols for Flutter's 156 Material names, unknown → circle (default),
  or bundle the Material Icons font for an exact match (about 350 KB more).
3 auto-decided: flex via a SwiftUI Layout, only in Rows/Columns with Expanded/Spacer; golden holds.
4 auto-decided: TextField fires onChange with {value} per keystroke, setState on stateKey (Flutter).

### Questions for you
1. 426: Swift shows the server's "Update required" page (T4.2); Flutter throws instead.
   Fix Flutter too? (default: yes, in this PR; it rides on the pending sdk patch)
2. Add Stack, Positioned, ClipRRect, GestureDetector as row 23b.30 (your food app)? (default: yes)
3. Host button style as row 23b.31: OrcaTheme closures per button type, server props win. Flutter
   hosts already get this from ThemeData. (default: yes)
4. A new example app, `native-widgets`: one food-card page with the S4 widgets? (default: yes)
5. Epic rows for 2 and 3 are added outside the repo at stage 09. (default: yes, for each yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Rows
23b.23 and 23b.24 come from `.pipeline/native-sdk/08-tasks.md` lines 60-61. 23b.30 and 23b.31 are
proposed here (questions 2 and 3); you asked for both at native-sdk-s3 gate 09.

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 23b.23 | Degrade on iOS. FallbackPrompt's CTA goes through `OrcaURLPolicy` and SystemActions, like any openUrl. OrcaClient reads a 426 body `{error, minSdkVersion, clientSdkVersion, page}` and throws `OrcaClientError.updateRequired` carrying the page; OrcaPageLoader draws that page. Unknown types keep S2's FallbackPrompt (trade-off 1). With question 1: Flutter's `fetchPage` returns the 426 page instead of throwing. | T4.1: info, warn and blocking draw Flutter's colours; the CTA goes through the policy (blocked schemes do nothing). T4.2: stubbed graceful, warn and require responses render as caps-policy-e2e asserts; a stubbed 426 draws "Update required". capability-demo's four pages run on a simulator. |
| 23b.24 | Six widgets. Icon (SF Symbols map, `src` as an image, size, color), Image (network via AsyncImage, bundle names, fit, width, height, alignment, color tint, alt as the accessibility label), Container (padding, margin, decoration: color, radius, border, shadow, gradient; width, height, alignment, color, clip), Expanded and Spacer (flex, trade-off 3), TextField (trade-off 4, the props in Findings). `capabilities.json` gains the six; `Generated.swift` and the caps hash are regenerated. With question 4: `examples/server/native-widgets.ts`, one page. | T4.4 (new): each widget's props in unit tests, flex sizes from the Layout, TextField's onChange `eventData`. counter, basic-actions, server-actions and capability-demo still run (the "four examples", F2). Schema CI shows no drift. |
| 23b.30 | (question 2) Stack (alignment, fit, clip), Positioned (top, right, bottom, left, width, height, via a Stack Layout), ClipRRect (one radius or four corners), GestureDetector (onTap, onLongPress, onDoubleTap). The caps gain four. | T4.5 (new): Positioned frames from the Stack Layout; each gesture fires its trigger; native-widgets shows a food card with a badge on the image. |
| 23b.31 | (question 3) `OrcaTheme` in the SwiftUI environment: optional style closures for Elevated, Outlined and Text buttons. A server prop (backgroundColor, color, borderRadius, padding ...) still wins over the host. | T4.6 (new): a host closure styles a button with no server props; a server prop overrides it. README shows the hook. |

### Trade-off 1: what an unknown widget draws (T4.3 against S2 gate 09)
T4.3 says: a debug build shows a placeholder card for a degraded node, a release build shows nothing.
At S2 gate 09 you kept Flutter's behaviour: an unknown type draws a generic FallbackPrompt in every
build, and S3 reports each such type once to DevTools.
- **Default, keep S2.** Same as Flutter, so both SDKs show the same thing to the same user. A
  developer sees the type in DevTools' Errors tab. T4.3 is rewritten to "the DevTools warning goes
  out in Debug" (already tested in S3).
- **Alternative A, T4.3 as written.** Debug: a grey card naming the type, like Flutter's
  `UnsupportedWidgetPlaceholder` (#6B7280). Release: nothing. The SDKs then differ.
- **Alternative B, both.** Debug: the grey card; Release: the FallbackPrompt.
Either way it only covers types that reach the client: a node the server strips under graceful never
arrives (F3).

### Trade-off 2: icons
Flutter maps 156 Material names (`sdk/lib/src/builders/builder_helpers.dart:450`) and draws
`Icons.circle` for any other name.
- **Default, SF Symbols.** A table from each of the 156 names to the nearest symbol (`search` →
  `magnifyingglass`, `shopping_cart` → `cart`, ...), unknown → `circle`. iOS-looking icons, which is
  the platform-idiom call from native-sdk 05. A Swift test reads Dart's map and fails when a name has
  no entry, so the two tables cannot drift (it runs in the monorepo, not in the mirror).
- **Alternative, the Material font.** Bundle `MaterialIcons-Regular.ttf` (Apache 2.0) as a package
  resource and draw the codepoint. Pixel match with Flutter and every Material name, at about 350 KB
  and a resource bundle in the package.

### Trade-off 3: flex (auto-decided)
HStack and VStack cannot split spare space by weight. A `FlexLayout` (the iOS 16 `Layout` protocol;
the package floor is iOS 16) measures the fixed children, then gives the rest to Expanded and Spacer
children by `flex`, as Flutter's Row does. It is used only when a Row or Column has an Expanded or
Spacer child, so every page that renders today keeps its exact layout and the counter golden holds.
Cost: two code paths in FlexView. Alternative: move every Row and Column onto FlexLayout now.

### Trade-off 4: TextField (auto-decided)
Flutter keeps the text in the field and, on each change, runs setState on `stateKey` when the node
has one, then fires `onChange` with `eventData: {value}` (`input_builders.dart:71-80`). Swift does the
same: a local `@State` seeded from the resolved `value`, re-seeded when that value changes elsewhere.
Props: placeholder, inputType (keyboard type), obscureText (SecureField), maxLines, maxLength,
enabled, readOnly, autofocus, textInputAction (submit label), autocorrect, style, decoration
(labelText, hintText, helperText, errorText, prefixText, suffixText, filled, fillColor,
contentPadding, labelStyle). `enableSuggestions` has no SwiftUI switch and is ignored.

### Question 1: the 426 page
`min-sdk-version.ts:154` answers 426 with one FallbackPrompt page (`__min_sdk_block_root__`,
severity blocking, "Update required"). T4.2 says the SDK shows it. Flutter throws
`OrcaClientException(426)` and never draws it, so today a Flutter user sees the host's error UI.
Default: Swift draws it, and Flutter's `fetchPage` returns the embedded page on 426 (a few lines in
`orca_client.dart`, one test). A Flutter host that catches the 426 exception to show its own screen
would see the server's page instead; that is a patch-level behaviour change for `orca_gateway`.
Alternative: Swift only, and the SDKs differ until a later Flutter change.

### Findings while planning
F1 The six widgets' `targets` already list ios (S0 gave every widget but the seven ios). The real
   change is `sdk-swift/capabilities.json`, `Generated.swift` and the caps hash.
F2 "All four examples" reads as counter, basic-actions, server-actions and capability-demo. None
   uses the six. ecommerce, animations, custom and static-flows do, but they also use widgets iOS
   lacks (Drawer, BottomNavigationBar, AnimatedContainer ...), so they stay out of S4's acceptance.
F3 Under graceful the engine strips the node and sends no `droppedFeatures`. The client cannot draw
   anything for a node it never receives; T4.3 can only cover unknown types that reach it (a stale
   caps hash, a plugin widget).
F4 Flutter's TextField reads a `stateKey` prop that the engine class does not declare. Swift reads
   it too, so hand-built nodes behave the same.
F5 ecommerce's search sets `query` from `V.event("query")`, but both SDKs send `{value}`. It looks
   like an example bug; I check it at 09 and list it, without fixing it in S4.
F6 Per-corner radii (Container, ClipRRect) need a custom Shape: `UnevenRoundedRectangle` is iOS 17.
F7 Image `repeat` has no SwiftUI equivalent short of tiling by hand; S4 ignores it and says so in
   the doc comment.

### Package additions
```
sdk-swift/Sources/OrcaGatewayCore/
  Client/   OrcaClientError.updateRequired(minSdk, clientSdk, page); 426 decoding
  Render/   IconNames (Material → SF Symbol table)
sdk-swift/Sources/OrcaGateway/
  Widgets/  Icon, Image, Container, TextField views; FlexLayout; (23b.30) StackLayout, Positioned,
            ClipRRect, GestureDetector; (23b.31) Style/OrcaTheme
  OrcaApp   OrcaPageLoader draws the 426 page
sdk-swift/capabilities.json, Generated.swift (regenerated)
sdk/lib/src/client/orca_client.dart: 426 returns the embedded page (question 1)
examples/server/native-widgets.ts, index.ts entry (question 4)
```

### Tests (T4 group)
- T4.1: FallbackPrompt colours per severity (view inspection on iOS, the golden style); CTA through
  the URL policy with a SystemActions recorder.
- T4.2: stub transports return the graceful, warn and require shapes from caps-policy-e2e
  (`__caps_warn_root__`, `__caps_warn_banner__`, `__caps_block_root__`) and a 426 body; the page
  model renders each. Plus the Flutter 426 test (question 1).
- T4.3: per trade-off 1. Default: already covered by S3's once-per-type DevTools test.
- T4.4: the six widgets' prop mapping, FlexLayout sizes for flex 1:2 and a Spacer, TextField events,
  the icon table against Dart's map.
- T4.5 and T4.6: as in the rows above, when 23b.30 and 23b.31 are in.
- By you at 10: capability-demo's four pages, native-widgets, and a scratch server (not committed)
  that sets each policy and a high minSdkVersion, so you see warn, require and 426 live.

### CI
No new jobs. The ubuntu core job runs the 426 decoding and the icon table test. The macOS job runs
the view tests and builds app-ios. SDK CI runs the Flutter 426 test. Schema CI checks the caps.

### Commits on feat/native-sdk-s4 (conventional)
1. chore(pipeline): native-sdk-s3 gates 10 and 12, S3 closed (done)
2. chore(pipeline): native-sdk-s4 stages 01-08
3. feat(sdk-swift): 426 page, CTA policy and degrade tests (23b.23)
4. fix(sdk): draw the 426 update page instead of throwing (question 1)
5. feat(sdk-swift): Icon, Image, Container, Expanded, Spacer, TextField (23b.24)
6. feat(sdk-swift): Stack, Positioned, ClipRRect, GestureDetector (23b.30)
7. feat(sdk-swift): host button styles through OrcaTheme (23b.31)
8. feat(examples): native-widgets demo app
9. chore(pipeline): stage 09 onward

### Not in S4
- release.sh's mirror and the docs (S5); Kotlin (S6).
- The widgets iOS lacks (Checkbox, Drawer, FloatingActionButton, InkWell, Radio, SnackBar,
  Tooltip) and the rest of the 92 that ecommerce and friends use.
- Tiled images (`repeat`), and `enableSuggestions`.
- The sdk release; you run release.sh when you choose.
