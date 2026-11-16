import CoreGraphics
import Foundation

/// What a playback reports, on the main actor.
enum VideoPlaybackEvent: Equatable {
    /// Loaded: the length in ms and the frame size.
    case ready(duration: Int, size: CGSize)
    /// The video could not be loaded.
    case failed(message: String)
    /// The position in ms, every 100 ms while playing.
    case position(Int)
    /// Played to its end (never while looping: it starts again).
    case ended
}

/// What the plugin asks of a video player for one url: the platform half of
/// video_player (video_player_avfoundation's FVPVideoPlayer), under the
/// controller that ports video_player's Dart semantics. `AVVideoPlayback` in
/// an app, a fake in the tests.
@MainActor
protocol VideoPlayback: AnyObject {
    /// Starts loading; from now until `dispose`, `onEvent` hears what the
    /// player reports.
    func initialize(_ onEvent: @escaping (VideoPlaybackEvent) -> Void)
    func setLooping(_ looping: Bool)
    func play()
    func pause()
    func seek(to milliseconds: Int)
    /// 0...1.
    func setVolume(_ volume: Double)
    /// Above 0; applied while playing.
    func setSpeed(_ speed: Double)
    func dispose()
}

#if canImport(AVFoundation)
import AVFoundation

/// `VideoPlayback` on AVPlayer, as video_player_avfoundation 2.9.4 plays it:
/// ready when the item's status is readyToPlay (its duration and
/// presentationSize), failed when it is failed (its error's
/// localizedDescription), the position every 100 ms by a periodic time
/// observer, the end by AVPlayerItemDidPlayToEndTime (a looping player seeks
/// to 0 instead), the speed as the rate while playing.
@MainActor
final class AVVideoPlayback: VideoPlayback {
    /// What PlayerLayerView shows.
    let player = AVPlayer()
    private let url: String
    private var looping = false
    private var playing = false
    private var speed = 1.0
    private var initialized = false
    private var onEvent: ((VideoPlaybackEvent) -> Void)?
    private var status: NSKeyValueObservation?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(url: String) {
        self.url = url
        // The end is handled here: looping seeks to 0, else it is reported.
        player.actionAtItemEnd = .none
    }

    func initialize(_ onEvent: @escaping (VideoPlaybackEvent) -> Void) {
        self.onEvent = onEvent
        guard let url = URL(string: url) else {
            onEvent(.failed(message: URLError(.badURL).localizedDescription))
            return
        }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        status = item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.statusChanged() } }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.ended() }
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 10), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.onEvent?(.position(Self.milliseconds(time))) }
        }
    }

    func setLooping(_ looping: Bool) {
        self.looping = looping
    }

    func play() {
        playing = true
        updatePlayingState()
    }

    func pause() {
        playing = false
        updatePlayingState()
    }

    func seek(to milliseconds: Int) {
        player.seek(to: CMTime(value: CMTimeValue(milliseconds), timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setVolume(_ volume: Double) {
        player.volume = Float(volume)
    }

    func setSpeed(_ speed: Double) {
        self.speed = speed
        updatePlayingState()
    }

    func dispose() {
        onEvent = nil
        status?.invalidate()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func statusChanged() {
        guard let item = player.currentItem else { return }
        switch item.status {
        case .readyToPlay where !initialized:
            initialized = true
            onEvent?(.ready(duration: Self.milliseconds(item.duration), size: item.presentationSize))
            updatePlayingState()
        case .failed:
            onEvent?(.failed(message: item.error?.localizedDescription ?? "Failed to load video"))
        default:
            break
        }
    }

    private func ended() {
        if looping {
            player.seek(to: .zero)
        } else {
            onEvent?(.ended)
        }
    }

    /// Calling play sets the rate to 1, so a speed is set as the rate.
    private func updatePlayingState() {
        guard initialized else { return }
        if playing {
            player.rate = Float(speed)
        } else {
            player.pause()
        }
    }

    /// FVPCMTimeToMillis, whole ms: an indefinite time (a live stream) is
    /// ExoPlayer's TIME_UNSET, as on Android.
    nonisolated static func milliseconds(_ time: CMTime) -> Int {
        if time.flags.contains(.indefinite) { return -9_223_372_036_854_775_807 }
        if time.timescale == 0 { return 0 }
        return Int(CMTimeConvertScale(time, timescale: 1000, method: .roundTowardZero).value)
    }
}
#endif
