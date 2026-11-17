#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Motion

/// One sheet's route animation, Flutter's ModalBottomSheetRoute (material
/// bottom_sheet.dart): its controller runs linearly from `from` to `to`, a
/// whole way in 250 ms in and 200 ms out (:29-30), and the panel shows
/// `value` of its height: the controller through Easing.legacyDecelerate,
/// Cubic(0, 0, 0.2, 1), both ways (:31, :695-699;
/// motion_defaults_m3.g.dart:210). After a drag the rest runs through
/// Split(`split`, legacyDecelerate) (:751-766): linear below the point of
/// release, the curve over what is left above it. Time is in ms.
struct SheetMotion: Equatable {
    static let enterMs = 250.0
    static let exitMs = 200.0

    var from: Double
    var to: Double
    var start: Double
    var split: Double?

    init(from: Double, to: Double, start: Double, split: Double? = nil) {
        self.from = from
        self.to = to
        self.start = start
        self.split = split
    }

    /// The route animation's value at `now`, 0 (out) ... 1 (in).
    func controller(at now: Double) -> Double {
        let span = abs(to - from)
        let travelled = max(0, now - start) / (to > from ? Self.enterMs : Self.exitMs)
        guard travelled < span else { return to }
        return to > from ? from + travelled : from - travelled
    }

    /// The share of the panel's height that shows at `now`.
    func value(at now: Double) -> Double {
        let progress = controller(at: now)
        guard let split else { return Self.legacyDecelerate(progress) }
        if progress <= split { return progress }
        return split + (1 - split) * Self.legacyDecelerate((progress - split) / (1 - split))
    }

    func isDone(at now: Double) -> Bool { controller(at: now) == to }

    /// The barrier's opacity: black54 (0x8A of black, Colors.black54,
    /// bottom_sheet.dart:1123) through Curves.ease of the route animation
    /// (routes.dart:1869, :2303-2310; bottom_sheet.dart:1193-1203).
    static func barrierOpacity(controller: Double) -> Double {
        0x8A / 255 * Curves.apply("ease", controller)
    }

    /// Flutter's `Cubic(0, 0, 0.2, 1).transform`: bisection until x is
    /// within 0.001 of `t`, then y there (curves.dart, `Cubic`).
    static func legacyDecelerate(_ t: Double) -> Double {
        if !(t > 0) { return 0 }
        if t >= 1 { return 1 }
        func cubic(_ a: Double, _ b: Double, _ m: Double) -> Double {
            3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m
        }
        var start = 0.0, end = 1.0, midpoint = 0.5
        for _ in 0..<64 {
            midpoint = (start + end) / 2
            let estimate = cubic(0, 0.2, midpoint)
            if abs(t - estimate) < 0.001 { break }
            if estimate < t { start = midpoint } else { end = midpoint }
        }
        return cubic(0, 1, midpoint)
    }
}

/// What a release of a dragged panel decides, Flutter's
/// `_BottomSheetState._handleDragEnd` (bottom_sheet.dart:299-327): a fling
/// down faster than 700 closes it (:32, :305-311); else it closes when the
/// route animation stands below 0.5, the panel dragged past half its height
/// (:33, :312-316); else it slides back.
enum SheetRelease {
    static let minFlingVelocity = 700.0
    static let closeProgressThreshold = 0.5
    /// How far a touch moves before the drag starts and the panel follows
    /// (kTouchSlop, gestures/constants.dart; DragStartBehavior.start).
    static let touchSlop: CGFloat = 18

    /// `controller`: the route animation at the release; `velocity`: down
    /// is positive, in points a second, nil where SwiftUI gives none.
    static func dismisses(controller: Double, velocity: Double?) -> Bool {
        if let velocity, velocity > minFlingVelocity { return true }
        return controller < closeProgressThreshold
    }
}

// MARK: - The page's sheets

