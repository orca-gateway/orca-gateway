# 09 · Implementation · native-parity-s9

## Front page

### In one breath
group 5 of 5 · tasks: 10 green, 0 blocked · cases: 31 of 31 legs green · Swift 322 · Kotlin 395
T9 Swift `OrcaApp`: `path: nil` boots from the config; title bar; "Page not found" page.
T10 Kotlin `OrcaApp`: `path = null` does the same, with a Material top bar and a Back arrow.
The default stays `home`: making the config boot the default broke three existing Kotlin tests.

### New for you
nothing new

### Trade-offs
1 needs you: config boot as the default of `OrcaApp(client)` (breaks hosts relying on `home`)
vs opt-in with no path (landed). · 1 auto-decided: one navigation bar on iOS, two on Android.

### Questions for you
1. No task is blocked. (default: nothing to retry)
2. `A` approves the stage; ship runs the hand checks and opens the PR. (default: go)
3. Flip the default so `OrcaApp(client)` boots from the config, as Flutter? Not blocking: the
   opt-in form ships now, the flip is one word plus three test updates. (default: keep opt-in)

## Appendix

### Group 1
#### Task T1 · Navigation fixture contract, Flutter as oracle
Files: `schema/navigation-fixture.schema.json` (new) · `schema/fixtures/navigation/01..11_*.json` (new, 56 cases) · `schema/fixtures/navigation/README.md` (new) · `sdk/test/conformance/navigation_fixtures_test.dart` (new)
Cases: B9.2-F, B9.3-F, B9.4-F, B9.5-F, B9.9-F, B9.10-F → green (`flutter test test/conformance/navigation_fixtures_test.dart`: +57; red first against a wrong fixture) · baseline unchanged (`flutter test` +303, analyze no issues)
Changed: fixtures 01 param match, 02 unknown path, 03 `/homework` unreachable, 04 / 05 redirect logged out / in, 06 redirect applied once, 07 initialAppState + overlay, 08 nested children, 09 tabs, 10 scaffold title, 11 no tabs · the runner pumps the real `OrcaApp(preloadedConfig:)`, `router.go(location)` and compares the whole `expected` map read from the router, the pages on stage and the stub client
Decisions: 1. redirect applied once per navigation (go_router 16.3.0 `applyTopLegacyRedirect`), brief corrected · 2. after a redirect, location / routePath / params / stack describe the target and the asked query is dropped; a `go` to a non-tab route gives a stack of that page alone and `tabIndex` null · 3. a tabs fixture carries two tabs; no tabs fixture carries `expected.appState` (the shell writes `_tabIndex`)
Review fit: pass
Review quality: the schema let an `error` case carry page-only fields, fixed (an `else` on `Expected`, the shape test checks the exact key set, `Route.transition` closed)
Not done: the fixtures are not run through a JSON Schema validator (none in the repo)

#### Task T2 · Navigation demo app on the example server
Files: `examples/server/navigation.ts` (new) · `examples/server/index.ts` · `examples/server/README.md` · `engine/test/demo-server.test.ts`
Cases: B9.4-D → green (`bun test test/demo-server.test.ts`: 5 pass; red first: `/config` 404) · baseline unchanged (`bun test` 738 pass, 0 fail)
Changed: `navigationApp` (id `navigation`; initialRoute `/welcome`; initialAppState `{loggedIn:false,userName:""}`; tabs home + account; drawer item Settings; flows welcome, home with child `product/:id`, account with the redirect + login, settings with child `about`; 7 titled pages) · registered in index.ts · README row · test `B9.4-D`
Decisions: 1. a local `Replace(route)` helper adds `replace: true` to `Navigate(route)` · 2. login sets a fixed `userName` · 3. log out on welcome (state only) and on account (state, then replace to `/welcome`)
Review fit: pass
Review quality: pass
Not done: `tsc --noEmit` is not a gate here (an existing tsconfig error)

### Group 2
#### Task T3 · Swift core: NavConfig model, fetchConfig
Files: `sdk-swift/Sources/OrcaGatewayCore/Models/NavConfig.swift` (new) · `sdk-swift/Sources/OrcaGatewayCore/Client/OrcaClient.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/OrcaClientTests.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/ModelRoundTripTests.swift` · `sdk-swift/Tests/OrcaGatewayCoreTests/Support/Fixtures.swift`
Cases: B9.1-CS → green (`swift test`: 239 tests, 0 failures; 5 new, red first as a compile error) · baseline unchanged (234 → 239)
Changed: `NavConfig`, `TabDef`, `DrawerItemDef`, `NavFlow`, `NavRoute`, `RedirectRule`, `RouteTransitionDef` as public Decodable / Equatable / Sendable structs with Dart's defaults, `raw` and `rawBody` kept, `NavFlow.pages` kept · `fetchConfig() async throws -> NavConfig`: one GET with the client's headers, non-200 as `OrcaClientError.http` · tests: URL, headers, decode, 404 / 500; every navigation fixture config decodes; count pinned at 11
Decisions: 1. no capability handshake, a 412 is a plain HTTP error, as Dart · 2. Decodable only; writing back goes through `raw` / `rawBody` · 3. absent `flows`, `routes`, `equals` default as Dart; required keys throw
Review fit: pass
Review quality: pass
Not done: nothing

