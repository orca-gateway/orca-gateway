#if canImport(SwiftUI) && canImport(AVFoundation)
import Combine
import Foundation
import OrcaGateway
import os
import SwiftUI

/// Voice recording and playback, the Swift port of the Flutter
/// `VoiceRecorderPlugin` (lib/src/voice_recorder_plugin.dart): register it
/// with the host, `OrcaApp(..., plugins: [VoiceRecorderPlugin()])`. The
/// recording is returned as Flutter returns it: `stopRecording` writes its path
/// and duration to state.
///
/// Widget `VoiceRecorder`: props `recorderId` (default the node's id) and
/// `showAmplitude` (default true). Triggers `onStateChange` {state} and
/// `onAmplitudeChange` {amplitude} (dBFS); `onRecordingComplete` is declared
/// and never fired, as in Flutter. Actions `startRecording`, `stopRecording`,
/// `pauseRecording`, `resumeRecording`, `playRecording`, `stopPlayback`,
/// `pausePlayback`, `resumePlayback`, `seekPlayback`.
public struct VoiceRecorderPlugin: OrcaPlugin {
    public let name = "VoiceRecorderPlugin"
    /// What the widget and the actions share (Flutter's static maps).
    let recorders: VoiceRecorders

    /// Records with AVAudioRecorder into Flutter's temporary directory (on
    /// iOS path_provider's NSCachesDirectory) and plays with AVAudioPlayer.
    public init() {
        self.init(recorders: VoiceRecorders(
            makeRecorder: { AudioFileRecorder() }, makePlayer: { AudioFilePlayer() },
            directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0],
            now: { Date() }))
    }

    init(recorders: VoiceRecorders) {
        self.recorders = recorders
    }

    public var widgets: [String: OrcaWidgetBuilder] {
        ["VoiceRecorder": { [recorders] node, model in
            let view = recorders.view(node, model)
            return AnyView(view.id("voice_recorder_\(view.recorderId)"))
        }]
    }

    public var actions: [String: OrcaActionHandler] {
        let recorders = recorders
        return [
            "startRecording": { try await recorders.startRecording($0, $1) },
            "stopRecording": { try await recorders.stopRecording($0, $1) },
            "pauseRecording": { await recorders.pauseRecording($0, $1) },
            "resumeRecording": { await recorders.resumeRecording($0, $1) },
            "playRecording": { try await recorders.playRecording($0, $1) },
            "stopPlayback": { try await recorders.stopPlayback($0, $1) },
            "pausePlayback": { try await recorders.pausePlayback($0, $1) },
            "resumePlayback": { try await recorders.resumePlayback($0, $1) },
            "seekPlayback": { await recorders.seekPlayback($0, $1) },
        ]
    }

    public var triggers: [String: [TriggerDefinition]] {
        ["VoiceRecorder": [
            TriggerDefinition(
                name: VoiceRecorderProps.Triggers.onAmplitudeChange, dataType: "Amplitude",
                description: "Fires periodically with {amplitude, dBFS} during recording"),
            TriggerDefinition(
                name: VoiceRecorderProps.Triggers.onStateChange, dataType: "String",
                description: "Fires with {state} when recording state changes"),
            TriggerDefinition(
                name: VoiceRecorderProps.Triggers.onRecordingComplete, dataType: "RecordingResult",
                description: "Fires with {path, duration} when recording stops"),
        ]]
    }
}

/// A trigger a VoiceRecorder fires, with its event data.
struct VoiceRecorderEvent: Equatable {
    let trigger: String
    let eventData: [String: JSONValue]
}

/// One recorder and what its views draw (Flutter's `_RecorderInstance`).
/// Each change of state or level goes to the views on screen as a trigger
/// event, and only a change, as a ValueNotifier notifies.
@MainActor
final class VoiceRecorderInstance: ObservableObject {
    let recorder: Recorder
    /// idle, recording or paused.
    @Published var state = "idle" {
        didSet {
            guard state != oldValue else { return }
            events.send(VoiceRecorderEvent(
                trigger: VoiceRecorderProps.Triggers.onStateChange, eventData: ["state": .string(state)]))
        }
    }
    /// The last level in dBFS.
    @Published var amplitude = -60.0 {
        didSet {
            guard amplitude != oldValue else { return }
            events.send(VoiceRecorderEvent(
                trigger: VoiceRecorderProps.Triggers.onAmplitudeChange, eventData: ["amplitude": .double(amplitude)]))
        }
    }
    /// When the last recording started.
    var startTime: Date?
    let events = PassthroughSubject<VoiceRecorderEvent, Never>()

