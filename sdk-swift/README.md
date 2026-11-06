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
the page's navigation:

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
