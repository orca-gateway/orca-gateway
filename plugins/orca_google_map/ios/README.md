# Orca Gateway Google map for iOS (`OrcaGoogleMap`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The plugin is built on the alpha iOS SDK, and its API may still
> change between alphas. For production apps use the Flutter plugin
> ([`orca_google_map`](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_google_map)).

The map for iOS and macOS apps on the Orca Gateway Swift SDK: the `GoogleMap` widget, which draws
a map with pins with Apple's MapKit, and the `moveCamera` action that animates its camera. It is
the twin of the Flutter plugin `orca_google_map`: the same widget, props, triggers, action, params
and defaults, so a server page that shows a map in a Flutter app shows it here too. The map is
Apple's map, not Google's: see [Differences from Flutter](#differences-from-flutter).

The source lives in [`plugins/orca_google_map/ios/` of orca-gateway/orca-gateway](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_google_map/ios).
[orca-google-map-swift](https://github.com/orca-gateway/orca-google-map-swift) is a read-only copy
for Swift Package Manager, updated on each release; send issues and pull requests to the monorepo.

## Install

The package needs iOS 16 or macOS 13, as the SDK does. In Xcode: **File → Add Package
Dependencies…**, paste `https://github.com/orca-gateway/orca-google-map-swift.git`, set
**Dependency Rule** to **Up to Next Major Version** from `0.1.0-alpha.1`, and add the
`OrcaGoogleMap` library to your app target.

In a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/orca-gateway/orca-gateway-swift.git", from: "0.1.0-alpha.2"),
    .package(url: "https://github.com/orca-gateway/orca-google-map-swift.git", from: "0.1.0-alpha.1"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "OrcaGateway", package: "orca-gateway-swift"),
        .product(name: "OrcaGoogleMap", package: "orca-google-map-swift"),
    ]),
]
```

The package brings the SDK, [orca-gateway-swift](https://github.com/orca-gateway/orca-gateway-swift),
from `0.1.0-alpha.2`, the first SDK release with the plugin API. Your app's own rule for the SDK
must allow that version: an exact `0.1.0-alpha.1` does not resolve with the plugin. A rule whose
lower bound is an alpha, as `from: "0.1.0-alpha.2"`, also takes the alphas after it.

## Register

Pass `GoogleMapPlugin()` to `OrcaApp` with the rest of your plugins:

```swift
import OrcaGateway
import OrcaGoogleMap
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            OrcaApp(
                client: OrcaClient(baseURL: URL(string: "https://orca.example.com")!,
                                   appId: "counter", apiKey: "demo-key"),
                path: "home",
                plugins: [GoogleMapPlugin()])
        }
    }
}
```

`OrcaApp(router:)` takes `plugins:` too. The client adds the `GoogleMap` widget type and the
`moveCamera` action type to the capabilities it sends, so the server keeps the nodes that use them.

## No Google key

MapKit draws the map, so the package brings no Google SDK, and the app needs no Google Maps key.
The Flutter plugin's `orca_plugin.yaml` asks for a `GOOGLE_MAPS_IOS_API_KEY` in `Info.plist` and a
`GMSServices.provideAPIKey` call in the app delegate, which `orca plugin add` writes into a Flutter
app: Flutter's map on iOS is Google's. A native app adds neither.

## Location

`myLocationEnabled` shows the device's location on the map (MapKit's blue dot) once the app holds
location permission. The plugin never asks for it, as Flutter's does not. An app that sets
`myLocationEnabled` adds `NSLocationWhenInUseUsageDescription` to its `Info.plist`, since iOS gives
no location to an app without it, and asks for permission itself:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to show your position on the map</string>
```

```swift
import CoreLocation

// Kept as long as the app runs (a property of something long-lived): iOS answers later.
let locationManager = CLLocationManager()
locationManager.requestWhenInUseAuthorization()
```

The text is the one the Flutter plugin's `orca_plugin.yaml` gives; write your own. On macOS a
sandboxed app also turns on App Sandbox's Location. Without permission the map shows no dot and
works as before.

## The widget

| Prop | Type | Default | What it does |
|---|---|---|---|
| `latitude` | number | `0` | The first camera's latitude, read when the map is made; after that only `moveCamera` and the user move the camera. |
| `longitude` | number | `0` | The first camera's longitude, read when the map is made. |
| `zoom` | number | `14` | The first camera's zoom, Google's zoom level (the world 256 × 2^zoom points wide), turned into MapKit's region for the map's size; read when the map is made. |
| `mapType` | string | `"normal"` | `normal`, `satellite`, `terrain` or `hybrid`; any other string draws `normal`. MapKit has no relief map: `terrain` draws the standard map. |
| `myLocationEnabled` | boolean | `false` | Shows the device's location once the app holds location permission (see [Location](#location)). |
| `zoomControlsEnabled` | boolean | `true` | No effect: the map has no zoom buttons, as Flutter's has none on iOS. |
| `markers` | array | none | The map's pins, each an object of the fields below. An entry that is not an object, or lacks a number `latitude` or `longitude`, is skipped. |

