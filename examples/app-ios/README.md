# iOS example: Orca Counter

The counter example drawn by the **experimental** Swift SDK (`sdk-swift/`, Epic 23b) against the
same Bun server as the Flutter example. The project depends on the SDK through a local path
(`../../sdk-swift`), so a change to the SDK shows up on the next build.

## Run it

1. Start the example server (it listens on `http://localhost:8080`):

   ```bash
   task example:dev:server
   ```

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

## What it shows

`+` and `-` change the count; `Reset` sets it to 0 and shows a snackbar. The page, the state and the
actions all come from `examples/server/counter.ts`; the app holds no logic beyond the server URL.
On the first request the SDK goes through the capability handshake (a 412, then one retry with its
capability vector), as the Flutter SDK does.
