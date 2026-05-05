# Orca Gateway Example App

A Flutter app that demonstrates the Orca Gateway SDK rendering server-driven UI.

## Running

```bash
# Start both the example server and the Flutter app
task example:dev

# Or start them separately:
task example:dev:server   # Starts the engine on localhost:8080
task example:dev:app      # Runs the Flutter app
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
