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
| Custom extensions | `custom` | `home` | a widget and actions from the app's plugins; see [Plugins](#plugins) |

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
is then not used. The host then calls `OrcaApp` with no path (`OrcaApp(client)`, the default): a
host that passes a path fetches no config:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity \
  --es ORCA_APP_ID navigation --es ORCA_BOOT config
```

It starts logged out on its welcome page; the protected route sends you to the login page until
you log in. A route that is not one of the tabs is drawn under a top bar with a back arrow and
the page's title. A config with tabs is drawn with its tab bar, one page stack per tab; the
drawer follows in the same release.

The `tabs` app in `examples/server/tabs.ts` shows the tab bar: extras `ORCA_APP_ID=tabs`,
`ORCA_BOOT=config` (`--es ORCA_APP_ID tabs --es ORCA_BOOT config`).

| Extra | Type | Default | What |
|---|---|---|---|
| `ORCA_BOOT` | string | `path` | `config` boots from the server's navigation config; anything else starts at `ORCA_PATH` |

## Deep links

The manifest gives `MainActivity` an intent filter for the scheme `orcacounter` and
`android:launchMode="singleTop"`; the activity holds no link code: `OrcaApp` reads the Intent and
navigates to the link. A link needs routes to go to, so start one of the `ORCA_BOOT=config` demo
apps (`navigation` or `tabs`, above) first, then send a link:

```bash
adb shell am start -a android.intent.action.VIEW -d "orcacounter:///home/product/42" com.orcagateway.examples.counter
```

The SDK keeps the URL's path and query and drops the scheme and the host, so write the link with
three slashes: in `orcacounter://product/42`, `product` is the host and the location is `/42`. The
running app gets the link as a new Intent and keeps the extras it was started with. To open the
app with a link (a cold start), stop it (`adb shell am force-stop com.orcagateway.examples.counter`)
and add the extras to the command: `--es ORCA_APP_ID navigation --es ORCA_BOOT config`.

The host passes `onDeeplink` only to log a line per link:

```bash
adb logcat -s OrcaCounter
```

```
I OrcaCounter: deeplink: incoming=orcacounter:///home/product/42 resolvedLocation=/home/product/42 wasRedirected=false isColdStart=false
```

A location no route matches shows "Page not found"; a protected route of `navigation` redirects to
the login page while logged out (`wasRedirected=true`).

## Plugins

The app registers two plugins ([`DemoPlugins.kt`](app/src/main/kotlin/com/orcagateway/examples/counter/DemoPlugins.kt)),
as the Flutter example does: `BadgePlugin` draws the `ColoredBadge` widget of the example server's
`custom` app, and `DeviceActionsPlugin` runs its actions `hapticFeedback`, `showConfetti`, `rateApp`
and `processPayment`. Start the server (step 1 above), then the app on `custom`:

```bash
task example:android:run APP=custom PAGE=home
```

Once installed, `adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --es ORCA_APP_ID custom`
does the same.

The page "Custom Actions & Components" ends with three badges: a green "CUSTOM BADGE", a blue
"TAPS: 0" and an orange "RATE: ★★★★★". The server sends a ColoredBadge only to an app that
advertises it (in the default `graceful` mode it leaves the widget out), so seeing them means the
plugin's widget reached the capabilities. Tap the green badge: a "Badge tapped!" snackbar. "Trigger
Haptic" counts up "Haptics triggered" and the blue badge. A device plays the haptics; the emulator
has none, so each action is also logged:

```bash
adb logcat -s OrcaDemoPlugins
```

The green badge prints `hapticFeedback light`, "Trigger Haptic" `hapticFeedback heavy`. The example
has no confetti or store SDK, so the handlers behind "Show Confetti", "Rate This App", "Pay $29.99"
and the orange badge only log the action they get.

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

## Error screens, dark mode, locale and splash

Five more extras try what `OrcaApp` draws around the pages. Without them the app is as before. As
above, install it once with `task example:android:run`, then start it with `adb shell am start`.

| Extra | Type | Default | What |
|---|---|---|---|
| `ORCA_API_KEY` | string | `demo-key` | the API key the app sends; the server answers any other 401 |
| `ORCA_SCHEME` | string | unset: the app's light theme | `dark` or `light`: the Material 3 colours of the app and of `OrcaApp` |
| `ORCA_LOCALE` | string | unset: the device's | a language tag (`ar`, `fr-FR`), `OrcaApp`'s `locale` |
| `ORCA_SPLASH` | boolean | off | the app's own splash in place of the SDK's spinner while `OrcaApp` boots |
| `ORCA_TIMEOUT` | string | `30` | how long one request may take, in seconds |

**Error screens.** A page that fails to load shows the SDK's error screen, Flutter's: an icon, a
title, a line saying why, and "Try again". Start the counter on a page the server does not have,
with a wrong key, and with no server:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --es ORCA_PATH missing
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --es ORCA_API_KEY wrong
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity \
  --es ORCA_SERVER_URL http://10.0.2.2:9
