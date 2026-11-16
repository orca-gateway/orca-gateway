#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A3.2, A3.4 (Align) and A3.7: the sizing wrappers drawn as Flutter's
/// render objects lay them out (layout_builders.dart :265-286, :487-521).
/// Each test draws a page through the real NodeView, its children solid
/// Containers, and finds each colour's frame in the pixels. The six types
/// are advertised (A3.1), so the page model here uses the standard registry.
@MainActor
final class SizingTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: A3.2 AspectRatio

    /// A3.2: AspectRatio 16:9 in a 320-wide parent is 320 by 180, its child
    /// given that size.
    func testA3_2AspectRatioSixteenNineIn320WideIs180Tall() throws {
        let pixels = try draw([
            node("ratio", "AspectRatio", ["aspectRatio": .double(16.0 / 9.0)], ["red"]),
            node("red", "Container", ["color": "#FF0000"]),
        ], width: 320, height: 400)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 320, height: 180))
    }

    /// A3.2: the width wins, then a parent too short caps the height and the
    /// width follows it (`_applyAspectRatio`); no aspectRatio is 1.
    func testA3_2AspectRatioFitsAShortParentAndDefaultsToSquare() throws {
        let short = try draw([
            node("ratio", "AspectRatio", ["aspectRatio": .double(16.0 / 9.0)], ["red"]),
            node("red", "Container", ["color": "#FF0000"]),
        ], width: 320, height: 90)
        assertFrame(short.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 160, height: 90))

        let square = try draw([
            node("ratio", "AspectRatio", [:], ["red"]),
            node("red", "Container", ["color": "#FF0000"]),
        ], width: 120, height: 400)
        assertFrame(square.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 120, height: 120))
    }

    // MARK: A3.2 FractionallySizedBox

    /// A3.2: widthFactor 0.5 takes half the width offered; the axis with no
    /// factor keeps what the parent offers (here all of it, a Container fills).
    func testA3_2FractionallySizedBoxHalfTakesHalf() throws {
        let pixels = try draw([
            node("half", "FractionallySizedBox", ["widthFactor": 0.5], ["red"]),
            node("red", "Container", ["color": "#FF0000"]),
        ], width: 320, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 160, height: 200))
    }

    /// A3.2: in a box the parent forces, the box keeps the forced size and
    /// the half-sized child sits at `alignment`, the centre by default.
    func testA3_2FractionallySizedBoxPlacesItsChildByAlignment() throws {
        for (alignment, origin) in [(nil, CGPoint(x: 80, y: 50)), ("topLeft", CGPoint(x: 0, y: 0)),
                                    ("bottomRight", CGPoint(x: 160, y: 100))] as [(String?, CGPoint)] {
            var props: [String: JSONValue] = ["widthFactor": 0.5, "heightFactor": 0.5]
            if let alignment { props["alignment"] = .string(alignment) }
            let pixels = try draw([
                node("box", "SizedBox", ["width": 320, "height": 200], ["half"]),
                node("half", "FractionallySizedBox", props, ["red"]),
                node("red", "Container", ["color": "#FF0000"]),
            ], width: 320, height: 200)
            assertFrame(pixels.bounds(of: Pixels.isRed),
                        CGRect(origin: origin, size: CGSize(width: 160, height: 100)))
        }
    }

    // MARK: A3.2 ConstrainedBox

    /// A3.2: a child that would fill is held to the box's max.
    func testA3_2ConstrainedBoxHoldsItsChildToItsMax() throws {
        let pixels = try draw([
            node("box", "ConstrainedBox", ["constraints": ["maxWidth": 150, "maxHeight": 60]], ["red"]),
            node("red", "Container", ["color": "#FF0000"]),
        ], width: 320, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 150, height: 60))
    }

    /// A3.2: a smaller child still makes the box its min (the green box
    /// below starts 40 down, not 20).
    func testA3_2ConstrainedBoxIsAtLeastItsMin() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["box", "green"]),
            node("box", "ConstrainedBox", ["constraints": ["minWidth": 100, "minHeight": 40]], ["red"]),
            box("red", "#FF0000", 20, 20), box("green", "#00FF00", 10, 10),
        ], width: 320, height: 200)
        XCTAssertEqual(try XCTUnwrap(pixels.bounds(of: Self.isGreen)).minY, 40, accuracy: Self.accuracy)
    }

    /// A3.2: the box's constraints apply within the parent's (`enforce`): a
    /// min of 400 in a 320-wide parent is 320, and a parent that forces its
    /// size wins over a smaller max.
    func testA3_2ConstrainedBoxStaysInsideTheParentsConstraints() throws {
        let wide = try draw([
            node("box", "ConstrainedBox", ["constraints": ["minWidth": 400, "maxHeight": 50]], ["red"]),
            node("red", "Container", ["color": "#FF0000"]),
        ], width: 320, height: 200)
        assertFrame(wide.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 320, height: 50))

        let forced = try draw([
            node("sized", "SizedBox", ["width": 200, "height": 100], ["box"]),
            node("box", "ConstrainedBox", ["constraints": ["maxWidth": 50]], ["red"]),
            node("red", "Container", ["color": "#FF0000"]),
        ], width: 320, height: 200)
        assertFrame(forced.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 200, height: 100))
    }

    // MARK: A3.2 A set width or height within the parent's limits

    // A Container or SizedBox with a set width or height is Flutter's
    // ConstrainedBox(tightFor(width, height)), laid out with `enforce`: the
    // set size is kept within the incoming min and max (container.dart:284,
    // proxy_box.dart:303-313).

    /// A3.2: a set 300 by 20 under min 120 by 40 and max 200 by 60 is 200 by 40.
    func testA3_2ConstrainedBoxHoldsASetSizeContainerWithinItsMinAndMax() throws {
        let pixels = try draw([
            node("box", "ConstrainedBox",
                 ["constraints": ["minWidth": 120, "minHeight": 40, "maxWidth": 200, "maxHeight": 60]], ["red"]),
            box("red", "#FF0000", 300, 20),
        ], width: 320, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 200, height: 40))
    }

    /// A3.2: a min of 100 by 40 raises a set 20 by 20 child to it.
    func testA3_2ConstrainedBoxMinRaisesASmallerSetSizeContainer() throws {
        let pixels = try draw([
            node("box", "ConstrainedBox", ["constraints": ["minWidth": 100, "minHeight": 40]], ["red"]),
            box("red", "#FF0000", 20, 20),
        ], width: 320, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 100, height: 40))
    }

    /// A3.2: the min reaches the box's own child only: under a Center, which
    /// loosens it, the 20 by 20 child keeps its size, centred.
    func testA3_2ConstrainedBoxMinDoesNotReachAGrandchild() throws {
        let pixels = try draw([
            node("box", "ConstrainedBox", ["constraints": ["minWidth": 100, "minHeight": 40]], ["center"]),
            node("center", "Center", [:], ["red"]),
            box("red", "#FF0000", 20, 20),
        ], width: 320, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 150, y: 90, width: 20, height: 20))
    }

    /// A3.2: in a 320 Row a Flexible's loose share (160) caps its set 300
    /// wide child; the Expanded one fills the other 160, in either order.
    func testA3_2AFlexiblesShareCapsItsSetWidthContainer() throws {
        for order in [["flexible", "expanded"], ["expanded", "flexible"]] {
            let pixels = try draw([
                node("sized", "SizedBox", ["width": 320], ["row"]),
                node("row", "Row", [:], order),
                node("flexible", "Flexible", [:], ["red"]),
                box("red", "#FF0000", 300, 20),
                node("expanded", "Expanded", [:], ["green"]),
                node("green", "Container", ["color": "#00FF00", "height": 20]),
            ], width: 400, height: 100)
            let redX: CGFloat = order[0] == "flexible" ? 0 : 160
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: redX, y: 0, width: 160, height: 20))
            assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 160 - redX, y: 0, width: 160, height: 20))
        }
    }

    /// A3.2: a stretched Column forces its width on a set 100 wide child
    /// (320); a Column at start leaves it 100.
    func testA3_2AStretchedColumnForcesItsWidthOnASetWidthContainer() throws {
        for (cross, width) in [("stretch", 320), ("start", 100)] as [(String, CGFloat)] {
            let pixels = try draw([
                node("col", "Column", ["crossAxisAlignment": .string(cross)], ["red"]),
                box("red", "#FF0000", 100, 20),
            ], width: 320, height: 200)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: width, height: 20))
        }
    }

    /// A3.2: a plain Row (no flex child, an HStack) leaves its children's
    /// width unbounded, as Flutter's does, so the HStack's share is no max:
    /// a set 48 wide box beside a Text keeps 48, and a set 250 wide one
    /// keeps 250 beside a Text that wants more than the 70 left.
    func testA3_2APlainRowKeepsASetWidthContainersWidth() throws {
        for (width, text) in [(48.0, "Hello"), (250.0, "Hello there, this is a long label")] {
            let pixels = try draw([
                node("row", "Row", ["crossAxisAlignment": "start"], ["red", "text"]),
                box("red", "#FF0000", width, 20),
                node("text", "Text", ["data": .string(text)]),
            ], width: 320, height: 100)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: width, height: 20))
        }
    }

    /// A3.2: an AspectRatio in a plain Row bounds what is below it, even past
    /// a Center: it is 200 by 200 (from the page's 200 height), the Center
    /// loosens that to a max of 200, so a set 300 wide child is 200, centred.
    func testA3_2AnAspectRatioInAPlainRowBoundsASetWidthContainerBelowACenter() throws {
        let pixels = try draw([
            node("row", "Row", [:], ["ratio"]),
            node("ratio", "AspectRatio", ["aspectRatio": 1], ["center"]),
            node("center", "Center", [:], ["red"]),
            box("red", "#FF0000", 300, 20),
        ], width: 320, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 90, width: 200, height: 20))
    }

    // MARK: A3.2 LimitedBox

    /// A3.2: under a bounded parent LimitedBox does nothing.
    func testA3_2LimitedBoxDoesNothingUnderABoundedParent() throws {
        let pixels = try draw([
            node("limit", "LimitedBox", ["maxWidth": 50, "maxHeight": 50], ["red"]),
            node("red", "Container", ["color": "#FF0000"]),
        ], width: 320, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 320, height: 200))
    }

    #if canImport(UIKit)
    /// A3.2: a SingleChildScrollView leaves its content's height unbounded
    /// (Flutter single_child_scroll_view.dart:500-501), so LimitedBox caps
    /// it at maxHeight: the Container that fills it is 50 tall. Drawn in a
    /// real scroll view, which ImageRenderer does not draw (so iOS only).
    func testA3_2LimitedBoxCapsTheUnboundedAxisInAScrollView() throws {
        let pixels = try hosted([
            node("scroll", "SingleChildScrollView", [:], ["limit"]),
            node("limit", "LimitedBox", ["maxHeight": 50], ["red"]),
            node("red", "Container", ["color": "#FF0000"]),
        ], width: 100, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 100, height: 50))
    }
    #endif

    // MARK: A3.4 Align

    /// A3.4: with no factor Align fills a bounded parent and puts its child
    /// at `alignment`, the centre when absent.
    func testA3_4AlignPutsItsChildAtItsAlignment() throws {
        for (alignment, origin) in [(nil, CGPoint(x: 90, y: 40)), ("topLeft", CGPoint(x: 0, y: 0)),
                                    ("centerRight", CGPoint(x: 180, y: 40)),
                                    ("bottomCenter", CGPoint(x: 90, y: 80))] as [(String?, CGPoint)] {
            let pixels = try draw([
                node("align", "Align", alignment.map { ["alignment": .string($0)] } ?? [:], ["red"]),
                box("red", "#FF0000", 20, 20),
            ], width: 200, height: 100)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(origin: origin, size: CGSize(width: 20, height: 20)))
        }
    }

    /// A3.4: a factor makes that axis the child's size times it: 40 by 30
    /// around a 20 by 20 child at bottomRight, the green box 30 down.
    func testA3_4AlignSizeFactorsShrinkWrapItsChild() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["align", "green"]),
            node("align", "Align", ["alignment": "bottomRight", "widthFactor": 2, "heightFactor": 1.5], ["red"]),
            box("red", "#FF0000", 20, 20), box("green", "#00FF00", 10, 10),
        ], width: 200, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 20, y: 10, width: 20, height: 20))
        XCTAssertEqual(try XCTUnwrap(pixels.bounds(of: Self.isGreen)).minY, 30, accuracy: Self.accuracy)
    }

    /// A3.4: a parent that forces its size wins over a factor (Flutter's
    /// `constrain`): Align is the whole 100 by 100 box, the child at topLeft.
    func testA3_4AlignInAForcedBoxTakesItsSize() throws {
        let pixels = try draw([
            node("sized", "SizedBox", ["width": 100, "height": 100], ["align"]),
            node("align", "Align", ["alignment": "topLeft", "widthFactor": 2], ["red"]),
            box("red", "#FF0000", 20, 20),
        ], width: 200, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    /// A3.4: Flutter's Alignment is absolute: topLeft stays on the left in
    /// right-to-left.
    func testA3_4AlignTopLeftStaysLeftInRightToLeft() throws {
        let pixels = try draw([
            node("align", "Align", ["alignment": "topLeft"], ["red"]),
            box("red", "#FF0000", 20, 20),
        ], width: 200, height: 100, direction: .rightToLeft)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 20, height: 20))
    }

    // MARK: A3.7 FittedBox

    /// A3.7: contain (the default) scales a 40 by 20 child up to 100 by 50
    /// in a 100 by 100 box, centred, even with `alignment` set (Flutter's
    /// builder does not read it).
    func testA3_7FittedBoxContainScalesItsChildCentred() throws {
        for props in [[:], ["fit": "contain", "alignment": "topLeft"]] as [[String: JSONValue]] {
            let pixels = try draw([
                node("sized", "SizedBox", ["width": 100, "height": 100], ["fitted"]),
                node("fitted", "FittedBox", props, ["red"]),
                box("red", "#FF0000", 40, 20),
            ], width: 100, height: 100)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 25, width: 100, height: 50))
        }
    }

    /// A3.7: cover scales the child until it covers the box (5x: 200 by
    /// 100), centred and not clipped (Flutter's FittedBox clips nothing by
    /// default), so it overflows the 100 by 100 box by 50 on each side.
    func testA3_7FittedBoxCoverCoversTheBoxCentred() throws {
        let pixels = try draw(fitted("cover", child: CGSize(width: 40, height: 20)), width: 200, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 50, width: 200, height: 100))
    }

    /// A3.7: scaleDown leaves a child that fits at its size, centred, and
    /// shrinks one that does not as contain does.
    func testA3_7FittedBoxScaleDownOnlyShrinks() throws {
        let small = try draw(fitted("scaleDown", child: CGSize(width: 40, height: 20)), width: 200, height: 200)
        assertFrame(small.bounds(of: Pixels.isRed), CGRect(x: 80, y: 90, width: 40, height: 20))

        let big = try draw(fitted("scaleDown", child: CGSize(width: 200, height: 100)), width: 200, height: 200)
        assertFrame(big.bounds(of: Pixels.isRed), CGRect(x: 50, y: 75, width: 100, height: 50))
    }

    /// A3.7: the other fits as Flutter's `applyBoxFit`, centred in the box
    /// at (50, 50).
    func testA3_7FittedBoxOtherFits() throws {
        let child = CGSize(width: 40, height: 20)
        for (fit, frame) in [("fill", CGRect(x: 50, y: 50, width: 100, height: 100)),
                             ("fitWidth", CGRect(x: 50, y: 75, width: 100, height: 50)),
                             ("fitHeight", CGRect(x: 0, y: 50, width: 200, height: 100)),
                             ("none", CGRect(x: 80, y: 90, width: 40, height: 20))] {
            let pixels = try draw(fitted(fit, child: child), width: 200, height: 200)
            assertFrame(pixels.bounds(of: Pixels.isRed), frame)
        }
    }

    // MARK: helpers

    static func isGreen(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.g > 200 && p.r < 60 && p.b < 60
    }

    /// A FittedBox with `fit` in a 100 by 100 SizedBox in the middle of the
    /// page (at 50, 50), its child a red box of `child`'s size.
    func fitted(_ fit: String, child: CGSize) -> [JSONValue] {
        [
            node("center", "Center", [:], ["sized"]),
            node("sized", "SizedBox", ["width": 100, "height": 100], ["fitted"]),
            node("fitted", "FittedBox", ["fit": .string(fit)], ["red"]),
            box("red", "#FF0000", Double(child.width), Double(child.height)),
        ]
    }

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    /// A wire node: a Column holds many children, every other type one.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:],
              _ children: [String] = []) -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": "layout",
            "childMode": .string(type == "Column" ? "multi" : "single"), "props": .object(props),
            "children": .array(children.map { .string($0) }), "watches": [],
        ]
    }

    /// A solid Container of `hex`, `width` by `height`.
    func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)])
    }

    func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self))
    }

    func rootId(_ nodes: [JSONValue]) throws -> String {
        guard case .object(let first)? = nodes.first else { return try XCTUnwrap(nil as String?, "no root node") }
        return try XCTUnwrap(first["id"]?.stringValue, "no root id")
    }

    /// The first node drawn with ImageRenderer at scale 1 in a `width` by
    /// `height` box from the top leading corner.
    func draw(_ nodes: [JSONValue], width: CGFloat, height: CGFloat,
              direction: LayoutDirection = .leftToRight) throws -> Pixels {
        let view = NodeView(id: try rootId(nodes), model: try model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
            .environment(\.layoutDirection, direction)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }

    #if canImport(UIKit)
    /// The first node in a UIKit window `width` by `height`, for a scroll
    /// view's content, which ImageRenderer does not draw. Scale 1.
    func hosted(_ nodes: [JSONValue], width: CGFloat, height: CGFloat) throws -> Pixels {
        let size = CGSize(width: width, height: height)
        let host = UIHostingController(rootView: NodeView(id: try rootId(nodes), model: try model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
            .ignoresSafeArea())
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }
    #endif
}
#endif
