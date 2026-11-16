# Offline fixtures

The executable spec for the boot of an app with offline support: given what an earlier run saved and what the
server answers to `/version` and `/config`, which requests the boot makes, what it gives the app (a config, the
force update, or an error), what is saved afterwards, and which pages the page cache then serves without a
request. It sits beside `navigation/` (where a location goes once the app has its config). Schema:
[`../../offline-fixture.schema.json`](../../offline-fixture.schema.json). No wire change: the payloads are the
engine's `/version` (`getVersionInfo`) and `/config` (`getNavConfig`) as they are.

## Flutter is the oracle

No value here is written from a design. The Flutter runner seeds an in-memory `SharedPreferencesAsync` with the
case's `saved` keys, answers the two requests over `MockClient`, runs the real `OrcaApp.preload` with a real
`StaticFlowManager`, and reads every expected field back. An expected value is whatever Flutter does; where that
is a quirk kept on purpose, the case's description says so. The Swift and Kotlin cores run the same files and
must give the same values.

## Shape

```jsonc
{
  "name": "static-flow-boot",
  "description": "What this file pins.",
  "cases": [
    {
      "name": "stale: a flow version moved",
      "description": "C14.3. What the case pins, and why.",
      "saved": {                              // the store before the boot, by Flutter's key names; absent = not saved
        "orca_nav_config": { /* a /config body */ },
        "orca_flow_versions": { "main": 3 },
        "orca_pages_main": { "home": { /* a page as the engine renders it */ } }
      },
      "version": { "status": 200, "body": { "flows": { "main": 4 } } },   // or "fail": no network
      "config": { "status": 200, "body": { /* a /config body */ } },      // only when the boot asks for it
      "expected": {
        "requests": ["version", "config"],    // in order
        "result": { "config": { "main": 4 } }, // | "forceUpdate" | { "error": "<message>" } | { "error": { "status": 500 } }
        "saved": {                            // the store after: exactly these keys
          "orca_nav_config": "config",        // "config": the /config body text served | "saved": unchanged
          "orca_flow_versions": { "main": 4 },// exactly
          "orca_pages_main": ["about", "home"]// the set of paths saved for that flow
        },
        "serves": { "home": "home", "profile": null } // path -> pageId from the cache, or null
      }
    }
  ]
}
```

Every case is one cold start: a new cache over the store as `saved` leaves it, as after a restart.

- **The store.** Values are written in the fixture as JSON; the store holds their JSON text (Flutter's
  `jsonEncode`). The three key kinds are Flutter's: `orca_nav_config` (the raw `/config` body text),
  `orca_flow_versions` (`{flow: version}`) and `orca_pages_<flow>` (`{path: page}`).
- **The answers.** `body` is sent as its JSON text with `status`. `"fail"` is a request that never reaches the
  server. A `/config` request in a case with no `config` is a failure too, and shows up in `requests`.
- **The result.** `config` lists the flows of the config the app gets, each with its `version` (null when the
  entry has none); whether it is the saved or the fetched one follows from `requests`. An `error` string is the
  boot's own message, exact; `{status}` is the client's error for a `/config` answer with that status, passed
  through (Flutter: `OrcaClientException.statusCode`).
- **The store after.** Read once the boot's saves have landed (Flutter does not await them). Pages are compared
  by the set of paths, not their JSON, so no SDK has to re-encode a page byte for byte.
- **What the cache serves.** Only when the result is a config: the runner gives the cache the dynamic paths of
  that config's static flows (Flutter: `initDynamicPaths(config.flows)`), then asks it for each path as a page
  load does (route path, no leading slash, Flutter: `getCachedPage(path, config.flows)`). A pageId is a page
  opened with no request; null is a page that goes to the network.

## What the files pin

| File | Behaviour |
|---|---|
| `01_static_flow_boot` | the first online boot saves the config, the versions and the static pages; fresh versions use the saved config and request no `/config`; a moved version refetches and resaves the whole config; offline (any `/version` failure, an error status too) boots from the saved config, or fails with `No network and no cached config available`; force update wins; a refetch deletes the pages of a versioned flow that is gone, not of an unversioned one; dynamic routes and pages only inside the config are never served; an unversioned flow keeps the boot stale (Flutter's quirk); a failed `/config` on a stale boot is the boot's error, with no fallback to the saved config |

Notes that are easy to miss:

- `/version` lists every flow, an unversioned one as 0, but only flows that carry a `version` in `/config` are
  saved. A saved version that is missing differs from 0, so an app with an unversioned flow refetches `/config`
  on every launch.
- The cache serves from `orca_pages_<flow>` only, for the static flows of the config the boot gave; the pages
  inside a saved `/config` body are never read for that.
- A page fetched from the network is never saved: only the pages pre-rendered in `/config` are.

## Running it

| SDK | Runner | Command |
|---|---|---|
| Flutter | `sdk/test/conformance/offline_fixtures_test.dart` | `cd sdk && flutter test test/conformance/offline_fixtures_test.dart` |
| Swift | lands with native parity step 14, group 2 | |
| Kotlin | lands with native parity step 14, group 2 | |

The Flutter runner walks up from its working directory to `schema/fixtures/offline`, runs every case of every
file (a new file is picked up with no edit to the runner), and checks that the family is well formed and has at
least one case of each result (config, force update, error), so an empty or missing directory fails the build.

## Adding a case

Write the store, the answers and your best guess of `expected`, run the Flutter runner, and keep what Flutter
reports. Then run the Swift and Kotlin runners: a difference there is a bug in the native SDK, not in the
fixture.
