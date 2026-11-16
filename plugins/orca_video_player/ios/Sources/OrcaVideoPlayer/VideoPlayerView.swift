#if canImport(SwiftUI) && canImport(AVFoundation)
import OrcaGateway
import SwiftUI

/// The VideoPlayer widget as Flutter draws it (video_player_plugin.dart
/// :229-286): loading, a 32 pt circle of 0x33000000 in the middle; on error,
/// "Video failed to load" at 14 pt in the middle; ready, the video at
/// aspectRatio (else the video's own), and with showControls a tap plays or
/// pauses it, with the play mark over it while not playing. Its player lives
/// from when it comes on screen until it leaves, and its triggers fire while
/// it is on screen.
struct VideoPlayerView: View {
    let options: VideoPlayerOptions
    @StateObject private var state: VideoPlayerState
    /// Fires one of the node's triggers; the task ends when its action does.
    let fire: @MainActor (VideoPlayerEvent) -> Task<Void, Never>?

    init(
        options: VideoPlayerOptions, state: @autoclosure @escaping () -> VideoPlayerState,
        fire: @escaping @MainActor (VideoPlayerEvent) -> Task<Void, Never>?
    ) {
        self.options = options
        _state = StateObject(wrappedValue: state())
        self.fire = fire
    }

    var body: some View {
        content
            .onAppear { state.appear(options) }
            .onChange(of: options) { state.change($0) }
            .onDisappear { state.disappear() }
            .onReceive(state.events) { _ = fire($0) }
    }

    @ViewBuilder
    private var content: some View {
        if state.hasError {
            Text("Video failed to load")
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !state.initialized {
            Circle()
                .fill(Color(.sRGB, white: 0, opacity: 0x33 / 255))
                .frame(width: 32, height: 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if options.showControls {
            ZStack {
                video
                if !state.isPlaying { PlayMark() }
            }
            .contentShape(Rectangle())
            .onTapGesture { state.togglePlayPause() }
        } else {
            video
        }
    }

    private var video: some View {
        PlayerLayerView(player: (state.controller?.playback as? AVVideoPlayback)?.player)
            .aspectRatio(options.aspectRatio ?? state.aspectRatio, contentMode: .fit)
    }
}

/// The play mark: a 56 pt circle of 0x99000000 with a white ▶ at 24 pt,
/// 4 pt of left padding, in its middle.
struct PlayMark: View {
    var body: some View {
        Circle()
            .fill(Color(.sRGB, white: 0, opacity: 0x99 / 255))
            .frame(width: 56, height: 56)
            .overlay {
                Text("\u{25B6}")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding(.leading, 4)
            }
    }
}
#endif
