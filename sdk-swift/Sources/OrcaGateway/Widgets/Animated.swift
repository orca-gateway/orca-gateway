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
/// when its node id changed: the new one fades in and the one it replaces
/// fades out from where it is, linearly, a full fade taking `duration` ms.
/// At most one child fades out: one still on its way out from an earlier
/// change is dropped (as the Kotlin twin), unless nothing replaces it (the
/// child before was none). The first child, a change under reduced motion
/// and one with a duration of 0 show at once. The same id with new props is
/// not a change.
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
    /// The current child's nodes, recorded as they are drawn: the view puts
    /// it in the environment of the current child (`orcaNodeRecorder`).
    let recorder = NodeRecorder()
    /// The child fading out, as an inert page of what was last drawn of it.
    private var frozen: [String: OrcaPageModel] = [:]
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
        // The child that leaves turns round where it is, and one that comes
        // back rises again from there; a child still going out from an
        // earlier change is dropped, unless no child took its place.
        let leaving = current ?? fades.first { !$0.rising }?.id
        var next: [Fade] = fades.compactMap { fade in
            guard fade.id == childId || fade.id == leaving else { return nil }
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

    /// The view was redrawn with `node` on `model`: the fades as above, and
    /// the frozen page. The current child's nodes are recorded as they are
    /// drawn (`recorder`, which also tells `enclosing`, the recorder of a
    /// switcher further out); when the child changes, the record of the one
    /// that left becomes its frozen page, which its layer is drawn from
    /// until its fade ends, and the record starts again for the new child.
    @discardableResult
    func update(node: ResolvedNode, in model: OrcaPageModel, enclosing: NodeRecorder? = nil,
                reduceMotion: Bool, at now: Double) -> Bool {
        let previous = current
        let childId = node.childIds.first
        let live = update(node: node, reduceMotion: reduceMotion, at: now)
        recorder.parent = enclosing
        if previous != childId {
            if let previous, let snapshot = recorder.snapshot(of: previous, state: model.store.state) {
                frozen[previous] = OrcaPageModel(snapshot: snapshot, of: model)
            }
            recorder.reset()
        }
        // A child that came back is the live one again; under reduced motion
        // or a duration of 0 nothing fades out, so nothing stays frozen.
        let fading = Set(fades.filter { !$0.rising }.map(\.id))
        frozen = frozen.filter { fading.contains($0.key) }
        return live
    }

    /// The frozen page a child on its way out is drawn from; nil for the
    /// current child, which is drawn from the live page.
    func outgoing(_ id: String) -> OrcaPageModel? {
        frozen[id]
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
        frozen.removeAll()
        needsTick = false
        objectWillChange.send()
    }
}

/// Flutter `AnimatedSwitcher` (`_buildAnimatedSwitcher`): `duration` only;
/// its default transition is a linear fade, the children stacked centred.
/// Unlike Flutter, which compares widget class and key, a new child is a new
/// node id.
///
/// A replace or a delete takes the old child's nodes off the page, so the
/// outgoing layer is drawn from the driver's frozen page of that child: its
/// nodes as each was last drawn, which the views below record as they draw
/// (`orcaNodeRecorder`), so a change only the child watches is in it. That
/// layer only draws: no hit testing, no actions, no animation ids, no
/// requests.
@MainActor
struct AnimatedSwitcherView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @StateObject private var driver = SwitcherDriver()
    @OrcaReduceMotion private var reduceMotion
    /// The recorder of a switcher further out, which this one's is told to.
    @Environment(\.orcaNodeRecorder) private var enclosing

    var body: some View {
        let live = driver.update(node: node, in: model, enclosing: enclosing,
                                 reduceMotion: reduceMotion, at: model.frameClock())
        TimelineView(.animation(minimumInterval: nil, paused: !live)) { context in
            ZStack(alignment: .center) {
                ForEach(driver.layers(at: OrcaPageModel.milliseconds(context.date))) { layer in
                    Group {
                        if let frozen = driver.outgoing(layer.id) {
                            NodeView(id: layer.id, model: frozen)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        } else {
                            NodeView(id: layer.id, model: model)
                                .environment(\.orcaNodeRecorder, driver.recorder)
                        }
                    }
                    .opacity(layer.opacity)
                }
            }
            .onChange(of: context.date) { date in
                driver.settle(at: OrcaPageModel.milliseconds(date))
            }
        }
    }
}

// MARK: Hero

/// The namespace the app's Heroes and zooming pages meet in, set by the
/// view that draws the router; nil for a page drawn outside `OrcaApp`.
private struct OrcaHeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var orcaHeroNamespace: Namespace.ID? {
        get { self[OrcaHeroNamespaceKey.self] }
        set { self[OrcaHeroNamespaceKey.self] = newValue }
    }
}

/// Flutter `Hero` (`_buildHero`): draws its child; with no `tag`, or an
/// empty one, it is the child alone. The tag is on `tag(of:)`; a widget
/// below finds it through `OrcaPageModel.heroTag(enclosing:)` when its
/// action fires, and the run's first `navigate` records it on the route it
/// pushes (`OrcaRouter.heroSource(of:)`).
///
/// The flight: on iOS 18 and up, inside `OrcaApp`, a Hero with a tag is the
/// source of the system's zoom transition (`HeroSource`: its page's route
/// and its tag), and the route pushed from it zooms out of it and back into
/// it (`HeroZoom`). The whole pushed page zooms, which is not Flutter's
/// flight of the one widget. Below iOS 18, on macOS and outside `OrcaApp`
/// nothing is marked and the push is the route's own.
@MainActor
struct HeroView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaHeroNamespace) private var namespace
    @Environment(\.orcaPage) private var page

    /// The node's hero tag; nil when it has none or an empty one.
    static func tag(of node: ResolvedNode) -> String? {
        guard let tag = node["tag"]?.stringValue, !tag.isEmpty else { return nil }
        return tag
    }

    /// What this Hero is the zoom source of; nil without a tag and outside
    /// `OrcaApp`.
    private var source: HeroSource? {
        guard let tag = Self.tag(of: node), let page else { return nil }
        return HeroSource(route: page.route.id, tag: tag)
    }

    var body: some View {
        ChildView(node: node, model: model)
            .modifier(HeroZoomSource(source: source, namespace: namespace))
    }
}

/// Marks a Hero as the view a pushed page zooms out of (iOS 18 and up);
/// the content alone everywhere else.
private struct HeroZoomSource: ViewModifier {
    let source: HeroSource?
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *), let source, let namespace {
            content.matchedTransitionSource(id: source, in: namespace)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// A pushed page that zooms out of the Hero it was pushed from, and back
/// into it when popped (iOS 18 and up; the system honours reduced motion).
/// With no `source`, and everywhere else, the content alone: the plain push.
struct HeroZoom: ViewModifier {
    let source: HeroSource?
    @Environment(\.orcaHeroNamespace) private var namespace

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *), let source, let namespace {
            content.navigationTransition(.zoom(sourceID: source, in: namespace))
        } else {
            content
        }
        #else
        content
        #endif
    }
}
#endif
