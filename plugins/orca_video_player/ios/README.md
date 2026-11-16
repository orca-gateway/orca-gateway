# Orca Gateway video player for iOS (`OrcaVideoPlayer`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The plugin is built on the alpha iOS SDK, and its API may still
> change between alphas. For production apps use the Flutter plugin
> ([`orca_video_player`](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_video_player)).

The video player for iOS and macOS apps on the Orca Gateway Swift SDK: the `VideoPlayer` widget,
which plays a network video with AVPlayer, and five actions that play, pause and seek it and set
its volume and speed. It is the twin of the Flutter plugin `orca_video_player`: the same widget,
props, triggers, actions, params and defaults, so a server page that plays a video in a Flutter
app plays it here too.

The source lives in [`plugins/orca_video_player/ios/` of orca-gateway/orca-gateway](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_video_player/ios).
[orca-video-player-swift](https://github.com/orca-gateway/orca-video-player-swift) is a read-only
copy for Swift Package Manager, updated on each release; send issues and pull requests to the
monorepo.

## Install

The package needs iOS 16 or macOS 13, as the SDK does. In Xcode: **File → Add Package
Dependencies…**, paste `https://github.com/orca-gateway/orca-video-player-swift.git`, set
**Dependency Rule** to **Up to Next Major Version** from `0.1.0-alpha.1`, and add the
`OrcaVideoPlayer` library to your app target.

In a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/orca-gateway/orca-gateway-swift.git", from: "0.1.0-alpha.2"),
    .package(url: "https://github.com/orca-gateway/orca-video-player-swift.git", from: "0.1.0-alpha.1"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "OrcaGateway", package: "orca-gateway-swift"),
        .product(name: "OrcaVideoPlayer", package: "orca-video-player-swift"),
    ]),
]
```

The package brings the SDK, [orca-gateway-swift](https://github.com/orca-gateway/orca-gateway-swift),
from `0.1.0-alpha.2`, the first SDK release with the plugin API. Your app's own rule for the SDK
must allow that version: an exact `0.1.0-alpha.1` does not resolve with the plugin. A rule whose
lower bound is an alpha, as `from: "0.1.0-alpha.2"`, also takes the alphas after it.

## Register

Pass `VideoPlayerPlugin()` to `OrcaApp` with the rest of your plugins:

```swift
import OrcaGateway
import OrcaVideoPlayer
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            OrcaApp(
                client: OrcaClient(baseURL: URL(string: "https://orca.example.com")!,
                                   appId: "counter", apiKey: "demo-key"),
                path: "home",
                plugins: [VideoPlayerPlugin()])
        }
    }
}
```

`OrcaApp(router:)` takes `plugins:` too. The client adds the `VideoPlayer` widget type and the
five action types to the capabilities it sends, so the server keeps the nodes that use them.

## Network and App Transport Security

The widget streams its `url` with AVPlayer. Nothing asks the user for a permission, and an `https`
URL plays with nothing in `Info.plist`. A plain `http` URL on any host but `localhost` is held to
App Transport Security: the app needs an exception for it, or the video fails to load (the widget
shows *Video failed to load* and fires `onError`).

The Flutter plugin's `orca_plugin.yaml` asks for `NSAllowsArbitraryLoads`, which turns App
Transport Security off for every connection, and `orca plugin add` writes it into a Flutter app's
`Info.plist`. Nothing writes a native app's: add the exception yourself.
`NSAllowsArbitraryLoadsForMedia` lifts it only for what AVFoundation loads, so the app's other
connections keep it:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoadsForMedia</key>
    <true/>
</dict>
```

For one host only, list it under `NSExceptionDomains` with `NSExceptionAllowsInsecureHTTPLoads`
instead.

## Sound

On iOS the plugin sets the shared `AVAudioSession`'s category to `.playback`, as Flutter's
`video_player` does when it initializes, so a video is heard with the Ring/Silent switch on
Silent. It does this once, when its first `VideoPlayer` comes on screen: a `.record` or
`.playAndRecord` session becomes `.playAndRecord`, so recording goes on, the category's options
are kept, and a session already `.playback` is left as it is. If iOS refuses the category, the
failure is logged and the video plays on. macOS has no audio session.

An app that wants another category for its videos (`.ambient`, say, so the Silent switch mutes
them) sets it after that: the plugin does not set it again, and a category set before is upgraded
as above.

## The widget

| Prop | Type | Default | What it does |
|---|---|---|---|
| `url` | string | `""` | The video's network URL; a new `url` loads a new player. |
| `autoPlay` | boolean | `false` | Plays as soon as the video is loaded, firing no `onPlay`. |
| `looping` | boolean | `false` | Starts again at the end, without `onComplete`. |
| `showControls` | boolean | `true` | A tap on the video plays or pauses it, firing `onPlay` or `onPause`, with the play mark over it while not playing. |
| `aspectRatio` | number | the video's | Width over height of the video's box. |
| `playerId` | string | the node's id | The id the actions name the player by, once it is loaded. |

While loading, a 32 pt circle of 20% black in the middle; when the video fails to load, the text
Video failed to load (14 pt) in the middle. Once loaded, the video in a box of `aspectRatio`,
stretched to fill it as Flutter's is, and with `showControls`, while not playing, a 56 pt circle
of 60% black with a white ▶ over it. The widget makes its player when it comes on screen and
frees it when it leaves; the player is registered under `playerId` once loaded, and removed when
the widget leaves or its `url` changes.

While on screen it fires:

- `onPlay` and `onPause` from the overlay's tap only (`showControls`), never from `playVideo`,
  `pauseVideo` or `autoPlay`.
- `onProgress` with `{position, duration, fraction}` (ms, ms, and 0 to 1) on each change of the
  player's state while it plays a video of known length; the position is read every 100 ms while
  playing.
- `onComplete` once when the position reaches the duration, and again only after the position is
  back before it. A video that does not loop pauses on its last frame there; a looping one starts
  again from 0 without `onComplete`.
- `onError` with `{message}`, the failure's `localizedDescription`, when the video fails to load.

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

In a checkout of the monorepo, where the package builds against `../../../sdk-swift` by path:

```bash
cd plugins/orca_video_player/ios && swift test
```

They drive the plugin with a fake player, so they need no network. The "Native Plugins CI"
workflow also runs them on an iOS simulator.

## Versioning and releases

`VERSION` holds the package version. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh)
(the `orca_video_player-ios` package), never by hand. Its `orca_video_player-ios-v<X>` tag starts
the "SDK Swift Mirror" workflow, which copies `plugins/orca_video_player/ios/` to
orca-video-player-swift with `git subtree split`, tags it `<X>` there and builds a package that
imports `OrcaVideoPlayer` at that tag, for macOS and the iOS simulator.

## License

[Business Source License 1.1](LICENSE), as the rest of Orca Gateway.
