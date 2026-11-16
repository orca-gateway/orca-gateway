#if canImport(SwiftUI)
import Foundation
import XCTest

import OrcaGateway
@testable import OrcaPushNotification

/// C17.4/S-token: the token and topics through Firebase Messaging
/// (firebase-ios-sdk), as the Flutter plugin's firebase_messaging 15.2.10 does
/// on iOS: the default init is the system's notification center and Firebase
/// on one APNs registration, with Flutter's name; without a configured
/// Firebase app the token and topic calls, and so the three actions, fail with
/// a message naming FirebaseApp.configure(), and nothing crashes; the APNs
/// token the host hands over reaches Messaging before each call, whichever
/// comes first, as firebase_messaging's ensureAPNSTokenSetting, and a call
/// before any APNs token fails as its apns-token-not-set check does;
/// Messaging's token, a nil token and its errors reach the actions. Messaging
/// itself is a fake here: a real FCM token, real topics and the real APNs
/// hand-off need the user's Firebase project and a device, at the hand check.
///
/// The manifest's whole dependency list, inside the monorepo and split out:
/// the SDK, then firebase-ios-sdk for FirebaseMessaging on the library.
@MainActor
final class PushMessagingTests: XCTestCase {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    /// Firebase's `Messaging.messaging()` as the adapter drives it, scripted
    /// and recorded.
    @MainActor final class FakeFirebaseMessaging: FirebaseMessagingInstance {
        var apnsToken: Data? {
            didSet { calls.append("apnsToken \(apnsToken.map(PushMessagingTests.hex) ?? "nil")") }
        }
        var nextToken: String? = "fcm-1"
        var error: Error?
        private(set) var calls: [String] = []

        /// Messaging holding `apnsToken` already (not recorded).
        init(apnsToken: Data? = nil) {
            self.apnsToken = apnsToken
        }

        func fetchToken() async throws -> String? {
            calls.append("token")
            if let error { throw error }
            return nextToken
        }

        func subscribe(topic: String) async throws {
            calls.append("subscribe \(topic)")
            if let error { throw error }
        }

        func unsubscribe(topic: String) async throws {
            calls.append("unsubscribe \(topic)")
            if let error { throw error }
        }
    }

    /// The plugin on the Firebase adapter, the adapter on a fake Messaging that
    /// exists once the host has configured Firebase; its actions registered on
    /// an executor as OrcaApp registers a plugin's actions.
    @MainActor final class Harness {
        let firebase: FakeFirebaseMessaging
        /// Whether the host has called FirebaseApp.configure().
        var configured = true
        let registration = RemoteNotificationRegistration()
        private(set) var adapter: FirebaseMessagingAdapter!
        private(set) var plugin: PushNotificationPlugin!
        let executor = ActionExecutor(store: ElmStore(StoreState()))

        init(firebase: FakeFirebaseMessaging? = nil) {
            self.firebase = firebase ?? FakeFirebaseMessaging()
            adapter = FirebaseMessagingAdapter(
                registration: registration, messaging: { [unowned self] in configured ? self.firebase : nil })
            plugin = PushNotificationPlugin(
                notifications: PushNotificationPluginTests.FakeNotifications(), messaging: adapter,
                registration: registration)
            for (type, handler) in plugin.actions { executor.registerHandler(type, handler) }
        }

        /// The error the action fails with, as text; nil when it does not fail.
        func failure(_ raw: JSONValue) async -> String? {
            await PushMessagingTests.failure { try await self.executor.execute(try raw.decode(Action.self)) }
        }

        func run(_ raw: JSONValue) async throws {
            try await executor.execute(try raw.decode(Action.self))
        }

        var state: StoreState { executor.store.state }
    }

    static let notConfigured = "Firebase is not configured: the app calls FirebaseApp.configure() at launch, "
        + "with its GoogleService-Info.plist, before the push token or topics are used"
    static let noAPNsToken = "The APNs token has not been set yet: the app delegate hands it to the plugin's "
        + "didRegisterForRemoteNotifications(withDeviceToken:) before the push token or topics are used"
    static let apnsA = Data([0x0a, 0x0b])
    static let apnsB = Data([0xbe, 0xef])

