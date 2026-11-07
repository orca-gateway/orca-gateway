# Orca Gateway Android SDK (`sdk-kotlin`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The native Android client for Orca Gateway (Epic 23b) works for the
> pages its 25 widgets and 15 action kinds cover, but its API may still change between alphas, so
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
follows the page's navigation, the system back gesture included:

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
| `sdk` | The OkHttp transport, `DeviceInfo.current(context)`, the Compose renderer with 25 widgets (the 15 core ones plus Icon, Image, Container, Expanded, Spacer, TextField, Stack, Positioned, ClipRRect, GestureDetector) and the degrade policies (an unknown widget becomes a FallbackPrompt; the server's `warn` banner, its `require` blocking prompt and the 426 upgrade page are drawn like any page), `OrcaTheme` button styles, `OrcaApp` on `OrcaRouter` (a `NavHost`), `SystemActions`, the DevTools client. Artifact `com.orcagateway:sdk`. | Android 7.0+ (minSdk 24) |

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
    ),
)
```

The SDK then sends DevTools (port 6363) its network requests, page timing, state changes, actions,
rebuilds and errors, and reconnects when DevTools restarts. A second `start` replaces the
connection; `OrcaDebug.stop()` ends it. On a device, set `host` to the Mac's address, or run
`adb reverse tcp:6363 tcp:6363` and use `localhost`. The connection is plain `ws://`, so the
build must allow cleartext traffic (debug builds only). The example app reads both settings from
intent extras; see [`examples/app-android`](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-android).

## Tests

```bash
task sdk-kotlin:test        # or: cd sdk-kotlin && ./gradlew :core:test :sdk:testDebugUnitTest
```

The core tests read the conformance fixtures from `../schema/fixtures/` at run time (render
fixtures, their `resolved` maps, action fixtures), the same files the engine, the Flutter SDK and
the Swift SDK run, so they only run inside the monorepo. The `sdk` tests run the Compose UI on the
JVM under Robolectric, no emulator, against pages recorded from the example server
(`task sdk-kotlin:record`). CI runs both, plus the example app's build, on Linux for every PR
touching `sdk-kotlin/`, `schema/` or `examples/app-android/`.

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
