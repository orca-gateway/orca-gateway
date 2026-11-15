# Navigation fixtures

The executable spec for route resolution: given the `/config` body an app serves and an app state, where does
a location end up, which page is requested, and how is it shown. It sits beside `render/` (what a page
resolves to) and `actions/` (what an action does). Schema: [`../../navigation-fixture.schema.json`](../../navigation-fixture.schema.json).

## Flutter is the oracle

No value here is written from a design. The Flutter runner boots the real `OrcaApp` from the fixture's config,
calls `go(location)` on the real GoRouter built by `NavigationHandler.buildRouter`, and reads every expected
field back from the router and the widget tree. An expected value is whatever Flutter does (go_router 16.3.0,
the version in `sdk/pubspec.lock`). The Swift and Kotlin cores resolve the same files with their pure
`RouteTable` and must give the same values. When Flutter's behaviour changes, the fixture changes with it and
the native tables follow.

## Shape

```jsonc
{
  "name": "param-match",
  "description": "What this file pins, in a sentence or two.",
  "config": { /* a GET /api/v1/app/:appId/config body, as the engine serves it */ },
  "appState": { /* optional: laid over config.initialAppState, key by key */ },
  "cases": [
    {
      "name": "one param",
      "location": "/product/42",            // asked location, leading slash, query allowed
      "expected": {
        "kind": "page",                     // "page" | "error"
        "location": "/product/42",          // final location, after the redirect
        "redirected": false,                // final path differs from the asked path
        "pagePath": "product/42",           // page request path of the top page
        "routePath": "/product/:id",        // full matched pattern
        "params": { "id": "42" },           // path params of every matched level
        "stack": ["product/42"],            // page request paths, bottom to top
        "tabIndex": null,                   // index into config.tabs, or null
        "scaffoldTitle": null,              // fallback title when wrapped in a title bar, else null
        "appState": { }                     // optional: the whole app state at resolve time
      }
    }
  ]
}
```

In `config`, route paths have no leading slash and a child carries its full path (`home/product/:id`), as
`collectRouteInfo` emits them; `initialRoute`, tab `initialRoute`, drawer `route` and redirect `to` have one.
Kind `error` carries only `kind`, `location` and `redirected`. Kind `page` carries every field but `appState`.

One behaviour per file, several cases per file, numbered in reading order. Every case is independent: a fresh
app, the seed, the overlay, then one `go`.

## What the files pin

| File | Behaviour |
|---|---|
| `01_param_match` | `:name` segments, params, first match wins, the query stays out of the page path |
| `02_unknown_path` | no match: error, location unchanged, no page request |
| `03_tab_prefix_unreachable` | `homework` beside tab `/home`: in the config, in no tab, not top level |
| `04_redirect_logged_out` | a redirect rule that holds: the target, `redirected`, the asked query dropped |
| `05_redirect_logged_in` | the same config with the state overlaid: no rule holds |
| `06_redirect_applied_once` | the rule runs once per navigation: no chain, no loop error |
| `07_initial_app_state` | the seed, the overlay on top, rules reading both |
| `08_nested_children` | a child shows over its parent chain: `stack` |
| `09_tabs` | tab routes and their index, a tab with no route, a route outside the tabs |
| `10_scaffold_title` | the three fallback title rules; a child of a non-tab route is not wrapped |
| `11_no_tabs_no_scaffold` | without tabs nothing is wrapped |

Notes that are easy to miss:

- A `go` to a route outside the tabs replaces the stack: `stack` is that page alone and `tabIndex` is null.
- The redirect rule looked up is the first route, in flow order and parents before children, whose full
  pattern has as many segments as the location and matches it. The target's own rule is not applied.
