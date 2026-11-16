import Foundation

/// What the plugin asks of a microphone recorder: the part of the record
/// package's `AudioRecorder` the Flutter plugin uses
/// (lib/src/voice_recorder_plugin.dart). `AudioFileRecorder` in an app, a fake
/// in the tests. One per recorderId.
@MainActor
protocol Recorder: AnyObject {
    /// Whether the app may record, asking the user when it has not yet.
    func hasPermission() async -> Bool
    /// Starts recording AAC-LC into the file at `path`, replacing it.
    func start(path: String) throws
    /// Stops recording and its level reports; the file's path, nil when
    /// nothing was recording.
    func stop() -> String?
    func pause()
    func resume()
    /// From now until `stop`, `onAmplitude` gets the input level in dBFS
    /// every `interval` seconds while recording (not while paused).
    func onAmplitudeChanged(every interval: TimeInterval, _ onAmplitude: @escaping (Double) -> Void)
}

#if canImport(AVFoundation)
import AVFoundation

/// `Recorder` on AVAudioRecorder, as record_ios does it: the microphone
/// permission from AVCaptureDevice; on iOS the session set to playAndRecord
/// and activated; AAC-LC at 44.1 kHz, 128 kbit/s, 2 channels (RecordConfig's
/// defaults); the level from metering (averagePower, -160 without a recorder).
@MainActor
final class AudioFileRecorder: Recorder {
    private var recorder: AVAudioRecorder?
    private var path: String?
    private var interval: TimeInterval = 0.2
    private var onAmplitude: ((Double) -> Void)?
    private var metering: Task<Void, Never>?

    func hasPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    func start(path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        let recorder = try AVAudioRecorder(url: URL(fileURLWithPath: path), settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVEncoderBitRateKey: 128_000,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ])
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()
        self.recorder = recorder
        self.path = path
    }

    func stop() -> String? {
        metering?.cancel()
        onAmplitude = nil
        recorder?.stop()
        recorder = nil
        defer { path = nil }
        return path
    }

    func pause() {
        guard let recorder, recorder.isRecording else { return }
        metering?.cancel()
        recorder.pause()
    }

    func resume() {
        recorder?.record()
        startMetering()
    }

    func onAmplitudeChanged(every interval: TimeInterval, _ onAmplitude: @escaping (Double) -> Void) {
        self.interval = interval
        self.onAmplitude = onAmplitude
        startMetering()
    }

    private func startMetering() {
        metering?.cancel()
        guard onAmplitude != nil else { return }
        let nanoseconds = UInt64(interval * 1_000_000_000)
        metering = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled, let self else { return }
                self.recorder?.updateMeters()
                self.onAmplitude?(Double(self.recorder?.averagePower(forChannel: 0) ?? -160))
            }
        }
    }
}
#endif
