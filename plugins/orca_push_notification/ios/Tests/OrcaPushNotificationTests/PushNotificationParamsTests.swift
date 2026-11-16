import Foundation
import XCTest

import OrcaGateway
import OrcaPushNotification

/// C17.5/S: the types `orca plugin generate --lang swift --types-only` writes
/// for orca_plugin.yaml (Generated/OrcaPushNotificationTypes.swift, kept equal
/// to the generator's output by cli/test/push_notification_swift_props_test.dart)
/// read what the Flutter plugin reads (lib/src/push_notification_plugin.dart):
/// each of its five actions' params from the raw action object. The plugin has
/// no widget, and so no props and no triggers.
///
/// P-pkg/S: the manifest takes the SDK by path inside the monorepo and from
/// its mirror once split out, by where the manifest is.
final class PushNotificationParamsTests: XCTestCase {
    func testC17_5_S_TheActionNamesAreFluttersFiveInItsOrder() {
        // One params type per action, named for it (the generator's
        // `<Action>Params`), in the order Flutter registers them.
        let types: [Any.Type] = [
            RequestNotificationPermissionParams.self, GetNotificationTokenParams.self,
            ShowLocalNotificationParams.self, SubscribeToTopicParams.self, UnsubscribeFromTopicParams.self,
        ]
        let names = types.map { type -> String in
            let name = String(describing: type).replacingOccurrences(of: "Params", with: "")
            return name.prefix(1).lowercased() + name.dropFirst()
        }
        XCTAssertEqual(names, [
            "requestNotificationPermission", "getNotificationToken", "showLocalNotification", "subscribeToTopic",
            "unsubscribeFromTopic",
        ])
    }

    func testC17_5_S_RequestNotificationPermissionParamsReadFluttersRawParams() {
        let request = RequestNotificationPermissionParams([
            "type": "requestNotificationPermission", "statusKey": "pushStatus", "tokenKey": "pushToken",
            "scope": "page",
        ])
        XCTAssertEqual(request.statusKey, "pushStatus")
        XCTAssertEqual(request.tokenKey, "pushToken")
        XCTAssertEqual(request.scope, "page")

        let bare = RequestNotificationPermissionParams(["type": "requestNotificationPermission"])
        XCTAssertNil(bare.statusKey, "the plugin writes no status")
        XCTAssertNil(bare.tokenKey, "the plugin fetches no token")
        XCTAssertNil(bare.scope, "the plugin defaults it to app")

        // Flutter reads these raw (`as String?`): a Value is not resolved, and a
        // non-string reads nil here and stays in the raw action, where the
        // plugin fails the action as Flutter's cast does.
        let value: JSONValue = ["type": "static", "value": "pushStatus"]
        let odd = RequestNotificationPermissionParams([
            "type": "requestNotificationPermission", "statusKey": value, "tokenKey": 7, "scope": true,
        ])
        XCTAssertNil(odd.statusKey)
        XCTAssertNil(odd.tokenKey)
        XCTAssertNil(odd.scope)
        XCTAssertEqual(odd.action["statusKey"], value)
        XCTAssertEqual(odd.action["tokenKey"], 7)
        XCTAssertEqual(odd.action["scope"], true)
    }

    func testC17_5_S_GetNotificationTokenParamsReadFluttersRawParams() {
        let get = GetNotificationTokenParams(["type": "getNotificationToken", "tokenKey": "pushToken", "scope": "page"])
        XCTAssertEqual(get.tokenKey, "pushToken")
        XCTAssertEqual(get.scope, "page")

        let bare = GetNotificationTokenParams(["type": "getNotificationToken"])
        XCTAssertNil(bare.tokenKey, "the plugin defaults it to fcmToken")
        XCTAssertNil(bare.scope, "the plugin defaults it to app")

        let odd = GetNotificationTokenParams(["type": "getNotificationToken", "tokenKey": 1, "scope": .null])
        XCTAssertNil(odd.tokenKey, "a non-string stays in the raw action, where the plugin fails the action")
        XCTAssertEqual(odd.action["tokenKey"], 1)
        XCTAssertNil(odd.scope, "null is absent, as Flutter's `as String? ?? 'app'`")
    }

    func testC17_5_S_ShowLocalNotificationParamsReadAStringAndLeaveAValueRaw() {
        let show = ShowLocalNotificationParams([
            "type": "showLocalNotification", "title": "Orca push", "body": "Tap to open the map",
            "payload": "orcacounter://open/map",
        ])
        XCTAssertEqual(show.title, "Orca push")
        XCTAssertEqual(show.body, "Tap to open the map")
        XCTAssertEqual(show.payload, "orcacounter://open/map")

        let bare = ShowLocalNotificationParams(["type": "showLocalNotification"])
        XCTAssertNil(bare.title, "the plugin defaults it to \"\"")
        XCTAssertNil(bare.body, "the plugin defaults it to \"\"")
        XCTAssertNil(bare.payload, "the plugin shows it with \"\" as its payload")

        // Flutter resolves each as a value (`executor.resolveString`): one sent
        // as a Value, or as a non-string, reads nil here and stays in the raw
        // action for the plugin to resolve.
        let title: JSONValue = ["type": "state", "key": "name", "scope": "app"]
        let payload: JSONValue = ["type": "static", "value": "orcacounter://open/map"]
        let bound = ShowLocalNotificationParams([
            "type": "showLocalNotification", "title": title, "body": 42, "payload": payload,
        ])
        XCTAssertNil(bound.title)
        XCTAssertNil(bound.body)
        XCTAssertNil(bound.payload)
        XCTAssertEqual(bound.action["title"], title)
        XCTAssertEqual(bound.action["body"], 42)
        XCTAssertEqual(bound.action["payload"], payload)
    }

