# Design brief · native-parity-s9 (plan step 9)

Stages 01-07 are skipped; this brief stands in for the design and the cases. Source of truth for behaviour:
the Flutter SDK (`sdk/lib/src/navigation/navigation_handler.dart`, `widgets/orca_app.dart`,
`widgets/orca_page.dart`, `models/page_response.dart`, `client/orca_client.dart` `fetchConfig`) and the engine
(`engine/src/core/app.ts` `getNavConfig`, `engine/src/core/flow.ts` `collectRouteInfo`).

## What Flutter does (checked 2026-11-15)

- `GET /api/v1/app/:appId/config` (no auth needed in the example server, device headers sent) returns
  `{appId, appName, initialRoute, tabs?, drawerItems?, initialAppState?, tabBarComponents?, drawerComponents?,
  flows: [{name, version?, isStatic?, pages?, routes: [{path, requiredAppState, isDynamic?, redirect?,
  transition?, children?}]}]}`. Route paths come without a leading slash (`home`), and a child carries its
  full path (`home/product/:id`). `NavConfig.fromJson` defaults: `initialRoute` `/`, lists empty.
- `OrcaApp._initRouter` seeds every `initialAppState` entry into app state before the router is built, so before
  the first page request.
- Routes of all flows are flattened in flow order. Matching (GoRouter): routes in order, first match wins; a
  pattern segment `:name` matches any one segment; a child is matched under its parent (parent prefix, then the
  rest), and a location that matches a child gives the page chain parent → child (`go('/home/product/3')` shows
  `home` under `home/product/3`). The page request path is the matched location without its leading slash and
  without the query (`_extractPagePath(state.matchedLocation)`); params reach the server through that path.
- With tabs: a route belongs to tab i when its path equals the tab's `initialRoute` or starts with it plus `/`
  (`_findTabRoutes`). Tab branches come first in match order, then the routes that are not tab routes. A route
  is a non-tab route only when its path starts with NO tab's `initialRoute` as a plain string prefix
  (`path.startsWith(prefix)`, no slash boundary), so `/homework` beside tab `/home` is in no branch and not top
  level: unreachable. A tab with no route of its own gets a synthetic route at its `initialRoute`.
- A non-tab route (only when the config has tabs) is wrapped in a Scaffold + AppBar. Title: the loaded page's
  `title`, else the fallback: the drawer item label whose `route` equals the path, else the last path segment
  capitalised (when the last segment is `:param` and there are two or more segments, the one before it).
  Children of a non-tab route are not wrapped (`scaffoldTitle` is not passed down).