- A config with tabs needs at least two of them (Flutter's default tab bar refuses one).
- With tabs, Flutter also writes the current tab into app state as `_tabIndex`; that is the shell's doing, not
  route resolution, so no case with tabs carries `expected.appState`. Sessions pin `_tabIndex` instead (below).

## Sessions

A case is one `go` on a fresh app. What the tab shell does over time (a tab keeps its stack, a reselect pops to
its root, `_tabIndex` follows and drives the tab) needs several steps on one app, so a file may carry `sessions`
beside `cases`, or alone:

```jsonc
"sessions": [
  {
    "name": "switch away and back",
    "boot": { "expected": { /* the app as booted at config.initialRoute, before any step */ } },
    "steps": [
      { "op": "push", "location": "/home/product/42",
        "expected": {
          "location": "/home/product/42",   // the visible location after the step
          "tabIndex": 0,                    // index into config.tabs, or null when no shell is shown
          "appState": { "_tabIndex": 0 },   // a subset: only the keys listed are compared
          "pageRequests": ["home/product/42"] // page paths requested during this step, in order; [] when none
        } }
    ]
  }
]
```

| Op | Fields | What the Flutter runner does |
|---|---|---|
| `go` | `location` | `go(location)` on the router |
| `push` | `location` | `push(location)` on the router |
| `back` | | `pop()` on the router |
| `tapTab` | `index` | taps that item of the default tab bar |
| `switchTab` | `tabId` | runs a `switchTab` action through the real action executor |
| `setAppState` | `key`, `value` | sets the key through the real state manager |

`boot.expected` and every step's `expected` carry the same four keys. As with cases, every value is recorded
from the real Flutter `OrcaApp`, here with a client that records the page requests. Steps of a session share one
app, in order; sessions are independent of each other.

| File | Behaviour |
|---|---|
| `12_tab_sessions` | switching away and back restores a tab's stack and fetches nothing; a reselect pops to the root; a tab is fetched on its first visit; `go` inside a tab keeps the pages it still needs |
| `13_tab_index_state` | `_tabIndex` follows taps, `go` and `switchTab`; setting it switches the tab; the same value or a non-int does nothing |
| `14_switch_tab` | `switchTab` lands on the tab's root and drops routes over the shell; an unknown id does nothing |

## Links

A link case is one URL handed to a fresh app, the way the platform hands over a deep link, and what the app
shows and reports once it has settled. A file that carries `links` carries nothing else beside its `config`.

```jsonc
"links": [
  {
    "name": "a param route outside the tabs",
    "link": "orcashop://open/order/7?gift=1", // the URL as the platform delivers it
    "coldStart": false,                       // true: the link opened the app
    "startAt": "/home",                       // warm only: what the app shows when the link arrives;
                                              // default config.initialRoute
    "appState": { "loggedIn": true },         // optional: laid over config.initialAppState before the boot
    "expected": {
      "kind": "page",                         // "page" | "error" (the not-found screen)
      "location": "/order/7?gift=1",          // final location: path and query
      "redirected": false,                    // final path differs from the link's location path
      "stack": ["order/7"],                   // as after a go; [] for kind error
      "tabIndex": null,                       // index into config.tabs, or null
      "pageRequests": ["order/7"],            // cold: every request since the start; warm: the ones the link adds
      "event": {                              // what the deep link callback receives; null: it is not called
        "resolvedLocation": "/order/7?gift=1",
        "pathParameters": { "id": "7" },
        "queryParameters": { "gift": "1" },
        "wasRedirected": false,
        "isColdStart": false
      }
    },
    "flutter": {                              // optional: where the Flutter SDK is known to differ
      "why": "q1 ... q5 ...",               // names the quirk (q1 to q6, below)
      "event": { "resolvedLocation": "orcashop://open/order/7?gift=1", "pathParameters": {} }
    }
  }
]
```

The location of a link is its path and its query, nothing else: scheme, host and fragment are dropped, an empty
path is `/`, a trailing slash is dropped. `https://shop.example/account?tab=2#x` and `app://host/account?tab=2`
are both `/account?tab=2`; `app://account` has host `account` and location `/`. The app goes to that location
as a `go`, so the stack and the tab come from the config and the asked route's redirect rule is applied once,
exactly as in the `cases` files. A cold link starts the app at the link's location: the initial route is never
shown or requested. The callback is called once, after the navigation and after the route change callback.

How the Flutter runner drives a link, on the real `OrcaApp` with `onDeeplink` set: cold, the link is the
platform's default route name before the app is pumped; warm, the app is brought to `startAt` and a
`pushRouteInformation` call is delivered on the `flutter/navigation` channel. Flutter keeps the whole URL as
its router location, so the runner reduces it to path and query before comparing `location`.

Native SDKs must match `expected` exactly and ignore `flutter`. The Flutter runner holds Flutter to `expected`
with the `flutter` values laid over it (`event` key by key, or `null`). An override is only written for one of
these documented quirks of the Flutter SDK, which the native SDKs do not copy:

| Quirk | What Flutter does | In the fixture |
|---|---|---|
| q1 | `pathParameters` is always empty | override on every link that ends on a param route |
| q2 | on iOS a cold launch reports `isColdStart: false` | not pinned: a widget test cannot be iOS's engine; the cold cases run the Android path |
| q3 | a link that arrives during boot, before the router exists, is dropped; `onDeeplink` then fires for the initial route with `wasRedirected: true, isColdStart: false` | not pinned: link cases boot from a ready config |
| q4 | only when the delivered string equals the location on screen character for character: no callback (and the next navigation is reported as that link) | `event: null` override on the bare-path case; a full URL to the same route does call back |
| q5 | `resolvedLocation` is the whole URL when the link is not redirected | override on every link that is not redirected |
| q6 | `wasRedirected` compares the raw path, so a trailing slash or an empty path reads as a redirect | `wasRedirected: true` override on the trailing-slash case and on the empty-path case |

In `expected`, `event.wasRedirected` compares the link's location path (normalised as above) with the final path,
so it always equals `redirected`: it is true only when a redirect rule ran.

| File | Behaviour |
|---|---|
| `15_deep_links` | a link's location; warm and cold; tab, nested child, param route; redirect while logged out; unknown link; a link to the location on screen |

## Running it

| SDK | Runner | Command |
|---|---|---|
| Flutter | `sdk/test/conformance/navigation_fixtures_test.dart` | `cd sdk && flutter test test/conformance/navigation_fixtures_test.dart` |
| Swift | the core's fixture tests: `RouteTable(config).resolve(location, appState)` per case, `TabShell(table)` per session step, the router's link entry per link | `cd sdk-swift && swift test` |
| Kotlin | the core's fixture tests, same calls | `cd sdk-kotlin && ./gradlew :core:test` |

Each runner walks up from its working directory to `schema/fixtures/navigation`, runs every file and every
case, session and link, and checks how many files it found (Flutter: at least fifteen, each well formed, one at
least with links) so an empty or missing directory fails the build.

## Adding a fixture

Write the config and the cases with your best guess of `expected`, run the Flutter runner, and keep what
Flutter reports. Then run the Swift and Kotlin runners: a difference there is a bug in the native route table,
not in the fixture.
