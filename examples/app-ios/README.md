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
| Custom extensions | `custom` | `home` | a plugin widget and plugin actions (see "Plugins" below) |
| Saved state | `saved-state` | `home` | a count saved on the device or for the session (see "Saved state" below) |

```bash
SIMCTL_CHILD_ORCA_APP_ID=server-actions SIMCTL_CHILD_ORCA_PATH=shop xcrun simctl launch booted com.orcagateway.examples.counter
```

### Boot from the navigation config

The apps above start at a path the host gives. Set `ORCA_BOOT=config` and the host calls
`OrcaApp(client:path:)` with `path: nil`, so the app asks the server for its navigation config first
(this is what `OrcaApp(client:)` alone does; the host passes a path in the other mode): the
config's `initialRoute` is the first page, its `initialAppState` is seeded before that page is
requested, redirects apply, an unknown location shows "Page not found", and a route outside the
tabs gets a title bar with a back button. `ORCA_PATH` is not read in this mode. The `navigation`
demo app (`examples/server/navigation.ts`) is made for it:

```bash
SIMCTL_CHILD_ORCA_APP_ID=navigation SIMCTL_CHILD_ORCA_BOOT=config xcrun simctl launch booted com.orcagateway.examples.counter
```

The default `counter` app has no navigation config, which is why the default stays `ORCA_PATH=home`.

A config with tabs is drawn as a tab bar with one stack per tab: a tab's page is fetched on its first
visit and kept while another tab is shown, a tap on the selected tab pops it to its first page, and
a route outside the tabs covers the bar. A config with `tabBarComponents` gets the server's tab bar
in place of the system one. The drawer follows in the same release. The `tabs` demo app
(`examples/server/tabs.ts`) is made for it: `ORCA_APP_ID=tabs ORCA_BOOT=config`.

```bash
SIMCTL_CHILD_ORCA_APP_ID=tabs SIMCTL_CHILD_ORCA_BOOT=config xcrun simctl launch booted com.orcagateway.examples.counter
```

## Deep links

The app registers the URL scheme `orcacounter` (`Info.plist` beside the project, merged into the
generated one) and holds no link code: `OrcaApp` receives the link and navigates to it. A link
needs routes to go to, so launch one of the `ORCA_BOOT=config` demo apps (`navigation` or `tabs`,
above) first, then open a link:

```bash
xcrun simctl openurl <device id> "orcacounter:///home/product/42"
```

`<device id>` is the simulator's id from `xcrun simctl list devices`, or `booted`. The SDK keeps
the URL's path and query and drops the scheme and the host, so write the link with three slashes:
in `orcacounter://product/42`, `product` is the host and the location is `/42`.

A link also starts the closed app, but without the `SIMCTL_CHILD_*` settings, so on the default
`counter` app, which has no routes. To start a config demo app by a link, give the settings to the
simulator itself first (they stay until the simulator shuts down or `launchctl unsetenv`):

```bash
xcrun simctl spawn <device id> launchctl setenv ORCA_APP_ID navigation
xcrun simctl spawn <device id> launchctl setenv ORCA_BOOT config
# only for a server elsewhere: xcrun simctl spawn <device id> launchctl setenv ORCA_SERVER_URL http://<address>:8080
xcrun simctl terminate <device id> com.orcagateway.examples.counter
xcrun simctl openurl <device id> "orcacounter:///home/product/42"
```

The host passes `onDeeplink` only to log a line per link. It goes to the system log (`NSLog`),
because an app that a link started has no console. Start this before you open the link:

```bash
xcrun simctl spawn <device id> log stream --predicate 'eventMessage CONTAINS "OrcaCounter deeplink"'
```

```
OrcaCounter deeplink: incoming=orcacounter:///home/product/42 resolvedLocation=/home/product/42 wasRedirected=false isColdStart=false
```

`isColdStart=true` on the link that started the app. The Xcode console and
`simctl launch --console` show the line too.

A location no route matches shows "Page not found"; a protected route of `navigation` redirects to
the login page while logged out (`wasRedirected=true`).

## Plugins

