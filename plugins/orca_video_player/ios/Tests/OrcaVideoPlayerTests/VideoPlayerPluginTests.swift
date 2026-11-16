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
@testable import OrcaVideoPlayer

/// C17.2/S: the Swift VideoPlayerPlugin does what the Flutter plugin does
/// (lib/src/video_player_plugin.dart on video_player 2.11.1), with AVPlayer
/// swapped for a fake playback: its name, widget, five actions and five
/// triggers; the props' defaults; a player per playerId registered only once
/// it is ready, gone when the view leaves or its url changes; each action's
/// effect and clamp, the speed error, an unknown playerId, params resolved as
/// values; the triggers' names, payloads and when they fire (the overlay tap,
/// never an action); onComplete once and re-armed; onError's message; the
/// view's drawing, and its own lifecycle in a real window.
@MainActor
final class VideoPlayerPluginTests: XCTestCase {
    /// video_player's platform player (video_player_avfoundation) as the
    /// plugin uses it, scripted: `send` is what AVPlayer would report.
    @MainActor final class FakePlayback: VideoPlayback {
        let url: String
        private(set) var calls: [String] = []
        private var onEvent: ((VideoPlaybackEvent) -> Void)?

        init(url: String) {
            self.url = url
        }

        func initialize(_ onEvent: @escaping (VideoPlaybackEvent) -> Void) {
            calls.append("initialize")
            self.onEvent = onEvent
        }

        func setLooping(_ looping: Bool) { calls.append("setLooping \(looping)") }
        func play() { calls.append("play") }
        func pause() { calls.append("pause") }
        func seek(to milliseconds: Int) { calls.append("seek \(milliseconds)") }
        func setVolume(_ volume: Double) { calls.append("setVolume \(volume)") }
        func setSpeed(_ speed: Double) { calls.append("setSpeed \(speed)") }
        func dispose() { calls.append("dispose") }

        func send(_ event: VideoPlaybackEvent) { onEvent?(event) }
    }

    /// What a player's view would fire from now on.
    @MainActor final class Fired {
        var events: [VideoPlayerEvent] = []
        var subscription: AnyCancellable?
    }

    /// The plugin on fake playbacks, its actions registered on an executor as
    /// OrcaApp registers a plugin's actions on every page.
    @MainActor final class Harness {
        private(set) var made: [FakePlayback] = []
        /// The states `appear` made, held as their views hold them.
        private(set) var states: [VideoPlayerState] = []
        private(set) var players: VideoPlayers!
        private(set) var plugin: VideoPlayerPlugin!
        let executor: ActionExecutor

        init(_ state: StoreState = StoreState()) {
            executor = ActionExecutor(store: ElmStore(state))
            players = VideoPlayers(makePlayback: { [unowned self] url in
                let playback = FakePlayback(url: url)
                self.made.append(playback)
                return playback
            })
            plugin = VideoPlayerPlugin(players: players)
            for (type, handler) in plugin.actions { executor.registerHandler(type, handler) }
        }

        func run(_ raw: JSONValue) async throws {
            try await executor.execute(try raw.decode(Action.self))
        }

        /// A view's player state, on screen with `options`, its triggers
        /// recorded as the view's onReceive would fire them.
        func appear(_ options: VideoPlayerOptions) -> (VideoPlayerState, Fired) {
            let state = VideoPlayerState(players: players)
            let fired = Fired()
            fired.subscription = state.events.sink { fired.events.append($0) }
            states.append(state)
            state.appear(options)
            return (state, fired)
        }

        /// As `appear`, then the playback reports a 5 s 1280 x 720 video ready.
        func ready(_ options: VideoPlayerOptions) throws -> (VideoPlayerState, Fired, FakePlayback) {
            let (state, fired) = appear(options)
            let playback = try XCTUnwrap(made.last)
            playback.send(VideoPlayerPluginTests.ready)
            return (state, fired, playback)
        }
    }

