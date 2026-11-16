# Orca Gateway voice recorder for Android (`orca-voice-recorder`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The plugin is built on the alpha Android SDK, and its API may still
> change between alphas. For production apps use the Flutter plugin
> ([`orca_voice_recorder`](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_voice_recorder)).

The voice recorder for Android apps on the Orca Gateway Kotlin SDK: the `VoiceRecorder` widget and
nine actions that record the microphone, play the recordings back and write the results to page or
app state. It is the twin of the Flutter plugin `orca_voice_recorder`: the same widget, triggers,
actions, params and defaults, so a server page that records in a Flutter app records here too.

The source lives in [`plugins/orca_voice_recorder/android/` of orca-gateway/orca-gateway](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_voice_recorder/android).

## Install

The plugin is on Maven Central, beside the SDK. With the repositories the
[SDK's install](https://github.com/orca-gateway/orca-gateway/tree/main/sdk-kotlin#install) names
(Google's and Maven Central), add it to your app module's `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.orcagateway:orca-voice-recorder:0.1.0-alpha.1")
}
```

It depends on the SDK, `com.orcagateway:sdk`, so Gradle brings the SDK too; when your app names
the SDK as well, Gradle takes the higher of the two versions. The app needs what the SDK needs:
`minSdk = 24` or higher and Compose turned on.

## Register

Make the plugin once, outside `setContent`, with the application context, and pass it to `OrcaApp`
with the rest of your plugins:

```kotlin
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.plugins.voicerecorder.VoiceRecorderPlugin
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
        val plugins = listOf(VoiceRecorderPlugin(applicationContext))
        setContent { OrcaApp(client, path = "home", plugins = plugins) }
    }
}
```

`OrcaApp(router)` takes `plugins` too. Before the first request `OrcaApp` adds the `VoiceRecorder`
widget type and the nine action names to the client's capabilities, so the server sends the nodes
that use them.

## Microphone

`RECORD_AUDIO` is in the library's manifest, and the manifest merger adds it to your app's: add
nothing. Android asks for it at run time: a `VoiceRecorder` on screen registers a permission
request with its activity, and the first `startRecording` without the permission asks the user
through it, then records once allowed. A refusal, or no `VoiceRecorder` on screen to ask through,
makes `startRecording` do nothing, silently, as in Flutter; a user who refused can allow the
microphone in the app's system settings. The request needs the activity's result registry, which
a `ComponentActivity`'s `setContent` provides.

## The widget

| Prop | Type | Default | What it does |
|---|---|---|---|
| `recorderId` | string | the node's id | The id the actions name the recorder by. |
| `showAmplitude` | boolean | `true` | Shows the level bar while recording. |

A 16 dp dot (red recording, orange paused, grey idle), while recording a 100 × 4 dp green level bar
below it, and the label Recording, Paused or Ready. While on screen it fires `onStateChange` with
`{state}` (`idle`, `recording` or `paused`) on each change of state, and `onAmplitudeChange` with
`{amplitude}` (the level in dBFS, read every 200 ms while recording) on each change of level.
`onRecordingComplete` is declared and never fired, as in Flutter: `stopRecording` writes the
recording's path and duration to state instead.

## The actions

`recorderId`, `path` and `position` are resolved as values (a `V.pageState(...)` works); the other
params are read as sent. An empty `recorderId` or `path` does nothing. `scope` is `page` or `app`.

| Action | Params (default) | What it does |
|---|---|---|
| `startRecording` | `recorderId` (required) | Asks for the microphone the first time (see Microphone), then records AAC-LC to `orca_recording_<recorderId>_<ms>.m4a` (see Recordings). Without the permission, nothing. |
| `stopRecording` | `recorderId` (required), `pathKey`, `durationKey`, `scope` (`page`) | Stops; writes the file's path to `pathKey` (not when it was stopped before any audio arrived, which leaves no file) and the duration in ms (wall clock since the start, pauses included) to `durationKey`. |
| `pauseRecording` | `recorderId` (required) | Pauses the recording; no level while paused. |
| `resumeRecording` | `recorderId` (required) | Resumes it. |
| `playRecording` | `path` (required), `positionKey`, `durationKey`, `stateKey`, `scope` (`page`) | Plays the file in place of any clip playing: its length in ms to `durationKey` once loaded, the position in ms to `positionKey` every 200 ms, `playing` to `stateKey` (`error` if it cannot play); at the end `0` to `positionKey` and `stopped` to `stateKey`. |
| `stopPlayback` | `positionKey`, `stateKey`, `scope` (`page`) | Stops; `0` to `positionKey`, `stopped` to `stateKey`. |
| `pausePlayback` | `stateKey`, `scope` (`page`) | Pauses; `paused` to `stateKey`. |
| `resumePlayback` | `stateKey`, `scope` (`page`) | Resumes; `playing` to `stateKey`. |
| `seekPlayback` | `position` (`0`) | Seeks to `position` ms; anything but a number, or a negative one, seeks to 0. |

A server page builds them, and the widget, with the TypeScript classes
`orca plugin generate --manifest orca_plugin.yaml` writes from the plugin's
[`orca_plugin.yaml`](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_voice_recorder/orca_plugin.yaml).
The example server's `custom` app has a Voice Page that records, stops into page state and plays
the file back ([`examples/server/custom.ts`](https://github.com/orca-gateway/orca-gateway/blob/main/examples/server/custom.ts)).

## Recordings

Recordings go to the app's cache directory (`Context.cacheDir`), where Flutter's
`getTemporaryDirectory()` puts them on Android: `.m4a` files (MPEG-4) of AAC at 44.1 kHz,
128 kbit/s, two channels. Android may delete cache files when storage runs low, so move a recording
the app keeps; its path is in the state key `stopRecording` wrote.

## Tests

In a checkout of the monorepo:

```bash
cd plugins/orca_voice_recorder/android && ./gradlew build
```

It compiles with warnings as errors, runs the unit tests under Robolectric and runs lint.
`./gradlew` is the SDK's wrapper, and the build includes `../../../sdk-kotlin`, so the plugin
compiles against the SDK's source.

## Versioning and releases

`VERSION` holds the package version. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh)
(the `orca_voice_recorder-android` package), never by hand. Its `orca_voice_recorder-android-v<X>`
tag starts the "SDK Kotlin Publish" workflow, which signs `com.orcagateway:orca-voice-recorder`
`<X>` and releases it to Maven Central. Its POM depends on `com.orcagateway:sdk` at the version in
`sdk-kotlin/VERSION`. A version on Central cannot be replaced, so a fix goes out as the next
version.

## License

[Business Source License 1.1](../LICENSE), as the rest of Orca Gateway.
