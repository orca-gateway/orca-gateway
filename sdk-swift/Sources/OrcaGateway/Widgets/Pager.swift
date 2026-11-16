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
/// has no scroll indicator and no pull to refresh. Known differences: a
/// drag stops at the first and last pages (iOS Flutter's bounces past
/// them), and a scroll view inside a page moving along the pager's axis
/// moves with it (Flutter's gesture arena gives the drag to one of them).
/// With `pageSnapping` false the pages are a free scroll view (FreePager).
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
/// - Let go, the release velocity and the finger's travel over the last
///   100 ms of the drag (VelocityTracker's window; no speed when the finger
///   was still for 40 ms) pick PageSnap's page, a fling only past both its
///   gates (speed and travel), and the pager settles there by Flutter's
///   ScrollSpringSimulation (PagerSpring), one sample a frame, ending
///   exactly on it.
/// - Each move goes through a ScrollObserver: begin, scrolling, end.
@MainActor
final class PagerFeed: ObservableObject {
    /// Flutter's kTouchSlop, in points.
    static let slop: Double = 18
    /// Flutter's kMaxFlingVelocity, points per second.
    static let maxFlingVelocity: Double = 8000

    @Published private(set) var page: Double

    private var extent: Double = 0
    private var count = 0
    private var vertical = false
    private var backwards = false
    private var fire: ([ScrollEvent]) -> Void = { _ in }

    private let observer = ScrollObserver()
    private var touch: Touch?
    private var settle: Task<Void, Never>?

    /// One touch: whether it is the pager's (nil until it passes the slop),
    /// the page and the finger along the axis where the drag started, its
    /// samples, and whether it stopped a settle.
    private struct Touch {
        var ours: Bool?
        var startPage: Double = 0
        var startFinger: Double = 0
        var samples: [(time: Date, finger: Double)] = []
        var held = false
    }

    init(page: Double = 0) {
        self.page = page
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
        if touch.ours == nil, max(abs(along), abs(across)) > Self.slop {
            touch.ours = abs(along) >= abs(across)
            touch.startPage = page
            touch.startFinger = along
            if touch.ours == true { fire(observer.observe(metrics, inProgress: true)) }
        }
        if touch.ours == true {
            touch.samples = touch.samples.filter { time.timeIntervalSince($0.time) <= 0.1 } + [(time, along)]
            let moved = (along - touch.startFinger) * (backwards ? 1 : -1)
            let offset = min(max(touch.startPage * extent + moved, 0), maxExtent)
            if offset != page * extent {
                page = offset / extent
                fire(observer.observe(metrics, inProgress: true))
            }
        }
        self.touch = touch
    }

    /// The finger has lifted.
    func ended(at time: Date) {
        guard let touch else { return }
        self.touch = nil
        if touch.ours == true {
            let release = Self.release(touch.samples, at: time)
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
        touch?.samples = []
        ended(at: Date())
    }

    private var maxExtent: Double { Double(max(count - 1, 0)) * extent }

    private var metrics: ScrollMetrics {
        ScrollMetrics(offset: page * extent, maxExtent: maxExtent, viewportDimension: extent)
    }

    /// The finger's speed along the axis in points per second over the
    /// velocity window, at most Flutter's kMaxFlingVelocity, and how far it
    /// travelled over it (newest minus oldest, Flutter's estimate offset).
    /// The window is VelocityTracker's: the samples of the last 100 ms back
    /// to a gap of more than 40 ms; none when the finger was still for
    /// 40 ms before `time`.
    private static func release(_ samples: [(time: Date, finger: Double)],
                                at time: Date) -> (velocity: Double, travel: Double) {
        guard let last = samples.last, time.timeIntervalSince(last.time) <= 0.04 else { return (0, 0) }
        var first = last
        for sample in samples.dropLast().reversed() {
            guard first.time.timeIntervalSince(sample.time) <= 0.04 else { break }
            first = sample
        }
        guard last.time > first.time else { return (0, 0) }
        let travel = last.finger - first.finger
        let speed = travel / last.time.timeIntervalSince(first.time)
        return (min(max(speed, -maxFlingVelocity), maxFlingVelocity), travel)
    }

    /// Stops a settle under way where it is, ending the scroll; whether one was.
    private func stopSettle() -> Bool {
        guard let settle else { return false }
        settle.cancel()
        self.settle = nil
        fire(observer.observe(metrics, inProgress: false))
        return true
    }

    /// Settles on PageSnap's page for the release `velocity` and `travel`
    /// (toward later pages), one spring sample a frame; the scroll ends there.
    private func settle(velocity: Double, travel: Double) {
        let start = page * extent
        let target = PageSnap.target(offset: start, viewportExtent: extent, velocity: velocity,
                                     travel: travel, pageCount: count)
        let end = Double(target ?? 0) * extent
        guard start != end else { return fire(observer.observe(metrics, inProgress: false)) }
        fire(observer.observe(metrics, inProgress: true))
        let spring = PagerSpring(start: start, end: end,
                                 velocity: PageSnap.flingVelocity(velocity, travel: travel))
        let began = Date()
        settle = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_666_667)
                guard let self, !Task.isCancelled, extent > 0 else { return }
                let time = Date().timeIntervalSince(began)
                let done = spring.done(time)
                page = spring.x(time) / extent
                if done { settle = nil }
                fire(observer.observe(metrics, inProgress: !done))
                if done { return }
            }
        }
    }
}

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