#### Task T4 · Kotlin core: NavConfig model, fetchConfig
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/models/NavConfig.kt` (new) · `.../core/client/OrcaClient.kt` · `.../core/client/OrcaClientTest.kt` · `.../core/support/Fixtures.kt` · `.../core/FixturePathsTest.kt`
Cases: B9.1-CK → green (`./gradlew build`: BUILD SUCCESSFUL, core 235, sdk 132; red first as a compile error) · baseline unchanged (core 228 + 7 new)
Changed: the seven public data classes with Dart's defaults and `NavConfig.fromJson(json, rawBody)` · `suspend fun fetchConfig(): NavConfig` · 6 client tests · `Fixtures.navigation` / `navigationFiles()` · the navigation count pinned at 11 and every fixture config decoded
Decisions: 1. `RedirectRule.when` with backticks, the same name as Swift and Dart · 2. plain GET, no caps-412 retry, as Dart · 3. decode-only models
Review fit: the new count pin sat inside an existing test, fixed (its own test, the existing one back to baseline)
Review quality: the same finding, fixed
Not done: a config failure still reads "Failed to fetch page: <status>" in the exception message (Dart says "config"); status and body are right

### Group 3
#### Task T5 · Swift core: RouteTable passes the navigation fixtures
Files: `sdk-swift/Sources/OrcaGatewayCore/Navigation/RouteTable.swift` (new) · `.../Navigation/RouteChangeEvent.swift` (new) · `sdk-swift/Tests/OrcaGatewayCoreTests/NavigationFixtureTests.swift` (new)
Cases: B9.2-S, B9.3-S, B9.4-S, B9.5-S, B9.9-S, B9.10-S → green (`swift test`: 248 tests, 0 failures; 11 files, 56 cases; red first as a compile error) · baseline unchanged (239 + 9 new)
Changed: `RouteTable(config).resolve(location, appState:) -> RouteResolution` (kind, location, redirected, pagePath, routePath, params, stack, tabIndex, scaffoldTitle, transition, queryParameters), `RouteResolutionKind`, `RouteChangeEvent`, `RouteChangeType` · the runner compares every expected field, one method per case id, `test_unpinnedCornersAgreeWithKotlin` beside them
Decisions: 1. the redirect lookup runs on the asked location whether or not a reachable route matches, as go_router does · 2. params and query values are percent-decoded, `pagePath` and `stack` keep raw segments · 3. a rule whose `equals` is a list or map never holds, as Dart `==`
Review fit: the twins disagreed on one name and on unpinned inputs, fixed (`routePath` from the chain's segments, Dart's title capitalisation, a mirrored test)
Review quality: pass
Not done: Swift compares path text by canonical equivalence (NFC / NFD), Kotlin and Dart by code unit

#### Task T6 · Kotlin core: RouteTable passes the navigation fixtures
Files: `sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/navigation/RouteTable.kt` (new) · `.../navigation/RouteChangeEvent.kt` (new) · `sdk-kotlin/core/src/test/kotlin/com/orcagateway/core/navigation/NavigationFixtureTest.kt` (new)
Cases: B9.2-K, B9.3-K, B9.4-K, B9.5-K, B9.9-K, B9.10-K → green (`./gradlew build`: BUILD SUCCESSFUL, core 243, sdk 132; 11 files, 56 cases; red first as a compile error) · baseline unchanged (core 235 + 8 new)
Changed: `RouteTable(config).resolve(location, appState)`, `RouteResolution`, `RouteResolutionKind { Page, Error }`, `RouteChangeEvent`, `RouteChangeType { Push, Replace, Pop }` · the runner compares every expected field, one method per case id, `unpinnedCornersAgreeWithSwift` beside them
Decisions: 1. when a rule holds, `location` is the rule's `to` · 2. params percent-decoded, `pagePath` / `stack` raw; `+` is a space in a query, a repeated key keeps its last value · 3. one bad escape keeps the whole part raw
Review fit: pass
Review quality: the percent-decoder corrupted a non-BMP character beside an escape, fixed (text copied whole, escape runs decoded strictly; `queryParameters`, `config` and the defaults aligned with Swift)
Not done: nothing

### Group 4
#### Task T7 · Swift router: config, app state, onRouteChanged
Files: `sdk-swift/Sources/OrcaGateway/Navigation/OrcaRouter.swift` · `sdk-swift/Tests/OrcaGatewayTests/RouterTests.swift` · `sdk-swift/README.md` (`OrcaPageModel.swift`, `PageModelTests.swift` not needed)
Cases: B9.6-US, B9.7-US → green (`swift test`: UI 104, core 248, 0 failures; 14 new; red first as compile errors, then one behavioural red) · baseline unchanged (the 7 router tests untouched)
Changed: `OrcaRoute` gains `location`, `scaffoldTitle`, `isNotFound`, `transition` · `OrcaRouter.init(client:config:system:onRouteChanged:)` seeds `initialAppState`, shows `initialRoute`'s chain as root + stack · `navigate` resolves through `RouteTable` · `setAppState` commits into every loaded page · `onRouteChanged` once per changed top location · README section
Decisions: 1. a push of a nested location adds its top page only; `replace` shows the chain · 2. `attach` merges: the router's scope wins, the page's seeds fill unset keys, so a host write during a load is kept · 3. the same location pushed over itself adds a page and fires no event
Review fit: the Kotlin twin lost a host write made during a page load, fixed in T8 (no Swift change)
Review quality: pass
Not done: the path init has no boot event; the `OrcaApp` side is group 5

#### Task T8 · Kotlin router: config, app state, onRouteChanged
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/navigation/OrcaRouter.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/navigation/RouterTest.kt` · `sdk-kotlin/README.md` (`OrcaPageModel.kt`, `PageModelTest.kt` not needed)
Cases: B9.6-UK, B9.7-UK → green (`./gradlew build`: BUILD SUCCESSFUL, core 243, sdk 146; 14 new; red first) · baseline unchanged (the 10 router tests untouched)
Changed: `OrcaRoute(path, location, scaffoldTitle, isNotFound, transition)` · `OrcaRouter(client, config, system, onRouteChanged)` beside the unchanged path constructor · `navigate` through `RouteTable` · `setAppState` · `onRouteChanged` · `public val table` · README section
Decisions: 1. one page per push, the chain on `replace` · 2. `stack` set from outside is `Pop` when shorter, else `Push` · 3. a not-found route still gets a loader if asked; `OrcaApp` checks `isNotFound` first (group 5)
Review fit: pass
Review quality: a host write made while a page was fetching was reverted when the page landed, fixed (`attach` merges as Swift does; the not-found path drops only the query, as Swift)
Not done: the `OrcaApp` side is group 5

