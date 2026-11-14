# Example Servers

Working server implementations demonstrating Orca Gateway engine features.

## Running

Start the demo server. Pick one:

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

To start all examples from source (server + Flutter app):

```bash
task example:dev
```

The server runs on `http://localhost:8080` by default.

## Examples

| File                  | Description                                                  |
| --------------------- | ------------------------------------------------------------ |
| `counter.ts`          | Basic counter with page state and increment/decrement actions |
| `ecommerce.ts`        | Product listing with cart, checkout flow, and server actions   |
| `animations.ts`       | Tween animations, sequences, and animated transitions         |
| `basic-actions.ts`    | Navigate, SetState, CopyToClipboard, OpenUrl, ShowSnackbar    |
| `server-actions.ts`   | Server-side action handlers with request round-trips          |
| `static-flows.ts`     | Offline-capable static flow definitions with versioning       |
| `capability-demo.ts`  | Capability negotiation and safe degradation fallbacks         |
| `custom.ts`           | Custom widget types and custom action handlers                |
| `orca_google_map.ts`  | Google Maps integration via the map plugin                    |
| `index.ts`            | Entry point — registers all examples into a single engine     |