    nonisolated static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// What `body` throws, as text; nil when it does not throw.
    static func failure(_ body: () async throws -> Void) async -> String? {
        do {
            try await body()
            return nil
        } catch {
            return "\(error)"
        }
    }

    /// The adapter's three calls, each one's failure as text (nil: none).
    static func failures(_ adapter: FirebaseMessagingAdapter) async -> [String?] {
        [
            await failure { _ = try await adapter.token() },
            await failure { try await adapter.subscribe(toTopic: "news") },
            await failure { try await adapter.unsubscribe(fromTopic: "news") },
        ]
    }

    // MARK: The default init

    func testC17_4_S_token_TheDefaultInitIsTheNotificationCenterAndFirebaseOnOneRegistration() throws {
        let plugin = PushNotificationPlugin()
        XCTAssertEqual(plugin.name, "PushNotificationPlugin")
        XCTAssertEqual(Set(plugin.actions.keys), PushNotificationPluginTests.actionNames)
        XCTAssertTrue(plugin.push.notifications is SystemNotifications)
        let firebase = try XCTUnwrap(plugin.push.messaging as? FirebaseMessagingAdapter)
        XCTAssertTrue(firebase.registration === plugin.push.registration,
                      "the APNs token the host hands the plugin is the one the adapter reads")
    }

    // MARK: Firebase not configured

    func testC17_4_S_token_WithoutAConfiguredFirebaseAppTheCallsThrowTheClearErrorAndNothingCrashes() async {
        // This test process never calls FirebaseApp.configure(): no default
        // app, where Messaging.messaging() would raise.
        let registration = RemoteNotificationRegistration()
        registration.deviceToken = Self.apnsA
        let failures = await Self.failures(FirebaseMessagingAdapter(registration: registration))
        XCTAssertEqual(failures, [Self.notConfigured, Self.notConfigured, Self.notConfigured])
    }

    func testC17_4_S_token_WithoutAConfiguredFirebaseAppTheThreeActionsFailWithThatMessage() async {
        let plugin = PushNotificationPlugin()
        let executor = ActionExecutor(store: ElmStore(StoreState()))
        for (type, handler) in plugin.actions { executor.registerHandler(type, handler) }
        let actions: [JSONValue] = [
            ["type": "getNotificationToken"], ["type": "subscribeToTopic", "topic": "news"],
            ["type": "unsubscribeFromTopic", "topic": "news"],
        ]
        for action in actions {
            let failure = await Self.failure { try await executor.execute(try action.decode(Action.self)) }
            XCTAssertEqual(failure, Self.notConfigured, "\(action)")
        }
        XCTAssertEqual(executor.store.state, StoreState(), "nothing written")
    }

    // MARK: The APNs token, in either order

    func testC17_4_S_token_AnAPNsTokenHandedOverBeforeFirebaseIsConfiguredReachesMessagingAtTheFirstCall() async throws {
        let h = Harness()
        h.configured = false
        h.plugin.didRegisterForRemoteNotifications(withDeviceToken: Self.apnsA)
        let early = await Self.failures(h.adapter)
        XCTAssertEqual(early, [Self.notConfigured, Self.notConfigured, Self.notConfigured])
        XCTAssertEqual(h.firebase.calls, [], "no Messaging before Firebase is configured")

        h.configured = true
        let token = try await h.adapter.token()
        XCTAssertEqual(token, "fcm-1")
        XCTAssertEqual(h.firebase.calls, ["apnsToken 0a0b", "token"], "the APNs token first")
    }