- Redirect (GoRouter top-level `redirect`, runs for `go` and `push`): find the route for the matched location
  with `_findRouteByPath` (all routes in flow order, a node before its children, full-path patterns, equal
  segment counts); when it has `redirect {when, equals, to}` and `appState[when] == equals`, go to `to`. The
  rule is applied ONCE per navigation (go_router 16.3.0 `applyTopLegacyRedirect`: "executed at most once per
  navigation", corrected at group 1 from T1's run on the real router): the target's own rule is not evaluated,
  so a chain stops at its first target, a loop shows the second route, a route redirecting to itself shows
  itself with `redirected` false, and only an unknown target ends on the error screen. After a redirect the
  location, routePath, params and stack describe the target and the asked query is dropped.
  State changes do not re-run it: the user navigates again after logging in.
- Unknown location: GoRouter's default error screen ("Page Not Found"), the location stays the unknown one, no
  page request.
- `onLocationChanged(location, previous, type)` fires after the redirect resolved, once per changed location
  (same URI twice is dropped), `type` push / replace / pop, first call at boot with `previous == null` and
  type push. `navigate` action: `replace` true → `router.go(path)`, else `router.push(path)`.

## Contract: `schema/fixtures/navigation/`

A new fixture family beside `render/` and `actions/`, with `schema/navigation-fixture.schema.json` and a README.
One file per behaviour, numbered like the others:

    { "name", "description",
      "config": { ...a /config body... },
      "appState": { ...optional, laid over config.initialAppState... },
      "cases": [ { "name", "location": "/product/42",
                   "expected": { "kind": "page" | "error",
                                 "location": "/product/42",        // final location, after redirects
                                 "redirected": false,
                                 "pagePath": "product/42",          // page request path (kind page)
                                 "routePath": "/product/:id",       // matched pattern
                                 "params": { "id": "42" },
                                 "stack": ["product/42"],           // page paths bottom to top after a `go`
                                 "tabIndex": null,                  // index into config.tabs, or null
                                 "scaffoldTitle": null,             // fallback title when wrapped, else null
                                 "appState": { ... } } } ] }        // optional: app state seen at resolve time

Fixtures (at least): param match (B9.2), unknown path and the `/homework` unreachable case (B9.3), redirect on
app state both ways plus the applied-once cases (B9.4), initialAppState seeding with the overlay (B9.5), nested
children with the chain (B9.9), tabs with a non-tab route and its title rules (feeds B9.8 and step 10).
Flutter is the oracle: `sdk/test/conformance/navigation_fixtures_test.dart` drives the real
`NavigationHandler.buildRouter` / `OrcaApp(preloadedConfig:)` with a stub client and asserts every expected
field, so an expected value is whatever Flutter does. No change to Flutter's production code.

## Native cores (`sdk-swift/Sources/OrcaGatewayCore`, `sdk-kotlin/core`), pure, Linux-tested

- `NavConfig` model with `TabDef`, `DrawerItemDef`, `NavFlow` (name, version, isStatic, routes, pages kept as
  decoded page responses for Phase C offline), `NavRoute` (path, children, redirect, transition, isDynamic),
  `RedirectRule`, `RouteTransitionDef` (type, duration 300, curve easeInOut), the raw JSON and raw body kept.
- `OrcaClient.fetchConfig()`: GET `/api/v1/app/{appId}/config` with the device headers, HTTP errors as today.
- `RouteTable(config)`: `resolve(location, appState) -> RouteResolution` with the fields of `expected` above
  plus the matched route's `transition`; it applies the matched route's redirect rule once (no chain, no limit; see above). Passes every
  navigation fixture.
- `RouteChangeEvent { location, previousLocation, type: push | replace | pop }`.

## Native UI (`sdk-swift/Sources/OrcaGateway`, `sdk-kotlin/sdk`)

- `OrcaApp(client:path: nil)` boots from the config: loading → `fetchConfig` → seed `initialAppState` → resolve
  `initialRoute` → show it; a failed fetch shows the error view with a retry. `path` becomes optional and keeps its
  default `home` (corrected at group 5: a config boot by default broke three existing tests, so it would break
  hosts): `OrcaApp(client)` and a host path behave as today; `path: nil` / `path = null` boots from the config.
- `OrcaRouter` gains a config: `navigate` resolves through `RouteTable` (redirect applied, `replace` = GoRouter
  `go` with the page chain as root + stack, otherwise push); an unknown location shows a "Page not found" page
  and fetches nothing. Navigation stays on `NavigationStack` / `NavHost`.
- App state: `router.appState` readable, `router.setAppState(key, value)` (and a bulk form) writes it and
  commits into every loaded page so widgets watching the key redraw.
- `onRouteChanged: (RouteChangeEvent) -> Void` on router and `OrcaApp`: Flutter's rules above; a back swipe or
  system back is `pop`.
- A resolution with `scaffoldTitle` is drawn with a navigation bar: back button and the live page title
  (`page.title`, else the fallback). iOS: `navigationTitle` on the pushed page; Android: a `TopAppBar` with a
  back arrow.
- Tabs and the drawer are step 10: until then a config with tabs runs as one stack.

## Demo and docs

- `examples/server`: a `navigation` demo app: `initialRoute` not `home`, `initialAppState` (`loggedIn: false`),
  a `/product/:id` route, a nested child, a protected route with a redirect to `/login`, a login page that sets
  `loggedIn` and navigates on, tabs plus one non-tab route. Registered in `examples/server/index.ts`.
- `examples/app-ios` and `examples/app-android`: boot from the config when `ORCA_PATH` is not set.
- `sdk-swift/README.md`, `sdk-kotlin/README.md`: the new boot, app state and `onRouteChanged`.
- No capability names change in this step (no widget, no action kind).

## Cases (ids are the rows of phase-b-tests.md)

| Id | Given / When / Then | Level |
|---|---|---|
| B9.1 | Given a config with `initialRoute` `/welcome`, when the app boots with no host path, then `/config` is fetched once and the first page request is `welcome` | unit (Swift UI tests, Kotlin sdk tests) + hand |
| B9.2 | Given route `product/:id`, when resolving `/product/42`, then pagePath `product/42`, params `{id: 42}` | fixture (Flutter, Swift, Kotlin) |
| B9.3 | Given an unknown location, when resolving, then kind `error`, location unchanged, no page request | fixture |
| B9.4 | Given a redirect on `loggedIn == false`, when resolving the protected route logged out, then the login location and `redirected`; logged in, then the route itself | fixture + hand |
| B9.5 | Given `initialAppState`, when booting, then the state is seeded before the first page request and sent with it | fixture + unit |
| B9.6 | Given a loaded page watching an app key, when the host writes the key through the router, then the host reads it back and the page's store holds it | unit |
| B9.7 | Given a router with `onRouteChanged`, when booting, pushing, replacing and popping, then one event each with location, previous and type; the same location twice gives none | unit |
| B9.8 | Given a config with tabs and a non-tab route, when it is pushed, then it shows a bar with a back button and the page title, the fallback title before the page loads | ui + hand |
| B9.9 | Given a nested child route, when resolving its location, then the child matches and the stack is parent, child | fixture |
| B9.10 | Every file under `schema/fixtures/navigation` passes in the Flutter, Swift and Kotlin runners; file counts pinned as for the other families | fixture |

Hand checks (B9.1, B9.4, B9.8) run at stage 10 on the iOS simulator and the Android emulator.
