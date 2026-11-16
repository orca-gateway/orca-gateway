# Orca Gateway push notifications for Android (`orca-push-notification`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The plugin is built on the alpha Android SDK, and its API may still
> change between alphas. For production apps use the Flutter plugin
> ([`orca_push_notification`](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_push_notification)).

Push notifications for Android apps on the Orca Gateway Kotlin SDK: five actions that ask for the
notification permission, write the Firebase Cloud Messaging (FCM) token to state, show a local
notification and subscribe to FCM topics, and a tapped notification's payload handed to your app.
It is the twin of the Flutter plugin `orca_push_notification`: the same plugin name, actions,
params and defaults, so a server page that sends them to a Flutter app sends them here too. It has
no widget.

The source lives in [`plugins/orca_push_notification/android/` of orca-gateway/orca-gateway](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_push_notification/android).

## Install

The plugin is on Maven Central, beside the SDK. With the repositories the
[SDK's install](https://github.com/orca-gateway/orca-gateway/tree/main/sdk-kotlin#install) names
(Google's and Maven Central), add it to your app module's `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.orcagateway:orca-push-notification:0.1.0-alpha.1")
}
```

It depends on the SDK, `com.orcagateway:sdk`, so Gradle brings the SDK too; when your app names
the SDK as well, Gradle takes the higher of the two versions. It also brings Google's Firebase
Cloud Messaging, `com.google.firebase:firebase-messaging` 25.0.2, and the Firebase and Google Play
services libraries it runs on, from Google's Maven repository. The app needs what the SDK needs:
`minSdk = 24` or higher and Compose turned on.

The token and the topics need your app's Firebase project (see [Firebase](#firebase)); local
notifications do not.

## Register

Make one plugin for the life of the app, with the application context, and pass it to `OrcaApp`.
In every `onCreate` of the activity, call `initialize` on that same plugin:

```kotlin
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.plugins.pushnotification.PushNotificationPlugin
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.client.OkHttpTransport
import com.orcagateway.sdk.navigation.OrcaRouter
import java.net.URI

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val push = plugin ?: PushNotificationPlugin(applicationContext).also { plugin = it }
        // Every onCreate, on the one plugin: this activity asks for the permission and hears the taps.
        push.initialize(this) { payload ->
            // The payload the page gave showLocalNotification. This app's pages give links of its
            // own scheme, opened as the same link from outside the app would be.
            if (payload != null && payload.startsWith("myapp://")) router.handleDeeplink(payload)
        }
        setContent { OrcaApp(router, plugins = listOf(push)) }
    }

    // One plugin and one router for the life of the app, kept outside the activity.
    private companion object {
        val router = OrcaRouter(
            OrcaClient(
                baseUrl = URI("https://orca.example.com"),
                appId = "counter",
                apiKey = "demo-key",
                transport = OkHttpTransport(),
            ),
            path = "home",
        )
        var plugin: PushNotificationPlugin? = null
    }
}
```

`initialize(activity, onNotificationTap)` makes the notification channel (see
[Notifications](#notifications)), registers the permission request that
`requestNotificationPermission` makes in the activity's result registry, and listens for the
activity's new Intents. It goes in `onCreate`, before the activity starts, as every result
registration must. Call it again in each new activity (a rotation makes one): the newest one asks
and hears the taps. The plugin lets go of an activity's request when the activity is destroyed.

Keep the one plugin: `OrcaApp` merges a router's plugins once, the first time it shows the router,
and keeps them through a rotation, so a plugin made by a later activity would get no action. Its
actions run on the main thread. Before the first request `OrcaApp` adds the five action names to
the client's capabilities.

The activity is a `ComponentActivity` with `android:launchMode="singleTop"`, as the SDK's
[deep links](https://github.com/orca-gateway/orca-gateway/tree/main/sdk-kotlin#deep-links) need
too:

```xml
<activity android:name=".MainActivity" android:exported="true" android:launchMode="singleTop">
```

A tap on a notification the plugin showed opens the app's launch activity; with `singleTop` it
reaches the running one as a new Intent, and `initialize`'s listener calls `onNotificationTap`
with the notification's payload: what the page gave `showLocalNotification`, `""` when it gave
none (as in Flutter), or a foreground message's data as JSON (see [Firebase](#firebase)). The
plugin never navigates: the app decides. A link goes to the SDK's router with
`router.handleDeeplink(payload)`, so the tap lands where the same link from outside the app would.
The Intent that starts an activity is not read: a tap that starts the app never reaches
`onNotificationTap`, and the app opens where it starts, as in Flutter.

## The actions

`statusKey`, `tokenKey` and `scope` are read as sent, as Flutter casts them: a value that is not a
string (a `V.pageState(...)` too) fails the action. `title`, `body`, `payload` and `topic` are
resolved as values (a `V.pageState(...)` works); one that is not a string is used as its text.
`scope` `app` writes app state, and any other string page state, as `setState` does.

| Action | Params (default) | What it does |
|---|---|---|
| `requestNotificationPermission` | `statusKey`, `tokenKey`, `scope` (`"app"`) | Asks for the permission (see [The permission](#the-permission)), then writes `granted` or `denied` to `statusKey` and, when granted, the FCM token to `tokenKey`; no token writes nothing. A key left out is not written, and without `tokenKey` no token is read. A token error fails the action after the status is written. |
| `getNotificationToken` | `tokenKey` (`"fcmToken"`), `scope` (`"app"`) | Writes the FCM token to `tokenKey`, null when there is none. |
| `showLocalNotification` | `title` (`""`), `body` (`""`), `payload` | Shows a notification with `title` and `body` (see [Notifications](#notifications)); a tap on it hands `payload` to `onNotificationTap`. Its id is the time in seconds, so a second one shown in the same second replaces the first. Writes no state. |
| `subscribeToTopic` | `topic` (required) | Subscribes the app to the FCM topic; an empty or absent one does nothing. Writes no state. |
| `unsubscribeFromTopic` | `topic` (required) | Unsubscribes the app from the FCM topic; an empty or absent one does nothing. Writes no state. |

A server page builds them with the TypeScript functions
`orca plugin generate --manifest orca_plugin.yaml` writes from the plugin's
[`orca_plugin.yaml`](https://github.com/orca-gateway/orca-gateway/blob/main/plugins/orca_push_notification/orca_plugin.yaml).
The example server's `custom` app has a Push Notifications page (`/push`) with a button for each
action (Request permission, Get token, Show notification with the payload
`orcacounter://open/map`, Subscribe to news, Unsubscribe from news) and the status and the token
shown from app state
([`examples/server/custom.ts`](https://github.com/orca-gateway/orca-gateway/blob/main/examples/server/custom.ts)).

## The permission

`POST_NOTIFICATIONS` is in the library's manifest, and the manifest merger adds it to your app's:
add nothing. From API 33 it is a runtime permission, and `requestNotificationPermission` asks the
user for it through the request `initialize` registered: `granted` when the user allows it,
`denied` when not. An app that holds it already is `granted` with nothing asked. Below API 33
nothing is asked: the app's notification setting decides
(`NotificationManagerCompat.areNotificationsEnabled()`). From API 33 `showLocalNotification`
without the permission shows nothing, and does not fail.

`requestNotificationPermission` fails, writing nothing, on every API level:

- before `initialize`, and after its activity is destroyed until the next `initialize`, with
  "PushNotificationPlugin.initialize(activity, onNotificationTap) must be called in the activity's
  onCreate before requestNotificationPermission";
- while an earlier request waits for the user, with firebase_messaging's "A request for
  permissions is already running, please wait for it to finish before doing another request."

## Firebase

The token and the topics are Firebase Cloud Messaging's, and need your app's Firebase project.
Both pieces are the app's, not the library's, which applies no Gradle plugin and carries no
Firebase file:

- `google-services.json`, downloaded from the Firebase console for your app's package name, in
  the app module's folder (`app/google-services.json`);
- Google's google-services Gradle plugin, `com.google.gms.google-services`, applied in the app
  module, which turns that file into the values Firebase starts from when the app starts. The app
  calls nothing itself.

Google's [Add Firebase to your Android project](https://firebase.google.com/docs/android/setup)
shows both. FCM also needs Google Play services on the device: a phone with the Play Store, or an
emulator image with Google APIs or Google Play.

Without them, local notifications and their taps work, and the token and topic actions fail with
Firebase's `IllegalStateException`, "Default FirebaseApp is not initialized in this process …", as
Flutter's do when the app has not called `Firebase.initializeApp`. With a `tokenKey`, a granted
`requestNotificationPermission` writes the status first and then fails the same way.

For messages, the library's manifest adds a `FirebaseMessagingService` that FCM starts in place of
Firebase's own. A message with a notification that arrives while the app is in the foreground (its
process at foreground importance and the screen not locked) is shown as a local notification on the
same channel, with the message's data as a JSON object for its payload, so a tap on it hands that
JSON to `onNotificationTap`. In the background the system shows notification messages itself, as
in Flutter, and a tap on one never reaches `onNotificationTap`. A message with data alone shows
nothing. A new token is not followed: a page reads the current one with `getNotificationToken`.

## Notifications

Every notification, the ones `showLocalNotification` shows and the foreground messages, goes to the
channel `orca_default_channel`, named "Notifications" in the app's notification settings, at high
importance (priority high below API 26, which has no channels). `initialize` makes the channel, and
so does each notification, so one shown before `initialize` has it too. A notification shows the
app's icon (`android:icon`) as its small icon, goes away when tapped, and a tap opens the app's
launch activity with the payload. An app without an `android:icon` shows none:
`showLocalNotification` fails with Android's `IllegalArgumentException`, "Invalid notification (no
valid small icon): …" (Flutter's `initialize` fails instead, without its `@mipmap/ic_launcher`).
An app without a launch activity gets notifications that a tap does not open.

## Differences from Flutter

- `initialize` takes the activity, and is called on the plugin in each activity's `onCreate`.
  Flutter's is a static call in `main()`, once, and its plugin always has its activity: there
  `requestNotificationPermission` cannot come before it, here it fails, naming `initialize`.
- The messaging service is in the manifest, so a message that arrives while the app is in the
  foreground is shown even before `initialize`, or in an app that never calls it. Flutter shows one
  only once `initialize` has started listening.

## Tests

In a checkout of the monorepo:

```bash
cd plugins/orca_push_notification/android && ./gradlew build
```

It compiles with warnings as errors, runs the unit tests under Robolectric and runs lint. The tests
drive every action through fakes of the system's notifications and of FCM, and the real channel,
notification, permission request, tap and messaging service under Robolectric, where there is no
Firebase project: there the token and topic actions are tested to fail. Building needs no
`google-services.json`. `./gradlew` is the SDK's wrapper, and the build includes
`../../../sdk-kotlin`, so the plugin compiles against the SDK's source.

## Versioning and releases

`VERSION` holds the package version. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh)
(the `orca_push_notification-android` package), never by hand. Its
`orca_push_notification-android-v<X>` tag starts the "SDK Kotlin Publish" workflow, which signs
`com.orcagateway:orca-push-notification` `<X>` and releases it to Maven Central. Its POM depends on
`com.orcagateway:sdk` at the version in `sdk-kotlin/VERSION`. A version on Central cannot be
replaced, so a fix goes out as the next version.

## License

[Business Source License 1.1](../LICENSE), as the rest of Orca Gateway.
