import XCTest

@testable import OrcaGatewayCore

/// A4.3, the core half of ColorFiltered: the Flutter builder's
/// `_parseBlendMode` (layout_builders.dart:758-783) maps 21 names to a
/// `BlendMode`; anything else, missing, unknown or in the wrong case, is
/// srcATop. The same cases as Kotlin's BlendModesTest.
final class BlendModesTests: XCTestCase {
    static let flutterNames = [
        "srcOver", "srcIn", "srcATop", "dstOver", "dstIn", "dstATop", "multiply", "screen", "overlay", "darken",
        "lighten", "colorDodge", "colorBurn", "hardLight", "softLight", "difference", "exclusion", "hue",
        "saturation", "color", "luminosity",
    ]

    /// A4.3: each of the 21 names is its own mode, and there are no others.
    func testA4_3EachOfThe21FlutterNamesIsItsOwnMode() {
        for name in Self.flutterNames {
            XCTAssertEqual(OrcaBlendMode.of(name).rawValue, name, name)
        }
        XCTAssertEqual(Set(OrcaBlendMode.allCases.map(\.rawValue)), Set(Self.flutterNames))
        XCTAssertEqual(OrcaBlendMode.allCases.count, 21)
    }

    /// A4.3: a missing blend mode is srcATop.
    func testA4_3AMissingBlendModeIsSrcATop() {
        XCTAssertEqual(OrcaBlendMode.of(nil), .srcATop)
    }

    /// A4.3: a name Flutter does not map is srcATop, Flutter's other
    /// BlendMode values included.
    func testA4_3AnUnknownBlendModeIsSrcATop() {
        for name in ["", "normal", "plus", "modulate", "xor", "clear", "src", "dst", "srcOut", "sourceAtop", "blur"] {
            XCTAssertEqual(OrcaBlendMode.of(name), .srcATop, name)
        }
    }

    /// A4.3: the names are matched as they are: the wrong case is srcATop.
    func testA4_3ABlendModeInTheWrongCaseIsSrcATop() {
        for name in ["Multiply", "MULTIPLY", "srcin", "SrcIn", "dstatop", "ColorDodge", "src_over", " multiply"] {
            XCTAssertEqual(OrcaBlendMode.of(name), .srcATop, name)
        }
    }
}
