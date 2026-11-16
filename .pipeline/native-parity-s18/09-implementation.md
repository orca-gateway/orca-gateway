# 09 · Implementation · native-parity-s18

## Front page

### In one breath
group 7 of 7 · tasks: 16 green, 0 blocked · cases: 14 of 14 green · swift 381/250 · kt 375/316
T12 iOS, T13 Android: demo switches (401, dark, locale, host splash, timeout) and README sections.
T16: iOS pages went black on black under dark mode (a T5 gap); now Flutter's light page and bar.
Hand checks on both devices: error screens, dark mode, splash with its locale, placeholder cards.
Every suite green except PR #33's four iOS 26.5 tests, which also fail on main alone.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. A approves the stage; stage 10 ticks C18.1-C18.5 and opens the step 18 PR. (default: go)

## Appendix

### Group 1
#### Task T1 · Swift core error mapping
Files: sdk-swift/Sources/OrcaGatewayCore/Client/OrcaErrorInfo.swift (new) · sdk-swift/Tests/OrcaGatewayCoreTests/OrcaErrorInfoTests.swift (new)
Cases: C18.2/S mapping, 22 `testC18_2_*` tests: red (no OrcaErrorInfo), then green; `swift test` 347 (325 + 22), 0 warnings.
Changed: public `OrcaErrorInfo` (Equatable, Sendable): `kind`, `title`, `message`, `init(_ error:)`, Flutter's words
verbatim (orca_error.dart). `.http` / `.action` share one status switch (401/403/404/429/>=500); other status: `.http`
reads "Failed to fetch page: N", `.action` keeps its message. DecodingError and `.invalidURL` → Configuration Error;
nine URLError codes → Connection Failed; the rest → Something Went Wrong. Commit 7313974.
Decisions: 1. Connection codes: notConnectedToInternet, cannotConnectToHost, cannotFindHost, networkConnectionLost,
dnsLookupFailed, timedOut, internationalRoamingOff, dataNotAllowed, callIsActive (all in Linux Foundation 5.10, checked);
TLS, badServerResponse, cancelled → Something Went Wrong. 2. /config and /version read "Failed to fetch page: N"
(documented). 3. Codes in an array: only Equatable needed on Linux.
Review fit: pass
Review quality: pass

