# Orca Gateway Example App

A Flutter app that demonstrates the Orca Gateway SDK rendering server-driven UI.

## Running

1. Start the demo server. Pick one:

   a. Docker:

   ```bash
   docker run --rm -p 8080:8080 ghcr.io/orca-gateway/demo-server:latest
   ```

   b. Download it for Linux, Windows or macOS from
   [the newest Engine release](https://github.com/orca-gateway/orca-gateway/releases?q=engine-v),
   then open it. Linux: `chmod +x demo-server-linux-x64` first, then run `./demo-server-linux-x64`.
   macOS: it comes as `demo-server-macos-arm64.zip`; unzip it in Finder. First start only, macOS:
   System Settings › Privacy & Security › Open Anyway. Windows: More info › Run anyway.

   c. From source, with Bun:

   ```bash
   task example:dev:server
   ```

   Ready when it prints `Orca demo server <version> on http://localhost:8080`.

2. Run the Flutter app:

   ```bash
   task example:dev:app
   ```

Or start both from source in one go (with DevTools):

```bash
task example:dev
```

## Configuration

The app connects to `http://localhost:8080` by default. To change the server URL, pass it as a build-time define:

```bash
flutter run --dart-define=BASE_URL=http://your-server:8080
```

## What It Demonstrates

- Server-driven page rendering with `OrcaPage`
- Navigation between server-defined routes
- State management (counters, forms, cart)
- Server actions with round-trip responses
- Plugin integration (maps, video)
