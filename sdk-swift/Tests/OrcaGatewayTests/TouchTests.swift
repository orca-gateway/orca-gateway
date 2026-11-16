#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A4.4: Flutter's `AbsorbPointer` and `IgnorePointer`
/// (layout_builders.dart:455-467, `absorbing` and `ignoring` default true;
/// RenderAbsorbPointer and RenderIgnorePointer, proxy_box.dart:3952-3953,
/// :3751-3752). Swift cannot inject a tap, so the taps are hit tests in a
/// hosted window (iOS): a Stack, a 120x120 Container behind holding the text
/// field "Behind", and in front the wrapper around an 80x80 Container at the
/// same origin holding the text field "Front"; a hit where both fields lie
/// finds one of them or neither. The size and look are ImageRenderer pixels
/// (macOS and iOS).
@MainActor
final class TouchTests: XCTestCase {
    static let accuracy: CGFloat = 0.5

    // MARK: size and look (ImageRenderer pixels)

    /// A4.4: each wrapper, either way, around a red 60x40 Container is
    /// exactly 60x40 and draws its child as it is (opaque red, never
    /// greyed out as disabled), over a blue page.
    func testA4_4EachWrapperIsItsChildsSizeAndLook() throws {
        let cases: [(String, [String: JSONValue])] = [
            ("AbsorbPointer", [:]), ("AbsorbPointer", ["absorbing": false]),
            ("IgnorePointer", [:]), ("IgnorePointer", ["ignoring": false]),
        ]
        for (type, props) in cases {
            let nodes = [node("w", type, props, ["red"]), box("red", "#FF0000", 60, 40)]
            let pixels = try draw(nodes, width: 100, height: 80)
            assertFrame(pixels.bounds(of: Pixels.isRed), CGRect(x: 0, y: 0, width: 60, height: 40),
                        "\(type) \(props)")
            assertPixel(pixels.pixel(30, 20), (255, 0, 0, 255), "\(type) \(props) inside")
            assertPixel(pixels.pixel(80, 60), (0, 0, 255, 255), "\(type) \(props) outside")
        }
    }

    // MARK: taps (a hosted window, two UIKit text fields as the probes)

    #if canImport(UIKit)
    /// A4.4: absorbing (by default or sent true), a hit inside the
    /// AbsorbPointer's box finds neither field: its child never gets it,
    /// and the field behind does not either (the Stack stops at the first
    /// child hit). Beside its box, over the field behind, the hit finds
    /// that field.
    func testA4_4AbsorbPointerTakesTheHitFromItsChildAndFromWhatIsBehind() throws {
        for absorbing in [nil, true] as [Bool?] {
            let probes = try Probes(overlap(wrapper("AbsorbPointer", absorbing.map { ["absorbing": .bool($0)] } ?? [:])))
            defer { probes.window.isHidden = true }
            XCTAssertNil(probes.field(at: probes.overlap), "absorbing \(String(describing: absorbing)): a field took it")
            XCTAssertNotNil(probes.window.hitTest(probes.overlap, with: nil), "nothing at all took the hit")
            XCTAssertTrue(probes.field(at: probes.besideFront) === probes.behind,
                          "beside the box the field behind took no hit")
        }
    }

    /// A4.4: with `absorbing` false it is an ordinary proxy box: the hit
    /// finds the front field.
    func testA4_4AbsorbPointerNotAbsorbingLetsItsChildTakeTheHit() throws {
        let probes = try Probes(overlap(wrapper("AbsorbPointer", ["absorbing": false])))
        defer { probes.window.isHidden = true }
        XCTAssertTrue(probes.field(at: probes.overlap) === probes.front, "the front field took no hit")
    }

    /// A4.4: ignoring (the default), neither the IgnorePointer nor its child
    /// is hit, so the hit goes on to the field behind.
    func testA4_4IgnorePointerLetsTheHitThroughToWhatIsBehind() throws {
        let probes = try Probes(overlap(wrapper("IgnorePointer", [:])))
        defer { probes.window.isHidden = true }
        XCTAssertTrue(probes.field(at: probes.overlap) === probes.behind, "the field behind took no hit")
    }

    /// A4.4: with `ignoring` false it is an ordinary proxy box: the hit
    /// finds the front field.
    func testA4_4IgnorePointerNotIgnoringLetsItsChildTakeTheHit() throws {
        let probes = try Probes(overlap(wrapper("IgnorePointer", ["ignoring": false])))
        defer { probes.window.isHidden = true }
        XCTAssertTrue(probes.field(at: probes.overlap) === probes.front, "the front field took no hit")
    }

    /// A4.4: `ignoring` bound to the page state `ignore` (as fixture 43
    /// binds it): true, the hit goes to the field behind; once the state is
    /// false, the next hit finds the front field, the same one (the child
    /// kept its identity).
    func testA4_4IgnorePointerBoundToStateFlipsAndTheChildTakesTheNextHit() throws {
        let bound: JSONValue = ["type": "state", "key": "ignore", "scope": "page"]
        let probes = try Probes(overlap(wrapper("IgnorePointer", ["ignoring": bound], watches: ["ignore"])),
                                state: [["key": "ignore", "scope": "page", "initial": true]])
        defer { probes.window.isHidden = true }
        XCTAssertTrue(probes.field(at: probes.overlap) === probes.behind, "ignoring: the field behind took no hit")

        probes.model.store.dispatch(["ignore": false])
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let front = try XCTUnwrap(Probes.field(placeholder: "Front", in: probes.window), "the front field is gone")
        XCTAssertTrue(front === probes.front, "the front field was made again")
        XCTAssertTrue(probes.field(at: probes.overlap) === probes.front, "not ignoring: the front field took no hit")
    }