/// The sheets openDialog has opened on one page and their motion: D4's
/// `DialogStack` kept live, the Swift side of the modal routes Flutter's
/// openDialog pushes on the page's Navigator (orca_page.dart:323-374) and
/// closeDialog pops (action_executor.dart:894-919). `DialogLayer` draws
/// `entries`, the open sheets and those still sliding out.
///
/// `open` returns only once its sheet has closed (the handler awaits
/// showModalBottomSheet, orca_page.dart:346; the route's future completes
/// as it is popped, navigator.dart:459-462, :481-483), so the next action of
/// a Sequential waits. A close takes the top sheet only; with none open it
/// does nothing. `closeAll` (the page torn down) ends every wait.
///
/// Each open takes input focus from what had it, so a page's field gives
/// up its keyboard (the route's FocusScope takes focus, routes.dart; it is
/// not given back on close, a known difference): `opens` counts them and
/// the layer ends editing in its window at each. VoiceOver: an open sends
/// focus into the sheet (a screen change), a close back to the element
/// focused when it opened (a layout change to it).
@MainActor
final class OrcaDialogs: ObservableObject {
    /// One sheet on screen: open, or sliding out once closed.
    struct Entry: Identifiable, Equatable {
        let sheet: DialogStack.Sheet
        var motion: SheetMotion
        var id: Int { sheet.id }
        var isClosing: Bool { motion.to == 0 }
    }

    /// The open sheets, the bottom one first.
    @Published private(set) var stack = DialogStack()
    /// The sheets to draw, the bottom one first: open, or sliding out.
    @Published private(set) var entries: [Entry] = []
    /// Now, in ms, on the scale of `OrcaPageModel.milliseconds(_:)`. Tests
    /// set it and call `tick()`.
    var clock: () -> Double = { OrcaPageModel.milliseconds(Date()) }
    /// False where nothing draws sheets (the shell's trees): openDialog
    /// opens nothing and does not wait, as Flutter's shell executor, which
    /// has no onOpenDialog (action_executor.dart:862-871).
    var isDrawn = true
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]

    #if canImport(UIKit)
    /// The element VoiceOver had focused as each sheet opened, by sheet id.
    private var openers: [Int: Any] = [:]
    /// The element VoiceOver has focused. Tests put their own here.
    static var focusedElement: () -> Any? = { UIAccessibility.focusedElement(using: .notificationVoiceOver) }
    /// Posts a notification to VoiceOver. Tests put their own here.
    static var post: (UIAccessibility.Notification, Any?) -> Void = {
        UIAccessibility.post(notification: $0, argument: $1)
    }
    #endif
    /// How many sheets have opened, ever.
    @Published private(set) var opens = 0

    /// A sheet's motion is not over by `clock()`.
    var isMoving: Bool {
        let now = clock()
        return entries.contains { !$0.motion.isDone(at: now) }
    }

    /// The top sheet as drawn; nil with none open.
    var top: Entry? {
        guard let id = stack.top?.id else { return nil }
        return entries.last { $0.id == id }
    }

    /// openDialog: a sheet of the Dialog `dialogId` of `nodes` slides in on
    /// top, and this returns once it has closed. An id the page lacks or a
    /// Dialog with no child on the page opens nothing and returns at once.
    func open(dialogId: String, heightFactor: Double?, nodes: [String: ComponentNode]) async {
        guard isDrawn else { return }
        prune()
        guard let sheet = stack.open(dialogId: dialogId, heightFactor: heightFactor, nodes: nodes) else { return }
        entries.append(Entry(sheet: sheet, motion: SheetMotion(from: 0, to: 1, start: clock())))
        opens += 1
        focusIn(sheet)
        await withCheckedContinuation { waiters[sheet.id] = $0 }
    }

    /// closeDialog: the top sheet slides out; none open, nothing happens.
    func close() {
        leave(dragged: nil)
    }

    /// A barrier tap, the Scrim's activation, VoiceOver's escape: the top
    /// sheet goes, whatever the Dialog's `dismissible` says.
    func dismiss() {
        leave(dragged: nil)
    }

    /// The top panel was let go with the route animation at `controller`:
    /// it closes from there, or slides back in from there.
    func release(controller: Double, velocity: Double?) {
        guard let id = top?.id, let index = entries.firstIndex(where: { $0.id == id }) else { return }
        if SheetRelease.dismisses(controller: controller, velocity: velocity) {
            leave(dragged: controller)
        } else {
            entries[index].motion = SheetMotion(from: controller, to: 1, start: clock(), split: controller)
        }
    }

    /// The page is gone: every sheet goes at once and every wait ends.
    func closeAll() {
        var closed: [DialogStack.Sheet] = []
        while let sheet = stack.close() { closed.append(sheet) }
        if !entries.isEmpty { entries.removeAll() }
        for sheet in closed {
            waiters.removeValue(forKey: sheet.id)?.resume()
            #if canImport(UIKit)
            openers[sheet.id] = nil
            #endif
        }
    }

    /// Forget the sheets that have slid out by `clock()`.
    func prune() {
        let now = clock()
        if entries.contains(where: { $0.isClosing && $0.motion.isDone(at: now) }) {
            entries.removeAll { $0.isClosing && $0.motion.isDone(at: now) }
        }
    }

    /// Draw again at `clock()` (tests, after moving the clock).
    func tick() {
        objectWillChange.send()
    }

    /// The top sheet leaves from where it stands (`dragged`: the route
    /// animation where a drag let it go), and its opener's wait ends.
    private func leave(dragged: Double?) {
        guard let sheet = stack.close() else { return }
        let now = clock()
        if let index = entries.firstIndex(where: { $0.id == sheet.id }) {
            let motion = entries[index].motion
            entries[index].motion = SheetMotion(from: dragged ?? motion.controller(at: now), to: 0, start: now,
                                                split: dragged ?? motion.split)
        }
        waiters.removeValue(forKey: sheet.id)?.resume()
        focusBack(sheet)
    }

    private func focusIn(_ sheet: DialogStack.Sheet) {
        #if canImport(UIKit)
        // The layer sends VoiceOver in once the panel is drawn.
        if let focused = Self.focusedElement() { openers[sheet.id] = focused }
        #endif
    }

    private func focusBack(_ sheet: DialogStack.Sheet) {
        #if canImport(UIKit)
        Self.post(.layoutChanged, openers.removeValue(forKey: sheet.id))
        #endif
    }
}

