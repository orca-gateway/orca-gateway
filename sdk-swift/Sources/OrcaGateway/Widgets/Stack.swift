#if canImport(SwiftUI)
import SwiftUI

/// Where a Positioned child sits in its Stack (Flutter `Positioned`).
struct PositionedSpec: Equatable {
    var top: CGFloat?
    var right: CGFloat?
    var bottom: CGFloat?
    var left: CGFloat?
    var width: CGFloat?
    var height: CGFloat?

    init(top: CGFloat? = nil, right: CGFloat? = nil, bottom: CGFloat? = nil, left: CGFloat? = nil,
         width: CGFloat? = nil, height: CGFloat? = nil) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
        self.width = width
        self.height = height
    }

    init(_ node: ResolvedNode) {
        self.init(top: Props.number(node["top"]), right: Props.number(node["right"]),
                  bottom: Props.number(node["bottom"]), left: Props.number(node["left"]),
                  width: Props.number(node["width"]), height: Props.number(node["height"]))
    }

    /// The width the Stack gives the child: both edges set it, else `width`.
    func width(in bounds: CGFloat) -> CGFloat? {
        if let left, let right { return max(bounds - left - right, 0) }
        return width
    }

    func height(in bounds: CGFloat) -> CGFloat? {
        if let top, let bottom { return max(bounds - top - bottom, 0) }
        return height
    }

    /// The child's leading edge: `left`, else from `right`, else by the
    /// Stack's alignment (Flutter `RenderStack.layoutPositionedChild`).
    func x(width: CGFloat, in bounds: CGFloat, alignment: CGFloat) -> CGFloat {
        if let left { return left }
        if let right { return bounds - right - width }
        return (bounds - width) * alignment
    }

    func y(height: CGFloat, in bounds: CGFloat, alignment: CGFloat) -> CGFloat {
        if let top { return top }
        if let bottom { return bounds - bottom - height }
        return (bounds - height) * alignment
    }
}

struct PositionedKey: LayoutValueKey {
    static let defaultValue: PositionedSpec? = nil
}

/// Flutter `RenderStack`. The Stack is as big as its largest ordinary child
/// (`fit: expand`: all the space offered), and as long as it is offered on
/// the axes its parent forces (`tight`); ordinary children are placed by
/// `alignment` (center by default, as the Flutter SDK parses it); Positioned
/// children by their edges, sized by both edges or their own width and
/// height. Later children draw on top. `fit: passthrough` (`passthrough`)
/// forces the ordinary children on the `tight` axes too and leaves them
/// loose on the others.
struct StackLayout: Layout {
    var alignment: UnitPoint
    var expand: Bool
    var tight: TightAxes = []
    var passthrough = false

    private func finite(_ value: CGFloat?) -> CGFloat? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let offered = (finite(proposal.width), finite(proposal.height))
        if expand, let width = offered.0, let height = offered.1 {
            return CGSize(width: width, height: height)
        }
        var size = CGSize.zero
        var sized = false
        for child in subviews where child[PositionedKey.self] == nil {
            let s = child.sizeThatFits(proposal)
            size.width = max(size.width, s.width)
            size.height = max(size.height, s.height)
            sized = true
        }
        // Only Positioned children: the Stack takes what it is offered.
        if !sized { size = CGSize(width: offered.0 ?? 0, height: offered.1 ?? 0) }
        if tight.contains(.horizontal), let width = offered.0 { size.width = width }
        if tight.contains(.vertical), let height = offered.1 { size.height = height }
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for child in subviews {
            if let spec = child[PositionedKey.self] {
                let fixedWidth = spec.width(in: bounds.width)
                let fixedHeight = spec.height(in: bounds.height)
                let measured = child.sizeThatFits(ProposedViewSize(width: fixedWidth, height: fixedHeight))
                let width = fixedWidth ?? measured.width
                let height = fixedHeight ?? measured.height
                let point = CGPoint(
                    x: bounds.minX + spec.x(width: width, in: bounds.width, alignment: alignment.x),
                    y: bounds.minY + spec.y(height: height, in: bounds.height, alignment: alignment.y))
                child.place(at: point, anchor: .topLeading, proposal: ProposedViewSize(width: width, height: height))
            } else {
                var size = expand ? bounds.size : child.sizeThatFits(ProposedViewSize(bounds.size))
                if passthrough, tight.contains(.horizontal) { size.width = bounds.width }
                if passthrough, tight.contains(.vertical) { size.height = bounds.height }
                let point = CGPoint(x: bounds.minX + (bounds.width - size.width) * alignment.x,
                                    y: bounds.minY + (bounds.height - size.height) * alignment.y)
                child.place(at: point, anchor: .topLeading, proposal: ProposedViewSize(size))
            }
        }
    }
}

