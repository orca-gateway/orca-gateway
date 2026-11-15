#if canImport(SwiftUI)
import SwiftUI

/// Progress (0...1) of the nearest enclosing AnimatedBuilder, after its
/// curve. Nodes below one resolve `tween` and `tweenSequence` props by it.
private struct OrcaAnimationProgressKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    var orcaAnimationProgress: Double? {
        get { self[OrcaAnimationProgressKey.self] }
        set { self[OrcaAnimationProgressKey.self] = newValue }
    }
}

/// Flutter `OrcaAnimatedBuilder` (sdk/lib/src/builders/animated_builder_widget.dart):
/// a clock of `duration` ms shaped by `curve`, running once or, with
/// `repeat`, forever (back and forth with `reverse`). Every frame its
/// descendants are resolved again with the clock's value, so their `tween`
/// props move. `autoStart: false` holds it at 0. `onComplete` fires when a
/// one-shot run ends.
///
/// Not ported yet: `animationId` targeting from actions (Dart's
/// AnimationRegistry); a tween naming an id resolves against the nearest
/// builder like an unnamed one.
@MainActor
struct AnimatedBuilderView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @State private var start = Date()
    @State private var completed = false

    var body: some View {
        let duration = max((node["duration"]?.doubleValue ?? 300) / 1000, 0.001)
        let repeats = node["repeat"]?.boolValue ?? false
        let reverse = node["reverse"]?.boolValue ?? false
        let autoStart = node["autoStart"]?.boolValue ?? true
        let curve = node["curve"]?.stringValue ?? "linear"
        let running = autoStart && (repeats || !completed)

        TimelineView(.animation(minimumInterval: nil, paused: !running)) { context in
            let raw = Self.clock(
                elapsed: context.date.timeIntervalSince(start), duration: duration,
                repeats: repeats, reverse: reverse, autoStart: autoStart)
            content
                .environment(\.orcaAnimationProgress, OrcaCurve.apply(curve, raw))
        }
        .task(id: node.id) {
            start = Date()
            completed = false
            guard autoStart, !repeats else { return }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            completed = true
            model.fire("onComplete", on: node)
        }
    }

    /// One child as is; several are stacked, as Dart's `Stack(fit: expand)`.
    @ViewBuilder
    private var content: some View {
        if node.childIds.count == 1, let only = node.childIds.first {
            NodeView(id: only, model: model)
        } else {
            ZStack(alignment: .topLeading) {
                ForEach(node.childIds, id: \.self) { NodeView(id: $0, model: model) }
            }
        }
    }

    /// The controller's raw value at `elapsed` seconds (Flutter's
    /// `forward()` and `repeat(reverse:)`).
    static func clock(elapsed: Double, duration: Double, repeats: Bool,
                      reverse: Bool, autoStart: Bool) -> Double {
        guard autoStart else { return 0 }
        let cycles = max(elapsed, 0) / duration
        guard repeats else { return min(cycles, 1) }
        let phase = cycles.truncatingRemainder(dividingBy: 1)
        guard reverse else { return phase }
        return Int(cycles) % 2 == 0 ? phase : 1 - phase
    }
}

/// Flutter's named curves (the `Curve` the engine sends), as cubic beziers.
enum OrcaCurve {
    static func apply(_ name: String, _ t: Double) -> Double {
        switch name {
        case "easeIn": return bezier(0.42, 0, 1, 1, t)
        case "easeOut": return bezier(0, 0, 0.58, 1, t)
        case "easeInOut": return bezier(0.42, 0, 0.58, 1, t)
        case "ease": return bezier(0.25, 0.1, 0.25, 1, t)
        case "fastOutSlowIn": return bezier(0.4, 0, 0.2, 1, t)
        case "easeInCubic": return bezier(0.55, 0.055, 0.675, 0.19, t)
        case "easeOutCubic": return bezier(0.215, 0.61, 0.355, 1, t)
        case "easeInOutCubic": return bezier(0.645, 0.045, 0.355, 1, t)
        case "decelerate": return 1 - (1 - t) * (1 - t)
        default: return t
        }
    }

    /// y on the bezier (0,0)-(x1,y1)-(x2,y2)-(1,1) at x = t (Flutter's Cubic).
    static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ t: Double) -> Double {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        func point(_ a: Double, _ b: Double, _ m: Double) -> Double {
            3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m
        }
        var lo = 0.0, hi = 1.0
        for _ in 0..<30 {
            let mid = (lo + hi) / 2
            if point(x1, x2, mid) < t { lo = mid } else { hi = mid }
        }
        return point(y1, y2, (lo + hi) / 2)
    }
}

/// Flutter `Transform` (layout_builders.dart `_buildTransform`): `transform`
/// is `{type: translate, dx, dy}`, `{type: rotate, angle}` (radians) or
/// `{type: scale, scaleX, scaleY}`, about `alignment` (default center).
///
/// One difference: a translated child is laid out at its own size along the
/// moved axis while the Transform keeps the size it is offered, so text can
/// slide inside a clipping parent (a ticker). Flutter needs an OverflowBox
/// for that; SwiftUI would otherwise squeeze or truncate the text first.
@MainActor
struct TransformView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let t = node["transform"]
        let anchor = Props.unitPoint(node["alignment"])
        let child = ChildView(node: node, model: model)
        switch t?["type"].stringValue {
        case "translate":
            let dx = t?["dx"].doubleValue ?? 0
            let dy = t?["dy"].doubleValue ?? 0
            // Keyed on the prop being sent, not on its value, so a tween
            // passing through 0 does not change the layout.
            OverflowAxes(horizontal: t?["dx"].isNull == false, vertical: t?["dy"].isNull == false) {
                child
            }
            .offset(x: dx, y: dy)
        case "rotate":
            child.rotationEffect(.radians(t?["angle"].doubleValue ?? 0), anchor: anchor)
        case "scale":
            let base = t?["scale"].doubleValue ?? 1
            child.scaleEffect(x: t?["scaleX"].doubleValue ?? base,
                              y: t?["scaleY"].doubleValue ?? base, anchor: anchor)
        default:
            child
        }
    }
}

/// Lays its child out unbounded along the chosen axes, takes no more than
/// the offered size itself, and pins the child to the top leading corner:
/// what overflows is drawn outside the bounds (Flutter's OverflowBox).
struct OverflowAxes: Layout {
    let horizontal: Bool
    let vertical: Bool

    private func childProposal(_ p: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: horizontal ? nil : p.width, height: vertical ? nil : p.height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(childProposal(proposal))
        func cap(_ size: CGFloat, _ offered: CGFloat?) -> CGFloat {
            guard let offered, offered.isFinite else { return size }
            return min(size, offered)
        }
        return CGSize(width: horizontal ? cap(ideal.width, proposal.width) : ideal.width,
                      height: vertical ? cap(ideal.height, proposal.height) : ideal.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                              proposal: childProposal(ProposedViewSize(bounds.size)))
    }
}
#endif
