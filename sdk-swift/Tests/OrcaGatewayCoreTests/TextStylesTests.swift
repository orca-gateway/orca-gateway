import XCTest

@testable import OrcaGatewayCore

/// A7.1 and A7.2, the core half of RichText and DefaultTextStyle: how wire
/// text styles combine, against Flutter. A style is what `parseTextStyle`
/// (sdk/lib/src/builders/builder_helpers.dart:96-120) makes of the wire
/// object: fontStyle always set, normal unless "italic" (:103-105), and
/// decoration "none" a value that clears (:141). A child's set fields win
/// over its parent's (TextStyle.merge, painting/text_style.dart:1078-1122;
/// for spans the engine's PushStyle, lib/ui/text/paragraph_builder.cc:396).
/// RichText's spans (primitive_builders.dart:325-348) run depth-first; a
/// Text under a DefaultTextStyle layers its own fields over the DTS's
/// (widgets/text.dart:723-728, :789-796). The same cases as Kotlin's
/// TextStylesTest.
final class TextStylesTests: XCTestCase {
    private func run(_ text: String, _ style: JSONValue?) -> TextStyles.Run {
        TextStyles.Run(text: text, style: style)
    }

    // MARK: A7.1 merge

    /// A7.1: the child's set fields win field by field, the parent's others
    /// stay; a null field is not set. A nil child is the parent as it is.
    func testA7_1AChildsSetFieldsWinOverItsParent() {
        let parent: JSONValue = ["fontSize": 20, "fontWeight": "bold", "color": "#1E88E5", "letterSpacing": 1]
        let child: JSONValue = ["color": "#E53935", "fontSize": 12, "decoration": "underline", "letterSpacing": nil]
        XCTAssertEqual(TextStyles.merge(parent, child),
                       ["fontSize": 12, "fontWeight": "bold", "color": "#E53935", "letterSpacing": 1,
                        "decoration": "underline", "fontStyle": "normal"])
        let parent2: JSONValue = ["fontSize": 20, "fontWeight": "bold", "color": "#1E88E5", "letterSpacing": 2]
        XCTAssertEqual(TextStyles.merge(parent2, ["fontSize": 12, "color": "#43A047", "letterSpacing": nil]),
                       ["fontSize": 12, "fontWeight": "bold", "color": "#43A047", "letterSpacing": 2, "fontStyle": "normal"])
        XCTAssertEqual(TextStyles.merge(parent, nil), parent)
        XCTAssertEqual(TextStyles.merge(nil, ["color": "#43A047"]), ["color": "#43A047", "fontStyle": "normal"])
        XCTAssertNil(TextStyles.merge(nil, nil))
    }

    /// A7.1: a child that has a style is upright unless its own fontStyle is
    /// "italic", even under an italic parent and even when the style is
    /// empty: parseTextStyle always sets fontStyle.
    func testA7_1AChildWithAStyleIsUprightUnlessItalic() {
        let italic: JSONValue = ["fontStyle": "italic", "color": "#43A047"]
        XCTAssertEqual(TextStyles.merge(italic, ["color": "#E53935"]), ["fontStyle": "normal", "color": "#E53935"])
        XCTAssertEqual(TextStyles.merge(italic, [:]), ["fontStyle": "normal", "color": "#43A047"])
        XCTAssertEqual(TextStyles.merge(italic, ["fontStyle": "oblique"])?["fontStyle"], "normal")
        XCTAssertEqual(TextStyles.merge(nil, ["fontStyle": "italic"]), ["fontStyle": "italic"])
        let italicBlue: JSONValue = ["fontStyle": "italic", "color": "#1E88E5"]
        XCTAssertEqual(TextStyles.merge(italicBlue, ["color": "#E53935"]), ["fontStyle": "normal", "color": "#E53935"])
        XCTAssertEqual(TextStyles.merge(italicBlue, [:]), ["fontStyle": "normal", "color": "#1E88E5"])
        XCTAssertEqual(TextStyles.merge(italicBlue, ["fontStyle": "oblique"]), ["fontStyle": "normal", "color": "#1E88E5"])
        XCTAssertEqual(TextStyles.merge(["color": "#1E88E5"], ["fontStyle": "italic"]),
                       ["fontStyle": "italic", "color": "#1E88E5"])
    }

