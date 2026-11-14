# iOS example: Orca Counter

The counter example drawn by the **alpha** Swift SDK (`sdk-swift/`, Epic 23b) against the
same Bun server as the Flutter example. The project depends on the SDK through a local path
(`../../sdk-swift`), so a change to the SDK shows up on the next build. Your own app installs the
published package instead; see "Install" in [`sdk-swift/README.md`](../../sdk-swift/README.md).

## Run it

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

2. Open `examples/app-ios/OrcaCounter.xcodeproj` in Xcode 16 or later, pick an iPhone simulator
   and press Run. The simulator reaches the Mac at `localhost`, so nothing else is needed.

   Or build from the terminal:

   ```bash
   task example:ios:build
   ```

If port 8080 is taken, start the server on another one (`PORT=8097 bun run index.ts` in
`examples/server`) and point the app at it: enable `ORCA_SERVER_URL` in the scheme's environment
variables in Xcode, or pass `SIMCTL_CHILD_ORCA_SERVER_URL=http://localhost:8097` to
`xcrun simctl launch`.

## Other example apps

The same app draws any app on the example server. Enable `ORCA_APP_ID` and `ORCA_PATH` in the
scheme, or pass them to `simctl launch`:

| App | `ORCA_APP_ID` | `ORCA_PATH` | Shows |
|---|---|---|---|
| Counter (default) | `counter` | `home` | state, a snackbar |
| Basic actions | `basic-actions` | `home` | navigation, back, URL, clipboard, share, toasts |
| Server actions | `server-actions` | `shop` | actions that run on the server and change the page |
| Todo | `todo` | `home` | add, tick, delete |

```bash
SIMCTL_CHILD_ORCA_APP_ID=server-actions SIMCTL_CHILD_ORCA_PATH=shop xcrun simctl launch booted com.orcagateway.examples.counter
```

## DevTools

Debug builds connect to Orca DevTools on `ws://localhost:6363` (start it with `task devtools:dev`)
and show up as "Orca Counter": network requests, page timing, state changes, actions, rebuilds and
errors. Set `ORCA_DEVTOOLS=0` to turn it off, or `ORCA_DEVTOOLS_HOST` to the Mac's address when the
app runs on a device.

## What it shows

`+` and `-` change the count; `Reset` sets it to 0 and shows a snackbar. The page, the state and the
actions all come from `examples/server/counter.ts`; the app holds no logic beyond the server URL.
On the first request the SDK goes through the capability handshake (a 412, then one retry with its
capability vector), as the Flutter SDK does.
