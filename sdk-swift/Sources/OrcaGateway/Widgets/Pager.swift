#if canImport(SwiftUI)
import SwiftUI

/// Flutter `PageView` (layout_builders.dart:668-684): horizontal unless
/// `scrollDirection` is "vertical", `pageSnapping` true, `reverse` false, no
/// controller (page 0 first, each page the viewport's size, forced on both
/// axes), wrapped in the scroll notifier, so onScrollBegin, onScrolling and
/// onScrollEnd fire with the offset and viewportDimension. The axis runs
/// backwards under `reverse` and, when horizontal, in right-to-left
/// (page_view.dart `_getDirection`).
///
/// Snapping, iOS 16 has no paging ScrollView, so the pager is drawn here:
/// only the pages in sight are built (Flutter's cache of 0 viewports), a
/// drag (PagerFeed) follows the finger and, let go, settles on the core's
/// PageSnap page with Flutter's scroll spring. It is no scroll view, so it
/// has no scroll indicator and no pull to refresh. Inside a scroll view, a
/// drag along the pager's axis is the pager's alone and one across it the
/// scroll view's (PagerHold, iOS), as Flutter's arena decides. Known
/// differences: a drag stops at the first and last pages (iOS Flutter's
/// bounces past them), and a scroll view inside a page moving along the
/// pager's axis moves with it (Flutter's gesture arena gives the drag to
/// one of them). With `pageSnapping` false the pages are a free scroll view
/// (FreePager).
@MainActor
struct PagerView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @StateObject private var feed: PagerFeed
    @Environment(\.layoutDirection) private var direction
    @GestureState private var touching = false

    /// `feed` is where it stands and what moves it (a new one at page 0, as
    /// Flutter's; a given one only in tests).
    init(node: ResolvedNode, model: OrcaPageModel, feed: PagerFeed? = nil) {
        self.node = node
        self.model = model
        _feed = StateObject(wrappedValue: feed ?? PagerFeed())
    }

    var body: some View {
        if Props.bool(node["pageSnapping"]) == false {
            FreePager(node: node, model: model)
        } else {
            snapping
        }
    }

    private var snapping: some View {
        let vertical = node["scrollDirection"]?.stringValue == "vertical"
        let backwards = (Props.bool(node["reverse"]) == true) != (!vertical && direction == .rightToLeft)
        let ids = node.childIds
        let fire: ([ScrollEvent]) -> Void = { [model, node] events in
            for event in events { model.fire(event.trigger, on: node, eventData: event.eventData) }
        }
        return GeometryReader { geometry in
            let size = geometry.size
            let extent = vertical ? size.height : size.width
            let _ = feed.update(extent: extent, count: ids.count, vertical: vertical, backwards: backwards, fire: fire)
            ZStack(alignment: .topLeading) {
                #if canImport(UIKit)
                PagerHoldPlace(vertical: vertical, size: size).frame(width: 0, height: 0)
                #endif
                ForEach(PagerFeed.built(page: feed.page, count: ids.count).map { ids[$0] }, id: \.self) { id in
                    let index = Double(ids.firstIndex(of: id) ?? 0)
                    let shift = (index - feed.page) * extent * (backwards ? -1 : 1)
                    NodeView(id: id, model: model)
                        .environment(\.layoutDirection, direction)
                        .modifier(AddTight(axes: [.horizontal, .vertical]))
                        .frame(width: size.width, height: size.height, alignment: .topLeading)
                        .offset(x: vertical ? 0 : shift, y: vertical ? shift : 0)
                }
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { feed.changed($0.translation, at: $0.time) }
            .onEnded { feed.ended(at: $0.time) })
        // A drag cancelled (no onEnded) settles from where it is, as Flutter's.
        .onChange(of: touching) { active in if !active { feed.released() } }
        // A new tree with fewer pages brings the pager back within them.
        .onChange(of: ids.count) { count in feed.keepWithinPages(count: count) }
        // Laid out and dragged left to right; right-to-left is `backwards`,
        // each page back in the ambient direction.
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// `pageSnapping` false: Flutter's PageView with its platform's own scroll
/// physics, a scroll view of viewport-sized pages, lazy, reversed as
/// SingleChildScrollView is (the pages in reverse order, the view starting
/// at the far end), with the scroll triggers of ScrollTriggers.
@MainActor
private struct FreePager: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let vertical = node["scrollDirection"]?.stringValue == "vertical"
        let reverse = Props.bool(node["reverse"]) == true
        GeometryReader { geometry in
            if node.actions.keys.contains(where: ScrollEvent.triggers.contains) {
                let triggers = ScrollTriggers(node: node, model: model, horizontal: !vertical, reverse: reverse,
                                              phased: Self.phased)
                if triggers.phased {
                    scrollView(vertical, reverse) { pages(geometry.size, vertical, reverse) }.modifier(triggers)
                } else {
                    scrollView(vertical, reverse) { ScrollTriggers.probe(pages(geometry.size, vertical, reverse)) }
                        .modifier(triggers)
                }
            } else {
                scrollView(vertical, reverse) { pages(geometry.size, vertical, reverse) }
            }
        }
    }

    @ViewBuilder
    private func scrollView<Content: View>(_ vertical: Bool, _ reverse: Bool,
                                           @ViewBuilder content: () -> Content) -> some View {
        let axis: Axis.Set = vertical ? .vertical : .horizontal
        let end: UnitPoint = vertical ? .bottom : .trailing
        let content = content()
        if !reverse {
            ScrollView(axis) { content }
        } else if #available(iOS 17, macOS 14, *) {
            ScrollView(axis) { content }.defaultScrollAnchor(end)
        } else {
            ScrollViewReader { proxy in
                ScrollView(axis) { content.id(node.id) }
                    .onAppear { proxy.scrollTo(node.id, anchor: end) }
            }
        }
    }

    @ViewBuilder
    private func pages(_ size: CGSize, _ vertical: Bool, _ reverse: Bool) -> some View {
        let ids = reverse ? Array(node.childIds.reversed()) : node.childIds
        let pages = ForEach(ids, id: \.self) { id in
            NodeView(id: id, model: model)
                .modifier(AddTight(axes: [.horizontal, .vertical]))
                .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        if vertical {
            LazyVStack(spacing: 0) { pages }
        } else {
            LazyHStack(spacing: 0) { pages }
        }
    }

    /// The scroll phase is there (iOS 18, macOS 15) and in use, as for
    /// SingleChildScrollView.
    private static var phased: Bool {
        guard ScrollNodeView.usesScrollPhase else { return false }
        if #available(iOS 18, macOS 15, *) { return true }
        return false
    }
}