    /// A7.1: a child without a style (nil, null, or not an object, which
    /// parseTextStyle reads as no style) keeps its parent's italic, and so
    /// does a span without a style.
    func testA7_1AChildWithoutAStyleKeepsItsParentsItalic() {
        let italic: JSONValue = ["fontStyle": "italic", "color": "#43A047"]
        XCTAssertEqual(TextStyles.merge(italic, nil), italic)
        XCTAssertEqual(TextStyles.merge(italic, .null), italic)
        XCTAssertEqual(TextStyles.merge(italic, "bold"), italic)
        let runs = TextStyles.spans(["text": "a", "style": italic, "children": [["text": "b"]]], base: nil)
        XCTAssertEqual(runs, [run("a", italic), run("b", italic)])
        let italic18: JSONValue = ["fontStyle": "italic", "fontSize": 18]
        XCTAssertEqual(TextStyles.merge(italic18, nil), italic18)
        XCTAssertEqual(TextStyles.merge(italic18, .null), italic18)
        XCTAssertEqual(TextStyles.merge(italic18, "bold"), italic18)
        XCTAssertNil(TextStyles.merge(nil, nil))
    }

    /// A7.1: decoration "none" is a set value: it wins over the parent's
    /// line and the merged style says "none"; a child that does not name a
    /// decoration keeps the parent's.
    func testA7_1DecorationNoneClearsTheParentsLine() {
        let underlined: JSONValue = ["decoration": "underline", "decorationColor": "#E53935"]
        XCTAssertEqual(TextStyles.merge(underlined, ["decoration": "none"]),
                       ["decoration": "none", "decorationColor": "#E53935", "fontStyle": "normal"])
        XCTAssertEqual(TextStyles.merge(underlined, ["color": "#000000"])?["decoration"], "underline")
        XCTAssertEqual(TextStyles.merge(underlined, ["decoration": nil]),
                       ["decoration": "underline", "decorationColor": "#E53935", "fontStyle": "normal"])
    }

    // MARK: A7.1 spans

    /// A7.1: fixture 46's tree on the engine base: runs in depth-first order,
    /// each span's style merged onto its parent's, the root's onto the base;
    /// "!" is the root's child, so it takes the root's style, not "world"'s.
    func testA7_1SpansFlattenDepthFirstWithMergedStyles() {
        let root: JSONValue = [
            "text": "Hello ", "style": ["fontWeight": "bold", "color": "#1E88E5"],
            "children": [
                ["text": "world", "style": ["fontStyle": "italic", "color": "#43A047"],
                 "children": [["text": "Ada", "style": ["color": "#E53935", "decoration": "underline"]]]],
                ["text": "!"],
            ],
        ]
        let base: JSONValue = ["fontSize": 14, "color": "#FFFFFF"]
        XCTAssertEqual(TextStyles.spans(root, base: base), [
            run("Hello ", ["fontSize": 14, "color": "#1E88E5", "fontWeight": "bold", "fontStyle": "normal"]),
            run("world", ["fontSize": 14, "color": "#43A047", "fontWeight": "bold", "fontStyle": "italic"]),
            run("Ada", ["fontSize": 14, "color": "#E53935", "fontWeight": "bold", "fontStyle": "normal",
                        "decoration": "underline"]),
            run("!", ["fontSize": 14, "color": "#1E88E5", "fontWeight": "bold", "fontStyle": "normal"]),
        ])
        XCTAssertEqual(TextStyles.spans(root, base: nil).first,
                       run("Hello ", ["fontWeight": "bold", "color": "#1E88E5", "fontStyle": "normal"]))
        XCTAssertEqual(TextStyles.spans(["text": "x"], base: base), [run("x", base)])
    }

