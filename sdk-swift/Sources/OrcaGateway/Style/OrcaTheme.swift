#if canImport(SwiftUI)
import SwiftUI

/// What the host app sets for the views an Orca page draws, the Swift side
/// of the `ThemeData` a Flutter host gives its MaterialApp. For now: a
/// button style per button type, as `elevatedButtonTheme`,
/// `outlinedButtonTheme` and `textButtonTheme`.
///
///     OrcaApp(client: client, path: "home")
///         .orcaTheme(OrcaTheme(elevatedButton: OrcaButtonStyle { configuration in
///             configuration.label
///                 .padding(.horizontal, 20).padding(.vertical, 12)
///                 .background(Color.orange, in: Capsule())
///                 .foregroundColor(.white)
///                 .opacity(configuration.isPressed ? 0.7 : 1)
///         }))
///
/// The server wins: a button whose node carries its own style props
/// (ElevatedButton `backgroundColor`, `foregroundColor`, `borderRadius`,
/// `padding`; OutlinedButton `color`, `borderColor`; TextButton `color`) is
/// drawn with those, not with the host style.
public struct OrcaTheme {
    public var elevatedButton: OrcaButtonStyle?
    public var outlinedButton: OrcaButtonStyle?
    public var textButton: OrcaButtonStyle?

    public init(elevatedButton: OrcaButtonStyle? = nil, outlinedButton: OrcaButtonStyle? = nil,
                textButton: OrcaButtonStyle? = nil) {
        self.elevatedButton = elevatedButton
        self.outlinedButton = outlinedButton
        self.textButton = textButton
    }

    /// The server props that style each button type.
    static let serverStyleProps: [String: [String]] = [
        "ElevatedButton": ["backgroundColor", "foregroundColor", "borderRadius", "padding"],
        "OutlinedButton": ["color", "borderColor"],
        "TextButton": ["color"],
    ]

    /// The host style for a button node, or nil when the host set none for
    /// its type or the server styled the button itself.
    func buttonStyle(for node: ResolvedNode) -> OrcaButtonStyle? {
        let serverStyled = (Self.serverStyleProps[node.type] ?? []).contains { node[$0] != nil }
        guard !serverStyled else { return nil }
        switch node.type {
        case "ElevatedButton": return elevatedButton
        case "OutlinedButton": return outlinedButton
        case "TextButton": return textButton
        default: return nil
        }
    }
}

/// A button style made from a closure, for `OrcaTheme`.
public struct OrcaButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    public init<Body: View>(@ViewBuilder _ make: @escaping (Configuration) -> Body) {
        self.make = { AnyView(make($0)) }
    }

    public func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

private struct OrcaThemeKey: EnvironmentKey {
    static let defaultValue = OrcaTheme()
}

extension EnvironmentValues {
    /// The host's theme for Orca pages; empty by default.
    public var orcaTheme: OrcaTheme {
        get { self[OrcaThemeKey.self] }
        set { self[OrcaThemeKey.self] = newValue }
    }
}

extension View {
    /// Styles the Orca pages inside this view (OrcaApp, OrcaPageView).
    public func orcaTheme(_ theme: OrcaTheme) -> some View {
        environment(\.orcaTheme, theme)
    }
}
#endif
