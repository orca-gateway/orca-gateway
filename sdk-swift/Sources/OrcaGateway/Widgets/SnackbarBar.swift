#if canImport(SwiftUI)
import SwiftUI

/// Flutter's M3 fixed SnackBar as showSnackbar shows it, `SnackBar(content:
/// Text(message))` on the Scaffold's light ThemeData (material snack_bar.dart
/// :690-905, _SnackbarDefaultsM3): as wide as it is offered, square
/// (no shape when fixed, :817-818), on inverseSurface #322F35, the message in
/// bodyMedium (14, line height 1.43, letter spacing 0.25) in onInverseSurface
/// #F5EFF7, starting 24 in and ending 24 from the end (:707-713), 14 above
/// and below (:29, :793), wrapping as a Flutter Text does. `safeArea` is laid
/// inside it around the text (SafeArea(top: false), :812): the horizontal
/// insets, so the bar runs edge to edge, and the bottom one where no bottom
/// bar lies under it (scaffold.dart:3273-3285).
///
/// Revealed by height, never faded (M3, :830, :888-891): `heightFactor` of
/// it shows, its top first, and the rest is clipped, as Flutter's
/// `Align(topStart, heightFactor)` in a ClipRect (:901). The Material's
/// elevation 6 casts a shadow (Skia's: light 600 above the bar's top, an
/// ambient and a spot blur of a few points, mostly under the bar), but that
/// ClipRect clips it to the bar's own rectangle, where the opaque bar covers
/// it: nothing of it shows, so none is drawn here. `drag` slides it down
/// inside the same clip (the Dismissible, :859-871). The whole bar's height,
/// whatever shows of it, goes up as `SnackbarHeightKey`.
struct SnackbarBar: View {
    let message: String
    /// The share of its height that shows, 0 ... 1.
    let heightFactor: Double
    var safeArea = EdgeInsets()
    var drag: CGFloat = 0

    static let background = Props.color(hex: "#322F35")
    static let textStyle = TextStyleProps(.object([
        "color": "#F5EFF7", "fontSize": 14, "letterSpacing": 0.25, "height": 1.43,
    ]))

    var body: some View {
        CenterFactorLayout(heightFactor: CGFloat(heightFactor), alignment: .topLeading) {
            bar.offset(y: drag)
        }
        .clipped()
    }

    /// The whole bar, as tall as its text: TextNodeView's line box (Flutter's
    /// `height`, half of the extra above the first line and below the last).
    private var bar: some View {
        let style = Self.textStyle
        let extra = style.extraLeading
        return style.styledText(message)
            .lineSpacing(max(extra, 0))
            .padding(.vertical, extra / 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 24 + safeArea.leading)
            .padding(.trailing, 24 + safeArea.trailing)
            .padding(.top, 14)
            .padding(.bottom, 14 + safeArea.bottom)
            .background(Self.background)
            .background(GeometryReader { area in
                Color.clear.preference(key: SnackbarHeightKey.self, value: area.size.height)
            })
    }
}

/// The whole height of the snackbar bar drawn below, shown or not.
struct SnackbarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// The app queue's head where the root Scaffold on screen, a titled route's
/// Scaffold or the tab shell draws it: a snackbar as `SnackbarBar`,
/// revealed by the queue's `reveal` through fastOutSlowIn both ways
/// (snack_bar.dart:596, :888-891), frames sampled while it enters or leaves;
/// nothing for a toast (ToastView draws those) or an idle queue. Each item is
/// a view of its own, so a drag never carries over to the next.
@MainActor
struct SnackbarSlot: View {
    @ObservedObject var snackbars: OrcaSnackbars
    /// The safe area to hold inside the bar.
    var safeArea = EdgeInsets()

    var body: some View {
        if let head = snackbars.head, head.style == .snackbar {
            LiveSnackbar(snackbars: snackbars, toast: head, safeArea: safeArea)
                .id(head.id)
        }
    }
}

/// One snackbar on screen. A drag down slides it with the finger; on
/// release it goes on down and off (Flutter's 200 ms movement for what is
/// left; a fling slides at that same pace where Flutter's is a spring), then
/// the queue drops it at once (`OrcaSnackbars.swipe`), or slides back up
/// (`SnackbarSwipe`, measured against the whole bar, as the Dismissible
/// measures its child). The bar takes every touch on it (the Dismissible's
/// opaque hit test). VoiceOver reads it as one element and hears it once as
/// it first appears (Flutter's live region, snack_bar.dart:849-851,
/// `OrcaSnackbars.announce`); its escape gesture is Flutter's semantics
/// dismiss, the same drop.
@MainActor
private struct LiveSnackbar: View {
    @ObservedObject var snackbars: OrcaSnackbars
    let toast: OrcaToast
    let safeArea: EdgeInsets
    @State private var drag: CGFloat = 0
    /// The whole bar's height, what a release is measured against.
    @State private var height: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: snackbars.queue.phase == .showing)) { _ in
            SnackbarBar(message: toast.message, heightFactor: Curves.apply("fastOutSlowIn", snackbars.reveal),
                        safeArea: safeArea, drag: drag)
        }
        .onPreferenceChange(SnackbarHeightKey.self) { height = $0 }
        .contentShape(Rectangle())
        .gesture(DragGesture()
            .onChanged { drag = max(0, $0.translation.height) }
            .onEnded(release))
        .accessibilityElement(children: .combine)
        .accessibilityAction(.escape) { snackbars.swipe(toast) }
        .onAppear { snackbars.announce(toast) }
    }

    private func release(_ value: DragGesture.Value) {
        var velocity: CGSize?
        if #available(iOS 17, macOS 14, *) { velocity = value.velocity }
        let full = max(height, 1)
        if SnackbarSwipe.dismisses(drag: drag, velocity: velocity, height: height) {
            let left = SnackbarSwipe.movement * Double(max(0, 1 - drag / full))
            withAnimation(.linear(duration: left)) { drag = max(drag, full) }
            DispatchQueue.main.asyncAfter(deadline: .now() + left) { [snackbars, toast] in snackbars.swipe(toast) }
        } else {
            withAnimation(.linear(duration: SnackbarSwipe.movement * Double(min(drag / full, 1)))) { drag = 0 }
        }
    }
}

