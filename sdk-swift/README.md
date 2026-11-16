# Orca Gateway iOS SDK

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The native iOS client for Orca Gateway works for the pages its 25
> widgets and 15 action kinds cover, but its API may still change between alphas. For production
> apps use the Flutter SDK ([`orca_gateway`](https://github.com/orca-gateway/orca-gateway/tree/main/sdk)).

The SDK renders the same server-driven pages as the Flutter SDK, from the same Bun engine and the
same wire format ([`schema/`](https://github.com/orca-gateway/orca-gateway/tree/main/schema)).
Widget names on the wire stay Flutter's (`Column`, `Row`, `Text`); the SwiftUI layer maps them to
native views. A widget the SDK does not draw yet gets the server's fallback (left out, a notice, or
a blocking prompt, per the server's policy), never a crash.

The source lives in [`sdk-swift/` of orca-gateway/orca-gateway](https://github.com/orca-gateway/orca-gateway/tree/main/sdk-swift).
[orca-gateway-swift](https://github.com/orca-gateway/orca-gateway-swift) is a read-only copy for
Swift Package Manager, updated on each release; send issues and pull requests to the monorepo.

## Install

In Xcode: **File → Add Package Dependencies…**, paste
`https://github.com/orca-gateway/orca-gateway-swift.git`, set **Dependency Rule** to **Exact
Version** `0.1.0-alpha.1`, and add the `OrcaGateway` library to your app target. Swift Package
Manager picks an alpha only through an exact rule.

In a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/orca-gateway/orca-gateway-swift.git", exact: "0.1.0-alpha.1"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "OrcaGateway", package: "orca-gateway-swift"),
    ]),
]
```

Then make `OrcaApp` the root view. It loads the page at `path` from your Orca server and follows
the page's navigation; with no `path` it starts from the app's navigation config instead, as the
Flutter SDK does (see the router section below):

```swift
import OrcaGateway
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            OrcaApp(
                client: OrcaClient(baseURL: URL(string: "https://orca.example.com")!,
                                   appId: "counter", apiKey: "demo-key"),
                path: "home")
        }
    }
}
```

An app on the iOS simulator reaches a server on your Mac at `http://localhost:<port>`. A plain
`http` server on any other host needs an App Transport Security exception in the app's
`Info.plist`. The [iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios)
runs every app of the example server.

## Routes, app state and route changes

`OrcaRouter` can boot from the app's config (`GET /api/v1/app/:appId/config`) instead of a fixed
path. It seeds the config's `initialAppState`, then shows `initialRoute`; from then on every
location goes through the config's routes: a redirect rule is applied (once), a nested route
opened with `replace` is shown over its parent pages, and a location no route matches becomes a
route with `isNotFound` set, for which no page is requested.

```swift
let client = OrcaClient(baseURL: url, appId: "shop", apiKey: "demo-key")
let config = try await client.fetchConfig()
let router = OrcaRouter(client: client, config: config) { event in
    // Once per change of location, after any redirect. The first event has
    // no previousLocation; type is .push, .replace or .pop (a back swipe too).
    analytics.screen(event.location, from: event.previousLocation, type: event.type)
}

// Later, in a view:
OrcaApp(router: router)
```

`onRouteChanged` is also a property of the router, on a router made with a `path` too; a callback
set after `init` sees the changes that follow. The same location twice gives no event.

App state is one scope shared by every page. The host reads it as `router.appState` and writes it
with `setAppState`; the write reaches every page already loaded, so widgets watching the key
redraw, and it is sent with the next page request:

```swift
router.setAppState("loggedIn", true)
router.setAppState(["loggedIn": true, "userName": "Amr"])
let loggedIn = router.appState["loggedIn"]?.boolValue ?? false
```

A redirect rule reads app state when a navigation happens; writing the state does not move the
user, so navigate after a login (`router.navigate(to: "/home", replace: true)`).

