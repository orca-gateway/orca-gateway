#if canImport(SwiftUI)
import SwiftUI

/// The side a drawer slides in from: `leading` for a drawer, `trailing` for
/// an end drawer. Never left or right: the layout direction decides.
enum DrawerEdge: Equatable {
    case leading
    case trailing
}

/// What a side panel does with a drag, without its drawing. Translations and
/// velocities run along the layout axis: positive from the leading side
/// toward the trailing side (the view flips the screen's x in a
/// right-to-left layout).
struct DrawerPanelModel: Equatable {
    enum Outcome: Equatable {
        case open
        case closed
    }

    /// Points per second from which a drag is a fling (Flutter
    /// `_kMinFlingVelocity`).
    static let flingVelocity: CGFloat = 365
    /// How far a drag from the screen edge must come in to open a drawer.
    static let openDistance: CGFloat = 40

    var edge: DrawerEdge
    /// The panel's width.
    var width: CGFloat

    /// A length along the axis as a length toward the panel's own edge.
    private func closing(_ value: CGFloat) -> CGFloat {
        edge == .leading ? -value : value
    }

    /// How far the drag has moved the panel toward its edge: 0 ... width.
    private func travel(_ translation: CGFloat) -> CGFloat {
        min(max(closing(translation), 0), max(width, 0))
    }

    /// Where the open panel is drawn during a drag: it follows the finger
    /// toward its edge, and nowhere else.
    func offset(translation: CGFloat) -> CGFloat {
        closing(travel(translation))
    }

    /// Where the closed panel is: its whole width past its edge.
    var closedOffset: CGFloat { closing(max(width, 0)) }

    /// 1 for the open panel, 0 for one dragged its whole width away: the
    /// scrim fades with it.
    func progress(translation: CGFloat) -> CGFloat {
        width > 0 ? 1 - travel(translation) / width : 1
    }

    /// The finger left the panel: a fling decides, else half the width
    /// (Flutter `DrawerController._settle`).
    func dragEnded(translation: CGFloat, velocity: CGFloat) -> Outcome {
        let speed = closing(velocity)
        if speed >= Self.flingVelocity { return .closed }
        if speed <= -Self.flingVelocity { return .open }
        return travel(translation) > width / 2 ? .closed : .open
    }

    /// A drag that began at the screen edge the closed panel lies behind:
    /// true when it came in far enough or fast enough to open it.
    func edgeDragOpens(translation: CGFloat, velocity: CGFloat) -> Bool {
        let distance = -closing(translation)
        let speed = -closing(velocity)
        return distance > 0 && (distance >= Self.openDistance || speed >= Self.flingVelocity)
    }
}

/// The drawers of an app, at its root: one panel at a time, over everything
/// (navigation and tab bars too). The shell and each page's Scaffold present
/// their drawer here instead of drawing an overlay of their own;
/// `DrawerHostLayer` draws it. Pages do not observe the host, so opening and
/// closing a drawer redraws no page.
@MainActor
final class DrawerHost: ObservableObject {
    struct Panel {
        let id: String
        let edge: DrawerEdge
        /// The user closed the panel (scrim, swipe, escape), or another
        /// panel took its place. Not called by `remove`.
        let onClose: () -> Void
        let content: () -> AnyView
    }

    /// The id of the shell drawer's panel.
    static let shellPanel = "__shell__"

    /// The panel last presented. It stays after it closed, for the slide
    /// out, until `forget()`.
    @Published private(set) var panel: Panel?
    @Published private(set) var isOpen = false

    /// The panel on screen, nil when none is open.
    var open: Panel? { isOpen ? panel : nil }

    /// Show a panel. An open panel of another id is closed first (its
    /// `onClose` runs).
    func present(id: String, edge: DrawerEdge, onClose: @escaping () -> Void = {},
                 content: @escaping () -> AnyView) {
        let old = open
        panel = Panel(id: id, edge: edge, onClose: onClose, content: content)
        isOpen = true
        if let old, old.id != id { old.onClose() }
    }

    /// The user closed the open panel: a tap on the scrim, a swipe, escape.
    func dismiss() {
        guard let panel = open else { return }
        isOpen = false
        panel.onClose()
    }

    /// The owner of panel `id` takes it away; nothing when another is open.
    func remove(_ id: String) {
        guard open?.id == id else { return }
        isOpen = false
    }

    /// Let go of a closed panel's content once it has slid out.
    func forget() {
        if !isOpen, panel != nil { panel = nil }
    }
}

/// The page a view is part of, for what a page's Scaffold needs to know
/// about its place: its router, its route (the `pageDrawerRequest` id) and
/// whether it is the first page of its stack (no back swipe at the leading
/// edge).
struct OrcaPageContext {
    let router: OrcaRouter
    let route: OrcaRoute
    let isStackRoot: Bool
}

private struct DrawerHostKey: EnvironmentKey {
    static let defaultValue: DrawerHost? = nil
}

private struct PageContextKey: EnvironmentKey {
    static let defaultValue: OrcaPageContext? = nil
}

extension EnvironmentValues {
    /// The app's drawer host; nil for a page drawn outside `OrcaApp`.
    var orcaDrawerHost: DrawerHost? {
        get { self[DrawerHostKey.self] }
        set { self[DrawerHostKey.self] = newValue }
    }