    init(recorder: Recorder) {
        self.recorder = recorder
    }
}

/// The recorders by recorderId and the one player, and the nine actions on
/// them, line for line Flutter's handlers (voice_recorder_plugin.dart
/// :224-464). The params come from the generated params types; recorderId,
/// path and position are resolved as values, as Flutter's `resolveString` and
/// `resolveValue`, the others read as sent.
@MainActor
final class VoiceRecorders {
    private static let log = Logger(subsystem: "com.orcagateway", category: "orca_voice_recorder")

    private(set) var instances: [String: VoiceRecorderInstance] = [:]
    /// Where recordings go.
    let directory: URL
    private let makeRecorder: @MainActor @Sendable () -> Recorder
    private let makePlayer: @MainActor @Sendable () -> Player
    private let now: @MainActor @Sendable () -> Date
    private lazy var player: Player = makePlayer()

    nonisolated init(
        makeRecorder: @escaping @MainActor @Sendable () -> Recorder, makePlayer: @escaping @MainActor @Sendable () -> Player,
        directory: URL, now: @escaping @MainActor @Sendable () -> Date
    ) {
        self.makeRecorder = makeRecorder
        self.makePlayer = makePlayer
        self.directory = directory
        self.now = now
    }

    /// The recorder for `id`, made the first time (Flutter's `_getOrCreate`).
    func recorder(_ id: String) -> VoiceRecorderInstance {
        if let instance = instances[id] { return instance }
        let instance = VoiceRecorderInstance(recorder: makeRecorder())
        instances[id] = instance
        return instance
    }

    /// The node's view on the recorder its recorderId names.
    func view(_ node: ResolvedNode, _ model: OrcaPageModel) -> VoiceRecorderView {
        let props = VoiceRecorderProps(node)
        let recorderId = props.recorderId ?? node.id
        return VoiceRecorderView(
            recorderId: recorderId, recorder: recorder(recorderId), showAmplitude: props.showAmplitude ?? true,
            fire: { model.fire($0.trigger, on: node, eventData: $0.eventData) })
    }

    // MARK: Recording

    func startRecording(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        let recorderId = Self.resolveString(StartRecordingParams(action).action["recorderId"], executor)
        guard !recorderId.isEmpty else { return }
        let instance = recorder(recorderId)
        guard await instance.recorder.hasPermission() else { return }

        let path = directory
            .appendingPathComponent("orca_recording_\(recorderId)_\(Self.milliseconds(now().timeIntervalSince1970)).m4a")
            .path
        try instance.recorder.start(path: path)
        instance.startTime = now()
        instance.state = "recording"
        instance.recorder.onAmplitudeChanged(every: 0.2) { [weak instance] in instance?.amplitude = $0 }
    }

    func stopRecording(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        let params = StopRecordingParams(action)
        let recorderId = Self.resolveString(params.action["recorderId"], executor)
        guard !recorderId.isEmpty, let instance = instances[recorderId] else { return }

        let path = instance.recorder.stop()
        instance.state = "idle"
        let duration = instance.startTime.map { Self.milliseconds(now().timeIntervalSince($0)) } ?? 0

        let scope = params.scope ?? "page"
        if let pathKey = params.pathKey, let path {
            try await Self.setState(executor, pathKey, .string(path), scope)
        }
        if let durationKey = params.durationKey {
            try await Self.setState(executor, durationKey, .int(duration), scope)
        }
    }

    func pauseRecording(_ action: JSONValue, _ executor: ActionExecutor) {
        let recorderId = Self.resolveString(PauseRecordingParams(action).action["recorderId"], executor)
        guard !recorderId.isEmpty, let instance = instances[recorderId] else { return }
        instance.recorder.pause()
        instance.state = "paused"
    }

