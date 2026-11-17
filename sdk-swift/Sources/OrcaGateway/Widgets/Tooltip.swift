#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import AudioToolbox
import UIKit
import UIKit.UIGestureRecognizerSubclass
#endif

// MARK: - The widget

/// Flutter's Tooltip builder (layout_builders.dart:583-586): MUI
/// `Tooltip(message, child)`, every other prop at its default. The child is
/// drawn as it is; with a message a long press on it shows the bubble
/// (`TooltipTrigger`), beside the child's own gestures. An empty or missing
/// message draws the child alone (MUI tooltip.dart:499-501).
@MainActor
struct TooltipNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    /// Its long press, its frame for the bubble and its message for VoiceOver.
    var trigger: TooltipTrigger {
        TooltipTrigger(key: OrcaTooltips.Key(model, node.id), message: Props.text(node["message"]), press: .beside)
    }

    var body: some View {
        ChildView(node: node, model: model).modifier(trigger)
    }
}

/// MUI's Tooltip around what it wraps, taking touches as RawTooltip does
/// (widgets/raw_tooltip.dart:672-700, :735-767): a long press of
/// `PressGestures.longPressDuration` within its slop shows the bubble
/// (`OrcaTooltips.press`), which the app's `OrcaTooltips` keeps while the
/// finger is down and takes away after it lifts or at any other touch. The
/// wrapped view's frame in the window is kept there for the bubble's place.
/// VoiceOver reads the wrapped view's label, then the message
/// (`TooltipSemantics`). With no message, or an empty one, nothing is added,
/// and a button keeps its own gestures.
struct TooltipTrigger: ViewModifier {
    /// How the bubble's long press meets the gestures of what it wraps.
    enum Press {
        /// Beside them: the Tooltip widget around any child. Its long press
        /// covers the child's whole box (the opaque Listener,
        /// raw_tooltip.dart:958-962), is simultaneous with the child's
        /// gestures and takes nothing from them (SwiftUI has no gesture arena
        /// to win; a known difference: a child's own long press, or a tap
        /// held past 500 ms, also fires).
        case beside
        /// In a button's `PressGestures`, its long press slot. An IconButton
        /// (`bubbleFirst` false) keeps a long press of its own: Flutter's
        /// GestureDetector inside the Tooltip joins the arena first and its
        /// timer ends first, so it wins and no bubble shows; without one the
        /// bubble takes the hold and the tap fires nothing
        /// (button_builders.dart:136-159). The FAB (`bubbleFirst`): its
        /// Tooltip is inside the GestureDetector carrying onLongPress
        /// (button_builders.dart:216-219, floating_action_button.dart:623),
        /// so the bubble wins and onLongPress never fires.
        case button(tap: PressGestures.Fire?, longPress: PressGestures.Fire?, bubbleFirst: Bool)
    }

    let key: OrcaTooltips.Key
    let message: String?
    let press: Press
    @Environment(\.orcaTooltips) private var tooltips
    @Environment(\.layoutDirection) private var direction

    /// There is a message to show: given and not empty.
    var shows: Bool { !(message ?? "").isEmpty }

    /// A button's gestures, `bubble` in the long press slot where the bubble
    /// takes the hold; nil for the Tooltip widget.
    func pressGestures(bubble: @escaping PressGestures.Fire) -> PressGestures? {
        guard case let .button(tap, longPress, bubbleFirst) = press else { return nil }
        guard shows else { return PressGestures(tap: tap, longPress: longPress) }
        return PressGestures(tap: tap, longPress: bubbleFirst ? bubble : longPress ?? bubble)
    }

    func body(content: Content) -> some View {
        if let message, !message.isEmpty {
            let show: PressGestures.Fire = { [tooltips, key, direction] in
                tooltips?.press(key, message: message, direction: direction)
                return nil
            }
            gestures(content.modifier(TooltipAnchor(key: key, tooltips: tooltips)), show: show)
                .modifier(TooltipSemantics(message: message))
        } else {
            gestures(content, show: { nil })
        }
    }

    @ViewBuilder
    private func gestures<V: View>(_ view: V, show: @escaping PressGestures.Fire) -> some View {
        if let gestures = pressGestures(bubble: show) {
            view.modifier(gestures)
        } else if shows {
            view.contentShape(Rectangle())
                .simultaneousGesture(PressGestures.longPressGesture.onEnded { _ in _ = show() })
        } else {
            view
        }
    }
}

