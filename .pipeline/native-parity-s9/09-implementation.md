# 09 · Implementation · native-parity-s9

## Front page

### In one breath
group 1 of 5 · tasks: 2 green, 0 blocked · cases: 7 of 31 legs green · bun 738 · Flutter +303
T1 Navigation fixtures: 11 files, 56 cases, a schema and a README, all passing on Flutter's router.
T2 Demo app: `navigation` on the example server, with tabs, a redirect and a nested route.
Flutter applies a route's redirect rule once per navigation, not as a chain; the brief is corrected.

### New for you
nothing new

### Trade-offs
3 auto-decided: redirect applied once, as go_router 16.3.0 does · fixtures with tabs carry two
tabs (one tab crashes Flutter's default bar) · no JSON Schema validator added to the repo.

### Questions for you
1. No task is blocked. (default: nothing to retry)
2. Next: group 2, `NavConfig` and `fetchConfig` in both cores? (default: go)
3. Schema validation of the fixtures in CI needs a validator dependency: leave it out, as for the
   action fixtures. (default: leave out)

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

### Test run
`cd engine && bun test` · 738 pass, 0 fail · `cd sdk && flutter test` · +303 All tests passed · `flutter analyze` · No issues found · failures: none

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Hand checks B9.1, B9.4, B9.8 on the iOS simulator and the Android emulator against the `navigation` app.
