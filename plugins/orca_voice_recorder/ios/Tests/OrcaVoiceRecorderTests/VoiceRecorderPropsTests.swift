import Foundation
import XCTest

import OrcaGateway
import OrcaVoiceRecorder

/// C17.5/S: the types `orca plugin generate --lang swift --types-only` writes
/// for orca_plugin.yaml (Generated/OrcaVoiceRecorderTypes.swift, kept equal to
/// the generator's output by cli/test/voice_recorder_swift_props_test.dart)
/// read what the Flutter plugin reads (lib/src/voice_recorder_plugin.dart):
/// the VoiceRecorder node's two props, its three trigger names, and each of
/// the nine actions' params from the raw action object.
///
/// P-pkg/S: the manifest takes the SDK by path inside the monorepo and from
/// its mirror once split out, by where the manifest is.
final class VoiceRecorderPropsTests: XCTestCase {
    /// A VoiceRecorder node with these props, resolved against `state` as the
    /// SDK resolves a page's node.
    func node(_ props: [String: JSONValue], state: StoreState = StoreState()) throws -> ResolvedNode {
        let page = try JSONValue.object([
            "pageId": "voice", "title": "Voice", "state": [],
            "components": [
                ["id": "rec", "type": "VoiceRecorder", "kind": "primitive", "childMode": "none",
                 "props": .object(props), "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self)
        let renderer = PageRenderer(page: page, registry: WidgetRegistry(types: ["VoiceRecorder"]))
        return try XCTUnwrap(renderer.resolve("rec", state: state))
    }

    func testC17_5_S_VoiceRecorderPropsReadRecorderIdAndShowAmplitude() throws {
        let props = VoiceRecorderProps(try node(["recorderId": "memo", "showAmplitude": false]))
        XCTAssertEqual(props.recorderId, "memo")
        XCTAssertEqual(props.showAmplitude, false)

        let bound = VoiceRecorderProps(try node(
            ["recorderId": ["type": "state", "key": "rid", "scope": "page"]],
            state: StoreState(page: ["rid": "memo-2"])))
        XCTAssertEqual(bound.recorderId, "memo-2", "a prop reads resolved, as Flutter's ctx.prop")
    }

    func testC17_5_S_AbsentPropsReadNil() throws {
        let props = VoiceRecorderProps(try node([:]))
        XCTAssertNil(props.recorderId, "the plugin defaults it to the node's id")
        XCTAssertNil(props.showAmplitude, "the plugin defaults it to true")
        XCTAssertEqual(props.node.id, "rec")
    }

    func testC17_5_S_TheTriggerNamesAreFlutters() {
        XCTAssertEqual(
            [VoiceRecorderProps.Triggers.onStateChange, VoiceRecorderProps.Triggers.onAmplitudeChange,
             VoiceRecorderProps.Triggers.onRecordingComplete],
            ["onStateChange", "onAmplitudeChange", "onRecordingComplete"])
    }

    func testC17_5_S_TheFourRecordingActionsParamsReadFluttersParams() {
        XCTAssertEqual(StartRecordingParams(["type": "startRecording", "recorderId": "memo"]).recorderId, "memo")
        XCTAssertEqual(PauseRecordingParams(["type": "pauseRecording", "recorderId": "memo"]).recorderId, "memo")
        XCTAssertEqual(ResumeRecordingParams(["type": "resumeRecording", "recorderId": "memo"]).recorderId, "memo")

        let stop = StopRecordingParams([
            "type": "stopRecording", "recorderId": "memo", "pathKey": "memoPath", "durationKey": "memoMs",
            "scope": "app",
        ])
        XCTAssertEqual(stop.recorderId, "memo")
        XCTAssertEqual(stop.pathKey, "memoPath")
        XCTAssertEqual(stop.durationKey, "memoMs")
        XCTAssertEqual(stop.scope, "app")

        let bare = StopRecordingParams(["type": "stopRecording", "recorderId": "memo"])
        XCTAssertNil(bare.pathKey)
        XCTAssertNil(bare.durationKey)
        XCTAssertNil(bare.scope, "the plugin defaults it to page")
        XCTAssertNil(StartRecordingParams(["type": "startRecording"]).recorderId, "the plugin does nothing")
    }

    func testC17_5_S_TheFivePlaybackActionsParamsReadFluttersParams() {
        let play = PlayRecordingParams([
            "type": "playRecording", "path": "/tmp/orca_recording_memo_1.m4a", "positionKey": "position",
            "durationKey": "length", "stateKey": "playback", "scope": "app",
        ])
        XCTAssertEqual(play.path, "/tmp/orca_recording_memo_1.m4a")
        XCTAssertEqual(play.positionKey, "position")
        XCTAssertEqual(play.durationKey, "length")
        XCTAssertEqual(play.stateKey, "playback")
        XCTAssertEqual(play.scope, "app")

        // Flutter resolves the path as a value: one sent as a Value reads nil
        // here and stays in the raw action for the plugin to resolve.
        let saved: JSONValue = ["type": "state", "key": "memoPath", "scope": "page"]
        let bound = PlayRecordingParams(["type": "playRecording", "path": saved])
        XCTAssertNil(bound.path)
        XCTAssertEqual(bound.action["path"], saved)

        let stop = StopPlaybackParams([
            "type": "stopPlayback", "positionKey": "position", "stateKey": "playback", "scope": "app",
        ])
        XCTAssertEqual(stop.positionKey, "position")
        XCTAssertEqual(stop.stateKey, "playback")
        XCTAssertEqual(stop.scope, "app")

        let pause = PausePlaybackParams(["type": "pausePlayback", "stateKey": "playback", "scope": "app"])
        XCTAssertEqual(pause.stateKey, "playback")
        XCTAssertEqual(pause.scope, "app")
        let resume = ResumePlaybackParams(["type": "resumePlayback", "stateKey": "playback", "scope": "app"])
        XCTAssertEqual(resume.stateKey, "playback")
        XCTAssertEqual(resume.scope, "app")
        XCTAssertNil(ResumePlaybackParams(["type": "resumePlayback"]).scope, "the plugin defaults it to page")

        // A number, whole or not (Dart's num).
        XCTAssertEqual(SeekPlaybackParams(["type": "seekPlayback", "position": 1500]).position, 1500)
        XCTAssertEqual(SeekPlaybackParams(["type": "seekPlayback", "position": 250.5]).position, 250.5)
        XCTAssertNil(SeekPlaybackParams(["type": "seekPlayback"]).position, "the plugin seeks to 0")
    }

    #if os(macOS)
    /// This package's directory (this file is Tests/OrcaVoiceRecorderTests/).
    let packageDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testP_pkg_S_TheManifestTakesTheSDKByPathInTheMonorepoAndFromItsMirrorSplitOut() throws {
        let sdk = packageDir.appendingPathComponent("../../../sdk-swift").standardizedFileURL
        let elsewhere = try temporaryDirectory()

        // In place, evaluated from a directory with no sdk-swift beside it.
        let inPlace = try dumpPackage(packageDir, from: elsewhere)
        XCTAssertEqual(inPlace["name"], "OrcaVoiceRecorder")
        XCTAssertEqual(inPlace["products"].arrayValue?.map { $0["name"] }, ["OrcaVoiceRecorder"])
        XCTAssertEqual(inPlace["targets"].arrayValue?.map { $0["name"] },
                       ["OrcaVoiceRecorder", "OrcaVoiceRecorderTests"])
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
        XCTAssertEqual(only(remote["location"]["remote"])["urlString"],
                       "https://github.com/orca-gateway/orca-gateway-swift")
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
            .appendingPathComponent("orca-voice-recorder-\(UUID().uuidString)")
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