/// Keeps the wrapped view's frame in the window with `tooltips` while it is
/// on screen, and takes it away, with its bubble, when the view goes
/// (RawTooltip disposed: its overlay child goes with it). A view coming back
/// (a page uncovered by a pop) puts its last frame back.
private struct TooltipAnchor: ViewModifier {
    let key: OrcaTooltips.Key
    let tooltips: OrcaTooltips?
    @State private var anchor = Anchor()

    /// This view's token, so a view of the same key going later leaves it,
    /// and its last frame; changing either redraws nothing.
    private final class Anchor {
        let token = UUID()
        var frame: CGRect?
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                anchor.frame = frame
                tooltips?.place(key, at: frame, by: anchor.token)
            }
            .onAppear {
                if let frame = anchor.frame { tooltips?.place(key, at: frame, by: anchor.token) }
            }
            .onDisappear { tooltips?.remove(key, by: anchor.token) }
    }
}

/// The message for VoiceOver as Flutter's semantics tooltip reads on iOS:
/// after the label of what it wraps (`Semantics(tooltip:)`,
/// raw_tooltip.dart:949-952; the engine's SemanticsObject.mm:583-596 joins
/// them with a line break, SwiftUI with a comma), what it wraps made one
/// element. The message is a clear element over it, so the element is there
/// also when nothing it wraps is read (an IconButton's icon), labelled with
/// the message alone. Not the iOS 18 label placeholder: it lays out a second
/// copy of the view off screen, whose frame reaches the anchor.
private struct TooltipSemantics: ViewModifier {
    let message: String

    func body(content: Content) -> some View {
        content
            .overlay { Color.clear.accessibilityElement().accessibilityLabel(Text(message)) }
            .accessibilityElement(children: .combine)
    }
}

/// Keeps the space of the view it is on, the page `model`'s Overlay, with
/// the app's tooltips while it is on screen: what `DialogLayer` lies in, the
/// Navigator the page's sheets go on. Flutter's bubble goes in the Overlay
/// nearest its Tooltip (OverlayPortal's default, raw_tooltip.dart:965-969;
/// overlay.dart:1941-1945), the one of the page's Navigator: the window over
/// the single stack, the tab's area above the tab bar under tabs (the
/// branch Navigator of StatefulShellRoute.indexedStack,
/// navigation_handler.dart:92).
///
/// A view coming back (a tab switched to again) puts its last frame back,
/// as `TooltipAnchor` does.
struct TooltipOverlayArea: ViewModifier {
    let model: OrcaPageModel
    @Environment(\.orcaTooltips) private var tooltips
    @State private var area = Area()

    /// This view's token, so a view of the same page going later leaves it,
    /// and its last frame; changing either redraws nothing.
    private final class Area {
        let token = UUID()
        var frame: CGRect?
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                area.frame = frame
                tooltips?.place(overlay: ObjectIdentifier(model), at: frame, by: area.token)
            }
            .onAppear {
                guard let frame = area.frame else { return }
                tooltips?.place(overlay: ObjectIdentifier(model), at: frame, by: area.token)
            }
            .onDisappear { tooltips?.remove(overlay: ObjectIdentifier(model), by: area.token) }
    }
}

// MARK: - The bubbles

/// The tooltip bubbles on screen, one set for the app (OrcaApp's) or for a
/// page shown on its own: what each Flutter RawTooltip's controller and
/// timer do (raw_tooltip.dart:552-767). A long press shows a bubble
/// (`press`) that fades in over `TooltipPlacement.fadeInMs`, with Flutter's
/// long-press feedback when it was not on screen. It stays while the finger
/// is down and starts to fade out `showDurationMs` after it lifts
/// (`touchUp`), over `fadeOutMs`, both through fastOutSlowIn. Any other
/// touch going down fades it out at once (`touchDown`, RawTooltip's global
/// pointer route); a touch on its own child does so only as it lifts with no
/// new long press (the child's recognizer, onLongPressCancel). Where no
/// touch is seen (macOS) the 1.5 s run from the press. A bubble shown sends
/// the one before away.
///
/// Time is `clock`'s. Each change first brings the bubbles up to it, and
/// `sleep` wakes them when the next fade starts or ends. Tests set `clock`,
/// set `sleep` to nil and pass time in with `tick()`.
@MainActor
final class OrcaTooltips: ObservableObject {
    /// A tooltipped node of a page.
    struct Key: Hashable {
        let model: ObjectIdentifier
        let node: String

