# Orca Gateway voice recorder for iOS (`OrcaVoiceRecorder`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The plugin is built on the alpha iOS SDK, and its API may still
> change between alphas. For production apps use the Flutter plugin
> ([`orca_voice_recorder`](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_voice_recorder)).

The voice recorder for iOS and macOS apps on the Orca Gateway Swift SDK: the `VoiceRecorder` widget
and nine actions that record the microphone, play the recordings back and write the results to
page or app state. It is the twin of the Flutter plugin `orca_voice_recorder`: the same widget,
triggers, actions, params and defaults, so a server page that records in a Flutter app records
here too.

The source lives in [`plugins/orca_voice_recorder/ios/` of orca-gateway/orca-gateway](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_voice_recorder/ios).
[orca-voice-recorder-swift](https://github.com/orca-gateway/orca-voice-recorder-swift) is a
read-only copy for Swift Package Manager, updated on each release; send issues and pull requests to
the monorepo.

## Install

The package needs iOS 16 or macOS 13, as the SDK does. In Xcode: **File → Add Package
Dependencies…**, paste `https://github.com/orca-gateway/orca-voice-recorder-swift.git`, set
**Dependency Rule** to **Up to Next Major Version** from `0.1.0-alpha.1`, and add the
`OrcaVoiceRecorder` library to your app target.

In a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/orca-gateway/orca-gateway-swift.git", from: "0.1.0-alpha.2"),
    .package(url: "https://github.com/orca-gateway/orca-voice-recorder-swift.git", from: "0.1.0-alpha.1"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "OrcaGateway", package: "orca-gateway-swift"),
        .product(name: "OrcaVoiceRecorder", package: "orca-voice-recorder-swift"),
    ]),
]
```

The package brings the SDK, [orca-gateway-swift](https://github.com/orca-gateway/orca-gateway-swift),
from `0.1.0-alpha.2`, the first SDK release with the plugin API. Your app's own rule for the SDK
must allow that version: an exact `0.1.0-alpha.1` does not resolve with the plugin. A rule whose
lower bound is an alpha, as `from: "0.1.0-alpha.2"`, also takes the alphas after it.

## Register

Pass `VoiceRecorderPlugin()` to `OrcaApp` with the rest of your plugins:

```swift
import OrcaGateway
import OrcaVoiceRecorder
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            OrcaApp(
                client: OrcaClient(baseURL: URL(string: "https://orca.example.com")!,
                                   appId: "counter", apiKey: "demo-key"),
                path: "home",
                plugins: [VoiceRecorderPlugin()])
        }
    }
}
```

`OrcaApp(router:)` takes `plugins:` too. The client adds the `VoiceRecorder` widget type and the
nine action types to the capabilities it sends, so the server keeps the nodes that use them.

## Microphone

Add `NSMicrophoneUsageDescription` to the app's `Info.plist`, a sentence that says why the app
records:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record audio</string>
```

Without it iOS ends the app the first time `startRecording` asks for the microphone. The first
`startRecording` asks the user; after a refusal `startRecording` does nothing, as in Flutter, until
the user allows the microphone in **Settings → Privacy & Security → Microphone**. A macOS app needs
the same key and, with App Sandbox or the Hardened Runtime on, the Audio Input entitlement
(`com.apple.security.device.audio-input`).

On iOS a recording sets the shared `AVAudioSession` to `.playAndRecord` (to the speaker, Bluetooth
allowed) and activates it; `playRecording` sets it to `.playback`.

## The widget

| Prop | Type | Default | What it does |
|---|---|---|---|
| `recorderId` | string | the node's id | The id the actions name the recorder by. |
| `showAmplitude` | boolean | `true` | Shows the level bar while recording. |

A 16 pt dot (red recording, orange paused, grey idle), while recording a 100 × 4 pt green level bar
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
| `startRecording` | `recorderId` (required) | Asks for the microphone the first time, then records AAC-LC to `orca_recording_<recorderId>_<ms>.m4a` (see Recordings). Without the permission, nothing. |
| `stopRecording` | `recorderId` (required), `pathKey`, `durationKey`, `scope` (`page`) | Stops; writes the file's path to `pathKey` and the duration in ms (wall clock since the start, pauses included) to `durationKey`. |
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

Recordings go to the app's Caches directory, where Flutter's `getTemporaryDirectory()` puts them on
iOS: `.m4a` files of AAC-LC at 44.1 kHz, 128 kbit/s, two channels. The system may delete Caches when
storage runs low, so move a recording the app keeps; its path is in the state key `stopRecording`
wrote.

## Tests

In a checkout of the monorepo, where the package builds against `../../../sdk-swift` by path:

```bash
cd plugins/orca_voice_recorder/ios && swift test
```

The "Native Plugins CI" workflow also runs them on an iOS simulator.

## Versioning and releases

`VERSION` holds the package version. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh)
(the `orca_voice_recorder-ios` package), never by hand. Its `orca_voice_recorder-ios-v<X>` tag
starts the "SDK Swift Mirror" workflow, which copies `plugins/orca_voice_recorder/ios/` to
orca-voice-recorder-swift with `git subtree split`, tags it `<X>` there and builds a package that
imports `OrcaVoiceRecorder` at that tag, for macOS and the iOS simulator.

## License

[Business Source License 1.1](LICENSE), as the rest of Orca Gateway.