/// Flutter `Stack`: fit, alignment, clipBehavior (no clip unless asked, as
/// the Flutter SDK parses it). `textDirection` is left to the system.
@MainActor
struct StackNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.orcaTight) private var tight

    var body: some View {
        let fit = node["fit"]?.stringValue
        StackLayout(alignment: Props.unitPoint(node["alignment"]), expand: fit == "expand",
                    tight: tight, passthrough: fit == "passthrough") {
            ForEach(node.childIds, id: \.self) { id in
                NodeView(id: id, model: model).layoutValue(key: PositionedKey.self, value: positioned(id))
            }
        }
        // loose (the default) loosens the ordinary children; passthrough
        // hands them the Stack's own tight axes (D9); expand tightens them
        // through the layout's proposal.
        .environment(\.orcaTight, fit == "passthrough" ? tight : [])
        .modifier(ClipIf(shape: Props.clips(node["clipBehavior"]) ? CornersShape(radii: .zero) : nil))
    }

    private func positioned(_ id: String) -> PositionedSpec? {
        guard model.renderer.node(id)?.type == "Positioned", let child = model.resolve(id) else { return nil }
        return PositionedSpec(child)
    }
}

/// Flutter `Positioned`: its child fills the width and height the Stack
/// gives it (both edges, or `width` / `height`), and takes its own size on
/// an axis left open. Outside a Stack it only draws its child.
@MainActor
struct PositionedView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let spec = PositionedSpec(node)
        let fillsWidth = spec.width != nil || (spec.left != nil && spec.right != nil)
        let fillsHeight = spec.height != nil || (spec.top != nil && spec.bottom != nil)
        ChildView(node: node, model: model)
            .environment(\.orcaTight, [fillsWidth ? .horizontal : [], fillsHeight ? .vertical : []])
            .frame(maxWidth: fillsWidth ? .infinity : nil, maxHeight: fillsHeight ? .infinity : nil,
                   alignment: .topLeading)
    }
}

/// Flutter `ClipRRect`: the child clipped to rounded corners. `borderRadius`
/// is a number or `{topLeft, topRight, bottomLeft, bottomRight}`; the
/// Flutter SDK reads only the number form.
@MainActor
struct ClipRRectView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .clipShape(CornersShape(radii: Props.radii(node["borderRadius"]) ?? .zero))
    }
}

/// Flutter `GestureDetector` as the SDK builds it: only the gestures the node
/// has actions for are attached (onTap, onDoubleTap, onLongPress), and then
/// the whole box takes touches, not just its drawn pixels
/// (`HitTestBehavior.opaque`). With none, it only draws its child.
@MainActor
struct GestureNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let tap = node.actions["onTap"] != nil
        let doubleTap = node.actions["onDoubleTap"] != nil
        let longPress = node.actions["onLongPress"] != nil
        if tap || doubleTap || longPress {
            ChildView(node: node, model: model)
                .contentShape(Rectangle())
                .modifier(Taps(
                    single: tap ? { model.fire("onTap", on: node) } : nil,
                    double: doubleTap ? { model.fire("onDoubleTap", on: node) } : nil))
                .modifier(LongPress(action: longPress ? { model.fire("onLongPress", on: node) } : nil))
                .accessibilityAddTraits(tap ? .isButton : [])
        } else {
            ChildView(node: node, model: model)
        }
    }
}

