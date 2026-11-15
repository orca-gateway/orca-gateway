#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A1.8 (gap 6): a read-only TextField takes focus and selection but no
/// edits (Flutter `readOnly`); `hintStyle`, `helperStyle`, `errorStyle` and
/// `isDense` from the decoration apply (BH:270-301). A field the server sends
/// none of them for keeps its native look (native-sdk gate 03), pinned by the
/// native-widgets-home golden. Focus, typing and the drawn styles need a
/// UIKit window (ImageRenderer cannot draw the platform's text field): iOS
/// only. The sizes use the real SwiftUI host of NativeWidgetTests.
@MainActor
final class TextFieldTests: XCTestCase {
    // MARK: A1.8 isDense

    /// isDense takes 4 off the top and the bottom of the default content
    /// padding, for an outlined field (12 to 8) and an underlined one (8 to
    /// 4), as Flutter's InputDecorator does for every border.
    func testA1_8IsDenseMakesTheFieldShorter() throws {
        for border in ["outline", "underline"] {
            let regular = try height(["border": .string(border), "labelText": "Name"])
            let dense = try height(["border": .string(border), "labelText": "Name", "isDense": true])
            XCTAssertEqual(regular - dense, 8, accuracy: 0.5, "\(border): \(regular) then dense \(dense)")
        }
    }

    #if canImport(UIKit)
    // MARK: A1.8 hint, helper and error styles

    /// hintStyle sets the hint's colour and size, inside the field; without
    /// one the hint stays grey.
    func testA1_8HintStyleApplies() throws {
        let styled = try drawn(["hintText": "WWW", "hintStyle": ["color": "#FF0000", "fontSize": 30]])
        let ink = try XCTUnwrap(styled.bounds(of: Pixels.isRed), "hint not drawn in its colour")
        XCTAssertGreaterThanOrEqual(ink.height, 18, "a 30 point W: \(ink)")

        let plain = try drawn(["hintText": "WWW"])
        XCTAssertNil(plain.bounds(of: Pixels.isRed), "an unstyled hint is grey")
    }

    /// helperStyle sets the helper's colour and size; without one the helper
    /// stays grey.
    func testA1_8HelperStyleApplies() throws {
        let styled = try drawn(["helperText": "WWW", "helperStyle": ["color": "#FF0000", "fontSize": 30]])
        let ink = try XCTUnwrap(styled.bounds(of: Pixels.isRed), "helper not drawn in its colour")
        XCTAssertGreaterThanOrEqual(ink.height, 18, "a 30 point W: \(ink)")

        let plain = try drawn(["helperText": "WWW"])
        XCTAssertNil(plain.bounds(of: Pixels.isRed), "an unstyled helper is grey")
    }

    /// errorStyle sets the error's colour and size.
    func testA1_8ErrorStyleApplies() throws {
        let styled = try drawn(["errorText": "WWW", "errorStyle": ["color": "#0000FF", "fontSize": 30]])
        let ink = try XCTUnwrap(styled.bounds(of: AppBarCardTests.isBlue), "error not drawn in its colour")
        XCTAssertGreaterThanOrEqual(ink.height, 18, "a 30 point W: \(ink)")
    }

    // MARK: A1.8 readOnly

    /// readOnly: the field takes focus and its text can be selected, but
    /// typing changes neither the field nor the page's state. With and
    /// without a decoration (Flutter's TextField and EditableText paths).
    func testA1_8AReadOnlyFieldTakesFocusAndSelectionButNoEdits() throws {
        for decoration: JSONValue? in [["labelText": "Name"], nil] {
            var props: [String: JSONValue] = ["stateKey": "name", "readOnly": true]
            props["decoration"] = decoration
            let (window, model) = try host(props)
            defer { window.isHidden = true }
            let field = try XCTUnwrap(Self.textField(in: window), "no text field")
            XCTAssertEqual(field.text, "hello")

            XCTAssertTrue(field.becomeFirstResponder(), "a read-only field takes focus (\(String(describing: decoration)))")
            field.selectAll(nil)
            let selected = try XCTUnwrap(field.selectedTextRange, "nothing selected")
            XCTAssertEqual(field.offset(from: selected.start, to: selected.end), 5, "the whole text is selected")

            field.insertText("x")
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            XCTAssertEqual(field.text, "hello", "typing changed a read-only field")
            XCTAssertEqual(model.store.value("name"), "hello")
            field.resignFirstResponder()
        }
    }
    #endif

    // MARK: helpers

    /// A page holding one TextField `f` with `props`; the page state `name`
    /// starts as "hello".
    func model(_ props: [String: JSONValue]) throws -> OrcaPageModel {
        OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "name", "scope": "page", "initial": "hello"]],
            "components": [AppBarCardTests.node("f", "TextField", kind: "input", childMode: "none", props: props)],
        ]).decode(PageResponse.self))
    }

    /// The height of a 300 wide field with `decoration`, in a real host.
    func height(_ decoration: [String: JSONValue]) throws -> CGFloat {
        let model = try model(["decoration": .object(decoration)])
        let frames = NativeWidgetTests().layout(width: 300, height: 300) {
            NodeView(id: "f", model: model).record("field")
        }
        return try XCTUnwrap(frames["field"], "field not laid out").height
    }

    #if canImport(UIKit)
    static let window = CGSize(width: 300, height: 200)

    /// A field with `decoration` drawn in a UIKit window (ImageRenderer
    /// cannot draw the platform's text field).
    func drawn(_ decoration: [String: JSONValue]) throws -> Pixels {
        let (window, _) = try host(["decoration": .object(decoration)])
        defer { window.isHidden = true }
        return try snapshot(window)
    }

    /// A field with `props` in a light UIKit window at the top left.
    func host(_ props: [String: JSONValue]) throws -> (UIWindow, OrcaPageModel) {
        let model = try model(props)
        let host = UIHostingController(rootView: NodeView(id: "f", model: model)
            .frame(width: Self.window.width, height: Self.window.height, alignment: .topLeading)
            .ignoresSafeArea())
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.window))
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
        let image = UIGraphicsImageRenderer(size: Self.window, format: format).image { context in
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
    #endif
}
#endif