`router.top` is the route on screen: `path` (the page request path), `location` (leading slash
and query), `isNotFound`, and `scaffoldTitle`, the fallback title of a route outside the tabs.
`OrcaApp(client: client)` boots from the config by itself (with a `path`, as in
`OrcaApp(client: client, path: "home")`, it opens that page and fetches no config);
`OrcaApp(router:)` draws a router made as above. Both show the "Page not found"
page and the title bar. A config with tabs runs as one stack.

## Deep links

`OrcaApp` receives the app's links itself: it attaches `.onOpenURL` (URL scheme links) and
`.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` (universal links), and goes to the
link's location, which is the URL's path and query. Scheme, host and fragment are ignored, an
empty path is `/` and a trailing slash is dropped: `https://shop.example/order/7?gift=1` and
`orcashop://open/order/7?gift=1` both open `/order/7?gift=1` (in `orcashop://order/7`, `order`
is the host, so the location is `/7`).

A link is a `navigate(to:replace: true)`: the stack and the tab come from the config, the
route's redirect rule applies (the asked query is dropped), and a location no route matches
shows "Page not found", which requests no page and has a "Go to home page" button that goes to
`/`. A link to the location already on screen navigates nothing.

A link that opens the app is where the app starts, instead of the config's `initialRoute`: one
that arrives during the version check or the config fetch is held until the router exists, and
the only page requested is the link's. That is exact when the app boots from the config. With a
`path` and no version check, or with `OrcaApp(router:)`, the first page shows at once; if iOS
delivers the launch URL after that, the link is handled as a link to a running app:
`isColdStart` is false and the first page was already requested. A host that needs it exact
makes the router with `link:` (below) and passes it to `OrcaApp(router:)`.

None of this needs a callback; to be told, pass `onDeeplink`:

```swift
OrcaApp(client: client, onDeeplink: { event in
    analytics.link(event.incoming, opened: event.resolvedLocation, cold: event.isColdStart)
})
```

It is called once per link, after the navigation and after `onRouteChanged`, with a
`DeeplinkEvent`:

| Field | What |
|---|---|
| `incoming` | the `URL` as the system delivered it |
| `resolvedLocation` | the final location, path and query: the link's, or the redirect rule's target |
| `pathParameters` | the matched route's path params, decoded; empty on "Page not found" |
| `queryParameters` | the final location's query, decoded |
| `wasRedirected` | a redirect rule sent the link to another path |
| `isColdStart` | the link opened the app: it came before the first route was on screen |

