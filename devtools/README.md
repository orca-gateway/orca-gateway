# Orca Gateway DevTools

A desktop debugger for [Orca Gateway](https://github.com/orca-gateway/orca-gateway). Connects to a running engine over WebSocket and inspects pages, state, actions, and the wire format in real time.

## Install

Pre-built binaries are published on the [Releases page](https://github.com/orca-gateway/orca-gateway/releases) for macOS, Windows, and Linux.

- **macOS**: download the `.dmg`, drag to Applications, launch. (Signed and notarized.)
- **Windows**: download the `.zip`, extract, run `orca_gateway_devtools.exe`. Windows SmartScreen will warn on first launch — click "More info" → "Run anyway".
- **Linux**: download the tarball, extract, run `./orca_gateway_devtools`.

## Build from source

Requires Flutter 3.24+ with desktop platforms enabled.

```sh
cd open-source/devtools
flutter pub get
flutter run -d macos     # or -d linux / -d windows
```

Release build:

```sh
flutter build macos --release
flutter build linux --release
flutter build windows --release
```

## License

BUSL-1.1 — see [LICENSE](LICENSE).
