import Foundation
import XCTest

import OrcaGateway
import OrcaVideoPlayer

/// C17.5/S: the types `orca plugin generate --lang swift --types-only` writes
/// for orca_plugin.yaml (Generated/OrcaVideoPlayerTypes.swift, kept equal to
/// the generator's output by cli/test/video_player_swift_props_test.dart)
/// read what the Flutter plugin reads (lib/src/video_player_plugin.dart):
/// the VideoPlayer node's six props, its five trigger names, and each of the
/// five actions' params from the raw action object.
///
/// P-pkg/S: the manifest takes the SDK by path inside the monorepo and from
/// its mirror once split out, by where the manifest is.
final class VideoPlayerPropsTests: XCTestCase {
    /// A VideoPlayer node with these props, resolved against `state` as the
    /// SDK resolves a page's node.
    func node(_ props: [String: JSONValue], state: StoreState = StoreState()) throws -> ResolvedNode {
        let page = try JSONValue.object([
            "pageId": "video", "title": "Video", "state": [],
            "components": [
                ["id": "player", "type": "VideoPlayer", "kind": "primitive", "childMode": "none",
                 "props": .object(props), "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self)
        let renderer = PageRenderer(page: page, registry: WidgetRegistry(types: ["VideoPlayer"]))
        return try XCTUnwrap(renderer.resolve("player", state: state))
    }

    func testC17_5_S_VideoPlayerPropsReadFluttersSixProps() throws {
        let props = VideoPlayerProps(try node([
            "url": "https://example.com/clip.mp4", "autoPlay": true, "looping": true, "showControls": false,
            "aspectRatio": 1.5, "playerId": "demo",
        ]))
        XCTAssertEqual(props.url, "https://example.com/clip.mp4")
        XCTAssertEqual(props.autoPlay, true)
        XCTAssertEqual(props.looping, true)
        XCTAssertEqual(props.showControls, false)
        XCTAssertEqual(props.aspectRatio, 1.5)
        XCTAssertEqual(props.playerId, "demo")

        // A number, whole or not (Flutter's `ctx.prop<num>('aspectRatio')?.toDouble()`).
        XCTAssertEqual(VideoPlayerProps(try node(["aspectRatio": 2])).aspectRatio, 2)

        let bound = VideoPlayerProps(try node(
            ["url": ["type": "state", "key": "clip", "scope": "page"]],
            state: StoreState(page: ["clip": "https://example.com/other.mp4"])))
        XCTAssertEqual(bound.url, "https://example.com/other.mp4", "a prop reads resolved, as Flutter's ctx.prop")
    }

    func testC17_5_S_AbsentPropsReadNil() throws {
        let props = VideoPlayerProps(try node([:]))
        XCTAssertNil(props.url, "the plugin defaults it to \"\"")
        XCTAssertNil(props.autoPlay, "the plugin defaults it to false")
        XCTAssertNil(props.looping, "the plugin defaults it to false")
        XCTAssertNil(props.showControls, "the plugin defaults it to true")
        XCTAssertNil(props.aspectRatio, "the plugin uses the video's own")
        XCTAssertNil(props.playerId, "the plugin defaults it to the node's id")
        XCTAssertEqual(props.node.id, "player")
    }

    func testC17_5_S_TheTriggerNamesAreFlutters() {
        XCTAssertEqual(
            [VideoPlayerProps.Triggers.onPlay, VideoPlayerProps.Triggers.onPause,
             VideoPlayerProps.Triggers.onComplete, VideoPlayerProps.Triggers.onProgress,
             VideoPlayerProps.Triggers.onError],
            ["onPlay", "onPause", "onComplete", "onProgress", "onError"])
    }

    func testC17_5_S_TheFiveActionsParamsReadFluttersParams() {
        XCTAssertEqual(PlayVideoParams(["type": "playVideo", "playerId": "demo"]).playerId, "demo")
        XCTAssertEqual(PauseVideoParams(["type": "pauseVideo", "playerId": "demo"]).playerId, "demo")

        let seek = SeekVideoParams(["type": "seekVideo", "playerId": "demo", "position": 1500])
        XCTAssertEqual(seek.playerId, "demo")
        XCTAssertEqual(seek.position, 1500)
        XCTAssertEqual(SeekVideoParams(["type": "seekVideo", "position": 250.5]).position, 250.5)

        let volume = SetVolumeParams(["type": "setVolume", "playerId": "demo", "volume": 0.5])
        XCTAssertEqual(volume.playerId, "demo")
        XCTAssertEqual(volume.volume, 0.5)
        XCTAssertEqual(SetVolumeParams(["type": "setVolume", "volume": 1]).volume, 1)

        let speed = SetPlaybackSpeedParams(["type": "setPlaybackSpeed", "playerId": "demo", "speed": 1.5])
        XCTAssertEqual(speed.playerId, "demo")
        XCTAssertEqual(speed.speed, 1.5)
        XCTAssertEqual(SetPlaybackSpeedParams(["type": "setPlaybackSpeed", "speed": 2]).speed, 2)

        // Missing: the plugin does nothing.
        XCTAssertNil(PlayVideoParams(["type": "playVideo"]).playerId)
        XCTAssertNil(PauseVideoParams(["type": "pauseVideo"]).playerId)
        XCTAssertNil(SeekVideoParams(["type": "seekVideo", "playerId": "demo"]).position)
        XCTAssertNil(SetVolumeParams(["type": "setVolume", "playerId": "demo"]).volume)
        XCTAssertNil(SetPlaybackSpeedParams(["type": "setPlaybackSpeed", "playerId": "demo"]).speed)

        // Flutter resolves each param as a value: one sent as a Value reads
        // nil here and stays in the raw action for the plugin to resolve.
        let id: JSONValue = ["type": "state", "key": "player", "scope": "page"]
        let at: JSONValue = ["type": "state", "key": "at", "scope": "page"]
        let bound = SeekVideoParams(["type": "seekVideo", "playerId": id, "position": at])
        XCTAssertNil(bound.playerId)
        XCTAssertNil(bound.position)
        XCTAssertEqual(bound.action["playerId"], id)
        XCTAssertEqual(bound.action["position"], at)
    }

    #if os(macOS)
    /// This package's directory (this file is Tests/OrcaVideoPlayerTests/).
    let packageDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testP_pkg_S_TheManifestTakesTheSDKByPathInTheMonorepoAndFromItsMirrorSplitOut() throws {
        let sdk = packageDir.appendingPathComponent("../../../sdk-swift").standardizedFileURL
        let elsewhere = try temporaryDirectory()

        // In place, evaluated from a directory with no sdk-swift beside it.
        let inPlace = try dumpPackage(packageDir, from: elsewhere)
        XCTAssertEqual(inPlace["name"], "OrcaVideoPlayer")
        XCTAssertEqual(inPlace["products"].arrayValue?.map { $0["name"] }, ["OrcaVideoPlayer"])
        XCTAssertEqual(inPlace["targets"].arrayValue?.map { $0["name"] },
                       ["OrcaVideoPlayer", "OrcaVideoPlayerTests"])
        XCTAssertEqual(inPlace["platforms"], try dumpPackage(sdk, from: elsewhere)["platforms"],
                       "the SDK's platforms")
        XCTAssertEqual(inPlace["dependencies"].arrayValue?.count, 1)
        let local = only(only(inPlace["dependencies"])["fileSystem"])
        XCTAssertEqual(local["identity"], "sdk-swift")
        XCTAssertEqual(local["path"].stringValue.map { URL(fileURLWithPath: $0).standardizedFileURL }, sdk)

        // Split out (the manifest at the root of its mirror), evaluated from
        // this package's directory, where ../../../sdk-swift exists.
        let split = elsewhere.appendingPathComponent("split")
        try FileManager.default.createDirectory(at: split, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: packageDir.appendingPathComponent("Package.swift"), to: split.appendingPathComponent("Package.swift"))
        let mirror = try dumpPackage(split, from: packageDir)["dependencies"]
        XCTAssertEqual(mirror.arrayValue?.count, 1)
        let remote = only(only(mirror)["sourceControl"])
        XCTAssertEqual(remote["identity"], "orca-gateway-swift")
        // The URL as a whole JSON string anywhere in the location: SwiftPM
        // writes it bare before its SourceControlURL type, `{"urlString": …}`
        // since.
        let location = String(decoding: try remote["location"].encoded(), as: UTF8.self)
        XCTAssertTrue(location.contains("\"https://github.com/orca-gateway/orca-gateway-swift\""), location)
        XCTAssertEqual(only(remote["requirement"]["range"]), ["lowerBound": "0.1.0-alpha.2", "upperBound": "1.0.0"],
                       "the first sdk-swift release with the plugin API, up to the next major")
    }

    /// The single element of a one-element array, else null.
    func only(_ value: JSONValue) -> JSONValue {
        guard let array = value.arrayValue, array.count == 1 else { return .null }
        return array[0]
    }

    /// A new empty directory, removed after the test.
    func temporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("orca-video-player-\(UUID().uuidString)")
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