        init(model: ObjectIdentifier, node: String) {
            self.model = model
            self.node = node
        }

        init(_ model: OrcaPageModel, _ node: String) {
            self.init(model: ObjectIdentifier(model), node: node)
        }
    }

    /// A bubble's fade: the controller runs linearly from `from` to `to`, a
    /// whole way in `fadeInMs` forward and `fadeOutMs` back (AnimationController
    /// forward and reverse from where it stands), the opacity through
    /// fastOutSlowIn both ways (CurvedAnimation, no reverse curve). Time in ms.
    struct Fade: Equatable {
        var from: Double
        var to: Double
        var start: Double

        private var wholeMs: Double {
            Double(to > from ? TooltipPlacement.fadeInMs : TooltipPlacement.fadeOutMs)
        }

        /// When it stands at `to`.
        var end: Double { start + abs(to - from) * wholeMs }

        func controller(at now: Double) -> Double {
            let travelled = max(0, now - start) / wholeMs
            guard travelled < abs(to - from) else { return to }
            return to > from ? from + travelled : from - travelled
        }

        func opacity(at now: Double) -> Double {
            Curves.apply("fastOutSlowIn", controller(at: now))
        }
    }

    struct Bubble: Identifiable, Equatable {
        let id: Int
        let key: Key
        var message: String
        var direction: LayoutDirection
        var fade: Fade
        /// When its fade out starts; nil while held, or once leaving.
        var hideAt: Double?

        var isLeaving: Bool { fade.to == 0 }

        mutating func leave(at now: Double) {
            fade = Fade(from: fade.controller(at: now), to: 0, start: now)
            hideAt = nil
        }
    }

    @Published private(set) var bubbles: [Bubble] = []
    /// Each tooltipped view's frame in SwiftUI's global space, kept as it moves.
    private(set) var frames: [Key: CGRect] = [:]
    private var owners: [Key: UUID] = [:]
    /// Each page's Overlay in the global space, by page model: where its
    /// bubbles are placed and clipped (`TooltipOverlayArea`). A page with
    /// none uses the host layer's whole space.
    private(set) var areas: [ObjectIdentifier: CGRect] = [:]
    private var areaOwners: [ObjectIdentifier: UUID] = [:]
    /// The host layer's origin in the global space; touches come in its own.
    var origin: CGPoint = .zero
    /// Now, in ms, on the scale of `OrcaPageModel.milliseconds(_:)`.
    var clock: () -> Double = { OrcaPageModel.milliseconds(Date()) }
    /// Waits the given ms, until the next fade starts or ends; nil: nothing
    /// wakes the bubbles but `tick()`.
    var sleep: ((Double) async -> Void)? = { ms in
        try? await Task.sleep(nanoseconds: UInt64(max(ms, 1) * 1_000_000))
    }
    /// Flutter's Feedback.forLongPress on iOS: the click system sound and a
    /// heavy impact (widgets/feedback.dart:136-146; the engine plays sound
    /// 1306, FlutterPlatformPlugin.mm:27, :251-255, :271-272). Tests put
    /// their own here.
    static var feedback: @MainActor () -> Void = {
        #if canImport(UIKit)
        AudioServicesPlaySystemSound(1306)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }
    /// A touch is down (from the window's touch watch).
    private var touching = false
    /// The touch down lies on the shown bubble's own child and its long press
    /// has not come.
    private var onOwnChild = false
    private var nextId = 0
    private var wake: Task<Void, Never>?

    /// A bubble's opacity is changing at `clock()`.
    var isFading: Bool {
        let now = clock()
        return bubbles.contains { $0.fade.controller(at: now) != $0.fade.to }
    }

    /// The view of `key` lies at `frame` (global); `token` is that view's.
    func place(_ key: Key, at frame: CGRect, by token: UUID) {
        owners[key] = token
        guard frames[key] != frame else { return }
        frames[key] = frame
        if bubbles.contains(where: { $0.key == key }) { objectWillChange.send() }
    }

