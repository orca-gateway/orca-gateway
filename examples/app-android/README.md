# Android example: Orca Counter

The counter example drawn by the **alpha** Kotlin SDK (`sdk-kotlin/`, Epic 23b) against the
same Bun server as the Flutter and iOS examples. The SDK's alpha is on Maven Central as
`com.orcagateway:sdk`, but this example does not use it: its Gradle build includes
`../../sdk-kotlin` (`includeBuild` in `settings.gradle.kts`), so it builds the SDK from source and an
SDK change shows up on the next build. Your own app installs the published artifact instead; see
"Install" in [`sdk-kotlin/README.md`](../../sdk-kotlin/README.md#install). The voice recorder,
video player and Google map plugins come from source the same way: the build also includes
`../../plugins/orca_voice_recorder/android`, `../../plugins/orca_video_player/android` and
`../../plugins/orca_google_map/android` (see [Plugins](#plugins)).

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
| Capability demo | `capability-demo` | `degrade` | the three fallback policies, on a plugin widget no app registers: left out (`graceful`), a warning banner above the page naming it (`warn`), or a blocking prompt instead of the page (`require`) |
| Native widgets | `native-widgets` | `home` | the ten widgets of S9: Icon, Image, Container, Expanded, Spacer, TextField, Stack, Positioned, ClipRRect, GestureDetector (the images come from picsum.photos) |
| Todo | `todo` | `home` | add, tick, delete |
| Custom extensions | `custom` | `home` | a widget and actions from the app's plugins; see [Plugins](#plugins) |
| Saved state | `saved-state` | `home` | a count saved on the device or for the session, then forgotten; see [Saved state](#saved-state) |

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

The app registers five plugins. Two are its own ([`DemoPlugins.kt`](app/src/main/kotlin/com/orcagateway/examples/counter/DemoPlugins.kt)),
as the Flutter example has them: `BadgePlugin` draws the `ColoredBadge` widget of the example server's
`custom` app, and `DeviceActionsPlugin` runs its actions `hapticFeedback`, `showConfetti`, `rateApp`
and `processPayment`. The third is the voice recorder package's `VoiceRecorderPlugin`
([`plugins/orca_voice_recorder/android`](../../plugins/orca_voice_recorder/android)), which draws the
`VoiceRecorder` of the same app's Voice Page and records and plays back (see
[The voice recorder](#the-voice-recorder) below). The fourth is the video player package's
`VideoPlayerPlugin` ([`plugins/orca_video_player/android`](../../plugins/orca_video_player/android)),
which plays the `VideoPlayer` of the app's Video Page and runs its playback actions (see
[The video player](#the-video-player) below). The fifth is the Google map package's `GoogleMapPlugin`
([`plugins/orca_google_map/android`](../../plugins/orca_google_map/android)), which draws the
`GoogleMap` of the app's Map Page and runs its `moveCamera` action (see [The Google map](#the-google-map)
below). Start the server (step 1 above), then the app on `custom`:

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

### The voice recorder

`settings.gradle.kts` includes `../../plugins/orca_voice_recorder/android`, so the build substitutes
`com.orcagateway:orca-voice-recorder` from source, as it does the SDK (that build includes the same
`sdk-kotlin`, so both use one SDK build). `MainActivity` adds `VoiceRecorderPlugin(applicationContext)`
to its plugins. The app's own manifest does not name the microphone: `RECORD_AUDIO` comes from the
library's manifest through the manifest merger, and the recorder asks for it on the first Start.

The emulator's microphone is the Mac's only while "Virtual microphone uses host audio input" is on,
in the emulator's Extended controls (the `...` button of its toolbar) › Microphone. Turn it on
before you start.

On the `custom` home page, tap "Go to Voice Page" (or start the app on it directly:
`adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --es ORCA_APP_ID custom --es ORCA_PATH voice`).
The "Voice Recorder" page shows a grey dot over "Ready", the buttons Start, Stop and Play, and the
"Saved to:" and "Duration:" lines under them. Then:

1. **Start.** Android asks once whether Orca Counter may record audio: allow it ("While using the
   app"). The dot turns red, the label reads "Recording", and a green bar under the dot moves with
   the Mac's microphone. A refusal records nothing and shows no message, as the Flutter plugin does.
2. **Stop.** The dot turns grey and the label reads "Ready"; under the buttons, "Saved to:" shows the
   recording's path (an `orca_recording_demo_<time>.m4a` in the app's cache directory) and
   "Duration:" its length in ms.
3. **Play.** The recording plays back. A playback that fails logs a line under the tag
   `OrcaVoiceRecorder` (`adb logcat -s OrcaVoiceRecorder`).

### The video player

`settings.gradle.kts` includes `../../plugins/orca_video_player/android` too, so the build substitutes
`com.orcagateway:orca-video-player` from source on the same `sdk-kotlin` build. Its directory is also
called `android`, and two included builds cannot share the build path `:android`, so this one takes its
root project's name, `orca-video-player-android`. `MainActivity` adds `VideoPlayerPlugin()` to its
plugins. The app's own manifest is unchanged: the player needs only `INTERNET`, which comes from the
library's manifest through the manifest merger and is granted at install, so nothing is asked.

The page streams the video_player package's example video (`butterfly.mp4` from
`flutter.github.io`, over https), so the emulator must be online. Without the network the player
shows "Video failed to load" in its place.

On the `custom` home page, tap "Go to Video Page" (or start the app on it directly:
`adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --es ORCA_APP_ID custom --es ORCA_PATH video`).
The "Video Player" page shows a small grey circle while the video loads, then the video with a dark
round button and a white ▶ over it. Under it are the buttons Play, Pause and Seek 0, then Volume 0.5
and Speed 1.5, and the lines "Position: 0 ms" and "Finished: false". Then:

1. **Tap the video.** It plays and the ▶ goes away; "Position:" counts up in steps of about 100 ms
   (the player's `onProgress`, kept in page state). Tap it again: it pauses and the ▶ comes back.
   Only these taps fire `onPlay` and `onPause`, as in the Flutter plugin.
2. **Play and Pause.** The buttons do the same through the `playVideo` and `pauseVideo` actions, the
   ▶ included. "Position:" moves only while the video plays.
3. **Seek 0.** The video goes back to its start; while it plays, "Position:" starts again from about
   0 ms.
4. **Volume 0.5 and Speed 1.5.** The sound drops to half (the emulator plays it on the Mac's
   speakers). The video plays one and a half times as fast, and "Position:" climbs that much faster;
   a speed set while paused applies on the next play.
5. **The end.** The clip is 7.5 s long. At its end the video stops on its last frame, the ▶ comes
   back and the line reads "Finished: true". Play or a tap starts it again from 0; "Finished:" stays
   true.

### The Google map

`settings.gradle.kts` includes `../../plugins/orca_google_map/android` as well, so the build substitutes
`com.orcagateway:orca-google-map` from source on the same `sdk-kotlin` build. Its directory is called
`android` too, so it takes its root project's name, `orca-google-map-android`, as the video player's
does. `MainActivity` adds `GoogleMapPlugin()` to its plugins. The location permissions
`ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` come from the library's manifest through the
manifest merger. Neither the app nor the plugin asks for them, as the Flutter plugin does not.

The map is Google's (Maps Compose on Google Play services), so the emulator image must have Google Play
(the Pixel images marked "Google Play" in the Device Manager). Google draws the map's tiles only with a
Google Maps API key, and the key is yours: put it in `examples/app-android/local.properties` (create
the file if it is missing), then build and install again:

```properties
GOOGLE_MAPS_ANDROID_API_KEY=<your key>
```

`app/build.gradle.kts` reads it into the manifest's `com.google.android.geo.API_KEY` meta-data.
`local.properties` is git-ignored, so the key is never committed. Google's
[Set up an API key](https://developers.google.com/maps/documentation/android-sdk/get-api-key) says how
to get one: a Google Cloud project with the Maps SDK for Android enabled, and a key restricted to Android
apps with the package `com.orcagateway.examples.counter` and the SHA-1 of the debug signing key, which
`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android` prints.

Without a key the page still opens, with no crash. Google logs "Authorization failure"
(`adb logcat -s "Google Maps Android API"`) and the map stays a plain grey box with the Google logo and
the zoom buttons. On the API 34 Google Play image tried here (Google Play services 23.18, which loads
Google's legacy map renderer) it then draws no pins and its camera does not move: drags, the zoom
buttons and "Move Camera to NYC" leave it on San Francisco, and the "Camera moved to" lines stay 0. Taps
and long presses still report their coordinates.

The page sets `myLocationEnabled`, so the map shows the device's position once the app holds a location
permission. Grant it and give the emulator a position before you open the page (`geo fix` takes the
longitude first; the emulator's Extended controls › Location does the same):

```bash
adb shell pm grant com.orcagateway.examples.counter android.permission.ACCESS_FINE_LOCATION
adb emu geo fix -122.4194 37.7749
```

On the `custom` home page, tap "Go to Map Page" (or start the app on it directly:
`adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --es ORCA_APP_ID custom --es ORCA_PATH map`).
The "Map Integration" page shows a map 300 high around San Francisco with the zoom buttons at its
bottom right. Under it are the lines "Map tapped on lat", "Map tapped on lng", "Long press at lat",
"Long press at lng", "Camera moved to lat", "Camera moved to lng", "Camera moved to zoom", "Marker
tapped:" and "Marker taps: 0", then the button "Move Camera to NYC".

With a key, expect the walk below. It has not been tried here: no key was available. The steps follow
the Flutter plugin and Maps Compose, and the iOS demo's walk, on Apple's map, was seen.

1. **The pins.** A red pin on San Francisco at the centre. Oakland's is off the map's right edge,
   across the bay: drag the map most of its width to the left to see it.
2. **Tap a pin.** Its info window opens over it ("San Francisco" and "This is SF!"), Google centres the
   map on it, and the lines read "Marker tapped: marker1" and "Marker taps: 1". Tap the same pin again:
   "Marker taps:" counts 2. Google fires `onMarkerTap` on every tap, as the Flutter plugin does.
3. **Tap off the pins.** The info window closes and "Map tapped on lat" and "lng" show the point.
4. **Long press.** "Long press at lat" and "lng" show the point.
5. **Pan or zoom.** Drag the map or use + and -: the three "Camera moved to" lines follow the camera
   while it moves.
6. **Move Camera to NYC.** The map animates to New York at zoom 14, and the "Camera moved to" lines end
   on about 40.7128, -74.006 and 14.
7. **Your location.** With the permission granted, a blue dot marks the emulator's position and Google's
   my-location button sits at the top right; it moves the camera there.

One difference from the Flutter plugin does not show on this page: a prop of the wrong type takes its
default, where Flutter fails the map's build.

## Offline, force update and sessions

Two boolean extras turn on `OrcaApp`'s `enableOffline` and `enableSessionTracking`, and a third
makes the host run the offline boot itself. The run task does not pass them: install the app once
with `task example:android:run`, then start it with `adb shell am start`. `-S` stops the running
app first, so the new extras apply, and the next launch is a cold start.

| Extra | Type | Default | What |
|---|---|---|---|
| `ORCA_OFFLINE` | boolean | off | ask the server's `/version` before the first page; with `ORCA_BOOT config`, also save the config and its static pages, and boot from them when the server cannot be reached |
| `ORCA_PRELOAD` | boolean | off | with `ORCA_BOOT config` only: the host awaits `preload` under its own splash, then gives `OrcaApp` the config; implies the offline cache |
| `ORCA_SESSIONS` | boolean | off | send a session start and end as the app comes and goes |

**Offline.** The example server's `static-flows` app has one static flow, `main`, at version 4:
its `home` and `about` pages come pre-rendered in `/config`, and `profile` is a dynamic route
(`isDynamic`), which never does. Boot it from its config with the offline cache on:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity \
  --ez ORCA_OFFLINE true --es ORCA_APP_ID static-flows --es ORCA_BOOT config
```

The app shows a spinner, then "Home (Static)". At boot the SDK asks `/version` and compares the flow
versions in the answer with the ones it saved (none yet), then fetches `/config` and saves it with
the pages of `home` and `about` (files in the app's `files/orca_gateway`). Those two pages then open
with no request, `about` too though it was never visited; `profile` is asked of the server each
time. The server's console shows it: `request_start` lines for `"path":"/version"` and
`"path":"/config"`, none for `/page/home`. Launch again with the same command: only `/version` this
time. The versions match, so the saved config is used and `/config` is not asked.

To check it offline:

1. Boot once with the server up (the command above).
2. Stop the server, then launch again with the same command. `/version` fails, so the app boots
   from the saved config: "Home (Static)" opens, "Go to About (also static)" opens
   "About (Static)", and "Go to Profile (dynamic, always fresh)" shows "Connection Failed" under
   a crossed-out Wi-Fi sign: a dynamic page is never cached.
3. With nothing saved the boot fails. Clear the app's data and launch again, the server still
   down: Flutter's screen for it, "Something Went Wrong" under a circled exclamation mark, with
   "An unexpected error occurred. Please try again." and "Try again".

   ```bash
   adb shell pm clear com.orcagateway.examples.counter
   ```

4. A new flow version fetches the config again. Start the server from source (`task
   example:dev:server`, which restarts when a file is saved), launch once, then set `version: 4`
   to `version: 5` in `examples/server/static-flows.ts` and launch again: the console shows
   `/version`, then `/config`, and the pages are saved again. Set it back to 4 when done (that is
   a new version too: one more fetch).

**The host's preload.** `ORCA_PRELOAD` boots the same way, run by the host
([`PreloadedApp` in `MainActivity.kt`](app/src/main/kotlin/com/orcagateway/examples/counter/MainActivity.kt)):
it shows its own splash, a spinner over "Checking version...", awaits `preload(client, manager)`
with a `StaticFlowManager` over `offlineStore(context)`, then shows `OrcaApp` with
`preloadedConfig` and that manager. `OrcaApp` then asks no `/version` and no `/config` of its
own, and the home page comes from the cache. The manager is over the files `ORCA_OFFLINE` uses, so
the two boots share one cache, and `ORCA_OFFLINE` adds nothing to this one.

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity \
  --ez ORCA_PRELOAD true --es ORCA_APP_ID static-flows --es ORCA_BOOT config
```

The offline check above holds as it is, with two texts of the host's own: with nothing saved and
the server down, the plain line "No network and no cached config available" (the message of the
`OfflineBootException` that `preload` throws); with `ORCA_FORCE_UPDATE=1` (below), a plain
"Update required", which `OrcaApp` never sees, as in Flutter. With a path (no `ORCA_BOOT config`)
the extra is ignored: there is no config to preload.

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

`ORCA_OFFLINE` and `ORCA_SESSIONS` work with `ORCA_BOOT config` too: the version check then comes
before `/config`, and a force update fetches neither the config nor a page.

## Saved state

The example server's `saved-state` app ([`saved-state.ts`](../server/saved-state.ts)) tries
`persistState` and `clearState`. Its home page shows a page-state count and an app-state visits
count, each 0 when nothing is saved, and "Leave this page" opens a second page whose "Back home"
opens the home page again. The app gives `OrcaApp` no `savedState`, so the SDK saves in the app's
`files/orca_gateway`, beside the offline cache. Install the app once with
`task example:android:run`, clear its data so nothing is saved, then start it on the app:

```bash
adb shell pm clear com.orcagateway.examples.counter
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity \
  --es ORCA_APP_ID saved-state --es ORCA_PATH home
```

"Launch again" below is the `am start` command again: `-S` force-stops the app first, so the
process ends and the next launch is a new one. Each saved entry is a file, which a debug build
lets you read:

```bash
adb shell run-as com.orcagateway.examples.counter ls files/orca_gateway
adb shell run-as com.orcagateway.examples.counter cat files/orca_gateway/orca_saved_page_home
```

1. **Count up.** "Count: 0" and "Visits: 0" show. Tap "+1" three times: "Count: 3". Launch again:
   "Count: 0". "+1" alone saves nothing.
2. **Save on device.** Tap "+1" three times, then "Save on device", then "+1" once more:
   "Count: 4". Launch again: "Count: 3", the value at the save. A save is a snapshot: the later
   "+1" was not saved. The `cat` prints `{"count":3}`.
3. **Session.** Tap "+1" ("Count: 4"), then "Save for this session". Tap "Leave this page", then
   "Back home": the home page is set up again and shows "Count: 4", the session copy. Launch
   again: "Count: 0". The session copy ended with the process, and saving for the session removed
   the copy on the device: `ls` shows no `orca_saved_page_home`.
4. **Forget.** Tap "+1" twice and "Save on device" ("Count: 2"), then launch again: "Count: 2". Tap
   "Forget": "Count:" with no number, the key is empty. Leave the page and come back: "Count: 0".
   Launch again: "Count: 0", and `ls` shows no `orca_saved_page_home`: both copies are gone. A
   session copy goes the same way: tap "+1", "Save for this session" and "Forget", then leave the
   page and come back: "Count: 0".
5. **Visits.** Tap "+1 and save" twice: "Visits: 2". Leave the page and come back: "Visits: 2",
   since app state is shared and the page's initial 0 does not replace a key that is set. Launch
   again: "Visits: 2", laid over the app state at boot, before the first page. The app's entry is
   the file `orca_saved_app`: `cat` it as above and it prints `{"visits":2}`.

The same steps give the same results booted from the app's config: put `--es ORCA_BOOT config` in
place of `--es ORCA_PATH home`. The config's `initialRoute` is `/home`, and the saved visits are in
the app state before that first route.

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
read it from `LocalConfiguration`, and so does the app's splash (`ORCA_SPLASH`, below), whose
caption ends with it. Against the example server the splash is a blink, so give the app a server
that takes the request and never answers. In a second terminal:

```bash
nc -l 8099
```

Then:

```bash
adb shell am start -S -n com.orcagateway.examples.counter/.MainActivity --ez ORCA_SPLASH true \
  --es ORCA_LOCALE fr-FR --es ORCA_BOOT config --es ORCA_TIMEOUT 5 \
  --es ORCA_SERVER_URL http://10.0.2.2:8099
```

`nc` prints the config request. The blue splash reads "host splash · fr-FR" under "Orca Counter":
the locale `OrcaApp` hands the views under it; without the extra it is the device's. Five seconds
later the request times out, "Connection Failed" shows and `nc` stops; start it again before the
next launch. The example pages have nothing that changes with the locale, so they look the same;
the layout stays left to right, as Flutter's default localizations are, and the server still gets
the device's locale in `x-orca-locale`.

**Splash.** With `ORCA_SPLASH` the app draws its own splash, "Orca Counter" in white on blue with
"host splash" and the locale under it, where the SDK shows its spinner while it boots: during the
version check (`ORCA_OFFLINE`) and while `/config` is fetched (`ORCA_BOOT config`). A page opened
at a path skips the `/config` fetch, so start the navigation app from its config with the check on:

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
