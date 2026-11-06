import Foundation
import XCTest

@testable import OrcaGatewayCore

/// T4.4: the Swift icon table covers every Material name the Flutter SDK
/// knows, so a page draws the same icons on both. Reads Dart's
/// `_materialIconMap` from sdk/lib/src/builders/builder_helpers.dart (the
/// monorepo; the mirror ships no tests).
final class IconNamesTests: XCTestCase {
    func dartIconNames() throws -> [String] {
        let source = String(decoding: try Fixtures.data("sdk/lib/src/builders/builder_helpers.dart"), as: UTF8.self)
        let start = try XCTUnwrap(source.range(of: "const _materialIconMap"))
        let end = try XCTUnwrap(source.range(of: "};", range: start.upperBound..<source.endIndex))
        let body = source[start.upperBound..<end.lowerBound]
        let pattern = try NSRegularExpression(pattern: #"'([a-z0-9_]+)':\s*Icons\."#)
        let text = String(body)
        return pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    func testEveryFlutterNameHasASymbol() throws {
        let names = try dartIconNames()
        XCTAssertEqual(names.count, 156)
        let missing = names.filter { IconNames.table[$0] == nil }
        XCTAssertEqual(missing, [], "Material names with no SF Symbol")
        let extra = Set(IconNames.table.keys).subtracting(names)
        XCTAssertEqual(extra, [], "names Flutter does not know")
    }

    func testUnknownNamesDrawAFilledCircleLikeFlutter() {
        XCTAssertEqual(IconNames.symbol(for: nil), "circle.fill")
        XCTAssertEqual(IconNames.symbol(for: "no_such_icon"), "circle.fill")
        XCTAssertEqual(IconNames.symbol(for: "search"), "magnifyingglass")
        XCTAssertEqual(IconNames.symbol(for: "favorite_border"), "heart")
        XCTAssertTrue(IconNames.isRotated("more_vert"))
        XCTAssertFalse(IconNames.isRotated("more_horiz"))
    }
}
