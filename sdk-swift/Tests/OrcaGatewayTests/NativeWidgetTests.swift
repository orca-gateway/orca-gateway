#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@testable import OrcaGateway

/// T4.4: the six widgets S4 adds. Layout runs in a real SwiftUI host; prop
/// parsing and the TextField's events run on the model.
@MainActor
final class NativeWidgetTests: XCTestCase {
    // MARK: FlexLayout (Expanded, Spacer)

    func testFlexSharesTheSpaceLeftByFlex() {
        let frames = layout(width: 350, height: 100) {
            FlexLayout(axis: .horizontal, cross: .center, fill: true, gap: 0) {
                Color.red.frame(width: 50, height: 10).record("fixed")
                Color.blue.record("one").layoutValue(key: FlexFactor.self, value: 1)
                Color.green.record("two").layoutValue(key: FlexFactor.self, value: 2)
            }
        }
        XCTAssertEqual(frames["fixed"]?.width, 50)
        XCTAssertEqual(frames["one"]?.width, 100)
        XCTAssertEqual(frames["two"]?.width, 200)
        XCTAssertEqual(frames["one"]?.minX, 50)
        XCTAssertEqual(frames["two"]?.minX, 150)
        // Centred on the cross axis: a 10 high child in a 100 high row.
        XCTAssertEqual(frames["fixed"]?.minY, 45)
    }

    func testGapsAreTakenBeforeTheShareAndASpacerPushesToTheEnd() {
        let frames = layout(width: 300, height: 100) {
            FlexLayout(axis: .horizontal, cross: .start, fill: true, gap: 10) {
                Color.red.frame(width: 40, height: 10).record("a")
                SpacerNodeView().record("spacer").layoutValue(key: FlexFactor.self, value: 1)
                Color.red.frame(width: 40, height: 10).record("b")
            }
        }
        XCTAssertEqual(frames["a"]?.minX, 0)
        XCTAssertEqual(frames["b"]?.maxX, 300)
        XCTAssertEqual(frames["b"]?.minY, 0)
    }

    func testAColumnSharesHeightAndStretchesAcross() {
        let frames = layout(width: 200, height: 400) {
            FlexLayout(axis: .vertical, cross: .stretch, fill: true, gap: 0) {
                Color.red.frame(height: 100).frame(maxWidth: .infinity).record("top")
                Color.blue.frame(maxWidth: .infinity).record("rest").layoutValue(key: FlexFactor.self, value: 1)
            }
        }
        XCTAssertEqual(frames["top"]?.height, 100)
        XCTAssertEqual(frames["rest"]?.height, 300)
        XCTAssertEqual(frames["rest"]?.width, 200)
    }

    // MARK: props

    func testAlignmentNamesFollowFlutter() {
        XCTAssertEqual(Props.alignment("topLeft"), .topLeading)
        XCTAssertEqual(Props.alignment("bottomCenter"), .bottom)
        XCTAssertEqual(Props.alignment("nonsense"), .center)
        XCTAssertEqual(Props.alignment(nil), .center)
    }

    func testRadiiFromANumberOrCorners() {
        XCTAssertEqual(Props.radii(12), CornerRadii(all: 12))
        XCTAssertEqual(Props.radii(["topLeft": 8, "topRight": 8]),
                       CornerRadii(topLeft: 8, topRight: 8, bottomLeft: 0, bottomRight: 0))
        XCTAssertNil(Props.radii("12"))
    }

    func testClipBehaviourIsOffUnlessAsked() {
        XCTAssertFalse(Props.clips(nil))
        XCTAssertFalse(Props.clips("none"))
        XCTAssertTrue(Props.clips("antiAlias"))
        XCTAssertTrue(Props.clips("hardEdge"))
    }

