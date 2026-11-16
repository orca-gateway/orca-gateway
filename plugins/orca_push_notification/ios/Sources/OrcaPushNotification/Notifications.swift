import Foundation
import OrcaGateway

/// What the plugin asks of the notification center: the part of
/// flutter_local_notifications 18.0.1 and firebase_messaging 15.2.10 the
/// Flutter plugin uses (lib/src/push_notification_plugin.dart).
/// `SystemNotifications` on UNUserNotificationCenter in an app, a fake in the
/// tests.
@MainActor
public protocol Notifications: Sendable {
    /// Asks the user for alert, badge and sound permission (once; later calls
    /// answer at once): whether notifications are authorized.
    func requestAuthorization() async throws -> Bool
    /// Shows the notification now.
    func add(_ notification: LocalNotification) async throws
    /// Becomes the center's delegate: `willPresent` says whether a
    /// notification arriving in the foreground is presented (banner, list,
    /// sound and badge) or not, `didReceive` hears a tap on one.
    func becomeDelegate(
        willPresent: @escaping @MainActor (DeliveredNotification) async -> Bool,
        didReceive: @escaping @MainActor (DeliveredNotification) -> Void)
    /// Asks APNs for the device token, which comes back through the app
    /// delegate (firebase_messaging does it at launch).
    func registerForRemoteNotifications()
}

/// A notification the plugin shows: its request's identifier, content and
/// userInfo.
public struct LocalNotification: Equatable, Sendable {
    public var id: Int
    public var title: String
    public var body: String
    public var userInfo: [String: JSONValue]

    public init(id: Int, title: String, body: String, userInfo: [String: JSONValue]) {
        self.id = id
        self.title = title
        self.body = body
        self.userInfo = userInfo
    }
}

/// A notification the center hands its delegate: its request's identifier,
/// whether APNs sent it, and its userInfo as JSON.
public struct DeliveredNotification: Equatable, Sendable {
    public var identifier: String
    public var isRemote: Bool
    public var userInfo: [String: JSONValue]

    public init(identifier: String, isRemote: Bool, userInfo: [String: JSONValue]) {
        self.identifier = identifier
        self.isRemote = isRemote
        self.userInfo = userInfo
    }
}

#if canImport(UserNotifications)
import UserNotifications
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// `Notifications` on UNUserNotificationCenter, as flutter_local_notifications
/// does it with DarwinInitializationSettings' and DarwinNotificationDetails'
/// defaults: the request shown now with the default sound. The center is
/// asked for each call, never at init (it needs an app bundle).
@MainActor
final class SystemNotifications: Notifications {
    /// The center's delegate, held here: the center holds it weakly.
    private let delegate = NotificationCenterDelegate()

    private var center: UNUserNotificationCenter { .current() }

    nonisolated init() {}

    /// Granted is authorized, as firebase_messaging's AuthorizationStatus
    /// read from the settings after the request.
    func requestAuthorization() async throws -> Bool {
        let center = center
        _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        return await center.notificationSettings().authorizationStatus == .authorized
    }

    func add(_ notification: LocalNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        let userInfo = try JSONSerialization.jsonObject(with: JSONValue.object(notification.userInfo).encoded())
        content.userInfo = userInfo as? [AnyHashable: Any] ?? [:]
        try await center.add(UNNotificationRequest(identifier: String(notification.id), content: content, trigger: nil))
    }

    func becomeDelegate(
        willPresent: @escaping @MainActor (DeliveredNotification) async -> Bool,
        didReceive: @escaping @MainActor (DeliveredNotification) -> Void
    ) {
        delegate.willPresent = willPresent
        delegate.didReceive = didReceive
        center.delegate = delegate
    }

    func registerForRemoteNotifications() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif canImport(AppKit)
        NSApplication.shared.registerForRemoteNotifications()
        #endif
    }
}

/// The center's delegate. iOS calls it off the main thread, so its methods
/// are nonisolated and hop to the main actor; a tap is the default action
/// only (the plugin registers no categories, so no other action comes).
@MainActor
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    var willPresent: (@MainActor (DeliveredNotification) async -> Bool)?
    var didReceive: (@MainActor (DeliveredNotification) -> Void)?

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let delivered = DeliveredNotification(notification)
        Task { @MainActor in
            let present = await self.willPresent?(delivered) ?? false
            completionHandler(present ? [.banner, .list, .sound, .badge] : [])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let tapped = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        let delivered = DeliveredNotification(response.notification)
        Task { @MainActor in
            if tapped { self.didReceive?(delivered) }
            completionHandler()
        }
    }
}

extension DeliveredNotification {
    /// The notification's identifier, whether APNs sent it, and its userInfo
    /// as JSON (empty when it is not JSON).
    init(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        let json = JSONSerialization.isValidJSONObject(userInfo)
            ? (try? JSONSerialization.data(withJSONObject: userInfo)).flatMap { try? JSONValue.decode($0) }
            : nil
        self.init(
            identifier: notification.request.identifier,
            isRemote: notification.request.trigger is UNPushNotificationTrigger,
            userInfo: json?.objectValue ?? [:])
    }
}
#endif