/// A snapping pager's position and the drag that moves it, Flutter's
/// PageView scroll position under PageScrollPhysics, fed by SwiftUI's
/// DragGesture (`changed`, `ended`, `released`).
///
/// - `page` is the position in pages; page × extent is Flutter's offset,
///   counted toward later pages whichever way the axis is drawn.
/// - A touch stops a settle where it is (Flutter's hold ends the scroll).
/// - A drag is the pager's once it passes `slop` along the axis before
///   across it; one that passes it across first is left to its end, for a
///   scroll view inside (Flutter's gesture arena). It follows the finger
///   from there (DragStartBehavior.start), kept within the pages, and
///   begins the scroll.
/// - Every position of the touch from touch-down goes to the core's
///   IOSFlingTracker, Flutter's iOS tracker (its recognizer feeds the
///   tracker from the pointer down; Android's windowed VelocityTracker is
///   Kotlin's). Let go, its velocity and travel pick PageSnap's page, a
///   fling only past both gates (speed and travel), and the pager settles
///   there by Flutter's ScrollSpringSimulation (PagerSpring), one sample a
///   frame, ending exactly on it; a new extent, or none, ends a settle on
///   its page at once.
/// - Fewer pages (a new tree) bring a pager past the last back to it
///   (`keepWithinPages`, outside the view's body), stopping a settle aimed
///   past it.
/// - Each move goes through a ScrollObserver: begin, scrolling, end.
@MainActor
final class PagerFeed: ObservableObject {
    /// Flutter's kTouchSlop, in points.
    static let slop: Double = 18

    @Published private(set) var page: Double

    private var extent: Double = 0
    private var count = 0
    private var vertical = false
    private var backwards = false
    private var fire: ([ScrollEvent]) -> Void = { _ in }

    private let observer = ScrollObserver()
    private var touch: Touch?
    private var settle: Task<Void, Never>?
    /// The page a settle under way ends on.
    private var settleTarget: Int?

    /// One touch: whether it is the pager's (nil until it passes the slop),
    /// the page and the finger along the axis where the drag started, its
    /// positions along the axis from touch-down, and whether it stopped a
    /// settle.
    private struct Touch {
        var ours: Bool?
        var startPage: Double = 0
        var startFinger: Double = 0
        var tracker = PageSnap.IOSFlingTracker()
        var held = false
    }

    init(page: Double = 0) {
        self.page = page
    }

    /// Whether a drag the finger has moved `along` and `across` the axis
    /// since touch-down is the pager's: nil within the slop, then whether
    /// it went further along than across.
    static func claims(along: Double, across: Double) -> Bool? {
        max(abs(along), abs(across)) > slop ? abs(along) >= abs(across) : nil
    }

    /// The pages built at `page`: the one in sight, two between pages.
    static func built(page: Double, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let first = min(max(Int(page.rounded(.down)), 0), count - 1)
        let last = min(max(Int(page.rounded(.up)), 0), count - 1)
        return Array(first...last)
    }

