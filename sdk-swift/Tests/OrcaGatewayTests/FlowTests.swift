#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A3.3 (ui) and A3.6: Wrap, Offstage and SafeArea drawn as Flutter lays
/// them out (layout_builders.dart :188-201, :295-303, :448-453; RenderWrap,
/// RenderOffstage, SafeArea). Sizes and positions come from pages drawn
/// through the real NodeView, their boxes solid Containers, each colour's
/// frame found in the pixels; taps, a child kept mounted and the device's
/// safe-area insets need a UIKit window (iOS only). The three types (and
/// IntrinsicHeight) are advertised (A3.1), so the page model here uses the
/// standard registry.
@MainActor
final class FlowTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: A3.3 Wrap

    /// A3.3: in 100 wide, spacing 10 and runSpacing 5, the third 40 wide box
    /// does not fit after the first two and opens a second run 5 below the
    /// first (as tall as its tallest child, 20). The Wrap (grey behind) hugs
    /// its widest run and its runs: 90 by 35.
    func testA3_3WrapMovesAChildThatDoesNotFitToTheNextRun() throws {
        let pixels = try draw([
            node("grey", "Container", ["color": "#808080"], ["wrap"]),
            node("wrap", "Wrap", ["spacing": 10, "runSpacing": 5], ["red", "green", "blue"]),
            box("red", "#FF0000", 40, 10), box("green", "#00FF00", 40, 20), box("blue", "#0000FF", 40, 10),
        ], width: 100, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 40, height: 10))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 50, y: 0, width: 40, height: 20))
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 0, y: 25, width: 40, height: 10))
        assertFrame(pixels.bounds(of: Self.isGrey), CGRect(x: 0, y: 0, width: 90, height: 35))
    }

    /// A3.3: `alignment` shares a run's free space: the 86 wide red box
    /// fills the first run (the Wrap is 86 wide), the second run (two 20
    /// wide boxes, spacing 10) leaves 36 of it.
    func testA3_3WrapAlignmentSharesARunsFreeSpace() throws {
        for (alignment, green, blue) in [
            ("start", 0, 30), ("end", 36, 66), ("center", 18, 48),
            ("spaceBetween", 0, 66), ("spaceAround", 9, 57), ("spaceEvenly", 12, 54),
        ] as [(String, CGFloat, CGFloat)] {
            let pixels = try draw([
                node("wrap", "Wrap", ["spacing": 10, "alignment": .string(alignment)], ["red", "green", "blue"]),
                box("red", "#FF0000", 86, 10), box("green", "#00FF00", 20, 10), box("blue", "#0000FF", 20, 10),
            ], width: 100, height: 200)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 86, height: 10), alignment)
            assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: green, y: 10, width: 20, height: 10), alignment)
            assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: blue, y: 10, width: 20, height: 10), alignment)
        }
    }

    /// A3.3: `crossAxisAlignment` places a child in its run's height (30,
    /// the green box's): start at the top, center 10 down, end 20 down;
    /// stretch and baseline are start, as the Flutter builder reads them.
    /// The second run starts 4 (runSpacing) below the first.
    func testA3_3WrapCrossAxisAlignmentPlacesAChildInItsRun() throws {
        for (cross, red) in [("start", 0), ("center", 10), ("end", 20), ("stretch", 0), ("baseline", 0)]
            as [(String, CGFloat)] {
            let pixels = try draw([
                node("wrap", "Wrap", ["runSpacing": 4, "crossAxisAlignment": .string(cross)],
                     ["red", "green", "blue"]),
                box("red", "#FF0000", 50, 10), box("green", "#00FF00", 50, 30), box("blue", "#0000FF", 50, 20),
            ], width: 100, height: 200)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: red, width: 50, height: 10), cross)
            assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 50, y: 0, width: 50, height: 30), cross)
            assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 0, y: 34, width: 50, height: 20), cross)
        }
    }

    /// A3.3: a parent forcing the width (a stretched Column) makes the Wrap
    /// that wide, so a lone child's free space is the whole rest: center
    /// puts the 40 wide box at 30 of 100.
    func testA3_3AParentForcingTheWidthSizesTheWrap() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "stretch"], ["wrap"]),
            node("wrap", "Wrap", ["alignment": "center"], ["red"]),
            box("red", "#FF0000", 40, 10),
        ], width: 100, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 30, y: 0, width: 40, height: 10))
    }

    /// A3.3: in right-to-left the Wrap is the mirror image (it takes the
    /// ambient direction, as Flutter's Wrap with no textDirection): the
    /// first run starts at the right and the second run too.
    func testA3_3WrapMirrorsInRightToLeft() throws {
        let pixels = try draw([
            node("wrap", "Wrap", ["spacing": 10, "runSpacing": 5], ["red", "green", "blue"]),
            box("red", "#FF0000", 40, 10), box("green", "#00FF00", 40, 20), box("blue", "#0000FF", 40, 10),
        ], width: 100, height: 200, direction: .rightToLeft)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 60, y: 0, width: 40, height: 10))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 10, y: 0, width: 40, height: 20))
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 60, y: 25, width: 40, height: 10))
    }

    /// A3.3: `direction: vertical` (the Flutter builder reads it; the engine
    /// cannot send it) runs down 100 of height, then into a second column 5
    /// (runSpacing) after the first, 20 wide; in right-to-left the columns
    /// stack from the right, the mirror image.
    func testA3_3AVerticalWrapRunsDownThenAcross() throws {
        for (direction, red, green, blue) in [
            (LayoutDirection.leftToRight, 0, 0, 25), (.rightToLeft, 90, 80, 65),
        ] as [(LayoutDirection, CGFloat, CGFloat, CGFloat)] {
            let pixels = try draw([
                node("wrap", "Wrap", ["direction": "vertical", "spacing": 10, "runSpacing": 5],
                     ["red", "green", "blue"]),
                box("red", "#FF0000", 10, 40), box("green", "#00FF00", 20, 40), box("blue", "#0000FF", 10, 40),
            ], width: 100, height: 100, direction: direction)
            let name = "\(direction)"
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: red, y: 0, width: 10, height: 40), name)
            assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: green, y: 50, width: 20, height: 40), name)
            assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: blue, y: 0, width: 10, height: 40), name)
        }
    }

    /// A3.3: IntrinsicHeight around a Wrap whose three chips fit on one line
    /// is one chip tall (RenderWrap's max intrinsic height is a layout at
    /// the width offered): the marker below starts at 20.
    func testA3_3IntrinsicHeightAroundAOneLineWrapIsOneChipTall() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["intrinsic", "marker"]),
            node("intrinsic", "IntrinsicHeight", [:], ["wrap"]),
            node("wrap", "Wrap", ["spacing": 5], ["red", "green", "blue"]),
            box("red", "#FF0000", 30, 20), box("green", "#00FF00", 30, 20), box("blue", "#0000FF", 30, 20),
            box("marker", "#FF00FF", 10, 10),
        ], width: 300, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 30, height: 20))
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 70, y: 0, width: 30, height: 20))
        assertFrame(pixels.bounds(of: Self.isMagenta), CGRect(x: 0, y: 20, width: 10, height: 10))
    }

    /// A3.3: a vertical Wrap's max intrinsic height is its children's
    /// heights summed with no spacing (RenderWrap.computeMaxIntrinsicHeight),
    /// 120: IntrinsicHeight makes it that tall, so the third child no longer
    /// fits under the first two (40 + 10 + 40 + 10 + 40 = 140) and opens a
    /// second column; the marker starts at 120.
    func testA3_3IntrinsicHeightAroundAVerticalWrapSumsTheChildrenWithoutSpacing() throws {
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "start"], ["intrinsic", "marker"]),
            node("intrinsic", "IntrinsicHeight", [:], ["wrap"]),
            node("wrap", "Wrap", ["direction": "vertical", "spacing": 10], ["red", "green", "blue"]),
            box("red", "#FF0000", 10, 40), box("green", "#00FF00", 20, 40), box("blue", "#0000FF", 10, 40),
            box("marker", "#FF00FF", 10, 10),
        ], width: 300, height: 200)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 10, height: 40))
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 0, y: 50, width: 20, height: 40))
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 20, y: 0, width: 10, height: 40))
        assertFrame(pixels.bounds(of: Self.isMagenta), CGRect(x: 0, y: 120, width: 10, height: 10))
    }

    // MARK: A3.6 Offstage

    /// A3.6: Offstage (offstage true by default) draws nothing and takes no
    /// space in a Column: the blue box follows the red one directly.
    func testA3_6OffstageByDefaultDrawsNothingAndTakesNoSpace() throws {
        let pixels = try draw(offstage(nil), width: 100, height: 100)
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 40, height: 20))
        XCTAssertNil(pixels.bounds(of: Self.isGreen), "an offstage child is drawn")
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 0, y: 20, width: 40, height: 20))

        let explicit = try draw(offstage(true), width: 100, height: 100)
        XCTAssertNil(explicit.bounds(of: Self.isGreen), "an offstage child is drawn")
        assertFrame(explicit.bounds(of: Self.isBlue), CGRect(x: 0, y: 20, width: 40, height: 20))
    }

    /// A3.6: `offstage: false` is its child as it is.
    func testA3_6OffstageFalseIsItsChild() throws {
        let pixels = try draw(offstage(false), width: 100, height: 100)
        assertFrame(pixels.bounds(of: Self.isGreen), CGRect(x: 0, y: 20, width: 40, height: 20))
        assertFrame(pixels.bounds(of: Self.isBlue), CGRect(x: 0, y: 40, width: 40, height: 20))
    }

    /// A3.6: offstage, it is as small as its parent allows: nothing where
    /// the parent leaves it free, the forced size where the parent forces
    /// one (RenderOffstage sizes to `constraints.smallest`).
    func testA3_6OffstageIsAsSmallAsItsParentAllows() throws {
        let nodes = [node("off", "Offstage", [:], ["green"]), box("green", "#00FF00", 40, 20)]
        let model = try model(nodes)
        let loose = NativeWidgetTests().layout(width: 300, height: 200) {
            NodeView(id: "off", model: model).record("off")
        }
        XCTAssertEqual(try XCTUnwrap(loose["off"]).size, .zero)

        let forced = NativeWidgetTests().layout(width: 300, height: 200) {
            NodeView(id: "off", model: model).environment(\.orcaTight, [.horizontal, .vertical]).record("off")
        }
        XCTAssertEqual(try XCTUnwrap(forced["off"]).size, CGSize(width: 300, height: 200))
    }

    #if canImport(UIKit)
    /// A3.6: offstage, its child takes no taps (a hit where the text field
    /// lies finds no text field); shown again, the same field does.
    func testA3_6OffstageTakesNoTaps() throws {
        let (window, model) = try hosted(fieldPage(hidden: true))
        defer { window.isHidden = true }
        let field = try XCTUnwrap(Self.textField(in: window), "the offstage field left the view tree")
        let centre = field.convert(CGPoint(x: field.bounds.midX, y: field.bounds.midY), to: window)
        XCTAssertFalse(Self.isInField(window.hitTest(centre, with: nil)), "an offstage field takes a tap")

        model.store.dispatch(["hidden": false])
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let shown = try XCTUnwrap(Self.textField(in: window), "no text field")
        XCTAssertTrue(shown === field, "the field was made again")
        let point = shown.convert(CGPoint(x: shown.bounds.midX, y: shown.bounds.midY), to: window)
        XCTAssertTrue(Self.isInField(window.hitTest(point, with: nil)), "a shown field takes no tap")
    }

    /// A3.6: the child stays mounted offstage, as Flutter keeps it: its
    /// onInit (adding 1 to the page state `inits`) runs when the page is
    /// built though it starts offstage, and not again as it is shown, hidden
    /// and shown again; shown, it is drawn.
    func testA3_6ToggledOffstageKeepsItsChildMounted() throws {
        let (window, model) = try hosted(countedPage())
        defer { window.isHidden = true }
        XCTAssertEqual(model.store.value("inits"), 1, "the offstage child was not built")
        XCTAssertNil(try snapshot(window).bounds(of: Self.isGreen), "an offstage child is drawn")

        for hidden in [false, true, false] {
            model.store.dispatch(["hidden": .bool(hidden)])
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertEqual(model.store.value("inits"), 1, "the child was built again")
        assertFrame(try snapshot(window).bounds(of: Self.isGreen), CGRect(x: 0, y: 0, width: 40, height: 20))
    }

    // MARK: A3.6 SafeArea

    /// The window's safe-area insets in the SafeArea tests: top 30, left 10,
    /// bottom 20, right 15 of a 200 by 200 window.
    static let insets = UIEdgeInsets(top: 30, left: 10, bottom: 20, right: 15)

    /// A3.6: SafeArea (every edge by default) keeps its content clear of the
    /// device insets, a page hosted as OrcaPageView hosts it.
    func testA3_6SafeAreaKeepsItsContentClearOfTheInsets() throws {
        let pixels = try safe(["safe": [:]])
        assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 10, y: 30, width: 175, height: 150))
    }

    /// A3.6: an edge flagged false lets the content into that inset; left
    /// and right are the screen's, in right-to-left too.
    func testA3_6SafeAreaEdgesFlaggedFalseLetTheContentIn() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let top = try safe(["safe": ["top": false]], direction: direction)
            assertFrame(top.bounds(of: Pixels.isRed), CGRect(x: 10, y: 0, width: 175, height: 180), "top \(direction)")
            let left = try safe(["safe": ["left": false, "bottom": false]], direction: direction)
            assertFrame(left.bounds(of: Pixels.isRed), CGRect(x: 0, y: 30, width: 185, height: 170),
                        "left, bottom \(direction)")
            let none = try safe(["safe": ["top": false, "bottom": false, "left": false, "right": false]],
                                direction: direction)
            assertFrame(none.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 200, height: 200), "none \(direction)")
        }
    }

    /// A3.6: an inset a SafeArea above took is never added twice, and a
    /// SafeArea below that flags it false does not reach back into it (its
    /// MediaQuery padding is 0 there in Flutter).
    func testA3_6ANestedSafeAreaNeverTakesAnInsetTwice() throws {
        let twice = try safe(["outer": [:], "safe": [:]])
        assertFrame(twice.bounds(of: Pixels.isRed), CGRect(x: 10, y: 30, width: 175, height: 150))
        let reopened = try safe(["outer": [:], "safe": ["top": false, "left": false]])
        assertFrame(reopened.bounds(of: Pixels.isRed), CGRect(x: 10, y: 30, width: 175, height: 150))
        let partly = try safe(["outer": ["top": false], "safe": ["top": false, "bottom": false]])
        assertFrame(partly.bounds(of: Pixels.isRed), CGRect(x: 10, y: 0, width: 175, height: 180))
    }
    #endif

    // MARK: helpers

    static func isGreen(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.g > 200 && p.r < 60 && p.b < 60
    }

    static func isBlue(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.b > 200 && p.r < 60 && p.g < 60
    }

    static func isMagenta(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && p.r > 200 && p.b > 200 && p.g < 60
    }

    static func isGrey(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8)) -> Bool {
        p.a > 200 && (100...160).contains(p.r) && (100...160).contains(p.g) && (100...160).contains(p.b)
    }

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, _ message: String = "",
                     file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected) \(message)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected) \(message)", file: file, line: line)
        }
    }

    /// A wire node: Column and Wrap hold many children, Text and TextField
    /// none, every other type one.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:],
              _ children: [String] = [], watches: [String] = []) -> JSONValue {
        let mode = ["Column", "Wrap"].contains(type) ? "multi"
            : ["Text", "TextField"].contains(type) ? "none" : "single"
        return [
            "id": .string(id), "type": .string(type), "kind": ["Text", "TextField"].contains(type) ? "primitive" : "layout",
            "childMode": .string(mode), "props": .object(props), "children": .array(children.map { .string($0) }),
            "watches": .array(watches.map { .string($0) }),
        ]
    }

    /// A solid Container of `hex`, `width` by `height`.
    func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)])
    }

    /// A Column: a red box, an Offstage (`offstage` not sent when nil)
    /// around a green one, a blue one; each 40 by 20.
    func offstage(_ offstage: Bool?) -> [JSONValue] {
        [
            node("col", "Column", ["crossAxisAlignment": "start"], ["red", "off", "blue"]),
            box("red", "#FF0000", 40, 20),
            node("off", "Offstage", offstage.map { ["offstage": .bool($0)] } ?? [:], ["green"]),
            box("green", "#00FF00", 40, 20),
            box("blue", "#0000FF", 40, 20),
        ]
    }

    func model(_ nodes: [JSONValue], state: [JSONValue] = []) throws -> OrcaPageModel {
        OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(state), "components": .array(nodes),
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
    /// A Column holding an Offstage whose `offstage` is the page state
    /// `hidden`, around `child`; the page's state is `hidden` and `state`.
    func togglePage(hidden: Bool, child: JSONValue, state: [JSONValue] = []) -> ([JSONValue], [JSONValue]) {
        guard case .object(let object) = child, let id = object["id"] else { return ([], []) }
        return ([
            node("col", "Column", ["crossAxisAlignment": "start"], ["off"]),
            node("off", "Offstage", ["offstage": ["type": "state", "key": "hidden", "scope": "page"]],
                 [id.stringValue ?? ""], watches: ["hidden"]),
            child,
        ], [["key": "hidden", "scope": "page", "initial": .bool(hidden)]] + state)
    }

    /// An offstage TextField.
    func fieldPage(hidden: Bool) -> ([JSONValue], [JSONValue]) {
        togglePage(hidden: hidden, child: node("field", "TextField", ["placeholder": "Name"]))
    }

    /// An offstage green 40 by 20 box whose onInit adds 1 to the page state
    /// `inits`.
    func countedPage() -> ([JSONValue], [JSONValue]) {
        guard case .object(var green) = box("green", "#00FF00", 40, 20) else { return ([], []) }
        green["actions"] = ["onInit": ["type": "setState", "scope": "page", "key": "inits", "value": [
            "type": "transform", "input": ["type": "state", "key": "inits", "scope": "page"],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]]]
        return togglePage(hidden: true, child: .object(green),
                          state: [["key": "inits", "scope": "page", "initial": 0]])
    }

    /// A page of red SafeAreas: `layers["outer"]`, when given, a SafeArea
    /// with those props around `layers["safe"]`'s, around a red Container
    /// that fills what it is given.
    func safe(_ layers: [String: [String: JSONValue]], direction: LayoutDirection = .leftToRight) throws -> Pixels {
        var nodes: [JSONValue] = []
        if let outer = layers["outer"] { nodes.append(node("outer", "SafeArea", outer, ["safe"])) }
        nodes.append(node("safe", "SafeArea", layers["safe"] ?? [:], ["red"]))
        nodes.append(node("red", "Container", ["color": "#FF0000"]))
        let (window, _) = try hosted((nodes, []), insets: Self.insets, direction: direction)
        defer { window.isHidden = true }
        XCTAssertEqual(window.rootViewController?.view.safeAreaInsets, Self.insets, "the window's safe area")
        return try snapshot(window)
    }

    /// The first node in a light 200 by 200 UIKit window, laid out as
    /// OrcaPageView lays a page out: filling the window inside its safe area,
    /// here `insets`.
    func hosted(_ page: ([JSONValue], [JSONValue]), insets: UIEdgeInsets = .zero,
                direction: LayoutDirection = .leftToRight) throws -> (UIWindow, OrcaPageModel) {
        let model = try model(page.0, state: page.1)
        let host = UIHostingController(rootView: NodeView(id: try rootId(page.0), model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environment(\.layoutDirection, direction))
        host.additionalSafeAreaInsets = insets
        // Away from the screen's edges, so the device's own insets (the
        // status bar, the home indicator) do not reach it.
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: 200, height: 200))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return (window, model)
    }

    func snapshot(_ window: UIWindow) throws -> Pixels {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }

    static func textField(in view: UIView) -> UITextField? {
        if let field = view as? UITextField { return field }
        for child in view.subviews {
            if let field = textField(in: child) { return field }
        }
        return nil
    }

    /// The view or one of its superviews is a text field.
    static func isInField(_ view: UIView?) -> Bool {
        var current = view
        while let view = current {
            if view is UITextField { return true }
            current = view.superview
        }
        return false
    }
    #endif
}
#endif
