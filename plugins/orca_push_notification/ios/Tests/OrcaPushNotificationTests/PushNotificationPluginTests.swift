#if canImport(SwiftUI)
import Foundation
import XCTest

import OrcaGateway
@testable import OrcaPushNotification

/// C17.4/S: the Swift PushNotificationPlugin does what the Flutter plugin does
/// (lib/src/push_notification_plugin.dart, on firebase_messaging 15.2.10 and
/// flutter_local_notifications 18.0.1), with the notification center and the
/// push service swapped for fakes: its name, no widgets, five actions and no
/// triggers; each action's params read raw or resolved as values, their
/// defaults and the state writes in their scopes; a granted and a denied
/// permission, the token after a grant, a nil token, a non-string raw key, a
/// messaging error, an empty topic; the notification's id, title, body and
/// payload; initialize's delegate and permission request; a foreground remote
/// notification shown as a local one with its data as JSON; a tap on the
/// plugin's notification handing its payload to onNotificationTap, a tap on any
/// other reaching nothing; the APNs token the host hands over. The real
/// UNUserNotificationCenter needs an app bundle: it is seen at the hand check.
@MainActor
final class PushNotificationPluginTests: XCTestCase {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    /// UNUserNotificationCenter as the plugin drives it, scripted and recorded.
    @MainActor final class FakeNotifications: Notifications {
        var authorized = true
        var authorizationError: Error?
        var addError: Error?
        /// Called when the permission is asked, after it is recorded.
        var onRequestAuthorization: (() -> Void)?
        private(set) var calls: [String] = []
        private(set) var added: [LocalNotification] = []
        private(set) var willPresent: ((DeliveredNotification) async -> Bool)?
        private(set) var didReceive: ((DeliveredNotification) -> Void)?

        func requestAuthorization() async throws -> Bool {
            calls.append("requestAuthorization")
            onRequestAuthorization?()
            if let authorizationError { throw authorizationError }
            return authorized
        }

        func add(_ notification: LocalNotification) async throws {
            calls.append("add")
            if let addError { throw addError }
            added.append(notification)
        }

        func becomeDelegate(
            willPresent: @escaping @MainActor (DeliveredNotification) async -> Bool,
            didReceive: @escaping @MainActor (DeliveredNotification) -> Void
        ) {
            calls.append("becomeDelegate")
            self.willPresent = willPresent
            self.didReceive = didReceive
        }

        func registerForRemoteNotifications() {
            calls.append("registerForRemoteNotifications")
        }
    }

    /// The push service (Firebase Messaging or APNs alone), scripted and
    /// recorded.
    @MainActor final class FakeMessaging: PushMessaging {
        var nextToken: String? = "token-1"
        var error: Error?
        private(set) var calls: [String] = []

        func token() async throws -> String? {
            calls.append("token")
            if let error { throw error }
            return nextToken
        }

        func subscribe(toTopic topic: String) async throws {
            calls.append("subscribe \(topic)")
            if let error { throw error }
        }

        func unsubscribe(fromTopic topic: String) async throws {
            calls.append("unsubscribe \(topic)")
            if let error { throw error }
        }
    }

    /// The plugin on fakes, its actions registered on an executor as OrcaApp
    /// registers a plugin's actions on every page.
    @MainActor final class Harness {
        let notifications = FakeNotifications()
        let messaging = FakeMessaging()
        let registration = RemoteNotificationRegistration()
        let plugin: PushNotificationPlugin
        let executor: ActionExecutor
        /// What onNotificationTap was called with, once initialized.
        private(set) var taps: [String?] = []

        init(_ state: StoreState = StoreState()) {
            executor = ActionExecutor(store: ElmStore(state))
            plugin = PushNotificationPlugin(notifications: notifications, messaging: messaging, registration: registration)
            for (type, handler) in plugin.actions { executor.registerHandler(type, handler) }
        }

