#if canImport(SwiftUI)
import Combine
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

/// Reduced motion for the SDK's animations: nil follows the system's
/// `accessibilityReduceMotion`, a value wins over it (the system key cannot
/// be set in a test). Read it through `@OrcaReduceMotion`.
private struct OrcaReduceMotionKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var orcaReduceMotion: Bool? {
        get { self[OrcaReduceMotionKey.self] }
        set { self[OrcaReduceMotionKey.self] = newValue }
    }
}

/// `@OrcaReduceMotion private var reduceMotion`: whether a view's animations
/// jump to their end state, the `reduceMotion` flag of the core's
/// controllers, implicit animations and transitions.
@propertyWrapper
struct OrcaReduceMotion: DynamicProperty {
    @Environment(\.orcaReduceMotion) private var override
    @Environment(\.accessibilityReduceMotion) private var system

    var wrappedValue: Bool { Self.resolve(override: override, system: system) }

    static func resolve(override: Bool?, system: Bool) -> Bool { override ?? system }
}

/// Flutter `OrcaAnimatedBuilder` (sdk/lib/src/builders/animated_builder_widget.dart):
/// a clock of `duration` ms shaped by `curve`, running once or, with
/// `repeat`, forever (back and forth with `reverse`). Every frame its
/// descendants are resolved again with the clock's value, so their `tween`
/// props move. `autoStart: false` holds it at 0 until an `animateForward`
/// names its `animationId`. `onComplete` fires each time a run reaches 1 or
/// reaches 0, never for a repeat cycle.
///
/// The clock is the core's `AnimationController`; the view only passes it
/// the frame's time, and frames are asked for only while a run is live.
@MainActor
struct AnimatedBuilderView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @StateObject private var driver: AnimatedBuilderDriver
    @OrcaReduceMotion private var reduceMotion

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        _driver = StateObject(wrappedValue: AnimatedBuilderDriver(model: model))
    }

    var body: some View {
        let live = driver.needsTick(at: model.frameClock())
        TimelineView(.animation(minimumInterval: nil, paused: !live)) { context in
            let now = OrcaPageModel.milliseconds(context.date)
            content
                .environment(\.orcaAnimationProgress, driver.progress(at: now))
                .onChange(of: context.date) { date in
                    driver.settle(at: OrcaPageModel.milliseconds(date))
                }
        }
        .onAppear { driver.appear(node: node, reduceMotion: reduceMotion, at: model.frameClock()) }
        .onDisappear { driver.disappear() }
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

    /// The controller's raw value `elapsed` seconds after the builder
    /// appeared (Flutter's `forward()` and `repeat(reverse:)`).
    static func clock(elapsed: Double, duration: Double, repeats: Bool,
                      reverse: Bool, autoStart: Bool) -> Double {
        var controller = AnimationController(durationMs: duration * 1000, repeats: repeats, reverses: reverse)
        if autoStart { controller.start(at: 0) }
        return controller.value(at: elapsed * 1000)
    }
}

/// One AnimatedBuilder's clock while it is on screen: a core
/// `AnimationController`, kept in the page's registry under the node's
/// `animationId` when it has one, so effects and targeted tweens reach it.
/// Every call takes "now" in milliseconds (`OrcaPageModel.milliseconds`):
/// the view passes its frame's date, tests pass numbers.
@MainActor
final class AnimatedBuilderDriver: ObservableObject {
    private let model: OrcaPageModel
    private let owner: AnimationRegistry.Owner
    private var node: ResolvedNode?
    private var id: String?
    /// The controller of a builder with no id, or one whose id a later
    /// builder took.
    private var local = AnimationController()
    private var wake: AnyCancellable?

    init(model: OrcaPageModel) {
        self.model = model
        self.owner = model.animations.makeOwner()
    }

    /// The builder came on screen (Flutter's `initState`): build the
    /// controller from the node's props, start it when `autoStart`, and
    /// register the id; the last builder to register an id owns it.
    func appear(node: ResolvedNode, reduceMotion: Bool, at now: Double) {
        self.node = node
        var controller = AnimationController(
            durationMs: AnimationDuration.milliseconds(node["duration"], default: 300),
            curve: node["curve"]?.stringValue,
            repeats: node["repeat"]?.boolValue ?? false,
            reverses: node["reverse"]?.boolValue ?? false,
            reduceMotion: reduceMotion)
        if node["autoStart"]?.boolValue ?? true { controller.start(at: now) }
        local = controller
        id = node["animationId"]?.stringValue
        if let id {
            model.animations.register(id: id, owner: owner, controller: controller)
            // An effect started a run on this id: the paused view has to ask
            // for frames again.
            wake = model.animationChanged.sink { [weak self] changed in
                guard let self, changed == self.id else { return }
                self.objectWillChange.send()
            }
        }
        objectWillChange.send()
    }

    /// The builder left the screen: its id goes, unless a later builder owns
    /// it by now.
    func disappear() {
        wake = nil
        guard let id else { return }
        if let own = model.animations.controller(id: id, owner: owner) { local = own }
        model.animations.unregister(id: id, owner: owner)
        self.id = nil
    }

    /// The registry's controller while this builder owns its id, else its own.
    private var controller: AnimationController {
        id.flatMap { model.animations.controller(id: $0, owner: owner) } ?? local
    }

    /// The value after the curve: what the builder's descendants resolve by.
    func progress(at now: Double) -> Double {
        controller.progress(at: now)
    }

    /// Whether the view needs another frame: a run is live, or one has ended
    /// and `settle` has not reported it yet.
    func needsTick(at now: Double) -> Bool {
        var probe = controller
        return probe.isRunning(at: now) || probe.takeCompletion(at: now)
    }

    /// The frame tick: fires `onComplete` when a run has reached 1 or
    /// reached 0 since the last tick, and lets the view pause. The returned
    /// task is the action's run; nil when nothing completed or the node has
    /// no `onComplete`.
    @discardableResult
    func settle(at now: Double) -> Task<Void, Never>? {
        let take: (inout AnimationController) -> Bool = { $0.takeCompletion(at: now) }
        let completed: Bool
        if let id, let owned = model.animations.update(id: id, owner: owner, take) {
            completed = owned
        } else {
            completed = take(&local)
        }
        guard completed, let node else { return nil }
        objectWillChange.send()
        return model.fire("onComplete", on: node)
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