// MARK: - Drawing

private struct DialogsDrawnKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// A layer over the NavigationStack draws the sheets of the page on top
    /// (`RouteDialogLayer`); an OrcaPageView with none above draws its own.
    var orcaDialogsDrawn: Bool {
        get { self[DialogsDrawnKey.self] }
        set { self[DialogsDrawnKey.self] = newValue }
    }
}

/// The sheets of the page a route's loader holds, once it has loaded: what
/// lies over a NavigationStack, drawn for the route on its top.
@MainActor
struct RouteDialogLayer: View {
    @ObservedObject var loader: OrcaPageLoader

    var body: some View {
        if case .loaded(let model) = loader.phase {
            DialogLayer(model: model)
        }
    }
}

/// A page's open sheets over the space it is given, Flutter's
/// showModalBottomSheet as orca_page.dart:346-371 calls it: each sheet a
/// barrier black54 over the whole space, then its panel, bottom to top. The
/// panel is `heightFactor` of the whole height, from the bottom edge (no
/// safe area: useSafeArea false, bottom_sheet.dart:1181-1183), loose in
/// width up to 640 and centred (Align bottomCenter > ConstrainedBox, :417-421;
/// the M3 maximum, bottom_sheet_defaults_m3.g.dart:18; the layout's
/// constraints, :618-625), so as wide as its content: white with top corners
/// 24, clipped (orca_page.dart:358-369), the Dialog's first child drawn in it
/// with the page's stores and executor, so a state change redraws inside.
///
/// The top sheet's barrier takes every touch (ModalBarrier, expand and
/// opaque, modal_barrier.dart:243-245, :437), so a tap closes it and the
/// page's edge swipe back never starts. A drag down moves the panel with the
/// finger (the route animation, linear) and the barrier with it; its release
/// decides (`SheetRelease`). A sheet sliding out takes no touch
/// (routes.dart:2277-2280).
///
/// VoiceOver, as Flutter's sheet reads on iOS: the panel's content, with no
/// name of its own (the route's label is empty there, bottom_sheet.dart
/// :726-728), then one element "Scrim" over the space above the panel (the
/// barrier's semantics clipped to it, :734-736, modal_barrier.dart:255-257)
/// whose activation closes the top sheet (bottom_sheet.dart:1356,
/// material_localizations.dart:1137; the panel before the barrier,
/// routes.dart:2282-2284), in one modal container: the page below is out of
/// reach (the barrier's BlockSemantics, modal_barrier.dart:259-264); its
/// escape gesture closes the top sheet (the barrier's semantics dismiss,
/// :236). Sheets below the top are hidden from it.
///
/// Beyond Flutter (the user's call, a known difference): with the keyboard
/// up the panels rise by the part of the keyboard over this space, their
/// height kept; Flutter's keyboard covers a modal sheet. The layer takes its
/// whole space from the page's first frame, so its keyboard reader is there
/// before any sheet opens.
///
/// Its space is the page's Overlay, Flutter's nearest one (the Navigator the
/// sheets go on): the tooltip bubbles of the page are placed in it
/// (`TooltipOverlayArea`).
@MainActor
struct DialogLayer: View {
    let model: OrcaPageModel
    @ObservedObject private var dialogs: OrcaDialogs
    /// How far the top panel is dragged down past the slop; nil: no drag.
    @State private var drag: CGFloat?
    /// The top sheet's route animation when the drag began.
    @State private var dragBase = 1.0
    /// No motion is under way: frames are not asked for. A paused timeline
    /// does not draw again for a change of state, so whatever moves the
    /// panels (the clock, a drag, the keyboard) clears it.
    @State private var settled = false
    /// How much of this space the keyboard covers, from the bottom.
    @State private var keyboard: CGFloat = 0