    /// The Overlay of the page `model` lies at `frame` (global); `token` is
    /// the view's that measured it.
    func place(overlay model: ObjectIdentifier, at frame: CGRect, by token: UUID) {
        areaOwners[model] = token
        guard areas[model] != frame else { return }
        areas[model] = frame
        if bubbles.contains(where: { $0.key.model == model }) { objectWillChange.send() }
    }

    /// The view that measured the Overlay of `model` went, unless a newer
    /// one holds it.
    func remove(overlay model: ObjectIdentifier, by token: UUID) {
        guard areaOwners[model] == token else { return }
        areaOwners[model] = nil
        areas[model] = nil
        if bubbles.contains(where: { $0.key.model == model }) { objectWillChange.send() }
    }

    /// The view of `key` went: its frame and its bubble go, unless a newer
    /// view holds the key.
    func remove(_ key: Key, by token: UUID) {
        guard owners[key] == token else { return }
        owners[key] = nil
        frames[key] = nil
        if bubbles.contains(where: { $0.key == key }) { bubbles.removeAll { $0.key == key } }
        schedule()
    }

    /// A long press on the view of `key` (RawTooltip `_handleLongPress`):
    /// its bubble fades in from where it stands, felt when it was not on
    /// screen; held while a touch is down, else (none seen) timed at once.
    func press(_ key: Key, message: String, direction: LayoutDirection) {
        let now = clock()
        var next = advanced(to: now)
        onOwnChild = false
        for index in next.indices where next[index].key != key && !next[index].isLeaving {
            next[index].leave(at: now)
        }
        let hideAt = touching ? nil : now + Double(TooltipPlacement.showDurationMs)
        if let index = next.lastIndex(where: { $0.key == key }) {
            next[index].message = message
            next[index].direction = direction
            next[index].fade = Fade(from: next[index].fade.controller(at: now), to: 1, start: now)
            next[index].hideAt = hideAt
        } else {
            Self.feedback()
            next.append(Bubble(id: nextId, key: key, message: message, direction: direction,
                               fade: Fade(from: 0, to: 1, start: now), hideAt: hideAt))
            nextId += 1
        }
        bubbles = next
        schedule()
    }

    /// A touch went down at `point`, in the host layer's space: the shown
    /// bubble fades out at once, unless the touch is on its own child.
    func touchDown(at point: CGPoint) {
        touching = true
        let now = clock()
        var next = advanced(to: now)
        if let index = next.firstIndex(where: { !$0.isLeaving }) {
            let global = CGPoint(x: point.x + origin.x, y: point.y + origin.y)
            if frames[next[index].key]?.contains(global) == true {
                onOwnChild = true
            } else {
                next[index].leave(at: now)
            }
        }
        update(next)
    }

    /// The last touch lifted: a held bubble goes `showDurationMs` from now
    /// (RawTooltip `_handlePressUp`); one whose own child was tapped, at once.
    func touchUp() {
        touching = false
        let now = clock()
        var next = advanced(to: now)
        if let index = next.firstIndex(where: { !$0.isLeaving }) {
            if onOwnChild {
                next[index].leave(at: now)
            } else if next[index].hideAt == nil {
                next[index].hideAt = now + Double(TooltipPlacement.showDurationMs)
            }
        }
        onOwnChild = false
        update(next)
    }

    /// Bring the bubbles up to `clock()`, then set the next wake.
    func tick() {
        update(advanced(to: clock()))
        // A fade that ended changes no bubble: the layer pauses its frames.
        objectWillChange.send()
    }

    /// The bubbles at `now`: the fades due by then started, those faded out
    /// gone.
    private func advanced(to now: Double) -> [Bubble] {
        var next = bubbles
        for index in next.indices {
            if let hideAt = next[index].hideAt, hideAt <= now { next[index].leave(at: hideAt) }
        }
        next.removeAll { $0.isLeaving && $0.fade.controller(at: now) == 0 }
        return next
    }

    private func update(_ next: [Bubble]) {
        if next != bubbles { bubbles = next }
        schedule()
    }

