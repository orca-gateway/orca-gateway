# Orca Gateway push notifications for iOS (`OrcaPushNotification`)

> [!WARNING]
> **Alpha (`0.1.0-alpha.1`).** The plugin is built on the alpha iOS SDK, and its API may still
> change between alphas. For production apps use the Flutter plugin
> ([`orca_push_notification`](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_push_notification)).

Push notifications for iOS apps on the Orca Gateway Swift SDK: five actions that ask for the
notification permission, write the Firebase Cloud Messaging (FCM) token to state, show a local
notification and subscribe to FCM topics, and a tapped notification's payload handed to your app.
It is the twin of the Flutter plugin `orca_push_notification`: the same plugin name, actions,
params and defaults, so a server page that sends them to a Flutter app sends them here too. It has
no widget.

The source lives in [`plugins/orca_push_notification/ios/` of orca-gateway/orca-gateway](https://github.com/orca-gateway/orca-gateway/tree/main/plugins/orca_push_notification/ios).
[orca-push-notification-swift](https://github.com/orca-gateway/orca-push-notification-swift) is a
read-only copy for Swift Package Manager, updated on each release; send issues and pull requests to
the monorepo.

## Install

The package needs iOS 16 or macOS 13, as the SDK does. In Xcode: **File → Add Package
Dependencies…**, paste `https://github.com/orca-gateway/orca-push-notification-swift.git`, set
**Dependency Rule** to **Up to Next Major Version** from `0.1.0-alpha.1`, and add the
`OrcaPushNotification` library to your app target. Then add
`https://github.com/firebase/firebase-ios-sdk` the same way, **Up to Next Major Version** from
`12.17.0`, with its `FirebaseCore` library: the app configures Firebase itself (see
[Firebase](#firebase)).

In a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/orca-gateway/orca-gateway-swift.git", from: "0.1.0-alpha.2"),
    .package(url: "https://github.com/orca-gateway/orca-push-notification-swift.git", from: "0.1.0-alpha.1"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.17.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "OrcaGateway", package: "orca-gateway-swift"),
        .product(name: "OrcaPushNotification", package: "orca-push-notification-swift"),
        .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
    ]),
]
```

The package brings the SDK, [orca-gateway-swift](https://github.com/orca-gateway/orca-gateway-swift),
from `0.1.0-alpha.2`, the first SDK release with the plugin API. Your app's own rule for the SDK
must allow that version: an exact `0.1.0-alpha.1` does not resolve with the plugin. A rule whose
lower bound is an alpha, as `from: "0.1.0-alpha.2"`, also takes the alphas after it.

It also brings Google's [firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk)
(Apache 2.0) from `12.17.0` up to the next major, for its `FirebaseMessaging` library, which builds
FirebaseCore, FirebaseInstallations, GoogleUtilities, GoogleDataTransport, nanopb and Promises with
it; SwiftPM fetches the rest of firebase-ios-sdk's dependencies too. One version of firebase-ios-sdk
serves the plugin and your app, so your app's rule for it must allow a 12.x from `12.17.0`.

The token and the topics need your app's Firebase project and Apple's push service (see
[Firebase](#firebase) and [APNs](#apns)); local notifications do not.

## Register

Make one plugin for the life of the app and pass it to `OrcaApp`. At launch, from your app
delegate, configure Firebase and call `initialize` on that same plugin; the app delegate also hands
the plugin the APNs device token:

```swift
import FirebaseCore
import OrcaGateway
import OrcaPushNotification
import SwiftUI
import UIKit

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            OrcaApp(router: AppDelegate.router, plugins: [AppDelegate.push])
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    // One plugin and one router for the life of the app: OrcaApp, the taps and the APNs token
    // reach the same ones.
    static let push = PushNotificationPlugin()
    static let router = OrcaRouter(
        client: OrcaClient(baseURL: URL(string: "https://orca.example.com")!,
                           appId: "counter", apiKey: "demo-key"),
        path: "home")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        // Before launch ends: the plugin becomes the notification center's delegate.
        Self.push.initialize { payload in
            // The payload the page gave showLocalNotification. This app's pages give links of its
            // own scheme, opened as the same link from outside the app would be.
            if let payload, payload.hasPrefix("myapp://"), let url = URL(string: payload) {
                Self.router.handleDeeplink(url)
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Self.push.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Self.push.didFailToRegisterForRemoteNotifications(withError: error)
    }
}
```

`initialize(onNotificationTap:)` makes the plugin the notification center's delegate (see
[The notification center's delegate](#the-notification-centers-delegate)), registers for remote
notifications, whose answer comes to your app delegate, and asks for alert, badge and sound
permission at once, as Flutter's `DarwinInitializationSettings` defaults do: iOS shows its dialog
on the first launch. Call it on the main actor before the app finishes launching, in
`application(_:didFinishLaunchingWithOptions:)`, as Apple asks of a notification center's
delegate. Later calls do nothing.

Keep the one plugin: its state, the tap handler and the APNs token, is the instance's, so the
plugin you initialize and hand the token to is the one `OrcaApp` registers. `OrcaApp(client:)`
takes `plugins:` too. The client adds the five action types to the capabilities it sends, so the
server keeps the nodes that use them. The actions run on the main actor.

The app delegate forwards both answers to the registration.
`didRegisterForRemoteNotifications(withDeviceToken:)` keeps the APNs device token and, once
Firebase is configured, hands it to Firebase Messaging at once, so Firebase maps the FCM token to
it; a token that came before `FirebaseApp.configure()` is handed over at the next token or topic
action. `didFailToRegisterForRemoteNotifications(withError:)` keeps why there is none (see
[When the token or topics fail](#when-the-token-or-topics-fail)). Firebase swizzles nothing (see
[Firebase](#firebase)), so without these two calls the plugin gets no APNs token.

## The notification center's delegate

`UNUserNotificationCenter` has one delegate. `initialize` makes it the plugin's and passes nothing
on to a delegate the app set before, so an app with a delegate of its own loses it: a notification
the app schedules itself is not shown while the app is in the foreground, and a tap on a
notification the plugin did not show, a remote one the system showed too, reaches nothing. A
delegate the app sets after `initialize` replaces the plugin's in turn: then the plugin's
notifications show in the foreground only if that delegate presents them, and their taps go to it,
not to `onNotificationTap`.

## Firebase

The token and the topics are Firebase Cloud Messaging's, and need your app's Firebase project.
Setting Firebase up is the app's, as a Flutter app's `main()` calls `Firebase.initializeApp()`:
the plugin never does it.

- `GoogleService-Info.plist`, downloaded from the Firebase console for your app's bundle ID, in the
  app target, so that it is in the app's bundle.
- `FirebaseApp.configure()` at launch, as in the snippet above. It reads that file, and without
  it stops the app: "`FirebaseApp.configure()` could not find a valid GoogleService-Info.plist in
  your project". An app that also runs without the file, as the
  [iOS example](https://github.com/orca-gateway/orca-gateway/tree/main/examples/app-ios) does,
  configures Firebase only when the file is in the bundle:

  ```swift
  if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
      FirebaseApp.configure()
  }
  ```

- `FirebaseAppDelegateProxyEnabled` set to `NO`, a Boolean, in the app's `Info.plist`, as the
  plugin's `orca_plugin.yaml` asks:

  ```xml
  <key>FirebaseAppDelegateProxyEnabled</key>
  <false/>
  ```

  Otherwise Firebase uses method swizzling to map the APNs token to the FCM token and to capture
  analytics data from message callbacks; with `NO` it swizzles nothing, and the APNs token reaches
  Firebase only through the plugin. Firebase reads a Boolean only: a string `NO` leaves swizzling
  on.

Leave `FirebaseMessagingInstallationIdEnabled` out of `Info.plist`, or `NO`, its default. With
`YES` Firebase registers the app through its installation ID instead of an FCM token, and the
token actions fail with Firebase's error, whose reason is "FirebaseMessagingInstallationIdEnabled
is set to YES, so FCM token operations are not supported."

Google's [Add Firebase to your Apple project](https://firebase.google.com/docs/ios/setup) shows the
file and the call, and
[Get started with Firebase Cloud Messaging in Apple platform apps](https://firebase.google.com/docs/cloud-messaging/ios/client)
the swizzling switch and the APNs key below.

### The deprecation warning

When SwiftPM resolves firebase-ios-sdk 12.18 or later, the build shows a deprecation warning from
the plugin's `FirebaseMessagingAdapter.swift`: Firebase deprecates Messaging's `token(completion:)`
there in favour of `register(completion:)`, the registration through the installation ID. That
registration is opt-in (`FirebaseMessagingInstallationIdEnabled`, `NO` by default), and while it
is, `token(completion:)` works as before. The plugin accepts the warning so that an app on a
current Firebase can add it; a 12.17.x pin would keep such an app away. There is nothing to do in
the app. The plugin moves to `register(completion:)` once that is no longer opt-in.

## APNs

FCM reaches an iOS app through Apple Push Notification service (APNs), which needs two things of
yours:

- The Push Notifications capability: in Xcode, the app target's **Signing & Capabilities**,
  **+ Capability**, **Push Notifications**. It adds the `aps-environment` entitlement, the one the
  plugin's `orca_plugin.yaml` names, and a device build needs your development team. Without it a
  device gives the app no APNs token, and registering fails.
- An APNs authentication key, made in your Apple Developer account (**Certificates, Identifiers &
  Profiles → Keys**, with Apple Push Notifications service), uploaded to Firebase: in the Firebase
  console, **Project settings**, the **Cloud Messaging** tab, **APNs authentication key** under the
  iOS app's configuration, **Upload**. Firebase sends to the app through APNs with it.

Apple's [Registering your app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
shows the capability.

## The actions

`statusKey`, `tokenKey` and `scope` are read as sent, as Flutter casts them: a value that is not a
string (a `V.pageState(...)` too) fails the action, with "statusKey is not a string: …" for
`statusKey`. `title`, `body`, `payload` and `topic` are resolved as values (a `V.pageState(...)`
works); one that is not a string is used as its text. `scope` `app` writes app state, and any other
string page state, as `setState` does.

| Action | Params (default) | What it does |
|---|---|---|
| `requestNotificationPermission` | `statusKey`, `tokenKey`, `scope` (`"app"`) | Asks for the permission (see [The permission](#the-permission)), then writes `granted` or `denied` to `statusKey` and, when granted, the FCM token to `tokenKey`; no token writes nothing. A key left out is not written, and without `tokenKey` no token is read. A token error fails the action after the status is written. |
| `getNotificationToken` | `tokenKey` (`"fcmToken"`), `scope` (`"app"`) | Writes the FCM token to `tokenKey`, null when there is none. |
| `showLocalNotification` | `title` (`""`), `body` (`""`), `payload` | Shows a notification with `title` and `body` and the default sound, in the foreground too (see [Notifications in the foreground](#notifications-in-the-foreground)); a tap on it hands `payload` to `onNotificationTap`. Its id is the time in seconds, so a second one shown in the same second replaces the first. Writes no state. |
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

`requestNotificationPermission` asks `UNUserNotificationCenter` for alert, badge and sound, then
reads the notification settings: `granted` when notifications are authorized, `denied` otherwise.
iOS shows its dialog once: `initialize` asks at launch already, so a later request answers at once
with what the user chose, and a user who said no turns notifications on in Settings. No
`Info.plist` entry is needed. An error from the request fails the action, writing nothing.

## When the token or topics fail

Without Firebase configured, local notifications and their taps work, and `getNotificationToken`,
`subscribeToTopic` and `unsubscribeFromTopic` fail with "Firebase is not configured: the app calls
FirebaseApp.configure() at launch, with its GoogleService-Info.plist, before the push token or
topics are used", as Flutter's do when the app has not called `Firebase.initializeApp`. With a
`tokenKey`, a granted `requestNotificationPermission` writes the status first and then fails the
same way.

With Firebase configured, they fail while Firebase Messaging has no APNs token (the app delegate
has handed none over yet, or registering failed), with "The APNs token has not been set yet: the
app delegate hands it to the plugin's didRegisterForRemoteNotifications(withDeviceToken:) before
the push token or topics are used", and after it " (registering failed: …)" with the error the app
delegate handed over, as firebase_messaging checks for the APNs token before it gets the token or
subscribes. An error from Firebase itself fails the action too.

## Notifications in the foreground

As the notification center's delegate, the plugin shows its own notifications while the app is in
the foreground too: a banner, in the list, with their sound and badge.

A remote notification that arrives while the app is in the foreground and has an alert or a sound
is shown as a local notification instead, as Flutter's plugin does: its title is the alert's title,
or the alert when that is a string, and its body the alert's body. Its payload is the message's
data as a JSON object: its keys but `aps` and Firebase's own (`gcm.…`, `google.…`,
`fcm_options`, `message_id`, `message_type`, `collapse_key`, `from`, `to`). A remote notification
with neither alert nor sound shows nothing. A new FCM token is not followed: a page reads the
current one with `getNotificationToken`.

## Taps

A tap on a notification the plugin showed, one from `showLocalNotification` or a foreground message
shown as one, calls `onNotificationTap` on the main actor with its payload: what the page gave
`showLocalNotification`, `""` when it gave none (as in Flutter), or the message's data as JSON. The
plugin never navigates: the app decides. A link goes to the SDK's router with
`router.handleDeeplink(url)`, so the tap lands where the same link from outside the app would.

In the background iOS shows remote notifications itself, as in Flutter, and a tap on one never
reaches `onNotificationTap`; nor does a tap on any other notification the plugin did not show.

## Differences from Flutter

- `initialize(onNotificationTap:)` is called on the plugin the app registers, from its app
  delegate. Flutter's is a static call in `main()`.
- The app delegate hands the APNs token, or the failure, to the plugin. Flutter's firebase_messaging
  is an app delegate of its own, which the Flutter engine passes those calls to, so a Flutter app
  forwards nothing.
- As the notification center's delegate, the plugin passes nothing on to the delegate it replaced.
  Flutter's firebase_messaging passes each call on to it.
- A tap that launches the app, on a notification the plugin showed before the app was closed: iOS
  hands it to the center's delegate when that was set before launch ended, as `initialize` in
  `application(_:didFinishLaunchingWithOptions:)` is, so it should reach `onNotificationTap` here.
  Flutter's plugin drops it: flutter_local_notifications keeps it for
  `getNotificationAppLaunchDetails`, which the plugin does not read. Not yet seen in an app.

## Tests

In a checkout of the monorepo, where the package builds against `../../../sdk-swift` by path:

```bash
cd plugins/orca_push_notification/ios && swift test
```

They drive every action through fakes of the notification center and of Firebase Messaging: the
raw and resolved params, the defaults, the state writes in their scopes, the failures,
`initialize`, the foreground rule, the tap, and the APNs token's way to Messaging in either order.
The real plugin, in a test process that never configures Firebase, fails the token and topic
actions with the "Firebase is not configured" message. They also check the manifest's dependencies
inside the monorepo and split out. The first build fetches firebase-ios-sdk and its dependencies.
The "Native Plugins CI" workflow also runs them on an iOS simulator.

Only an app shows the rest, the real notification center (it needs an app bundle): the permission
dialog, the banner and the tap; and, with your Firebase project, the APNs key and the capability,
a real APNs token, FCM token and topics.

## Versioning and releases

`VERSION` holds the package version. It is bumped only by
[`scripts/release.sh`](https://github.com/orca-gateway/orca-gateway/blob/main/scripts/release.sh)
(the `orca_push_notification-ios` package), never by hand. Its `orca_push_notification-ios-v<X>`
tag starts the "SDK Swift Mirror" workflow, which copies `plugins/orca_push_notification/ios/` to
orca-push-notification-swift with `git subtree split`, tags it `<X>` there and builds a package
that imports `OrcaPushNotification` at that tag, for macOS and the iOS simulator.

## License

[Business Source License 1.1](LICENSE), as the rest of Orca Gateway.