        func run(_ raw: JSONValue) async throws {
            try await executor.execute(try raw.decode(Action.self))
        }

        /// The error the action fails with, as text; nil when it does not fail.
        func failure(_ raw: JSONValue) async -> String? {
            do {
                try await run(raw)
                return nil
            } catch {
                return "\(error)"
            }
        }

        var state: StoreState { executor.store.state }

        /// The plugin initialized as the host does at launch, its taps recorded.
        func initialize() {
            plugin.initialize(onNotificationTap: { [unowned self] in self.taps.append($0) })
        }

        /// The center asking how to present a notification in the foreground.
        func willPresent(_ notification: DeliveredNotification) async throws -> Bool {
            let willPresent = try XCTUnwrap(notifications.willPresent, "initialize made the plugin the delegate")
            return await willPresent(notification)
        }

        /// The user tapping a notification.
        func tap(_ notification: DeliveredNotification) throws {
            try XCTUnwrap(notifications.didReceive, "initialize made the plugin the delegate")(notification)
        }
    }

    /// What a second tap handler hears.
    @MainActor final class Taps {
        var payloads: [String?] = []
    }

    static let actionNames: Set<String> = [
        "requestNotificationPermission", "getNotificationToken", "showLocalNotification", "subscribeToTopic",
        "unsubscribeFromTopic",
    ]

    /// A notification the plugin added, as the center hands it back.
    func delivered(_ notification: LocalNotification) -> DeliveredNotification {
        DeliveredNotification(identifier: String(notification.id), isRemote: false, userInfo: notification.userInfo)
    }

    /// A remote (APNs) notification with this userInfo.
    func remote(_ userInfo: [String: JSONValue], identifier: String = UUID().uuidString) -> DeliveredNotification {
        DeliveredNotification(identifier: identifier, isRemote: true, userInfo: userInfo)
    }

    // MARK: The plugin

    func testC17_4_S_ThePluginHasFluttersNameNoWidgetsFiveActionsAndNoTriggers() throws {
        let plugin = Harness().plugin
        XCTAssertEqual(plugin.name, "PushNotificationPlugin")
        XCTAssertTrue(plugin.widgets.isEmpty)
        XCTAssertEqual(Set(plugin.actions.keys), Self.actionNames)
        XCTAssertTrue(plugin.triggers.isEmpty)

        let merged = try PluginMerger.merge(
            builtInWidgets: Set(GeneratedCapabilities.widgets), plugins: [plugin.parts])
        XCTAssertEqual(merged.widgetOwners, [:])
        XCTAssertEqual(merged.pluginActionTypes, Self.actionNames)
    }

    // MARK: requestNotificationPermission

    func testC17_4_S_AGrantedPermissionWritesGrantedAndThenTheTokenIntoAppScopeByDefault() async throws {
        let h = Harness()
        try await h.run([
            "type": "requestNotificationPermission", "statusKey": "pushStatus", "tokenKey": "pushToken",
        ])
        XCTAssertEqual(h.notifications.calls, ["requestAuthorization"], "alert, badge and sound, asked once")
        XCTAssertEqual(h.messaging.calls, ["token"], "the token as getNotificationToken gets it")
        XCTAssertEqual(h.state, StoreState(app: ["pushStatus": "granted", "pushToken": "token-1"]))
    }

    func testC17_4_S_ADeniedPermissionWritesDeniedAndGetsNoToken() async throws {
        let h = Harness()
        h.notifications.authorized = false
        try await h.run([
            "type": "custom:requestNotificationPermission", "statusKey": "pushStatus", "tokenKey": "pushToken",
            "scope": "page",
        ])
        XCTAssertEqual(h.messaging.calls, [])
        XCTAssertEqual(h.state, StoreState(page: ["pushStatus": "denied"]))
    }

