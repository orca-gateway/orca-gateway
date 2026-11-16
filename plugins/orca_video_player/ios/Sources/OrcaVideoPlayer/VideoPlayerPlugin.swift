#if canImport(SwiftUI) && canImport(AVFoundation)
import Combine
import CoreGraphics
import Foundation
import OrcaGateway
import SwiftUI

/// Video playback, the Swift port of the Flutter `VideoPlayerPlugin`
/// (lib/src/video_player_plugin.dart, on video_player 2.11.1): register it
/// with the host, `OrcaApp(..., plugins: [VideoPlayerPlugin()])`.
///
/// Widget `VideoPlayer`: props `url` (default ""), `autoPlay` (false),
/// `looping` (false), `showControls` (true), `aspectRatio` (the video's) and
/// `playerId` (the node's id). Triggers `onPlay` and `onPause` (the overlay
/// tap only), `onComplete`, `onProgress` {position, duration, fraction} (ms)
/// and `onError` {message}. Actions `playVideo`, `pauseVideo`, `seekVideo`
/// {position ms}, `setVolume` {volume}, `setPlaybackSpeed` {speed}, each on
/// the player registered under its `playerId` once it is ready.
public struct VideoPlayerPlugin: OrcaPlugin {
    public let name = "VideoPlayerPlugin"
    /// What the widget and the actions share (Flutter's static map).
    let players: VideoPlayers

    /// Plays with AVPlayer.
    public init() {
        self.init(players: VideoPlayers(makePlayback: { AVVideoPlayback(url: $0) }))
    }

    init(players: VideoPlayers) {
        self.players = players
    }

    public var widgets: [String: OrcaWidgetBuilder] {
        ["VideoPlayer": { [players] node, model in
            let view = players.view(node, model)
            return AnyView(view.id("video_player_\(view.options.playerId)"))
        }]
    }

    public var actions: [String: OrcaActionHandler] {
        let players = players
        return [
            "playVideo": { await players.playVideo($0, $1) },
            "pauseVideo": { await players.pauseVideo($0, $1) },
            "seekVideo": { try await players.seekVideo($0, $1) },
            "setVolume": { try await players.setVolume($0, $1) },
            "setPlaybackSpeed": { try await players.setPlaybackSpeed($0, $1) },
        ]
    }

    public var triggers: [String: [TriggerDefinition]] {
        ["VideoPlayer": [
            TriggerDefinition(name: VideoPlayerProps.Triggers.onPlay, description: "Fires when playback starts"),
            TriggerDefinition(name: VideoPlayerProps.Triggers.onPause, description: "Fires when playback pauses"),
            TriggerDefinition(name: VideoPlayerProps.Triggers.onComplete, description: "Fires when video reaches the end"),
            TriggerDefinition(
                name: VideoPlayerProps.Triggers.onProgress, dataType: "VideoProgress",
                description: "Fires with {position, duration, fraction} during playback"),
            TriggerDefinition(
                name: VideoPlayerProps.Triggers.onError, dataType: "String",
                description: "Fires with {message} on playback error"),
        ]]
    }
}

/// A VideoPlayer node's props with Flutter's defaults.
struct VideoPlayerOptions: Equatable {
    var url = ""
    var autoPlay = false
    var looping = false
    var showControls = true
    /// Nil: the video's own.
    var aspectRatio: Double?
    var playerId: String
}

extension VideoPlayerOptions {
    init(_ node: ResolvedNode) {
        let props = VideoPlayerProps(node)
        self.init(
            url: props.url ?? "", autoPlay: props.autoPlay ?? false, looping: props.looping ?? false,
            showControls: props.showControls ?? true, aspectRatio: props.aspectRatio, playerId: props.playerId ?? node.id)
    }
}

/// A trigger a VideoPlayer fires, with its event data.
struct VideoPlayerEvent: Equatable {
    let trigger: String
    let eventData: [String: JSONValue]?
}

