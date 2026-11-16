#if canImport(SwiftUI)
import SwiftUI

// AbsorbPointer and IgnorePointer of the Flutter SDK's layout_builders.dart
// (:455-467). Both are proxy boxes: the child's size and look, whatever
// they do to taps (never drawn as disabled), and the modifiers are the same
// either way, so the child keeps its identity and state when a value bound
// to page state flips them.

// MARK: - AbsorbPointer

/// Flutter `AbsorbPointer` (`absorbing` default true), RenderAbsorbPointer
/// `hitTest` (proxy_box.dart:3952-3953): absorbing, a hit inside its box is
/// a hit on it, so its child never gets it and, in a Stack, nothing behind
/// it does either; not absorbing, it is its child. Absorbing, the child
/// takes no hits and an invisible fill over its box (`hitFill`: a clear
/// layer or a content shape alone would let UIKit views behind take them)
/// takes every one.
@MainActor
struct AbsorbPointerView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        let absorbing = Props.bool(node["absorbing"]) ?? true
        ChildView(node: node, model: model)
            .allowsHitTesting(!absorbing)
            .overlay {
                if absorbing { Rectangle().hitFill() }
            }
    }
}

// MARK: - IgnorePointer

/// Flutter `IgnorePointer` (`ignoring` default true), RenderIgnorePointer
/// `hitTest` (proxy_box.dart:3751-3752): ignoring, neither it nor anything
/// inside it is hit, so the hit goes on to what is behind it; not ignoring,
/// it is its child.
@MainActor
struct IgnorePointerView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .allowsHitTesting(!(Props.bool(node["ignoring"]) ?? true))
    }
}
#endif
