# Orca Gateway iOS SDK

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The native iOS client for Orca Gateway works for the pages its 93
> widgets and 28 action kinds cover, but its API may still change between alphas. For production
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

## Animation

What the animation step adds, in plain words:

- **Controlled animations.** An AnimatedBuilder that carries an `animationId` can be told to play by a
  button: the `animateForward` action starts it again from the beginning, `animateReverse` runs it back
  from where it is. A builder with `autoStart: false` waits for one of them. `onComplete` fires at the end
  of a forward run and of a reverse run, never for a repeating one. A tween may name the id of the
  animation it follows.
- **Implicit animations.** AnimatedContainer, AnimatedOpacity and AnimatedAlign glide to the new value
  when a prop changes (size, colour, padding, opacity, alignment), over the widget's `duration`. The first
  frame shows the value as is. All 41 of Flutter's curve names are understood, with Flutter's formulas; a
  missing or unknown name is `easeInOut`. This is also the default of AnimatedBuilder now (it was linear).
- **AnimatedSwitcher.** When its child is replaced by another node (a server action swaps it, or the
  page is fetched again), the old child fades out while the new one fades in. The same node with new
  props does not fade.
- **Hero.** On iOS 18 and later, tapping inside a Hero zooms the pushed page out of it, and back into it
  on return. The whole page zooms; it is not Flutter's flight of the one widget. On iOS 16 and 17, inside
  tabs, or with an empty tag, the child is drawn and the push is the plain one.
- **Route transitions.** A route's `fade` and `slideUp` are honoured: the pushed page's content fades in
  or rises from the bottom, with the route's duration and curve. It appears over the page background,
  not over the previous page, and going back is the system pop. Every other kind (`scale`, `slideRight`,
  `slide`, `none`) keeps the system push.
- **Reduced motion.** With "Reduce Motion" on in the system settings, every animation above jumps to its
  end state at once, `onComplete` still fires once, and route transitions fall back to the system push.

To see it all, run the `motion` app of the example server in the
[iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios), booted from its
config (`ORCA_APP_ID=motion ORCA_BOOT=config`): a menu with one page for the controlled animation, one
for the three implicit widgets, one for the switcher, a Hero pair, and one page per transition kind at
600 ms.

## Reorderable list

A ReorderableListView draws its children as the rows of a list; a long press on a row picks it up, no
edit mode and no handles.

- **What fires.** Dropping a row somewhere else runs the list's `onReorder` action with
  `{oldIndex, newIndex}`, read through `V.event`. Dropping it back where it was runs nothing.
- **The raw `newIndex`.** `newIndex` is Flutter's value: the position to insert at, counted before the
  dragged row is taken out. The first of three rows dropped at the end gives 3 (not 2), dropped below
  the second gives 2; the last row dropped at the top gives 0. Moving a row down, the action subtracts
  one before inserting. `ReorderDrop` in the core holds the rule.
- **The order comes from the page.** The list never moves a row itself. After the drop it draws the
  children the page has, so the row goes back unless the action changes the order (page state, or a
  server action that sends the new children).
- **Padding.** `padding` is drawn inside the rows: its left and right in every row, its top in the
  first and its bottom in the last, so it scrolls with them.
- **Horizontal.** With `scrollDirection: "horizontal"` the children are drawn in a scrolling row that
  cannot be reordered: SwiftUI drags rows in a vertical list only.
- **Scroll triggers.** `onScrollBegin`, `onScrolling` and `onScrollEnd` fire as on a
  SingleChildScrollView. The vertical list fires them on iOS 18 and later only; the horizontal row on
  every supported version.

To see it, run the `reorder` app of the example server in the
[iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios), booted from its
config (`ORCA_APP_ID=reorder ORCA_BOOT=config`): a list whose order lives in page state, moved by
`onReorder`.

## Sub-pages

A SubPage draws another page inside the page. The SDK fetches it when the SubPage comes on screen,
draws the SubPage's child (or a spinner) until the first answer, and `SubPage error: <message>` when
that fetch fails.

