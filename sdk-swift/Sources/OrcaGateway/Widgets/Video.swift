#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit) && canImport(AVFoundation)
import AVFoundation
import UIKit
#endif

/// `Video` (engine/src/components/primitive/video.ts): a network video
/// (`src`, mp4 or HLS) in a `width` by `height` box, fitted by `fit`
/// (default `cover`). With `autoplay` (default) it plays while at least
/// `visibleFraction` (default 0.5) of it is on screen and pauses when it
/// scrolls away or the page goes. `muted` and `loop` default to true, as in a
/// feed. `poster` is drawn until the first frame is ready. `onTap` fires on a
/// tap, like an Image wrapped in a GestureDetector.
@MainActor
struct VideoNodeView: View {
    let node: ResolvedNode

    var body: some View {
        let width = Props.number(node["width"])
        let height = Props.number(node["height"])
        ZStack {
            #if canImport(UIKit) && canImport(AVFoundation)
            VisibilityTracked(threshold: node["visibleFraction"]?.doubleValue ?? 0.5) { visible in
                PlayerSurface(
                    src: Props.text(node["src"]),
                    poster: node["poster"]?.stringValue,
                    fill: (node["fit"]?.stringValue ?? "cover") == "cover",
                    playing: visible && (node["autoplay"]?.boolValue ?? true),
                    muted: node["muted"]?.boolValue ?? true,
                    loop: node["loop"]?.boolValue ?? true)
            }
            #else
            poster
            #endif
        }
        .frame(width: width, height: height)
        .clipped()
        .accessibilityElement()
        .accessibilityAddTraits(.startsMediaSession)
    }

    @ViewBuilder
    private var poster: some View {
        if let src = node["poster"]?.stringValue, let url = URL(string: src) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) } else { Color.black }
            }
        } else {
            Color.black
        }
    }
}

#if canImport(UIKit) && canImport(AVFoundation)
/// Reports whether `threshold` of the view's area is inside the window. It
/// is checked on every layout pass, which a scroll causes, so a video in a
/// horizontal or vertical list starts as it comes into view.
private struct VisibilityTracked<Content: View>: View {
    let threshold: Double
    @ViewBuilder let content: (Bool) -> Content
    @State private var visible = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content(visible && scenePhase == .active)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { update(proxy.frame(in: .global)) }
                        .onChange(of: proxy.frame(in: .global)) { update($0) }
                })
            .onDisappear { visible = false }
    }

    private func update(_ frame: CGRect) {
        let screen = UIScreen.main.bounds
        let area = frame.width * frame.height
        guard area > 0 else { visible = false; return }
        let shown = frame.intersection(screen)
        let fraction = shown.isNull ? 0 : (shown.width * shown.height) / area
        let next = fraction >= threshold
        if next != visible { visible = next }
    }
}

/// One AVPlayer in an AVPlayerLayer, looping with AVPlayerLooper. The poster
/// stays on top until the layer has a frame to show.
private struct PlayerSurface: UIViewRepresentable {
    let src: String
    let poster: String?
    let fill: Bool
    let playing: Bool
    let muted: Bool
    let loop: Bool

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.configure(src: src, poster: poster, loop: loop)
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        view.configure(src: src, poster: poster, loop: loop)
        view.playerLayer.videoGravity = fill ? .resizeAspectFill : .resizeAspect
        view.player.isMuted = muted
        if playing { view.player.play() } else { view.player.pause() }
    }

    static func dismantleUIView(_ view: PlayerUIView, coordinator: ()) {
        view.player.pause()
        view.player.removeAllItems()
    }
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var current: String?
    private let posterView = UIImageView()
    private var readyObservation: NSKeyValueObservation?
    private var posterTask: URLSessionDataTask?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.player = player
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.frame = bounds
        posterView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(posterView)
        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
            let ready = layer.isReadyForDisplay
            DispatchQueue.main.async { self?.posterView.isHidden = ready }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(src: String, poster: String?, loop: Bool) {
        guard src != current else { return }
        current = src
        looper = nil
        player.removeAllItems()
        posterView.isHidden = false
        loadPoster(poster)
        guard let url = URL(string: src), ["http", "https"].contains(url.scheme?.lowercased()) else { return }
        let item = AVPlayerItem(url: url)
        // Feed previews: start fast, small buffer.
        item.preferredForwardBufferDuration = 2
        if loop {
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            player.insert(item, after: nil)
        }
    }

    private func loadPoster(_ poster: String?) {
        posterTask?.cancel()
        posterView.image = nil
        guard let poster, let url = URL(string: poster) else { return }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self?.posterView.image = image }
        }
        posterTask = task
        task.resume()
    }
}
#endif
#endif
