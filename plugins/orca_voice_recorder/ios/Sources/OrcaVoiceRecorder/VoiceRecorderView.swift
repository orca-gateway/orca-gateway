#if canImport(SwiftUI) && canImport(AVFoundation)
import OrcaGateway
import SwiftUI

/// The VoiceRecorder widget as Flutter draws it (voice_recorder_plugin.dart
/// :182-219): a 16 pt dot, red recording, orange paused, grey idle; while
/// recording with showAmplitude, 8 pt below, a 100 x 4 pt bar green over
/// (amplitude + 60) / 60 of its width, clamped; 4 pt below, the label
/// Recording, Paused or Ready at 12 pt. While on screen it fires its
/// recorder's changes as the node's triggers (Flutter's listeners, from
/// initState to dispose).
struct VoiceRecorderView: View {
    let recorderId: String
    @ObservedObject var recorder: VoiceRecorderInstance
    let showAmplitude: Bool
    /// Fires one of the node's triggers; the task ends when its action does.
    let fire: @MainActor (VoiceRecorderEvent) -> Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Self.dotColor(recorder.state))
                .frame(width: 16, height: 16)
            if showAmplitude && recorder.state == "recording" {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.rgb(0x4CAF50))
                    .frame(width: 100 * Self.barFraction(recorder.amplitude), height: 4)
                    .frame(width: 100, height: 4, alignment: .leading)
                    .padding(.top, 8)
            }
            Text(Self.label(recorder.state))
                .font(.system(size: 12))
                .padding(.top, 4)
        }
        .onReceive(recorder.events) { _ = fire($0) }
    }

    static func label(_ state: String) -> String {
        state == "recording" ? "Recording" : state == "paused" ? "Paused" : "Ready"
    }

    static func dotColor(_ state: String) -> Color {
        rgb(state == "recording" ? 0xFF0000 : state == "paused" ? 0xFF9800 : 0x9E9E9E)
    }

    /// The share of the bar a level in dBFS fills: -60 and below none, 0 and
    /// above all of it.
    static func barFraction(_ amplitude: Double) -> Double {
        min(max(amplitude + 60, 0), 60) / 60
    }

    private static func rgb(_ hex: Int) -> Color {
        Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
#endif
