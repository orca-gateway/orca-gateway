#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A4.5, the UI half of InteractiveViewer (layout_builders.dart:636-644;
/// interactive_viewer.dart build :1052-1140): the child laid out with the
/// viewer's own constraints, drawn through the transform and clipped to
/// the viewer's box, the box taking hits while a child's own controls
/// still take theirs. Swift cannot inject a pinch or a drag, so the
/// transform is preset (the view's internal initial state) and the glue
/// that feeds SwiftUI's gestures to the core's ViewerGesture is checked on
/// its own. Pixels by ImageRenderer (macOS and iOS), hits in a hosted
/// window with UIKit text fields as the probes (iOS).
@MainActor
final class ViewerTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: layout and drawing (ImageRenderer pixels)

    /// A4.5: at rest a viewer around a 200x200 child of four 100x100
    /// quadrants is 200x200 and draws its child unchanged, nothing outside.
    func testA4_5AtRestTheViewerIsItsChildsSizeAndDrawsItUnchanged() throws {
        let model = try model(quadrants())
        let frames = NativeWidgetTests().layout(width: 300, height: 300) {
            NodeView(id: "v", model: model).record("v")
        }
        assertFrame(frames["v"], CGRect(x: 0, y: 0, width: 200, height: 200))

        let pixels = try draw(NodeView(id: "v", model: model))
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 100, height: 100))
        assertFrame(pixels.bounds(of: Self.green), CGRect(x: 100, y: 0, width: 100, height: 100))
        assertFrame(pixels.bounds(of: Self.blue), CGRect(x: 0, y: 100, width: 100, height: 100))
        assertFrame(pixels.bounds(of: Self.yellow), CGRect(x: 100, y: 100, width: 100, height: 100))
        assertFrame(pixels.bounds { !Self.grey($0) }, CGRect(x: 0, y: 0, width: 200, height: 200))
    }

    /// A4.5: zoomed to 2 at (0, 0) the red top-left quadrant fills the
    /// viewer and nothing of the child shows outside it; at (-200, -200)
    /// the yellow bottom-right one does (the scale about the top left, then
    /// the translation in the viewer's points).
    func testA4_5AtAPresetTransformTheChildIsDrawnThroughIt() throws {
        let model = try model(quadrants())
        let topLeft = try draw(viewer(model, ViewerTransform(scale: 2, x: 0, y: 0)))
        assertFrame(topLeft.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 200, height: 200))
        assertFrame(topLeft.bounds { !Self.grey($0) }, CGRect(x: 0, y: 0, width: 200, height: 200))

        let bottomRight = try draw(viewer(model, ViewerTransform(scale: 2, x: -200, y: -200)))
        assertFrame(bottomRight.bounds(of: Self.yellow), CGRect(x: 0, y: 0, width: 200, height: 200))
        assertFrame(bottomRight.bounds { !Self.grey($0) }, CGRect(x: 0, y: 0, width: 200, height: 200))
    }

    /// A4.5: zoomed in, the child is clipped to the viewer's box: a magenta
    /// 50x200 sibling drawn before it in a row stays magenta though the
    /// child at (2, -200, -200) reaches over it, and the viewer beside it
    /// is all yellow.
    func testA4_5ZoomedInTheChildIsClippedToTheViewersBox() throws {
        let model = try model(quadrants() + [box("sibling", "#FF00FF", 50, 200)])
        let zoomed = try viewer(model, ViewerTransform(scale: 2, x: -200, y: -200))
        let pixels = try draw(HStack(alignment: .top, spacing: 0) {
            NodeView(id: "sibling", model: model)
            zoomed
        })
        assertFrame(pixels.bounds(of: Self.magenta), CGRect(x: 0, y: 0, width: 50, height: 200))
        assertFrame(pixels.bounds(of: Self.yellow), CGRect(x: 50, y: 0, width: 200, height: 200))
        assertFrame(pixels.bounds { !Self.grey($0) }, CGRect(x: 0, y: 0, width: 250, height: 200))
    }

    /// A4.5: the viewer gives its child its own constraints (Flutter's
    /// `constrained` true): in a 200x200 SizedBox, which stays 200x200, a
    /// 300x300 red Container is laid out and drawn at 200x200.
    func testA4_5InAForcedBoxTheChildIsLaidOutAtTheViewersSize() throws {
        let nodes = [
            node("size", "SizedBox", ["width": 200, "height": 200], ["v"]),
            node("v", "InteractiveViewer", [:], ["big"]),
            box("big", "#FF0000", 300, 300),
        ]
        let model = try model(nodes)
        let frames = NativeWidgetTests().layout(width: 300, height: 300) {
            NodeView(id: "size", model: model).record("size")
        }
        assertFrame(frames["size"], CGRect(x: 0, y: 0, width: 200, height: 200))
        let pixels = try draw(NodeView(id: "size", model: model))
        assertFrame(pixels.bounds(of: Self.red), CGRect(x: 0, y: 0, width: 200, height: 200))
        assertFrame(pixels.bounds { !Self.grey($0) }, CGRect(x: 0, y: 0, width: 200, height: 200))
    }

    // MARK: the glue (SwiftUI's gestures to ViewerGesture)

    /// The 200x200 viewer of the pages above, Flutter's defaults.
    static let limits = ViewerLimits(viewport: ViewerSize(width: 200, height: 200),
                                     child: ViewerSize(width: 200, height: 200))
    static let centre = ViewerPoint(x: 100, y: 100)
    static let zoomed = ViewerTransform(scale: 2, x: -100, y: -100)

    /// A4.5: a pinch is Flutter's scale gesture about its focal point: x2
    /// about the centre is 2 at (-100, -100), and as it goes on to x10 it
    /// stops at 2.5 about the same point.
    func testA4_5APinchIsFluttersScaleGestureAboutItsFocalPoint() {
        var feed = ViewerFeed()
        let two = feed.pinch(2, about: Self.centre, transform: .identity, limits: Self.limits)
        assertTransform(two, Self.zoomed)
        let more = feed.pinch(10, about: Self.centre, transform: two, limits: Self.limits)
        assertTransform(more, ViewerTransform(scale: 2.5, x: -150, y: -150))
    }

    /// A4.5: a drag on its own is a pan from where it is first reported:
    /// that first report moves nothing, a move by (-50, -30) pans by it;
    /// once it ends, the next drag starts afresh where it is.
    func testA4_5ADragOnItsOwnIsAPanFromWhereItIsFirstReported() {
        var feed = ViewerFeed()
        let first = feed.drag(to: Self.centre, transform: Self.zoomed, limits: Self.limits)
        assertTransform(first, Self.zoomed)
        let moved = feed.drag(to: ViewerPoint(x: 50, y: 70), transform: first, limits: Self.limits)
        assertTransform(moved, ViewerTransform(scale: 2, x: -150, y: -130))
        feed.dragEnded()
        let next = feed.drag(to: Self.centre, transform: moved, limits: Self.limits)
        assertTransform(next, moved)
    }

    /// A4.5: while a pinch is on, a drag is one of its fingers and moves
    /// nothing; after the pinch ends the drag goes on as a pan of its own,
    /// starting where it then is.
    func testA4_5ADragDuringAPinchIsIgnoredAndThenPansAfresh() {
        var feed = ViewerFeed()
        let pinched = feed.pinch(2, about: Self.centre, transform: .identity, limits: Self.limits)
        let during = feed.drag(to: ViewerPoint(x: 40, y: 40), transform: pinched, limits: Self.limits)
        assertTransform(during, pinched)
        feed.pinchEnded()
        let restart = feed.drag(to: ViewerPoint(x: 40, y: 40), transform: during, limits: Self.limits)
        assertTransform(restart, pinched)
        let moved = feed.drag(to: ViewerPoint(x: 0, y: 10), transform: restart, limits: Self.limits)
        assertTransform(moved, ViewerTransform(scale: 2, x: -140, y: -130))
    }

    /// A4.5: a new pinch starts a new gesture from the transform it finds:
    /// after a x2 pinch has ended, another x1.25 about the centre goes to
    /// 2.5, not to 1.25.
    func testA4_5EachPinchStartsFromTheTransformItFinds() {
        var feed = ViewerFeed()
        let first = feed.pinch(2, about: Self.centre, transform: .identity, limits: Self.limits)
        feed.pinchEnded()
        let second = feed.pinch(1.25, about: Self.centre, transform: first, limits: Self.limits)
        assertTransform(second, ViewerTransform(scale: 2.5, x: -150, y: -150))
    }

    /// A4.5: the pinch's focal point is where it began when SwiftUI says
    /// (MagnifyGesture, iOS 17 / macOS 14), else the centre of the box
    /// (MagnificationGesture has no location).
    func testA4_5APinchsFocalPointIsWhereItBeganElseTheBoxsCentre() {
        XCTAssertEqual(ViewerFeed.focal(CGPoint(x: 10, y: 20), in: CGSize(width: 200, height: 100)),
                       ViewerPoint(x: 10, y: 20))
        XCTAssertEqual(ViewerFeed.focal(nil, in: CGSize(width: 200, height: 100)), ViewerPoint(x: 100, y: 50))
    }

    /// A4.5: the drag is attached only while it can move the transform:
    /// zoomed in with pan on. At 1 (and below) Flutter's bound leaves no
    /// room, so a one-finger drag is left to a scroll view around it.
    func testA4_5TheDragIsTakenOnlyWhileItCanPan() {
        XCTAssertFalse(ViewerFeed.pans(.identity, Self.limits))
        XCTAssertFalse(ViewerFeed.pans(ViewerTransform(scale: 0.9, x: 0, y: 0), Self.limits))
        XCTAssertTrue(ViewerFeed.pans(Self.zoomed, Self.limits))
        var off = Self.limits
        off.panEnabled = false
        XCTAssertFalse(ViewerFeed.pans(Self.zoomed, off))
    }

    // MARK: taps (a hosted window, UIKit text fields as the probes)

    #if canImport(UIKit)
    /// A4.5: a tap on a control inside the viewer still reaches it, at rest
    /// and zoomed in to 2, where the field is drawn twice as large: a point
    /// below it at rest is in it then.
    func testA4_5ATapOnAFieldInsideTheViewerReachesIt() throws {
        let (window, _) = try hosted(fields())
        defer { window.isHidden = true }
        let front = try XCTUnwrap(Self.field(placeholder: "Front", in: window), "no front field (the child is not drawn)")
        let frame = front.convert(front.bounds, to: window)
        XCTAssertTrue(Self.field(at: CGPoint(x: frame.midX, y: frame.midY), in: window) === front,
                      "the front field took no hit at \(frame)")

        let model = try model(fields())
        let zoomed = try hosted(viewer(model, ViewerTransform(scale: 2, x: 0, y: 0)))
        defer { zoomed.isHidden = true }
        let scaled = try XCTUnwrap(Self.field(placeholder: "Front", in: zoomed), "no front field zoomed in")
        let scaledFrame = scaled.convert(scaled.bounds, to: zoomed)
        XCTAssertEqual(scaledFrame.width, frame.width * 2, accuracy: 1, "the field is not drawn zoomed in")
        XCTAssertEqual(scaledFrame.height, frame.height * 2, accuracy: 1, "the field is not drawn zoomed in")
        let point = CGPoint(x: 50, y: scaledFrame.maxY - 4)
        XCTAssertTrue(scaledFrame.contains(point) && !frame.contains(point),
                      "\(point) is not in the zoomed field \(scaledFrame) only")
        XCTAssertTrue(Self.field(at: point, in: zoomed) === scaled, "the zoomed field took no hit at \(point)")
    }

    /// A4.5: the viewer takes hits on its whole box (Flutter's opaque
    /// GestureDetector): where its child draws nothing, the field behind it
    /// gets no hit; beside the viewer the same field does.
    func testA4_5TheViewerTakesHitsOnItsWholeBox() throws {
        let (window, _) = try hosted(fields())
        defer { window.isHidden = true }
        let behind = try XCTUnwrap(Self.field(placeholder: "Behind", in: window), "no field behind")
        XCTAssertNotNil(Self.field(placeholder: "Front", in: window), "no front field (the child is not drawn)")
        let frame = behind.convert(behind.bounds, to: window)
        let inside = CGPoint(x: 50, y: frame.midY), beside = CGPoint(x: 150, y: frame.midY)
        XCTAssertTrue(frame.contains(inside) && frame.contains(beside), "the field behind \(frame) is not under both")
        XCTAssertNil(Self.field(at: inside, in: window), "a field took a hit inside the viewer's box")
        XCTAssertTrue(Self.field(at: beside, in: window) === behind, "beside the viewer the field behind took no hit")
    }

    /// `content` in a light 200x200 window away from the screen's edges.
    func hosted<V: View>(_ content: V) throws -> UIWindow {
        let host = UIHostingController(rootView: content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: 200, height: 200))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return window
    }

    /// The first node of `nodes` hosted, and its model.
    func hosted(_ nodes: [JSONValue]) throws -> (UIWindow, OrcaPageModel) {
        let model = try model(nodes)
        return (try hosted(NodeView(id: try rootId(nodes), model: model)), model)
    }

    /// The text field a hit at `point` lands in, if any.
    static func field(at point: CGPoint, in window: UIWindow) -> UITextField? {
        var current = window.hitTest(point, with: nil)
        while let view = current {
            if let field = view as? UITextField { return field }
            current = view.superview
        }
        return nil
    }

    static func field(placeholder: String, in view: UIView) -> UITextField? {
        if let field = view as? UITextField, field.placeholder == placeholder { return field }
        for child in view.subviews {
            if let field = field(placeholder: placeholder, in: child) { return field }
        }
        return nil
    }
    #endif

    // MARK: pages

    /// The viewer "v" (with `props`) around a 200x200 Column of four
    /// 100x100 quadrants: red, green on top, blue, yellow below.
    func quadrants(_ props: [String: JSONValue] = [:]) -> [JSONValue] {
        [
            node("v", "InteractiveViewer", props, ["grid"]),
            node("grid", "Column", ["mainAxisSize": "min", "crossAxisAlignment": "start"], ["top", "bottom"]),
            node("top", "Row", ["mainAxisSize": "min"], ["red", "green"]),
            node("bottom", "Row", ["mainAxisSize": "min"], ["blue", "yellow"]),
            box("red", "#FF0000", 100, 100), box("green", "#00FF00", 100, 100),
            box("blue", "#0000FF", 100, 100), box("yellow", "#FFFF00", 100, 100),
        ]
    }

    /// A Stack (top left): a 200x200 Container holding the field "Behind"
    /// across its bottom, then over its left half the viewer "v" around a
    /// 100x200 Container holding the field "Front" at its top.
    func fields() -> [JSONValue] {
        [
            node("stack", "Stack", ["alignment": "topLeft"], ["back", "v"]),
            node("back", "Container", ["width": 200, "height": 200, "alignment": "bottomLeft"], ["behind"]),
            node("behind", "TextField", ["placeholder": "Behind"]),
            node("v", "InteractiveViewer", [:], ["inner"]),
            node("inner", "Container", ["width": 100, "height": 200, "alignment": "topLeft"], ["front"]),
            node("front", "TextField", ["placeholder": "Front"]),
        ]
    }

    /// The viewer "v" of `model` starting from `initial`.
    func viewer(_ model: OrcaPageModel, _ initial: ViewerTransform) throws -> InteractiveViewerView {
        InteractiveViewerView(node: try XCTUnwrap(model.resolve("v"), "no viewer"), model: model, initial: initial)
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
    static let magenta = colour(255, 0, 255)
    static let grey = colour(128, 128, 128)
    static let page = Color(.sRGB, red: 128 / 255, green: 128 / 255, blue: 128 / 255)

    func assertTransform(_ actual: ViewerTransform, _ expected: ViewerTransform,
                         file: StaticString = #filePath, line: UInt = #line) {
        for (a, e) in [(actual.scale, expected.scale), (actual.x, expected.x), (actual.y, expected.y)] {
            XCTAssertEqual(a, e, accuracy: 1e-9, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("not drawn, expected \(expected)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(actual) vs \(expected)", file: file, line: line)
        }
    }

    /// A wire node: a Stack, Row or Column holds many children, a TextField
    /// none, the rest one.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:],
              _ children: [String] = []) -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": type == "TextField" ? "primitive" : "layout",
            "childMode": ["Stack", "Row", "Column"].contains(type) ? "multi" : type == "TextField" ? "none" : "single",
            "props": .object(props), "children": .array(children.map { .string($0) }), "watches": [],
        ]
    }

    /// A solid Container of `hex`, `width` by `height`.
    func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)])
    }

    /// The page, its registry widened by InteractiveViewer (advertised only
    /// in group 6; the renderer degrades any type it lacks).
    func model(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [], "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["InteractiveViewer"])))
    }

    func rootId(_ nodes: [JSONValue]) throws -> String {
        guard case .object(let first)? = nodes.first else { return try XCTUnwrap(nil as String?, "no root node") }
        return try XCTUnwrap(first["id"]?.stringValue, "no root id")
    }

    /// `content` drawn by ImageRenderer at scale 1 in a 300x300 box from the
    /// top leading corner, over a grey page (a render that draws nothing can
    /// come back holding the previous render's pixels).
    func draw<V: View>(_ content: V) throws -> Pixels {
        let renderer = ImageRenderer(content: content
            .frame(width: 300, height: 300, alignment: .topLeading)
            .background(Self.page))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}
#endif
