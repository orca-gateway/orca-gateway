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
    /// Typing is the field's new text and its editingChanged actions
    /// (`insertText` reaches no SwiftUI field in package tests).
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

            field.text = "x"
            SwitchSliderTests.perform(.editingChanged, on: field)
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            XCTAssertEqual(field.text, "hello", "typing changed a read-only field")
            XCTAssertEqual(model.store.value("name"), "hello")
            field.resignFirstResponder()
        }
    }

    // MARK: A6.7 enabled false

    /// A6.7: a disabled field keeps its text's look, in the field's black:
    /// Flutter's decorated TextField keeps the builder's style over
    /// Material's disabled colour (text_field.dart:1584-1586), and SwiftUI
    /// does not dim it. Bare, it is Flutter's EditableText with `readOnly:
    /// !enabled || readOnly` (input_builders.dart ~:464-467): it takes focus;
    /// decorated, TextField(enabled: false): it takes none. An edit is put
    /// back and writes and sends nothing (Flutter's onChanged is null).
    func testA6_7ADisabledFieldKeepsItsTextAndTakesNoEdits() throws {
        let onChange: JSONValue = ["type": "setState", "key": "echo", "value": ["type": "event", "key": "value"]]
        for decoration: JSONValue? in [nil, ["labelText": "Name"]] {
            var props: [String: JSONValue] = ["stateKey": "name"]
            props["decoration"] = decoration
            let (live, _) = try host(props)
            let ink = try snapshot(live).bounds(of: Pixels.isInk)
            live.isHidden = true

            props["enabled"] = false
            let (window, model) = try host(props, onChange: onChange)
            defer { window.isHidden = true }
            let label = decoration == nil ? "bare" : "decorated"
            XCTAssertNotNil(ink, "\(label): no text in ink")
            XCTAssertEqual(try snapshot(window).bounds(of: Pixels.isInk), ink, "\(label): its text drawn otherwise")

            let field = try XCTUnwrap(Self.textField(in: window), "\(label): no text field")
            XCTAssertEqual(field.becomeFirstResponder(), decoration == nil, "\(label): focus")
            field.text = "hello!"
            SwitchSliderTests.perform(.editingChanged, on: field)
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            XCTAssertEqual(field.text, "hello", "\(label): the edit stayed")
            XCTAssertEqual(model.store.value("name"), "hello", "\(label): the edit was written")
            XCTAssertEqual(model.store.value("echo"), .null, "\(label): the edit fired onChange")
            field.resignFirstResponder()
        }
    }

    /// A6.7: a disabled decorated field draws Material 3's disabled state
    /// (input_decorator_defaults_m3.g.dart): the label, hint, helper,
    /// counter and prefix in onSurface #1D1B20 at 0.38, the border at 0.12,
    /// a filled field's underline at 0.38; the error text stays red. Each
    /// part is drawn alone on an empty field; a large font where the part
    /// takes a style, so its strokes show their full colour (text in the
    /// greyed range CheckboxRadioTests uses, as glyphs render a little
    /// darker than a fill of the same colour). A colour the
    /// decoration sets wins (Flutter merges the decoration's style over the
    /// state's).
    func testA6_7ADisabledDecorationDrawsMaterialDisabledColours() throws {
        let big: JSONValue = ["fontSize": 30]
        let line = (228, 228, 228), indicator = (169, 168, 170)
        let cases: [(String, [String: JSONValue], (Int, Int, Int)?)] = [
            ("label", ["labelText": "WWW", "labelStyle": big, "border": "none"], nil),
            ("hint", ["hintText": "WWW", "hintStyle": big, "border": "none"], nil),
            ("helper", ["helperText": "WWW", "helperStyle": big, "border": "none"], nil),
            ("counter", ["border": "none"], nil),
            ("prefix", ["prefixText": "WWW", "border": "none"], nil),
            ("underline", [:], line),
            ("outline", ["border": "outline"], line),
            ("filled underline", ["filled": true], indicator),
        ]
        for (part, decoration, colour) in cases {
            var props: [String: JSONValue] = ["decoration": .object(decoration), "enabled": false]
            if part == "counter" { props["maxLength"] = 10 }
            let (window, _) = try host(props)
            defer { window.isHidden = true }
            let darkest = Self.darkest(try snapshot(window))
            if let colour {
                CheckboxRadioTests.assertColour(darkest, colour, "\(part): the darkest pixel")
            } else if decoration.values.contains(big) {
                XCTAssertTrue(CheckboxRadioTests.isGreyed(darkest), "\(part): the darkest pixel \(darkest)")
            } else {
                let grey = Int(darkest.g)
                XCTAssertTrue((160...240).contains(grey) && abs(Int(darkest.r) - grey) <= 8,
                              "\(part): \(darkest), not drawn in the disabled grey or lighter")
            }
        }

        let red: JSONValue = ["color": "#FF0000", "fontSize": 30]
        for (part, decoration) in [("labelStyle", ["labelText": "WWW", "labelStyle": red]),
                                   ("errorText", ["errorText": "WWW", "errorStyle": big])] as [(String, JSONValue)] {
            let (window, _) = try host(["decoration": decoration, "enabled": false])
            defer { window.isHidden = true }
            XCTAssertNotNil(try snapshot(window).bounds(of: Pixels.isRed), "\(part): not red while disabled")
        }
    }

    /// The pixel with the least light.
    static func darkest(_ pixels: Pixels) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        var found = pixels.pixel(0, 0)
        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                let p = pixels.pixel(x, y)
                if Int(p.r) + Int(p.g) + Int(p.b) < Int(found.r) + Int(found.g) + Int(found.b) { found = p }
            }
        }
        return found
    }
    #endif

    // MARK: helpers

    /// A page holding one TextField `f` with `props` (and `onChange` when
    /// given); the page state `name` starts as "hello".
    func model(_ props: [String: JSONValue], onChange: JSONValue? = nil) throws -> OrcaPageModel {
        var field = AppBarCardTests.node("f", "TextField", kind: "input", childMode: "none", props: props)
        if let onChange, case .object(var node) = field {
            node["actions"] = ["onChange": onChange]
            field = .object(node)
        }
        return OrcaPageModel(page: try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "name", "scope": "page", "initial": "hello"]],
            "components": [field],
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
    func host(_ props: [String: JSONValue], onChange: JSONValue? = nil) throws -> (UIWindow, OrcaPageModel) {
        let model = try model(props, onChange: onChange)
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