The app registers two plugins, the Swift twins of the Flutter example's: `BadgePlugin` draws the
server's `ColoredBadge` widget in SwiftUI, and `DeviceActionsPlugin` runs the custom actions
`hapticFeedback`, `showConfetti`, `rateApp` and `processPayment`. Both are in
`OrcaCounter/OrcaCounterApp.swift`, passed as `OrcaApp(..., plugins: [...])`. To see them, start
the server (step 1 above) and launch the `custom` app:

```bash
SIMCTL_CHILD_ORCA_APP_ID=custom xcrun simctl launch --console booted com.orcagateway.examples.counter
```

Under "Custom Component" the page shows three badges: a green "CUSTOM BADGE", a blue "TAPS: 0" and
an orange "RATE: ★★★★★". The server leaves out widgets an app does not advertise, so a drawn badge
shows that the plugin added `ColoredBadge` to the app's capabilities. Then:

- Tap "CUSTOM BADGE": a light haptic and the snackbar "Badge tapped!".
- Tap "Trigger Haptic": a heavy haptic; "Haptics triggered: 1" and the blue badge reads "TAPS: 1".
- Tap "Show Confetti", "Rate This App" or "Pay $29.99": the console prints the action as
  `[DeviceActionsPlugin] {...}` (the example has no confetti or store SDK); rating and paying then
  show their snackbars.

The simulator plays no haptics; a device does.

## Version check and sessions

Two switches turn on what `OrcaApp` does besides drawing pages. `1` or `true` turns each on. Add
them in Xcode under Product › Scheme › Edit Scheme… › Run › Arguments › Environment Variables, or
pass them to `simctl launch` as `SIMCTL_CHILD_*`:

| Setting | Turns on |
|---|---|
| `ORCA_OFFLINE` | `enableOffline`: a version check before the first page; with `ORCA_BOOT=config` also the offline boot ("Offline" below) |
| `ORCA_SESSIONS` | `enableSessionTracking`: a session start and end as the app comes and goes |

Both work with `ORCA_BOOT=config` too: the version check then comes before the navigation config
is asked for, and a force update loads neither the config nor a page.

**Force update.** Start the server with `ORCA_FORCE_UPDATE=1` (from source:
`ORCA_FORCE_UPDATE=1 task example:dev:server`; Docker: add `-e ORCA_FORCE_UPDATE=1`), then launch
the `static-flows` app with the version check on:

```bash
SIMCTL_CHILD_ORCA_OFFLINE=1 SIMCTL_CHILD_ORCA_APP_ID=static-flows SIMCTL_CHILD_ORCA_PATH=home \
  xcrun simctl launch booted com.orcagateway.examples.counter
```

The app shows "Update required. Please update the app." and loads no page. Restart the server
without the flag and launch again: the "Home (Static)" page loads. Without `ORCA_OFFLINE` the app
never asks for the version, so the server flag changes nothing. Launched with `ORCA_BOOT=config`
and `ORCA_PRELOAD` ("Offline" below), the host shows its own plain "Update required" line instead,
and `OrcaApp` never starts.

**Sessions.** Launch with `SIMCTL_CHILD_ORCA_SESSIONS=1`. The server's console prints
`[Orca Gateway] Session started device=<id>` when the app comes to the foreground and
`[Orca Gateway] Session ended device=<id>` when it goes to the background (Device › Home in the
Simulator). The id is the app's device id, made on first run and kept. A start or end that cannot
reach the server is queued and sent on the next foreground; the server then prints
`[Orca Gateway] Offline sessions registered: device=<id> count=<n>`.

## Offline

With `ORCA_OFFLINE` and `ORCA_BOOT=config`, `OrcaApp` keeps what it needs to start with no network,
as the Flutter SDK does. The `static-flows` demo app (`examples/server/static-flows.ts`) is made for
it: one static flow, `main`, at version 4, whose `home` and `about` pages the server pre-renders into
the config, and a dynamic `profile` page it leaves out.

