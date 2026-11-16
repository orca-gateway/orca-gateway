#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A5.1, A5.2 and A5.3, the UI half of ListView and GridView against
/// Flutter's builders (structure_builders.dart:161-227): `SliverList`
/// (children forced to the cross extent), `SliverFixedExtentList`
/// (itemExtent), `SliverPadding`, a reversed axis and
/// `SliverGridRegularTileLayout` (cells forced to the core's GridCells).
/// Rows count themselves into page key `built` on init, as Flutter's
/// OrcaLifecycleWrapper does when a row's element is built. ImageRenderer
/// does not draw a scroll view's content, so the lists that scroll are
/// hosted in a UIKit window and moved through their UIScrollView (iOS);
/// the ones laid out with no limit on their axis do not scroll and are
/// drawn by ImageRenderer (macOS and iOS). The same cases as Kotlin's
/// ListTest.
@MainActor
final class ListTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    override func tearDown() {
        ScrollNodeView.usesScrollPhase = true
        super.tearDown()
    }

    // MARK: no limit on the scroll axis (ImageRenderer)

    /// A5.2: in a Column (no height limit) the list lays out every child,
    /// as long as its content, instead of throwing as Flutter's does: the
    /// padding, five rows of 40, then the Column's next child.
    func testA5_2AListWithNoLimitLaysOutEveryChild() throws {
        let rows = (0..<5).map { "r\($0)" }
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "stretch"], ["l", "after"]),
            node("l", "ListView", ["padding": ["top": 10, "right": 0, "bottom": 0, "left": 0]], rows),
        ] + rows.enumerated().map { index, id in
            box(id, index == 0 ? Self.redHex : index == 4 ? Self.blueHex : Self.greenHex, height: 40)
        } + [box("after", Self.yellowHex, height: 20)], width: 300, height: 400)
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 10, width: 300, height: 40))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 170, width: 300, height: 40))
        assertFrame(pixels.bounds(of: Self.yellow), CGRect(x: 0, y: 210, width: 300, height: 20))
    }

    /// A5.3: in a Column (no height limit) the grid lays out every cell, as
    /// tall as its rows: five square cells of 150 in two columns with
    /// mainAxisSpacing 10, then the Column's next child.
    func testA5_3AGridWithNoLimitLaysOutEveryCell() throws {
        let cells = (0..<5).map { "c\($0)" }
        let pixels = try draw([
            node("col", "Column", ["crossAxisAlignment": "stretch"], ["g", "after"]),
            node("g", "GridView", ["mainAxisSpacing": 10], cells),
        ] + cells.enumerated().map { index, id in
            box(id, index == 3 ? Self.redHex : index == 4 ? Self.blueHex : Self.greenHex)
        } + [box("after", Self.yellowHex, height: 20)], width: 300, height: 600)
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 150, y: 160, width: 150, height: 150))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 320, width: 150, height: 150))
        assertFrame(pixels.bounds(of: Self.yellow), CGRect(x: 0, y: 470, width: 300, height: 20))
    }

    #if canImport(UIKit)
    // MARK: A5.1 ListView is lazy (hosted)

    /// A5.1: of 1,000 rows 40 high in a view 400 high only those near the
    /// screen are built (SwiftUI: the 10 on screen; Flutter adds its 250 px
    /// cache, 17 rows); a jump to row 500 builds the rows there, which then
    /// fill the view from its top.
    func testA5_1AListOf1000RowsBuildsOnlyTheRowsNearTheViewport() throws {
        let rows = (0..<1000).map { "r\($0)" }
        let hosted = try HostedList([node("l", "ListView", [:], rows)] + rows.enumerated().map { index, id in
            box(id, index == 500 ? Self.blueHex : Self.greenHex, height: 40, actions: ["onInit": Self.count("built")])
        }, width: 300, height: 400)
        defer { hosted.close() }
        let first = hosted.built
        XCTAssertTrue((10...30).contains(first), "built \(first)")

        hosted.scroll(to: CGPoint(x: 0, y: 20_000))

        let after = hosted.built
        XCTAssertTrue((first + 10...first + 30).contains(after), "built \(after) after \(first)")
        assertFrame(try hosted.pixels().bounds(of: Self.blue), CGRect(x: 0, y: 0, width: 300, height: 40))
    }

    /// A5.1: the list runs onScrollBegin, onScrolling and onScrollEnd with
    /// Flutter's metrics: 100 rows of 40 in a view of 400 scroll 3,600;
    /// on iOS 18's scroll phase and on the iOS 16-17 probe.
    func testA5_1ScrollingTheListRunsTheScrollTriggers() throws {
        for phased in [true, false] {
            ScrollNodeView.usesScrollPhase = phased
            let rows = (0..<100).map { "r\($0)" }
            let hosted = try HostedList([node("l", "ListView", [:], rows, actions: Self.triggers)]
                + rows.map { box($0, Self.greenHex, height: 40) }, width: 300, height: 400)
            defer { hosted.close() }

            hosted.scroll(to: CGPoint(x: 0, y: 1000))

            XCTAssertEqual(hosted.value("begins"), 1, "phased \(phased)")
            XCTAssertEqual(hosted.value("ends"), 1, "phased \(phased)")
            XCTAssertEqual(hosted.value("endOffset"), 1000, "phased \(phased)")
            XCTAssertEqual(hosted.value("maxExtent"), 3600, "phased \(phased)")
            XCTAssertEqual(hosted.value("viewport"), 400, "phased \(phased)")
            XCTAssertEqual(hosted.value("endAtEnd"), false, "phased \(phased)")

            hosted.scroll(to: CGPoint(x: 0, y: 3600))

            XCTAssertEqual(hosted.value("ends"), 2, "phased \(phased)")
            XCTAssertEqual(hosted.value("endOffset"), 3600, "phased \(phased)")
            XCTAssertEqual(hosted.value("endAtEnd"), true, "phased \(phased)")
        }
    }

    /// A5.1: a list fills its parent, as Flutter's viewport does, and its
    /// rows fill its width, whatever width they ask for.
    func testA5_1AListFillsItsParentAndItsRowsItsWidth() throws {
        let hosted = try HostedList([
            node("l", "ListView", [:], ["a", "b"]),
            box("a", Self.redHex, width: 40, height: 40), box("b", Self.greenHex, height: 40),
        ], width: 300, height: 400)
        defer { hosted.close() }
        assertFrame(hosted.scrollFrame, CGRect(x: 0, y: 0, width: 300, height: 400))
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 300, height: 40))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 40, width: 300, height: 40))
    }

    // MARK: A5.2 direction, padding, reverse, itemExtent, shrinkWrap (hosted)

    /// A5.2: a horizontal list runs across, each child as tall as the list.
    func testA5_2AHorizontalListRunsAcrossAndFillsItsHeight() throws {
        let hosted = try HostedList([
            node("l", "ListView", ["scrollDirection": "horizontal"], ["a", "b", "c"]),
            box("a", Self.redHex, width: 50), box("b", Self.greenHex, width: 60), box("c", Self.blueHex, width: 70),
        ], width: 300, height: 100)
        defer { hosted.close() }
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 50, height: 100))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 50, y: 0, width: 60, height: 100))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 110, y: 0, width: 70, height: 100))
    }

    /// A5.2: padding is inside the scroll extent: around the first row at
    /// the start, after the last at the end (10 + 20 × 40 + 30 = 840 of
    /// content in a view of 400).
    func testA5_2PaddingIsInsideTheScrollExtent() throws {
        let rows = (0..<20).map { "r\($0)" }
        let hosted = try HostedList([
            node("l", "ListView", ["padding": ["top": 10, "right": 5, "bottom": 30, "left": 20]], rows),
        ] + rows.enumerated().map { index, id in
            box(id, index == 0 ? Self.redHex : index == 19 ? Self.blueHex : Self.greenHex, height: 40)
        }, width: 300, height: 400)
        defer { hosted.close() }
        assertFrame(try hosted.pixels().bounds(of: Self.red), CGRect(x: 20, y: 10, width: 275, height: 40))

        hosted.scroll(to: CGPoint(x: 0, y: 440))

        assertFrame(try hosted.pixels().bounds(of: Self.blue), CGRect(x: 20, y: 330, width: 275, height: 40))
    }

    /// A5.2: reverse puts the first child at the far end, offset 0 there;
    /// the padding stays on its side. Horizontal, it starts at the right.
    func testA5_2ReverseStartsAtTheFarEnd() throws {
        let vertical = try HostedList([
            node("l", "ListView", ["reverse": true, "padding": ["top": 0, "right": 0, "bottom": 10, "left": 0]],
                 ["a", "b", "c"]),
            box("a", Self.redHex, height: 40), box("b", Self.greenHex, height: 40), box("c", Self.blueHex, height: 40),
        ], width: 300, height: 400)
        defer { vertical.close() }
        let pixels = try vertical.pixels()
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 350, width: 300, height: 40))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 310, width: 300, height: 40))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 270, width: 300, height: 40))

        let horizontal = try HostedList([
            node("l", "ListView", ["scrollDirection": "horizontal", "reverse": true], ["a", "b"]),
            box("a", Self.redHex, width: 50), box("b", Self.greenHex, width: 60),
        ], width: 300, height: 100)
        defer { horizontal.close() }
        let row = try horizontal.pixels()
        assertFrame(row.bounds(of: Self.red), CGRect(x: 250, y: 0, width: 50, height: 100))
        assertFrame(row.bounds(of: Self.green), CGRect(x: 190, y: 0, width: 60, height: 100))
    }

    /// A5.2: itemExtent forces every child's main extent, whatever it asks for.
    func testA5_2ItemExtentForcesEachChildsLength() throws {
        let hosted = try HostedList([
            node("l", "ListView", ["itemExtent": 30], ["a", "b"]),
            box("a", Self.redHex, height: 50), box("b", Self.greenHex, height: 10),
        ], width: 300, height: 400)
        defer { hosted.close() }
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 300, height: 30))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 30, width: 300, height: 30))
    }

    /// A5.2: shrinkWrap sizes the list to its content on the scroll axis,
    /// as Flutter's ShrinkWrappingViewport, never past its parent, and
    /// stays lazy: 1,000 rows fill the 400 offered and build only those
    /// near the view.
    func testA5_2ShrinkWrapHugsItsContent() throws {
        let short = try HostedList([
            node("l", "ListView", ["shrinkWrap": true], ["a", "b", "c"]),
            box("a", Self.greenHex, height: 40), box("b", Self.greenHex, height: 40),
            box("c", Self.blueHex, height: 40),
        ], width: 300, height: 400)
        defer { short.close() }
        assertFrame(short.scrollFrame, CGRect(x: 0, y: 0, width: 300, height: 120))
        assertFrame(try short.pixels().bounds(of: Self.blue), CGRect(x: 0, y: 80, width: 300, height: 40))

        let rows = (0..<1000).map { "r\($0)" }
        let long = try HostedList([node("l", "ListView", ["shrinkWrap": true], rows)] + rows.map {
            box($0, Self.greenHex, height: 40, actions: ["onInit": Self.count("built")])
        }, width: 300, height: 400)
        defer { long.close() }
        assertFrame(long.scrollFrame, CGRect(x: 0, y: 0, width: 300, height: 400))
        XCTAssertTrue((10...30).contains(long.built), "built \(long.built)")
    }

    // MARK: A5.3 GridView (hosted)

    /// A5.3: two columns 310 wide with crossAxisSpacing 10, mainAxisSpacing
    /// 4 and childAspectRatio 1.5 are cells 150 x 100, each child forced to
    /// its cell.
    func testA5_3AGridOfTwoColumnsWithSpacingAndRatio() throws {
        let hosted = try HostedList([
            node("g", "GridView", ["crossAxisCount": 2, "mainAxisSpacing": 4, "crossAxisSpacing": 10,
                                   "childAspectRatio": 1.5], ["c0", "c1", "c2", "c3"]),
            box("c0", Self.redHex, width: 10, height: 10), box("c1", Self.greenHex), box("c2", Self.blueHex),
            box("c3", Self.yellowHex),
        ], width: 310, height: 400)
        defer { hosted.close() }
        assertFrame(hosted.scrollFrame, CGRect(x: 0, y: 0, width: 310, height: 400))
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 150, height: 100))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 160, y: 0, width: 150, height: 100))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 104, width: 150, height: 100))
        assertFrame(pixels.bounds(of: Self.yellow), CGRect(x: 160, y: 104, width: 150, height: 100))
    }

    /// A5.3: with no count, ratio or spacing, two square columns; the
    /// padding is taken off first.
    func testA5_3DefaultsAndPadding() throws {
        let hosted = try HostedList([
            node("g", "GridView", ["padding": ["top": 5, "right": 10, "bottom": 0, "left": 20]], ["c0", "c1", "c2"]),
            box("c0", Self.redHex), box("c1", Self.greenHex), box("c2", Self.blueHex),
        ], width: 310, height: 400)
        defer { hosted.close() }
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 20, y: 5, width: 140, height: 140))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 160, y: 5, width: 140, height: 140))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 20, y: 145, width: 140, height: 140))
    }

    /// A5.3: a horizontal grid splits its height and reads the ratio as
    /// height / width.
    func testA5_3AHorizontalGrid() throws {
        let hosted = try HostedList([
            node("g", "GridView", ["scrollDirection": "horizontal", "mainAxisSpacing": 5, "crossAxisSpacing": 10,
                                   "childAspectRatio": 2], ["c0", "c1", "c2"]),
            box("c0", Self.redHex), box("c1", Self.greenHex), box("c2", Self.blueHex),
        ], width: 300, height: 210)
        defer { hosted.close() }
        let pixels = try hosted.pixels()
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 50, height: 100))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 0, y: 110, width: 50, height: 100))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 55, y: 0, width: 50, height: 100))
    }

    /// A5.3: of 200 cells only the rows near the view are built (SwiftUI:
    /// the 6 on screen; Flutter: 5 rows of 150 in 400 and its 250 px cache,
    /// 10 cells).
    func testA5_3AGridBuildsOnlyTheCellsNearTheViewport() throws {
        let cells = (0..<200).map { "c\($0)" }
        let hosted = try HostedList([node("g", "GridView", [:], cells)] + cells.map {
            box($0, Self.greenHex, actions: ["onInit": Self.count("built")])
        }, width: 300, height: 400)
        defer { hosted.close() }
        XCTAssertTrue((6...20).contains(hosted.built), "built \(hosted.built)")
    }

    /// A5.3: the grid runs the scroll triggers: 10 rows of 150 with spacing
    /// 10 in a view of 400 scroll 1,190.
    func testA5_3ScrollingTheGridRunsTheScrollTriggers() throws {
        let cells = (0..<20).map { "c\($0)" }
        let hosted = try HostedList([node("g", "GridView", ["mainAxisSpacing": 10], cells, actions: Self.triggers)]
            + cells.map { box($0, Self.greenHex) }, width: 300, height: 400)
        defer { hosted.close() }

        hosted.scroll(to: CGPoint(x: 0, y: 1190))

        XCTAssertEqual(hosted.value("begins"), 1)
        XCTAssertEqual(hosted.value("maxExtent"), 1190)
        XCTAssertEqual(hosted.value("endOffset"), 1190)
        XCTAssertEqual(hosted.value("endAtEnd"), true)
        XCTAssertEqual(hosted.value("viewport"), 400)
    }
    #endif

    // MARK: pages

    static let redHex = "#FF0000", greenHex = "#00FF00", blueHex = "#0000FF", yellowHex = "#FFFF00"
    static let keys = ["built", "begins", "scrolls", "ends", "endOffset", "endAtEnd", "viewport", "maxExtent"]

    /// begin counts; onScrolling counts and writes maxExtent; end counts and
    /// writes where it settled, whether at the end, and the viewport.
    static var triggers: [String: JSONValue] {
        [
            "onScrollBegin": count("begins"),
            "onScrolling": sequence([count("scrolls"), write("maxExtent", "maxExtent")]),
            "onScrollEnd": sequence([count("ends"), write("endOffset", "offset"), write("endAtEnd", "atEnd"),
                                     write("viewport", "viewportDimension")]),
        ]
    }

    static func sequence(_ actions: [JSONValue]) -> JSONValue {
        ["type": "actionGroup", "mode": "sequential", "actions": .array(actions)]
    }

    /// setState `key` to the event's `field`.
    static func write(_ key: String, _ field: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": ["type": "event", "key": .string(field)]]
    }

    /// setState `key` to itself plus 1.
    static func count(_ key: String) -> JSONValue {
        ["type": "setState", "scope": "page", "key": .string(key), "value": [
            "type": "transform", "input": ["type": "state", "key": .string(key), "scope": "page"],
            "by": [["type": "add", "by": ["type": "static", "value": 1]]],
        ]]
    }

    /// A wire node: a ListView, GridView or Column holds many children, the rest at most one.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:], _ children: [String] = [],
              actions: [String: JSONValue] = [:]) -> JSONValue {
        let multi = ["ListView", "GridView", "Column", "Row"].contains(type)
        return [
            "id": .string(id), "type": .string(type), "kind": "layout",
            "childMode": .string(multi ? "multi" : children.isEmpty ? "none" : "single"),
            "props": .object(props), "children": .array(children.map { .string($0) }), "watches": [],
            "actions": .object(actions),
        ]
    }

    /// A Container of `hex`, `width` by `height` when set.
    func box(_ id: String, _ hex: String, width: Double? = nil, height: Double? = nil,
             actions: [String: JSONValue] = [:]) -> JSONValue {
        var props: [String: JSONValue] = ["color": .string(hex)]
        if let width { props["width"] = .double(width) }
        if let height { props["height"] = .double(height) }
        return node(id, "Container", props, actions: actions)
    }

    /// The page, its registry widened by ListView and GridView (advertised
    /// only in group 8; the renderer degrades any type it lacks), its keys at 0.
    static func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": .array(keys.map { ["key": .string($0), "scope": "page", "initial": 0] }),
            "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["ListView", "GridView"])))
    }

    static func rootId(_ nodes: [JSONValue]) throws -> String {
        guard case .object(let first)? = nodes.first else { return try XCTUnwrap(nil as String?, "no root node") }
        return try XCTUnwrap(first["id"]?.stringValue, "no root id")
    }

    // MARK: helpers

    typealias Pixel = (r: UInt8, g: UInt8, b: UInt8, a: UInt8)

    static func colour(_ r: Int, _ g: Int, _ b: Int) -> (Pixel) -> Bool {
        { p in p.a > 250 && abs(Int(p.r) - r) < 12 && abs(Int(p.g) - g) < 12 && abs(Int(p.b) - b) < 12 }
    }

    static let red = colour(255, 0, 0)
    static let green = colour(0, 255, 0)
    static let blue = colour(0, 0, 255)
    static let yellow = colour(255, 255, 0)

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, _ message: String = "",
                     file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected) \(message)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected) \(message)", file: file, line: line)
        }
    }

    /// The first node drawn by ImageRenderer at scale 1 in a `width` by
    /// `height` box from the top leading corner.
    func draw(_ nodes: [JSONValue], width: CGFloat, height: CGFloat) throws -> Pixels {
        let view = NodeView(id: try Self.rootId(nodes), model: try Self.model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}

#if canImport(UIKit)
/// The first node of `nodes` in a UIKit window `width` by `height` (light,
/// scale 1 pixels), kept on screen until `close`.
@MainActor
private final class HostedList {
    let model: OrcaPageModel
    private let window: UIWindow

    init(_ nodes: [JSONValue], width: CGFloat, height: CGFloat) throws {
        model = try ListTests.model(nodes)
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        let host = UIHostingController(rootView: NodeView(id: try ListTests.rootId(nodes), model: model)
            .frame(width: width, height: height, alignment: .topLeading)
            .ignoresSafeArea())
        window = UIWindow(frame: frame)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = frame
        host.view.layoutIfNeeded()
        pump(0.3)
    }

    func value(_ key: String) -> JSONValue { model.store.value(key) }

    /// How many rows have run onInit.
    var built: Int { value("built").dartInt ?? -1 }

    /// The first UIScrollView in the window.
    var scrollView: UIScrollView? {
        func find(_ view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            return view.subviews.lazy.compactMap(find).first
        }
        return find(window)
    }

    /// The scroll view's frame in the window.
    var scrollFrame: CGRect? { scrollView.map { $0.convert($0.bounds, to: window) } }

    /// `setContentOffset` with no scroll in progress (a jump), then a pump.
    func scroll(to offset: CGPoint) {
        scrollView?.setContentOffset(offset, animated: false)
        pump(0.5)
    }

    func pixels() throws -> Pixels {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        return try Pixels(XCTUnwrap(image.cgImage))
    }

    func pump(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func close() {
        window.isHidden = true
    }
}
#endif
#endif