    /// Wake when the next fade starts or ends; none when nothing is due.
    private func schedule() {
        wake?.cancel()
        wake = nil
        let now = clock()
        let due = bubbles.flatMap { bubble -> [Double] in
            [bubble.hideAt, bubble.fade.end > now ? bubble.fade.end : nil].compactMap { $0 }
        }.min()
        guard let sleep, let due else { return }
        wake = Task { [weak self] in
            await sleep(max(due - now, 0))
            guard !Task.isCancelled else { return }
            self?.tick()
        }
    }
}

/// The bubbles of `tooltips` over all below it, edge to edge, taking no
/// touch. OrcaApp lays it over the stacks, their sheets and bars, the tab
/// bar and the drawer; a page shown on its own, over itself. Each bubble is
/// placed by `TooltipPlacement` around its child in its page's Overlay
/// (`OrcaTooltips.areas`, else this whole space) less the part the keyboard
/// covers (raw_tooltip.dart:896-897), measured with that space as its most
/// (`constraints.loosen()`, :993), clipped to the Overlay (Overlay clips,
/// Clip.hardEdge) and faded by its `Fade`. Flutter paints it in that Overlay
/// right after the route it is in (overlay.dart:1831-1836): over the page,
/// its AppBar and a sheet it is in; under tabs, in the tab's area above the
/// tab bar. VoiceOver reads its text while it shows, as Flutter's, which no
/// ExcludeSemantics hides (raw_tooltip.dart:887-893).
/// Along the bottom edge lies, on iOS, the keyboard's reader
/// (`KeyboardOverlap`); along the top, what sees the window's touches
/// (`WindowWatcher`).
@MainActor
struct TooltipHostLayer: View {
    @ObservedObject var tooltips: OrcaTooltips
    /// How much of this layer the keyboard covers, from the bottom.
    @State private var keyboard: CGFloat = 0

