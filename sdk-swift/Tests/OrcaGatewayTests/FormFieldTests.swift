#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A6.4 and A6.7 for TextFormField and Form. Flutter's TextFormField builder
/// is a copy of TextField's (input_builders.dart:86-137), so the TextField
/// view draws it; a Form is its one child and nothing else
/// (layout_builders.dart:481-483). The registry is widened by the two types
/// (advertised only in group 8). Typing needs a UIKit window (iOS only), as
/// in TextFieldTests; the Form's layout runs on macOS too.
@MainActor
final class FormFieldTests: XCTestCase {
    /// A6.4: a Form draws its child and adds nothing: it is the child's
    /// size, where the child is.
    func testA6_4AFormDrawsItsChild() throws {
        let model = try page([
            AppBarCardTests.node("form", "Form", props: [:], children: ["box"]),
            AppBarCardTests.node("box", "SizedBox", childMode: "none", props: ["width": 120, "height": 30]),
        ])
        let frames = NativeWidgetTests().layout(width: 300, height: 200) {
            NodeView(id: "form", model: model).record("form")
        }
        let frame = try XCTUnwrap(frames["form"], "the Form drew nothing")
        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 120, height: 30))
    }

    #if canImport(UIKit)
    /// A6.4: a TextFormField in a Form, as fixture 45 holds it, binds as a
    /// TextField does (TextFieldTests): it shows the store at its stateKey,
    /// and an edit writes the key in page scope, then fires onChange with
    /// the text (onChange reads the key back). The edit is the field's new
    /// text and its editingChanged actions: `insertText` reaches no SwiftUI
    /// field in package tests.
    func testA6_4ATextFormFieldInAFormBindsLikeATextField() throws {
        let hosted = try SwitchSliderTests.Host(try formPage(["stateKey": "name"]))
        defer { hosted.close() }
        let field = try XCTUnwrap(TextFieldTests.textField(in: hosted.window), "no text field in the Form")
        XCTAssertEqual(field.text, "hello")

        XCTAssertTrue(field.becomeFirstResponder(), "the field takes no focus")
        field.text = "hello!"
        SwitchSliderTests.perform(.editingChanged, on: field)
        SwitchSliderTests.settle(hosted) { hosted.model.store.value("echo") != "unset" }
        XCTAssertEqual(field.text, "hello!")
        XCTAssertEqual(hosted.model.store.state.page["name"], "hello!", "the key")
        XCTAssertEqual(hosted.model.store.value("seen"), "hello!", "onChange ran before the write")
        XCTAssertEqual(hosted.model.store.value("echo"), "hello!", "onChange's value")
        field.resignFirstResponder()
    }

    /// A6.7: a disabled bare TextFormField is Flutter's EditableText made
    /// readOnly (input_builders.dart ~:464-467): it takes focus, and an
    /// edit is put back and writes and fires nothing (Flutter's onChanged is
    /// null), as a disabled bare TextField.
    func testA6_7ADisabledTextFormFieldIsReadOnly() throws {
        let hosted = try SwitchSliderTests.Host(try formPage(["stateKey": "name", "enabled": false]))
        defer { hosted.close() }
        let field = try XCTUnwrap(TextFieldTests.textField(in: hosted.window), "no text field in the Form")
        XCTAssertEqual(field.text, "hello")
        XCTAssertTrue(field.becomeFirstResponder(), "a disabled bare field takes no focus")

        field.text = "hello!"
        SwitchSliderTests.perform(.editingChanged, on: field)
        hosted.pump(0.5)
        XCTAssertEqual(field.text, "hello", "the edit stayed")
        XCTAssertEqual(hosted.model.store.value("name"), "hello", "the edit was written")
        XCTAssertEqual(hosted.model.store.value("echo"), "unset", "the edit fired onChange")
        field.resignFirstResponder()
    }

    /// A Form around a TextFormField `f` with `props` and onChange: `name`
    /// to `seen`, the event's value to `echo`.
    func formPage(_ props: [String: JSONValue]) throws -> OrcaPageModel {
        var field = try XCTUnwrap(AppBarCardTests.node("f", "TextFormField", kind: "input", childMode: "none",
                                                       props: props).objectValue)
        field["actions"] = ["onChange": ["type": "actionGroup", "mode": "sequential", "actions": [
            ["type": "setState", "key": "seen", "value": ["type": "state", "key": "name", "scope": "page"]],
            ["type": "setState", "key": "echo", "value": ["type": "event", "key": "value"]],
        ]]]
        return try page([AppBarCardTests.node("form", "Form", props: [:], children: ["f"]), .object(field)])
    }
    #endif

    /// A page of `nodes` (the first is the root) whose registry draws Form
    /// and TextFormField; page state `name` "hello", `seen` and `echo`
    /// "unset".
    func page(_ nodes: [JSONValue]) throws -> OrcaPageModel {
        let response = try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "name", "scope": "page", "initial": "hello"],
                      ["key": "seen", "scope": "page", "initial": "unset"],
                      ["key": "echo", "scope": "page", "initial": "unset"]],
            "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: response, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["Form", "TextFormField"])))
    }
}
#endif
