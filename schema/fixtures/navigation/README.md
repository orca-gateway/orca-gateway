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
  route resolution, so no fixture with tabs carries `expected.appState`.

## Running it

| SDK | Runner | Command |
|---|---|---|
| Flutter | `sdk/test/conformance/navigation_fixtures_test.dart` | `cd sdk && flutter test test/conformance/navigation_fixtures_test.dart` |
| Swift | the core's fixture tests, `RouteTable(config).resolve(location, appState)` per case | `cd sdk-swift && swift test` |
| Kotlin | the core's fixture tests, same call | `cd sdk-kotlin && ./gradlew :core:test` |

Each runner walks up from its working directory to `schema/fixtures/navigation`, runs every file and every
case, and checks how many files it found (Flutter: at least six, each well formed) so an empty or missing
directory fails the build.

## Adding a fixture

Write the config and the cases with your best guess of `expected`, run the Flutter runner, and keep what
Flutter reports. Then run the Swift and Kotlin runners: a difference there is a bug in the native route table,
not in the fixture.
