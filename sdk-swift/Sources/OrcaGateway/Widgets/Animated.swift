#if canImport(SwiftUI)
import Combine
import SwiftUI

// MARK: The implicit widgets

/// One implicitly animated widget's clock while it is on screen: the core's
/// `ImplicitAnimation` over the node's resolved props. The view hands it the
/// node on every redraw and draws `node(at:)`, the same node with the props
/// sampled at the frame's time, through the plain widget's drawing code.
/// Every call takes "now" in milliseconds (`OrcaPageModel.milliseconds`).
@MainActor
final class ImplicitDriver: ObservableObject {
    enum Kind {
        case container, opacity, align

        /// What Flutter's widget assumes for a prop the node leaves out. It
        /// is filled in before the props reach the core, where a missing
        /// side would snap instead of animating.
        var defaults: [String: JSONValue] {
            switch self {
            case .container: return [:]
            case .opacity: return ["opacity": 1]
            case .align: return ["alignment": "center"]
            }
        }
    }

    private let kind: Kind
    private var animation = ImplicitAnimation()
    private var node: ResolvedNode?
    /// Whether the view needs another frame: a run is live, or one has ended
    /// and `settle` has not let the view pause yet.
    private(set) var needsTick = false

    init(_ kind: Kind) {
        self.kind = kind
    }

    /// The view was redrawn with `node` (Flutter's `didUpdateWidget`): props
    /// that differ from the last ones start a run from what is on screen;
    /// the first ones, and any change under reduced motion or with a
    /// duration of 0, show at once. Returns `needsTick`.
    @discardableResult
    func update(node: ResolvedNode, reduceMotion: Bool, at now: Double) -> Bool {
        var filled = node
        for (key, value) in kind.defaults where node[key] == nil { filled.props[key] = value }
        self.node = filled
        animation.durationMs = AnimationDuration.milliseconds(node["duration"])
        animation.curve = node["curve"]?.stringValue
        animation.reduceMotion = reduceMotion
        if animation.retarget(to: filled.props, at: now) {
            needsTick = true
        } else if !animation.isRunning(at: now) {
            needsTick = false
        }
        return needsTick
    }

    /// The node to draw at `now`: the core's mix while a run is live, else
    /// the props exactly as they were resolved.
    func node(at now: Double) -> ResolvedNode {
        guard var sampled = node else { preconditionFailure("node(at:) before update") }
        sampled.props = animation.value(at: now)
        return sampled
    }

    /// The frame tick: once the run has ended, lets the view pause.
    func settle(at now: Double) {
        guard needsTick, !animation.isRunning(at: now) else { return }
        needsTick = false
        objectWillChange.send()
    }
}

/// Draws an implicit widget: hands the node to the driver, asks for frames
/// only while a run is live, and builds `content` from the sampled node.
@MainActor
private struct ImplicitFrames<Content: View>: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @ObservedObject var driver: ImplicitDriver
    let reduceMotion: Bool
    @ViewBuilder let content: (ResolvedNode) -> Content

    var body: some View {
        // Not a published change: the driver only notes the new target, and
        // handing it the same node again does nothing.
        let live = driver.update(node: node, reduceMotion: reduceMotion, at: model.frameClock())
        TimelineView(.animation(minimumInterval: nil, paused: !live)) { context in
            content(driver.node(at: OrcaPageModel.milliseconds(context.date)))
                .onChange(of: context.date) { date in
                    driver.settle(at: OrcaPageModel.milliseconds(date))
                }
        }
    }
}

/// Flutter `AnimatedContainer` (layout_builders.dart `_buildAnimatedContainer`):
/// a Container whose `width`, `height`, `color`, `padding`, `margin`,
/// `decoration` and `alignment` move to their new values over `duration` ms
/// (300) by `curve` (easeInOut). The sampled props are drawn by ContainerView.
@MainActor
struct AnimatedContainerView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @StateObject private var driver = ImplicitDriver(.container)
    @OrcaReduceMotion private var reduceMotion

    var body: some View {
        ImplicitFrames(node: node, model: model, driver: driver, reduceMotion: reduceMotion) {
            ContainerView(node: $0, model: model)
        }
    }
}