    func testC17_5_S_TheTopicParamsReadAStringAndLeaveAValueRaw() {
        XCTAssertEqual(SubscribeToTopicParams(["type": "subscribeToTopic", "topic": "news"]).topic, "news")
        XCTAssertEqual(UnsubscribeFromTopicParams(["type": "unsubscribeFromTopic", "topic": "news"]).topic, "news")
        XCTAssertNil(SubscribeToTopicParams(["type": "subscribeToTopic"]).topic, "the plugin does nothing")
        XCTAssertNil(UnsubscribeFromTopicParams(["type": "unsubscribeFromTopic"]).topic, "the plugin does nothing")

        // Resolved as a value in Flutter: a Value reads nil here and stays in
        // the raw action for the plugin to resolve.
        let topic: JSONValue = ["type": "state", "key": "topic", "scope": "page"]
        let subscribe = SubscribeToTopicParams(["type": "subscribeToTopic", "topic": topic])
        XCTAssertNil(subscribe.topic)
        XCTAssertEqual(subscribe.action["topic"], topic)
        let unsubscribe = UnsubscribeFromTopicParams(["type": "unsubscribeFromTopic", "topic": topic])
        XCTAssertNil(unsubscribe.topic)
        XCTAssertEqual(unsubscribe.action["topic"], topic)
    }

    #if os(macOS)
    /// This package's directory (this file is Tests/OrcaPushNotificationTests/).
    let packageDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testP_pkg_S_TheManifestTakesTheSDKByPathInTheMonorepoAndFromItsMirrorSplitOut() throws {
        let sdk = packageDir.appendingPathComponent("../../../sdk-swift").standardizedFileURL
        let elsewhere = try temporaryDirectory()

        // In place, evaluated from a directory with no sdk-swift beside it.
        let inPlace = try dumpPackage(packageDir, from: elsewhere)
        XCTAssertEqual(inPlace["name"], "OrcaPushNotification")
        XCTAssertEqual(inPlace["products"].arrayValue?.map { $0["name"] }, ["OrcaPushNotification"])
        XCTAssertEqual(inPlace["targets"].arrayValue?.map { $0["name"] },
                       ["OrcaPushNotification", "OrcaPushNotificationTests"])
        XCTAssertEqual(inPlace["platforms"], try dumpPackage(sdk, from: elsewhere)["platforms"],
                       "the SDK's platforms")
        // The SDK by identity, not the dependency count: another package may
        // join it (the messaging library).
        let local = only(dependencies(inPlace, kind: "fileSystem", identity: "sdk-swift"))
        XCTAssertEqual(local["path"].stringValue.map { URL(fileURLWithPath: $0).standardizedFileURL }, sdk)
        XCTAssertEqual(dependencies(inPlace, kind: "sourceControl", identity: "orca-gateway-swift"), [],
                       "not the mirror in the monorepo")

        // Split out (the manifest at the root of its mirror), evaluated from
        // this package's directory, where ../../../sdk-swift exists.
        let split = elsewhere.appendingPathComponent("split")
        try FileManager.default.createDirectory(at: split, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: packageDir.appendingPathComponent("Package.swift"), to: split.appendingPathComponent("Package.swift"))
        let mirror = try dumpPackage(split, from: packageDir)
        XCTAssertEqual(dependencies(mirror, kind: "fileSystem", identity: "sdk-swift"), [],
                       "not the SDK by path split out")
        let remote = only(dependencies(mirror, kind: "sourceControl", identity: "orca-gateway-swift"))
        // The URL as a whole JSON string anywhere in the location: SwiftPM
        // writes it bare before its SourceControlURL type, `{"urlString": …}`
        // since.
        let location = String(decoding: try remote["location"].encoded(), as: UTF8.self)
        XCTAssertTrue(location.contains("\"https://github.com/orca-gateway/orca-gateway-swift\""), location)
        XCTAssertEqual(only(remote["requirement"]["range"]), ["lowerBound": "0.1.0-alpha.2", "upperBound": "1.0.0"],
                       "the first sdk-swift release with the plugin API, up to the next major")
    }

    /// The manifest's dependencies of `kind` (fileSystem, sourceControl) with
    /// this identity, each the object inside its kind's one-element array.
    func dependencies(_ manifest: JSONValue, kind: String, identity: String) -> JSONValue {
        .array((manifest["dependencies"].arrayValue ?? [])
            .map { only($0[kind]) }
            .filter { $0["identity"] == JSONValue.string(identity) })
    }

    /// The single element of a one-element array, else null.
    func only(_ value: JSONValue) -> JSONValue {
        guard let array = value.arrayValue, array.count == 1 else { return .null }
        return array[0]
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