```bash
SIMCTL_CHILD_ORCA_BOOT=config SIMCTL_CHILD_ORCA_APP_ID=static-flows SIMCTL_CHILD_ORCA_OFFLINE=1 \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

Each start asks `/version` and compares the flow versions with the saved ones:

- Nothing saved yet, or a version moved: the app fetches `/config` and saves it with the static
  pages and the versions, in the app's Application Support/com.orcagateway.examples.counter/OrcaGateway.
- Every version matches: the saved config is used and `/config` is not asked for.
- `/version` fails (no network, the server down, an error answer): the app boots from the saved
  config. With nothing saved it shows Flutter's screen for it, "Something Went Wrong" and "An
  unexpected error occurred. Please try again.", with "Try again".

`home` and `about` then open from the saved pages with no request, visited or not. `profile` and
every other page go to the network. The saved config is the installed app's, not one per
`ORCA_APP_ID`: offline, the last one saved boots, whichever app saved it.

**Check it by hand.** Each launch is the command above, which quits a running copy first. The
server's console prints a `request_start` line per request, with its `"path"`.

1. Nothing saved: remove the app (`xcrun simctl uninstall booted com.orcagateway.examples.counter`)
   and install it again (Run in Xcode). With the server stopped, launch: an exclamation mark in a
   circle, "Something Went Wrong" and "An unexpected error occurred. Please try again.", with "Try
   again".
2. Start the server and launch: "Home (Static)" shows. The server got `/version` and `/config`,
   and no `/page/home`.
3. Launch again: only `/version` this time.
4. Stop the server and launch: "Home (Static)" shows. Tap "Go to About (also static)": "About
   (Static)" opens, though it was never shown before. Tap "Back to Home", then "Go to Profile
   (dynamic, always fresh)": "Could not load this page" with the connection error.
5. A version bump: start the server and launch once. Then change `version: 4` to `version: 5` in
   `examples/server/static-flows.ts`, restart the server (from source) and launch: the server
   gets `/config` again. Set it back to 4 after.

**The host's preload.** `ORCA_PRELOAD=1` (with `ORCA_BOOT=config` only) moves the offline boot into
the host, as Flutter's `OrcaApp.preload`: the app shows its own splash, "Checking version...",
awaits `preload(client:cache:)` over `FileKeyValueStore.applicationSupport()` (the store
`enableOffline` uses), then shows `OrcaApp(client:preloadedConfig:staticFlowManager:)` with that
config and cache, which asks for nothing and draws the first page at once. It implies the offline
cache, with or without `ORCA_OFFLINE`. A force update shows the host's plain "Update required"
line. The steps above give the same results with it, except step 1: there the host shows the
plain line "No network and no cached config available" (relaunch to try again).

```bash
SIMCTL_CHILD_ORCA_BOOT=config SIMCTL_CHILD_ORCA_APP_ID=static-flows SIMCTL_CHILD_ORCA_PRELOAD=1 \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

The host's code is `HostPreload` in `OrcaCounter/OrcaCounterApp.swift`.

## Saved state

The `saved-state` demo app (`examples/server/saved-state.ts`) tries `persistState` and
`clearState` ("Saved state" in [`sdk-swift/README.md`](../../sdk-swift/README.md)). Its page shows
a page-state count with the buttons "+1", "Save on device", "Save for this session" and "Forget",
an app-state visits count with "+1 and save", and "Leave this page", which opens another page whose
"Back home" opens this page again. A grey line under each button says what it does. The host
passes no `savedState:`, so `OrcaApp` saves in its own file store. Start the server (step 1 above;
from source if your demo server does not have this app yet), then launch:

```bash
SIMCTL_CHILD_ORCA_APP_ID=saved-state SIMCTL_CHILD_ORCA_PATH=home \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

Booted from its config, the steps below give the same results:

```bash
SIMCTL_CHILD_ORCA_APP_ID=saved-state SIMCTL_CHILD_ORCA_BOOT=config \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

The device copies are files in the app's Application
Support/com.orcagateway.examples.counter/OrcaGateway: `orca_saved_page_home` holds the count and
`orca_saved_app` the visits. To read one:

```bash
dir="$(xcrun simctl get_app_container booted com.orcagateway.examples.counter data)/Library/Application Support/com.orcagateway.examples.counter/OrcaGateway"
cat "$dir/orca_saved_page_home"
```

It prints the saved JSON, such as `{"count":3}`, or "No such file or directory" when nothing is
saved.