### Group 5
#### Task T9 · Swift OrcaApp: config boot, title bar
Files: `sdk-swift/Sources/OrcaGateway/OrcaApp.swift` · `sdk-swift/Tests/OrcaGatewayTests/AppBootTests.swift` (new) · `examples/app-ios/OrcaCounter/OrcaCounterApp.swift` · `examples/app-ios/README.md`
Cases: B9.1-US, B9.5-US, B9.8-US → green (`swift test`: UI 74, core 248, 0 failures; 6 new; red first as a compile error) · baseline unchanged · the example app builds
Changed: `OrcaAppBoot` (loading / ready(router) / failed(message)) · `OrcaApp(client:path:system:onRouteChanged:)`: a path (default `home`) as before, `path: nil` fetches `/config` once and boots the config router, a failed fetch shows "Try again" · a not-found route draws "Page not found" with no loader · a route with `scaffoldTitle` gets an inline navigation title, the page's title once loaded · example host `ORCA_BOOT=config`
Decisions: 1. a page with its own AppBar on a titled route gives one navigation bar (Flutter shows two) · 2. the title is `page.title` once loaded, even when empty, as Flutter · 3. the hosted title check runs on macOS and is skipped on iOS
Review fit: pass
Review quality: pass
Not done: the back button is not asserted by a test (NavigationStack draws it); it rests on the hand check

#### Task T10 · Kotlin OrcaApp: config boot, top bar
Files: `sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/OrcaApp.kt` · `sdk-kotlin/sdk/src/test/kotlin/com/orcagateway/sdk/OrcaAppTest.kt` · `examples/app-android/app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt` · `examples/app-android/README.md` (`OrcaPageView.kt` not needed)
Cases: B9.1-UK, B9.5-UK, B9.8-UK → green (`./gradlew build`: BUILD SUCCESSFUL, core 243, sdk 152; 6 new; red first) · baseline unchanged (no baseline test edited) · the example app builds
Changed: `OrcaAppBoot` (Loading / Ready(router) / Failed(message)) · `OrcaApp(client, modifier, path, system, onRouteChanged)`: a path (default `home`) as before, `path = null` boots from `/config` · a not-found route draws "Page not found" with no loader · a route with `scaffoldTitle` sits under a Material 3 `TopAppBar` with the live title and a Back arrow · example host extra `ORCA_BOOT=config`
Decisions: 1. a page with its own AppBar draws it below the route bar, two bars as Flutter · 2. the title is the page's once loaded, else the fallback · 3. first pass made the config boot the default and broke three baseline tests; reworked to opt-in, the default question goes to the user
Review fit: pass
Review quality: pass
Not done: nothing

### Test run
`cd engine && bun test` · 738 pass, 0 fail · `cd sdk && flutter test` · +303 All tests passed · `flutter analyze` · No issues found · `cd sdk-swift && swift test` · UI 74 and core 248 tests, 0 failures, no warnings · `cd sdk-kotlin && ./gradlew build` · BUILD SUCCESSFUL, core 243, sdk 152 · `examples/app-android` `:app:assembleDebug` BUILD SUCCESSFUL · `examples/app-ios` `xcodebuild build` BUILD SUCCEEDED · failures: none (an earlier line of this section said "Swift UI 104": that was a sub-suite of the core bundle)

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Hand checks B9.1, B9.4, B9.8 on the iOS simulator and the Android emulator against the `navigation` app.