/// The ready players by playerId (Flutter's `_controllers`) and the five
/// actions on them, line for line Flutter's handlers (:291-332): playerId
/// resolved as a string value, position, volume and speed as values; an
/// unknown playerId or a missing number does nothing, a number that is not
/// one fails the action (Dart's `as num?`), before the player is looked up.
@MainActor
final class VideoPlayers {
    private(set) var controllers: [String: VideoController] = [:]
    let makePlayback: @MainActor @Sendable (String) -> VideoPlayback

    nonisolated init(makePlayback: @escaping @MainActor @Sendable (String) -> VideoPlayback) {
        self.makePlayback = makePlayback
    }

    /// The node's view, its player made when it comes on screen.
    func view(_ node: ResolvedNode, _ model: OrcaPageModel) -> VideoPlayerView {
        VideoPlayerView(
            options: VideoPlayerOptions(node), state: VideoPlayerState(players: self),
            fire: { model.fire($0.trigger, on: node, eventData: $0.eventData) })
    }

    func register(_ playerId: String, _ controller: VideoController) {
        controllers[playerId] = controller
    }

    func unregister(_ playerId: String) {
        controllers[playerId] = nil
    }

    func playVideo(_ action: JSONValue, _ executor: ActionExecutor) {
        controller(PlayVideoParams(action).action["playerId"], executor)?.play()
    }

    func pauseVideo(_ action: JSONValue, _ executor: ActionExecutor) {
        controller(PauseVideoParams(action).action["playerId"], executor)?.pause()
    }

    func seekVideo(_ action: JSONValue, _ executor: ActionExecutor) throws {
        let params = SeekVideoParams(action)
        let position = try number(params.action, "position", executor)?.dartInt
        guard let controller = controller(params.action["playerId"], executor), let position else { return }
        controller.seek(to: position)
    }

    func setVolume(_ action: JSONValue, _ executor: ActionExecutor) throws {
        let params = SetVolumeParams(action)
        let volume = try number(params.action, "volume", executor)?.doubleValue
        guard let controller = controller(params.action["playerId"], executor), let volume else { return }
        controller.setVolume(volume)
    }

    func setPlaybackSpeed(_ action: JSONValue, _ executor: ActionExecutor) throws {
        let params = SetPlaybackSpeedParams(action)
        let speed = try number(params.action, "speed", executor)?.doubleValue
        guard let controller = controller(params.action["playerId"], executor), let speed else { return }
        try controller.setPlaybackSpeed(speed)
    }

    /// Dart's `executor.resolveValue(action[key]) as num?`: nil when missing
    /// or null, else a number; anything else throws, as the cast does.
    private func number(_ action: JSONValue, _ key: String, _ executor: ActionExecutor) throws -> JSONValue? {
        let value = executor.resolve(action[key])
        if value.isNull { return nil }
        guard value.isNumber else { throw VideoPlayerNumberError(key: key, value: value) }
        return value
    }

    /// The player under Dart's `executor.resolveString(action['playerId'] ?? '')`:
    /// the resolved value's toString, "" for null.
    private func controller(_ raw: JSONValue, _ executor: ActionExecutor) -> VideoController? {
        let value = executor.resolve(raw)
        return controllers[value.isNull ? "" : DartFormat.string(value)]
    }
}

/// video_player's `VideoPlayerValue`, the part the plugin uses; times in ms.
struct VideoPlayerValue: Equatable {
    var duration = 0
    var position = 0
    var size = CGSize.zero
    var isInitialized = false
    var isPlaying = false
    var isLooping = false
    var volume = 1.0
    var playbackSpeed = 1.0

    /// Width over height; 1 until initialized or without a size.
    var aspectRatio: Double {
        guard isInitialized, size.width > 0, size.height > 0 else { return 1 }
        return size.width / size.height
    }
}