A host that receives links elsewhere (an app delegate, a push notification's payload) hands them
to the router, and sets the callback on it; with `OrcaApp(router:)` the view still delivers the
system's links to that router:

```swift
router.onDeeplink = { event in … }
router.handleDeeplink(url)                      // isColdStart: false
let router = OrcaRouter(client: client, config: config, link: launchURL)   // boots at the link
let router = OrcaRouter(client: client, path: "home", onDeeplink: { … }, link: launchURL)
```

A router made with `link:` reports it once, `isColdStart` set, and drops one repeat of that exact
URL while it is still on the location it booted at: under `OrcaApp(router:)` the system may
deliver the launch URL again, and that is not a second link. `OrcaAppBoot.handleDeeplink(_:)`,
for a host with its own root view, holds a link until the router exists (a cold start) and
treats every link to an existing router as a link to a running app.

The system only delivers links the app declares: a URL scheme under `CFBundleURLTypes` in the
app's `Info.plist` (Xcode: target, Info, URL Types), and for universal links the Associated
Domains capability (`applinks:shop.example`) with an `apple-app-site-association` file on that
domain. See Apple's
[custom URL scheme](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
and [universal links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
guides.

## Layout

| Target | What | Platforms |
|---|---|---|
| `OrcaGatewayCore` | Wire models (`ComponentNode`, `Value`, `Action`, `PageResponse`), `ValueResolver` (9 Value kinds, 31 transforms, 13 BoolExpr ops), `ElmStore` with page and app scopes, effects as data, the generated capability vector. Foundation only. | iOS 16+, macOS 13+, Linux |
| `OrcaGateway` | SwiftUI renderer, views and adapters (slice S2 onward). Re-exports the core. | iOS 16+, macOS 13+ |

Minimum: Swift tools 5.9 (Xcode 15+), iOS 16.

## Status by slice

| Slice | Content | State |
|---|---|---|
| S1 | Pure core: models, resolver, store, caps vector, Linux CI | done |
| S2 | `OrcaClient` with the 412 caps handshake, renderer, 15 core widgets, counter page | done |
| S3 | Action executor (15 kinds), navigation, system and server adapters, DevTools | done |
| S4 | Degrade policies and the 426 page, ten more widgets, `OrcaTheme` button styles | done |
| S5 | `0.1.0-alpha.1` on the read-only `orca-gateway-swift` mirror | this release |

## Styling buttons

A Flutter host styles an Orca page's buttons through its `ThemeData`. An iOS host does it with
`OrcaTheme`, one `OrcaButtonStyle` per button type:

```swift
OrcaApp(client: client, path: "home")
    .orcaTheme(OrcaTheme(elevatedButton: OrcaButtonStyle { configuration in
        configuration.label
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color.orange, in: Capsule())
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }))
```

The server wins: a button whose node carries its own style props (ElevatedButton
`backgroundColor`, `foregroundColor`, `borderRadius`, `padding`; OutlinedButton `color`,
`borderColor`; TextButton `color`) is drawn with those, not with the host style.

## Sessions, analytics and version check

`OrcaApp` takes two options, both off by default:

```swift
OrcaApp(client: client, path: "home", enableOffline: true, enableSessionTracking: true)
```

- `enableOffline` asks the server's `/version` before the first page. When the answer carries
  `forceUpdate: true`, the app shows "Update required. Please update the app." and loads no page.
  Any other answer, or none, lets it boot. The offline page cache and `preload()` come later.
- `enableSessionTracking` sends a session start to `/session` when the app comes to the foreground,
  and an end when it goes to the background. One that cannot reach the server is saved in
  `UserDefaults` and sent to `/session/offline` on the next foreground.

`OrcaApp(client:)` gives its client a device id when the client has none: a random id made on
first run, saved in `UserDefaults` and sent as `x-orca-device-id` on every request. `OrcaApp(router:)`
uses the router's client as you built it; set
`client.deviceId = DeviceIdentity.resolve(UserDefaultsKeyValueStore())` to send the same id.

`OrcaAnalytics` sends your own events. `OrcaApp` does not make one; build it from your client and
call `track`:

```swift
let analytics = OrcaAnalytics.forClient(client)
analytics.track("screen_view", payload: ["screen": .string("home")])
```

Events go to `POST /api/v1/app/<appId>/events` in batches of 20, or every 10 seconds while some
wait. A failed batch goes back in the buffer and is sent with the next one; past 500 buffered
events the oldest are dropped. `await analytics.dispose()` sends what is left. The events route is
an Orca Cloud route: the open-source engine answers it with 404, so there the events stay buffered.

`OrcaTelemetry.onEvent` receives the SDK's own events. There is one so far: `unknown_widget_type`
with `["type": "<widget type>"]`, sent the first time a page holds a widget type the SDK does not
draw (once per type per process).

```swift
OrcaTelemetry.onEvent = { name, payload in print(name, payload) }
```

## Plugins

A plugin brings widget types and custom actions the SDK does not have, as a Flutter `OrcaPlugin`
does. It is a type conforming to `OrcaPlugin`:

- `name`: shown in conflict messages.
- `widgets`: an `OrcaWidgetBuilder` per wire type. It gets the resolved node and the page model and
  returns an `AnyView`: it reads a prop with `node["label"]`, draws a child with
  `NodeView(id: node.childIds[0], model: model)` and fires a trigger with
  `model.fire("onTap", on: node, eventData: [...])`, which runs the node's action for it. Fire a
  tap from a `Button`: `onTapGesture` drops a touch held about a second, which Flutter still taps.
- `actions`: an `OrcaActionHandler` per action type. It gets the action as the server sent it
  (params as sibling keys, not resolved; `executor.resolve(value)` resolves one) and the executor.
- `triggers`: the triggers each widget type can fire. Metadata: nothing reads them at run time.

All but `name` default to empty. Pass plugins to `OrcaApp`, with `customActions` (handlers outside
any plugin) and `widgets` (a `WidgetBuilders` of your own widget types) if you have some:

```swift
struct BadgePlugin: OrcaPlugin {
    let name = "BadgePlugin"
    var widgets: [String: OrcaWidgetBuilder] {
        ["ColoredBadge": { node, model in
            AnyView(Button { _ = model.fire("onTap", on: node) } label: {
                Text(node["label"]?.stringValue ?? "")
            })
        }]
    }
    var actions: [String: OrcaActionHandler] {
        ["hapticFeedback": { action, _ in print("haptic", action["intensity"]) }]
    }
}

OrcaApp(client: client, path: "home", plugins: [BadgePlugin()],
        customActions: ["rateApp": { _, _ in /* open the store page */ }])
```

`OrcaApp(router:)` takes the same three options. They are merged once, before the first request,
with Flutter's rules: a widget type claimed twice (by two plugins, or by a plugin and the SDK or
`widgets`) or an action type claimed twice (by two plugins, or by a plugin and `customActions`) is
a conflict. A conflict shows the error view with Flutter's message, such as
`Widget type "ColoredBadge" from plugin "b" conflicts with plugin "a".`, and loads no page.

An action runs the handler registered under its type as sent, else the one under its type without
`custom:`, so a `hapticFeedback` handler runs both `hapticFeedback` and `custom:hapticFeedback`. A
handler named like a built-in action kind (`navigate`, `copyToClipboard`) replaces the built-in.

The client adds the plugins' widget types, and their action types (each bare and as
`custom:<name>`), to the capabilities it sends, so the server keeps the nodes that use them.
`customActions` and `widgets` are not advertised, as in Flutter. The
[iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios) registers
two plugins for the example server's `custom` app.

To start a plugin from a Flutter plugin's `orca_plugin.yaml`, the CLI writes a Swift stub (a props
type per widget, a params type per action, a placeholder builder and handler for each):