    /// A7.1: a child that is not an object is a run of its own text, Dart's
    /// `'$c'` (null prints "null"), in the style of the span that holds it.
    func testA7_1ANonObjectChildIsItsOwnTextWithTheParentsStyle() {
        let blue: JSONValue = ["color": "#1E88E5", "fontStyle": "normal"]
        let runs = TextStyles.spans(["text": "n=", "style": ["color": "#1E88E5"],
                                     "children": ["x", 3, 4.0, true, nil]], base: nil)
        XCTAssertEqual(runs, [run("n=", blue), run("x", blue), run("3", blue), run("4.0", blue),
                              run("true", blue), run("null", blue)])
        let green: JSONValue = ["color": "#43A047", "fontStyle": "normal"]
        let greenRuns = TextStyles.spans(["text": "n=", "style": ["color": "#43A047"],
                                          "children": ["plain", 3, 2.5, 4.0, true, nil]], base: nil)
        XCTAssertEqual(greenRuns, ["n=", "plain", "3", "2.5", "4.0", "true", "null"].map { run($0, green) })
    }

    /// A7.1: a span without `text` (or with null) is an empty run that still
    /// carries its style; a number text prints the Dart way
    /// (resolveStringValue, builder_helpers.dart:436-447). No root at all is
    /// Flutter's `const TextSpan()`: one empty run in the base style.
    func testA7_1ASpanWithoutTextIsAnEmptyRun() {
        let blue: JSONValue = ["color": "#1E88E5", "fontStyle": "normal"]
        let runs = TextStyles.spans(["style": ["color": "#1E88E5"],
                                     "children": [["text": "a"], ["style": ["fontWeight": "bold"]], ["text": nil],
                                                  ["text": 2.5]]], base: nil)
        XCTAssertEqual(runs, [run("", blue), run("a", blue),
                              run("", ["color": "#1E88E5", "fontWeight": "bold", "fontStyle": "normal"]),
                              run("", blue), run("2.5", blue)])
        XCTAssertEqual(TextStyles.spans(nil, base: ["fontSize": 14]), [run("", ["fontSize": 14])])
        let base: JSONValue = ["fontSize": 14, "color": "#FFFFFF"]
        let size20: JSONValue = ["fontSize": 20, "color": "#FFFFFF", "fontStyle": "normal"]
        XCTAssertEqual(TextStyles.spans(["style": ["fontSize": 20],
                                         "children": [["text": nil, "children": [["text": 7]]]]], base: base),
                       [run("", size20), run("", size20), run("7", size20)])
        XCTAssertEqual(TextStyles.spans([:], base: base), [run("", base)])
        XCTAssertEqual(TextStyles.spans(nil, base: base), [run("", base)])
    }

    // MARK: A7.2 DefaultTextStyle layering

    /// A7.2: a Text's own style merges over the DTS's field by field (and,
    /// being a style, sets upright); without its own style the DTS's stands;
    /// without a DTS it is its own.
    func testA7_2ATextsOwnStyleMergesOverTheDtsStyle() {
        let dts = TextStyles.Layer(style: ["fontWeight": "bold", "color": "#E53935", "fontSize": 30, "fontStyle": "italic"])
        XCTAssertEqual(TextStyles.layer(dts: dts, own: TextStyles.Layer(style: ["color": "#1E88E5"])).style,
                       ["fontWeight": "bold", "color": "#1E88E5", "fontSize": 30, "fontStyle": "normal"])
        XCTAssertEqual(TextStyles.layer(dts: dts, own: TextStyles.Layer()).style, dts.style)
        XCTAssertEqual(TextStyles.layer(dts: nil, own: TextStyles.Layer(style: ["color": "#1E88E5"])).style,
                       ["color": "#1E88E5", "fontStyle": "normal"])
        XCTAssertEqual(TextStyles.layer(dts: TextStyles.Layer(), own: TextStyles.Layer(style: ["fontSize": 12])).style,
                       ["fontSize": 12, "fontStyle": "normal"])
    }