    /// What the view is as it draws: the viewport's extent on the axis, the
    /// page count, the axis and its direction, and how to fire a trigger.
    func update(extent: Double, count: Int, vertical: Bool, backwards: Bool,
                fire: @escaping ([ScrollEvent]) -> Void) {
        self.extent = extent
        self.count = count
        self.vertical = vertical
        self.backwards = backwards
        self.fire = fire
    }

    /// The finger has moved by `translation` since it touched.
    func changed(_ translation: CGSize, at time: Date) {
        guard extent > 0, count > 0 else { return }
        var touch = self.touch ?? Touch(held: stopSettle())
        let along = Double(vertical ? translation.height : translation.width)
        let across = Double(vertical ? translation.width : translation.height)
        touch.tracker.add(time: time.timeIntervalSinceReferenceDate, position: along)
        if touch.ours == nil, let ours = Self.claims(along: along, across: across) {
            touch.ours = ours
            touch.startPage = page
            touch.startFinger = along
            if touch.ours == true { fire(observer.observe(metrics, inProgress: true)) }
        }
        if touch.ours == true {
            let moved = (along - touch.startFinger) * (backwards ? 1 : -1)
            let offset = min(max(touch.startPage * extent + moved, 0), maxExtent)
            if offset != page * extent {
                page = offset / extent
                fire(observer.observe(metrics, inProgress: true))
            }
        }
        self.touch = touch
    }

    /// The page count is now `count` (a new tree, this pager kept): past
    /// the last page, the pager comes back to it without a scroll (Flutter
    /// keeps the offset within the new extent); a settle aimed past it
    /// stops there and ends the scroll.
    func keepWithinPages(count: Int) {
        self.count = count
        let last = Double(max(count - 1, 0))
        if let target = settleTarget, Double(target) > last {
            settle?.cancel()
            settle = nil
            settleTarget = nil
            page = min(page, last)
            fire(observer.observe(metrics, inProgress: false))
        } else if page > last {
            page = last
        }
    }

    /// The finger has lifted.
    func ended(at time: Date) {
        guard let touch else { return }
        self.touch = nil
        if touch.ours == true {
            let release = touch.tracker.estimate(now: time.timeIntervalSinceReferenceDate)
            let sign: Double = backwards ? 1 : -1
            settle(velocity: release.velocity * sign, travel: release.travel * sign)
        } else if touch.held {
            settle(velocity: 0, travel: 0)
        }
    }

    /// The touch is over, ended or cancelled: a cancelled one settles from
    /// where it is (Flutter's `cancel` goes ballistic at 0).
    func released() {
        guard touch != nil else { return }
        touch?.tracker = PageSnap.IOSFlingTracker()
        ended(at: Date())
    }

    private var maxExtent: Double { Double(max(count - 1, 0)) * extent }

    private var metrics: ScrollMetrics {
        ScrollMetrics(offset: page * extent, maxExtent: maxExtent, viewportDimension: extent)
    }

    /// Stops a settle under way where it is, ending the scroll; whether one was.
    private func stopSettle() -> Bool {
        guard let settle else { return false }
        settle.cancel()
        self.settle = nil
        settleTarget = nil
        fire(observer.observe(metrics, inProgress: false))
        return true
    }

    /// Settles on PageSnap's page for the release `velocity` and `travel`
    /// (toward later pages), one spring sample a frame; the scroll ends
    /// there, at once when the extent changes (or goes) on the way.
    private func settle(velocity: Double, travel: Double) {
        let start = page * extent
        guard let target = PageSnap.target(offset: start, viewportExtent: extent, velocity: velocity,
                                           travel: travel, pageCount: count),
              start != Double(target) * extent
        else { return fire(observer.observe(metrics, inProgress: false)) }
        fire(observer.observe(metrics, inProgress: true))
        let spring = PagerSpring(start: start, end: Double(target) * extent,
                                 velocity: PageSnap.flingVelocity(velocity, travel: travel))
        let began = Date(), laidOut = extent
        settleTarget = target
        settle = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_666_667)
                guard let self, !Task.isCancelled else { return }
                let time = Date().timeIntervalSince(began)
                let resized = extent != laidOut
                let done = resized || spring.done(time)
                page = resized ? Double(target) : spring.x(time) / extent
                if done {
                    settle = nil
                    settleTarget = nil
                }
                fire(observer.observe(metrics, inProgress: !done))
                if done { return }
            }
        }
    }
}

#if canImport(UIKit)
/// Where a snapping pager is in UIKit: a 0-size view at its top leading
/// corner (ImageRenderer would draw a placeholder for a bigger one) that
/// holds the pager's PagerHold.
private struct PagerHoldPlace: UIViewRepresentable {
    let vertical: Bool
    let size: CGSize