    func testC17_4_S_RequestNotificationPermissionWritesOnlyTheKeysItIsGivenAndANilTokenWritesNothing() async throws {
        let bare = Harness()
        try await bare.run(["type": "requestNotificationPermission"])
        XCTAssertEqual(bare.notifications.calls, ["requestAuthorization"])
        XCTAssertEqual(bare.messaging.calls, [], "no tokenKey, no token")
        XCTAssertEqual(bare.state, StoreState())

        let tokenOnly = Harness()
        try await tokenOnly.run([
            "type": "requestNotificationPermission", "statusKey": .null, "tokenKey": "pushToken", "scope": "page",
        ])
        XCTAssertEqual(tokenOnly.state, StoreState(page: ["pushToken": "token-1"]), "a null key is no key")

        let noToken = Harness()
        noToken.messaging.nextToken = nil
        try await noToken.run([
            "type": "requestNotificationPermission", "statusKey": "pushStatus", "tokenKey": "pushToken",
        ])
        XCTAssertEqual(noToken.messaging.calls, ["token"])
        XCTAssertEqual(noToken.state, StoreState(app: ["pushStatus": "granted"]), "a nil token writes nothing")
    }

    // MARK: getNotificationToken

    func testC17_4_S_GetNotificationTokenWritesTheTokenOrNullIntoFcmTokenInAppScopeByDefault() async throws {
        let h = Harness()
        try await h.run(["type": "getNotificationToken"])
        XCTAssertEqual(h.state, StoreState(app: ["fcmToken": "token-1"]))
        XCTAssertEqual(h.notifications.calls, [], "no permission asked")

        h.messaging.nextToken = nil
        try await h.run(["type": "getNotificationToken"])
        XCTAssertEqual(h.state, StoreState(app: ["fcmToken": .null]), "no token writes null")

        let keyed = Harness()
        try await keyed.run(["type": "custom:getNotificationToken", "tokenKey": "pushToken", "scope": "page"])
        XCTAssertEqual(keyed.state, StoreState(page: ["pushToken": "token-1"]))
        XCTAssertEqual(keyed.messaging.calls, ["token"])
    }

    // MARK: Failures

    func testC17_4_S_ANonStringRawKeyFailsTheActionAsFluttersCastDoes() async throws {
        // Read raw, never resolved: a Value object is not a string either.
        let value: JSONValue = ["type": "static", "value": "pushStatus"]

        let status = Harness()
        let statusFailure = await status.failure(["type": "requestNotificationPermission", "statusKey": 7])
        XCTAssertEqual(statusFailure, "statusKey is not a string: 7")
        XCTAssertEqual(status.notifications.calls, ["requestAuthorization"], "asked first, then cast, as Flutter")
        XCTAssertEqual(status.state, StoreState())

        let token = Harness()
        let tokenFailure = await token.failure(["type": "requestNotificationPermission", "tokenKey": value])
        XCTAssertEqual(tokenFailure, "tokenKey is not a string: {type: static, value: pushStatus}")
        XCTAssertEqual(token.messaging.calls, [])

        let scope = Harness()
        let scopeFailure = await scope.failure([
            "type": "requestNotificationPermission", "statusKey": "pushStatus", "scope": true,
        ])
        XCTAssertEqual(scopeFailure, "scope is not a string: true")
        XCTAssertEqual(scope.state, StoreState(), "cast before any write")

        let get = Harness()
        let getFailure = await get.failure(["type": "getNotificationToken", "tokenKey": 1])
        XCTAssertEqual(getFailure, "tokenKey is not a string: 1")
        XCTAssertEqual(get.messaging.calls, [], "cast before the token")
        let getScopeFailure = await get.failure(["type": "getNotificationToken", "scope": value])
        XCTAssertEqual(getScopeFailure, "scope is not a string: {type: static, value: pushStatus}")
        XCTAssertEqual(get.state, StoreState())
    }

