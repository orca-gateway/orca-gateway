#if canImport(SwiftUI)
import SwiftUI

/// The Scrollbar the scroll view below is directly inside: none outside a
/// Scrollbar, and none inside another scroll view (Flutter's Scrollbar
/// follows depth-0 notifications only).
struct ScrollbarFollow: Equatable {
    var thumbVisibility: Bool
}

private struct ScrollbarFollowKey: EnvironmentKey {
    static let defaultValue: ScrollbarFollow? = nil
}

extension EnvironmentValues {
    var orcaScrollbar: ScrollbarFollow? {
        get { self[ScrollbarFollowKey.self] }
        set { self[ScrollbarFollowKey.self] = newValue }
    }
}

/// Flutter `Scrollbar` (layout_builders.dart:603-611), on iOS a
/// CupertinoScrollbar over the scroll view directly inside it: here that
/// scroll view's own indicator, shown while it scrolls and faded by the
/// system after (ScrollIndicators). Widgets that do not scroll may stand
/// between them; a scroll view nested in that one is not followed.
/// `thickness` has no iOS counterpart (Flutter's 3 points, 8 while
/// dragging, against the system's own), so it is not read. A snapping
/// PageView is drawn without a scroll view, so it shows no thumb (Flutter
/// draws one along the pages).
@MainActor
struct ScrollbarView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .environment(\.orcaScrollbar, ScrollbarFollow(thumbVisibility: Props.bool(node["thumbVisibility"]) == true))
    }
}

/// The indicators of a scroll kind (SingleChildScrollView, ListView,
/// GridView, PageView), applied where WidgetView builds it: visible
/// directly inside a Scrollbar; otherwise hidden on iOS, as Flutter on a
/// phone draws none without a Scrollbar (scroll_configuration.dart
/// :160-172), and the system's default on macOS, where Flutter's desktop
/// behaviour draws one. The scroll views inside it follow no Scrollbar.
///
/// `thumbVisibility` keeps Flutter's thumb shown; the system cannot keep
/// its indicator shown, so it is flashed instead, fading about a second
/// later: once the view is on screen (iOS 17 / macOS 14; SwiftUI's own
/// flash on appear runs before the view is laid out and shows nothing)
/// and each time a scroll ends (iOS 18 / macOS 15, the scroll phase).
/// iOS 16 shows it only while scrolling.
struct ScrollIndicators: ViewModifier {
    @Environment(\.orcaScrollbar) private var scrollbar
    /// Each move flashes the indicators.
    @State private var flashes = 0

    func body(content: Content) -> some View {
        let shown = content
            .environment(\.orcaScrollbar, nil)
            .scrollIndicators(scrollbar == nil ? Self.withoutScrollbar : .visible)
        if #available(iOS 18, macOS 15, *) {
            flashing(shown).onScrollPhaseChange { old, new in
                if keep, new == .idle, old != .idle { flashes += 1 }
            }
        } else if #available(iOS 17, macOS 14, *) {
            flashing(shown)
        } else {
            shown
        }
    }

    private var keep: Bool { scrollbar?.thumbVisibility == true }

    @available(iOS 17, macOS 14, *)
    private func flashing<V: View>(_ view: V) -> some View {
        view
            .scrollIndicatorsFlash(trigger: flashes)
            .task(id: keep) { if keep { flashes += 1 } }
    }

    private static var withoutScrollbar: ScrollIndicatorVisibility {
        #if os(macOS)
        .automatic
        #else
        .hidden
        #endif
    }
}
#endif
