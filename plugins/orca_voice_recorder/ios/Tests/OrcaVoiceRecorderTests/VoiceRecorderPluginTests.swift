#if canImport(SwiftUI) && canImport(AVFoundation)
import Combine
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

import OrcaGateway
@testable import OrcaVoiceRecorder

/// C17.3/S: the Swift VoiceRecorderPlugin does what the Flutter plugin does
/// (lib/src/voice_recorder_plugin.dart), with AVFoundation swapped for fakes:
/// its name, widget, nine actions and three triggers; the widget's recorder,
/// props defaults and drawing; each action's params, defaults, clamps and
/// state writes; the triggers' names and payloads; a denied permission and an
/// unknown recorderId; recorderId, path and position resolved as values.
@MainActor
final class VoiceRecorderPluginTests: XCTestCase {
    /// Flutter's `AudioRecorder` (record) as the plugin uses it, scripted.
    @MainActor final class FakeRecorder: Recorder {
        var permission = true
        /// When false, stop returns nil (nothing was written).
        var stopReturnsPath = true
        private(set) var calls: [String] = []
        private(set) var startedPath: String?
        private(set) var amplitudeInterval: TimeInterval?
        private(set) var onAmplitude: ((Double) -> Void)?

        func hasPermission() async -> Bool {
            calls.append("hasPermission")
            return permission
        }

        func start(path: String) throws {
            calls.append("start")
            startedPath = path
        }

        func stop() -> String? {
            calls.append("stop")
            onAmplitude = nil
            defer { startedPath = nil }
            return stopReturnsPath ? startedPath : nil
        }

        func pause() { calls.append("pause") }
        func resume() { calls.append("resume") }

        func onAmplitudeChanged(every interval: TimeInterval, _ onAmplitude: @escaping (Double) -> Void) {
            calls.append("onAmplitudeChanged")
            amplitudeInterval = interval
            self.onAmplitude = onAmplitude
        }
    }

    /// Flutter's `AudioPlayer` (audioplayers) as the plugin uses it, scripted:
    /// play reports `duration` before it returns, as the source loads.
    @MainActor final class FakePlayer: Player {
        struct Failure: Error {}

        var onPosition: ((Int) async -> Void)?
        var onDuration: ((Int) async -> Void)?
        var onComplete: (() async -> Void)?
        var failsToPrepare = false
        var failsToPlay = false
        var duration = 4200
        private(set) var calls: [String] = []

        func preparePlayback() throws {
            calls.append("preparePlayback")
            if failsToPrepare { throw Failure() }
        }

        func play(path: String) async throws {
            calls.append("play \(path)")
            if failsToPlay { throw Failure() }
            await onDuration?(duration)
        }

        func stop() { calls.append("stop") }
        func pause() { calls.append("pause") }
        func resume() { calls.append("resume") }
        func seek(milliseconds: Int) { calls.append("seek \(milliseconds)") }

        /// Every listener is gone (Flutter's `_playbackSubs.cancelAll`).
        var unsubscribed: Bool { onPosition == nil && onDuration == nil && onComplete == nil }
    }

    @MainActor final class Clock {
        var now = Date(timeIntervalSince1970: 1_700_000_000)
    }

    /// What a recorder's views would hear from now on.
    @MainActor final class Fired {
        var events: [VoiceRecorderEvent] = []
        var subscription: AnyCancellable?
    }

    /// The plugin on fakes, its actions registered on an executor as OrcaApp
    /// registers a plugin's actions on every page.
    @MainActor final class Harness {
        let player = FakePlayer()
        let clock = Clock()
        let directory = URL(fileURLWithPath: "/tmp/orca-voice-tests", isDirectory: true)
        var permission = true
        private(set) var made: [FakeRecorder] = []
        private(set) var recorders: VoiceRecorders!
        private(set) var plugin: VoiceRecorderPlugin!
        let executor: ActionExecutor

        init(_ state: StoreState = StoreState()) {
            executor = ActionExecutor(store: ElmStore(state))
            let player = self.player
            let clock = self.clock
            recorders = VoiceRecorders(
                makeRecorder: { [unowned self] in
                    let recorder = FakeRecorder()
                    recorder.permission = self.permission
                    self.made.append(recorder)
                    return recorder
                },
                makePlayer: { player }, directory: directory, now: { clock.now })
            plugin = VoiceRecorderPlugin(recorders: recorders)
            for (type, handler) in plugin.actions { executor.registerHandler(type, handler) }
        }