    func resumeRecording(_ action: JSONValue, _ executor: ActionExecutor) {
        let recorderId = Self.resolveString(ResumeRecordingParams(action).action["recorderId"], executor)
        guard !recorderId.isEmpty, let instance = instances[recorderId] else { return }
        instance.recorder.resume()
        instance.state = "recording"
    }

    // MARK: Playback

    func playRecording(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        let params = PlayRecordingParams(action)
        let path = Self.resolveString(params.action["path"], executor)
        guard !path.isEmpty else {
            Self.log.debug("playRecording: empty path, skipping")
            return
        }
        // Live progress into these state keys when the caller names them.
        let positionKey = params.positionKey
        let durationKey = params.durationKey
        let stateKey = params.stateKey
        let scope = params.scope ?? "page"

        // The recorder leaves the session set for input: route it to output.
        do {
            try player.preparePlayback()
        } catch {
            Self.log.error("setAudioContext failed: \(String(describing: error), privacy: .public)")
        }

        // The last clip's listeners go before this clip's come, all before
        // play, so none misses its first event.
        cancelPlayback()
        if let positionKey {
            player.onPosition = { try? await Self.writeState(executor, positionKey, .int($0), scope) }
        }
        if let durationKey {
            player.onDuration = { try? await Self.writeState(executor, durationKey, .int($0), scope) }
        }
        player.onComplete = { [weak self] in
            self?.cancelPlayback()
            try? await Self.writeState(executor, positionKey, 0, scope)
            try? await Self.writeState(executor, stateKey, "stopped", scope)
        }

        do {
            try await player.play(path: path)
            try await Self.writeState(executor, stateKey, "playing", scope)
            Self.log.debug("play started: \(path, privacy: .public)")
        } catch {
            Self.log.error("play failed: \(String(describing: error), privacy: .public)")
            cancelPlayback()
            try await Self.writeState(executor, stateKey, "error", scope)
        }
    }

    func stopPlayback(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        player.stop()
        cancelPlayback()
        let params = StopPlaybackParams(action)
        let scope = params.scope ?? "page"
        try await Self.writeState(executor, params.positionKey, 0, scope)
        try await Self.writeState(executor, params.stateKey, "stopped", scope)
    }

    func pausePlayback(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        player.pause()
        let params = PausePlaybackParams(action)
        try await Self.writeState(executor, params.stateKey, "paused", params.scope ?? "page")
    }

    func resumePlayback(_ action: JSONValue, _ executor: ActionExecutor) async throws {
        player.resume()
        let params = ResumePlaybackParams(action)
        try await Self.writeState(executor, params.stateKey, "playing", params.scope ?? "page")
    }

    func seekPlayback(_ action: JSONValue, _ executor: ActionExecutor) {
        // A whole number of ms, else 0, never below 0.
        let position = executor.resolve(SeekPlaybackParams(action).action["position"]).dartInt ?? 0
        player.seek(milliseconds: max(position, 0))
    }

    /// Flutter's `_playbackSubs.cancelAll()`.
    private func cancelPlayback() {
        player.onPosition = nil
        player.onDuration = nil
        player.onComplete = nil
    }

    // MARK: Helpers

    /// Dart's `executor.resolveString`: the resolved value's `toString`, ""
    /// for null.
    private static func resolveString(_ raw: JSONValue, _ executor: ActionExecutor) -> String {
        let value = executor.resolve(raw)
        return value.isNull ? "" : DartFormat.string(value)
    }

    /// A `setState` of `key` in `scope` (app, else page), run by the executor.
    private static func setState(
        _ executor: ActionExecutor, _ key: String, _ value: JSONValue, _ scope: String
    ) async throws {
        try await executor.execute(.setState(.init(key: key, scope: scope == "app" ? .app : .page, value: value)))
    }

    /// Flutter's `_writeState`: nothing without a key.
    private static func writeState(
        _ executor: ActionExecutor, _ key: String?, _ value: JSONValue, _ scope: String
    ) async throws {
        guard let key, !key.isEmpty else { return }
        try await setState(executor, key, value, scope)
    }

    /// Whole milliseconds in `seconds`, as Dart's `inMilliseconds` and
    /// `millisecondsSinceEpoch`.
    private static func milliseconds(_ seconds: TimeInterval) -> Int {
        Int((seconds * 1000).rounded(.towardZero))
    }
}
#endif