**Check it by hand.** Each launch is one of the two commands above, the same each time. It quits a
running copy first, so a launch is also a kill and relaunch. Start with nothing saved: a fresh
install, or `rm -f "$dir"/orca_saved_*` before a launch. Open the page again with "Leave this page"
and "Back home", not by going back: going back shows the page as you left it, unsaved count
included, because it was never set up again.

1. Launch: "Count: 0" and "Visits: 0".
2. Count up: tap "+1" three times: "Count: 3". Launch again: "Count: 0", as nothing was saved.
3. Save on device: tap "+1" three times, then "Save on device". `orca_saved_page_home` holds
   `{"count":3}`. Tap "+1" twice: "Count: 5", and the file still holds 3, as a save is a snapshot.
   Launch again: "Count: 3".
4. Session: tap "+1" ("Count: 4"), then "Save for this session". `orca_saved_page_home` is gone: a
   key keeps one saved copy, now the session's. Tap "+1": "Count: 5". Tap "Leave this page", then
   "Back home": "Count: 4", the session copy. Launch again: "Count: 0", as the session ended with
   the process.
5. Forget: tap "+1" twice, then "Save on device": "Count: 2", and the file holds `{"count":2}`. Tap
   "Forget": "Count:" with no number, and the file is gone. Tap "+1": "Count: 1" (an empty count
   adds from 0). Launch again: "Count: 0". "Forget" deletes a session copy too: tap "+1", "Save for
   this session" and "Forget", then "Leave this page" and "Back home": "Count: 0".
6. Visits: tap "+1 and save" twice: "Visits: 2", and `orca_saved_app` holds `{"visits":2}`. Tap
   "Leave this page", then "Back home": still "Visits: 2", as app state is shared and the page's
   initial 0 only fills an empty key. Launch again: "Visits: 2", restored at boot before the first
   page.

## Error screens, dark mode, locale and splash

Five more settings try what `OrcaApp` draws around the pages. Set them as the two above, in the
scheme or as `SIMCTL_CHILD_*`. Unset, the app runs as before:

| Setting | Default | Does |
|---|---|---|
| `ORCA_API_KEY` | `demo-key` | the client's API key; the example server answers any other with 401 |
| `ORCA_SCHEME` | unset: the system's | `dark` or `light`, passed as `OrcaApp(colorScheme:)` |
| `ORCA_LOCALE` | unset: the device's | a BCP-47 tag such as `ar` or `fr-FR`, passed as `OrcaApp(locale:)` |
| `ORCA_SPLASH` | off | `1` or `true`: the app's own splash, passed as `OrcaApp(splashView:)` |
| `ORCA_TIMEOUT` | unset: the SDK's 30 | the seconds a request may take, set as the client's `timeout` |

The app reads its settings at launch, and `simctl launch` leaves a running app as it is, so the
commands below add `--terminate-running-process`. Start the server first (step 1 above). Each error
screen is the SDK's `OrcaErrorView`: Flutter's error screen, with a "Try again" button added.

**Page not found.** A path the counter app does not have:

```bash
SIMCTL_CHILD_ORCA_PATH=missing \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

A magnifying glass, "Not Found" and "The requested page could not be found."

**Unauthorized.** A key the server does not know:

```bash
SIMCTL_CHILD_ORCA_API_KEY=wrong \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

A lock, "Unauthorized" and "Invalid or missing API key. Please check your configuration."

**Offline.** Stop the server and launch, or leave it running and point the app at a port nothing
listens on:

```bash
SIMCTL_CHILD_ORCA_SERVER_URL=http://localhost:9 \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

A crossed-out Wi-Fi sign, "Connection Failed" and "Unable to reach the server. Please check your
network and server status." With the server stopped, start it again and tap "Try again": the
counter loads.

**Dark mode.** `ORCA_SCHEME=dark` turns the SDK's own screens dark, the error screen and the
spinner. A server page's Scaffold stays light, as Flutter's default theme draws it, so try it on an
error screen:

```bash
SIMCTL_CHILD_ORCA_SCHEME=dark SIMCTL_CHILD_ORCA_PATH=missing \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

"Not Found" in white on black. `ORCA_SCHEME=light` keeps it light on a simulator in dark mode
(`xcrun simctl ui booted appearance dark`).

