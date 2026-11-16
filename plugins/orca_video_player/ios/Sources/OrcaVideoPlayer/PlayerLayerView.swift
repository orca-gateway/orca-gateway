#if canImport(SwiftUI) && canImport(AVFoundation)
import AVFoundation
import SwiftUI

/// The player's frames in an AVPlayerLayer, as sdk-swift's Video draws them
/// (Widgets/Video.swift, internal there). Stretched to the view's bounds, as
/// Flutter's Texture fills its AspectRatio box: at the video's own aspect
/// ratio that is the whole frame, at another one it is stretched. It takes
/// no touch or click, so a tap reaches the SwiftUI gesture over it.
#if canImport(UIKit)
import UIKit

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> LayerView {
        LayerView()
    }

    func updateUIView(_ view: LayerView, context: Context) {
        view.playerLayer.player = player
    }

    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resize
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    }
}
#elseif canImport(AppKit)
import AppKit

struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> LayerView {
        LayerView()
    }

    func updateNSView(_ view: LayerView, context: Context) {
        view.playerLayer.player = player
    }

    final class LayerView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resize
            // A layer-hosting view: the layer first, then wantsLayer.
            layer = playerLayer
            wantsLayer = true
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    }
}
#endif
#endif