    /// Both probes in a hosted window, told apart by their placeholders.
    @MainActor
    struct Probes {
        let window: UIWindow
        let model: OrcaPageModel
        let behind: UITextField
        let front: UITextField
        /// A point inside both fields (so inside both Containers).
        let overlap: CGPoint
        /// A point inside the field behind, right of the front Container.
        let besideFront: CGPoint

        init(_ nodes: [JSONValue], state: [JSONValue] = []) throws {
            (window, model) = try TouchTests.hosted(nodes, state: state)
            behind = try XCTUnwrap(Self.field(placeholder: "Behind", in: window), "no field behind")
            front = try XCTUnwrap(Self.field(placeholder: "Front", in: window), "no front field (the child is not drawn)")
            let behindFrame = behind.convert(behind.bounds, to: window)
            let frontFrame = front.convert(front.bounds, to: window)
            overlap = CGPoint(x: 40, y: min(behindFrame.midY, frontFrame.midY))
            besideFront = CGPoint(x: 100, y: behindFrame.midY)
            XCTAssertTrue(behindFrame.contains(overlap) && frontFrame.contains(overlap),
                          "\(overlap) is not in both fields: behind \(behindFrame), front \(frontFrame)")
            XCTAssertTrue(behindFrame.contains(besideFront) && !frontFrame.contains(besideFront),
                          "\(besideFront) is not beside the front field: behind \(behindFrame), front \(frontFrame)")
        }

        /// The text field a hit at `point` lands in, if any.
        func field(at point: CGPoint) -> UITextField? {
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
    }

    /// The first node in a light 200x200 window away from the screen's edges.
    static func hosted(_ nodes: [JSONValue], state: [JSONValue]) throws -> (UIWindow, OrcaPageModel) {
        let model = try model(nodes, state: state)
        let host = UIHostingController(rootView: NodeView(id: try rootId(nodes), model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
        let window = UIWindow(frame: CGRect(x: 0, y: 300, width: 200, height: 200))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return (window, model)
    }
    #endif

    // MARK: pages

    /// A Stack (top left): a 120x120 Container holding the field "Behind",
    /// then `front` (its first node "w") over it.
    func overlap(_ front: [JSONValue]) -> [JSONValue] {
        [
            node("stack", "Stack", ["alignment": "topLeft"], ["back", "w"]),
            node("back", "Container", ["width": 120, "height": 120, "alignment": "topLeft"], ["behind"]),
            node("behind", "TextField", ["placeholder": "Behind"]),
        ] + front
    }

    /// `type` with `props`, id "w", around an 80x80 Container holding the
    /// field "Front".
    func wrapper(_ type: String, _ props: [String: JSONValue], watches: [String] = []) -> [JSONValue] {
        [
            node("w", type, props, ["box"], watches: watches),
            node("box", "Container", ["width": 80, "height": 80, "alignment": "topLeft"], ["front"]),
            node("front", "TextField", ["placeholder": "Front"]),
        ]
    }

    // MARK: helpers

    func assertPixel(_ actual: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ expected: (UInt8, UInt8, UInt8, UInt8),
                     _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let pairs = [(actual.r, expected.0), (actual.g, expected.1), (actual.b, expected.2), (actual.a, expected.3)]
        for (a, e) in pairs where abs(Int(a) - Int(e)) > 2 {
            return XCTFail("\(message): \(actual) vs \(expected)", file: file, line: line)
        }
    }

    func assertFrame(_ actual: CGRect?, _ expected: CGRect, _ message: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("\(message): not drawn, expected \(expected)", file: file, line: line) }
        for (a, e) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(a, e, accuracy: Self.accuracy, "\(message): \(actual) vs \(expected)", file: file, line: line)
        }
    }

    /// A wire node: a Stack holds many children, a TextField none, the rest one.
    func node(_ id: String, _ type: String, _ props: [String: JSONValue] = [:],
              _ children: [String] = [], watches: [String] = []) -> JSONValue {
        [
            "id": .string(id), "type": .string(type), "kind": type == "TextField" ? "primitive" : "layout",
            "childMode": type == "Stack" ? "multi" : type == "TextField" ? "none" : "single",
            "props": .object(props), "children": .array(children.map { .string($0) }),
            "watches": .array(watches.map { .string($0) }),
        ]
    }

    /// A solid Container of `hex`, `width` by `height`.
    func box(_ id: String, _ hex: String, _ width: Double, _ height: Double) -> JSONValue {
        node(id, "Container", ["color": .string(hex), "width": .double(width), "height": .double(height)])
    }

    /// The page, its registry widened by the two types (they are advertised
    /// only in group 6, and the renderer degrades any type it lacks).
    static func model(_ nodes: [JSONValue], state: [JSONValue] = []) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(state), "components": .array(nodes),
        ]).decode(PageResponse.self)
        let registry = WidgetRegistry(types: Set(GeneratedCapabilities.widgets).union(["AbsorbPointer", "IgnorePointer"]))
        return OrcaPageModel(page: page, registry: registry)
    }

    static func rootId(_ nodes: [JSONValue]) throws -> String {
        guard case .object(let first)? = nodes.first else { return try XCTUnwrap(nil as String?, "no root node") }
        return try XCTUnwrap(first["id"]?.stringValue, "no root id")
    }

    static let blue = Color(.sRGB, red: 0, green: 0, blue: 1)

    /// The first node drawn by ImageRenderer at scale 1 in a `width` by
    /// `height` box from the top leading corner, over a blue page (a render
    /// that draws nothing can come back holding the previous render's
    /// pixels).
    func draw(_ nodes: [JSONValue], width: CGFloat, height: CGFloat) throws -> Pixels {
        let view = NodeView(id: try Self.rootId(nodes), model: try Self.model(nodes))
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Self.blue)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage))
    }
}
#endif