/// Flutter `AnimatedOpacity` (`_buildAnimatedOpacity`): `opacity` (1) moves
/// to its new value over `duration` ms by `curve`.
@MainActor
struct AnimatedOpacityView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @StateObject private var driver = ImplicitDriver(.opacity)
    @OrcaReduceMotion private var reduceMotion

    var body: some View {
        ImplicitFrames(node: node, model: model, driver: driver, reduceMotion: reduceMotion) { sampled in
            // A curve that overshoots (elastic, back) leaves 0...1.
            ChildView(node: sampled, model: model)
                .opacity(min(max(Double(Props.number(sampled["opacity"]) ?? 1), 0), 1))
        }
    }
}

/// Flutter `AnimatedAlign` (`_buildAnimatedAlign`): `alignment` (center)
/// moves to its new value over `duration` ms by `curve`; `widthFactor` and
/// `heightFactor` size the box from the child.
@MainActor
struct AnimatedAlignView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @StateObject private var driver = ImplicitDriver(.align)
    @OrcaReduceMotion private var reduceMotion

    var body: some View {
        ImplicitFrames(node: node, model: model, driver: driver, reduceMotion: reduceMotion) {
            AlignedView(node: $0, model: model)
        }
    }
}

/// Flutter `Align`: the child at `alignment`, one of the nine names or a
/// mid-run `{x, y}`, in a box that fills what it is offered, or on an axis
/// with a factor is the child's size times it.
@MainActor
struct AlignedView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        AlignLayout(point: Props.unitPoint(node["alignment"]),
                    widthFactor: Props.number(node["widthFactor"]),
                    heightFactor: Props.number(node["heightFactor"])) {
            ChildView(node: node, model: model).environment(\.orcaTight, [])
        }
    }
}

/// Flutter `RenderPositionedBox`: CenterFactorLayout's sizes, with the child
/// at any point of the box and not only in the middle.
struct AlignLayout: Layout {
    var point: UnitPoint
    var widthFactor: CGFloat?
    var heightFactor: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let child = subviews.first?.sizeThatFits(proposal) ?? .zero
        return CGSize(width: side(child.width, widthFactor, proposal.width),
                      height: side(child.height, heightFactor, proposal.height))
    }

    private func side(_ child: CGFloat, _ factor: CGFloat?, _ offered: CGFloat?) -> CGFloat {
        let bound = offered.flatMap { $0.isFinite ? $0 : nil }
        guard let factor else { return bound ?? child }
        return min(child * factor, bound ?? .infinity)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        let size = child.sizeThatFits(proposal)
        child.place(at: CGPoint(x: bounds.minX + (bounds.width - size.width) * point.x,
                                y: bounds.minY + (bounds.height - size.height) * point.y),
                    anchor: .topLeading, proposal: ProposedViewSize(size))
    }
}

// MARK: AnimatedSwitcher

/// An AnimatedSwitcher's children while it is on screen. The child changed
/// when its node id changed: the new one fades in and every other one fades
/// out from where it is, linearly, a full fade taking `duration` ms. The
/// first child, a change under reduced motion and one with a duration of 0
/// show at once. The same id with new props is not a change.
@MainActor
final class SwitcherDriver: ObservableObject {
    /// One child to draw, the oldest first, and its opacity.
    struct Layer: Equatable, Identifiable {
        var id: String
        var opacity: Double
    }

    private struct Fade {
        var id: String
        var start: Double
        var from: Double
        var rising: Bool
        var span: Double

        func opacity(at now: Double) -> Double {
            let moved = max(0, now - start) / span
            return rising ? min(1, from + moved) : max(0, from - moved)
        }

        func ended(at now: Double) -> Bool {
            opacity(at: now) == (rising ? 1 : 0)
        }
    }

    private var fades: [Fade] = []
    private var current: String?
    private var started = false
    /// Whether the view needs another frame (see `ImplicitDriver.needsTick`).
    private(set) var needsTick = false