/// video_player's Dart `VideoPlayerController` (2.11.1) over a playback: the
/// value and its listener, and what play, pause, seek, volume and speed do
/// before they reach the platform.
@MainActor
final class VideoController {
    let playback: VideoPlayback
    /// Called on each change of `value`, as a ValueNotifier's listener.
    var onUpdate: (() -> Void)?
    private(set) var value = VideoPlayerValue() {
        didSet { if value != oldValue { onUpdate?() } }
    }
    private var disposed = false

    /// `VideoPlayerController.networkUrl(url)..setLooping(looping)`.
    init(playback: VideoPlayback, looping: Bool) {
        self.playback = playback
        value.isLooping = looping
    }

    /// Loads the video: `onReady` once it is initialized, else `onError`
    /// with the failure's message.
    func initialize(onReady: @escaping () -> Void, onError: @escaping (String) -> Void) {
        var pending: (ready: () -> Void, error: (String) -> Void)? = (onReady, onError)
        playback.initialize { [weak self] event in
            guard let self, !self.disposed else { return }
            switch event {
            case let .ready(duration, size):
                var next = value
                next.duration = duration
                next.size = size
                next.isInitialized = true
                value = next
                playback.setLooping(value.isLooping)
                playback.setVolume(value.volume)
                applyPlayPause()
                pending?.ready()
                pending = nil
            case let .failed(message):
                value = VideoPlayerValue()
                pending?.error(message)
                pending = nil
            case let .position(position):
                // Polled only while playing; a looping player's end is not
                // reported, it starts again.
                guard value.isPlaying, !(value.isLooping && position >= value.duration) else { return }
                updatePosition(position)
            case .ended:
                pause()
                seek(to: value.duration)
            }
        }
    }

    /// From 0 when at the end.
    func play() {
        if value.position == value.duration { seek(to: 0) }
        value.isPlaying = true
        applyPlayPause()
    }

    func pause() {
        value.isPlaying = false
        applyPlayPause()
    }

    /// Clamped to [0, duration].
    func seek(to milliseconds: Int) {
        guard !disposed, value.isInitialized else { return }
        let position = milliseconds > value.duration ? value.duration : max(milliseconds, 0)
        playback.seek(to: position)
        updatePosition(position)
    }

    /// Clamped to 0...1.
    func setVolume(_ volume: Double) {
        value.volume = min(max(volume, 0), 1)
        guard !disposed, value.isInitialized else { return }
        playback.setVolume(value.volume)
    }

    /// Above 0, else an error; applied while playing, kept for the next play
    /// while paused.
    func setPlaybackSpeed(_ speed: Double) throws {
        if speed < 0 {
            throw VideoPlayerArgumentError(value: speed, name: "Negative playback speeds are generally unsupported.")
        } else if speed == 0 {
            throw VideoPlayerArgumentError(
                value: speed, name: "Zero playback speed is generally unsupported. Consider using [pause].")
        }
        value.playbackSpeed = speed
        applyPlaybackSpeed()
    }

    func dispose() {
        disposed = true
        onUpdate = nil
        playback.dispose()
    }

    private func applyPlayPause() {
        guard !disposed, value.isInitialized else { return }
        if value.isPlaying {
            playback.play()
            applyPlaybackSpeed()
        } else {
            playback.pause()
        }
    }

    private func applyPlaybackSpeed() {
        guard !disposed, value.isInitialized, value.isPlaying else { return }
        playback.setSpeed(value.playbackSpeed)
    }

    /// The platform may report a position past the duration: clamped.
    private func updatePosition(_ milliseconds: Int) {
        value.position = min(milliseconds, value.duration)
    }
}

/// Dart's `ArgumentError.value(value, name)`, as video_player's
/// setPlaybackSpeed throws it: it fails the action, with Dart's text.
struct VideoPlayerArgumentError: Error, CustomStringConvertible {
    let value: Double
    let name: String

    var description: String { "Invalid argument (\(name)): \(DartFormat.double(value))" }
}

