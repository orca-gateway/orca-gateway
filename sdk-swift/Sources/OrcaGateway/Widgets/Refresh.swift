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
/// on iOS 18.5), as Flutter hears depth 0 only.
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
/// first page). Nor is a ListView or GridView with no limit on its scroll
/// axis (a shrinkWrap one in a Column), drawn as a stack that does not
/// scroll, as Flutter's, which fits its content and takes no drag
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
/// PageView), applied where WidgetView builds it: `refreshable` when it is
/// a vertical scroll view directly inside a PullToRefresh. The scroll views
/// inside it are not directly inside one.
struct RefreshOnPull: ViewModifier {
    let node: ResolvedNode
    @Environment(\.orcaRefresh) private var refresh
    @Environment(\.orcaUnbounded) private var unbounded

    func body(content: Content) -> some View {
        let inner = content.environment(\.orcaRefresh, nil)
        if let refresh, Self.pulled(node, unbounded: unbounded) {
            inner.refreshable { await refresh() }
        } else {
            inner
        }
    }

    /// Whether the scroll kind `node`, offered no limit on the `unbounded`
    /// axes, is pulled: a SingleChildScrollView unless horizontal; a
    /// ListView or GridView unless horizontal or unbounded vertically
    /// (then drawn as a stack that does not scroll); a PageView only when
    /// vertical and not snapping. `refreshable` on a view with no scroll
    /// view of its own would pass on to the first vertical one inside it.
    static func pulled(_ node: ResolvedNode, unbounded: TightAxes) -> Bool {
        let direction = node["scrollDirection"]?.stringValue
        switch node.type {
        case "PageView": return direction == "vertical" && Props.bool(node["pageSnapping"]) == false
        case "ListView", "GridView": return direction != "horizontal" && !unbounded.contains(.vertical)
        default: return direction != "horizontal"
        }
    }
}
#endif
