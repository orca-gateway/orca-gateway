# Orca Gateway Google map for Android (`orca-google-map`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The plugin is built on the alpha Android SDK, and its API may still
> change between alphas. For production apps use the Flutter plugin
> ([`orca_google_map`](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_google_map)).

The Google map for Android apps on the Orca Gateway Kotlin SDK: the `GoogleMap` widget, which draws
Google's map with markers through Google's Maps Compose, and the `moveCamera` action that animates
its camera. It is the twin of the Flutter plugin `orca_google_map`: the same widget, props,
triggers, action, params and defaults, so a server page that shows a map in a Flutter app shows it
here too.

The source lives in [`plugins/orca_google_map/android/` of orca-gateway/orca-gateway](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_google_map/android).

## Install

The plugin is on Maven Central, beside the SDK. With the repositories the
[SDK's install](https://github.com/orca-gateway/orca-gateway/tree/main/sdk-kotlin#install) names
(Google's and Maven Central), add it to your app module's `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.orcagateway:orca-google-map:0.1.0-alpha.1")
}
```

It depends on the SDK, `com.orcagateway:sdk`, so Gradle brings the SDK too; when your app names
the SDK as well, Gradle takes the higher of the two versions. It also brings Maps Compose from
Maven Central, and the Maps SDK for Android it draws with (`play-services-maps`) from Google's
Maven repository. The app needs what the SDK needs: `minSdk = 24` or higher and Compose turned on.

The map needs Google Play services on the device, as every Google map on Android does: a phone
with the Play Store, or an emulator image with Google APIs or Google Play.

## Register

Make the plugin once, outside `setContent` (the maps `moveCamera` moves are kept in it), and pass
it to `OrcaApp` with the rest of your plugins:

```kotlin
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.plugins.googlemap.GoogleMapPlugin
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
        val plugins = listOf(GoogleMapPlugin())
        setContent { OrcaApp(client, path = "home", plugins = plugins) }
    }
}
```

`GoogleMapPlugin()` takes no `Context`, and its action runs on the main thread. `OrcaApp(router)`
takes `plugins` too. Before the first request `OrcaApp` adds the `GoogleMap` widget type and the
`moveCamera` action name to the client's capabilities, so the server sends the nodes that use them.

## The Maps API key

Google's map needs your app's Maps API key, which the plugin does not carry. Make one in the Google
Cloud Console with the Maps SDK for Android enabled, and restrict it to your app's package name and
signing certificate's SHA-1, as Google's
[Using API keys](https://developers.google.com/maps/documentation/android-sdk/get-api-key) page
shows.

The app's manifest names it in a `meta-data` inside `<application>`. To keep the key out of version
control, put it in `local.properties` (not committed) and pass it through a manifest placeholder;
`GOOGLE_MAPS_ANDROID_API_KEY` is the name the Flutter plugin's `orca_plugin.yaml` uses:

```xml
<!-- app/src/main/AndroidManifest.xml -->
<application>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="${GOOGLE_MAPS_ANDROID_API_KEY}" />
</application>
```

```kotlin
// app/build.gradle.kts
val mapsApiKey = rootDir.resolve("local.properties").takeIf { it.isFile }
    ?.let { file -> java.util.Properties().apply { file.inputStream().use { load(it) } } }
    ?.getProperty("GOOGLE_MAPS_ANDROID_API_KEY").orEmpty()

android {
    defaultConfig {
        manifestPlaceholders["GOOGLE_MAPS_ANDROID_API_KEY"] = mapsApiKey
    }
}
```

Without the `meta-data` the Maps SDK throws when the first map is made. With a key Google refuses
(the Maps SDK for Android not enabled, or the key restricted to another app) the map is drawn
without its tiles, and Google says why in logcat.

## Location

`ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` are in the library's manifest, and the manifest
merger adds them to your app's. Both are runtime permissions, and the plugin never asks for them,
as Flutter's does not. With `myLocationEnabled`, the map shows the device's location (Google's blue
dot and its my-location button) only while the app holds one of them; without either, it leaves
the location layer off. The plugin reads the permission as it draws the map, so ask before the page
with the map opens:

```kotlin
// In the activity, before setContent.
val askForLocation =
    registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {}
askForLocation.launch(
    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
)
```

An app that never sets `myLocationEnabled` can drop both from its merged manifest with
`tools:node="remove"`.

## The widget

| Prop | Type | Default | What it does |
|---|---|---|---|
| `latitude` | number | `0` | The first camera's latitude, read when the map is made; after that only `moveCamera` and the user move the camera. |
| `longitude` | number | `0` | The first camera's longitude, read when the map is made. |
| `zoom` | number | `14` | The first camera's zoom, Google's zoom level; read when the map is made. |
| `mapType` | string | `"normal"` | `normal`, `satellite`, `terrain` or `hybrid`; any other string draws `normal`. |
| `myLocationEnabled` | boolean | `false` | Shows the device's location while the app holds a location permission (see [Location](#location)). |
| `zoomControlsEnabled` | boolean | `true` | Shows the map's zoom + and - buttons. |
| `markers` | array | none | The map's markers, each an object of the fields below. An entry that is not an object, or lacks a number `latitude` or `longitude`, is skipped. |

| Marker field | Type | Default | What it does |
|---|---|---|---|
| `id` | string | `""` | What `onMarkerTap` fires as `markerId`; a value that is not a string is used as its text. |
| `latitude` | number | required | The marker's latitude. |
| `longitude` | number | required | The marker's longitude. |
| `title` | string | `""` | The info window's title. |
| `snippet` | string | none | The info window's text under the title. |

The map fills the box its parent gives it, as Flutter's map does: give it a height, as the
example's 300-high Container does. `mapType`, `myLocationEnabled`, `zoomControlsEnabled` and
`markers` follow each update of the props; the camera props do not. Google's other controls are
its defaults, as with Flutter's: the compass, the map toolbar and, with the location layer, the
my-location button. The plugin keeps each map under its node id from when it is made until it
leaves the screen.

While on screen it fires:

- `onTap` with `{latitude, longitude}`, the tapped point, on a tap off the markers.
- `onLongPress` with `{latitude, longitude}`, the pressed point, on a long press.
- `onCameraMove` with `{latitude, longitude, zoom}`, the camera's centre and zoom, at each position
  while the camera moves, from a gesture, `moveCamera`'s animation or a marker tap; not the one it
  is made at.
- `onMarkerTap` with `{markerId}` on each tap on a marker; Google then opens its info window and
  centres the camera on it.

## The action

Every param is resolved as a value (a `V.pageState(...)` works). `targetId` is the map node's id,
the key the server gives it (the example's `.withKey("main-map")`); a value that is not a string is
used as its text. An empty or unknown `targetId`, or a map no longer on screen, does nothing, and
so does a missing `latitude` or `longitude`; a param that resolves to anything but a number fails
the action, as Flutter's cast does.

| Action | Params | What it does |
|---|---|---|
| `moveCamera` | `targetId` (required), `latitude` (required), `longitude` (required), `zoom` | Animates the map's camera to `latitude`, `longitude` at `zoom` (default 14), north up and flat, as Flutter's does. Fires no trigger itself; `onCameraMove` fires as the camera moves. |

A server page builds it, and the widget, with the TypeScript classes
`orca plugin generate --manifest orca_plugin.yaml` writes from the plugin's
[`orca_plugin.yaml`](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_google_map/orca_plugin.yaml).
The example server's `custom` app has a Map Page with a map of San Francisco and two markers, Texts
for what each trigger fired, a count of marker taps, and a Move Camera to NYC button
([`examples/server/custom.ts`](https://github.com/orca-gateway/orca-gateway/blob/main/examples/server/custom.ts)).

## Differences from Flutter

One: a prop or a marker field of the wrong type reads as absent. The prop takes its default, a
marker with a coordinate that is not a number is skipped, a title that is not a string is empty and
a snippet that is not a string is left out. Flutter's casts fail the map's build there.

## Tests

In a checkout of the monorepo:

```bash
cd plugins/orca_google_map/android && ./gradlew build
```

It compiles with warnings as errors, runs the unit tests under Robolectric and runs lint.
Robolectric cannot draw Google Maps, so the tests drive the plugin through a fake map; the real one
is checked by hand in the Android example. `./gradlew` is the SDK's wrapper, and the build includes
`../../../sdk-kotlin`, so the plugin compiles against the SDK's source.

## Versioning and releases

`VERSION` holds the package version. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh)
(the `orca_google_map-android` package), never by hand. Its `orca_google_map-android-v<X>` tag
starts the "SDK Kotlin Publish" workflow, which signs `com.orcagateway:orca-google-map` `<X>` and
releases it to Maven Central. Its POM depends on `com.orcagateway:sdk` at the version in
`sdk-kotlin/VERSION`. A version on Central cannot be replaced, so a fix goes out as the next
version.

## License

[Business Source License 1.1](../LICENSE), as the rest of Orca Gateway.
