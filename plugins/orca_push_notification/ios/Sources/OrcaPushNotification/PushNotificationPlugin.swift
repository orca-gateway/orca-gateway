#if canImport(SwiftUI)
import Foundation
import OrcaGateway
import os

/// Push and local notifications, the Swift port of the Flutter
/// `PushNotificationPlugin` (lib/src/push_notification_plugin.dart, on
/// firebase_messaging 15.2.10 and flutter_local_notifications 18.0.1):
/// register it with the host, `OrcaApp(..., plugins: [push])`, call
/// `push.initialize(onNotificationTap:)` at launch, as Flutter's
/// `initialize()` in `main()`, and forward the APNs token from the app
/// delegate (`didRegisterForRemoteNotifications(withDeviceToken:)`).
///
/// No widgets, no triggers. Actions `requestNotificationPermission`
/// {statusKey, tokenKey, scope (app)} writes "granted" or "denied" and, when
/// granted, the token; `getNotificationToken` {tokenKey (fcmToken), scope
/// (app)} writes the token or null; `showLocalNotification` {title (""),
/// body (""), payload}; `subscribeToTopic` and `unsubscribeFromTopic`
/// {topic}, nothing for an empty one.
public struct PushNotificationPlugin: OrcaPlugin {
    public let name = "PushNotificationPlugin"
    /// What the actions, initialize and the token hand-off share (Flutter's
    /// statics).
    let push: PushNotifications

    /// The plugin on its seams: `notifications` the notification center,
    /// `messaging` the push service, `registration` where the APNs token the
    /// host hands over is kept for the messaging to read.
    public init(
        notifications: Notifications, messaging: PushMessaging,
        registration: RemoteNotificationRegistration = RemoteNotificationRegistration()
    ) {
        push = PushNotifications(notifications: notifications, messaging: messaging, registration: registration)
    }

    public var actions: [String: OrcaActionHandler] {
        let push = push
        return [
            "requestNotificationPermission": { try await push.requestNotificationPermission($0, $1) },
            "getNotificationToken": { try await push.getNotificationToken($0, $1) },
            "showLocalNotification": { try await push.showLocalNotification($0, $1) },
            "subscribeToTopic": { try await push.subscribeToTopic($0, $1) },
            "unsubscribeFromTopic": { try await push.unsubscribeFromTopic($0, $1) },
        ]
    }

    /// Flutter's `PushNotificationPlugin.initialize`, on the instance the
    /// host registers (the plugin's state is the instance's, not static).
    /// Call it once at launch, before the app finishes launching: the plugin
    /// becomes the notification center's delegate (replacing the host's),
    /// registers for remote notifications and asks for alert, badge and sound
    /// permission. A tap on a notification the plugin showed calls
    /// `onNotificationTap` with its payload. Later calls do nothing.
    @MainActor
    public func initialize(onNotificationTap: (@MainActor (String?) -> Void)? = nil) {
        push.initialize(onNotificationTap: onNotificationTap)
    }

    /// The app delegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
    /// hands the APNs device token over (nothing is swizzled).
    @MainActor
    public func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        push.registration.deviceToken = deviceToken
        push.registration.error = nil
    }

    /// The app delegate's `application(_:didFailToRegisterForRemoteNotificationsWithError:)`.
    @MainActor
    public func didFailToRegisterForRemoteNotifications(withError error: Error) {
        push.registration.deviceToken = nil
        push.registration.error = error
    }
}

/// The host's APNs registration as its app delegate hands it over: the device
/// token, or why there is none. The messaging reads it.
@MainActor
public final class RemoteNotificationRegistration {
    public internal(set) var deviceToken: Data?
    public internal(set) var error: Error?

    public nonisolated init() {}
}

/// The five actions, initialize and the notification center's delegate, line
/// for line Flutter's (push_notification_plugin.dart :40-168): statusKey,
/// tokenKey and scope read raw (`as String?`: anything else fails the
/// action), title, body, payload and topic resolved as values.
@MainActor
final class PushNotifications {
    private static let log = Logger(subsystem: "com.orcagateway", category: "orca_push_notification")
    /// The userInfo keys of a notification the plugin shows.
    static let idKey = "orcaNotificationId"
    static let payloadKey = "payload"

    let notifications: Notifications
    let messaging: PushMessaging
    let registration: RemoteNotificationRegistration
    private var initialized = false
    private var onNotificationTap: (@MainActor (String?) -> Void)?
    /// The last notification presented in the foreground (firebase_messaging's
    /// `_foregroundUniqueIdentifier`: iOS 18 can ask twice).
    private var lastPresented: String?

    nonisolated init(notifications: Notifications, messaging: PushMessaging, registration: RemoteNotificationRegistration) {
        self.notifications = notifications
        self.messaging = messaging
        self.registration = registration
    }

    // MARK: initialize

    func initialize(onNotificationTap: (@MainActor (String?) -> Void)?) {
        guard !initialized else { return }
        initialized = true
        self.onNotificationTap = onNotificationTap
        notifications.becomeDelegate(
            willPresent: { [weak self] in await self?.willPresent($0) ?? false },
            didReceive: { [weak self] in self?.didReceive($0) })
        notifications.registerForRemoteNotifications()
        // DarwinInitializationSettings' request*Permission defaults.
        let notifications = notifications
        Task { _ = try? await notifications.requestAuthorization() }
    }

