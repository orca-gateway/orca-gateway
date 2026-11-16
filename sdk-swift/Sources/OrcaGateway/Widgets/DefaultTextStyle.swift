#if canImport(SwiftUI)
import SwiftUI

/// Flutter `DefaultTextStyle` as the builder makes it (LB:588-601): the
/// replacing constructor (FW widgets/text.dart:63), not `.merge`, so the
/// Texts below draw its style on the engine's defaults, never on the
/// ambient style, and a DTS inside it replaces it whole (design D7). It
/// hands down `style`, `textAlign`, `maxLines` and `overflow` (?? clip);
/// a Text lays its own fields over them (`TextStyles.layer`). RichText
/// never reads it. Layout is its child's.
@MainActor
struct DefaultTextStyleView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        ChildView(node: node, model: model)
            .environment(\.orcaDefaultTextStyle, TextStyles.Layer(
                style: node["style"], textAlign: node["textAlign"]?.stringValue,
                maxLines: node["maxLines"]?.intValue, overflow: node["overflow"]?.stringValue ?? "clip"))
    }
}

/// The DefaultTextStyle above this point; nil, the default: none, so a
/// Text draws on the ambient style as it always has. A Material host sets
/// it back to nil, as Flutter's Material resets it (MUI material.dart:
/// 470-474): the whole Scaffold (its drawers are drawn by the app's drawer
/// host, above every page, so no DTS reaches them), the whole AppBar
/// toolbar (leading, title, actions: `AppBarToolbar`, so SliverAppBar's
/// row as well), Card, the three buttons (ElevatedButton, TextButton,
/// OutlinedButton), the FloatingActionButton and InkWell's child.
/// IconButton has no Material and passes it through.
private struct OrcaDefaultTextStyleKey: EnvironmentKey {
    static let defaultValue: TextStyles.Layer? = nil
}

extension EnvironmentValues {
    var orcaDefaultTextStyle: TextStyles.Layer? {
        get { self[OrcaDefaultTextStyleKey.self] }
        set { self[OrcaDefaultTextStyleKey.self] = newValue }
    }
}

extension TextStyleProps {
    /// This style on Flutter's engine defaults, the base a Text under a
    /// DefaultTextStyle draws on: size ?? 14, colour ?? white, weight ??
    /// regular, so nothing ambient shows through. The size counts as sent,
    /// so Dynamic Type follows the Text's rule (`font`): the system font
    /// at that fixed size, a family scaled from it.
    var onEngineBase: TextStyleProps {
        var style = self
        style.size = size ?? Self.engineSize
        style.color = color ?? Self.engineColor
        style.weight = weight ?? .regular
        return style
    }
}
#endif