#### Task T2 · Kotlin core error mapping
Files: sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/OrcaErrorInfo.kt (new) · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/OrcaErrorInfoTest.kt (new)
Cases: C18.2/K mapping, 20 `c18_2_*` tests: red (did not compile), then green; core 347 (327 + 20).
Changed: public `data class OrcaErrorInfo(kind, title, message)`, enum `Kind` (KDoc names Flutter's icon), `from(Throwable)`,
Flutter's words verbatim. Some tests go through the real client with a stub transport (executeAction 400). Commit 8de7b09.
Decisions: 1. Only SerializationException and InvalidUrl → Configuration Error; a plain IllegalArgumentException (the
plugin conflict) → Something Went Wrong, tested. 2. SocketException, UnknownHostException, InterruptedIOException
(timeouts) → Connection Failed; plain IOException and SSLHandshakeException → Something Went Wrong (as Flutter's
HttpException/HandshakeException). 3. /config and /version read "Failed to fetch page: N" (documented).
Review fit: pass
Review quality: pass

### Group 2
#### Task T3 · Swift error screen per status
Files: sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Sources/OrcaGateway/OrcaBoot.swift · sdk-swift/Tests/OrcaGatewayTests/ErrorScreenTests.swift (new)
Cases: C18.2/S screen, 7 `testC18_2_*` tests (each kind's title, message, icon; 404 with retry; 401/403/429/503;
unreachable; retry loads the page; config 500 with retry; plugin conflict, no retry): red (new types), then green.
Changed: public `OrcaErrorView(error:retry:)` (Flutter's sizes, platform colours, SF Symbols, "Try again" with a
retry, id `orca.error`); LoadError deleted. OrcaPageLoader and OrcaAppBoot gain a public read-only `error` beside the
unchanged `.failed(String)`, cleared on reload/retry. The config-boot switch moved into an internal AppBootContent.
The conflict shows "Something Went Wrong" with its own message (OrcaPluginConflict), no retry. Commit d62d7b0.
Decisions: 1. A small Mirror-based ViewTree in the tests reads the drawn texts and symbols (no inspection helper; the
accessibility tree is empty in a test window). 2. `.failed` with a nil error draws nothing (the loaders set both).
AppBootTests and OrcaAppPluginTests unchanged: no test pinned the old titles.
Review fit: pass (the conflict test's request count proves little; OrcaAppPluginTests' C16.1 test covers it)
Review quality: pass

#### Task T4 · Kotlin error screen per status
Files: sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaBoot.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/ErrorScreenTest.kt (new) · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppPluginTest.kt
Cases: C18.2/K screen, 10 `c18_2_*` tests: red at compile, then green; sdk 244 (234 + 10).
Changed: public `OrcaErrorView(error, modifier, onRetry?)`, Flutter's exact Material icons (Outlined.Lock, Filled
Block, SearchOff, Speed, CloudOff, ErrorOutline, Settings, WifiOff), sizes, onSurface/onSurfaceVariant; old ErrorView
deleted. Both `Phase.Failed` gain `error: Throwable? = null` (message unchanged). OrcaBoot keeps the conflict error;
"Something Went Wrong" with its message, no retry. Tests pinning the old titles now assert the new title and message.
Commits 327ad31, d046127.
Decisions: 1. Icons straight from Icons, not IconNames (Dart's map lacks four of them). 2. A Failed phase with no
error draws RuntimeException(message): Something Went Wrong.
Review fit: pass
Review quality: bare TextStyle replaced the host text style, fixed (base.merge, with a host-font test)

### Group 3
#### Task T5 · Swift host views, theme, locale
Files: sdk-swift/Sources/OrcaGateway/OrcaApp.swift · sdk-swift/Sources/OrcaGateway/OrcaBoot.swift · sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · sdk-swift/Tests/OrcaGatewayTests/AppShellTests.swift (new)
Cases: C18.1/S, C18.3/S, 7 tests (5 `testC18_1_*`, 2 `testC18_3_*`): red (did not compile), then green; the Scaffold
assertion stayed red until Structure.swift was pinned. SwiftUI 151 under `swift test` (144 + 7).
Changed: both public inits gain, after their parameters, `loadingView`, `splashView`, `errorView`, `forceUpdateView`
(AnyView closures), `colorScheme: ColorScheme?`, `locale: Locale?`, nil by default. An internal BootViews mirrors
Flutter's _buildSplash / _buildForceUpdate / _buildError (the host's error view alone, no retry). ScaffoldView pins
the light scheme (Flutter's light ThemeData wrap). Pages keep the SDK spinner and OrcaErrorView. Commit 91ef6c0.
Decisions: 1. The scheme and locale go through the environment inside OrcaApp (transformEnvironment; nil leaves the
host's), not preferredColorScheme: Flutter's themeMode also stops at its MaterialApp. 2. x-orca-locale unchanged,
tested.
Review fit: pass
Review quality: pass

#### Task T6 · Kotlin host views, theme, locale
Files: sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaBoot.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Structure.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/AppShellTest.kt (new)
Cases: C18.1/K (6 tests), C18.3/K (3 tests): red (did not compile), then green; sdk 253 (244 + 9). Putting the host
scheme back on the Scaffold turns its assertion red.
Changed: both overloads gain `loading`, `splash`, `error(Throwable)`, `forceUpdate`, `colorScheme: ColorScheme?`,
`locale: Locale?`, null by default. OrcaBootView draws the host's views for its phases; the config boot draws splash ?:
loading, and the host's error(e) alone or OrcaErrorView with retry. ScaffoldWidget pins `lightColorScheme()`; a server
backgroundColor still wins. Retained ViewModel and plugin wiring unchanged. Commit b050ee5.
Decisions: 1. The theme and locale wrapper is always in the tree (null keeps the host's scheme), so switching them
keeps the boot and the stack. 2. A locale does not change the layout direction (Flutter's default localizations are
LTR without the host's). 3. The wrapper keeps the inherited text style (goldens unchanged).
Review fit: pass
Review quality: the private wrapper was named OrcaTheme like the public host theme, fixed (WithSchemeAndLocale,
commit 05886be)

#### R3 · Rebase onto origin/main 96094da (PRs #35 and #32)
Main brought the config boot as the default, the tab shell, per-tab stacks, drawers and three widgets (31 advertised).
Old tip 05886be → new tip 8d41cc2; only T3-T6 changed. Conflicts: OrcaApp.kt doc (both texts), AppBootContent's ready
phase draws main's RouterRoot (tab shell, drawer layer), Structure.kt (the light pin wraps main's PageDrawer and
ScaffoldFrame), both Swift init and doc merges. No old error view left; tab and drawer pages go through RoutePage
(OrcaErrorView with retry) under the scheme and locale wrapper. Tests that meant `home` now name it (4 in
ErrorScreenTest, 3 in AppShellTest); no assertion changed. Generated files had no conflict.
Suites: engine 745 · Flutter 326 · cli 27, analyze clean · Swift 0 warnings, swift test 197 + 351 · xcodebuild 217,
4 skips, main's 4 failures only · Kotlin core 353, sdk 294 · both example apps build.
Review fit: pass
Review quality: pass

#### R3b · An iOS page drawer stays light under a dark scheme
Files: sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · sdk-swift/Tests/OrcaGatewayTests/AppShellTests.swift
Found in R3: main draws iOS page drawers in the app-root layer, outside ScaffoldView's light pin. `ScaffoldDrawers.open`
now hands the host the drawer content pinned light (page drawers only; the shell drawer is unchanged), as Flutter's
Scaffold wrap and Android. Case `testC18_3_APageScaffoldDrawerStaysLightUnderADarkScheme`: red, then green. Commit d1bb105.
Review fit: pass
Review quality: pass

### Group 4
#### Task T7 · Swift request timeout option
Files: sdk-swift/Sources/OrcaGatewayCore/Client/OrcaClient.swift · sdk-swift/Sources/OrcaGatewayCore/Client/HTTPTransport.swift · sdk-swift/Tests/OrcaGatewayCoreTests/RequestTimeoutTests.swift (new)
Cases: C18.5/S, 8 `testC18_5_*` tests: red (no `timeout`), then green; core 359 (351 + 8).
Changed: `OrcaClient(..., timeout: TimeInterval = 30)` and a public `var timeout` (copies keep it). The client's one
send path races the transport against the timeout in a throwing task group; on timeout it cancels the transport and
throws URLError(.timedOut) (Connection Failed). HTTPRequest gains `timeout`; URLSessionTransport sets
URLRequest.timeoutInterval from it. Commit 18e179b.
Decisions: 1. URLRequest.timeoutInterval is set too, so the SDK's transport stops in time (a task group waits for its
children). 2. The task group is kept; a custom transport must honour cancellation (documented). 3. Non-positive or
NaN timeouts mean 0 s; capped at 4e9 s.
Review fit: no public doc said a custom transport must honour cancellation, fixed (commit c56c36e)
Review quality: the doc did not name Dart's source or say Flutter never applies its timeout, fixed (commit 039eb72)

#### Task T8 · Kotlin request timeout option
Files: sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/OrcaClient.kt · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/client/HttpTransport.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/client/OkHttpTransport.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/client/OrcaClientTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/client/OkHttpTransportTest.kt
Cases: C18.5/K, 4 core + 2 sdk `c18_5_*` tests: red (did not compile; the slow answer got a 200 on the old
transport), then green; core 357, sdk 296.
Changed: `HttpRequest.timeoutMillis: Long? = null`; `OrcaClient(..., timeoutMillis: Long = 30_000)` carried by its
copies and put on every request in its one send path (page, handshake retry, config, action, version, session,
analytics). OkHttpTransport sets it as the call's own timeout; past it OkHttp throws InterruptedIOException("timeout")
(Connection Failed). MockWebServer tests: 1 s answer vs 100 ms throws; 50 ms answer within 5 s succeeds. Commit 111a7e3.
Decisions: 1. Long milliseconds, as the module names time (flushIntervalMillis). 2. Per-call timeout, no client copy.
Review fit: pass
Review quality: the KDoc did not name Dart's source or say Flutter never applies its timeout, fixed (commit 992a6fd;
HttpTransport's KDoc also says a custom transport must apply it)

### Group 5
#### Task T9 · Kotlin placeholder drawn as Flutter
Files: sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/widgets/Content.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/UnsupportedWidgetPlaceholderTest.kt (new)
Cases: C18.4/K look, 6 `c18_4_*` tests: red (did not compile), then green; sdk 302 (296 + 6).
Changed: internal `UnsupportedWidgetPlaceholderWidget(node, model, modifier)` next to FallbackPromptWidget: Flutter's
grey card (6% fill, 1 px 35% border, radius 8), icon from IconNames, one-line title (displayName or widgetType),
reason or Flutter's default, "Learn more" through `model.openLink` (the URL policy). Not registered or advertised yet.
Commit 20ced52.
Decisions: 1. Inner padding 17: Flutter's Container adds the border width to the padding. 2. Any iconName draws an
icon (an unknown one the circle), as Flutter's resolveIconData never returns null. 3. "Learn more" has no ripple,
like Flutter's GestureDetector.
Review fit: pass
Review quality: pass

#### Task T10 · Swift placeholder drawn as Flutter
Files: sdk-swift/Sources/OrcaGateway/Widgets/Content.swift · sdk-swift/Tests/OrcaGatewayTests/UnsupportedWidgetPlaceholderTests.swift (new)
Cases: C18.4/S look, 10 `testC18_4_*` tests: red (did not compile), then green; SwiftUI 208 (198 + 10).
Changed: internal `UnsupportedWidgetPlaceholderView(node:model:)` next to FallbackPromptView: Flutter's card, icon via
IconNames (hidden from VoiceOver), title, reason or default, "Learn more" through `model.openLink`; content-wide unless
the parent forces the width, as Flutter's Container. Not dispatched or advertised yet. Commits 6e5526e, 6026452, d8dbce0.
Decisions: 1. An unknown iconName draws circle.fill (Flutter's Icons.circle). 2. Edges tested exactly, with a glyph
side-bearing helper.
Review fit: content inset 16 instead of Flutter's 16 + border (17), tests too loose to see it, fixed (6026452)
Review quality: the icon was read by VoiceOver, unlike Flutter and Kotlin, fixed (d8dbce0)

### Group 6
#### Task T14 · Swift placeholder advertised and dispatched
Files: sdk-swift/capabilities.json · sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift · sdk-swift/Sources/OrcaGateway/NodeView.swift · sdk-swift/Tests/OrcaGatewayCoreTests/CapabilitiesTests.swift · sdk-swift/Tests/OrcaGatewayTests/UnsupportedWidgetPlaceholderTests.swift · sdk-swift/Tests/OrcaGatewayTests/StructureWidgetTests.swift (added by hand at 09)
Cases: C18.4/S advertised: testC18_4_…AdvertisedAndTheStandardRegistryKnowsIt red ("not advertised"), then green ·
testC18_4_APageWithFixture17…DrawsThePlaceholder red ("degraded to FallbackPrompt"), then green (shown at 115d032).
Changed: capabilities.json and the regenerated vector list it (32, hash 039b7725…, equal to Kotlin's); the widget switch
draws UnsupportedWidgetPlaceholderView; group 5's tests now use the standard registry; the 31 pin moves to 32.
Commit 47d9790.
Decisions: 1. The page test uses fixture 17's expected[0], the node the engine sends. 2. Exactly 32, not >=.
Review fit: 31 pin left red, moved (47d9790); red run missing from the digest, shown; fixed
Review quality: pass

#### Task T11 · Kotlin placeholder advertised and registered
Files: sdk-kotlin/capabilities.json · sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt · sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt · sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/capabilities/CapabilitiesTest.kt · sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/widgets/UnsupportedWidgetPlaceholderTest.kt
Cases: C18.4/K advertised: red ("expected 32 but was 31"; "expected UnsupportedWidgetPlaceholder but was
FallbackPrompt"), then green; sdk 316 (315 + 1).
Changed: capabilities.json and Generated.kt list it (32, same hash as Swift); WidgetBuilders registers group 5's
composable; pin renamed `c1_kotlinAdvertisesTheSame32WidgetsAsSwift`; a page with fixture 17 draws the card, not
FallbackPrompt. Commit b25ba05.
Decisions: 1. Group 5's test never widened a registry; only its KDoc changed. 2. capabilities.json $comment unchanged.
Review fit: pass
Review quality: pass (nits only: import order, one assertion style)

#### Task T15 · Placeholder demo page on the example server (added by hand at 09)
Files: examples/server/capability-demo.ts · examples/server/index.ts
Cases: C18.4 hand (enables): live on :8097, `/capability-demo/page/placeholder` 404 before, then 200 with two
UnsupportedWidgetPlaceholder nodes (fixture 17's props; widgetType only). Engine 748.
Changed: a `placeholder` page in the capability demo app and its console line. Commit 115d032.
Decisions: 1. Imported from components/primitive: components/index.ts does not re-export the widget.
Review fit: pass
Review quality: pass

### Group 7
#### Task T12 · iOS demo, Swift README sections
Files: examples/app-ios/OrcaCounter/OrcaCounterApp.swift · examples/app-ios/README.md · sdk-swift/README.md
Cases: C18.3 hand/S (enables): example builds, no warnings; README sample compiled against the local SDK; on the
simulator 404, 401, offline, dark, host splash, locale and the placeholder page matched the README.
Changed: switches ORCA_API_KEY, ORCA_SCHEME, ORCA_LOCALE, ORCA_SPLASH, ORCA_TIMEOUT (defaults unchanged) into the client
and OrcaApp; a private HostSplash showing the locale its views get; both README sections; alpha banner 32 widgets /
20 action kinds. Commit 5fd012f.
Decisions: 1. ORCA_TIMEOUT set only when given. 2. Splash caption shows the locale (memory: ios-demo-splash-shows-locale).
3. Commands add `--terminate-running-process`; the splash is held with `nc -l` + ORCA_TIMEOUT=5.
Review fit: pass
Review quality: pass

#### Task T16 · Swift Scaffold page light under a dark scheme (added by hand at 09, found by T12)
Files: sdk-swift/Sources/OrcaGateway/Widgets/Structure.swift · sdk-swift/Tests/OrcaGatewayTests/AppShellTests.swift
Cases: C18.3/S fix, 4 `testC18_3_` tests: 3 red (no background, dark bar), then green; 1 regression guard.
Changed: T5 pinned ScaffoldView light but it drew no background, so under a dark scheme (and a dark device with no
scheme) a page was black on black. ScaffoldView now always paints backgroundColor or the light system background, and
AppBarChrome pins the bar light (`toolbarColorScheme`). Commit b9f4886.
Decisions: 1. The bar checked through a real UINavigationBar in a UIKit window. 2. Bar pinned only under an AppBar.
Review fit: pass
Review quality: pass

#### Task T13 · Android demo, Kotlin README sections
Files: examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt · examples/app-android/README.md · sdk-kotlin/README.md
Cases: C18.3 hand/K (enables): assembleDebug green; on the emulator 401, 404, offline, dark, host splash, the locale
caption, a 2 s timeout and the placeholder page.
Changed: the same five extras (the activity's MaterialTheme on the scheme), a private HostSplash showing the locale
OrcaApp provides, both README sections, counts 32 / 20. Commits 9e1c75e, 4ac69f4, b48f426.
Decisions: 1. Error tables use Flutter's titles (Forbidden, Not Found), not the brief's. 2. Fractional ORCA_TIMEOUT.
Review fit: no locale visible for the hand check, fixed (4ac69f4)
Review quality: READMEs said a path boot skips the version check, fixed (4ac69f4); then a copied 30 s default,
blocked, retried once under the standing rule's default, fixed (b48f426)

### Test run
Group 7: generators no drift · engine 748 · Flutter 330 · cli 27, analyze clean · `swift build --build-tests` 0
warnings · `swift test` 381 + 219 · xcodebuild OrcaGatewayTests 250 run, 4 golden skips, PR #33's 4 iOS 26.5
failures only · `./gradlew build` core 375, sdk 316 · both example apps build (Android again after b48f426).
Group 6: generators no drift · engine 748 · `swift build --build-tests` 0 warnings · `swift test` 381 ·
xcodebuild OrcaGatewayTests 246 run, 4 golden skips, PR #33's 4 iOS 26.5 failures only · `./gradlew build` core 375,
sdk 316. Files: the tasks' only (StructureWidgetTests added to T14 by hand).
R4 (rebased onto 3cdeef7, PR #36): generators no drift · engine 748 · Flutter 330 · cli 27, analyze clean · `swift
build --build-tests` 0 warnings · `swift test` 380 · xcodebuild OrcaGatewayTests 245 run, 4 golden skips, PR #33's 4 iOS
26.5 failures only · `./gradlew build` core 375, sdk 315 · both example apps build.
Group 5: `swift build --build-tests` 0 warnings · `swift test` 359 + 208 · xcodebuild OrcaGatewayTests 228 run, 4
golden skips, PR #33's 4 iOS 26.5 failures only · `./gradlew build` core 357, sdk 302. Files: the tasks' only.
Group 4: `swift build --build-tests` 0 warnings · `swift test` 359 · xcodebuild OrcaGatewayTests 218 run, 4 golden
skips, main's 4 failures only · `./gradlew build` core 357, sdk 296, 0 failures. Files: the tasks' only.
Group 3: `swift build --build-tests` 0 warnings · `swift test` 347 · xcodebuild OrcaGatewayTests 171 run, 4 golden
skips, 4 failures = main's on iOS 26.5, none else · `./gradlew build` core 347, sdk 253, 0 failures. Files: the tasks' only.
Group 2: `swift build --build-tests` 0 warnings · `swift test` 347 · xcodebuild OrcaGatewayTests 164 run, 4 golden
skips, 4 failures = main's on iOS 26.5 (AppBarCardTests A1_9 ×3, ButtonTests D11), none else · `./gradlew build` core
347, sdk 243 (244 after the T4 rework), 0 failures, 0 skipped. Files changed: the tasks' files only.
Group 1: `swift build --build-tests` 0 warnings · `swift test` 347, 0 failures · `./gradlew build` exit 0, core 347,
sdk 234, 0 failures, 0 skipped. Failures: none. Files changed: the tasks' files only.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
PR #34 merged (5e3099f); after group 2 the branch was rebased onto 5e3099f (tree unchanged), after group 3 onto
96094da (PRs #35 and #32, R3), after group 5 onto 3cdeef7 (PR #36, R4: no shared files, range-diff unchanged,
restore point d8dbce0). No config, env or migration.
Hand checks by the session after group 7 (iOS 04AFD6DE, Android emulator-5584, server :8094): 404, 401, offline, dark
error screen, a Scaffold page light under a dark scheme (iOS also with the device dark), the host splash reading
"host splash · fr-FR" until the 5 s timeout shows Connection Failed, and the placeholder page's two cards.
Screenshots: session scratchpad s18/hand-ios and s18/hand-android.

### Stage 10 rework: rebase on main 6a7f0e0 (PRs #37, #40) and PR #38's CI (2026-11-16)
PR #38 conflicted with main after PRs #37 (deep links) and #40 (13 layout wrappers, Scaffold insets) merged, and its
"UI tests and example (iOS simulator)" job failed to build the test target on Xcode 16.4 (run 43784457921).
Rebase (restore point backup/native-parity-s18-pre-rebase): conflicts resolved by hand in OrcaApp.kt (T4, T6:
RouterApp takes the host views, onDeeplink kept), OrcaApp.swift (T3, T5: AppBootContent keeps firstRouteAppeared and
the deep link modifiers), Structure.swift (doc), capabilities.json ×2 and the count pins (44 + UnsupportedWidgetPlaceholder
= 45), both demo apps (onDeeplink and the step 18 switches); Generated.swift/.kt regenerated, never merged (45 widgets,
one capsHash c24e80ed… for both).
- T17 (226aab9) Swift: the C18.4 look test's padding points are typed sub-expressions; Xcode 16.4 gave up on them
  (1.1 s on Xcode 27.2). Review fit: pass · Review quality: pass
- T18 (9847d5e) Kotlin A3.1 pin and the README counts move to 45. Review fit: pass · Review quality: pass
- T20 (de3bde5) Kotlin: PR #37's B11.1 failed-config test waits for step 18's "Server Error" screen. Review fit: pass ·
  Review quality: pass
- T19 (421f2e1) Swift: before iOS 26 a page AppBar's navigation bar and the status bar stayed dark under a dark scheme
  (toolbarColorScheme applies only to a visible bar background); a UIKit pin keeps them light; the warn golden takes the
  Scaffold's painted background (one seam row). Found on the iOS 18.5 simulator; T16 was checked on 26.5 only.
  Decision (memory "ios-bar-light-pin", minor): a pin, not `.toolbarBackground(.visible)` (a hairline breaks three
  goldens). Review fit: pass · Review quality: pass
Test run (rebased head 421f2e1): engine 751 · Flutter 349 · cli 27 · generators no drift · `swift test` core 407,
SwiftUI 286, 0 warnings · xcodebuild package on iOS 18.5 (CI's runtime) 407 + 330, 0 failures, goldens compared ·
iOS 26.5: 5 AppBarCardTests/ButtonTests failures, all failing on origin/main alone (PR #33's four plus
A1_9ScaffoldLeadingWidthSizesTheLeadingSlot since PR #40) · `./gradlew build` core 401, sdk 402, 0 failures · both
example apps build.
