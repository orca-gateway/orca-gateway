#if canImport(SwiftUI)
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
#endif

@testable import OrcaGateway

/// A7.2: SelectableText as Flutter's builder makes it (primitive_builders
/// .dart:350-362): Material's SelectableText, a read-only EditableText
/// (selectable_text.dart:705-799) whose style is the DefaultTextStyle's
/// merged with its own, textAlign own ?? DTS ?? start, maxLines own ?? DTS
/// (the field is then maxLines lines tall and scrolls, no ellipsis), as
/// wide as its text plus RenderEditable's 3 point caret margin. On iOS a
/// read-only, selectable UITextView in a hosted window (ImageRenderer cannot
/// draw a UIKit view); on macOS the Text path with text selection, drawn by
/// ImageRenderer. A long press, the handles and the edit menu are a hand
/// check. SelectableText and DefaultTextStyle are advertised only in group
/// 7, so the page's registry is widened by them.
@MainActor
final class SelectableTextTests: XCTestCase {
    static let words = "MMMM MMMM MMMM MMMM MMMM MMMM"

    #if canImport(UIKit)
    /// A7.2: a UITextView that cannot be edited and can be selected, no
    /// data detectors, no background, no inset but the caret margin on the
    /// right and no line padding, not scrolling without maxLines; the text
    /// as sent, the view as wide as its one line plus 3 points.
    func testA7_2SelectableIsAReadOnlySelectableTextViewWithTheCaretMargin() throws {
        let (window, views) = try hosted([selectable("s", "Hello world")])
        defer { window.isHidden = true }
        let view = try XCTUnwrap(views.first, "no UITextView drawn")
        XCTAssertFalse(view.isEditable, "the text can be edited")
        XCTAssertTrue(view.isSelectable, "the text cannot be selected")
        XCTAssertEqual(view.dataDetectorTypes, [], "data detectors are on")
        XCTAssertEqual(view.backgroundColor?.cgColor.alpha ?? 0, 0, "the view has a background")
        XCTAssertEqual(view.textContainerInset, UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 3))
        XCTAssertEqual(view.textContainer.lineFragmentPadding, 0)
        XCTAssertFalse(view.isScrollEnabled, "a text without maxLines scrolls")
        XCTAssertEqual(view.attributedText.string, "Hello world")
        let line = view.attributedText.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin, context: nil)
        XCTAssertEqual(view.bounds.width, ceil(line.width) + 3, accuracy: 1,
                       "not the text's width plus the caret margin: \(view.bounds.width) vs \(line.width)")
    }

    /// A7.2: without a DTS, as a Text without one: the ambient body font
    /// (17 at the default size, scaled by Dynamic Type), the label colour,
    /// start; its own size, weight, colour and textAlign win, and a sent
    /// size is fixed, as a Text's.
    func testA7_2SelectableWithoutADtsIsStyledAsAText() throws {
        let plain = try attributes([selectable("s", "Hello")])
        XCTAssertEqual(plain.font.pointSize, UIFont.preferredFont(forTextStyle: .body).pointSize, accuracy: 0.01)
        XCTAssertFalse(plain.font.fontDescriptor.symbolicTraits.contains(.traitBold), "the ambient font is bold")
        XCTAssertEqual(Self.rgba(plain.color), Self.rgba(.label), "not the label colour")
        XCTAssertEqual(plain.alignment, .left, "not start aligned")

        let own = try attributes([selectable("s", "Hello", [
            "style": ["fontSize": 20, "fontWeight": "bold", "color": "#FF0000"], "textAlign": "center",
        ])])
        XCTAssertEqual(own.font.pointSize, 20, accuracy: 0.01)
        XCTAssertTrue(own.font.fontDescriptor.symbolicTraits.contains(.traitBold), "its own weight is lost")
        XCTAssertEqual(Self.rgba(own.color), [1, 0, 0, 1], "its own colour is lost")
        XCTAssertEqual(own.alignment, .center, "its own textAlign is lost")

        let large: (AnyView) -> AnyView = { AnyView($0.environment(\.dynamicTypeSize, .accessibility3)) }
        let scaled = try attributes([selectable("s", "Hello")], wrap: large)
        let body = UIFont.preferredFont(forTextStyle: .body, compatibleWith: UITraitCollection(
            preferredContentSizeCategory: UIContentSizeCategory(DynamicTypeSize.accessibility3)))
        XCTAssertGreaterThan(body.pointSize, 30, "the accessibility size is not larger")
        XCTAssertEqual(scaled.font.pointSize, body.pointSize, accuracy: 0.01, "the body font did not scale")
        let fixed = try attributes([selectable("s", "Hello", ["style": ["fontSize": 20]])], wrap: large)
        XCTAssertEqual(fixed.font.pointSize, 20, accuracy: 0.01, "a sent size scaled")
    }

    /// A7.2: under a DTS {fontWeight: bold} the text is white 14 bold on the
    /// engine base, start; its own fontSize, colour and textAlign win field
    /// by field over the DTS's, the DTS's weight and maxLines still apply.
    func testA7_2SelectableUnderADtsDrawsWhiteFourteenBoldAndItsOwnFieldsWin() throws {
        let ambient: (AnyView) -> AnyView = { AnyView($0.font(.largeTitle).foregroundColor(.red)) }
        let under = try attributes([dts("d", ["style": ["fontWeight": "bold"]], child: "s"),
                                    selectable("s", "Hello")], wrap: ambient)
        XCTAssertEqual(under.font.pointSize, 14, accuracy: 0.01, "not the engine's 14")
        XCTAssertTrue(under.font.fontDescriptor.symbolicTraits.contains(.traitBold), "the DTS's weight is lost")
        XCTAssertEqual(Self.rgba(under.color), [1, 1, 1, 1], "not the engine's white")
        XCTAssertEqual(under.alignment, .left, "not start aligned")
        XCTAssertFalse(under.view.isScrollEnabled)

        let own = try attributes([
            dts("d", ["style": ["fontWeight": "bold", "fontSize": 30, "color": "#FF0000"], "textAlign": "center",
                      "maxLines": 3], child: "s"),
            selectable("s", "Hello", ["style": ["fontSize": 16, "color": "#0000FF"], "textAlign": "right"]),
        ])
        XCTAssertEqual(own.font.pointSize, 16, accuracy: 0.01, "its own size lost to the DTS's")
        XCTAssertTrue(own.font.fontDescriptor.symbolicTraits.contains(.traitBold), "the DTS's weight is lost")
        XCTAssertEqual(Self.rgba(own.color), [0, 0, 1, 1], "its own colour lost to the DTS's")
        XCTAssertEqual(own.alignment, .right, "its own textAlign lost to the DTS's")
        XCTAssertTrue(own.view.isScrollEnabled, "the DTS's maxLines is lost")
    }

    /// A7.2: the word around a point inside "world" is "world" (what a
    /// double tap or a long press selects); selected, the view's selection
    /// is that word, and a range over two words reads them back and copies
    /// them. The gestures, the handles and the menu are a hand check.
    func testA7_2SelectableSelectsAWordAndARangeAndCopiesIt() throws {
        let (window, views) = try hosted([selectable("s", "Hello world again")])
        defer { window.isHidden = true }
        let view = try XCTUnwrap(views.first, "no UITextView drawn")
        let inside = try XCTUnwrap(view.position(from: view.beginningOfDocument, offset: 8))
        let word = try XCTUnwrap(view.tokenizer.rangeEnclosingPosition(
            inside, with: .word, inDirection: UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)),
            "no word around the point")
        XCTAssertEqual(view.text(in: word), "world")
        view.selectedTextRange = word
        XCTAssertEqual(view.selectedRange, NSRange(location: 6, length: 5), "the word is not selected")

        view.selectedRange = NSRange(location: 0, length: 11)
        XCTAssertEqual(view.selectedTextRange.flatMap { view.text(in: $0) }, "Hello world")
        XCTAssertTrue(view.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil),
                      "Copy is not offered")
        // Reading the pasteboard back would ask the user (the paste prompt)
        // and stop the run; its change count and `hasStrings` do not.
        let count = UIPasteboard.general.changeCount
        view.copy(nil)
        XCTAssertGreaterThan(UIPasteboard.general.changeCount, count, "Copy did not write the pasteboard")
        XCTAssertTrue(UIPasteboard.general.hasStrings, "Copy did not write a string")
    }

    /// A7.2: with maxLines 2 a long text is two lines tall (a two-line
    /// text's height), scrolls to the rest and is not cut or ellipsized; a
    /// one-line text with maxLines 2 is two lines tall too (RenderEditable
    /// clamps to minLines ?? maxLines lines); maxLines 1 is one line that
    /// does not wrap and scrolls sideways; without maxLines the view fits
    /// every line and does not scroll.
    func testA7_2SelectableMaxLinesTwoIsTwoLinesTallAndScrollsWithoutAnEllipsis() throws {
        func boxed(_ data: String, _ props: [String: JSONValue] = [:]) throws -> UITextView {
            let (window, views) = try hosted([box("b", width: 150, child: "s"), selectable("s", data, props)])
            defer { window.isHidden = true }
            return try XCTUnwrap(views.first, "no UITextView drawn")
        }
        let one = try boxed("M").bounds.height
        let two = try boxed("M\nM").bounds.height
        XCTAssertGreaterThan(two, one + 10, "the two-line text is not taller: \(one) vs \(two)")

        let cut = try boxed(Self.words, ["maxLines": 2])
        XCTAssertEqual(cut.bounds.height, two, accuracy: 1, "maxLines 2 is not two lines tall")
        XCTAssertEqual(cut.bounds.width, 150, accuracy: 0.5, "the text does not span the box")
        XCTAssertTrue(cut.isScrollEnabled, "maxLines 2 does not scroll")
        XCTAssertGreaterThan(cut.contentSize.height, cut.bounds.height + one / 2, "nothing past two lines")
        XCTAssertEqual(cut.attributedText.string, Self.words, "the text was cut")
        XCTAssertEqual(cut.textContainer.maximumNumberOfLines, 0, "the lines are limited")
        XCTAssertEqual(cut.textContainer.lineBreakMode, .byWordWrapping, "the text is truncated")

        XCTAssertEqual(try boxed("M", ["maxLines": 2]).bounds.height, two, accuracy: 1,
                       "a one-line text with maxLines 2 is not two lines tall")

        let single = try boxed(Self.words, ["maxLines": 1])
        XCTAssertEqual(single.bounds.height, one, accuracy: 1, "maxLines 1 is not one line tall")
        XCTAssertEqual(single.caretRect(for: single.endOfDocument).minY,
                       single.caretRect(for: single.beginningOfDocument).minY, accuracy: 1, "maxLines 1 wraps")
        XCTAssertGreaterThan(single.contentSize.width, single.bounds.width + 20, "maxLines 1 cannot scroll sideways")
        XCTAssertTrue(single.isScrollEnabled, "maxLines 1 does not scroll")

        let whole = try boxed(Self.words)
        XCTAssertGreaterThan(whole.bounds.height, two + 10, "the long text is not past two lines")
        XCTAssertEqual(whole.bounds.height, whole.sizeThatFits(CGSize(
            width: whole.bounds.width, height: .greatestFiniteMagnitude)).height, accuracy: 1,
                       "the view does not fit every line")
        XCTAssertFalse(whole.isScrollEnabled, "a text without maxLines scrolls")
    }

    /// A7.2: a selection survives a redraw while the text is unchanged (a
    /// page-state key the node watches changes and its props do not; its
    /// colour changes), as Flutter's SelectableText keeps its controller
    /// while `data` is the same (didUpdateWidget); new data clears it.
    func testA7_2SelectableKeepsItsSelectionWhileItsDataIsUnchanged() async throws {
        let data: JSONValue = ["type": "state", "key": "text", "scope": "page"]
        let tint: JSONValue = ["type": "state", "key": "tint", "scope": "page"]
        let page: [JSONValue] = [selectable("s", "", ["data": data, "style": ["color": tint]],
                                            watches: ["text", "tick", "tint"])]
        let state: [JSONValue] = [["key": "text", "scope": "page", "initial": "Hello world again"],
                                  ["key": "tick", "scope": "page", "initial": 0],
                                  ["key": "tint", "scope": "page", "initial": "#000000"]]
        let model = try Self.model(page, state: state)
        let (window, views) = try hosted(page, model: model)
        defer { window.isHidden = true }
        let view = try XCTUnwrap(views.first, "no UITextView drawn")
        XCTAssertEqual(view.attributedText.string, "Hello world again")
        view.selectedRange = NSRange(location: 6, length: 5)

        func set(_ key: String, _ value: JSONValue) async throws -> UITextView {
            let action: JSONValue = ["type": "setState", "scope": "page", "key": .string(key),
                                     "value": ["type": "static", "value": value]]
            await model.run(try action.decode(Action.self))
            try await Task.sleep(nanoseconds: 300_000_000)
            return try XCTUnwrap(Self.textViews(in: window).first, "no UITextView after \(key)")
        }
        let redrawn = try await set("tick", 1)
        XCTAssertEqual(redrawn.selectedRange, NSRange(location: 6, length: 5), "a redraw cleared the selection")

        let red = try await set("tint", "#FF0000")
        let color = red.attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(Self.rgba(color), [1, 0, 0, 1], "the new colour is not drawn")
        XCTAssertEqual(red.selectedRange, NSRange(location: 6, length: 5), "a new colour cleared the selection")

        let changed = try await set("text", "Goodbye now")
        XCTAssertEqual(changed.attributedText.string, "Goodbye now", "the new data is not drawn")
        XCTAssertEqual(changed.selectedRange.length, 0, "new data kept the old selection")
    }

    // MARK: hosting

    /// The first UITextView's text attributes at its first character, and
    /// the view.
    func attributes(_ nodes: [JSONValue], wrap: (AnyView) -> AnyView = { $0 }) throws
        -> (font: UIFont, color: UIColor?, alignment: NSTextAlignment?, view: UITextView) {
        let (window, views) = try hosted(nodes, wrap: wrap)
        defer { window.isHidden = true }
        let view = try XCTUnwrap(views.first, "no UITextView drawn")
        let text = try XCTUnwrap(view.attributedText)
        XCTAssertGreaterThan(text.length, 0, "no text")
        let font = try XCTUnwrap(text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, "no font")
        return (font, text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
                (text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment,
                view)
    }

    /// The page in a light 300x300 UIKit window, from its top leading
    /// corner, and the UITextViews in it. `wrap` puts the ambient around it.
    func hosted(_ nodes: [JSONValue], model: OrcaPageModel? = nil, wrap: (AnyView) -> AnyView = { $0 }) throws
        -> (window: UIWindow, views: [UITextView]) {
        guard case .object(let first)? = nodes.first, let root = first["id"]?.stringValue else {
            return try XCTUnwrap(nil as (UIWindow, [UITextView])?, "no root node")
        }
        let page = AnyView(NodeView(id: root, model: try model ?? Self.model(nodes))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
        let host = UIHostingController(rootView: wrap(page).background(Color.white).ignoresSafeArea())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return (window, Self.textViews(in: window))
    }

    static func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }

    /// The colour's sRGB components in the light appearance, rounded to
    /// two places.
    static func rgba(_ color: UIColor?) -> [CGFloat] {
        guard let color else { return [] }
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard resolved.getRed(&r, green: &g, blue: &b, alpha: &a) else { return [] }
        return [r, g, b, a].map { ($0 * 100).rounded() / 100 }
    }
    #else
    /// A7.2 on macOS (no UITextView): a SelectableText is the Text path with
    /// text selection, so it draws the same pixels as a Text with the same
    /// fields, alone, with its own style and textAlign, and under a DTS.
    func testA7_2SelectableOnMacOSDrawsTheSamePixelsAsAText() throws {
        let own: [String: JSONValue] = ["style": ["fontSize": 18, "color": "#FF0000"], "textAlign": "center"]
        for (props, inDts) in [([String: JSONValue](), false), (own, false), ([:], true), (own, true)] {
            func page(_ type: String) -> [JSONValue] {
                let leaf = selectable("s", "Hello world", props, type: type)
                return inDts ? [dts("d", ["style": ["fontWeight": "bold", "color": "#000000"]], child: "s"), leaf]
                    : [leaf]
            }
            let drawn = try draw(page("SelectableText"))
            XCTAssertNotNil(drawn.bounds(of: { $0.a > 100 && min($0.r, $0.g, $0.b) < 200 }),
                            "nothing drawn for \(props)")
            XCTAssertTrue(drawn.bytes == (try draw(page("Text"))).bytes,
                          "not a Text's pixels for \(props), DTS \(inDts)")
        }
    }

    /// The page in a 200x60 box from its top leading corner over white,
    /// drawn by ImageRenderer at scale 1.
    func draw(_ nodes: [JSONValue]) throws -> Pixels {
        guard case .object(let first)? = nodes.first, let root = first["id"]?.stringValue else {
            return try XCTUnwrap(nil as Pixels?, "no root node")
        }
        let renderer = ImageRenderer(content: NodeView(id: root, model: try Self.model(nodes))
            .frame(width: 200, height: 60, alignment: .topLeading).background(Color.white))
        renderer.scale = 1
        return try Pixels(XCTUnwrap(renderer.cgImage, "nothing drawn"))
    }
    #endif

    // MARK: pages

    /// A SelectableText (or `type`) of `data`; a `data` in `props` wins.
    func selectable(_ id: String, _ data: String, _ props: [String: JSONValue] = [:],
                    type: String = "SelectableText", watches: [String] = []) -> JSONValue {
        var all = props
        all["data"] = props["data"] ?? .string(data)
        return [
            "id": .string(id), "type": .string(type), "kind": "primitive", "childMode": "none",
            "props": .object(all), "children": [], "watches": .array(watches.map { .string($0) }),
        ]
    }

    func dts(_ id: String, _ props: [String: JSONValue], child: String) -> JSONValue {
        [
            "id": .string(id), "type": "DefaultTextStyle", "kind": "layout", "childMode": "single",
            "props": .object(props), "children": [.string(child)], "watches": [],
        ]
    }

    func box(_ id: String, width: Double, child: String) -> JSONValue {
        [
            "id": .string(id), "type": "Container", "kind": "layout", "childMode": "single",
            "props": ["width": .double(width)], "children": [.string(child)], "watches": [],
        ]
    }

    /// The page of `nodes` (the first is the root), its registry widened by
    /// SelectableText and DefaultTextStyle.
    static func model(_ nodes: [JSONValue], state: [JSONValue] = []) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": .array(state), "components": .array(nodes),
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets)
            .union(["SelectableText", "DefaultTextStyle"])))
    }
}
#endif