| Marker field | Type | Default | What it does |
|---|---|---|---|
| `id` | string | `""` | What `onMarkerTap` fires as `markerId`; a value that is not a string is used as its text. |
| `latitude` | number | required | The pin's latitude. |
| `longitude` | number | required | The pin's longitude. |
| `title` | string | `""` | The callout's title. |
| `snippet` | string | none | The callout's text under the title. |

The map is an MKMapView that fills the box its parent gives it, as Flutter's map does: give it a
height, as the example's 300-high Container does. `mapType`, `myLocationEnabled` and `markers`
follow each update of the props; the camera props do not. A marker is a red pin, and a tap on it
opens a callout with its title and snippet (Google's info window). The plugin keeps each map under
its node id from when it is made until it leaves the screen.

While on screen it fires:

- `onTap` with `{latitude, longitude}`, the tapped point, on a tap off the pins and their callouts.
  It waits to see that the tap is not a double tap: a double tap zooms and fires nothing.
- `onLongPress` with `{latitude, longitude}`, the pressed point, once, as a long press begins.
- `onCameraMove` with `{latitude, longitude, zoom}`, the camera's centre and Google's zoom, again
  and again while the visible region changes, from a gesture or `moveCamera`'s animation; not as
  the map is placed at its first camera.
- `onMarkerTap` with `{markerId}` on each tap on a pin, the one already selected too; a tap on the
  callout fires nothing.

## The action

Every param is resolved as a value (a `V.pageState(...)` works). `targetId` is the map node's id,
the key the server gives it (the example's `.withKey("main-map")`); a value that is not a string is
used as its text. An empty or unknown `targetId`, or a map no longer on screen, does nothing, and
so does a missing `latitude` or `longitude`; a param that resolves to anything but a number fails
the action, as Flutter's cast does.

| Action | Params | What it does |
|---|---|---|
| `moveCamera` | `targetId` (required), `latitude` (required), `longitude` (required), `zoom` | Animates the map's camera to `latitude`, `longitude` at `zoom` (default 14), Google's zoom level. Fires no trigger itself; `onCameraMove` fires as the camera moves. |

A server page builds it, and the widget, with the TypeScript classes
`orca plugin generate --manifest orca_plugin.yaml` writes from the plugin's
[`orca_plugin.yaml`](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_google_map/orca_plugin.yaml).
The example server's `custom` app has a Map Page with a map of San Francisco and two markers, Texts
for what each trigger fired, a count of marker taps, and a Move Camera to NYC button
([`examples/server/custom.ts`](https://github.com/orca-gateway/orca-gateway/blob/main/examples/server/custom.ts)).

## Differences from Flutter

Flutter's plugin draws Google's map with google_maps_flutter; this one draws Apple's map, not
Google's, with MapKit. Its tiles, labels and pins are Apple's, and:

- `terrain` draws the standard map: MapKit has no relief map.
- `zoomControlsEnabled` has no effect, and Flutter's iOS map has no zoom buttons either.
- A tap on a marker does not centre the camera on it, as Google's map on iOS does.
- `moveCamera` keeps the map's rotation: a map the user turned stays turned, where Google's camera
  turns back north up.
- A prop or a marker field of the wrong type reads as absent: the prop takes its default, a marker
  with a coordinate that is not a number is skipped, a title that is not a string is empty and a
  snippet that is not a string is left out. Flutter's casts fail the map's build there.
- In a Column with nothing bounding its height, the map takes the Column's leftover height, where
  Flutter's map fails layout.

## Tests

In a checkout of the monorepo, where the package builds against `../../../sdk-swift` by path:

```bash
cd plugins/orca_google_map/ios && swift test
```

They drive the plugin through a fake map, and a real MKMapView in a window for the view's own
path: its region, pins, callouts and gestures. The "Native Plugins CI" workflow also runs them on
an iOS simulator.

## Versioning and releases

`VERSION` holds the package version. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh)
(the `orca_google_map-ios` package), never by hand. Its `orca_google_map-ios-v<X>` tag starts the
"SDK Swift Mirror" workflow, which copies `plugins/orca_google_map/ios/` to orca-google-map-swift
with `git subtree split`, tags it `<X>` there and builds a package that imports `OrcaGoogleMap` at
that tag, for macOS and the iOS simulator.

## License

[Business Source License 1.1](LICENSE), as the rest of Orca Gateway.