```bash
orca plugin generate --lang swift --manifest orca_plugin.yaml
```

See [`cli/README.md`](https://github.com/orca-gateway/orca-gateway/blob/main/cli/README.md).

## Tests

In a checkout of the monorepo:

```bash
task sdk-swift:test        # or: cd sdk-swift && swift test
```

The tests read the conformance fixtures from `../schema/fixtures/` at run time (render fixtures,
their `resolved` maps, action fixtures), the same files the engine and the Flutter SDK run, so
they only run inside the [monorepo](https://github.com/orca-gateway/orca-gateway). The mirror
carries `Tests/` as the split leaves it; Swift Package Manager never builds a dependency's tests.
CI runs them on Linux for every PR touching `sdk-swift/` or `schema/`, and on an iOS simulator for
the SwiftUI layer.

## Capabilities

`Sources/OrcaGatewayCore/Capabilities/Generated.swift` is generated; do not edit it. It lists the
widgets and action kinds named in [`capabilities.json`](capabilities.json) (each widget must carry
the `ios` target in the monorepo's
[`schema/widget-registry.json`](https://github.com/orca-gateway/orca-gateway/blob/main/schema/widget-registry.json))
plus every value kind, transform and BoolExpr op of the engine. Add a widget or action kind to
`capabilities.json` in the same PR that implements it, then regenerate from the monorepo root:

```bash
bun run schema/gen-native-capabilities.ts
```

## Versioning and releases

`VERSION` holds the SDK version and feeds `sdkSemver` in the capability vector, which the client
sends as `X-Orca-Sdk-Version`. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh),
never by hand. Its `sdk-swift-v<X>` tag starts the "SDK Swift Mirror" workflow, which copies
`sdk-swift/` to orca-gateway-swift with `git subtree split`, tags it `<X>` there and builds that
tag from a fresh package.

A server's minimum SDK version reads pre-releases in semver order: a minimum of `0.1.0` turns
`0.1.0-alpha.1` away with the update-required page.

## License

[Business Source License 1.1](LICENSE), as the rest of Orca Gateway.