**Host splash and timeout.** A splash shows while the app waits for its first answer: the version
check (`ORCA_OFFLINE=1`) or the navigation config (`ORCA_BOOT=config`). Against the example server
that is a blink, so give the app a server that takes the request and never answers. In a second
terminal:

```bash
nc -l 8099
```

Then:

```bash
SIMCTL_CHILD_ORCA_SPLASH=1 SIMCTL_CHILD_ORCA_BOOT=config SIMCTL_CHILD_ORCA_TIMEOUT=5 \
  SIMCTL_CHILD_ORCA_SERVER_URL=http://localhost:8099 \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

`nc` prints the config request. The app shows its own splash: "Orca Counter" in large white letters
on indigo, and under it "host splash" with the locale its views get. Five seconds later the request
times out, "Connection Failed" shows and `nc` stops; start it again before the next launch. Without
`ORCA_SPLASH` the same wait shows the SDK's spinner, and without `ORCA_TIMEOUT` it lasts the SDK's
30 seconds.

**Locale.** Add `SIMCTL_CHILD_ORCA_LOCALE=fr-FR` (or `ar`) to the launch above: the splash caption
reads `host splash · fr-FR`, the locale `OrcaApp` gives every view under it. The example's pages
format no dates or numbers, so they look the same. The server still gets the device's locale in
`x-orca-locale`, as from Flutter.

**Placeholder card.** The `placeholder` page of the `capability-demo` app shows two
`UnsupportedWidgetPlaceholder` cards, the grey card a server sends for a widget that cannot run in
this app:

```bash
SIMCTL_CHILD_ORCA_APP_ID=capability-demo SIMCTL_CHILD_ORCA_PATH=placeholder \
  xcrun simctl launch --terminate-running-process booted com.orcagateway.examples.counter
```

The first card has every prop set: a map icon, "Google Maps", the reason and a "Learn more" link.
The second has only the widget type, so it shows the SDK's defaults: "OrcaGoogleMap" and "This
widget runs in the compiled mobile app and cannot preview here."

## DevTools

Debug builds connect to Orca DevTools on `ws://localhost:6363` (start it with `task devtools:dev`)
and show up as "Orca Counter": network requests, page timing, state changes, actions, rebuilds and
errors. Set `ORCA_DEVTOOLS=0` to turn it off, or `ORCA_DEVTOOLS_HOST` to the Mac's address when the
app runs on a device.

Two more switches, both off by default, are set the same way as the ones under "Version check and
sessions" (the scheme's environment variables, or `SIMCTL_CHILD_*` for `simctl launch`). `1` or
`true` turns each on:

| Setting | Turns on |
|---|---|
| `ORCA_OVERLAY` | `showOverlay`: a chip at the bottom right of each page with its load time |
| `ORCA_BODIES` | `includeBodies`: the request and response bodies in DevTools' network events |

**Overlay.**

```bash
SIMCTL_CHILD_ORCA_OVERLAY=1 xcrun simctl launch booted com.orcagateway.examples.counter
```

Each page shows a black chip 8 points in from its bottom right corner with the page's load time in
green, such as `42ms` (request start to render complete). Tap it for `Load: 42.3ms`,
`Components: <n>` and `Cache: -`; tap again to fold it. The chip needs DevTools on in the app, not
the DevTools window: it shows without `task devtools:dev` running, and `ORCA_DEVTOOLS=0` hides it.

**Bodies.**

```bash
SIMCTL_CHILD_ORCA_BODIES=1 xcrun simctl launch booted com.orcagateway.examples.counter
```

In DevTools, open Network, pick a request and its Body tab: it shows the response, for a page
request the page's JSON. The event also carries the request body (for a page request, the app
state the app sent). Without the switch the tab says "Bodies are not captured by default." The
`authorization`, `cookie`, `set-cookie`, `x-api-key` and `proxy-authorization` headers show as
`<redacted>` either way.

## What it shows

`+` and `-` change the count; `Reset` sets it to 0 and shows a snackbar. The page, the state and the
actions all come from `examples/server/counter.ts`; the app holds no logic beyond the server URL.
On the first request the SDK goes through the capability handshake (a 412, then one retry with its
capability vector), as the Flutter SDK does.