```

The first shows "Not Found" under a magnifier with a cross, the second "Unauthorized" under a
padlock, the third "Connection Failed" under a crossed-out Wi-Fi sign: nothing listens on port 9.
Stopping the server does the same; start it again and tap "Try again": the page loads.

**Dark mode.** `ORCA_SCHEME` puts the app and `OrcaApp` on Material 3's dark (or light) colours:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --es ORCA_SCHEME dark \
  --es ORCA_SERVER_URL http://10.0.2.2:9
```

The spinner and then "Connection Failed" are drawn light on dark: the SDK's own screens follow the
scheme. A server page does not: without the URL extra the counter page stays light, as Flutter draws
a page's Scaffold in its default light theme.

**Locale.** `--es ORCA_LOCALE ar` (or `fr-FR`) gives `OrcaApp` that locale: its screens and pages
read it from `LocalConfiguration`. The example pages have nothing that changes with it, so they
look the same; the layout stays left to right, as Flutter's default localizations are, and the
server still gets the device's locale in `x-orca-locale`.

**Splash.** With `ORCA_SPLASH` the app draws its own splash, "Orca Counter" in white on blue with
"host splash" under it, where the SDK shows its spinner while it boots: during the version check
(`ORCA_OFFLINE`) and while `/config` is fetched (`ORCA_BOOT config`). A page opened at a path skips
both, so start the navigation app from its config with the check on:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --ez ORCA_SPLASH true \
  --ez ORCA_OFFLINE true --es ORCA_APP_ID navigation --es ORCA_BOOT config
```

The blue splash shows, then the Welcome page. From a server on your computer this takes a moment
only. Pages that load later, and a page's own reload, keep the SDK's spinner.

**Timeout.** The server's `addToCart` action on the `shop` page waits three seconds before it
answers. Give the app two:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --es ORCA_TIMEOUT 2 \
  --es ORCA_APP_ID server-actions --es ORCA_PATH shop
```

Tap "Add to Cart": after two seconds the snackbar says "Failed to add to cart. Try again." Without
the extra a request may take 30 seconds, and the same tap ends three seconds later with "Added 1x
Orca Gateway Pro License to cart!". A page request that runs out of time shows "Connection Failed".

**Placeholder.** The `placeholder` page of the capability demo shows two UnsupportedWidgetPlaceholder
cards, the grey card for a widget an app knows but cannot run on its platform. The first sets every
prop ("Google Maps", a map icon, a reason and "Learn more"); the second only the widget type, so
the SDK's defaults show:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity \
  --es ORCA_APP_ID capability-demo --es ORCA_PATH placeholder
```

## DevTools

Debug builds connect to Orca DevTools on port 6363 of the Mac (start it with `task devtools:dev`)
and show up as "Orca Counter": network requests, page timing, state changes, actions, rebuilds and
errors. The emulator reaches the Mac at `10.0.2.2`, so nothing else is needed. Four intent extras
change that:

| Extra | Type | Default | What |
|---|---|---|---|
| `ORCA_DEVTOOLS` | boolean | on in debug builds, off in release builds | connect to DevTools or not |
| `ORCA_DEVTOOLS_HOST` | string | `10.0.2.2` | the Mac's address; on a device, its address on your network |
| `ORCA_OVERLAY` | boolean | off | draw the load chip at the bottom right of each page |
| `ORCA_BODIES` | boolean | off | send request and response bodies in DevTools' network events |

`ORCA_OVERLAY` and `ORCA_BODIES` do nothing while DevTools is off.

To change any of them, restart the app with the extra. `-S` stops the running app first, and it
matters: the app starts DevTools once per process. Without `-S`, `am start` hands the intent to
the running activity (it is `singleTop`), which keeps the settings it started with; and while
DevTools is on, a new activity in the same process (after a rotation, or Back and a relaunch)
neither opens a second connection nor reads these extras again.

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --ez ORCA_DEVTOOLS false
```

**The load chip.** Start the app with the overlay on:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --ez ORCA_OVERLAY true
```

Each page shows a small black chip 8 dp in from its bottom right corner with the page's load time
in green, for example `84ms` (from the request start to the render). Tap it: it shows
`Load: 84.3ms`, `Components: <the page's node count>` and `Cache: -`. Tap again to fold it.

**Bodies.** Start the app with bodies on:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --ez ORCA_BODIES true
```

In DevTools, open Network, pick a request and its Body tab: a page request shows the page JSON the
server sent back. Its event also carries the app state the app sent (`requestBody`); the Body tab
shows the request body only for a request that got no answer. Without the extra, the Body tab says
bodies are not captured. The `Authorization` header (the app's API key) shows as `<redacted>` either way.

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