    /// A7.2: textAlign is the Text's own, then the DTS's, then start.
    func testA7_2OwnTextAlignWinsThenTheDtsThenStart() {
        let dts = TextStyles.Layer(textAlign: "right")
        XCTAssertEqual(TextStyles.layer(dts: dts, own: TextStyles.Layer(textAlign: "center")).textAlign, "center")
        XCTAssertEqual(TextStyles.layer(dts: dts, own: TextStyles.Layer()).textAlign, "right")
        XCTAssertEqual(TextStyles.layer(dts: TextStyles.Layer(), own: TextStyles.Layer()).textAlign, "start")
        XCTAssertEqual(TextStyles.layer(dts: nil, own: TextStyles.Layer()).textAlign, "start")
        let centered = TextStyles.Layer(textAlign: "center")
        XCTAssertEqual(TextStyles.layer(dts: centered, own: TextStyles.Layer(textAlign: "right")).textAlign, "right")
        XCTAssertEqual(TextStyles.layer(dts: centered, own: TextStyles.Layer()).textAlign, "center")
    }

    /// A7.2: maxLines is the Text's own, then the DTS's, else none.
    func testA7_2OwnMaxLinesWinsThenTheDts() {
        let dts = TextStyles.Layer(maxLines: 3)
        XCTAssertEqual(TextStyles.layer(dts: dts, own: TextStyles.Layer(maxLines: 1)).maxLines, 1)
        XCTAssertEqual(TextStyles.layer(dts: dts, own: TextStyles.Layer()).maxLines, 3)
        XCTAssertNil(TextStyles.layer(dts: TextStyles.Layer(), own: TextStyles.Layer()).maxLines)
    }

    /// A7.2: overflow is the Text's own, then its style's, then the DTS's,
    /// then clip. "Its style" is Flutter's effective style (text.dart:794,
    /// the DTS style merged with the Text's), so a DTS style's overflow beats
    /// the DTS's own overflow.
    func testA7_2OverflowIsOwnThenItsStyleThenTheDtsThenClip() {
        let dts = TextStyles.Layer(overflow: "visible")
        XCTAssertEqual(TextStyles.layer(dts: dts, own: TextStyles.Layer(style: ["overflow": "fade"], overflow: "ellipsis")).overflow,
                       "ellipsis")
        XCTAssertEqual(TextStyles.layer(dts: dts, own: TextStyles.Layer(style: ["overflow": "fade"])).overflow, "fade")
        let styled = TextStyles.Layer(style: ["overflow": "ellipsis"], overflow: "visible")
        XCTAssertEqual(TextStyles.layer(dts: styled, own: TextStyles.Layer(style: ["color": "#1E88E5"])).overflow,
                       "ellipsis")
        XCTAssertEqual(TextStyles.layer(dts: dts, own: TextStyles.Layer(style: ["color": "#1E88E5"])).overflow, "visible")
        XCTAssertEqual(TextStyles.layer(dts: nil, own: TextStyles.Layer()).overflow, "clip")
        let fading = TextStyles.Layer(style: ["overflow": "visible"], overflow: "fade")
        XCTAssertEqual(TextStyles.layer(dts: fading, own: TextStyles.Layer(style: ["overflow": "ellipsis"], overflow: "clip")).overflow,
                       "clip")
        XCTAssertEqual(TextStyles.layer(dts: fading, own: TextStyles.Layer(style: ["overflow": "ellipsis"])).overflow, "ellipsis")
        XCTAssertEqual(TextStyles.layer(dts: fading, own: TextStyles.Layer()).overflow, "visible")
        XCTAssertEqual(TextStyles.layer(dts: TextStyles.Layer(overflow: "fade"), own: TextStyles.Layer()).overflow, "fade")
        XCTAssertEqual(TextStyles.layer(dts: TextStyles.Layer(), own: TextStyles.Layer()).overflow, "clip")
    }
}
