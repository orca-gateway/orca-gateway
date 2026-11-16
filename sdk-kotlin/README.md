# Orca Gateway Android SDK (`sdk-kotlin`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The native Android client for Orca Gateway (Epic 23b) works for the
> pages its 32 widgets and 20 action kinds cover, but its API may still change between alphas, so
> use it with care. The Flutter SDK
> ([`orca_gateway`](https://github.com/orca-gateway/orca-gateway/tree/main/sdk)) stays the stable
> one; use it for production apps.

The SDK renders the same server-driven pages as the Flutter and iOS SDKs, from the same Bun engine
and the same wire format ([`schema/`](https://github.com/orca-gateway/orca-gateway/tree/main/schema)).
Widget names on the wire stay Flutter's (`Column`, `Row`, `Text`); the Compose layer maps them to
Material 3.

## Install

The SDK is on Maven Central. Your build needs Google's repository and Maven Central, for example in
`settings.gradle.kts`:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
```

Then add the SDK to your app module's `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.orcagateway:sdk:0.1.0-alpha.1")
}
```

The app needs `minSdk = 24` or higher and Compose turned on (the Kotlin Compose compiler plugin,
`buildFeatures { compose = true }`, and `androidx.activity:activity-compose` for `setContent`). The
[example's build file](https://github.com/orca-gateway/orca-gateway/blob/main/examples/app-android/app/build.gradle.kts)
is a working setup. The SDK's manifest adds the `INTERNET` permission for you.

Then make `OrcaApp` the activity's content. It loads the page at `path` from your Orca server and
follows the page's navigation, the system back gesture included. Without a `path`, `OrcaApp(client)`
boots from the server's navigation config instead (see "Navigation from the server config"):

```kotlin
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.client.OkHttpTransport
import java.net.URI

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val client = OrcaClient(
            baseUrl = URI("https://orca.example.com"),
            appId = "counter",
            apiKey = "demo-key",
            transport = OkHttpTransport(),
        )
        setContent { OrcaApp(client, path = "home") }
    }
}
```

`OrcaClient` lives in `sdk-core`, which `sdk` brings along. An app on the emulator reaches a server
on your computer at `http://10.0.2.2:<port>`. Plain `http` works only where the app allows
cleartext traffic; the [Android example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-android)
allows it in debug builds only, and runs every app of the example server.

For the core alone on the JVM (wire models, `ValueResolver`, `ElmStore`, `OrcaClient`), without
Android or Compose, Maven Central is enough:

```kotlin
dependencies {
    implementation("com.orcagateway:sdk-core:0.1.0-alpha.1")
}
```

It needs JDK 17 or later and brings no HTTP library: `OrcaClient` sends through any
`HttpTransport` you give it (`OkHttpTransport` in `sdk` is one).

## Layout

| Module | What | Platforms |
|---|---|---|
| `core` | Wire models (`ComponentNode`, `Value`, `Action`, `PageResponse`), `ValueResolver` (9 Value kinds, 31 transforms, 13 BoolExpr ops), `ElmStore` with page and app scopes, the action executor with effects as data, the render tree, `OrcaClient` with the 412 caps handshake behind an `HttpTransport` interface, the generated capability vector, DevTools events (`DevToolsEvent`, `OrcaDebug`). kotlinx.serialization only. Artifact `com.orcagateway:sdk-core`. | JVM 17+, Android |
| `sdk` | The OkHttp transport, `DeviceInfo.current(context)`, the Compose renderer with 32 widgets (those in [`capabilities.json`](capabilities.json)) and the degrade policies (an unknown widget becomes a FallbackPrompt; the server's `warn` banner, its `require` blocking prompt and the 426 upgrade page are drawn like any page), `OrcaTheme` button styles, `OrcaApp` on `OrcaRouter` (a `NavHost`) with its error screen (`OrcaErrorView`), `SystemActions`, the DevTools client. Artifact `com.orcagateway:sdk`. | Android 7.0+ (minSdk 24) |

Build: Gradle 9 through the committed wrapper, Kotlin 2.4, AGP 9, any JDK 17 or later, and an
Android SDK with platform 36 (`ANDROID_HOME` or `local.properties`).

## Status by slice

| Slice | Content | State |
|---|---|---|
| S6 | Pure core: models, resolver, store, executor, caps vector, Linux CI | done |
| S7 | `OrcaClient` with the 412 caps handshake, the `sdk` module: Compose renderer, 15 core widgets, `OrcaApp`; the counter app in [`examples/app-android`](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-android) | done |
| S8 | Navigation with `OrcaRouter` on a `NavHost` and the system back gesture; system actions through `SystemActions.android(context)` (open URL, clipboard, share); DevTools events, sent by `OrcaDebug.start(OrcaDebugConfig(...))`; the example app runs `basic-actions`, `server-actions` and DevTools | done |
| S9 | Degrade policies and the drawn 426 page, ten more widgets (Icon, Image, Container, Expanded, Spacer, TextField, Stack, Positioned, ClipRRect, GestureDetector), `OrcaTheme` button styles | done |
| S10 | `0.1.0-alpha.1` on Maven Central as `com.orcagateway:sdk-core` and `com.orcagateway:sdk`; `sdk-kotlin` in `scripts/release.sh`; the tag-triggered "SDK Kotlin Publish" workflow | this package |

## Navigation from the server config

`OrcaRouter` can start from the app's `/config` instead of a fixed path. The config names the
first route, the app state to start with, and every route of the app:

```kotlin
val config = client.fetchConfig() // suspend: GET /api/v1/app/{appId}/config
val router = OrcaRouter(client, config, onRouteChanged = { event ->
    // event.location, event.previousLocation (null for the first one), event.type: Push, Replace, Pop
    analytics.screen(event.location)
})
setContent { OrcaApp(router) }
```

- The router starts at `config.initialRoute`, with `config.initialAppState` already in app state,
  so the first page request carries it.
- `router.navigate("/product/42")` resolves the location through the config's routes (`RouteTable`
  in the core). A route's redirect rule (`when` an app state key `equals` a value, go `to`) is
  applied once, against the app state of that moment. `navigate(location, replace = true)` shows a
  nested route with its parent pages under it; without `replace` one page is pushed.
- A location no route matches becomes a route with `isNotFound`, and no page is requested for it.
  Each `OrcaRoute` also carries its `location`, and from the config its `scaffoldTitle` and
  `transition`.
- `router.appState` reads the shared app state. `router.setAppState("loggedIn", JsonValue.Bool(true))`
  (or a map of several keys) writes it into every loaded page, so widgets that watch the key
  redraw. Writing state does not navigate: call `navigate` again after a login.
- `onRouteChanged` fires once each time the location on top changes, after the redirect: `Push`
  for `navigate`, `Replace` with `replace = true`, `Pop` for `goBack()` and the system back
  gesture. Showing the location that is already on top reports nothing. It can also be set later
  (`router.onRouteChanged = ...`), and works on a router built from a path.

`OrcaApp(client)`, with no path, fetches the config itself and boots from it, as the Flutter SDK
does: the config's `initialRoute` and `initialAppState`, its routes, the "Page not found" screen,
the title bar and the tabs. `OrcaRouter(client, path = "home")` and `OrcaApp(client, path = "home")`
open that one page: no config, every path is a page.

## Deep links

`OrcaApp` opens links by itself, inside a `ComponentActivity`:

- The link of the Intent that launched the activity (the data of an `ACTION_VIEW`) opens the app
  at the link: the router starts there instead of the config's `initialRoute` (or of `path`), with
  `initialAppState` seeded and the route's redirect applied, and only that page is requested. It
  is read once, not again after a rotation or a restore from saved state.
- The link of every new Intent goes there while the app runs, also one that arrives while the
  config is still being fetched (it is held, and then opens the app).

A link's location is the URL's path and query; scheme, host and fragment are ignored
(`https://shop.example/product/42?tab=specs` and `myapp://open/product/42?tab=specs` both go to
`/product/42?tab=specs`). It is shown as `navigate(location, replace = true)` shows it: the tab
and the parent pages come from the config. A link no route matches shows "Page not found", whose
"Go to home page" button goes to `/`. A link to the location already on screen navigates nowhere.

```kotlin
OrcaApp(client, onDeeplink = { event ->
    // event.incoming            the link as delivered
    // event.resolvedLocation    where it ended, after the redirect: path and query
    // event.pathParameters      of the matched route ("id" to "42")
    // event.queryParameters     of the final location
    // event.wasRedirected       a redirect rule sent it elsewhere (a protected route, logged out)
    // event.isColdStart         the link is what opened the app
    analytics.link(event.resolvedLocation)
})
```

`onDeeplink` is called once per link, after the navigation and after `onRouteChanged`; links
navigate without it too. With `OrcaApp(router)`, set `router.onDeeplink`.

The manifest needs an intent filter for your links, and `singleTop` so a link reaches the running
activity as a new Intent instead of starting a second one:

```xml
<activity android:name=".MainActivity" android:exported="true" android:launchMode="singleTop">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="myapp" android:host="open" />
    </intent-filter>
</activity>
```

A host that receives links elsewhere (a push notification, its own `onNewIntent`) hands them to
the router: `router.handleDeeplink(url)` (pass `isColdStart = true` when the link opened the app),
or `router.handleIntent(intent)`, which returns false when the Intent carries no link. Before the
router exists, `OrcaAppBoot.handleDeeplink(url)` holds the link for it.

## Styling buttons

A Flutter host styles an Orca page's buttons through its `ThemeData`. An Android host does it with
`OrcaTheme`, one `OrcaButtonStyle` per button type, provided once above `OrcaApp` through
`LocalOrcaTheme`; it reaches every page, pushed ones too:

```kotlin
import com.orcagateway.sdk.style.LocalOrcaTheme
import com.orcagateway.sdk.style.OrcaButtonStyle
import com.orcagateway.sdk.style.OrcaTheme

CompositionLocalProvider(
    LocalOrcaTheme provides OrcaTheme(
        elevatedButton = OrcaButtonStyle(
            shape = CircleShape,
            containerColor = Color(0xFFFF9800),
            contentColor = Color.White,
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 12.dp),
        ),
    ),
) {
    OrcaApp(client)
}
```

An `OrcaButtonStyle` sets any of `shape`, `containerColor`, `contentColor`, `border` and
`contentPadding`; what it leaves out keeps the Material 3 default. A button type without a style is
drawn as before.

The server wins: a button whose node carries its own style props (ElevatedButton
`backgroundColor`, `foregroundColor`, `borderRadius`, `padding`; OutlinedButton `color`,
`borderColor`; TextButton `color`) is drawn with those, not with the host style.

## DevTools

Off until you start it. Start it once per process, for example in `Application.onCreate`:

```kotlin
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.sdk.debug.OrcaDebugConfig
import com.orcagateway.sdk.debug.start

OrcaDebug.start(
    OrcaDebugConfig(
        enabled = true,        // debug builds only
        host = "10.0.2.2",     // the Mac running DevTools, as the emulator sees it
        appName = "My Shop",
        appVersion = "1.4.0",  // your versionName; the SDK takes no Context for it
        showOverlay = true,    // the load chip on each page
        logTimings = true,     // one logcat line per page load
        includeBodies = false, // the default; read the note below before turning it on
    ),
)
```

The SDK then sends DevTools (port 6363) its network requests, page timing, state changes, actions,
rebuilds and errors, and reconnects when DevTools restarts. A second `start` replaces the
connection and its options; `OrcaDebug.stop()` ends it and puts the options back to their
defaults. On a device, set `host` to the Mac's address, or run `adb reverse tcp:6363 tcp:6363` and
use `localhost`. The connection is plain `ws://`, so the build must allow cleartext traffic (debug
builds only). The example app reads its DevTools settings from intent extras; see
[`examples/app-android`](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-android).

Five options, with Flutter's names and defaults, choose what goes:

| Option | Default | What it does |
|---|---|---|
| `showOverlay` | `false` | draws a chip at the bottom right of each server page with its load time (request start to render complete); a tap shows `Load`, `Components` (the page's node count) and `Cache` (always `-`) |
| `logTimings` | `false` | also writes each page's `timing` event to logcat, tag `OrcaGateway`: `[OrcaDebug] Timing: <pageId> - <path>` |
| `captureStateChanges` | `true` | off: no `state_change` events |
| `captureNetworkRequests` | `true` | off: no `network` events; a failed request still sends its `error` event |
| `includeBodies` | `false` | on: `network` events carry `requestBody` (for a page, the app state it sent; for other requests, their body, if any) and `responseBody` (the JSON, else the raw text) |

Actions, rebuilds, timing and errors are never gated: they go whenever DevTools is on. The
`authorization`, `cookie`, `set-cookie`, `x-api-key` and `proxy-authorization` headers are always
sent as `<redacted>`.

Bodies can hold tokens and user data, and their size is not capped, so `includeBodies` stays off
unless you ask for it.

DevTools also shows how a value was made, as the Flutter SDK sends it:

- **Rebuilds.** Each time a widget that watches state is built (the first build included), its
  `widget_rebuild` event carries the trace of each prop built from a value: the state it read, a
  transform's input, then each step with its input and output.
- **setState.** Its `action` event carries `transformTrace`, the same steps for a transform value,
  and `affectedWidgets`, the page's widgets whose `watches` hold the key (id, type, watches). In
  DevTools: the action's Transform and Widgets tabs; pick a widget for its prop traces.
- **debugLog.** It shows as its `action` event (family `custom`), and its line goes to logcat under
  the action's tag (`orca` when it has none).

## Sessions, analytics and version check

`OrcaApp` takes two switches, both off by default. Both overloads have them, `OrcaApp(client)` and
`OrcaApp(router)`:

```kotlin
OrcaApp(client, path = "home", enableOffline = true, enableSessionTracking = true)
```

`enableOffline` asks the server's `/version` before the first page. When the answer says
`forceUpdate: true`, the app shows "Update required. Please update the app." and loads no page. Any
other answer, or none, lets the app start. The offline cache of static flows and `preload()` come
later (plan step 14), so for now this switch runs only the check.

`enableSessionTracking` posts a session start to `/session` when the app process comes to the
foreground, and an end when it goes to the background. It follows the process through
`ProcessLifecycleOwner`, not the activity, so a rotation does not end the session. A start or end
that cannot reach the server is queued in SharedPreferences and sent to `/session/offline` on the
next foreground. The SDK
declares `androidx.lifecycle:lifecycle-process` for this; your app adds nothing.

`OrcaApp(client)` gives a client without a `deviceId` a random one, made on first run and saved in
the SharedPreferences file `orca_gateway`. The client sends it as `x-orca-device-id` on every
request, whether or not sessions are tracked. For `OrcaApp(router)`, build the router's client with
`deviceId = DeviceIdentity.resolve(SharedPreferencesKeyValueStore(context))` to send the same id.

The SDK sends no analytics by itself. Build one `OrcaAnalytics` at app start and call `track`:

```kotlin
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.telemetry.OrcaAnalytics

val analytics = OrcaAnalytics.forClient(client)
analytics.track("screen_view", mapOf("screen" to JsonValue.String("home")))
```

Events go to `/events` in batches: when 20 are waiting, or 10 seconds after the first one. A batch
that fails goes back in the buffer, which keeps the newest 500. `/events` is a cloud route; the OSS
engine answers it 404. Call `dispose()` on teardown to send what is left.

`OrcaTelemetry.onEvent` is a process-wide hook for what the SDK itself reports. Set it once:

```kotlin
import android.util.Log
import com.orcagateway.core.telemetry.OrcaTelemetry

OrcaTelemetry.onEvent = { event, data -> Log.w("Orca", "$event $data") }
```

It reports one event so far, `unknown_widget_type` with `{"type": "<type>"}`, the first time the
process meets a widget type the SDK does not draw.

## App shell: host views, theme, locale, errors and timeout

Around the pages `OrcaApp` draws a few screens of its own: a spinner while it boots, an error
screen, and "Update required". Both overloads take four composables that replace them, and the
colours and locale for them and the pages; the client takes the request timeout:

```kotlin
import androidx.compose.material3.darkColorScheme
import java.util.Locale

val client = OrcaClient(
    baseUrl = URI("https://orca.example.com"),
    appId = "counter",
    apiKey = "demo-key",
    transport = OkHttpTransport(),
    timeoutMillis = 10_000, // 30_000 by default
)
setContent {
    OrcaApp(
        client,
        enableOffline = true,
        loading = { MyLoading() },
        splash = { MySplash() },
        error = { error -> MyError(error) },
        forceUpdate = { MyUpdatePrompt() },
        colorScheme = darkColorScheme(),
        locale = Locale.forLanguageTag("fr-FR"),
    )
}
```

- `splash`, else `loading`, shows while the app boots: the version check (`enableOffline`) and the
  `/config` fetch (no `path`). A page opened at a path skips the `/config` fetch; with
  `enableOffline` the splash still shows during the version check. Pages keep the SDK's spinner.
- `error` gets what failed the boot: the `/config` fetch's error or a plugin conflict. A page that
  fails to load always shows the SDK's error screen, with "Try again".
- `forceUpdate` replaces "Update required. Please update the app.".
- `colorScheme` is the Material 3 colours of everything `OrcaApp` draws, with your typography and
  shapes; null keeps your `MaterialTheme`. A Scaffold page stays light, as Flutter draws it in its
  default light theme, so dark mode shows on the SDK's screens and your own views.
- `locale` is what `OrcaApp`'s screens and pages read from `LocalConfiguration`. The layout direction
  stays yours (Flutter's default localizations are left to right), and nothing is sent: the
  `x-orca-locale` header stays the device's locale.

Each one left out (null) keeps what the SDK does without it.

The error screen is Flutter's (`buildOrcaError`): an icon, a title and a message for what failed.
`OrcaErrorView(error, modifier, onRetry)` draws it for any error of yours too, and
`OrcaErrorInfo.from(error)` (in `sdk-core`) gives its kind, title and message for a view of your own:

| What failed | Title |
|---|---|
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 429 | Too Many Requests |
| 500 or more | Server Error |
| another status | Error, with the message "Failed to fetch page: <status>" |
| an answer that does not decode, a URL that cannot be built | Configuration Error |
| a server not reached, or a request past the timeout | Connection Failed |
| anything else | Something Went Wrong |

`timeoutMillis` is how long one request may take, send to answer, 30 seconds by default.
`OkHttpTransport` applies it as the call's timeout; a transport of your own must apply
`HttpRequest.timeoutMillis` itself. Flutter's `OrcaClient` declares the same `timeout` but does not
apply it, so a slow server there waits as long as the HTTP library does.

## Plugins

A plugin bundles widgets and actions that belong together, as Flutter's `OrcaPlugin` does. Give
your plugins to `OrcaApp` (both overloads take them):

```kotlin
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.TriggerDefinition
import com.orcagateway.sdk.OrcaPlugin
import com.orcagateway.sdk.WidgetBuilder

private val coloredBadge: WidgetBuilder = { node, model, modifier ->
    Text(node["label"]?.stringValue ?: "", modifier.clickable { model.fire("onTap", on = node) })
}

class BadgePlugin : OrcaPlugin {
    override val name = "BadgePlugin"
    override val widgets = mapOf("ColoredBadge" to coloredBadge)
    override val actions = mapOf(
        "hapticFeedback" to OrcaActionHandler { action, executor -> /* action["intensity"] */ },
    )
    override val triggers = mapOf("ColoredBadge" to listOf(TriggerDefinition("onTap")))
}

OrcaApp(client, plugins = listOf(BadgePlugin()))
```

- `name` names the plugin in conflict messages.
- `widgets` maps a wire type to a `WidgetBuilder` (the node, the page model, the parent's
  modifier). A builder draws children with `NodeView(id, model)` and fires a trigger with
  `model.fire(trigger, on = node, eventData = ...)`: the node's action of that name runs and reads
  the event data through `V.event`.
- `actions` maps an action type to an `OrcaActionHandler`. It gets the action as sent (a
  `JsonObject`: `type` and its params, unresolved) and the `ActionExecutor`;
  `executor.resolve(value)` resolves a value against the page state, app state and event data.
- `triggers` declares the events each widget fires, for tooling. Nothing reads it at run time.

`OrcaApp` also takes `customActions`, handlers by type that belong to no plugin, and `widgets`, a
`WidgetBuilders` (`WidgetBuilders.standard()` plus what you `register` on it) for your own
widgets. It merges all of them once, before the first request, with Flutter's rules: two plugins
with one widget type or one action name, a plugin widget the SDK or `widgets` already draws, or a
plugin action named in `customActions` is a conflict. The first one stops the app: it shows its
error view with Flutter's message, for example
`Widget type "ColoredBadge" from plugin "B" conflicts with plugin "A".`, and fetches nothing.

An action `{"type":"custom:hapticFeedback"}` (the engine's `Custom("custom:hapticFeedback", ...)`) or
`{"type":"hapticFeedback"}` runs the handler named `hapticFeedback`; one registered under the exact
type `custom:hapticFeedback` comes first. A plugin action named like a built-in one
(`copyToClipboard`, `navigate`, ...) is no conflict: it replaces the built-in. An action that no
handler and no built-in knows does nothing.

Before the first request `OrcaApp` adds the plugins' widget types, and their action names both bare
and as `custom:<name>`, to the client's capabilities, so the server sends those widgets instead of
treating them as unsupported. Only plugins are advertised, not `customActions` or `widgets`.

The CLI writes a plugin stub from a plugin's `orca_plugin.yaml`: a props type per widget, a params
type per action, the triggers, and a placeholder builder and a no-op handler for each, to fill in
([CLI README](https://github.com/orca-gateway/orca-gateway/tree/main/cli#native-plugin-stubs)):

```bash
orca plugin generate --lang kotlin --manifest orca_plugin.yaml --package com.example.plugins
```

The [Android example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-android#plugins)
registers two plugins (`DemoPlugins.kt`) for the example server's `custom` app.

## Tests

```bash
task sdk-kotlin:test        # or: cd sdk-kotlin && ./gradlew :core:test :sdk:testDebugUnitTest
```

The core tests read the conformance fixtures from `../schema/fixtures/` at run time (render
fixtures, their `resolved` maps, action fixtures), the same files the engine, the Flutter SDK and
the Swift SDK run, so they only run inside the monorepo. The `sdk` tests run the Compose UI on the
JVM under Robolectric, no emulator, against pages recorded from the example server
(`task sdk-kotlin:record`). CI runs both, plus the example app's build, on Linux for every PR
touching `sdk-kotlin/`, `schema/` or `examples/app-android/`. It also stages the Maven publication
and builds a scratch consumer against it with `scripts/maven-verify.sh`.

## Capabilities

`core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt` is generated; do not edit it.
It lists the widgets and action kinds named in [`capabilities.json`](capabilities.json) (each widget
must carry the `android` target in `schema/widget-registry.json`) plus every value kind, transform
and BoolExpr op of the engine. Add a widget or action kind to `capabilities.json` in the same PR
that implements it, then regenerate from the monorepo root:

```bash
bun run schema/gen-native-capabilities.ts
```

## Versioning

`VERSION` holds the SDK version, which both artifacts carry, and feeds `sdkSemver` in the capability
vector, which the client sends as `x-orca-sdk-version`. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh),
never by hand. `0.1.0-alpha.1` is the first published version.

The script pushes a `sdk-kotlin-v<X>` tag, and that tag starts the "SDK Kotlin Publish" workflow. It
checks that `VERSION` reads `<X>`, signs both artifacts and releases them to Maven Central in one
deployment, then builds a scratch app against `<X>` from Central. A version on Central cannot be
replaced, so a fix goes out as the next version.

## License

[Business Source License 1.1](LICENSE), as the rest of Orca Gateway.
