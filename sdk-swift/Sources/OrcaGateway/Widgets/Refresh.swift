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
/// first page). macOS has no pull to refresh on a scroll view: the child is
/// drawn as is.
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

    func body(content: Content) -> some View {
        let inner = content.environment(\.orcaRefresh, nil)
        if let refresh, Self.pulled(node) {
            inner.refreshable { await refresh() }
        } else {
            inner
        }
    }

    /// Whether the scroll kind `node` is drawn with a vertical scroll view:
    /// a PageView only when vertical and not snapping.
    static func pulled(_ node: ResolvedNode) -> Bool {
        let direction = node["scrollDirection"]?.stringValue
        guard node.type == "PageView" else { return direction != "horizontal" }
        return direction == "vertical" && Props.bool(node["pageSnapping"]) == false
    }
}
#endif