    var body: some View {
        GeometryReader { area in
            let origin = area.frame(in: .global).origin
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: nil, paused: !tooltips.isFading)) { _ in
                    bubbles(in: area.size, origin: origin, keyboardTop: area.size.height - keyboard)
                }
                #if canImport(UIKit)
                // With no height: nothing for ImageRenderer to draw a
                // placeholder for. Built in this closure, so a walk of the
                // view values never reaches them.
                WindowWatcher(tooltips: tooltips).frame(width: area.size.width, height: 0)
                KeyboardOverlap(opens: 0) { keyboard = $0 }
                    .frame(width: area.size.width, height: 0)
                    .frame(width: area.size.width, height: area.size.height, alignment: .bottomLeading)
                #endif
            }
            .onAppear { tooltips.origin = origin }
            .onChange(of: origin) { tooltips.origin = $0 }
        }
        .allowsHitTesting(false)
    }

    /// `keyboardTop`: in this layer's space.
    private func bubbles(in size: CGSize, origin: CGPoint, keyboardTop: CGFloat) -> some View {
        let now = tooltips.clock()
        return ZStack(alignment: .topLeading) {
            ForEach(tooltips.bubbles) { bubble in
                if let child = tooltips.frames[bubble.key] {
                    let overlay = (tooltips.areas[bubble.key.model] ?? CGRect(origin: origin, size: size))
                        .offsetBy(dx: -origin.x, dy: -origin.y)
                    let free = max(min(overlay.maxY, keyboardTop) - overlay.minY, 0)
                    BubblePlacement(child: child.offsetBy(dx: -origin.x - overlay.minX, dy: -origin.y - overlay.minY)) {
                        TooltipBubble(message: bubble.message)
                            .environment(\.layoutDirection, bubble.direction)
                    }
                    .frame(width: max(overlay.width, 0), height: free, alignment: .topLeading)
                    .frame(width: max(overlay.width, 0), height: max(overlay.height, 0), alignment: .topLeading)
                    .clipped()
                    .offset(x: overlay.minX, y: overlay.minY)
                    .opacity(bubble.fade.opacity(at: now))
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        // Frames are absolute: no mirroring of the places.
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// One bubble in the overlay it fills, sized as Flutter's Text in it: its
/// own width when the message fits on one line, else the overlay's (a
/// wrapping Text takes the whole width, TextWidthBasis.parent), and placed
/// where `TooltipPlacement` says for `child`.
private struct BubblePlacement: Layout {
    let child: CGRect

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for bubble in subviews {
            let ideal = bubble.sizeThatFits(.unspecified)
            let width = min(ideal.width, bounds.width)
            let height = min(ideal.width <= bounds.width ? ideal.height
                : bubble.sizeThatFits(ProposedViewSize(width: width, height: nil)).height, bounds.height)
            let origin = TooltipPlacement.origin(
                child: .init(x: child.minX, y: child.minY, width: child.width, height: child.height),
                bubble: .init(width: width, height: height),
                overlay: .init(width: bounds.width, height: bounds.height))
            bubble.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), anchor: .topLeading,
                         proposal: ProposedViewSize(width: width, height: height))
        }
    }
}

/// The bubble MUI's Tooltip draws on a phone under the light ThemeData()
/// (tooltip.dart:450-465, :503-534; _TooltipBox :595-627): grey[700] at 0.9
/// (#616161, alpha 0xE6), corners 4, the message in bodyMedium white 14
/// (line height 1.43, letter spacing 0.25, typography_defaults_m3.g.dart
/// :142-151), start aligned, 16 in from the sides and 4 from the top and
/// bottom, at least 32 tall with the text centred in it. As wide as the
/// width offered: its placement offers its own (`BubblePlacement`).
struct TooltipBubble: View {
    let message: String

    static let fill = Props.color(hex: "#616161E6")
    static let textStyle = TextStyleProps(.object([
        "color": "#FFFFFF", "fontSize": 14, "letterSpacing": 0.25, "height": 1.43,
    ]))

    var body: some View {
        let style = Self.textStyle
        let extra = style.extraLeading
        style.styledText(message)
            .lineSpacing(max(extra, 0))
            .padding(.vertical, extra / 2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(minHeight: 32)
            .background(RoundedRectangle(cornerRadius: 4).fill(Self.fill))
    }
}

#if canImport(UIKit)
/// Every touch of the host layer's window, going down
/// (`OrcaTooltips.touchDown`, in the layer's space) and the last one lifting
/// (`touchUp`): RawTooltip's global pointer route and its recognizer's press
/// up (raw_tooltip.dart:706-733, :762-767). It lies along the layer's top
/// edge with no height, takes no touch and is not an accessibility element;
/// the touches come from `TouchWatch` on the window.
private struct WindowWatcher: UIViewRepresentable {
    let tooltips: OrcaTooltips

    func makeUIView(context: Context) -> Watcher {
        let watcher = Watcher()
        updateUIView(watcher, context: context)
        return watcher
    }

    func updateUIView(_ watcher: Watcher, context: Context) {
        watcher.tooltips = tooltips
    }

    final class Watcher: UIView {
        weak var tooltips: OrcaTooltips?
        private let touches = TouchWatch()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            touches.down = { [weak self] point in
                guard let self else { return }
                self.tooltips?.touchDown(at: self.convert(point, from: nil))
            }
            touches.up = { [weak self] in self?.tooltips?.touchUp() }
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            touches.view?.removeGestureRecognizer(touches)
            window?.addGestureRecognizer(touches)
        }
    }
}

/// Sees every touch of the window it is on and takes none: it never leaves
/// `.possible` while a touch is down, prevents no other recognizer and is
/// prevented by none, cancels and delays nothing, and fails as the last
/// touch lifts. `down` gets each touch going down, in window coordinates;
/// `up`, the last one lifting or cancelled.
final class TouchWatch: UIGestureRecognizer {
    var down: @MainActor (CGPoint) -> Void = { _ in }
    var up: @MainActor () -> Void = {}

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { down(touch.location(in: nil)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        ended(event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        ended(event)
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    private func ended(_ event: UIEvent) {
        let live = (event.allTouches ?? []).contains { $0.phase != .ended && $0.phase != .cancelled }
        guard !live else { return }
        up()
        state = .failed
    }
}
#endif

private struct OrcaTooltipsKey: EnvironmentKey {
    static let defaultValue: OrcaTooltips? = nil
}

extension EnvironmentValues {
    /// The bubbles a Tooltip below shows its own in: the app's, or a page's
    /// shown on its own; nil: none is drawn.
    var orcaTooltips: OrcaTooltips? {
        get { self[OrcaTooltipsKey.self] }
        set { self[OrcaTooltipsKey.self] = newValue }
    }
}
#endif
