#if canImport(SwiftUI)
import SwiftUI

/// Flutter `InteractiveViewer` (layout_builders.dart:636-644: `minScale`
/// 0.8, `maxScale` 2.5, `panEnabled` and `scaleEnabled` true; the
/// framework's boundaryMargin zero, constrained true, clipBehavior
/// hardEdge, no alignment). Its build (interactive_viewer.dart:1052-1140) is
/// all proxies, so the viewer is its child's size and the child is laid out
/// with the viewer's own proposal. The child is drawn through the core's
/// ViewerTransform (the scale about its top-left corner, then the offset)
/// and clipped to the viewer's box, which takes hits all over (Flutter's
/// opaque GestureDetector, `hitFill`) while the child's own controls take
/// theirs first. A pinch and, only while it can pan, a drag are fed to the
/// core's ViewerGesture by `ViewerFeed`; fling inertia is not ported.
/// Two known differences:
/// - The pinch's focal point is fixed for the whole pinch: where it began
///   (MagnifyGesture, iOS 17 / macOS 14) or the box's centre
///   (MagnificationGesture, iOS 16), as SwiftUI reports no live one. Flutter's
///   is the live centre of the fingers, and its scale update keeps the
///   reference under it (interactive_viewer.dart:757-775), so moving two
///   fingers pans while zooming there, even with panEnabled false; here it
///   does not. The core follows a moving focal point; nothing feeds it one.
/// - A UIKit-backed child (a text field) zoomed past the viewer's edge still
///   takes taps on its clipped-off part, where Flutter's ClipRect takes none
///   (SwiftUI hit-tests a platform view without the clip).
@MainActor
struct InteractiveViewerView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @State private var transform: ViewerTransform
    @State private var feed = ViewerFeed()
    @State private var size = CGSize.zero
    @GestureState private var dragging = false

    /// `initial` is the transform it starts from (the identity, as
    /// Flutter's; another only in tests).
    init(node: ResolvedNode, model: OrcaPageModel, initial: ViewerTransform = .identity) {
        self.node = node
        self.model = model
        _transform = State(initialValue: initial)
    }

    var body: some View {
        ChildView(node: node, model: model)
            .scaleEffect(transform.scale, anchor: .topLeading)
            .offset(x: transform.x, y: transform.y)
            .clipShape(Rectangle())
            .contentShape(Rectangle())
            .background { Rectangle().hitFill() }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .modifier(Pinch(changed: { magnification, start in
                guard size.width > 0, size.height > 0 else { return }
                transform = feed.pinch(magnification, about: ViewerFeed.focal(start, in: size),
                                       transform: transform, limits: limits)
            }, ended: { feed.pinchEnded() }))
            .gesture(DragGesture()
                .updating($dragging) { _, state, _ in state = true }
                .onChanged { value in
                    guard size.width > 0, size.height > 0 else { return }
                    transform = feed.drag(to: ViewerPoint(x: value.location.x, y: value.location.y),
                                          transform: transform, limits: limits)
                },
                including: ViewerFeed.pans(transform, limits) ? .all : .subviews)
            // Ended or cancelled (when the drag is let go of mid-way), the state resets.
            .onChange(of: dragging) { active in if !active { feed.dragEnded() } }
    }

    /// The viewport and the child are both the viewer's box (the child is
    /// laid out at the viewer's proposal and the viewer takes its size).
    private var limits: ViewerLimits {
        let box = ViewerSize(width: size.width, height: size.height)
        return ViewerLimits(viewport: box, child: box,
                            minScale: Props.number(node["minScale"]) ?? 0.8,
                            maxScale: Props.number(node["maxScale"]) ?? 2.5,
                            panEnabled: Props.bool(node["panEnabled"]) ?? true,
                            scaleEnabled: Props.bool(node["scaleEnabled"]) ?? true)
    }
}

/// The pinch: MagnifyGesture with where it began (iOS 17 / macOS 14), else
/// MagnificationGesture, which has no location. Simultaneous, so it holds
/// back neither the drag nor the child's own gestures. `ended` runs once it
/// ends or is cancelled.
private struct Pinch: ViewModifier {
    let changed: (Double, CGPoint?) -> Void
    let ended: () -> Void
    @GestureState private var pinching = false

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 17, macOS 14, *) {
                content.simultaneousGesture(MagnifyGesture()
                    .updating($pinching) { _, state, _ in state = true }
                    .onChanged { changed($0.magnification, $0.startLocation) })
            } else {
                content.simultaneousGesture(MagnificationGesture()
                    .updating($pinching) { _, state, _ in state = true }
                    .onChanged { changed($0, nil) })
            }
        }
        .onChange(of: pinching) { active in if !active { ended() } }
    }
}

/// SwiftUI's pinch and drag fed to Flutter's one scale gesture
/// (ViewerGesture). A pinch reports its magnification since it began about
/// a focal point that SwiftUI keeps fixed (Flutter's moves with the
/// fingers; see InteractiveViewerView). It starts a gesture of its own, as
/// a second finger restarts Flutter's (ScaleGestureRecognizer
/// `_reconfigure`), and a drag while it lasts is one of its fingers, so it
/// moves nothing. A drag on its own is a pan (scale 1) from where it is
/// first reported (Flutter's starts past its slop the same way); after a
/// pinch it starts afresh.
struct ViewerFeed {
    private var gesture: ViewerGesture?
    private var pinching = false

    /// A pinch at `magnification` since it began, about `focal`.
    mutating func pinch(_ magnification: Double, about focal: ViewerPoint, transform: ViewerTransform,
                        limits: ViewerLimits) -> ViewerTransform {
        if !pinching {
            pinching = true
            gesture = Self.started(at: focal, transform)
        }
        return gesture?.update(scale: magnification, focal: focal, transform: transform, limits: limits) ?? transform
    }

    /// A drag's finger at `location`.
    mutating func drag(to location: ViewerPoint, transform: ViewerTransform,
                       limits: ViewerLimits) -> ViewerTransform {
        guard !pinching else { return transform }
        if gesture == nil { gesture = Self.started(at: location, transform) }
        return gesture?.update(scale: 1, focal: location, transform: transform, limits: limits) ?? transform
    }

    mutating func pinchEnded() {
        pinching = false
        gesture = nil
    }

    mutating func dragEnded() {
        if !pinching { gesture = nil }
    }

    /// The pinch's focal point: where it began when SwiftUI reports it
    /// (MagnifyGesture), else the centre of the box.
    static func focal(_ start: CGPoint?, in size: CGSize) -> ViewerPoint {
        let point = start ?? CGPoint(x: size.width / 2, y: size.height / 2)
        return ViewerPoint(x: point.x, y: point.y)
    }

    /// Whether a drag can move the transform, so it is taken: zoomed in
    /// with pan on. At 1 and below Flutter's bound leaves no room, and the
    /// drag goes on to a scroll view around the viewer.
    static func pans(_ transform: ViewerTransform, _ limits: ViewerLimits) -> Bool {
        limits.panEnabled && transform.scale > 1
    }

    private static func started(at focal: ViewerPoint, _ transform: ViewerTransform) -> ViewerGesture {
        var gesture = ViewerGesture()
        gesture.start(focal: focal, transform: transform)
        return gesture
    }
}
#endif
