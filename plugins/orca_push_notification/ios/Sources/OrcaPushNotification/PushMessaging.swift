import Foundation

/// What the plugin asks of the push service: the part of firebase_messaging's
/// `FirebaseMessaging.instance` the Flutter plugin uses
/// (lib/src/push_notification_plugin.dart). Firebase Messaging or APNs alone,
/// whichever the app's adapter speaks; a fake in the tests. Named so it does
/// not clash with Firebase's `Messaging`.
@MainActor
protocol PushMessaging: Sendable {
    /// The device's push token, nil when there is none; throws when the
    /// service is not set up, which fails the action, as `getToken()` does.
    func token() async throws -> String?
    func subscribe(toTopic topic: String) async throws
    func unsubscribe(fromTopic topic: String) async throws
    /// The host has handed over an APNs token (now in the plugin's
    /// registration), for a service that takes it as it comes.
    func deviceTokenDidChange()
}

extension PushMessaging {
    /// Nothing, for a service that reads the token when it needs it.
    func deviceTokenDidChange() {}
}
