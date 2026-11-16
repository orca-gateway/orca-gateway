#if canImport(SwiftUI)
import SwiftUI

/// The PullToRefresh the scroll view below is directly inside, and what
/// its pull runs: none outside a PullToRefresh, and none inside another
/// scroll view (Flutter's RefreshIndicator hears depth-0 notifications
/// only, refresh_indicator.dart:461-475).
struct PullRefresh {
    let node: ResolvedNode
    let model: OrcaPageModel

    /// Fires onRefresh and waits for it to end; nothing to wait for
    /// without one, as Flutter's onRefresh then completes at once.
    @MainActor
    func callAsFunction() async {
        await model.fire("onRefresh", on: node)?.value
    }
}

private struct PullRefreshKey: EnvironmentKey {
    static let defaultValue: PullRefresh? = nil
}

extension EnvironmentValues {
    var orcaRefresh: PullRefresh? {
        get { self[PullRefreshKey.self] }
        set { self[PullRefreshKey.self] = newValue }
    }
}

/// Flutter `PullToRefresh` (layout_builders.dart:372-393), a
/// RefreshIndicator over the scroll view directly inside it: here that
/// scroll view's own refresh control (SwiftUI `refreshable`, RefreshOnPull).
/// Widgets that do not scroll may stand between them. A pull down at its
/// top (a `reverse` one's far end, as Flutter's) fires onRefresh and the
/// spinner turns until the action has ended (Flutter awaits it,
/// refresh_indicator.dart:634-639); with no onRefresh it stops at once. A
/// horizontal scroll view never refreshes, nor does one nested inside the
/// first (SwiftUI's refresh action stops at the first scroll view, checked
/// on iOS 18.5), as Flutter hears depth 0 only. Inside another scroll view
/// (a page's body) a pull at its top stays its own, so it refreshes and the
/// page stands still, as Flutter's inner Scrollable wins the drag (KeepPull,
/// iOS 17.4 on; before, UIKit may hand the pull to the outer one).
///
/// Known differences: a drag begun lower down that carries the view on past
/// its top also refreshes (UIRefreshControl's own rule, checked by a drag
/// on the iOS 18.5 simulator), where Flutter's default `onEdge` trigger
/// refreshes only a drag begun at the top (:461-475). `color`,
/// `backgroundColor` and `displacement` have no counterpart in
/// `refreshable`, which draws the system's spinner where the system puts
/// it, so they are not read; the pull needed is the system's own (Flutter's
/// is a sixth of the view's height). A snapping PageView is drawn without a
/// scroll view, so it is not pulled (Flutter refreshes a vertical one at its
/// first page). Nor is a ListView, GridView or CustomScrollView with no
/// limit on its scroll axis (a shrinkWrap one in a Column), drawn as a
/// stack that does not scroll, as Flutter's, which fits its content and takes no drag
/// (widgets/scroll_physics.dart:241-250). macOS has no pull to refresh on a
/// scroll view: the child is drawn as is.
@MainActor
struct PullToRefreshView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .environment(\.orcaRefresh, PullRefresh(node: node, model: model))
    }
}

/// The pull of a scroll kind (SingleChildScrollView, ListView, GridView,
/// CustomScrollView, PageView), applied where WidgetView builds it:
/// `refreshable` (and, on iOS, KeepPull) when it is a vertical scroll view
/// directly inside a PullToRefresh. The scroll views inside it are not
/// directly inside one.
struct RefreshOnPull: ViewModifier {
    let node: ResolvedNode
    @Environment(\.orcaRefresh) private var refresh
    @Environment(\.orcaUnbounded) private var unbounded

    func body(content: Content) -> some View {
        let inner = content.environment(\.orcaRefresh, nil)
        if let refresh, Self.pulled(node, unbounded: unbounded) {
            #if canImport(UIKit)
            inner.refreshable { await refresh() }
                .background(alignment: .topLeading) { KeepPull().frame(width: 0, height: 0) }
            #else
            inner.refreshable { await refresh() }
            #endif
        } else {
            inner
        }
    }