    nonisolated static let clip = "https://example.com/clip.mp4"
    nonisolated static let otherClip = "https://example.com/other.mp4"
    static let ready = VideoPlaybackEvent.ready(duration: 5000, size: CGSize(width: 1280, height: 720))
    static let actionNames: Set<String> = ["playVideo", "pauseVideo", "seekVideo", "setVolume", "setPlaybackSpeed"]
    /// What video_player sends the platform once the video is initialized.
    static let initialized = ["initialize", "setLooping false", "setVolume 1.0", "pause"]

    static let onPlay = VideoPlayerEvent(trigger: "onPlay", eventData: nil)
    static let onPause = VideoPlayerEvent(trigger: "onPause", eventData: nil)
    static let onComplete = VideoPlayerEvent(trigger: "onComplete", eventData: nil)

    func progress(_ position: Int, of duration: Int = 5000) -> VideoPlayerEvent {
        VideoPlayerEvent(trigger: "onProgress", eventData: [
            "position": .int(position), "duration": .int(duration),
            "fraction": .double(Double(position) / Double(duration)),
        ])
    }

    func options(
        url: String = clip, autoPlay: Bool = false, looping: Bool = false, playerId: String = "demo"
    ) -> VideoPlayerOptions {
        VideoPlayerOptions(url: url, autoPlay: autoPlay, looping: looping, playerId: playerId)
    }

    /// A page with one VideoPlayer node whose onProgress stores the position.
    func page(_ props: [String: JSONValue], watches: [JSONValue] = []) throws -> PageResponse {
        try JSONValue.object([
            "pageId": "video", "title": "Video",
            "state": [["key": "pos", "scope": "page", "initial": -1],
                      ["key": "clip", "scope": "page", "initial": .string(Self.clip)]],
            "components": [
                ["id": "player", "type": "VideoPlayer", "kind": "primitive", "childMode": "none",
                 "props": .object(props), "children": [], "watches": .array(watches),
                 "actions": [
                     "onProgress": ["type": "setState", "scope": "page", "key": "pos",
                                    "value": ["type": "event", "key": "position"]],
                 ]],
            ],
        ]).decode(PageResponse.self)
    }

    func model(_ props: [String: JSONValue]) throws -> OrcaPageModel {
        OrcaPageModel(page: try page(props), registry: WidgetRegistry(types: ["VideoPlayer"]))
    }

    // MARK: The plugin

    func testC17_2_S_ThePluginHasFluttersNameWidgetFiveActionsAndFiveTriggers() throws {
        let h = Harness()
        let plugin = h.plugin!
        XCTAssertEqual(plugin.name, "VideoPlayerPlugin")
        XCTAssertEqual(Set(plugin.widgets.keys), ["VideoPlayer"])
        XCTAssertEqual(Set(plugin.actions.keys), Self.actionNames)
        XCTAssertEqual(plugin.triggers, ["VideoPlayer": [
            TriggerDefinition(name: "onPlay", description: "Fires when playback starts"),
            TriggerDefinition(name: "onPause", description: "Fires when playback pauses"),
            TriggerDefinition(name: "onComplete", description: "Fires when video reaches the end"),
            TriggerDefinition(name: "onProgress", dataType: "VideoProgress",
                              description: "Fires with {position, duration, fraction} during playback"),
            TriggerDefinition(name: "onError", dataType: "String", description: "Fires with {message} on playback error"),
        ]])

        let merged = try PluginMerger.merge(
            builtInWidgets: Set(GeneratedCapabilities.widgets), plugins: [plugin.parts])
        XCTAssertEqual(merged.widgetOwners, ["VideoPlayer": "VideoPlayerPlugin"])
        XCTAssertEqual(merged.pluginActionTypes, Self.actionNames)

        let shipped = VideoPlayerPlugin()
        XCTAssertEqual(shipped.name, "VideoPlayerPlugin")
        XCTAssertTrue(shipped.players.controllers.isEmpty)
    }

    // MARK: The widget

