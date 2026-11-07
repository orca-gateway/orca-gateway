# Android example: Orca Counter

The counter example drawn by the **experimental** Kotlin SDK (`sdk-kotlin/`, Epic 23b) against the
same Bun server as the Flutter and iOS examples. This Gradle build includes `../../sdk-kotlin`, so it
builds the SDK from source and an SDK change shows up on the next build. Nothing is published yet.

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

## What it shows

`+` and `-` change the count; `Reset` sets it to 0 and shows a snackbar. The page, the state and the
actions all come from `examples/server/counter.ts`; the app holds no logic beyond the server URL.
On the first request the SDK goes through the capability handshake (a 412, then one retry with its
capability vector), as the Flutter and Swift SDKs do.

Debug builds allow plain HTTP for the example server; release builds keep Android's HTTPS-only
default. Navigation, URL, clipboard and share actions, server actions and DevTools arrive in the
next slice (S8), so the other example apps (`basic-actions`, `server-actions`) draw but those
actions do nothing yet.
