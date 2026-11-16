# Orca Gateway video player for Android (`orca-video-player`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The plugin is built on the alpha Android SDK, and its API may still
> change between alphas. For production apps use the Flutter plugin
> ([`orca_video_player`](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_video_player)).

The video player for Android apps on the Orca Gateway Kotlin SDK: the `VideoPlayer` widget, which
plays a network video with the platform's `MediaPlayer`, and five actions that play, pause and
seek it and set its volume and speed. It is the twin of the Flutter plugin `orca_video_player`:
the same widget, props, triggers, actions, params and defaults, so a server page that plays a
video in a Flutter app plays it here too.

The source lives in [`plugins/orca_video_player/android/` of orca-gateway/orca-gateway](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_video_player/android).

## Install

The plugin is on Maven Central, beside the SDK. With the repositories the
[SDK's install](https://github.com/orca-gateway/orca-gateway/tree/main/sdk-kotlin#install) names
(Google's and Maven Central), add it to your app module's `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.orcagateway:orca-video-player:0.1.0-alpha.1")
}
```

It depends on the SDK, `com.orcagateway:sdk`, so Gradle brings the SDK too; when your app names
the SDK as well, Gradle takes the higher of the two versions. The app needs what the SDK needs:
`minSdk = 24` or higher and Compose turned on.

## Register

Make the plugin once, outside `setContent` (its players live in it), and pass it to `OrcaApp`
with the rest of your plugins:

```kotlin
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.plugins.videoplayer.VideoPlayerPlugin
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
        val plugins = listOf(VideoPlayerPlugin())
        setContent { OrcaApp(client, path = "home", plugins = plugins) }
    }
}
```

`VideoPlayerPlugin()` takes no `Context`, and its actions run on the main thread. `OrcaApp(router)`
takes `plugins` too. Before the first request `OrcaApp` adds the `VideoPlayer` widget type and the
five action names to the client's capabilities, so the server sends the nodes that use them.

## Network and cleartext

`INTERNET` is in the library's manifest, and the manifest merger adds it to your app's: add
nothing. Android grants it at install, so nothing is asked at run time, and an `https` URL plays
as is.

A plain `http` URL is cleartext, which Android blocks by default for apps that target API 28 or
higher: the app must allow it itself, or the video fails to load (the widget shows *Video failed
to load* and fires `onError`). The library allows none, and the Flutter plugin's `orca_plugin.yaml`
asks for `INTERNET` alone. Allow only the hosts your videos come from with a network security
config, named on the app's `<application>` as
`android:networkSecurityConfig="@xml/network_security_config"`:

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">videos.example.com</domain>
    </domain-config>
</network-security-config>
```

`android:usesCleartextTraffic="true"` on `<application>` allows every host instead; the
[Android example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-android)
sets it in its debug manifest only, for the example server.

## The widget

| Prop | Type | Default | What it does |
|---|---|---|---|
| `url` | string | `""` | The video's network URL; a new `url` loads a new player. |
| `autoPlay` | boolean | `false` | Plays as soon as the video is loaded, firing no `onPlay`. |
| `looping` | boolean | `false` | Starts again at the end, without `onComplete`. |
| `showControls` | boolean | `true` | A tap on the video plays or pauses it, firing `onPlay` or `onPause`, with the play mark over it while not playing. |
| `aspectRatio` | number | the video's | Width over height of the video's box. |
| `playerId` | string | the node's id | The id the actions name the player by, once it is loaded. |

While loading, a 32 dp circle of 20% black in the middle; when the video fails to load, the text
Video failed to load (14 sp) in the middle. Once loaded, the video on a `TextureView` in a box of
`aspectRatio`, stretched to fill it as Flutter's is, and with `showControls`, while not playing, a
56 dp circle of 60% black with a white ▶ over it. The widget makes its player when it comes on
screen and frees it when it leaves; the player is registered under `playerId` once loaded, and
removed when the widget leaves or its `url` changes.

While on screen it fires:

- `onPlay` and `onPause` from the overlay's tap only (`showControls`), never from `playVideo`,
  `pauseVideo` or `autoPlay`.
- `onProgress` with `{position, duration, fraction}` (ms, ms, and 0 to 1) on each change of the
  player's state while it plays a video of known length; the position is read every 100 ms while
  playing.
- `onComplete` once when the position reaches the duration, and again only after the position is
  back before it. A video that does not loop pauses on its last frame there; a looping one starts
  again from 0 without `onComplete`.
- `onError` with `{message}` when the video fails to load: `MediaPlayer`'s error codes, as
  `Video player had error what=… extra=…`, or the exception's text when the url cannot be
  opened.

## The actions

Every param is resolved as a value (a `V.pageState(...)` works). An empty or unknown `playerId`,
or one whose video has not loaded yet, does nothing, and so does a missing `position`, `volume`
or `speed`; one that resolves to anything but a number fails the action, as Flutter's cast does.

| Action | Params | What it does |
|---|---|---|
| `playVideo` | `playerId` (required) | Plays, from 0 when at the end. Fires no `onPlay`. |
| `pauseVideo` | `playerId` (required) | Pauses. Fires no `onPause`. |
| `seekVideo` | `playerId` (required), `position` (required) | Seeks to `position` ms, clamped between 0 and the duration. |
| `setVolume` | `playerId` (required), `volume` (required) | Sets the volume, clamped to 0...1. |
| `setPlaybackSpeed` | `playerId` (required), `speed` (required) | Sets the speed (1 is normal). Applied while playing; set while paused, it applies at the next play. A speed of 0 or less fails the action, with `video_player`'s error. |

A server page builds them, and the widget, with the TypeScript classes
`orca plugin generate --manifest orca_plugin.yaml` writes from the plugin's
[`orca_plugin.yaml`](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_video_player/orca_plugin.yaml).
The example server's `custom` app has a Video Page that plays a video with Play, Pause, Seek 0,
Volume 0.5 and Speed 1.5 buttons and shows the position `onProgress` keeps in page state
([`examples/server/custom.ts`](https://github.com/orca-gateway/orca-gateway/blob/main/examples/server/custom.ts)).

## Tests

In a checkout of the monorepo:

```bash
cd plugins/orca_video_player/android && ./gradlew build
```

It compiles with warnings as errors, runs the unit tests under Robolectric and runs lint. The
tests drive the plugin with a fake player, and `MediaPlayer` through Robolectric's, so they need
no network. `./gradlew` is the SDK's
wrapper, and the build includes `../../../sdk-kotlin`, so the plugin compiles against the SDK's
source.

## Versioning and releases

`VERSION` holds the package version. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh)
(the `orca_video_player-android` package), never by hand. Its `orca_video_player-android-v<X>` tag
starts the "SDK Kotlin Publish" workflow, which signs `com.orcagateway:orca-video-player` `<X>`
and releases it to Maven Central. Its POM depends on `com.orcagateway:sdk` at the version in
`sdk-kotlin/VERSION`. A version on Central cannot be replaced, so a fix goes out as the next
version.

## License

[Business Source License 1.1](../LICENSE), as the rest of Orca Gateway.