    func testC17_2_S_TheWidgetReadsFluttersPropsWithTheirDefaults() throws {
        let h = Harness()
        let set = try model([
            "url": .string(Self.clip), "autoPlay": true, "looping": true, "showControls": false,
            "aspectRatio": 1.5, "playerId": "demo",
        ])
        let node = try XCTUnwrap(set.resolve("player"))
        XCTAssertEqual(VideoPlayerOptions(node), VideoPlayerOptions(
            url: Self.clip, autoPlay: true, looping: true, showControls: false, aspectRatio: 1.5, playerId: "demo"))
        XCTAssertEqual(h.players.view(node, set).options, VideoPlayerOptions(node))

        let bare = try model([:])
        let bareNode = try XCTUnwrap(bare.resolve("player"))
        XCTAssertEqual(VideoPlayerOptions(bareNode), VideoPlayerOptions(
            url: "", autoPlay: false, looping: false, showControls: true, aspectRatio: nil, playerId: "player"),
            "url \"\", autoPlay and looping false, showControls true, the video's aspect ratio, the node's id")
        XCTAssertEqual(VideoPlayerOptions(try XCTUnwrap(try model(["aspectRatio": 2]).resolve("player"))).aspectRatio, 2)

        let drawn = try XCTUnwrap(h.plugin.widgets["VideoPlayer"])(node, set)
        let renderer = ImageRenderer(content: drawn.frame(width: 100, height: 100))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage, "the VideoPlayer drew nothing")
        XCTAssertTrue(h.players.controllers.isEmpty, "drawing registers no player")
    }

    func testC17_2_S_APlayerIsRegisteredUnderItsPlayerIdOnlyOnceItIsReady() async throws {
        let h = Harness()
        let (state, fired) = h.appear(options())
        let playback = try XCTUnwrap(h.made.first)
        XCTAssertEqual(playback.url, Self.clip)
        XCTAssertEqual(playback.calls, ["initialize"])
        XCTAssertFalse(state.initialized)
        XCTAssertTrue(h.players.controllers.isEmpty, "not registered while it loads (Flutter :156-160)")

        try await h.run(["type": "playVideo", "playerId": "demo"])
        XCTAssertEqual(playback.calls, ["initialize"], "an action before it is ready finds no player")

        playback.send(Self.ready)
        XCTAssertTrue(state.initialized)
        XCTAssertTrue(h.players.controllers["demo"] === state.controller)
        XCTAssertEqual(Set(h.players.controllers.keys), ["demo"])
        XCTAssertEqual(playback.calls, Self.initialized, "video_player applies looping, volume and pause once initialized")
        XCTAssertEqual(state.aspectRatio, 1280.0 / 720.0, "the video's own")
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(fired.events, [], "ready fires nothing")

        state.appear(options())
        XCTAssertEqual(h.made.count, 1, "appearing again while on screen builds no second player")
    }

    func testC17_2_S_AutoPlayPlaysOnceReadyAndFiresNoOnPlay() throws {
        let h = Harness()
        let (state, fired) = h.appear(options(autoPlay: true))
        XCTAssertEqual(h.made.first?.calls, ["initialize"], "not before it is ready")

        h.made.first?.send(Self.ready)
        XCTAssertEqual(h.made.first?.calls, Self.initialized + ["play", "setSpeed 1.0"])
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(fired.events, [progress(0)], "playing is an update (onProgress at 0); autoPlay fires no onPlay")
    }

    // MARK: The triggers

    func testC17_2_S_OnProgressFiresWithPositionDurationAndFractionOnEachUpdateWhilePlaying() async throws {
        let h = Harness()
        let (_, fired, playback) = try h.ready(options())
        playback.send(.position(100))
        XCTAssertEqual(fired.events, [], "paused: video_player polls no position")

        try await h.run(["type": "playVideo", "playerId": "demo"])
        playback.send(.position(100))
        playback.send(.position(200))
        playback.send(.position(200))
        playback.send(.position(1250))
        try await h.run(["type": "pauseVideo", "playerId": "demo"])
        playback.send(.position(1300))

        XCTAssertEqual(fired.events, [progress(0), progress(100), progress(200), progress(1250)],
                       "on each change while playing (a ValueNotifier); none once paused")
        XCTAssertEqual(playback.calls, Self.initialized + ["play", "setSpeed 1.0", "pause"])

        let unknown = Harness()
        let (_, quiet) = unknown.appear(options())
        let live = try XCTUnwrap(unknown.made.first)
        live.send(.ready(duration: 0, size: CGSize(width: 1280, height: 720)))
        try await unknown.run(["type": "playVideo", "playerId": "demo"])
        live.send(.position(100))
        XCTAssertEqual(quiet.events, [], "no onProgress (nor onComplete) without a known duration")
    }

    func testC17_2_S_OnCompleteFiresOnceAtTheEndAndAgainOnlyAfterThePositionIsBackBeforeIt() async throws {
        let h = Harness()
        let (state, fired, playback) = try h.ready(options())
        try await h.run(["type": "playVideo", "playerId": "demo"])
        playback.send(.position(4900))
        playback.send(.ended)

        XCTAssertEqual(playback.calls, Self.initialized + ["play", "setSpeed 1.0", "pause", "seek 5000"],
                       "at the end it pauses on the last frame")
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.controller?.value.position, 5000)
        XCTAssertEqual(fired.events, [progress(0), progress(4900), Self.onComplete])

        try await h.run(["type": "seekVideo", "playerId": "demo", "position": 5000])
        XCTAssertEqual(fired.events.filter { $0 == Self.onComplete }.count, 1, "once while it stays at the end")

        try await h.run(["type": "seekVideo", "playerId": "demo", "position": 4000])
        try await h.run(["type": "seekVideo", "playerId": "demo", "position": 6000])
        XCTAssertEqual(fired.events, [progress(0), progress(4900), Self.onComplete, Self.onComplete],
                       "re-armed below the duration, so the next end fires again")
    }

    func testC17_2_S_PlayAtTheEndSeeksToZeroFirst() async throws {
        let h = Harness()
        let (state, fired, playback) = try h.ready(options())
        try await h.run(["type": "seekVideo", "playerId": "demo", "position": 5000])
        XCTAssertEqual(fired.events, [Self.onComplete], "a seek to the end completes too")

        try await h.run(["type": "playVideo", "playerId": "demo"])
        XCTAssertEqual(playback.calls, Self.initialized + ["seek 5000", "seek 0", "play", "setSpeed 1.0"])
        XCTAssertEqual(state.controller?.value.position, 0)
        XCTAssertEqual(fired.events, [Self.onComplete, progress(0)])
    }

    func testC17_2_S_ALoopingPlayerLoopsWithoutOnComplete() async throws {
        let h = Harness()
        let (_, fired, playback) = try h.ready(options(looping: true))
        XCTAssertEqual(playback.calls, ["initialize", "setLooping true", "setVolume 1.0", "pause"],
                       "the playback loops by itself (no ended event)")

        try await h.run(["type": "playVideo", "playerId": "demo"])
        playback.send(.position(4900))
        playback.send(.position(5000))
        playback.send(.position(0))
        playback.send(.position(100))

        XCTAssertEqual(fired.events, [progress(0), progress(4900), progress(0), progress(100)],
                       "the end is not reported while looping, so no onComplete")
    }

    func testC17_2_S_TheOverlayTapTogglesPlayAndPauseAndFiresOnPlayAndOnPause() throws {
        let h = Harness()
        let (state, fired, playback) = try h.ready(options())

        state.togglePlayPause()
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(fired.events, [progress(0), Self.onPlay])

        state.togglePlayPause()
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(fired.events, [progress(0), Self.onPlay, Self.onPause])
        XCTAssertEqual(playback.calls, Self.initialized + ["play", "setSpeed 1.0", "pause"])
    }

    func testC17_2_S_ThePlayAndPauseActionsFireNeitherOnPlayNorOnPause() async throws {
        let h = Harness()
        let (state, fired, playback) = try h.ready(options())

        try await h.run(["type": "playVideo", "playerId": "demo"])
        XCTAssertTrue(state.isPlaying, "the play mark goes")
        try await h.run(["type": "pauseVideo", "playerId": "demo"])
        XCTAssertFalse(state.isPlaying)
        try await h.run(["type": "custom:playVideo", "playerId": "demo"])

        XCTAssertEqual(fired.events, [progress(0), progress(0)], "updates only: no onPlay, no onPause")
        XCTAssertEqual(playback.calls, Self.initialized + ["play", "setSpeed 1.0", "pause", "play", "setSpeed 1.0"])
    }

    func testC17_2_S_OnErrorFiresWithTheMessageWhenTheVideoFailsToLoad() throws {
        let h = Harness()
        let (state, fired) = h.appear(options())
        h.made.first?.send(.failed(message: "The server is not correctly configured."))

        XCTAssertTrue(state.hasError)
        XCTAssertFalse(state.initialized)
        XCTAssertEqual(fired.events, [VideoPlayerEvent(
            trigger: "onError", eventData: ["message": "The server is not correctly configured."])])
        XCTAssertTrue(h.players.controllers.isEmpty)

        let later = Harness()
        let (loaded, quiet, playback) = try later.ready(options())
        playback.send(.failed(message: "Lost the connection."))
        XCTAssertFalse(loaded.hasError, "onError is the load's failure only, as Flutter's catchError on initialize")
        XCTAssertEqual(quiet.events, [])
    }

    // MARK: The actions

    func testC17_2_S_SeekVideoSeeksToWholeMsClampedToZeroAndTheDuration() async throws {
        let h = Harness()
        let (state, _, playback) = try h.ready(options())
        try await h.run(["type": "seekVideo", "playerId": "demo", "position": 1500])
        XCTAssertEqual(state.controller?.value.position, 1500)
        try await h.run(["type": "seekVideo", "playerId": "demo", "position": 1500.9])
        try await h.run(["type": "seekVideo", "playerId": "demo", "position": -250])
        try await h.run(["type": "seekVideo", "playerId": "demo", "position": 9000])
        try await h.run(["type": "seekVideo", "playerId": "demo"])
        try await h.run(["type": "seekVideo", "playerId": "demo", "position": "1500"])

        XCTAssertEqual(playback.calls, Self.initialized + ["seek 1500", "seek 1500", "seek 0", "seek 5000"],
                       "a missing or non-number position does nothing")
        XCTAssertEqual(state.controller?.value.position, 5000)
    }

    func testC17_2_S_SetVolumeClampsToZeroToOne() async throws {
        let h = Harness()
        let (state, _, playback) = try h.ready(options())
        try await h.run(["type": "setVolume", "playerId": "demo", "volume": 0.5])
        try await h.run(["type": "setVolume", "playerId": "demo", "volume": 1.5])
        try await h.run(["type": "setVolume", "playerId": "demo", "volume": -1])
        try await h.run(["type": "setVolume", "playerId": "demo"])

        XCTAssertEqual(playback.calls, Self.initialized + ["setVolume 0.5", "setVolume 1.0", "setVolume 0.0"])
        XCTAssertEqual(state.controller?.value.volume, 0)
    }

    func testC17_2_S_SetPlaybackSpeedAppliesWhilePlayingAndFailsTheActionAtZeroOrBelow() async throws {
        let h = Harness()
        let (state, _, playback) = try h.ready(options())
        try await h.run(["type": "setPlaybackSpeed", "playerId": "demo", "speed": 1.5])
        XCTAssertEqual(playback.calls, Self.initialized, "paused: kept for the next play, as video_player does")

        try await h.run(["type": "playVideo", "playerId": "demo"])
        try await h.run(["type": "setPlaybackSpeed", "playerId": "demo", "speed": 2])
        XCTAssertEqual(playback.calls, Self.initialized + ["play", "setSpeed 1.5", "setSpeed 2.0"])

        for (speed, message) in [
            (JSONValue.int(0), "Invalid argument (Zero playback speed is generally unsupported. Consider using [pause].): 0.0"),
            (JSONValue.int(-1), "Invalid argument (Negative playback speeds are generally unsupported.): -1.0"),
        ] {
            do {
                try await h.run(["type": "setPlaybackSpeed", "playerId": "demo", "speed": speed])
                XCTFail("speed \(speed) did not fail the action")
            } catch {
                XCTAssertEqual("\(error)", message, "Dart's ArgumentError, as video_player throws it")
            }
        }
        XCTAssertEqual(playback.calls, Self.initialized + ["play", "setSpeed 1.5", "setSpeed 2.0"])
        XCTAssertEqual(state.controller?.value.playbackSpeed, 2)

        try await h.run(["type": "setPlaybackSpeed", "playerId": "demo"])
        try await h.run(["type": "setPlaybackSpeed", "playerId": "ghost", "speed": 0])
        XCTAssertEqual(playback.calls.count, Self.initialized.count + 3, "a missing speed or an unknown player does nothing")
    }

    func testC17_2_S_AnUnknownOrMissingPlayerIdDoesNothing() async throws {
        let h = Harness()
        let (_, fired, playback) = try h.ready(options())
        for params: [String: JSONValue] in [["playerId": "ghost"], [:]] {
            for (type, extra) in [("playVideo", [:]), ("pauseVideo", [:]), ("seekVideo", ["position": 100]),
                                  ("setVolume", ["volume": 0.5]), ("setPlaybackSpeed", ["speed": 2])]
                as [(String, [String: JSONValue])] {
                try await h.run(.object(params.merging(extra) { $1 }.merging(["type": .string(type)]) { $1 }))
            }
        }
        XCTAssertEqual(playback.calls, Self.initialized)
        XCTAssertEqual(fired.events, [])
    }

    func testC17_2_S_ThePlayerIdAndTheNumbersAreResolvedAsValues() async throws {
        let h = Harness(StoreState(page: ["pid": "demo", "at": 1200, "vol": 0.25, "rate": 1.5]))
        let (_, _, playback) = try h.ready(options())
        func value(_ key: String) -> JSONValue { ["type": "state", "scope": "page", "key": .string(key)] }

        try await h.run(["type": "playVideo", "playerId": value("pid")])
        try await h.run(["type": "seekVideo", "playerId": value("pid"), "position": value("at")])
        try await h.run(["type": "setVolume", "playerId": value("pid"), "volume": value("vol")])
        try await h.run(["type": "setPlaybackSpeed", "playerId": value("pid"), "speed": value("rate")])
        try await h.run(["type": "pauseVideo", "playerId": value("pid")])
        XCTAssertEqual(playback.calls, Self.initialized + [
            "play", "setSpeed 1.0", "seek 1200", "setVolume 0.25", "setSpeed 1.5", "pause",
        ])

        let (_, _, seven) = try h.ready(options(playerId: "7"))
        try await h.run(["type": "playVideo", "playerId": 7])
        XCTAssertEqual(seven.calls.last, "setSpeed 1.0", "a number reads as its Dart toString")
    }

    // MARK: The player's lifetime

    func testC17_2_S_ANewUrlDisposesTheOldPlayerAndBuildsANewOne() throws {
        let h = Harness()
        let (state, fired, old) = try h.ready(options())
        XCTAssertNotNil(h.players.controllers["demo"])

        state.change(options(url: Self.otherClip))
        XCTAssertEqual(old.calls, Self.initialized + ["dispose"])
        XCTAssertTrue(h.players.controllers.isEmpty, "the old player is unregistered (Flutter :196-208)")
        XCTAssertFalse(state.initialized, "loading again")
        let new = try XCTUnwrap(h.made.last)
        XCTAssertEqual(h.made.count, 2)
        XCTAssertEqual(new.url, Self.otherClip)
        XCTAssertEqual(new.calls, ["initialize"])

        old.send(.ended)
        old.send(Self.ready)
        XCTAssertTrue(h.players.controllers.isEmpty, "the old player is gone for good")

        new.send(Self.ready)
        XCTAssertTrue(h.players.controllers["demo"] === state.controller)
        XCTAssertTrue(state.initialized)

        var same = options(url: Self.otherClip)
        same.showControls = false
        state.change(same)
        XCTAssertEqual(h.made.count, 2, "only a new url builds a new player")
        XCTAssertEqual(fired.events, [])
    }

    func testC17_2_S_TheViewLeavingDisposesItsPlayerAndUnregistersIt() throws {
        let h = Harness()
        let (state, fired, playback) = try h.ready(options())
        state.disappear()
        XCTAssertEqual(playback.calls, Self.initialized + ["dispose"])
        XCTAssertTrue(h.players.controllers.isEmpty)

        playback.send(.position(100))
        playback.send(.ended)
        XCTAssertEqual(fired.events, [], "a disposed player fires nothing")

        let (early, _) = h.appear(options(playerId: "early"))
        early.disappear()
        h.made.last?.send(Self.ready)
        XCTAssertTrue(h.players.controllers.isEmpty, "a player that left before it was ready is never registered")
        XCTAssertEqual(h.made.last?.calls, ["initialize", "dispose"])

        state.appear(options())
        XCTAssertEqual(h.made.count, 3, "back on screen, a new player")
        XCTAssertFalse(state.initialized)
    }

    // MARK: On screen

    /// The plugin's VideoPlayer for the node, in a real window: on screen it
    /// builds its player (the view's onAppear); its triggers reach the node's
    /// actions through model.fire (the view's own onReceive); a tap on it
    /// goes to SwiftUI, not to the player's view; a new url from page state
    /// builds a new player (the view's onChange); leaving disposes it (the
    /// view's onDisappear).
    func testC17_2_S_OnScreenTheViewBuildsItsPlayerFiresThroughTheModelAndDisposesItWhenItLeaves() throws {
        let h = Harness()
        let builders = WidgetBuilders()
        builders.register("VideoPlayer", try XCTUnwrap(h.plugin.widgets["VideoPlayer"]))
        let model = OrcaPageModel(
            page: try page(["url": ["type": "state", "scope": "page", "key": "clip"], "playerId": "demo"],
                           watches: ["clip"]),
            registry: WidgetRegistry(types: ["VideoPlayer"]), widgets: builders)
        let shown = Shown()
        let hosted = Hosted(AnyView(Shown.Toggled(shown: shown, model: model)))
        defer { hosted.close() }

        pump(until: { h.made.count == 1 })
        let first = try XCTUnwrap(h.made.first, "on screen, the view built no player")
        XCTAssertEqual(first.url, Self.clip)
        first.send(Self.ready)
        let controller = try XCTUnwrap(h.players.controllers["demo"])

        controller.play()
        first.send(.position(300))
        pump(until: { model.store.state.page["pos"] == 300 })
        XCTAssertEqual(model.store.state.page["pos"], 300,
                       "onProgress {position} did not reach the node's action through model.fire")

        let hit = try XCTUnwrap(hosted.hit(x: 150, y: 150), "nothing on screen at the video")
        XCTAssertFalse(hit is PlayerLayerView.LayerView,
                       "a tap on the video goes to the player's own view, not to the tap gesture over it")

        Task { await model.run(.setState(.init(key: "clip", scope: .page, value: .string(Self.otherClip)))) }
        pump(until: { h.made.count == 2 })
        XCTAssertEqual(h.made.last?.url, Self.otherClip, "a new url did not build a new player")
        XCTAssertEqual(first.calls.last, "dispose")
        XCTAssertTrue(h.players.controllers.isEmpty)

        shown.on = false
        pump(until: { h.made.last?.calls.last == "dispose" })
        XCTAssertEqual(h.made.last?.calls, ["initialize", "dispose"], "leaving did not dispose the player")
    }

    // MARK: Drawing

    func testC17_2_S_TheViewDrawsFluttersLoadingErrorAndReadyStates() throws {
        let h = Harness()

        let loading = try pixels(VideoPlayerState(players: h.players), width: 100, height: 100)
        assertColor(loading.color(50, 50), [0, 0, 0, 0x33], "loading: a 0x33000000 circle in the middle")
        assertColor(loading.color(50 + 14, 50), [0, 0, 0, 0x33], "32 pt wide")
        assertColor(loading.color(50 + 18, 50), [0, 0, 0, 0], "and no wider")

        let (failed, _) = h.appear(options())
        h.made.last?.send(.failed(message: "nope"))
        let error = try pixels(failed, width: 200, height: 100)
        let text = try pixels(Text("Video failed to load").font(.system(size: 14)), width: 200, height: 100)
        XCTAssertEqual(error.rgba, text.rgba, "error: \"Video failed to load\" at 14 pt in the middle")
        XCTAssertTrue(text.rgba.contains { $0 != 0 }, "the reference text drew nothing")

        // Ready: the video at its own 16:9, or at aspectRatio; with
        // showControls, while not playing, a 56 pt 0x99000000 circle over it.
        let (ready, _, _) = try h.ready(options())
        XCTAssertEqual(try pixels(ready, width: 320, height: nil).height, 180, "the video's own aspect ratio")
        XCTAssertEqual(try pixels(ready, VideoPlayerOptions(url: Self.clip, aspectRatio: 2, playerId: "demo"),
                                  width: 320, height: nil).height, 160, "aspectRatio")

        let paused = try pixels(ready, width: 320, height: nil)
        let bare = try pixels(ready, VideoPlayerOptions(url: Self.clip, showControls: false, playerId: "demo"),
                              width: 320, height: nil)
        ready.togglePlayPause()
        let playing = try pixels(ready, width: 320, height: nil)
        XCTAssertEqual(playing.rgba, bare.rgba, "playing: no play mark")
        XCTAssertNotEqual(paused.rgba, playing.rgba, "paused: the play mark")
        for (x, y) in [(160, 90 + 24), (160 - 24, 90), (160, 90 - 24)] {
            XCTAssertNotEqual(paused.color(x, y), playing.color(x, y), "inside the 56 pt circle at \(x), \(y)")
        }
        for (x, y) in [(160, 90 + 32), (160 - 32, 90), (10, 10)] {
            XCTAssertEqual(paused.color(x, y), playing.color(x, y), "outside the circle at \(x), \(y)")
        }

        let mark = try pixels(PlayMark(), width: nil, height: nil)
        XCTAssertEqual([mark.width, mark.height], [56, 56])
        assertColor(mark.color(28, 52), [0, 0, 0, 0x99], "a 0x99000000 circle")
        assertColor(mark.color(2, 2), [0, 0, 0, 0], "round")
        XCTAssertTrue((26...34).contains { x in mark.color(x, 28) == [255, 255, 255, 255] },
                      "a white mark in the middle, 2 pt right of it (4 pt left padding)")
    }

    // MARK: Helpers

    /// Runs the main run loop until `done`, 3 s at most (as sdk-swift's
    /// PagerTests wait), so SwiftUI draws and the fired actions run.
    func pump(until done: () -> Bool, timeout: Double = 3) {
        let deadline = Date().addingTimeInterval(timeout)
        while !done() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    }

    /// Whether the node is on screen.
    @MainActor final class Shown: ObservableObject {
        @Published var on = true

        struct Toggled: View {
            @ObservedObject var shown: Shown
            let model: OrcaPageModel

            var body: some View {
                if shown.on { NodeView(id: "player", model: model) }
            }
        }
    }

    /// A view in a real window (UIKit or AppKit), as sdk-swift's
    /// LifecycleTests host a node, kept on screen until `close`.
    @MainActor final class Hosted {
        #if canImport(UIKit)
        private let window: UIWindow
        #elseif canImport(AppKit)
        private let window: NSWindow
        #endif

        init(_ content: AnyView) {
            let root = content.frame(width: 300, height: 300, alignment: .topLeading)
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

        /// The view a touch or click at x, y from the top left goes to.
        func hit(x: Double, y: Double) -> AnyObject? {
            #if canImport(UIKit)
            return window.hitTest(CGPoint(x: x, y: y), with: nil)
            #elseif canImport(AppKit)
            return window.contentView?.hitTest(NSPoint(x: x, y: (window.contentView?.bounds.height ?? 300) - y))
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

    /// The view drawn at scale 1: its size and its sRGB premultiplied
    /// pixels, top row first.
    struct Pixels {
        let width: Int
        let height: Int
        let rgba: [UInt8]

        func color(_ x: Int, _ y: Int) -> [Int] {
            let i = (y * width + x) * 4
            return rgba[i..<i + 4].map(Int.init)
        }
    }

    func pixels(_ state: VideoPlayerState, _ options: VideoPlayerOptions? = nil,
                width: CGFloat, height: CGFloat?) throws -> Pixels {
        try pixels(VideoPlayerView(options: options ?? self.options(), state: state, fire: { _ in nil }),
                   width: width, height: height)
    }

    func pixels(_ view: some View, width: CGFloat?, height: CGFloat?) throws -> Pixels {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
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
        XCTAssertTrue(zip(actual, expected).allSatisfy { abs($0 - $1) <= 3 },
                      "\(message): \(actual), expected \(expected)", line: line)
    }
}
#endif