/// What a release of the bar decides, Flutter's Dismissible with direction
/// down (widgets/dismissible.dart:19-22, :114, :465-536).
enum SnackbarSwipe {
    /// The share of its height a slow drag must pass to dismiss (:22).
    static let threshold: CGFloat = 0.4
    /// A fling: at least this fast down (:19) ...
    static let minFlingVelocity: CGFloat = 700
    /// ... and this much faster down than sideways (:20), points a second.
    static let minFlingVelocityDelta: CGFloat = 400
    /// The slide's time for the whole height (`movementDuration`, :114).
    static let movement: Double = 0.2

    /// True when the bar goes: dragged down `drag` of its whole `height`,
    /// let go at `velocity` (nil where SwiftUI gives none, before iOS 17:
    /// then the distance alone decides). No drag never goes; a fling down
    /// goes whatever the distance, a fling up comes back; else past 0.4 goes.
    static func dismisses(drag: CGFloat, velocity: CGSize?, height: CGFloat) -> Bool {
        guard drag > 0 else { return false }
        if let velocity, abs(velocity.height) - abs(velocity.width) >= minFlingVelocityDelta,
           abs(velocity.height) >= minFlingVelocity {
            return velocity.height > 0
        }
        return height > 0 && drag / height > threshold
    }
}

/// The insets a bottom layer holds, as Flutter's Scaffold gives them to its
/// bottom slots: the horizontal safe area, and the bottom one (the home
/// indicator) unless the keyboard is up, when MediaQuery's padding is what
/// the view padding leaves above the keyboard, nothing (scaffold.dart
/// :3396-3405; the bar's SafeArea, snack_bar.dart:812).
struct BottomLayerInsets: Equatable {
    var leading: CGFloat = 0
    var trailing: CGFloat = 0
    var bottom: CGFloat = 0
}

/// Lays `content` in the space it is given, which ends on the keyboard's
/// top while it is up (Flutter's contentBottom, scaffold.dart:1173-1176,
/// with resizeToAvoidBottomInset), and hands it `BottomLayerInsets`. Two
/// readers: one keeping to the whole safe area (keyboard included), so it
/// ends where the content must; one inside it past the keyboard only, so it
/// sees the container's insets and, by reaching lower, that the keyboard is
/// up. A reader that ignores a region reads 0 for it, so neither ignores the
/// container's; `content` reaches past it itself where it must.
struct BottomLayerReader<Content: View>: View {
    @ViewBuilder let content: (BottomLayerInsets) -> Content

    var body: some View {
        GeometryReader { outer in
            GeometryReader { inner in
                let keyboardUp = inner.size.height > outer.size.height + 0.5
                content(BottomLayerInsets(leading: inner.safeAreaInsets.leading,
                                          trailing: inner.safeAreaInsets.trailing,
                                          bottom: keyboardUp ? 0 : inner.safeAreaInsets.bottom))
                    .frame(width: outer.size.width, height: outer.size.height, alignment: .top)
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

/// `SnackbarSlot` at the bottom of the space it lies over, edge to edge
/// with the horizontal safe area inside it; `reachesBottomEdge`: past the
/// bottom safe area too, holding it inside (a Scaffold with no bottom bar).
/// It takes no touch outside the bar.
@MainActor
struct SnackbarOverlay: View {
    let snackbars: OrcaSnackbars
    let reachesBottomEdge: Bool

    var body: some View {
        BottomLayerReader { insets in
            SnackbarSlot(snackbars: snackbars, safeArea: EdgeInsets(
                top: 0, leading: insets.leading, bottom: reachesBottomEdge ? insets.bottom : 0,
                trailing: insets.trailing))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.container, edges: reachesBottomEdge ? [.horizontal, .bottom] : .horizontal)
        }
    }
}

private struct SnackbarDrawnKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// A Scaffold above, or the tab shell, draws the app's snackbar: a
    /// Scaffold below is nested and draws none (Flutter's messenger shows
    /// the bar only in a root Scaffold, scaffold.dart:229-263).
    var orcaSnackbarDrawn: Bool {
        get { self[SnackbarDrawnKey.self] }
        set { self[SnackbarDrawnKey.self] = newValue }
    }
}
#endif