    func testC17_4_S_AMessagingOrNotificationsErrorFailsTheAction() async throws {
        let get = Harness()
        get.messaging.error = Failure(description: "Firebase is not set up")
        let getFailure = await get.failure(["type": "getNotificationToken"])
        XCTAssertEqual(getFailure, "Firebase is not set up")
        XCTAssertEqual(get.state, StoreState(), "nothing written")

        // The status is written before the token is asked, as in Flutter.
        let request = Harness()
        request.messaging.error = Failure(description: "Firebase is not set up")
        let requestFailure = await request.failure([
            "type": "requestNotificationPermission", "statusKey": "pushStatus", "tokenKey": "pushToken",
        ])
        XCTAssertEqual(requestFailure, "Firebase is not set up")
        XCTAssertEqual(request.state, StoreState(app: ["pushStatus": "granted"]))

        let asked = Harness()
        asked.notifications.authorizationError = Failure(description: "not allowed")
        let askedFailure = await asked.failure(["type": "requestNotificationPermission", "statusKey": "pushStatus"])
        XCTAssertEqual(askedFailure, "not allowed")
        XCTAssertEqual(asked.state, StoreState())

        let topic = Harness()
        topic.messaging.error = Failure(description: "topics are off")
        let subscribeFailure = await topic.failure(["type": "subscribeToTopic", "topic": "news"])
        XCTAssertEqual(subscribeFailure, "topics are off")
        let unsubscribeFailure = await topic.failure(["type": "unsubscribeFromTopic", "topic": "news"])
        XCTAssertEqual(unsubscribeFailure, "topics are off")

        let show = Harness()
        show.notifications.addError = Failure(description: "cannot add")
        let showFailure = await show.failure(["type": "showLocalNotification", "title": "Hi"])
        XCTAssertEqual(showFailure, "cannot add")
    }

    // MARK: showLocalNotification

    func testC17_4_S_ShowLocalNotificationShowsTitleBodyAndPayloadUnderTheCurrentTimeInSeconds() async throws {
        let h = Harness()
        let before = Int(Date().timeIntervalSince1970)
        try await h.run([
            "type": "showLocalNotification", "title": "Orca push", "body": "Tap to open the map",
            "payload": "orcacounter://open/map",
        ])
        let after = Int(Date().timeIntervalSince1970)

        let shown = try XCTUnwrap(h.notifications.added.first)
        XCTAssertEqual(h.notifications.added.count, 1)
        XCTAssertTrue((before...after).contains(shown.id), "\(shown.id) is the time in seconds")
        XCTAssertEqual(shown.title, "Orca push")
        XCTAssertEqual(shown.body, "Tap to open the map")
        XCTAssertEqual(shown.userInfo, ["orcaNotificationId": .int(shown.id), "payload": "orcacounter://open/map"])
        XCTAssertEqual(h.state, StoreState(), "no state")

        try await h.run(["type": "custom:showLocalNotification"])
        let bare = try XCTUnwrap(h.notifications.added.last)
        XCTAssertEqual(bare.title, "", "Flutter's default")
        XCTAssertEqual(bare.body, "", "Flutter's default")
        XCTAssertEqual(bare.userInfo, ["orcaNotificationId": .int(bare.id)], "no payload")
    }

