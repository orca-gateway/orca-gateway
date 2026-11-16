import FirebaseCore
import FirebaseMessaging
import Foundation

/// `PushMessaging` on Firebase Messaging (firebase-ios-sdk), as
/// firebase_messaging 15.2.10 drives it on iOS (FLTFirebaseMessagingPlugin.m,
/// method_channel_messaging.dart): the FCM token and the topic calls go to
/// `Messaging.messaging()`, awaited, and its errors are thrown, which fails the
/// action.
///
/// Firebase is the app's to configure (`FirebaseApp.configure()`, as Flutter's
/// `Firebase.initializeApp()` is the app's): without a default app each call
/// throws `FirebaseMessagingError.notConfigured`. Unguarded, it would not
/// raise: `Messaging.messaging()` returns nil there (FirebaseCore only logs
/// that the default app is not configured), so a call would do nothing and
/// the token and topic calls would never complete.
///
/// The APNs token: Firebase does no swizzling (the app sets
/// FirebaseAppDelegateProxyEnabled to NO), so the host hands it to the plugin,
/// which keeps it in `registration`. It is handed to Messaging as it comes,
/// once Firebase is configured, as firebase_messaging does in didRegister:
/// Firebase then maps a first FCM token to it and re-maps one to a new APNs
/// token. A token that came before FirebaseApp.configure() is handed over
/// before the next call, as firebase_messaging's ensureAPNSTokenSetting does;
/// neither hands over a token Messaging has already. While Messaging has none,
/// a call throws `FirebaseMessagingError.noAPNsToken`, as firebase_messaging's
/// apns-token-not-set check does before getToken, subscribeToTopic and
/// unsubscribeFromTopic.
@MainActor
final class FirebaseMessagingAdapter: PushMessaging {
    /// Where the host's APNs token is kept (the plugin's).
    let registration: RemoteNotificationRegistration
    /// Messaging, nil while Firebase is not configured.
    private let messaging: @MainActor @Sendable () -> FirebaseMessagingInstance?

    /// On Firebase's default app, once the app has configured it.
    nonisolated convenience init(registration: RemoteNotificationRegistration) {
        self.init(registration: registration, messaging: { FirebaseApp.app() == nil ? nil : Messaging.messaging() })
    }

    nonisolated init(
        registration: RemoteNotificationRegistration,
        messaging: @escaping @MainActor @Sendable () -> FirebaseMessagingInstance?
    ) {
        self.registration = registration
        self.messaging = messaging
    }

    func token() async throws -> String? {
        try await ready().fetchToken()
    }

    func subscribe(toTopic topic: String) async throws {
        try await ready().subscribe(topic: topic)
    }

    func unsubscribe(fromTopic topic: String) async throws {
        try await ready().unsubscribe(topic: topic)
    }

    /// The host's new APNs token goes to Messaging at once; before Firebase
    /// is configured, at the next call.
    func deviceTokenDidChange() {
        guard let messaging = messaging() else { return }
        handOver(to: messaging)
    }

    /// Messaging, with the host's APNs token handed over.
    private func ready() throws -> FirebaseMessagingInstance {
        guard let messaging = messaging() else { throw FirebaseMessagingError.notConfigured }
        handOver(to: messaging)
        guard messaging.apnsToken != nil else { throw FirebaseMessagingError.noAPNsToken(registration.error) }
        return messaging
    }

    /// The host's APNs token to Messaging, when it is not Messaging's already.
    private func handOver(to messaging: FirebaseMessagingInstance) {
        if let deviceToken = registration.deviceToken, messaging.apnsToken != deviceToken {
            messaging.apnsToken = deviceToken
        }
    }
}

/// Why the Firebase adapter does not call Messaging; it fails the action.
enum FirebaseMessagingError: Error, CustomStringConvertible {
    /// No default FirebaseApp (Flutter's `[core/no-app]`).
    case notConfigured
    /// Messaging has no APNs token yet (firebase_messaging's
    /// `apns-token-not-set`), with why the host's registration failed, if it
    /// did.
    case noAPNsToken(Error?)

    var description: String {
        switch self {
        case .notConfigured:
            "Firebase is not configured: the app calls FirebaseApp.configure() at launch, with its "
                + "GoogleService-Info.plist, before the push token or topics are used"
        case .noAPNsToken(let error):
            "The APNs token has not been set yet: the app delegate hands it to the plugin's "
                + "didRegisterForRemoteNotifications(withDeviceToken:) before the push token or topics are used"
                + (error.map { " (registering failed: \($0))" } ?? "")
        }
    }
}

/// What the adapter asks of Firebase's `Messaging.messaging()`: the APNs token
/// it holds, the FCM token and the topic calls. `Messaging` in an app, a fake
/// in the tests.
@MainActor
protocol FirebaseMessagingInstance: AnyObject {
    var apnsToken: Data? { get set }
    /// The FCM registration token, nil when Firebase gives none.
    func fetchToken() async throws -> String?
    func subscribe(topic: String) async throws
    func unsubscribe(topic: String) async throws
}

extension Messaging: FirebaseMessagingInstance {
    func fetchToken() async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            // Deprecated from Firebase 12.18 for register(completion:), which is opt-in, so this still
            // works: warning accepted. Follow-up: move to register(completion:) when it is not opt-in.
            token { value, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: value) }
            }
        }
    }

    func subscribe(topic: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscribe(toTopic: topic) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func unsubscribe(topic: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unsubscribe(fromTopic: topic) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
}

#if canImport(SwiftUI) && canImport(UserNotifications)
extension PushNotificationPlugin {
    /// The plugin on the system: UNUserNotificationCenter for the
    /// notifications and Firebase Messaging for the token and topics, sharing
    /// the APNs token the host hands over. The app configures Firebase
    /// (`FirebaseApp.configure()` at launch); without it the token and topic
    /// actions fail, and local notifications work.
    public init() {
        let registration = RemoteNotificationRegistration()
        self.init(
            notifications: SystemNotifications(),
            messaging: FirebaseMessagingAdapter(registration: registration),
            registration: registration)
    }
}
#endif