- **The prefix rule.** The embedded page is not a page of its own: its nodes go into the host page's
  node store and its state into the host's page state, each id and each page-state key with a prefix
  in front. For a SubPage with key `detail` the first page gets `detail:` (node `0` becomes
  `detail:0`, state `count` becomes `detail:count`), and each joined page gets `detail#1:`,
  `detail#2:` and so on. Every reference and action inside the embedded page is rewritten the same
  way when it is mounted, so the page reads and writes its own `count` and never the host's; app
  state is shared and left alone. A SubPage inside a sub-page composes (`outer:inner:`). The rules
  are the core's `SubPage` and `SubPageRegistry`, pinned by the monorepo's
  [`schema/fixtures/subpage`](https://github.com/orca-gateway/orca-gateway/tree/main/schema/fixtures/subpage).
- **Params are the query.** The fetch is the normal page route for the resolved `pageId`, with the
  resolved `params` as its query string (keys sorted, percent-encoded, null left out): the page
  reads them as `V.request("queryParams.userId")`. When the resolved `pageId` or `params` change,
  the page is fetched again and replaces what is mounted.
- **Replace and join.** `updateSubPage` fetches another page into a SubPage on screen; the old
  content stays until the answer comes, and a failed fetch leaves it and fails the action (a
  lifecycle's `onError` runs). `replace`, the default, removes the mounted pages with their state
  and mounts the new one; `join` adds it below the others, each page with its own state. The change
  stays through redraws. A `subPageId` that names no SubPage on screen does nothing.
- **Server actions inside.** A `serverAction` fired from a node of a sub-page posts that page's
  state alone, under the keys the page declared (no prefix), and the actions the server returns are
  rewritten with the prefix before they run: a returned `setState` or component mutation lands in
  the sub-page. The server code is the same as for a page shown on its own.
- **Leaving.** When the SubPage node goes away its nodes are removed; its state keys stay until a
  SubPage with the same key loads again.
- **Limits.** A SubPage key may not hold `:` or `#` (the engine refuses it). A plugin action's own
  literal fields that name a state key or a node are not rewritten: inside a sub-page, pass the key
  as a state Value.

To see it, run the `subpage` app of the example server in the
[iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios), booted from its
config (`ORCA_APP_ID=subpage ORCA_BOOT=config`): a host count beside a sub-page's own count, a param
sent to the sub-page, and two buttons, Replace with B and Join C.

## Sliver scrolling

A CustomScrollView is one lazy scroll view. Its slivers are laid one after the other in it: a
SliverList's children and a SliverToBoxAdapter's child as rows as wide as the view, a SliverGrid as
rows of cells with GridView's sizes and spacings, and a SliverAppBar. Only the rows near the screen
are built. `scrollDirection`, `reverse`, `shrinkWrap` and the triggers `onScrollBegin`,
`onScrolling` and `onScrollEnd` work as on a ListView.

- **The bar is drawn by the SDK**, not by the navigation bar: `backgroundColor`, `flexibleSpace`
  as wide as the bar, up to its height, behind a toolbar row 56 high with `leading`, `title`
  (`centerTitle`) and `action_0` to `action_9`. It follows the scroll with Flutter's numbers: it shrinks from
  `expandedHeight` and scrolls away, stops at `collapsedHeight` (else 56) when `pinned`, and
  comes back on any scroll toward the start when `floating`. The toolbar row fades as it leaves.
  Under the status bar the bar reaches the top of the screen and is taller by that inset.
- **Where the bar collapses.** Only as the first sliver of a vertical view that is not reversed.
  Anywhere else (not first, a horizontal or reversed view, outside a CustomScrollView) it is a box
  as tall as `expandedHeight` that scrolls with the content, whatever `pinned`, `floating` and
  `snap` say. With `shrinkWrap` it collapses but stays below the status bar.
- **Snap.** With `floating` and `snap` the bar opens or closes fully when a scroll ends, over
  300 ms. On iOS 18 and later that is the moment the scroll stops; on iOS 16 and 17 it is 0.15 s
  after the view last moved.
- **Scrolling by code.** A floating bar also comes back when the view is scrolled toward its start
  by code; Flutter brings it back on a drag only.
- **Elevation.** `elevation` draws no shadow: a SliverAppBar carries no `shadowColor`, as Flutter's
  Material 3 bar draws none.
- **Scroll metrics.** `maxExtent` in the scroll triggers is exact when every row has one length and
  an estimate otherwise: SwiftUI learns a lazy stack's length from the rows it has built.
- **Outside a CustomScrollView** (Flutter throws) a SliverList draws its children one below the
  other, a SliverGrid all its cells, a SliverToBoxAdapter its child. A widget that is no sliver,
  directly in a CustomScrollView, is drawn as a row.

To see it, run the `slivers` app of the example server in the
[iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios), booted from its
config (`ORCA_APP_ID=slivers ORCA_BOOT=config`): three tabs, a pinned bar over a coloured
`flexibleSpace`, a floating bar and a plain one.

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
  With a `path`, as here, that is all it does: any other answer, or none, lets it boot. Booting from
  the config (no `path`), it also keeps the app working offline; see "Offline" below.
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

## DevTools

Off until you start it. Start it once, before the first page, for example in your `App`'s `init`:

```swift
init() {
    #if DEBUG
    OrcaDebug.start(OrcaDebugConfig(
        enabled: true,
        host: "localhost",      // on a device: the Mac running DevTools
        appName: "My Shop",
        showOverlay: true,
        includeBodies: true))
    #endif
}
```

The SDK then sends Orca DevTools (`ws://<host>:6363`, `port` changes it) its network requests, page
timing, state changes, actions, rebuilds and errors, and reconnects when DevTools restarts (up to
10 tries in a row). A second `start` replaces the connection; `OrcaDebug.stop()` ends it and puts
the options below back to their defaults. The simulator reaches DevTools at `localhost`.

The five options of Flutter's `OrcaDebugConfig`, with its defaults:

| Option | Default | What it does |
|---|---|---|
| `showOverlay` | `false` | A chip 8 points in from the bottom right of each page with its load time (request start to render complete). A tap shows `Load`, `Components` (the page's node count) and `Cache` (`-`); the next folds it. |
| `logTimings` | `false` | Also writes `[OrcaDebug] Timing: <pageId> - <path>` to the system log for each page's `timing` event (subsystem `com.orcagateway`, category `OrcaDebug`). |
| `captureStateChanges` | `true` | Off: no `state_change` events. |
| `captureNetworkRequests` | `true` | Off: no `network` events. A failed request still sends its `error` event. |
| `includeBodies` | `false` | `network` events carry `requestBody` (for a page request, the app state it sent) and `responseBody` (the response's JSON, else its raw text). |

Actions, rebuilds, page timing and errors are always sent while DevTools is on; no option turns them
off. Bodies can hold tokens and personal data, so `includeBodies` stays off unless you ask for it.
With or without bodies, the `authorization`, `cookie`, `set-cookie`, `x-api-key` and
`proxy-authorization` headers are sent as `<redacted>`.

DevTools also shows how a value was worked out:

- A widget that watches state sends a `widget_rebuild` each time it is built, the first time
  included, with the trace of each prop: `state` (the key read and its value), `input` (a
  transform's input), then one step per transform with what went in and what came out. A prop
  with no step (a static value) is left out, and a widget with none sends nothing. In DevTools: an
  action's Widgets tab, then a widget, "Prop pipelines".
- A `setState` whose value is a transform carries that value's trace (the action's Transform tab)
  and the page's widgets that watch the key (its Widgets tab).
- A `debugLog` action shows as an action of family `custom`, and its line goes to the system log
  (subsystem `com.orcagateway`, category the action's tag).

The [iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios) starts
it in debug builds and turns the overlay and bodies on from two switches.

## App shell: host views, theme, locale, errors and timeout

`OrcaApp` draws a few screens of its own around the pages: a spinner while it boots, an error
screen when the config or a page cannot be fetched, and the force-update screen. Each boot screen
can be your own, `colorScheme` and `locale` reach everything `OrcaApp` draws, and the client's
`timeout` bounds every request:

```swift
OrcaApp(
    client: OrcaClient(baseURL: url, appId: "shop", apiKey: "demo-key", timeout: 10),
    enableOffline: true,
    splashView: { AnyView(SplashScreen()) },
    errorView: { error in AnyView(Text(OrcaErrorInfo(error).title)) },
    forceUpdateView: { AnyView(UpdateScreen()) },
    colorScheme: .dark,
    locale: Locale(identifier: "fr-FR"))
```

- `splashView` shows while the version check runs (`enableOffline`) and while the navigation config
  is asked for (Flutter's `splashWidget`). `loadingView` (Flutter's `loadingWidget`) shows in the
  same places when there is no `splashView`; with neither, the SDK's spinner.
- `errorView` gets the error when the config cannot be fetched or the plugins conflict, and is
  drawn alone, with no retry (Flutter's `errorBuilder`). Without it, `OrcaErrorView`.
- `forceUpdateView` replaces "Update required. Please update the app." (Flutter's
  `forceUpdateBuilder`).

The four are boot screens, as in Flutter. With a `path` no config is fetched, and a page keeps the
SDK's spinner while it loads and `OrcaErrorView`, with its "Try again" button, when it fails.
`OrcaApp(router:)` takes the same options.

`colorScheme` (`.dark` or `.light`; nil, the default, follows the system) and `locale` (nil: the
environment's) are set in the environment of everything under `OrcaApp`: its screens, your views
and the pages. They do not turn the whole window, as `preferredColorScheme` would. A page's
Scaffold stays light whatever the scheme, as Flutter's builders draw it in the default light theme,
so dark mode shows on the SDK's screens and your own views, not inside a server page. The
`x-orca-locale` header stays the device's locale, as in Flutter.

**Error screens.** `OrcaErrorView(error:retry:)` is Flutter's `buildOrcaError`: an icon, a title
and a message, centred, and a "Try again" button when it has a `retry` (a native extra). `OrcaApp`
shows it for a page or a config that failed; you can show it too. `OrcaErrorInfo(error)` gives its
`kind`, `title` and `message` for a screen of your own. Titles and messages are Flutter's:

| Error | `kind` | Title |
|---|---|---|
| HTTP 401 | `.unauthorized` | Unauthorized |
| HTTP 403 | `.forbidden` | Forbidden |
| HTTP 404 | `.notFound` | Not Found |
| HTTP 429 | `.tooManyRequests` | Too Many Requests |
| HTTP 500 and up | `.server` | Server Error |
| Any other HTTP status | `.status` | Error, with `Failed to fetch page: <status>` (a server action: its own message) |
| A body that does not decode, a bad URL | `.configuration` | Configuration Error |
| No network, no host, no connection, a timeout | `.connection` | Connection Failed |
| Anything else | `.unknown` | Something Went Wrong |

One native difference: "Failed to fetch page" also stands for the config and the version check,
which Flutter names.

**Timeout.** `OrcaClient(timeout:)`, 30 seconds by default, bounds each request from send to answer;
a slower one fails with `URLError(.timedOut)`, shown as Connection Failed, as Flutter's `OrcaClient`
`timeout` does. A custom `transport` must honour task cancellation, or the timeout waits for its
answer.

The [iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios) has a
switch for each of these, with the commands to see the error screens, dark mode and a host splash.

## Offline

With `enableOffline` and no `path`, `OrcaApp` keeps the app working with no network, by the
Flutter SDK's rules:

- The server pre-renders the pages of a static flow (`isStatic` on the flow), dynamic routes aside,
  into `/config`. The app saves them at boot with the config and the flow versions, in Application
  Support/<bundle id>/OrcaGateway (`FileKeyValueStore.applicationSupport()`). Any of those pages,
  visited or not, then opens with no request, also offline and after a restart.
- Each start asks `/version`. When every flow's version equals the saved one, the saved config is
  used and `/config` is not asked for. When one moved (or is new), the whole `/config` is fetched
  and saved again, and the saved pages of a versioned flow that is gone from it are deleted.
- Offline is any `/version` failure: no network, the server down, an error answer. The app then
  boots from the saved config. With none saved (no online start yet), it shows Flutter's screen
  for it, "Something Went Wrong" and "An unexpected error occurred. Please try again.", with "Try
  again", which runs the boot again. An `errorView` gets the error itself, an `OfflineBootError`.
- Dynamic routes (`isDynamic`) and pages outside static flows are never cached: they always go to
  the network, so offline they show the page's error. A page from the network is never saved.
- A flow with no version (0 on the server) gets no saved version, so `/version` finds it moved on
  every start and `/config` is fetched every time, as in Flutter.

The boot can run in your own splash instead (Dart `OrcaApp.preload`). `preload(client:cache:)`
does the steps above and returns `.success(config)` or `.forceUpdate`; offline with nothing saved
it throws `OfflineBootError`, whose text is "No network and no cached config available". Give
`OrcaApp` that config and the same cache: it asks for nothing and its first frame is the first
page. Over `FileKeyValueStore.applicationSupport()` the cache is the one `enableOffline` uses.

```swift
let cache = StaticFlowManager(store: FileKeyValueStore.applicationSupport())
let result = try await preload(client: client, cache: cache)
// .forceUpdate: show your own force-update screen; OrcaApp never sees it.
if case .success(let config) = result {
    OrcaApp(client: client, preloadedConfig: config, staticFlowManager: cache)
}
```

The [iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios) does
this behind `ORCA_PRELOAD` (`HostPreload` in `OrcaCounterApp.swift`).

## Saved state

Two actions keep a state key when its page or the app goes away, as in the Flutter SDK:
`persistState` saves the key's value and `clearState` forgets it. The engine builds them with
`PersistState(key, scope = "page", storage = "local")` and `ClearState(key, scope = "page")`;
`scope` is `page` or `app`.

- **A snapshot.** `persistState` saves the key's value at that moment, null included, from the
  page the action runs in (or from app state). A later `setState` does not change the saved copy;
  run `persistState` again to save the new value. A key the scope does not hold saves nothing.
- **Local or session.** `local` survives a restart. `session` stays in memory while the app's
  process runs: it outlives leaving a page and opening it again, not a relaunch. A key has one
  saved copy: saving it in one storage deletes the copy in the other.
- **Forget.** `clearState` empties the live key (it reads as null) and deletes both saved copies.
- **Where.** `local` is one small JSON file per scope, `orca_saved_app` for app state and
  `orca_saved_page_<pageId>` for a page, in Application Support/<bundle id>/OrcaGateway
  (`FileKeyValueStore.applicationSupport()`), beside the offline cache's files. A file left with
  no key is deleted. A file that cannot be read or written is ignored, and the action still
  completes.
- **When it comes back.** A saved key replaces the declared initial value, or is added when the
  page does not declare it. App state: at boot, laid over the config's `initialAppState` (over an
  empty app state with a `path`) before the first route is resolved, so redirect rules and the
  first page request see the saved values. A page: each time its state is set up, right after the
  seed from its state definitions, so on every open (from the network or the offline cache) and
  when it is fetched again and seeded anew. The page never shows its initials first. A page's
  app-scoped definitions only fill an empty key, so a restored app key stays.
- **Sub-pages.** A sub-page has no saved entry of its own: its state lives in the host page's
  state, under its prefix (see "Sub-pages" above).
- **Flutter.** The rules and the entry names are Flutter's, pinned by the monorepo's action
  fixtures 48 to 50 in
  [`schema/fixtures/actions`](https://github.com/orca-gateway/orca-gateway/tree/main/schema/fixtures/actions).
  Flutter keeps `local` in SharedPreferences instead of files.

`OrcaApp` keeps one `SavedState` for its whole life. Pass your own as `savedState:`; nil, the
default, is one over the file store the offline cache uses. A router you make for
`OrcaApp(router:)` takes `savedState:` too, but there nil saves and restores nothing: pass one to
save as `OrcaApp` does.

```swift
// What OrcaApp makes when given nil.
let router = OrcaRouter(client: client, config: config,
                        savedState: SavedState(local: FileKeyValueStore.applicationSupport()))

// Local entries in memory only: nothing is written, nothing outlives the process.
OrcaApp(client: client, path: "home", savedState: SavedState(local: nil))
```

Session entries are shared by the whole process. `SavedState.resetSession()` empties them, for
example when a user signs out; `SavedState.sessionEntries` reads them.

To see it, run the `saved-state` app of the example server in the
[iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios)
(`ORCA_APP_ID=saved-state ORCA_PATH=home`, or `ORCA_BOOT=config`): a count to save on the device or
for the session and to forget, and a visits count in app state.

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
