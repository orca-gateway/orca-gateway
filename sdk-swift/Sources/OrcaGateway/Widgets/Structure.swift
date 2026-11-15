#if canImport(SwiftUI)
import SwiftUI

/// Scaffold: `body` fills the screen; an `appBar` slot holding an AppBar
/// becomes the navigation bar of the enclosing NavigationStack (see
/// AppBarChrome: title, leading item, `action_N` items on the trailing side);
/// `floatingActionButton` floats bottom-trailing; `bottomNavigationBar` and
/// `persistentFooterButton_N` sit above the bottom safe area. Drawers and
/// bottom sheets are not drawn yet.
@MainActor
struct ScaffoldView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let appBar = node.slots["appBar"].flatMap(model.resolve)
        ZStack(alignment: .bottomTrailing) {
            if let background = Props.color(node["backgroundColor"]) {
                background.ignoresSafeArea()
            }
            Group {
                if let body = node.slots["body"] {
                    NodeView(id: body, model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let fab = node.slots["floatingActionButton"] {
                NodeView(id: fab, model: model).padding(16)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBars }
        .modifier(AppBarChrome(appBar: appBar, model: model))
        // Flutter's Scaffold lays out its slots with fresh, loose
        // constraints, so an axis forced on the Scaffold (the warn banner's
        // stretched Column) reaches neither the AppBar title nor the body.
        .environment(\.orcaTight, [])
    }

    @ViewBuilder
    private var bottomBars: some View {
        let footer = indexedSlots(node, "persistentFooterButton")
        if !footer.isEmpty || node.slots["bottomNavigationBar"] != nil {
            VStack(spacing: 0) {
                if !footer.isEmpty {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        ForEach(footer, id: \.self) { NodeView(id: $0, model: model) }
                    }
                    .padding(8)
                }
                if let bar = node.slots["bottomNavigationBar"] {
                    NodeView(id: bar, model: model)
                }
            }
        }
    }
}

/// `name_0`, `name_1`, ... slot ids in order, stopping at the first gap (the
/// Flutter builders read indexed slots this way).
func indexedSlots(_ node: ResolvedNode, _ name: String) -> [String] {
    var ids: [String] = []
    while let id = node.slots["\(name)_\(ids.count)"] { ids.append(id) }
    return ids
}

/// Puts a Scaffold's AppBar into the navigation bar (Flutter `_buildAppBar`,
/// SB:85-120, M3). The title is centred, or with `centerTitle` false a
/// leading item (after the back button). A `leading` slot replaces the back
/// button, `leadingWidth` sizes it (UIKit's bar margin stands in for
/// Flutter's default 56 box), and `automaticallyImplyLeading` false hides
/// the back button (SwiftUI then also turns off the swipe back, which
/// Flutter keeps). `elevation` with a
/// `shadowColor` draws `AppBarShadow` at the top of the content, under the
/// bar: SwiftUI has no navigation-bar shadow, and a global
/// UINavigationBarAppearance would leak to other screens. A slot that is not
/// an AppBar is drawn above the body instead.
@MainActor
private struct AppBarChrome: ViewModifier {
    let appBar: ResolvedNode?
    let model: OrcaPageModel

    func body(content: Content) -> some View {
        if let appBar, appBar.type == "AppBar" {
            let actions = indexedSlots(appBar, "action")
            let background = Props.color(appBar["backgroundColor"])
            content
                .overlay(alignment: .top) { AppBarShadow(appBar: appBar) }
                .navigationTitle(plainTitle(appBar))
                .toolbar {
                    if centresTitle(appBar) {
                        ToolbarItem(placement: .principal) { title(appBar) }
                    }
                    #if os(iOS)
                    if appBar.slots["leading"] != nil || !centresTitle(appBar) {
                        ToolbarItem(placement: .navigationBarLeading) {
                            HStack(spacing: 16) {
                                if let leading = appBar.slots["leading"] {
                                    NodeView(id: leading, model: model)
                                        .frame(width: Props.number(appBar["leadingWidth"]))
                                }
                                if !centresTitle(appBar) { title(appBar) }
                            }
                        }
                    }
                    if !actions.isEmpty {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            ForEach(actions, id: \.self) { NodeView(id: $0, model: model) }
                        }
                    }
                    #endif
                }
                #if os(iOS)
                .navigationBarBackButtonHidden(
                    appBar.slots["leading"] != nil || Props.bool(appBar["automaticallyImplyLeading"]) == false)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(background ?? Color.clear, for: .navigationBar)
                .toolbarBackground(background == nil ? .automatic : .visible, for: .navigationBar)
                #endif
        } else if let appBar {
            content.safeAreaInset(edge: .top, spacing: 0) {
                WidgetView(node: appBar, model: model)
            }
        } else {
            content
        }
    }

    /// Centred unless `centerTitle` is false (Flutter on iOS centres with
    /// fewer than two actions). The leading placement is iOS-only, so macOS
    /// always centres.
    private func centresTitle(_ appBar: ResolvedNode) -> Bool {
        #if os(iOS)
        return Props.bool(appBar["centerTitle"]) != false
        #else
        return true
        #endif
    }

    @ViewBuilder
    private func title(_ appBar: ResolvedNode) -> some View {
        if let title = appBar.slots["title"] {
            // A title without its own style gets the bar's font.
            NodeView(id: title, model: model).font(.headline)
        }
    }

    /// The title as plain text, for the back button and accessibility.
    private func plainTitle(_ appBar: ResolvedNode) -> String {
        guard let id = appBar.slots["title"], let title = model.resolve(id), title.type == "Text" else {
            return model.page.title
        }
        return Props.text(title["data"])
    }
}