    func testC17_4_S_TitleBodyPayloadAndTopicAreResolvedAsValues() async throws {
        let h = Harness(StoreState(page: ["name": "Orca", "topic": "news"]))
        try await h.run([
            "type": "showLocalNotification", "title": ["type": "state", "scope": "page", "key": "name"],
            "body": 42, "payload": ["type": "static", "value": "orcacounter://open/map"],
        ])
        let shown = try XCTUnwrap(h.notifications.added.first)
        XCTAssertEqual(shown.title, "Orca")
        XCTAssertEqual(shown.body, "42", "a number reads as its Dart toString")
        XCTAssertEqual(shown.userInfo["payload"], "orcacounter://open/map")

        // A payload sent that resolves to null is "", as resolveString; a
        // null payload is none.
        try await h.run([
            "type": "showLocalNotification", "payload": ["type": "state", "scope": "page", "key": "missing"],
        ])
        XCTAssertEqual(h.notifications.added.last?.userInfo["payload"], "")
        try await h.run(["type": "showLocalNotification", "payload": .null])
        XCTAssertEqual(h.notifications.added.last?.userInfo["payload"], nil)

        let topic: JSONValue = ["type": "state", "scope": "page", "key": "topic"]
        try await h.run(["type": "subscribeToTopic", "topic": topic])
        try await h.run(["type": "unsubscribeFromTopic", "topic": topic])
        XCTAssertEqual(h.messaging.calls, ["subscribe news", "unsubscribe news"])
    }

    // MARK: Topics

    func testC17_4_S_SubscribeAndUnsubscribeGoToTheMessagingAndAnEmptyTopicDoesNothing() async throws {
        let h = Harness()
        try await h.run(["type": "subscribeToTopic", "topic": "news"])
        try await h.run(["type": "custom:unsubscribeFromTopic", "topic": "news"])
        XCTAssertEqual(h.messaging.calls, ["subscribe news", "unsubscribe news"])

        try await h.run(["type": "subscribeToTopic"])
        try await h.run(["type": "subscribeToTopic", "topic": ""])
        try await h.run(["type": "unsubscribeFromTopic", "topic": .null])
        try await h.run(["type": "unsubscribeFromTopic", "topic": ["type": "state", "scope": "page", "key": "none"]])
        XCTAssertEqual(h.messaging.calls, ["subscribe news", "unsubscribe news"], "an empty topic does nothing")
        XCTAssertEqual(h.state, StoreState())
    }

    // MARK: initialize

    func testC17_4_S_InitializeBecomesTheDelegateRegistersForPushAndAsksForPermissionOnce() async throws {
        let h = Harness()
        let asked = expectation(description: "the permission asked at launch")
        h.notifications.onRequestAuthorization = { asked.fulfill() }
        h.initialize()
        XCTAssertEqual(h.notifications.calls, ["becomeDelegate", "registerForRemoteNotifications"],
                       "the delegate before initialize returns, as iOS needs at launch")
        await fulfillment(of: [asked], timeout: 5)
        h.notifications.onRequestAuthorization = nil
        XCTAssertEqual(h.notifications.calls,
                       ["becomeDelegate", "registerForRemoteNotifications", "requestAuthorization"])

        // A second initialize does nothing, as Flutter's `_initialized`: the
        // first tap handler stays.
        let second = Taps()
        h.plugin.initialize(onNotificationTap: { second.payloads.append($0) })
        try await h.run(["type": "showLocalNotification", "payload": "first"])
        try h.tap(delivered(try XCTUnwrap(h.notifications.added.first)))
        XCTAssertEqual(h.taps, ["first"])
        XCTAssertEqual(second.payloads, [])
        XCTAssertEqual(h.notifications.calls.filter { $0 == "becomeDelegate" }.count, 1)
    }

    func testC17_4_S_TheForegroundPresentsThePluginsOwnNotificationsOnly() async throws {
        let h = Harness()
        h.initialize()
        try await h.run(["type": "showLocalNotification", "title": "Hi"])
        let own = try await h.willPresent(delivered(try XCTUnwrap(h.notifications.added.first)))
        XCTAssertTrue(own, "banner, list, sound and badge")

        let other = try await h.willPresent(
            DeliveredNotification(identifier: "x", isRemote: false, userInfo: ["payload": "elsewhere"]))
        XCTAssertFalse(other, "not the plugin's")
        let silent = try await h.willPresent(remote(["aps": ["content-available": 1], "link": "a"]))
        XCTAssertFalse(silent, "a remote message with no notification")
        XCTAssertEqual(h.notifications.added.count, 1, "nothing shown for either")
    }