    func testC17_4_S_token_ACallBeforeAnyAPNsTokenFailsAsFirebaseMessagingsCheckAndALaterTokenIsHandedOver() async throws {
        let h = Harness()
        let early = await Self.failures(h.adapter)
        XCTAssertEqual(early, [Self.noAPNsToken, Self.noAPNsToken, Self.noAPNsToken])
        XCTAssertEqual(h.firebase.calls, [], "Messaging is not asked without an APNs token")

        // Why there is none, when the host handed that over.
        h.plugin.didFailToRegisterForRemoteNotifications(withError: Failure(description: "no aps-environment"))
        let failed = await Self.failures(h.adapter)
        XCTAssertEqual(failed[0], Self.noAPNsToken + " (registering failed: no aps-environment)")
        XCTAssertEqual(h.firebase.calls, [])

        h.plugin.didRegisterForRemoteNotifications(withDeviceToken: Self.apnsA)
        try await h.adapter.subscribe(toTopic: "news")
        XCTAssertEqual(h.firebase.calls, ["apnsToken 0a0b", "subscribe news"])
    }

    func testC17_4_S_token_ANewAPNsTokenReplacesMessagingsAndTheSameOneIsNotHandedAgain() async throws {
        let h = Harness()
        h.plugin.didRegisterForRemoteNotifications(withDeviceToken: Self.apnsA)
        _ = try await h.adapter.token()
        try await h.adapter.unsubscribe(fromTopic: "news")
        h.plugin.didRegisterForRemoteNotifications(withDeviceToken: Self.apnsB)
        _ = try await h.adapter.token()
        XCTAssertEqual(h.firebase.calls, ["apnsToken 0a0b", "token", "unsubscribe news", "apnsToken beef", "token"])
    }

    func testC17_4_S_token_MessagingsOwnAPNsTokenIsEnoughWithoutTheHosts() async throws {
        let h = Harness(firebase: FakeFirebaseMessaging(apnsToken: Self.apnsA))
        let token = try await h.adapter.token()
        XCTAssertEqual(token, "fcm-1")
        XCTAssertEqual(h.firebase.calls, ["token"])
    }

    // MARK: Through the actions

    func testC17_4_S_token_MessagingsTokenANilTokenTopicsAndErrorsReachTheActions() async throws {
        let h = Harness()
        h.plugin.didRegisterForRemoteNotifications(withDeviceToken: Self.apnsA)
        try await h.run(["type": "getNotificationToken"])
        XCTAssertEqual(h.state, StoreState(app: ["fcmToken": "fcm-1"]))

        h.firebase.nextToken = nil
        try await h.run(["type": "getNotificationToken"])
        XCTAssertEqual(h.state, StoreState(app: ["fcmToken": .null]), "no token writes null")

        try await h.run(["type": "subscribeToTopic", "topic": "news"])
        try await h.run(["type": "unsubscribeFromTopic", "topic": "news"])
        XCTAssertEqual(h.firebase.calls, ["apnsToken 0a0b", "token", "token", "subscribe news", "unsubscribe news"])

        h.firebase.error = Failure(description: "fcm is down")
        let failures = [
            await h.failure(["type": "getNotificationToken", "tokenKey": "pushToken"]),
            await h.failure(["type": "subscribeToTopic", "topic": "news"]),
            await h.failure(["type": "unsubscribeFromTopic", "topic": "news"]),
        ]
        XCTAssertEqual(failures, ["fcm is down", "fcm is down", "fcm is down"])
        XCTAssertEqual(h.state, StoreState(app: ["fcmToken": .null]), "nothing written")
    }

    // MARK: The manifest

    #if os(macOS)
    /// This package's directory (this file is Tests/OrcaPushNotificationTests/).
    let packageDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// firebase-ios-sdk as the manifest takes it in both branches: by URL, the
    /// 12.17 releases (12.18 deprecates Messaging's FCM token; 13 needs Xcode
    /// 26.2, CI builds with 16.4).
    static let firebase: JSONValue = [
        "identity": "firebase-ios-sdk",
        "location": "https://github.com/firebase/firebase-ios-sdk",
        "requirement": ["range": [["lowerBound": "12.17.0", "upperBound": "12.18.0"]]],
    ]