/// Flutter `InkWell` as the SDK's `_buildInkWell` builds it
/// (layout_builders.dart:615-634): Material's InkWell on a transparent
/// Material, its onTap, onLongPress and onDoubleTap always set, even for a
/// node without those actions, and no `enabled`. So it always takes the
/// touch over its whole box (HitTestBehavior.opaque; a GestureDetector
/// around it gets none). The long press and the tap are one gesture
/// (`gestures`), as Flutter's gesture arena decides between its
/// recognizers: a press held for Flutter's 500 ms, moving at most its 18 pt
/// touch slop, fires `onLongPress` and never a tap; a press lifted sooner is
/// a tap. The taps are sorted as Flutter's DoubleTapGestureRecognizer sorts
/// them (`InkTaps`, `DoubleTapResolver`): a tap is held, and fires `onTap`
/// once kDoubleTapTimeout, 300 ms, has passed since its lift with no second
/// tap; a second tap lifting within the 300 ms fires `onDoubleTap` instead,
/// and no tap. The gesture holds no drag (what takes a
/// ScrollView's pan from it on iOS 18), so a swipe that starts on the
/// InkWell is left to a ScrollView around it, as Flutter's scrollable wins
/// its arena once the touch moves past the slop: the long press needs
/// 500 ms held still and the taps end only on the lift.
///
/// The ink lies under the child, as Flutter paints it on the Material (an
/// opaque child hides it), clipped to `borderRadius` (a number, a circular
/// radius); the child is not clipped. The highlight is `highlightColor`,
/// ThemeData()'s #BCBCBC66 without one, fading in and out over Flutter's
/// 200 ms. Flutter turns it on in onTapDown, which, with a double tap and
/// a long press competing, fires at kPressTimeout, 100 ms after the touch
/// (tap.dart:212, :343), and keeps it on after the lift until the tap fires
/// once the 300 ms double-tap window ends, or until the long press cancels
/// it. iOS shows it while the finger is down (D6), as Kotlin documents for
/// its ripple: from the touch until the finger lifts, moves past the 18 pt
/// slop (where Flutter cancels the tap), or a ScrollView takes the touch;
/// it stays on through a long press. It is read by a gesture of its own
/// (`highlightGesture`), beside the triggers' gesture and simultaneous with
/// it: written by `.updating` on the triggers' long press, the iPhone fired
/// no tap at all (hand check 3). No ripple on iOS (D6): `splashColor` is
/// not read.
@MainActor
struct InkWellNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    /// What a tap fires; always attached, so never nil.
    let tap: PressGestures.Fire?
    /// What a double tap fires; always attached, so never nil.
    let doubleTap: PressGestures.Fire?
    /// What a long press fires; always attached, so never nil.
    let longPress: PressGestures.Fire?
    /// Whether a finger is down on the InkWell (`highlightGesture`), the
    /// highlight's: reset by SwiftUI on the lift, past the slop, or when a
    /// ScrollView takes the touch.
    @GestureState private var pressed = false
    /// The taps so far, waiting to be a tap or a double tap; kept with the
    /// view, so a tap held over a redraw still fires.
    @State private var taps = InkTaps()

    /// Flutter's pressed highlight fade, 200 ms (ink_well.dart:1036).
    static let highlightFade: Double = 0.2
    /// ThemeData()'s light `highlightColor` (theme_data.dart:595).
    static let themeHighlight = Props.color(hex: "#BCBCBC66")

    /// The InkWell's long press and tap as one gesture, exactly the FAB's
    /// (`PressGestures.exclusive`): first Flutter's long press (500 ms within
    /// 18 pt), then one tap, which can succeed only once the long press has
    /// failed. Nothing more goes in it: a count-2 tap nested in it lost the
    /// single taps on the iPhone (hand check 2), and `.updating` on its long
    /// press lost every tap (hand check 3), so double taps are `InkTaps`' to
    /// find and the highlight `highlightGesture`'s.
    static var gestures: ExclusiveGesture<LongPressGesture, TapGesture> {
        PressGestures.exclusive
    }

    /// The highlight's gesture: a long press that never succeeds, so it
    /// takes nothing from the triggers' gesture or a ScrollView, pressing
    /// from the touch and given up past Flutter's kTouchSlop, 18 pt; its
    /// pressing state written to `pressing`. It holds no drag: a
    /// `DragGesture` that starts at the touch (minimumDistance 0) can keep
    /// an iOS 18 ScrollView from scrolling.
    static func highlightGesture(pressing: GestureState<Bool>) -> GestureStateGesture<LongPressGesture, Bool> {
        LongPressGesture(minimumDuration: .infinity, maximumDistance: PressGestures.touchSlop)
            .updating(pressing) { current, state, _ in state = current }
    }

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        // Flutter's builder sets all three, whatever the node's actions.
        tap = PressGestures.fire("onTap", on: node, in: model, when: true)
        doubleTap = PressGestures.fire("onDoubleTap", on: node, in: model, when: true)
        longPress = PressGestures.fire("onLongPress", on: node, in: model, when: true)
    }

    var body: some View {
        face(pressed: pressed)
            .gesture(Self.gestures.onEnded { ended in
                switch ended {
                case .first: _ = longPress?()
                case .second: tapEnded()
                }
            })
            .simultaneousGesture(Self.highlightGesture(pressing: $pressed))
            .accessibilityAddTraits(.isButton)
    }

    /// A tap lifted now: `InkTaps` decides whether it is a tap, waiting out
    /// the double-tap window, or the second of a double tap.
    private func tapEnded() {
        taps.tapEnded(at: ProcessInfo.processInfo.systemUptime) { [tap, doubleTap] event in
            switch event {
            case .tap: _ = tap?()
            case .doubleTap: _ = doubleTap?()
            }
        }
    }

    /// The InkWell drawn `pressed` or at rest: its child over the ink, the
    /// whole box taking touches.
    func face(pressed: Bool) -> some View {
        let shape = CornersShape(radii: CornerRadii(all: Props.number(node["borderRadius"]) ?? 0))
        let highlight = Props.color(node["highlightColor"]) ?? Self.themeHighlight
        return ChildView(node: node, model: model)
            .background {
                ZStack {
                    Rectangle().hitFill()
                    shape.fill(highlight)
                        .opacity(pressed ? 1 : 0)
                        .animation(.linear(duration: Self.highlightFade), value: pressed)
                }
            }
            .contentShape(Rectangle())
    }
}