    @discardableResult
    func update(node: ResolvedNode, reduceMotion: Bool, at now: Double) -> Bool {
        update(childId: node.childIds.first, durationMs: AnimationDuration.milliseconds(node["duration"]),
               reduceMotion: reduceMotion, at: now)
    }

    /// The view was redrawn showing `childId`. Returns `needsTick`.
    @discardableResult
    func update(childId: String?, durationMs: Double, reduceMotion: Bool, at now: Double) -> Bool {
        defer {
            started = true
            current = childId
        }
        guard started, childId != current else {
            if !started { fades = rest(childId, at: now) }
            return needsTick
        }
        guard !reduceMotion, durationMs > 0 else {
            fades = rest(childId, at: now)
            needsTick = false
            return false
        }
        // Everyone turns round where they are; a child that comes back
        // rises again from there.
        var next: [Fade] = fades.compactMap { fade in
            let opacity = fade.opacity(at: now)
            guard opacity > 0 || fade.id == childId else { return nil }
            return Fade(id: fade.id, start: now, from: opacity, rising: fade.id == childId, span: durationMs)
        }
        if let childId, !next.contains(where: { $0.id == childId }) {
            next.append(Fade(id: childId, start: now, from: 0, rising: true, span: durationMs))
        }
        fades = next
        needsTick = true
        return true
    }

    private func rest(_ childId: String?, at now: Double) -> [Fade] {
        childId.map { [Fade(id: $0, start: now, from: 1, rising: true, span: 1)] } ?? []
    }

    /// The children to draw at `now`; one that has faded out is gone.
    func layers(at now: Double) -> [Layer] {
        fades.compactMap { fade in
            let opacity = fade.opacity(at: now)
            return fade.rising || opacity > 0 ? Layer(id: fade.id, opacity: opacity) : nil
        }
    }

    /// The frame tick: once every fade has ended, lets the view pause.
    func settle(at now: Double) {
        guard needsTick, fades.allSatisfy({ $0.ended(at: now) }) else { return }
        fades.removeAll { !$0.rising }
        needsTick = false
        objectWillChange.send()
    }
}

/// Flutter `AnimatedSwitcher` (`_buildAnimatedSwitcher`): `duration` only;
/// its default transition is a linear fade, the children stacked centred.
/// Unlike Flutter, which compares widget class and key, a new child is a new
/// node id.
///
/// A child fades out only while its node is still on the page: one that a
/// replace or a delete removed has nothing left to draw, so it goes at once
/// and the new one fades in.
@MainActor
struct AnimatedSwitcherView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @StateObject private var driver = SwitcherDriver()
    @OrcaReduceMotion private var reduceMotion

    var body: some View {
        let live = driver.update(node: node, reduceMotion: reduceMotion, at: model.frameClock())
        TimelineView(.animation(minimumInterval: nil, paused: !live)) { context in
            ZStack(alignment: .center) {
                ForEach(driver.layers(at: OrcaPageModel.milliseconds(context.date))) { layer in
                    NodeView(id: layer.id, model: model).opacity(layer.opacity)
                }
            }
            .onChange(of: context.date) { date in
                driver.settle(at: OrcaPageModel.milliseconds(date))
            }
        }
    }
}

// MARK: Hero

/// The tag of the nearest enclosing Hero, nil outside one: what a navigate
/// fired below a Hero records as the source of the flight.
private struct OrcaHeroTagKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var orcaHeroTag: String? {
        get { self[OrcaHeroTagKey.self] }
        set { self[OrcaHeroTagKey.self] = newValue }
    }
}

/// Flutter `Hero` (`_buildHero`): draws its child; with no `tag`, or an
/// empty one, it is the child alone. The flight between two pages is not
/// drawn here: the push is the route's own. The tag is on `tag(of:)` and,
/// for the widgets below, in `orcaHeroTag`.
@MainActor
struct HeroView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    /// The node's hero tag; nil when it has none or an empty one.
    static func tag(of node: ResolvedNode) -> String? {
        guard let tag = node["tag"]?.stringValue, !tag.isEmpty else { return nil }
        return tag
    }

    var body: some View {
        ChildView(node: node, model: model)
            .environment(\.orcaHeroTag, Self.tag(of: node))
    }
}
#endif
