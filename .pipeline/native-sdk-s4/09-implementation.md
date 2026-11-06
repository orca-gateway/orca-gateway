# 09 · Implementation · native-sdk-s4

## Front page

### In one breath
S4 is built on feat/native-sdk-s4: 9 code commits (23b.23, 24, 30, 31, Flutter 426), nothing pushed.
iOS draws 10 more widgets, plus the warn, require and 426 pages; capability-demo's 4 pages run.
native-widgets on the simulator: images, cards, flex, typing, hearts, tap, double tap, long press.
Fixed on the way: Flutter's tight layout (fill the forced axis), fast typing, the single-tap delay.
Tests: Swift core 111 (macOS, Linux 5.10/6.2, iOS); UI 46 macOS, 50 iOS with 4 goldens; Flutter 225.

### New for you
Flutter's tight constraints in SwiftUI (trade-off 3) → learning/swiftui-proposal-layout.md

### Trade-offs
1 needs you: Swift returns the 426 page from fetchPage, as Flutter now does (08 said throw); keep.
2 needs you: a host button style applies only when the server sent no style props at all; keep.
3 auto-decided: forced axes travel in the environment (`orcaTight`), the SwiftUI form of tight.
4 auto-decided: the FallbackPrompt CTA goes out as an openUrl effect, through OrcaURLPolicy.