    /// Whether the scroll kind `node`, offered no limit on the `unbounded`
    /// axes, is pulled: a SingleChildScrollView unless horizontal; a
    /// ListView, GridView or CustomScrollView unless horizontal or unbounded vertically
    /// (then drawn as a stack that does not scroll); a PageView only when
    /// vertical and not snapping. `refreshable` on a view with no scroll
    /// view of its own would pass on to the first vertical one inside it.
    static func pulled(_ node: ResolvedNode, unbounded: TightAxes) -> Bool {
        let direction = node["scrollDirection"]?.stringValue
        switch node.type {
        case "PageView": return direction == "vertical" && Props.bool(node["pageSnapping"]) == false
        case "ListView", "GridView", "CustomScrollView": return direction != "horizontal" && !unbounded.contains(.vertical)
        default: return direction != "horizontal"
        }
    }
}

#if canImport(UIKit)
/// Keeps a pull at the top of the refreshed scroll view its own when it is
/// nested in another: UIKit hands a drag past a nested scroll view's edge to
/// the one around it (`transfersVerticalScrollingToParent`, on by default),
/// so the page would move and the pull never start (a real pull on the iOS
/// 18.5 simulator), where Flutter's inner Scrollable wins the drag,
/// overscrolls and its RefreshIndicator refreshes. A 0-size view at the
/// scroll view's top leading corner (ImageRenderer would draw a placeholder
/// for a bigger one) that turns the transfer off on it, iOS 17.4 on (no
/// switch before).
private struct KeepPull: UIViewRepresentable {
    func makeUIView(context: Context) -> KeepPullAnchor {
        KeepPullAnchor(rightToLeft: context.environment.layoutDirection == .rightToLeft)
    }

    func updateUIView(_ anchor: KeepPullAnchor, context: Context) {
        anchor.rightToLeft = context.environment.layoutDirection == .rightToLeft
        anchor.keep()
    }
}

/// The refreshed scroll view's top leading corner in UIKit, which takes no
/// touch: its top left, or its top right when the layout runs right to left.
private final class KeepPullAnchor: UIView {
    var rightToLeft: Bool {
        didSet { if rightToLeft != oldValue { found = nil } }
    }

    /// The refreshed scroll view, once found, while it stays in the window.
    private weak var found: UIScrollView?

    init(rightToLeft: Bool) {
        self.rightToLeft = rightToLeft
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        keep()
    }

    /// Turns the transfer off on the refreshed scroll view, looking again
    /// on the next turns of the run loop until SwiftUI has drawn it; once
    /// found, it is not looked for again while it stays in the window.
    func keep(tries: Int = 5) {
        guard #available(iOS 17.4, *), let window else { return }
        if let found, found.window === window { return }
        if let scroll = refreshed {
            found = scroll
            scroll.transfersVerticalScrollingToParent = false
        } else if tries > 0 {
            DispatchQueue.main.async { [weak self] in self?.keep(tries: tries - 1) }
        }
    }

    /// The scroll view with a refresh control whose top leading corner is
    /// this view's, the nearest: SwiftUI draws it beside this view, not
    /// around it, so each view around this one is searched in turn.
    private var refreshed: UIScrollView? {
        guard let window else { return nil }
        let corner = convert(CGPoint.zero, to: window)
        func find(in view: UIView, skipping searched: UIView?) -> UIScrollView? {
            for sub in view.subviews where sub !== searched {
                if let scroll = sub as? UIScrollView, scroll.refreshControl != nil {
                    let frame = scroll.convert(scroll.bounds, to: window)
                    let leading = rightToLeft ? frame.maxX : frame.minX
                    if abs(leading - corner.x) < 0.5, abs(frame.minY - corner.y) < 0.5 { return scroll }
                }
                if let match = find(in: sub, skipping: nil) { return match }
            }
            return nil
        }
        var searched: UIView = self
        var around = superview
        while let view = around {
            if let match = find(in: view, skipping: searched) { return match }
            searched = view
            around = view.superview
        }
        return nil
    }
}
#endif
#endif