    init(model: OrcaPageModel) {
        self.model = model
        _dialogs = ObservedObject(wrappedValue: model.dialogs)
    }

    var body: some View {
        // Read here, not only in the timeline: a change must draw again.
        let lift = keyboard
        ZStack {
            // The whole space, empty, taking no touch, from the page's first
            // frame: the keyboard reader lies along its bottom edge.
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            if !dialogs.entries.isEmpty {
                GeometryReader { area in
                    TimelineView(.animation(minimumInterval: nil, paused: settled && drag == nil)) { context in
                        sheets(in: area.size, now: dialogs.clock(), lift: lift)
                            .onChange(of: context.date) { _ in
                                guard !dialogs.isMoving else { return }
                                dialogs.prune()
                                settled = true
                            }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { dialogs.dismiss() }
            }
        }
        #if canImport(UIKit)
        .background(alignment: .bottom) {
            // No height: nothing to draw (ImageRenderer would draw a UIKit
            // view's placeholder), only the bottom edge to measure from.
            KeyboardOverlap(opens: dialogs.opens) {
                keyboard = $0
                settled = false
            }
            .frame(height: 0)
        }
        #endif
        .onReceive(dialogs.objectWillChange) { _ in settled = false }
        .modifier(TooltipOverlayArea(model: model))
        #if canImport(UIKit)
        // A sheet opened and its panel is drawn: VoiceOver goes into it.
        .onChange(of: dialogs.opens) { _ in OrcaDialogs.post(.screenChanged, nil) }
        #endif
    }

    private func sheets(in size: CGSize, now: Double, lift: CGFloat) -> some View {
        let topId = dialogs.stack.top?.id
        return ZStack(alignment: .bottom) {
            ForEach(dialogs.entries) { entry in
                sheet(entry, isTop: entry.id == topId, size: size, now: now, lift: lift)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    /// `lift`: how far the keyboard raises the panel.
    private func sheet(_ entry: OrcaDialogs.Entry, isTop: Bool, size: CGSize, now: Double,
                       lift: CGFloat) -> some View {
        let height = size.height * CGFloat(entry.sheet.heightFactor)
        let dragged = isTop ? drag.map { controller(dragged: $0, height: height) } : nil
        let barrierT = dragged ?? entry.motion.controller(at: now)
        let shown = dragged ?? entry.motion.value(at: now)
        return ZStack(alignment: .bottom) {
            Color.black.opacity(SheetMotion.barrierOpacity(controller: barrierT))
                .contentShape(Rectangle())
                .onTapGesture { dialogs.dismiss() }
                .accessibilityHidden(true)
            // The barrier as VoiceOver finds it: above the panel only, the
            // panel as the keyboard has raised it.
            Color.clear
                .frame(height: max(size.height - height - lift, 0))
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel("Scrim")
                .accessibilityAction { dialogs.dismiss() }
                // SwiftUI makes an element with an action a button; Flutter's
                // Scrim on iOS is not one.
                .accessibilityRemoveTraits(.isButton)
                .accessibilitySortPriority(0)
            panel(entry, height: height, width: size.width)
                .offset(y: height * CGFloat(1 - shown) - lift)
                .gesture(dragGesture(height: height), including: isTop ? .all : .subviews)
                .accessibilitySortPriority(1)
        }
        .allowsHitTesting(isTop && !entry.isClosing)
        .accessibilityHidden(!isTop || entry.isClosing)
    }

    /// The Dialog's first child on its white panel, as tall as the sheet
    /// and as wide as the child up to `width` and 640, centred. The child
    /// gets Flutter's tight height and loose width; the panel's Material
    /// resets a DefaultTextStyle and the route's top padding is removed
    /// (MediaQuery.removePadding(removeTop:), bottom_sheet.dart:1183); light,
    /// as MaterialApp is without a darkTheme (orca_app.dart:569-572).
    private func panel(_ entry: OrcaDialogs.Entry, height: CGFloat, width: CGFloat) -> some View {
        NodeView(id: entry.sheet.rootId, model: model)
            .frame(height: height, alignment: .topLeading)
            .environment(\.orcaTight, [.vertical])
            .environment(\.orcaDefaultTextStyle, nil)
            .environment(\.orcaSafeAreaTaken, [.top])
            .environment(\.colorScheme, .light)
            .background(Color.white)
            .clipShape(CornersShape(radii: CornerRadii(topLeft: 24, topRight: 24)))
            .contentShape(Rectangle())
            .accessibilityElement(children: .contain)
            .frame(maxWidth: min(width, 640))
    }

    /// The route animation of a panel `height` tall dragged down `dragged`.
    private func controller(dragged: CGFloat, height: CGFloat) -> Double {
        min(max(dragBase - Double(dragged / max(height, 1)), 0), 1)
    }

    private func dragGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: SheetRelease.touchSlop, coordinateSpace: .global)
            .onChanged { value in
                if drag == nil { dragBase = dialogs.top?.motion.controller(at: dialogs.clock()) ?? 1 }
                drag = max(0, value.translation.height - SheetRelease.touchSlop)
            }
            .onEnded { value in
                let released = controller(dragged: drag ?? 0, height: height)
                drag = nil
                dialogs.release(controller: released, velocity: Self.velocity(value))
            }
    }

    /// The drag's downward speed in points a second.
    private static func velocity(_ value: DragGesture.Value) -> Double {
        if #available(iOS 17.0, macOS 14.0, *) {
            return Double(value.velocity.height)
        }
        // The predicted end lies about a quarter of a second ahead.
        return Double(value.predictedEndTranslation.height - value.translation.height) * 4
    }
}

#if canImport(UIKit)
/// How far the keyboard's top lies above its own bottom edge, from the
/// keyboard's frame notifications (screen coordinates), reported whenever it
/// changes; 0 when the keyboard is down or beside it. It takes no touch, is
/// not an accessibility element, and may have no height. Each new
/// `opens` (a sheet opened) ends editing in its window, so a field below
/// gives up focus and its keyboard; the tooltip layer passes 0 always.
struct KeyboardOverlap: UIViewRepresentable {
    let opens: Int
    let changed: (CGFloat) -> Void

    func makeUIView(context: Context) -> Reader {
        let reader = Reader()
        reader.changed = changed
        reader.opens = opens
        return reader
    }

    func updateUIView(_ reader: Reader, context: Context) {
        reader.changed = changed
        if opens != reader.opens {
            reader.opens = opens
            reader.window?.endEditing(true)
        }
    }

    final class Reader: UIView {
        var changed: (CGFloat) -> Void = { _ in }
        /// The sheets opened when editing was last ended.
        var opens = 0
        /// The keyboard's frame in screen coordinates; nil while it is down.
        private var keyboard: CGRect?
        private var reported: CGFloat = 0

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(keyboardChanged(_:)),
                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardHidden(_:)),
                               name: UIResponder.keyboardWillHideNotification, object: nil)
        }

        required init?(coder: NSCoder) { nil }

        @objc private func keyboardChanged(_ note: Notification) {
            keyboard = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            report(now: true)
        }

        @objc private func keyboardHidden(_ note: Notification) {
            keyboard = nil
            report(now: true)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report(now: false)
        }

        /// `now`: from a keyboard notification, outside any view update, so
        /// told at once; from a layout pass, on the next turn of the main
        /// queue, not while SwiftUI may be updating.
        private func report(now: Bool) {
            var overlap: CGFloat = 0
            if let keyboard, !keyboard.isEmpty, let screen = window?.screen {
                let frame = convert(keyboard, from: screen.coordinateSpace)
                if frame.minX < bounds.maxX, frame.maxX > bounds.minX, frame.minY < bounds.maxY {
                    overlap = bounds.maxY - frame.minY
                }
            }
            guard overlap != reported else { return }
            reported = overlap
            if now { return changed(overlap) }
            let tell = changed
            DispatchQueue.main.async { tell(overlap) }
        }
    }
}
#endif
#endif
