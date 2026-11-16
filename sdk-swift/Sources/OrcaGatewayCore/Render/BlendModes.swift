import Foundation

/// The blend modes a ColorFiltered can use, Flutter's `BlendMode` as the
/// Flutter builder's `_parseBlendMode` reads them (layout_builders.dart
/// :758-783): 21 names, each the case of the same name. How each mode
/// combines a colour (source) with a pixel (destination) is Flutter's
/// (dart:ui `BlendMode`); the UI layers draw it. Named `OrcaBlendMode`, not
/// `BlendMode`, so it never clashes with SwiftUI's in a module that imports
/// both.
public enum OrcaBlendMode: String, CaseIterable, Sendable {
    case srcOver, srcIn, srcATop, dstOver, dstIn, dstATop
    case multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, hardLight, softLight
    case difference, exclusion, hue, saturation, color, luminosity

    /// The mode named `value` exactly as Flutter spells it; srcATop when it
    /// is missing, unknown or in another case.
    public static func of(_ value: String?) -> OrcaBlendMode {
        value.flatMap(OrcaBlendMode.init(rawValue:)) ?? .srcATop
    }
}