### Questions for you
1. Push and open the S4 PR at stage 10? (default: yes; nothing merged or published)
2. UAT at 10: you try native-widgets and capability-demo on the simulator? (default: yes, :8097)
3. Flutter throws on the warn wrapper (a Column around a Scaffold). Its own session? (default: yes)
4. The min-SDK gate skips pre-release versions (iOS alpha never gets 426). Fix in S5? (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Tasks, status and evidence
| # | Status | Evidence |
|---|---|---|
| 23b.23 | done | `OrcaClient.upgradeRequiredPage` returns the page inside a 426 body `{error, minSdkVersion, clientSdkVersion, page}`; a 426 with no page, or any other status, still throws `.http`. The FallbackPrompt CTA calls `OrcaPageModel.openLink`: OrcaURLPolicy first, then an `openUrl` effect under OrcaApp, or SwiftUI's `openURL` for a page shown on its own. `examples/server/index.ts` reads `ORCA_FALLBACK_POLICY` and `ORCA_MIN_SDK_VERSION`, so you can see each policy live. capability-demo gains a `degrade` page (a Checkbox iOS lacks). T4.1: 4 FallbackPrompt tests (an allowed link, a blocked scheme, with and without a router). T4.2: 6 DegradeTests on the recorded graceful, warn, require and 426 bodies, plus goldens of warn and require. T4.3: trade-off 1 of 08, S3's DevTools test. Commit 4f392e4 |
| Flutter 426 | done | `orca_client.dart` `fetchPage` returns the embedded page on 426 (gate 08 question 1). `sdk/test/min_sdk_426_test.dart`: 3 tests (426 with a page, 426 without, 500). Commit 31be328 |
| 23b.24 | done | Icon (an SF Symbols table for Flutter's 156 names, unknown → `circle.fill`, `src` as a template image), Image (AsyncImage, assets, fit with cover by default, alt), Container (padding, margin, decoration with color, per-corner radii, border, shadows, gradient; width, height, alignment, clip), Expanded and Spacer (a `FlexLayout`, used only when a Row or Column has one), TextField (local text, setState on `stateKey`, onChange `{value}` per keystroke, the decoration). Caps: 25 widgets, hash regenerated. T4.4: 13 NativeWidgetTests (flex sizes, props, corners, every SF symbol exists, TextField events and typing order, the forced axis) and 2 IconNamesTests that read Dart's map. Commits 4c5dbdf, 3a035ef, 1c09298, f07c8cf |
| 23b.30 | done | Stack and Positioned through a `StackLayout` (alignment, fit, clip; edges, width, height); ClipRRect (a number or four corners); GestureDetector (only the gestures that have actions, the whole box takes touches). T4.5: 5 StackTests (Positioned frames, Flutter's edge rules, the demo's heart toggling its icon). Commits 79f6d0f, f07c8cf |
| 23b.31 | done | `OrcaTheme` in the environment with optional closures for Elevated, Outlined and Text buttons; `.orcaTheme(_:)` on any view; README "Styling buttons". T4.6: 3 OrcaThemeTests (the host styles a plain button, a server prop wins, the theme travels). Commit f2bd8d6 |
| demo | done | `examples/server/native-widgets.ts`: search field with a live "You typed" label, two food cards (image with rounded top corners, a badge, a heart), a 1:2 flex row, a Spacer row, a tap and double-tap box. Recorded page, render test and golden. Commit 9ece76f |

### On the simulator (iPhone 16 Pro, iOS 18.5, server on :8097)
- native-widgets: the photos load and cover their box, the top corners are clipped, the badges sit
  top right, the cards have soft shadows, flex 1:2 splits the row, the Spacer pushes its label right.
- Typing "salmon poke bowl" fast, then deleting it: the field and "You typed:" stay in step.
- The heart toggles at once; a long press shows "Margherita Pizza: long press".
- The bottom box: one tap shows "Tapped" about 300 ms later (the double-tap wait), two quick taps
  show "Double tapped". Toasts last 2 s, as in Flutter.
- capability-demo: home (info, "Learn more" opens example.com in Safari), upgrade (warn), blocked
  (blocking), negotiation (Divider), and degrade under `ORCA_FALLBACK_POLICY=warn`: the banner,
  then "Unsupported content" in place of the Checkbox.
- counter, basic-actions and server-actions still draw as in S3.

### Test results
| Where | Result |
|---|---|
| macOS, `swift test` | core 111/111, UI 46/46 (the goldens are iOS only) |
| Linux, `swift:5.10-jammy` and `swift:6.2-noble` | build with no warnings, 111/111 each |
| iOS 18.5 simulator, `xcodebuild test -scheme OrcaGateway-Package` | core 111/111, UI 50/50 with 4 goldens |
| Flutter, `flutter test` in `sdk/` | 225 passed |
| `gen-native-capabilities.ts`, `gen-widget-registry.ts` | no drift |
| Engine | unchanged by S4; last run 684 pass, 1 fail: a caps-412 test needs port 8080, which Docker holds here |

### Trade-off 1: the 426 page comes back from fetchPage
08 planned `OrcaClientError.updateRequired` carrying the page, and the loader drawing it. With the
Flutter fix in the same PR, `fetchPage` returns the page in both SDKs, so a host needs no new error
case and both draw the same screen. Alternative: throw in Swift and draw in the loader, so a host
can tell a 426 apart (it can today only by the page's root id `__min_sdk_block_root__`).

### Trade-off 2: when the host's button style applies
08 said "server props win". A per-prop merge would need the host closure to read each server prop;
instead a button with any of its type's server style props (Elevated: backgroundColor,
foregroundColor, borderRadius, padding; Outlined: color, borderColor; Text: color) keeps the native
look with those props, and only plain buttons take the host's style. Alternative: pass the server props into the closure and let the host merge.

### Trade-off 3: forced axes (auto-decided)
Flutter forces a child's size on the cross axis of a stretched Row or Column, the main axis inside
Expanded, and a Positioned child's set width or height; a Container or Text there fills it. SwiftUI
lets a view choose, so the cards' text boxes hugged their text. The parent writes the forced axes to
the environment; Container, Text and SizedBox read them; Center, Stack, an aligning Container and a
Scaffold's slots reset them. Cost: one more rule per new widget. Alternative: a custom Layout for
every container.

### Trade-off 4: the CTA as an effect (auto-decided)
The FallbackPrompt link goes through the same path as an `openUrl` action: the policy, then the
host's SystemActions under OrcaApp. A refused scheme does nothing, and DevTools sees the effect.

### Findings worth remembering
- F1 Flutter throws "RenderCustomMultiChildLayoutBox was given an infinite size" on the warn
  wrapper: the engine puts a Scaffold inside a Column. iOS draws it. Not fixed here (question 3).
- F2 The engine's `parseSemver` takes only X.Y.Z, so `0.1.0-alpha.1` skips the min-SDK gate. The
  426 body was recorded with `--sdk-version 0.1.0` (question 4).
- F3 S2's Card does not fill under stretch (basic-actions shows narrow cards); Flutter's does. The
  forced-axis rule would cover it; left for later so S2's goldens stay put.
- F4 Flutter's ClipRRect reads only a number radius, so the demo's rounded top corners are square on
  Flutter. Swift reads both forms, as Container does.
- F5 ecommerce's search sets `query` from `V.event("query")`, but both SDKs send `{value}`: an example
  bug, not fixed in S4.
- F6 Goldens are drawn with `layer.render(in:)`, which drops shadow blur; the device shows it.
- F7 CI runs Xcode 16.4 (iOS SDK 18.5) and has golden files only for counter; it skips warn, require
  and native-widgets, which are recorded with the local iOS SDK 27.2.
- F8 Taps arrive about 300 ms late when a node also has onDoubleTap, as in Flutter. Screenshots taken
  right after an injected tap miss the toast.
- F9 Epic plan rows 23b.30 and 23b.31 added (outside the repo, approved at gate 08).

### For ship (stage 10) to know
Nothing to deploy. Push the branch and open the PR. CI covers the ubuntu core, the macOS UI job (the
counter golden, app-ios build), schema and SDK. The `orca_gateway` 426 change is a patch for the
next sdk release, which you run with release.sh. The example server is stopped; UAT starts it again
on :8097 (`PORT=8097 bun run index.ts` in `examples/server`, with `ORCA_FALLBACK_POLICY` to taste).