        func run(_ raw: JSONValue) async throws {
            try await executor.execute(try raw.decode(Action.self))
        }

        var state: StoreState { executor.store.state }

        func recorder(_ id: String) -> FakeRecorder? {
            recorders.instances[id]?.recorder as? FakeRecorder
        }

        /// Listens to recorder `id` as its view does (made if it is not yet).
        func fired(_ id: String) -> Fired {
            let fired = Fired()
            fired.subscription = recorders.recorder(id).events.sink { fired.events.append($0) }
            return fired
        }
    }

    static let actionNames: Set<String> = [
        "startRecording", "stopRecording", "pauseRecording", "resumeRecording", "playRecording",
        "stopPlayback", "pausePlayback", "resumePlayback", "seekPlayback",
    ]

    func stateChange(_ state: String) -> VoiceRecorderEvent {
        VoiceRecorderEvent(trigger: "onStateChange", eventData: ["state": .string(state)])
    }

    func amplitudeChange(_ amplitude: Double) -> VoiceRecorderEvent {
        VoiceRecorderEvent(trigger: "onAmplitudeChange", eventData: ["amplitude": .double(amplitude)])
    }

    /// A page with one VoiceRecorder node whose onStateChange and
    /// onAmplitudeChange store their event data.
    func model(_ props: [String: JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "voice", "title": "Voice",
            "state": [["key": "recState", "scope": "page", "initial": ""],
                      ["key": "level", "scope": "page", "initial": 0]],
            "components": [
                ["id": "rec", "type": "VoiceRecorder", "kind": "primitive", "childMode": "none",
                 "props": .object(props), "children": [], "watches": [],
                 "actions": [
                     "onStateChange": ["type": "setState", "scope": "page", "key": "recState",
                                       "value": ["type": "event", "key": "state"]],
                     "onAmplitudeChange": ["type": "setState", "scope": "page", "key": "level",
                                           "value": ["type": "event", "key": "amplitude"]],
                 ]],
            ],
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: ["VoiceRecorder"]))
    }

    // MARK: The plugin

    func testC17_3_S_ThePluginHasFluttersNameWidgetNineActionsAndThreeTriggers() throws {
        let h = Harness()
        let plugin = h.plugin!
        XCTAssertEqual(plugin.name, "VoiceRecorderPlugin")
        XCTAssertEqual(Set(plugin.widgets.keys), ["VoiceRecorder"])
        XCTAssertEqual(Set(plugin.actions.keys), Self.actionNames)
        XCTAssertEqual(plugin.triggers, ["VoiceRecorder": [
            TriggerDefinition(name: "onAmplitudeChange", dataType: "Amplitude",
                              description: "Fires periodically with {amplitude, dBFS} during recording"),
            TriggerDefinition(name: "onStateChange", dataType: "String",
                              description: "Fires with {state} when recording state changes"),
            TriggerDefinition(name: "onRecordingComplete", dataType: "RecordingResult",
                              description: "Fires with {path, duration} when recording stops"),
        ]], "onRecordingComplete is declared, as in Flutter, and never fired")

        let merged = try PluginMerger.merge(
            builtInWidgets: Set(GeneratedCapabilities.widgets), plugins: [plugin.parts])
        XCTAssertEqual(merged.widgetOwners, ["VoiceRecorder": "VoiceRecorderPlugin"])
        XCTAssertEqual(merged.pluginActionTypes, Self.actionNames)

        let shipped = VoiceRecorderPlugin()
        XCTAssertEqual(shipped.name, "VoiceRecorderPlugin")
        XCTAssertEqual(shipped.recorders.directory,
                       FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0],
                       "Flutter's getTemporaryDirectory on iOS (path_provider: NSCachesDirectory)")
    }

    // MARK: The widget

    func testC17_3_S_TheWidgetRegistersARecorderUnderItsRecorderIdElseTheNodesIdAndShowsAmplitudeByDefault() throws {
        let h = Harness()
        let model = try model(["recorderId": "memo"])
        let node = try XCTUnwrap(model.resolve("rec"))

        let drawn = try XCTUnwrap(h.plugin.widgets["VoiceRecorder"])(node, model)
        let renderer = ImageRenderer(content: drawn)
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage, "the VoiceRecorder drew nothing")
        XCTAssertEqual(Set(h.recorders.instances.keys), ["memo"])

        let view = h.recorders.view(node, model)
        XCTAssertTrue(view.recorder === h.recorders.instances["memo"], "one recorder per recorderId")
        XCTAssertTrue(view.showAmplitude, "showAmplitude defaults to true")
        XCTAssertEqual(Set(h.recorders.instances.keys), ["memo"])

        let bare = try self.model([:])
        let bareView = h.recorders.view(try XCTUnwrap(bare.resolve("rec")), bare)
        XCTAssertTrue(bareView.recorder === h.recorders.instances["rec"], "recorderId defaults to the node's id")

        let quiet = try self.model(["recorderId": "memo", "showAmplitude": false])
        XCTAssertFalse(h.recorders.view(try XCTUnwrap(quiet.resolve("rec")), quiet).showAmplitude)
        XCTAssertEqual(h.made.map(\.calls), [[], []], "two recorders (memo, rec); drawing records nothing")
    }

    /// The plugin's VoiceRecorder for the node, on screen in a real window:
    /// startRecording and a new level reach the node's onStateChange and
    /// onAmplitudeChange through model.fire, the view's own subscription.
    func testC17_3_S_OnScreenTheViewsTriggersFireThroughTheModelIntoTheNodesActions() throws {
        let h = Harness()
        let model = try model(["recorderId": "memo"])
        let drawn = try XCTUnwrap(h.plugin.widgets["VoiceRecorder"])(try XCTUnwrap(model.resolve("rec")), model)
        let hosted = Hosted(drawn)
        defer { hosted.close() }
        pump(until: { hosted.appeared })
        XCTAssertTrue(hosted.appeared, "the VoiceRecorder never came on screen")

        Task {
            do { try await h.run(["type": "startRecording", "recorderId": "memo"]) }
            catch { XCTFail("startRecording threw \(error)") }
        }
        pump(until: { model.store.state.page["recState"] == "recording" })
        XCTAssertEqual(model.store.state.page["recState"], "recording",
                       "onStateChange {state} did not reach the node's action through model.fire")

        try XCTUnwrap(h.recorder("memo")?.onAmplitude, "startRecording did not sample the level")(-12.5)
        pump(until: { model.store.state.page["level"] == -12.5 })
        XCTAssertEqual(model.store.state.page["level"], -12.5,
                       "onAmplitudeChange {amplitude} did not reach the node's action through model.fire")
    }

    /// Runs the main run loop until `done`, 3 s at most (as sdk-swift's
    /// PagerTests wait), so SwiftUI draws and the fired actions run.
    func pump(until done: () -> Bool, timeout: Double = 3) {
        let deadline = Date().addingTimeInterval(timeout)
        while !done() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    }

    /// A view in a real window (UIKit or AppKit), as sdk-swift's
    /// LifecycleTests host a node, kept on screen until `close`.
    @MainActor final class Hosted {
        final class Flag { var on = false }

        private let flag: Flag
        #if canImport(UIKit)
        private let window: UIWindow
        #elseif canImport(AppKit)
        private let window: NSWindow
        #endif

        /// The view's onAppear ran.
        var appeared: Bool { flag.on }

        init(_ content: AnyView) {
            let flag = Flag()
            self.flag = flag
            let root = content
                .onAppear { flag.on = true }
                .frame(width: 300, height: 300, alignment: .topLeading)
            let size = CGRect(x: 0, y: 0, width: 300, height: 300)
            #if canImport(UIKit)
            let host = UIHostingController(rootView: root)
            window = UIWindow(frame: size)
            window.rootViewController = host
            window.isHidden = false
            host.view.frame = size
            host.view.layoutIfNeeded()
            #elseif canImport(AppKit)
            window = NSWindow(contentRect: size, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: root)
            host.frame = size
            window.contentView = host
            window.orderFront(nil)
            window.contentView?.layoutSubtreeIfNeeded()
            #endif
        }

        func close() {
            #if canImport(UIKit)
            window.isHidden = true
            #elseif canImport(AppKit)
            window.orderOut(nil)
            #endif
        }
    }

    /// The view drawn at scale 1: its size and its sRGB pixels, top row first.
    struct Pixels {
        let width: Int
        let height: Int
        let rgba: [UInt8]

        func color(_ x: Int, _ y: Int) -> [Int] {
            let i = (y * width + x) * 4
            return rgba[i..<i + 4].map(Int.init)
        }
    }

    func pixels(_ recorder: VoiceRecorderInstance, showAmplitude: Bool = true) throws -> Pixels {
        let renderer = ImageRenderer(
            content: VoiceRecorderView(
                recorderId: "memo", recorder: recorder, showAmplitude: showAmplitude, fire: { _ in nil }))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        rgba.withUnsafeMutableBytes { bytes in
            let context = CGContext(
                data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return Pixels(width: image.width, height: image.height, rgba: rgba)
    }

    func assertColor(_ actual: [Int], _ expected: [Int], _ message: String, line: UInt = #line) {
        XCTAssertTrue(zip(actual, expected + [255]).allSatisfy { abs($0 - $1) <= 3 },
                      "\(message): \(actual), expected \(expected)", line: line)
    }

    func testC17_3_S_TheViewDrawsFluttersDotAmplitudeBarAndLabel() throws {
        let h = Harness()
        let recorder = h.recorders.recorder("memo")

        let idle = try pixels(recorder)
        assertColor(idle.color(idle.width / 2, 8), [0x9E, 0x9E, 0x9E], "a grey 16 pt dot when idle")
        XCTAssertLessThan(idle.width, 100, "no amplitude bar when idle")

        recorder.state = "paused"
        let paused = try pixels(recorder)
        assertColor(paused.color(paused.width / 2, 8), [0xFF, 0x98, 0x00], "orange when paused")
        XCTAssertEqual(paused.height, idle.height, "no amplitude bar when paused")

        recorder.state = "recording"
        recorder.amplitude = -30
        let recording = try pixels(recorder)
        assertColor(recording.color(50, 8), [0xFF, 0x00, 0x00], "red when recording")
        XCTAssertEqual(recording.width, 100, "the 100 pt bar")
        XCTAssertEqual(recording.height, idle.height + 12, "8 pt gap, 4 pt bar")
        let bar = 16 + 8 + 2
        assertColor(recording.color(25, bar), [0x4C, 0xAF, 0x50], "(-30 + 60) / 60 of the bar is green")
        XCTAssertEqual(recording.color(75, bar)[3], 0, "the rest is empty")

        recorder.amplitude = -75
        XCTAssertEqual(try pixels(recorder).color(2, bar)[3], 0, "below -60 dBFS the bar is empty")
        recorder.amplitude = 6
        assertColor(try pixels(recorder).color(97, bar), [0x4C, 0xAF, 0x50], "above 0 dBFS it is full")

        XCTAssertEqual(try pixels(recorder, showAmplitude: false).height, idle.height, "showAmplitude false: no bar")

        XCTAssertEqual(VoiceRecorderView.label("idle"), "Ready")
        XCTAssertEqual(VoiceRecorderView.label("recording"), "Recording")
        XCTAssertEqual(VoiceRecorderView.label("paused"), "Paused")
        XCTAssertEqual(VoiceRecorderView.barFraction(-30), 0.5)
        XCTAssertEqual(VoiceRecorderView.barFraction(-75), 0)
        XCTAssertEqual(VoiceRecorderView.barFraction(6), 1)
    }

    // MARK: Recording

    func testC17_3_S_StartRecordingAsksPermissionFirstThenRecordsAacToTheTemporaryFileAndSamplesEvery200ms() async throws {
        let h = Harness()
        let fired = h.fired("memo")

        try await h.run(["type": "startRecording", "recorderId": "memo"])

        let recorder = try XCTUnwrap(h.recorder("memo"))
        XCTAssertEqual(recorder.calls, ["hasPermission", "start", "onAmplitudeChanged"])
        XCTAssertEqual(recorder.startedPath, "/tmp/orca-voice-tests/orca_recording_memo_1700000000000.m4a")
        XCTAssertEqual(recorder.amplitudeInterval, 0.2)
        XCTAssertEqual(h.recorders.instances["memo"]?.state, "recording")
        XCTAssertEqual(fired.events, [stateChange("recording")])
        XCTAssertEqual(h.state, StoreState(), "starting writes no state")
    }

    func testC17_3_S_APermissionDenialReturnsSilently() async throws {
        let h = Harness()
        h.permission = false
        let fired = h.fired("memo")

        try await h.run(["type": "startRecording", "recorderId": "memo"])

        XCTAssertEqual(h.recorder("memo")?.calls, ["hasPermission"])
        XCTAssertEqual(h.recorders.instances["memo"]?.state, "idle")
        XCTAssertEqual(fired.events, [])
        XCTAssertEqual(h.state, StoreState())
    }

    func testC17_3_S_WhileRecordingEachNewLevelFiresOnAmplitudeChangeInDBFS() async throws {
        let h = Harness()
        let fired = h.fired("memo")
        try await h.run(["type": "startRecording", "recorderId": "memo"])
        let recorder = try XCTUnwrap(h.recorder("memo"))

        recorder.onAmplitude?(-60)
        recorder.onAmplitude?(-30)
        recorder.onAmplitude?(-30)
        recorder.onAmplitude?(-12.5)

        XCTAssertEqual(fired.events, [stateChange("recording"), amplitudeChange(-30), amplitudeChange(-12.5)],
                       "from -60, on each change only, as a ValueNotifier")
        XCTAssertEqual(h.recorders.instances["memo"]?.amplitude, -12.5)
    }

    func testC17_3_S_StopRecordingWritesThePathAndTheWallClockDurationInMsToTheKeys() async throws {
        let h = Harness()
        let fired = h.fired("memo")
        try await h.run(["type": "startRecording", "recorderId": "memo"])
        h.clock.now += 1.5004

        try await h.run([
            "type": "stopRecording", "recorderId": "memo", "pathKey": "memoPath", "durationKey": "memoMs",
        ])

        XCTAssertEqual(h.recorder("memo")?.calls, ["hasPermission", "start", "onAmplitudeChanged", "stop"])
        XCTAssertEqual(h.state, StoreState(page: [
            "memoPath": "/tmp/orca-voice-tests/orca_recording_memo_1700000000000.m4a", "memoMs": 1500,
        ]), "scope page by default")
        XCTAssertEqual(h.recorders.instances["memo"]?.state, "idle")
        XCTAssertEqual(fired.events, [stateChange("recording"), stateChange("idle")])
        XCTAssertNil(h.recorder("memo")?.onAmplitude, "no level after stop")
    }

    func testC17_3_S_StopRecordingWritesToAppScopeAndOnlyTheKeysItIsGiven() async throws {
        let h = Harness()
        try await h.run(["type": "startRecording", "recorderId": "memo"])
        h.clock.now += 2
        try await h.run([
            "type": "stopRecording", "recorderId": "memo", "pathKey": "memoPath", "durationKey": "memoMs",
            "scope": "app",
        ])
        XCTAssertEqual(h.state, StoreState(app: [
            "memoPath": "/tmp/orca-voice-tests/orca_recording_memo_1700000000000.m4a", "memoMs": 2000,
        ]))

        let bare = Harness()
        try await bare.run(["type": "startRecording", "recorderId": "memo"])
        try await bare.run(["type": "stopRecording", "recorderId": "memo"])
        XCTAssertEqual(bare.state, StoreState(), "no keys, no writes")
        XCTAssertEqual(bare.recorder("memo")?.calls.last, "stop")

        // Nothing recorded: the path is not written, the duration still is,
        // from the last start (0 when there was none), as Flutter.
        let nothing = Harness()
        try await nothing.run(["type": "startRecording", "recorderId": "memo"])
        nothing.recorder("memo")?.stopReturnsPath = false
        nothing.clock.now += 0.25
        try await nothing.run([
            "type": "stopRecording", "recorderId": "memo", "pathKey": "memoPath", "durationKey": "memoMs",
        ])
        XCTAssertEqual(nothing.state, StoreState(page: ["memoMs": 250]))

        let unstarted = Harness()
        _ = unstarted.recorders.recorder("memo")
        try await unstarted.run(["type": "stopRecording", "recorderId": "memo", "durationKey": "memoMs"])
        XCTAssertEqual(unstarted.state, StoreState(page: ["memoMs": 0]))
    }

    func testC17_3_S_PauseAndResumeRecordingSetPausedAndRecording() async throws {
        let h = Harness()
        let fired = h.fired("memo")
        try await h.run(["type": "startRecording", "recorderId": "memo"])

        try await h.run(["type": "pauseRecording", "recorderId": "memo"])
        XCTAssertEqual(h.recorders.instances["memo"]?.state, "paused")
        try await h.run(["type": "pauseRecording", "recorderId": "memo"])
        try await h.run(["type": "resumeRecording", "recorderId": "memo"])
        XCTAssertEqual(h.recorders.instances["memo"]?.state, "recording")

        XCTAssertEqual(h.recorder("memo")?.calls,
                       ["hasPermission", "start", "onAmplitudeChanged", "pause", "pause", "resume"])
        XCTAssertEqual(fired.events, [stateChange("recording"), stateChange("paused"), stateChange("recording")],
                       "onStateChange on each change only")
        XCTAssertEqual(h.state, StoreState())
    }

    func testC17_3_S_AnUnknownOrEmptyRecorderIdDoesNothing() async throws {
        let h = Harness()
        try await h.run(["type": "stopRecording", "recorderId": "ghost", "pathKey": "p", "durationKey": "d"])
        try await h.run(["type": "pauseRecording", "recorderId": "ghost"])
        try await h.run(["type": "resumeRecording", "recorderId": "ghost"])
        XCTAssertTrue(h.recorders.instances.isEmpty, "only startRecording makes a recorder")

        try await h.run(["type": "startRecording"])
        try await h.run(["type": "startRecording", "recorderId": ""])
        try await h.run(["type": "stopRecording", "recorderId": "", "durationKey": "d"])
        XCTAssertTrue(h.recorders.instances.isEmpty)
        XCTAssertTrue(h.made.isEmpty)
        XCTAssertEqual(h.state, StoreState())
    }

    func testC17_3_S_RecorderIdPathAndPositionAreResolvedAsValues() async throws {
        let h = Harness(StoreState(page: ["rid": "memo", "voicePath": "/tmp/saved.m4a", "at": 800]))
        let rid: JSONValue = ["type": "state", "scope": "page", "key": "rid"]

        try await h.run(["type": "startRecording", "recorderId": rid])
        try await h.run(["type": "custom:stopRecording", "recorderId": rid, "durationKey": "memoMs"])
        XCTAssertEqual(h.recorder("memo")?.calls, ["hasPermission", "start", "onAmplitudeChanged", "stop"])
        XCTAssertEqual(h.state.page["memoMs"], 0)

        try await h.run(["type": "startRecording", "recorderId": 7])
        XCTAssertEqual(h.recorder("7")?.calls.first, "hasPermission", "a number reads as its Dart toString")

        try await h.run(["type": "playRecording", "path": ["type": "state", "scope": "page", "key": "voicePath"]])
        try await h.run(["type": "seekPlayback", "position": ["type": "state", "scope": "page", "key": "at"]])
        XCTAssertEqual(h.player.calls, ["preparePlayback", "play /tmp/saved.m4a", "seek 800"])
    }

    // MARK: Playback

    func testC17_3_S_PlayRecordingSetsThePlaybackSessionFirstAndWritesStatePositionAndDuration() async throws {
        let h = Harness()
        try await h.run([
            "type": "playRecording", "path": "/tmp/a.m4a", "positionKey": "position", "durationKey": "length",
            "stateKey": "playback", "scope": "app",
        ])
        XCTAssertEqual(h.player.calls, ["preparePlayback", "play /tmp/a.m4a"])
        XCTAssertEqual(h.state, StoreState(app: ["length": 4200, "playback": "playing"]))

        await h.player.onPosition?(500)
        XCTAssertEqual(h.state, StoreState(app: ["length": 4200, "playback": "playing", "position": 500]))

        await h.player.onComplete?()
        XCTAssertEqual(h.state, StoreState(app: ["length": 4200, "playback": "stopped", "position": 0]),
                       "the end writes 0 and stopped")
        XCTAssertTrue(h.player.unsubscribed)
    }

    func testC17_3_S_PlayRecordingListensOnlyForTheKeysItIsGivenAndReplacesTheLastPlaysListeners() async throws {
        let h = Harness()
        try await h.run(["type": "playRecording", "path": "/tmp/a.m4a", "positionKey": "position"])
        XCTAssertNotNil(h.player.onPosition)
        XCTAssertNil(h.player.onDuration)

        try await h.run(["type": "playRecording", "path": "/tmp/b.m4a"])
        XCTAssertNil(h.player.onPosition, "the first clip's listener is gone")
        XCTAssertNil(h.player.onDuration)
        XCTAssertNotNil(h.player.onComplete)
        await h.player.onComplete?()
        XCTAssertEqual(h.state, StoreState(), "no keys, no writes")
        XCTAssertEqual(h.player.calls, ["preparePlayback", "play /tmp/a.m4a", "preparePlayback", "play /tmp/b.m4a"])
    }

    func testC17_3_S_PlayRecordingWritesErrorWhenPlayFailsAndCarriesOnWhenTheSessionFails() async throws {
        let h = Harness()
        h.player.failsToPlay = true
        try await h.run([
            "type": "playRecording", "path": "/tmp/a.m4a", "positionKey": "position", "stateKey": "playback",
        ])
        XCTAssertEqual(h.state, StoreState(page: ["playback": "error"]))
        XCTAssertTrue(h.player.unsubscribed)

        let session = Harness()
        session.player.failsToPrepare = true
        try await session.run(["type": "playRecording", "path": "/tmp/a.m4a", "stateKey": "playback"])
        XCTAssertEqual(session.player.calls, ["preparePlayback", "play /tmp/a.m4a"])
        XCTAssertEqual(session.state, StoreState(page: ["playback": "playing"]))
    }

    func testC17_3_S_PlayRecordingWithAnEmptyPathDoesNothing() async throws {
        let h = Harness()
        try await h.run(["type": "playRecording", "stateKey": "playback"])
        try await h.run(["type": "playRecording", "path": "", "stateKey": "playback"])
        try await h.run(["type": "playRecording", "path": ["type": "state", "scope": "page", "key": "none"]])
        XCTAssertEqual(h.player.calls, [])
        XCTAssertEqual(h.state, StoreState())
    }

    func testC17_3_S_StopPauseAndResumePlaybackWriteStoppedPausedAndPlaying() async throws {
        let h = Harness()
        try await h.run(["type": "playRecording", "path": "/tmp/a.m4a", "positionKey": "position"])

        try await h.run(["type": "pausePlayback", "stateKey": "playback"])
        XCTAssertEqual(h.state, StoreState(page: ["playback": "paused"]))
        try await h.run(["type": "resumePlayback", "stateKey": "playback", "scope": "app"])
        XCTAssertEqual(h.state, StoreState(page: ["playback": "paused"], app: ["playback": "playing"]))
        XCTAssertNotNil(h.player.onPosition, "pausing keeps the listeners")

        try await h.run(["type": "stopPlayback", "positionKey": "position", "stateKey": "playback"])
        XCTAssertEqual(h.state, StoreState(page: ["playback": "stopped", "position": 0], app: ["playback": "playing"]))
        XCTAssertTrue(h.player.unsubscribed)

        let bare = Harness()
        try await bare.run(["type": "stopPlayback"])
        try await bare.run(["type": "pausePlayback", "stateKey": ""])
        try await bare.run(["type": "resumePlayback"])
        XCTAssertEqual(bare.player.calls, ["stop", "pause", "resume"])
        XCTAssertEqual(bare.state, StoreState(), "no key or an empty one: no write")
        XCTAssertEqual(h.player.calls, ["preparePlayback", "play /tmp/a.m4a", "pause", "resume", "stop"])
    }

    func testC17_3_S_SeekPlaybackSeeksToAWholeNumberOfMsClampedAtZero() async throws {
        let h = Harness()
        try await h.run(["type": "seekPlayback", "position": 1500])
        try await h.run(["type": "seekPlayback", "position": 1500.9])
        try await h.run(["type": "seekPlayback", "position": -250])
        try await h.run(["type": "seekPlayback", "position": "1500"])
        try await h.run(["type": "seekPlayback"])
        XCTAssertEqual(h.player.calls, ["seek 1500", "seek 1500", "seek 0", "seek 0", "seek 0"])
        XCTAssertEqual(h.state, StoreState())
    }
}
#endif