    /// The plugin's own notifications are presented; a remote one with a
    /// notification is shown as a local one instead, its data as the JSON
    /// payload (Flutter's onMessage listener); nothing else is presented.
    func willPresent(_ notification: DeliveredNotification) async -> Bool {
        let repeated = notification.identifier == lastPresented
        lastPresented = notification.identifier
        if notification.userInfo[Self.idKey] != nil { return true }
        guard notification.isRemote, !repeated else { return false }

        // firebase_messaging's message: a notification when aps has an alert
        // (a string alert is its title), the data the keys left.
        let alert = notification.userInfo["aps"]?["alert"] ?? .null
        guard !alert.isNull else { return false }
        let data = notification.userInfo.filter { !Self.isMessageKey($0.key) }
        let payload = (try? JSONValue.object(data).encoded()).map { String(decoding: $0, as: UTF8.self) }
        do {
            // Flutter's `notification.hashCode`: a number of 30 bits.
            try await notifications.add(Self.notification(
                id: Int.random(in: 0 ..< 1 << 30), title: alert.stringValue ?? alert["title"].stringValue ?? "",
                body: alert["body"].stringValue ?? "", payload: payload))
        } catch {
            Self.log.error("show failed: \(String(describing: error), privacy: .public)")
        }
        return false
    }

    /// A tap on a notification the plugin showed hands its payload to the
    /// host; any other reaches nothing.
    func didReceive(_ notification: DeliveredNotification) {
        guard notification.userInfo[Self.idKey] != nil else { return }
        onNotificationTap?(notification.userInfo[Self.payloadKey]?.stringValue)
    }

    // MARK: Actions

    func requestNotificationPermission(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        let granted = try await notifications.requestAuthorization()

        let params = RequestNotificationPermissionParams(action)
        let statusKey = try Self.cast(params.statusKey, action, "statusKey")
        let tokenKey = try Self.cast(params.tokenKey, action, "tokenKey")
        let scope = try Self.cast(params.scope, action, "scope") ?? "app"

        if let statusKey {
            try await Self.setState(executor, statusKey, granted ? "granted" : "denied", scope)
        }
        if granted, let tokenKey, let token = try await messaging.token() {
            try await Self.setState(executor, tokenKey, .string(token), scope)
        }
    }

    func getNotificationToken(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        let params = GetNotificationTokenParams(action)
        let tokenKey = try Self.cast(params.tokenKey, action, "tokenKey") ?? "fcmToken"
        let scope = try Self.cast(params.scope, action, "scope") ?? "app"

        let token = try await messaging.token()
        try await Self.setState(executor, tokenKey, token.map(JSONValue.string) ?? .null, scope)
    }

    func showLocalNotification(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        let params = ShowLocalNotificationParams(action).action
        let title = Self.resolveString(params["title"], executor)
        let body = Self.resolveString(params["body"], executor)
        let payload = params["payload"].isNull ? nil : Self.resolveString(params["payload"], executor)

        try await notifications.add(Self.notification(
            id: Int(Date().timeIntervalSince1970), title: title, body: body, payload: payload))
    }

    func subscribeToTopic(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        let topic = Self.resolveString(SubscribeToTopicParams(action).action["topic"], executor)
        guard !topic.isEmpty else { return }
        try await messaging.subscribe(toTopic: topic)
    }

    func unsubscribeFromTopic(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        let topic = Self.resolveString(UnsubscribeFromTopicParams(action).action["topic"], executor)
        guard !topic.isEmpty else { return }
        try await messaging.unsubscribe(fromTopic: topic)
    }

    // MARK: Helpers

    /// A notification the plugin shows, marked as its own, with the payload.
    private static func notification(id: Int, title: String, body: String, payload: String?) -> LocalNotification {
        var userInfo: [String: JSONValue] = [idKey: .int(id)]
        userInfo[payloadKey] = payload.map(JSONValue.string)
        return LocalNotification(id: id, title: title, body: body, userInfo: userInfo)
    }

    /// The userInfo keys firebase_messaging does not count as the message's
    /// data (`remoteMessageUserInfoToDict`).
    private static func isMessageKey(_ key: String) -> Bool {
        ["aps", "fcm_options", "message_id", "message_type", "collapse_key", "from", "to"].contains(key)
            || key.hasPrefix("gcm.") || key.hasPrefix("google.")
    }

    /// Dart's `action[key] as String?`: the generated param when it is a
    /// string, nil when missing or null; anything else fails the action, as
    /// the cast throws.
    private static func cast(_ string: String?, _ action: JSONValue, _ key: String) throws -> String? {
        if string != nil || action[key].isNull { return string }
        throw PushNotificationParamError(key: key, value: action[key])
    }

    /// Dart's `executor.resolveString`: the resolved value's `toString`, ""
    /// for null.
    private static func resolveString(_ raw: JSONValue, _ executor: ActionExecutor) -> String {
        let value = executor.resolve(raw)
        return value.isNull ? "" : DartFormat.string(value)
    }

    /// A `setState` of `key` in `scope` (app, else page), run by the executor.
    private static func setState(
        _ executor: ActionExecutor, _ key: String, _ value: JSONValue, _ scope: String
    ) async throws {
        try await executor.execute(.setState(.init(key: key, scope: scope == "app" ? .app : .page, value: value)))
    }
}

/// A param read raw that is not a string, where Dart's `as String?` throws:
/// it fails the action.
struct PushNotificationParamError: Error, CustomStringConvertible {
    let key: String
    let value: JSONValue

    var description: String { "\(key) is not a string: \(DartFormat.string(value))" }
}
#endif