    func testC17_4_S_AForegroundRemoteNotificationIsShownAsALocalOneWithItsDataAsJSON() async throws {
        let h = Harness()
        h.initialize()
        let message = remote([
            "aps": ["alert": ["title": "Order shipped", "body": "Tap to track it"], "sound": "default"],
            "link": "orcacounter://open/map", "count": 2,
            // Firebase's own keys are not the message's data, as
            // firebase_messaging reads it.
            "gcm.message_id": "1", "google.c.a.e": "1", "fcm_options": ["image": "https://x"], "from": "sender",
        ], identifier: "remote-1")

        let presented = try await h.willPresent(message)
        XCTAssertFalse(presented, "not presented itself")
        let shown = try XCTUnwrap(h.notifications.added.first)
        XCTAssertEqual(h.notifications.added.count, 1)
        XCTAssertTrue((0 ..< 1 << 30).contains(shown.id))
        XCTAssertEqual(shown.title, "Order shipped")
        XCTAssertEqual(shown.body, "Tap to track it")
        XCTAssertEqual(shown.userInfo["payload"], #"{"count":2,"link":"orcacounter://open/map"}"#)

        // Shown once when iOS 18 asks twice for the same notification, as
        // firebase_messaging guards.
        _ = try await h.willPresent(message)
        XCTAssertEqual(h.notifications.added.count, 1)

        // A string alert is the title, as firebase_messaging reads it.
        _ = try await h.willPresent(remote(["aps": ["alert": "Hello"]]))
        XCTAssertEqual(h.notifications.added.last?.title, "Hello")
        XCTAssertEqual(h.notifications.added.last?.body, "")
        XCTAssertEqual(h.notifications.added.last?.userInfo["payload"], "{}")

        // Its tap hands the data's JSON to onNotificationTap.
        try h.tap(delivered(shown))
        XCTAssertEqual(h.taps, [#"{"count":2,"link":"orcacounter://open/map"}"#])
    }

    // MARK: The tap

    func testC17_4_S_ATapOnTheNotificationThePluginShowedHandsItsPayloadToOnNotificationTap() async throws {
        let h = Harness()
        h.initialize()
        try await h.run(["type": "showLocalNotification", "title": "Orca", "payload": "orcacounter://open/map"])
        try await h.run(["type": "showLocalNotification", "title": "No payload"])

        try h.tap(delivered(h.notifications.added[0]))
        try h.tap(delivered(h.notifications.added[1]))
        XCTAssertEqual(h.taps, ["orcacounter://open/map", nil])
    }

    func testC17_4_S_ATapOnANotificationThePluginDidNotShowReachesNothing() async throws {
        let h = Harness()
        h.initialize()
        try h.tap(remote(["aps": ["alert": "Background push"], "link": "orcacounter://open/map"]))
        try h.tap(DeliveredNotification(identifier: "7", isRemote: false, userInfo: ["payload": "elsewhere"]))
        XCTAssertEqual(h.taps, [])
    }

    // MARK: The APNs token

    func testC17_4_S_TheHostHandsTheAPNsTokenOverAndItIsKeptForTheMessaging() async throws {
        let h = Harness()
        XCTAssertNil(h.registration.deviceToken)

        h.plugin.didFailToRegisterForRemoteNotifications(withError: Failure(description: "no aps-environment"))
        XCTAssertEqual(h.registration.error.map { "\($0)" }, "no aps-environment")
        XCTAssertNil(h.registration.deviceToken)

        let token = Data([0xde, 0xad, 0xbe, 0xef])
        h.plugin.didRegisterForRemoteNotifications(withDeviceToken: token)
        XCTAssertEqual(h.registration.deviceToken, token)
        XCTAssertNil(h.registration.error, "the token, or why there is none")
        XCTAssertEqual(h.messaging.calls, [], "kept, not fetched")
    }
}
#endif
