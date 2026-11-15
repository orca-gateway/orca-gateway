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
| Todo | `todo` | `home` | add, tick, delete |

```bash
task example:android:run APP=basic-actions PAGE=home
task example:android:run APP=server-actions PAGE=shop
task example:android:run APP=capability-demo PAGE=degrade
task example:android:run APP=native-widgets PAGE=home
task example:android:run APP=todo PAGE=home
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

### The navigation demo: booting from the server config

The apps above start at the page you pass. An app with a navigation config can instead boot from
it: the app asks the server for `/config`, seeds the config's `initialAppState` and opens its
`initialRoute`, and every location goes through the config's routes (parameters, nested routes,
redirects, a "Page not found" page for an unknown one). The `navigation` app in
`examples/server/navigation.ts` is made for it. Set the extra `ORCA_BOOT` to `config`; `ORCA_PATH`
is then not used. The host then calls `OrcaApp(client, path = null)`: a host that passes a path, or
none at all (`OrcaApp(client)` opens `home`), fetches no config:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity \
  --es ORCA_APP_ID navigation --es ORCA_BOOT config
```

It starts logged out on its welcome page; the protected route sends you to the login page until
you log in. A route that is not one of the tabs is drawn under a top bar with a back arrow and
the page's title. The tab bar itself is not drawn yet: the app runs as one stack.

| Extra | Type | Default | What |
|---|---|---|---|
| `ORCA_BOOT` | string | `path` | `config` boots from the server's navigation config; anything else starts at `ORCA_PATH` |

## Force update and sessions

Two boolean extras turn on `OrcaApp`'s `enableOffline` and `enableSessionTracking`. The run task
does not pass them: install the app once with `task example:android:run`, then start it with
`adb shell am start`. `-S` stops the running app first, so the new extras apply.

| Extra | Type | Default | What |
|---|---|---|---|
| `ORCA_OFFLINE` | boolean | off | ask the server's `/version` before the first page |
| `ORCA_SESSIONS` | boolean | off | send a session start and end as the app comes and goes |

**Force update.** With `ORCA_FORCE_UPDATE=1` the server's static-flows app answers `/version` with
`forceUpdate: true`. Start the server that way, then that app with the check on:

```bash
ORCA_FORCE_UPDATE=1 task example:dev:server
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity \
  --ez ORCA_OFFLINE true --es ORCA_APP_ID static-flows --es ORCA_PATH home
```

The app shows a spinner, then "Update required. Please update the app.", and loads no page. The SDK
draws that screen itself; the "Update required" page of `ORCA_MIN_SDK_VERSION` above is one the
server sends. Without `ORCA_OFFLINE` the app never asks `/version` and shows the home page. Restart
the server without `ORCA_FORCE_UPDATE` and the check passes: the home page shows too.

**Sessions.** Start any app with tracking on, the counter here:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --ez ORCA_SESSIONS true
```

The server's console prints `[Orca Gateway] Session started device=<id>`. Send the app to the
background (Home, or `adb shell input keyevent KEYCODE_HOME`): about a second later it prints
`[Orca Gateway] Session ended device=<id>`. Bring the app back from the recent apps: a new
`Session started`. A rotation ends nothing. Each one is also a `request_start` and `request_end`
line with `"path":"/session"`. The id stays the same: the SDK saves it on first run.

To see the offline queue, stop the server while the app is open, send the app to the background,
start the server again and bring the app back. The end that failed was queued: the console prints
`Session started`, then `Offline sessions registered: device=<id> count=1`.

Not there yet: `ORCA_OFFLINE` runs only the version check. The offline cache of static flows and
`preload()` arrive with plan step 14, so with the server down the app still cannot load a page.

Both extras work with `ORCA_BOOT config` too: the version check then comes before `/config`, and a
force update fetches neither the config nor a page.

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
actions all come from `examples/server/counter.ts`; the app holds no logic beyond the settings it
reads from intent extras. On the first request the SDK goes through the capability handshake (a
412, then one retry with its capability vector), as the Flutter and Swift SDKs do.

Debug builds allow plain HTTP for the example server and DevTools; release builds keep Android's
HTTPS-only default.
