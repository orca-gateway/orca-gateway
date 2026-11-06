#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// T4.5: Stack, Positioned and ClipRRect (23b.30), in a real SwiftUI host
/// (the `layout` helper of NativeWidgetTests).
@MainActor
final class StackTests: XCTestCase {
    let host = NativeWidgetTests()

    func testTheStackIsAsBigAsItsLargestChildAndCentresIt() {
        let frames = host.layout(width: 400, height: 400) {
            StackLayout(alignment: .center, expand: false) {
                Color.red.frame(width: 200, height: 100).record("image")
                Color.blue.frame(width: 50, height: 20).record("label")
            }
            .record("stack")
        }
        XCTAssertEqual(frames["stack"]?.size, CGSize(width: 200, height: 100))
        XCTAssertEqual(frames["label"]?.minX, 75)
        XCTAssertEqual(frames["label"]?.minY, 40)
    }

    func testPositionedChildrenSitByTheirEdges() {
        let frames = host.layout(width: 400, height: 400) {
            StackLayout(alignment: .center, expand: false) {
                Color.red.frame(width: 300, height: 160).record("image")
                Color.orange.frame(width: 60, height: 24).record("badge")
                    .layoutValue(key: PositionedKey.self, value: PositionedSpec(top: 12, right: 12))
                Color.white.record("bar").frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutValue(key: PositionedKey.self, value: PositionedSpec(right: 0, bottom: 0, left: 0, height: 40))
            }
        }
        XCTAssertEqual(frames["badge"], CGRect(x: 300 - 12 - 60, y: 12, width: 60, height: 24))
        XCTAssertEqual(frames["bar"], CGRect(x: 0, y: 120, width: 300, height: 40))
    }

    func testExpandFillsWhatItIsOffered() {
        let frames = host.layout(width: 320, height: 200) {
            StackLayout(alignment: .topLeading, expand: true) {
                Color.red.frame(width: 10, height: 10).record("small")
            }
            .record("stack")
        }
        XCTAssertEqual(frames["stack"]?.size, CGSize(width: 320, height: 200))
    }

    func testPositionedSpecFollowsFlutter() {
        let both = PositionedSpec(right: 10, left: 10)
        XCTAssertEqual(both.width(in: 100), 80)
        let fromRight = PositionedSpec(right: 10, width: 30)
        XCTAssertEqual(fromRight.x(width: 30, in: 100, alignment: 0.5), 60)
        let open = PositionedSpec(top: 0)
        XCTAssertEqual(open.x(width: 20, in: 100, alignment: 0.5), 40)
        XCTAssertEqual(open.y(height: 20, in: 100, alignment: 0.5), 0)
    }
}
#endif