    func makeUIView(context: Context) -> PagerHoldAnchor { PagerHoldAnchor() }

    func updateUIView(_ anchor: PagerHoldAnchor, context: Context) {
        anchor.vertical = vertical
        anchor.size = size
    }
}

/// A snapping pager's corner in UIKit, which takes no touch: while in a
/// window it puts the pager's PagerHold on the nearest UIScrollView around
/// it (the touches on the pager go through that one) and takes it off
/// when it leaves.
private final class PagerHoldAnchor: UIView {
    var vertical = false
    var size: CGSize = .zero
    private var hold: PagerHold?

    /// The pager, in this view's space.
    var pager: CGRect { CGRect(origin: .zero, size: size) }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        place()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        place()
    }

    private func place() {
        var around = window == nil ? nil : superview
        while let view = around, !(view is UIScrollView) { around = view.superview }
        let scroll = around as? UIScrollView
        guard hold?.view !== scroll else { return }
        if let hold { hold.view?.removeGestureRecognizer(hold) }
        hold = scroll.map { scroll in
            let hold = PagerHold(anchor: self)
            scroll.addGestureRecognizer(hold)
            return hold
        }
    }
}

/// Keeps a drag along a snapping pager's axis from the scroll views around
/// it, as Flutter's gesture arena gives it to the deepest drag recognizer,
/// the pager's. The pager's DragGesture is simultaneous, so that a drag
/// across the axis reaches a scroll view around it or inside a page; a
/// UIScrollView around it would scroll with a drag along it too. The pan
/// of every scroll view around the pager waits on the hold, which fails at
/// once for a touch that starts off the pager; for one on it, once the
/// finger passes the slop, it begins when along the axis (PagerFeed.claims,
/// the feed's own rule), so those pans fail, and fails when across. It
/// cancels and delays no touch and recognises alongside every gesture, so
/// the pager's DragGesture follows the whole drag.
private final class PagerHold: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private weak var anchor: PagerHoldAnchor?
    private var touch: UITouch?
    private var start: CGPoint = .zero

    init(anchor: PagerHoldAnchor) {
        self.anchor = anchor
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touch == nil else { return }
        guard let anchor, let first = touches.first, anchor.pager.contains(first.location(in: anchor)) else {
            state = .failed
            return
        }
        touch = first
        start = first.location(in: anchor)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch), let anchor else { return }
        if state == .possible {
            let point = touch.location(in: anchor)
            let along = anchor.vertical ? point.y - start.y : point.x - start.x
            let across = anchor.vertical ? point.x - start.x : point.y - start.y
            if let ours = PagerFeed.claims(along: along, across: across) { state = ours ? .began : .failed }
        } else if state == .began || state == .changed {
            state = .changed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch) else { return }
        state = state == .began || state == .changed ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch, touches.contains(touch) else { return }
        state = state == .began || state == .changed ? .cancelled : .failed
    }

    override func reset() {
        super.reset()
        touch = nil
    }

    func gestureRecognizer(_ hold: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    /// The pan of a scroll view around the pager waits on the hold.
    func gestureRecognizer(_ hold: UIGestureRecognizer,
                           shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        guard let anchor, let scroll = other.view as? UIScrollView else { return false }
        return other === scroll.panGestureRecognizer && anchor.isDescendant(of: scroll)
    }
}
#endif

/// Flutter's ScrollSpringSimulation (physics/spring_simulation.dart) with
/// ScrollPhysics' default spring, mass 0.5, stiffness 100, damping ratio
/// 1.1 (scroll_physics.dart:434-438), overdamped: from `start` to `end`
/// with `velocity` in points per second, exactly `end` once within
/// Flutter's tolerance for a 3x screen (1/3 point, 20/3 points per second).
struct PagerSpring {
    private let end: Double
    private let r1: Double, r2: Double, c1: Double, c2: Double

    init(start: Double, end: Double, velocity: Double) {
        let mass = 0.5, stiffness = 100.0
        let damping = 1.1 * 2 * (mass * stiffness).squareRoot()
        let root = (damping * damping - 4 * mass * stiffness).squareRoot()
        r1 = (-damping - root) / (2 * mass)
        r2 = (-damping + root) / (2 * mass)
        let distance = start - end
        c2 = (velocity - r1 * distance) / (r2 - r1)
        c1 = distance - c2
        self.end = end
    }

    func x(_ time: Double) -> Double {
        done(time) ? end : end + c1 * exp(r1 * time) + c2 * exp(r2 * time)
    }

    func done(_ time: Double) -> Bool {
        abs(c1 * exp(r1 * time) + c2 * exp(r2 * time)) < 1.0 / 3
            && abs(c1 * r1 * exp(r1 * time) + c2 * r2 * exp(r2 * time)) < 20.0 / 3
    }
}
#endif