/// Flutter's DoubleTapGestureRecognizer beside the TapGestureRecognizer of
/// a widget that has both (an InkWell), as times in and events out: a tap
/// is held from its lift; a second tap lifting before kDoubleTapTimeout has
/// passed makes the two a double tap; a held tap whose window is over is a
/// tap. Flutter's window runs from the first lift to the second touch-down
/// (multitap.dart, `_registerFirstTap`, `_trackTap`); SwiftUI's TapGesture
/// reports only lifts, so here it runs to the second lift, a little
/// stricter. Nor is the second tap's place read (TapGesture has none):
/// Flutter's kDoubleTapSlop, 100 pt between the two, is not applied.
struct DoubleTapResolver {
    enum Event: Equatable {
        case tap
        case doubleTap
    }

    /// Flutter's kDoubleTapTimeout, 300 ms (gestures/constants.dart:35).
    static let timeout: TimeInterval = 0.3

    /// When the held tap lifted; nil when no tap is held.
    private(set) var held: TimeInterval?

    /// When the held tap's window is over and it is a tap; nil when none.
    var deadline: TimeInterval? { held.map { $0 + Self.timeout } }

    /// A tap lifted at `time`. Within a held tap's window it is the second
    /// of a double tap; else (a held tap whose window is over is a tap
    /// first) it is held.
    mutating func tapEnded(at time: TimeInterval) -> [Event] {
        var events = advance(to: time)
        if held == nil {
            held = time
        } else {
            held = nil
            events.append(.doubleTap)
        }
        return events
    }

    /// The clock reached `time`: a held tap whose window is over is a tap.
    mutating func advance(to time: TimeInterval) -> [Event] {
        guard let deadline, time >= deadline else { return [] }
        held = nil
        return [.tap]
    }
}

/// An InkWell's taps as they come: each lift goes to its
/// `DoubleTapResolver`, and while a tap is held a wait fires it once its
/// window is over, unless a second tap lifts first.
@MainActor
final class InkTaps {
    private var resolver = DoubleTapResolver()
    /// The wait for the held tap's window to end; nil when none is held.
    private(set) var wait: Task<Void, Never>?

    /// A tap lifted at `time` (seconds of `systemUptime`): `fire` gets what
    /// it makes, now or once the window is over.
    func tapEnded(at time: TimeInterval, fire: @escaping @MainActor (DoubleTapResolver.Event) -> Void) {
        wait?.cancel()
        wait = nil
        resolver.tapEnded(at: time).forEach(fire)
        guard let deadline = resolver.deadline else { return }
        wait = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((deadline - time) * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.wait = nil
            self.resolver.advance(to: deadline).forEach(fire)
        }
    }
}

/// Only the tap gestures that have actions. With both, the double tap is
/// attached first, so a single tap fires once the double tap has failed
/// (Flutter waits the same way, `kDoubleTapTimeout`); without a double tap,
/// a single tap fires at once.
private struct Taps: ViewModifier {
    let single: (() -> Void)?
    let double: (() -> Void)?

    func body(content: Content) -> some View {
        switch (single, double) {
        case let (single?, double?):
            content.onTapGesture(count: 2, perform: double).onTapGesture(perform: single)
        case let (single?, nil):
            content.onTapGesture(perform: single)
        case let (nil, double?):
            content.onTapGesture(count: 2, perform: double)
        case (nil, nil):
            content
        }
    }
}

private struct LongPress: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.simultaneousGesture(LongPressGesture().onEnded { _ in action() })
        } else {
            content
        }
    }
}
#endif
