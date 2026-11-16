import Foundation

/// What the plugin asks of an audio file player: the part of audioplayers'
/// `AudioPlayer` the Flutter plugin uses (lib/src/voice_recorder_plugin.dart).
/// `AudioFilePlayer` in an app, a fake in the tests. One for the whole plugin.
///
/// The three listeners are Flutter's stream subscriptions: the plugin sets
/// them before `play` and clears them to cancel.
@MainActor
protocol Player: AnyObject {
    /// The position in ms, as it plays.
    var onPosition: ((Int) async -> Void)? { get set }
    /// The clip's duration in ms, once it is loaded.
    var onDuration: ((Int) async -> Void)? { get set }
    /// The clip played to its end.
    var onComplete: (() async -> Void)? { get set }
    /// Routes the audio session to output (iOS `.playback`), as the Flutter
    /// plugin's `setAudioContext`.
    func preparePlayback() throws
    /// Plays the file at `path` from its start, in place of any clip.
    func play(path: String) async throws
    func stop()
    func pause()
    func resume()
    func seek(milliseconds: Int)
}

#if canImport(AVFoundation)
import AVFoundation

/// `Player` on AVAudioPlayer: the duration when the clip loads, the position
/// every 200 ms while playing, the end from the player's delegate.
@MainActor
final class AudioFilePlayer: NSObject, Player, AVAudioPlayerDelegate {
    var onPosition: ((Int) async -> Void)?
    var onDuration: ((Int) async -> Void)?
    var onComplete: (() async -> Void)?
    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?

    struct PlayFailed: Error {
        let path: String
    }

    func preparePlayback() throws {
        #if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    func play(path: String) async throws {
        stop()
        let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        player.delegate = self
        guard player.play() else { throw PlayFailed(path: path) }
        self.player = player
        await onDuration?(Self.milliseconds(player.duration))
        startTicker()
    }

    func stop() {
        ticker?.cancel()
        player?.stop()
        player = nil
    }

    func pause() {
        ticker?.cancel()
        player?.pause()
    }

    func resume() {
        guard let player, player.play() else { return }
        startTicker()
    }

    func seek(milliseconds: Int) {
        player?.currentTime = TimeInterval(milliseconds) / 1000
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finished = ObjectIdentifier(player)
        Task { @MainActor in
            guard let current = self.player, ObjectIdentifier(current) == finished else { return }
            self.ticker?.cancel()
            self.player = nil
            await self.onComplete?()
        }
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let player = self.player else { return }
                await self.onPosition?(Self.milliseconds(player.currentTime))
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private static func milliseconds(_ seconds: TimeInterval) -> Int {
        Int((seconds * 1000).rounded(.towardZero))
    }
}
#endif
