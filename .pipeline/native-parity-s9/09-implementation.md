# 09 · Implementation · native-parity-s9

## Front page

### In one breath
group 3 of 5 · tasks: 6 green, 0 blocked · cases: 21 of 31 legs green · Swift 248 · Kotlin 375
T5 Swift core: `RouteTable` resolves a location; all 11 fixtures (56 cases) pass.
T6 Kotlin core: the same `RouteTable`; the same 56 cases pass.
A cross-check aligned the two on corners no fixture pins, with one mirrored test on each side.

### New for you
nothing new

### Trade-offs
2 auto-decided: a path or query part with a bad escape is kept as raw text on both SDKs ·
`routePath` is built from the matched segments, not the raw config string.

### Questions for you
1. No task is blocked. (default: nothing to retry)
2. Next: group 4, both routers (config, app state, onRouteChanged)? (default: go)
3. Swift compares path text by Unicode canonical equivalence, Kotlin and Dart by code unit; a
   route in NFC asked in NFD matches on Swift only. Leave it as a known difference. (default: leave)

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

### Test run
`cd sdk-swift && swift test` · Executed 248 tests, with 0 failures · `cd sdk-kotlin && ./gradlew build` · BUILD SUCCESSFUL, core 243, sdk 132 · group 1: `bun test` 738 pass, `flutter test` +303 · failures: none

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Hand checks B9.1, B9.4, B9.8 on the iOS simulator and the Android emulator against the `navigation` app.