/// A param that resolved to something other than a number, where Dart's
/// `as num?` throws: it fails the action, with the Kotlin plugin's text.
struct VideoPlayerNumberError: Error, CustomStringConvertible {
    let key: String
    let value: JSONValue

    var description: String { "\(key) is not a number: \(DartFormat.string(value))" }
}

/// One VideoPlayer view's player, Flutter's `_OrcaVideoPlayerState`
/// (:138-227): it builds the controller when the view comes on screen,
/// registers it under the playerId once it is ready, fires the triggers from
/// its updates, and disposes it when the url changes (building a new one)
/// or the view leaves.
@MainActor
final class VideoPlayerState: ObservableObject {
    @Published private(set) var initialized = false
    @Published private(set) var hasError = false
    /// What the view draws of the controller's value.
    @Published private(set) var isPlaying = false
    @Published private(set) var aspectRatio = 1.0
    private(set) var controller: VideoController?
    /// The triggers to fire, from the view on screen.
    let events = PassthroughSubject<VideoPlayerEvent, Never>()
    private let players: VideoPlayers
    private var options: VideoPlayerOptions?
    private var completed = false

    init(players: VideoPlayers) {
        self.players = players
    }

    /// Flutter's initState, once until the view leaves.
    func appear(_ options: VideoPlayerOptions) {
        guard controller == nil else { return }
        self.options = options
        initController()
    }

    /// Flutter's didUpdateWidget: a new url disposes the player and builds
    /// a new one.
    func change(_ options: VideoPlayerOptions) {
        guard let old = self.options else { return }
        self.options = options
        guard old.url != options.url else { return }
        disposeController(old.playerId)
        initController()
    }

    /// Flutter's dispose.
    func disappear() {
        guard let options else { return }
        disposeController(options.playerId)
        self.options = nil
    }

    /// The overlay's tap.
    func togglePlayPause() {
        guard let controller else { return }
        if controller.value.isPlaying {
            controller.pause()
            events.send(VideoPlayerEvent(trigger: VideoPlayerProps.Triggers.onPause, eventData: nil))
        } else {
            controller.play()
            events.send(VideoPlayerEvent(trigger: VideoPlayerProps.Triggers.onPlay, eventData: nil))
        }
    }

    private func initController() {
        guard let options else { return }
        let controller = VideoController(playback: players.makePlayback(options.url), looping: options.looping)
        self.controller = controller
        controller.onUpdate = { [weak self, unowned controller] in self?.controllerUpdated(controller.value) }
        controller.initialize(
            onReady: { [weak self, unowned controller] in
                guard let self, let options = self.options else { return }
                initialized = true
                players.register(options.playerId, controller)
                if options.autoPlay { controller.play() }
            },
            onError: { [weak self] message in
                guard let self else { return }
                hasError = true
                events.send(VideoPlayerEvent(
                    trigger: VideoPlayerProps.Triggers.onError, eventData: ["message": .string(message)]))
            })
    }

    private func disposeController(_ playerId: String) {
        players.unregister(playerId)
        controller?.dispose()
        controller = nil
        initialized = false
        hasError = false
        isPlaying = false
        completed = false
    }

    /// Flutter's `_onControllerUpdate`.
    private func controllerUpdated(_ value: VideoPlayerValue) {
        if isPlaying != value.isPlaying { isPlaying = value.isPlaying }
        if aspectRatio != value.aspectRatio { aspectRatio = value.aspectRatio }

        if value.isPlaying && value.duration > 0 {
            events.send(VideoPlayerEvent(trigger: VideoPlayerProps.Triggers.onProgress, eventData: [
                "position": .int(value.position), "duration": .int(value.duration),
                "fraction": .double(Double(value.position) / Double(value.duration)),
            ]))
        }

        if value.position >= value.duration && value.duration > 0 && !completed {
            completed = true
            events.send(VideoPlayerEvent(trigger: VideoPlayerProps.Triggers.onComplete, eventData: nil))
        } else if value.position < value.duration {
            completed = false
        }
    }
}
#endif