    func testC17_4_S_token_TheManifestsWholeDependencyListIsTheSDKThenFirebaseInBothBranches() throws {
        let sdk = packageDir.appendingPathComponent("../../../sdk-swift").standardizedFileURL
        let elsewhere = try temporaryDirectory()

        // In place, evaluated from a directory with no sdk-swift beside it.
        let inPlace = try dumpPackage(packageDir, from: elsewhere)
        let local = try XCTUnwrap(inPlace["dependencies"].arrayValue)
        XCTAssertEqual(local.count, 2, "\(local)")
        let paths = local.first?["fileSystem"].arrayValue
        XCTAssertEqual(paths?.count, 1)
        let path = paths?.first
        XCTAssertEqual(path?["identity"], "sdk-swift")
        XCTAssertEqual(path?["path"].stringValue.map { URL(fileURLWithPath: $0).standardizedFileURL }, sdk)
        XCTAssertEqual(local.last.map(Self.remote), Self.firebase)

        // Split out (the manifest at the root of its mirror), evaluated from
        // this package's directory, where ../../../sdk-swift exists.
        let split = elsewhere.appendingPathComponent("split")
        try FileManager.default.createDirectory(at: split, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: packageDir.appendingPathComponent("Package.swift"), to: split.appendingPathComponent("Package.swift"))
        let splitManifest = try dumpPackage(split, from: packageDir)
        let mirror = try XCTUnwrap(splitManifest["dependencies"].arrayValue)
        XCTAssertEqual(mirror.map(Self.remote), [
            [
                "identity": "orca-gateway-swift", "location": "https://github.com/orca-gateway/orca-gateway-swift",
                "requirement": ["range": [["lowerBound": "0.1.0-alpha.2", "upperBound": "1.0.0"]]],
            ],
            Self.firebase,
        ])

        // FirebaseMessaging on the library, after the SDK; the tests take
        // neither more nor less than before.
        for (manifest, sdkIdentity) in [(inPlace, "sdk-swift"), (splitManifest, "orca-gateway-swift")] {
            let targets = try XCTUnwrap(manifest["targets"].arrayValue)
            XCTAssertEqual(targets.map { $0["name"] }, ["OrcaPushNotification", "OrcaPushNotificationTests"])
            let products = targets[0]["dependencies"].arrayValue?
                .map { JSONValue.array(Array(($0["product"].arrayValue ?? []).prefix(2))) }
            XCTAssertEqual(products, [["OrcaGateway", .string(sdkIdentity)], ["FirebaseMessaging", "firebase-ios-sdk"]])
            XCTAssertEqual(targets[1]["dependencies"].arrayValue?.count, 2)
        }
    }

    /// A source control dependency as its identity, its URL (SwiftPM writes it
    /// bare before its SourceControlURL type, `{"urlString": …}` since) and its
    /// requirement; null for anything else.
    static func remote(_ dependency: JSONValue) -> JSONValue {
        guard let control = dependency["sourceControl"].arrayValue, control.count == 1,
              let remote = control[0]["location"]["remote"].arrayValue, remote.count == 1
        else { return .null }
        let url = remote[0].stringValue ?? remote[0]["urlString"].stringValue
        return [
            "identity": control[0]["identity"], "location": url.map(JSONValue.string) ?? .null,
            "requirement": control[0]["requirement"],
        ]
    }

    /// A new empty directory, removed after the test.
    func temporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("orca-push-notification-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    /// `swift package dump-package` of the package in `dir`, run from `cwd`
    /// with its own scratch directory (this package's .build is the running
    /// test's), as JSON.
    func dumpPackage(_ dir: URL, from cwd: URL) throws -> JSONValue {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift", "package", "--package-path", dir.path, "--scratch-path", try temporaryDirectory().path,
            "dump-package",
        ]
        process.currentDirectoryURL = cwd
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let json = out.fileHandleForReading.readDataToEndOfFile()
        let message = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "dump-package of \(dir.path): \(message)")
        return try JSONValue.decode(json)
    }
    #endif
}
#endif
