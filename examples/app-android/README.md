# Android example: Orca Counter

The counter example drawn by the **alpha** Kotlin SDK (`sdk-kotlin/`, Epic 23b) against the
same Bun server as the Flutter and iOS examples. The SDK's alpha is on Maven Central as
`com.orcagateway:sdk`, but this example does not use it: its Gradle build includes
`../../sdk-kotlin` (`includeBuild` in `settings.gradle.kts`), so it builds the SDK from source and an
SDK change shows up on the next build. Your own app installs the published artifact instead; see
"Install" in [`sdk-kotlin/README.md`](../../sdk-kotlin/README.md#install).

## Run it

You need Android Studio (or the Android SDK command-line tools) with an emulator, and JDK 17 or
later.

1. Start the example server (it listens on `http://localhost:8080`):

   ```bash
   task example:dev:server
   ```

2. Start an emulator, for example the Pixel 3a API 34 image, from Android Studio's Device Manager
   or with `emulator -avd <name>`.

3. Install and start the app:

   ```bash
   task example:android:run
   ```

   Or open `examples/app-android` in Android Studio and press Run. The emulator reaches the Mac at
   `10.0.2.2`, which is the app's default server.

If port 8080 is taken, start the server on another one (`PORT=8097 bun run index.ts` in
`examples/server`) and pass its URL:

```bash
task example:android:run URL=http://10.0.2.2:8097
```

`task example:android:run` passes the server URL, app id and path as intent extras
(`ORCA_SERVER_URL`, `ORCA_APP_ID`, `ORCA_PATH`); you can send the same extras with
`adb shell am start`.

## Other example apps

The same app draws any app on the example server. Pass `APP` and `PAGE` to the run task:

| App | `APP` | `PAGE` | Shows |
|---|---|---|---|
| Counter (default) | `counter` | `home` | state, a snackbar |
| Basic actions | `basic-actions` | `home`, `about`, `product`, `ecommerce`, `checkout` | navigation, back, URL, clipboard, share, toasts |
| Server actions | `server-actions` | `shop` | actions that run on the server and change the page |
| Capability demo | `capability-demo` | `degrade` | the three fallback policies, on a Checkbox this SDK does not draw: left out (`graceful`), a warning banner above the page (`warn`), or a blocking prompt instead of the page (`require`) |
| Native widgets | `native-widgets` | `home` | the ten widgets of S9: Icon, Image, Container, Expanded, Spacer, TextField, Stack, Positioned, ClipRRect, GestureDetector (the images come from picsum.photos) |

```bash
task example:android:run APP=basic-actions PAGE=home
task example:android:run APP=server-actions PAGE=shop
task example:android:run APP=capability-demo PAGE=degrade
task example:android:run APP=native-widgets PAGE=home
```

Basic actions starts at `home`, which opens the four other pages; `PAGE` starts the app on one of
them directly. The back gesture (or a page's back button) returns to the page before. Open URL
and share hand off to the browser and the share sheet; copy puts the text on the clipboard.

The `degrade` page shows the policy the server was started with, `graceful` by default. To try the
others, restart the server with `ORCA_FALLBACK_POLICY`, then start the app again. With
`ORCA_MIN_SDK_VERSION=99.0.0` every page of every app answers 426 instead, and the app draws the
"Update required" page; restart the server without it to go back.

```bash
ORCA_FALLBACK_POLICY=warn task example:dev:server      # or =require
ORCA_MIN_SDK_VERSION=99.0.0 task example:dev:server
```

## DevTools

Debug builds connect to Orca DevTools on port 6363 of the Mac (start it with `task devtools:dev`)
and show up as "Orca Counter": network requests, page timing, state changes, actions, rebuilds and
errors. The emulator reaches the Mac at `10.0.2.2`, so nothing else is needed. Two intent extras
change that:

| Extra | Type | Default | What |
|---|---|---|---|
| `ORCA_DEVTOOLS` | boolean | on in debug builds, off in release builds | connect to DevTools or not |
| `ORCA_DEVTOOLS_HOST` | string | `10.0.2.2` | the Mac's address; on a device, its address on your network |

To turn DevTools off, restart the app with the extra. `-S` stops the running app first: the app
connects once per process, so a running app keeps its connection (a rotation does not open a
second one).

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --ez ORCA_DEVTOOLS false
```

Add `--es ORCA_APP_ID server-actions --es ORCA_PATH shop` (or another app) as the run task does.
On a device, pass the Mac's address the same way (`--es ORCA_DEVTOOLS_HOST 192.168.1.20`), or run
`adb reverse tcp:6363 tcp:6363` and pass `localhost`.

## What it shows

`+` and `-` change the count; `Reset` sets it to 0 and shows a snackbar. The page, the state and the
actions all come from `examples/server/counter.ts`; the app holds no logic beyond the server URL
and the DevTools settings. On the first request the SDK goes through the capability handshake (a
412, then one retry with its capability vector), as the Flutter and Swift SDKs do.

Debug builds allow plain HTTP for the example server and DevTools; release builds keep Android's
HTTPS-only default.