    /// The route a page is drawn for; nil outside `OrcaApp`.
    var orcaPage: OrcaPageContext? {
        get { self[PageContextKey.self] }
        set { self[PageContextKey.self] = newValue }
    }
}

/// What a page tells the shell around it about its own chrome, so the shell
/// adds only what the page left free.
struct PageChrome: Equatable {
    /// The page's AppBar is the navigation bar: its title stays.
    var hasBar = false
    /// The navigation bar's leading item is the page's.
    var hasLeadingItem = false
    /// The page has a drawer of its own at the leading edge.
    var hasLeadingDrawer = false
}

struct PageChromeKey: PreferenceKey {
    static let defaultValue = PageChrome()

    static func reduce(value: inout PageChrome, nextValue: () -> PageChrome) {
        let next = nextValue()
        value.hasBar = value.hasBar || next.hasBar
        value.hasLeadingItem = value.hasLeadingItem || next.hasLeadingItem
        value.hasLeadingDrawer = value.hasLeadingDrawer || next.hasLeadingDrawer
    }
}

/// The drawer layer of the app root: the host's panel over everything else.
@MainActor
struct DrawerHostLayer: View {
    @ObservedObject var host: DrawerHost

    var body: some View {
        ZStack {
            if let panel = host.panel {
                DrawerPanel(edge: panel.edge, isOpen: host.isOpen, onClose: { host.dismiss() },
                            content: panel.content)
                    .id(panel.id)
            }
        }
        .task(id: host.isOpen) {
            guard !host.isOpen else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            if !Task.isCancelled { host.forget() }
        }
    }
}

/// How wide a drawer is when the server gives no `width`.
let drawerDefaultWidth: CGFloat = 304

/// One side panel: `content` at the leading edge (the trailing one for an
/// end drawer) over a dimmed scrim. It slides in and out; a tap on the scrim
/// closes it, and so does a drag of the panel toward its edge past half its
/// width or a fling, the panel following the finger. For VoiceOver the scrim
/// is a "Close" button, the drawer (scrim and panel) is modal and the escape gesture closes it;
/// the Escape key does too.
@MainActor
struct DrawerPanel: View {
    let edge: DrawerEdge
    let isOpen: Bool
    let onClose: () -> Void
    let content: () -> AnyView

    @Environment(\.layoutDirection) private var direction
    /// False until the panel is first on screen, so it slides in.
    @State private var appeared = false
    @State private var width: CGFloat = drawerDefaultWidth
    /// Back to 0 when the finger leaves; the panel slides to where it settles.
    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: 0.2)))
    private var drag: CGFloat = 0

    var body: some View {
        let model = DrawerPanelModel(edge: edge, width: width)
        let shown = isOpen && appeared
        // The layout axis runs against the screen's x when right-to-left.
        let axis: CGFloat = direction == .rightToLeft ? -1 : 1
        let offset = shown ? model.offset(translation: drag) : model.closedOffset
        ZStack(alignment: edge == .leading ? .leading : .trailing) {
            Button(action: onClose) {
                Color.black.opacity(shown ? 0.4 * model.progress(translation: drag) : 0)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .disabled(!isOpen)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("orca.drawer.scrim")

            content()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                .offset(x: offset * axis)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .updating($drag) { value, state, _ in state = value.translation.width * axis }
                        .onEnded { value in
                            let outcome = model.dragEnded(
                                translation: value.translation.width * axis,
                                velocity: DrawerPanel.velocity(value) * axis)
                            if outcome == .closed { onClose() }
                        })
                .accessibilityIdentifier("orca.drawer")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(isOpen)
        .accessibilityHidden(!isOpen)
        .animation(.easeOut(duration: 0.25), value: shown)
        .onAppear { appeared = true }
    }

    /// The drag's horizontal speed in points per second.
    static func velocity(_ value: DragGesture.Value) -> CGFloat {
        if #available(iOS 17.0, macOS 14.0, *) {
            return value.velocity.width
        }
        // The predicted end lies about a quarter of a second ahead.
        return (value.predictedEndTranslation.width - value.translation.width) * 4
    }
}

/// A strip along a screen edge that opens the drawer behind it when a drag
/// comes in from that edge.
@MainActor
struct DrawerEdgeGrip: View {
    let edge: DrawerEdge
    let open: () -> Void

    @Environment(\.layoutDirection) private var direction

    var body: some View {
        let axis: CGFloat = direction == .rightToLeft ? -1 : 1
        Color.clear
            .frame(width: 16)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 8).onEnded { value in
                let model = DrawerPanelModel(edge: edge, width: drawerDefaultWidth)
                if model.edgeDragOpens(translation: value.translation.width * axis,
                                       velocity: DrawerPanel.velocity(value) * axis) {
                    open()
                }
            })
            .accessibilityHidden(true)
    }
}

/// The button that opens a drawer from a navigation bar.
@MainActor
struct DrawerMenuButton: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Image(systemName: "line.3.horizontal")
        }
        .accessibilityLabel("Menu")
        .accessibilityIdentifier("orca.drawer.menu")
    }
}
#endif