/// An AppBar outside a Scaffold's appBar slot, laid out as Flutter's
/// NavigationToolbar: `toolbarHeight` high (default 56); the leading slot a
/// box `leadingWidth` wide (default 56) at the leading edge, as high as the
/// bar, its size forced as Flutter's tight constraints force it; the title
/// centred, or with `centerTitle` false 16 after the leading box (16 in
/// without one); actions at the trailing edge. `elevation` with a
/// `shadowColor` draws `AppBarShadow` under the bar.
@MainActor
struct AppBarView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let centred = Props.bool(node["centerTitle"]) != false
        ZStack {
            if centred, let title = node.slots["title"] {
                NodeView(id: title, model: model).font(.headline).padding(.horizontal, 16)
            }
            HStack(spacing: 0) {
                if let leading = node.slots["leading"] {
                    NodeView(id: leading, model: model)
                        .environment(\.orcaTight, [.horizontal, .vertical])
                        .frame(width: Props.number(node["leadingWidth"]) ?? 56)
                }
                if !centred, let title = node.slots["title"] {
                    NodeView(id: title, model: model).font(.headline).padding(.leading, 16)
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    ForEach(indexedSlots(node, "action"), id: \.self) { NodeView(id: $0, model: model) }
                }
                .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Props.number(node["toolbarHeight"]) ?? 56)
        .background(Props.color(node["backgroundColor"]))
        .overlay(alignment: .bottom) {
            AppBarShadow(appBar: node).alignmentGuide(.bottom) { $0[.top] }
        }
    }
}

/// An AppBar's elevation shadow, drawn below the edge it is aligned to: a
/// strip `elevation` points tall fading from `shadowColor` at 25% (Skia's
/// spot-shadow alpha, which Flutter's Material shadow uses) to clear.
/// Flutter's M3 AppBar has elevation 0 and a transparent shadowColor by
/// default, so nothing is drawn unless both are sent. It never takes taps.
private struct AppBarShadow: View {
    let appBar: ResolvedNode

    var body: some View {
        let elevation = Props.number(appBar["elevation"]) ?? 0
        if elevation > 0, let color = Props.color(appBar["shadowColor"]) {
            LinearGradient(colors: [color.opacity(0.25), color.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: elevation)
                .allowsHitTesting(false)
        }
    }
}

/// Card (Flutter `_buildCard`, SB:122-160, M3): rounded surface (radius
/// default 12) with a shadow from `elevation` (default 1), inner `padding`,
/// outer `margin` (default 4), both absolute (D4). `surfaceTintColor` is laid
/// over the colour (default white) with the M3 opacity for the elevation
/// (`surfaceTintOpacity`); `clipBehavior`, when sent, clips the child to the
/// card's shape, not the shadow.
@MainActor
struct CardView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let elevation = Props.number(node["elevation"]) ?? 1
        let radius = Props.number(node["borderRadius"]) ?? 12
        let shape = CornersShape(radii: CornerRadii(all: radius))
        ChildView(node: node, model: model)
            .orcaPadding(node["padding"])
            .modifier(ClipIf(shape: Props.clips(node["clipBehavior"]) ? shape : nil))
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Props.color(node["color"]) ?? Color.white)
                    .shadow(
                        color: Props.color(node["shadowColor"]) ?? Color.black.opacity(0.18),
                        radius: elevation, x: 0, y: elevation / 2)
                    // After the shadow, which would otherwise shade the tint too.
                    .overlay {
                        if let tint = Self.tint(node["surfaceTintColor"]) {
                            RoundedRectangle(cornerRadius: radius)
                                .fill(tint.opacity(Self.surfaceTintOpacity(elevation)))
                        }
                    })
            .orcaPadding(node["margin"], fallback: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }

    /// The tint as Flutter's `withOpacity` uses it: the colour's own alpha is
    /// replaced, so it is read opaque. Transparent (`#00000000`) is no tint.
    static func tint(_ value: JSONValue?) -> Color? {
        guard let hex = value?.stringValue, Props.color(value) != nil, hex.uppercased() != "#00000000" else {
            return nil
        }
        return Props.color(.string(String(hex.prefix(7))))
    }

    /// Flutter `ElevationOverlay.applySurfaceTint`'s opacity: the M3 table,
    /// linear between its entries, clamped at both ends.
    static func surfaceTintOpacity(_ elevation: CGFloat) -> Double {
        let table: [(elevation: CGFloat, opacity: Double)] = [
            (0, 0), (1, 0.05), (3, 0.08), (6, 0.11), (8, 0.12), (12, 0.14),
        ]
        guard elevation > 0 else { return 0 }
        for (lower, upper) in zip(table, table.dropFirst()) where elevation <= upper.elevation {
            let t = Double((elevation - lower.elevation) / (upper.elevation - lower.elevation))
            return lower.opacity + t * (upper.opacity - lower.opacity)
        }
        return 0.14
    }
}
#endif