    func testBoxDecorationReadsEveryFlutterField() throws {
        let decoration = try XCTUnwrap(BoxDecorationProps([
            "color": "#FFFFFF",
            "borderRadius": 16,
            "border": ["color": "#E0E0E0", "width": 2],
            "boxShadow": [["color": "#33000000", "blurRadius": 8, "offset": ["dx": 0, "dy": 4]]],
            "gradient": ["colors": ["#FF5722", "#FFC107"], "stops": [0, 1], "begin": "topLeft", "end": "bottomRight"],
        ]))
        XCTAssertEqual(decoration.radii, CornerRadii(all: 16))
        XCTAssertEqual(decoration.border?.width, 2)
        XCTAssertEqual(decoration.shadows.count, 1)
        XCTAssertEqual(decoration.shadows.first?.blurRadius, 8)
        XCTAssertEqual(decoration.shadows.first?.offset, CGSize(width: 0, height: 4))
        XCTAssertEqual(decoration.gradient?.begin, .topLeading)
        XCTAssertEqual(decoration.gradient?.end, .bottomTrailing)
        XCTAssertNil(BoxDecorationProps(nil))
        // Flutter's defaults: begin center, an end of center becomes centerRight.
        let plain = try XCTUnwrap(BoxDecorationProps(["gradient": ["colors": ["#000000", "#FFFFFF"]]]))
        XCTAssertEqual(plain.gradient?.begin, .center)
        XCTAssertEqual(plain.gradient?.end, .trailing)
        XCTAssertNil(BoxDecorationProps(["border": ["style": "none"]])?.border)
    }

    func testCornerRadiiAreCappedAtHalfTheShorterSide() {
        let shape = CornersShape(radii: CornerRadii(all: 100))
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 40, height: 20))
        XCTAssertEqual(path.boundingRect.integral, CGRect(x: 0, y: 0, width: 40, height: 20))
        XCTAssertTrue(path.contains(CGPoint(x: 20, y: 10)))
        XCTAssertFalse(path.contains(CGPoint(x: 1, y: 1)))
    }

    // MARK: icons

    func testEverySymbolExistsOnThisPlatform() {
        for (name, symbol) in IconNames.table {
            #if canImport(UIKit)
            XCTAssertNotNil(UIImage(systemName: symbol), "\(name) → \(symbol)")
            #elseif canImport(AppKit)
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), "\(name) → \(symbol)")
            #endif
        }
    }

    // MARK: TextField

    func testAnEditSetsStateThenFiresOnChangeWithTheValue() async throws {
        let model = OrcaPageModel(page: try page(field: [
            "id": "f", "type": "TextField", "kind": "primitive", "childMode": "none",
            "props": ["stateKey": "name", "value": ["type": "state", "key": "query"]],
            "actions": ["onChange": ["type": "setState", "key": "query",
                                     "value": ["type": "event", "key": "value"]]],
            "children": [], "watches": ["query"],
        ]))
        let field = try XCTUnwrap(model.resolve("f"))

        await model.textChanged("piz", on: field)?.value

        XCTAssertEqual(model.store.value("name"), "piz")
        XCTAssertEqual(model.store.value("query"), "piz")
        XCTAssertEqual(model.resolve("f")?["value"], "piz")
    }

    func testAFieldWithNoBindingFiresNothing() throws {
        let model = OrcaPageModel(page: try page(field: [
            "id": "f", "type": "TextField", "kind": "primitive", "childMode": "none",
            "props": ["placeholder": "Search"], "children": [], "watches": [],
        ]))
        XCTAssertNil(model.textChanged("x", on: try XCTUnwrap(model.resolve("f"))))
    }

    // MARK: helpers

    func page(field: JSONValue) throws -> PageResponse {
        try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "query", "scope": "page", "initial": ""], ["key": "name", "scope": "page", "initial": ""]],
            "components": [field],
        ]).decode(PageResponse.self)
    }

    func layout<V: View>(width: CGFloat, height: CGFloat, @ViewBuilder _ content: () -> V) -> [String: CGRect] {
        let box = FrameBox()
        let root = content()
            .frame(width: width, height: height, alignment: .topLeading)
            .coordinateSpace(name: FrameBox.space)
            .onPreferenceChange(FramesKey.self) { box.frames = $0 }
        let size = CGRect(x: 0, y: 0, width: width, height: height)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: size)
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = size
        host.view.layoutIfNeeded()
        #elseif canImport(AppKit)
        let host = NSHostingView(rootView: root)
        host.frame = size
        host.layoutSubtreeIfNeeded()
        #endif
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        _ = host
        return box.frames
    }
}

final class FrameBox {
    static let space = "orca-test"
    var frames: [String: CGRect] = [:]
}

struct FramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func record(_ name: String) -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(key: FramesKey.self,
                                   value: [name: geometry.frame(in: .named(FrameBox.space))])
        })
    }
}
#endif
